import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:elyx_digital_assignment/core/constants/cache_constants.dart';
import 'package:elyx_digital_assignment/core/di/injection_container.dart';
import 'package:elyx_digital_assignment/core/error/failures.dart';
import 'package:elyx_digital_assignment/core/network/dio_client.dart';
import 'package:elyx_digital_assignment/core/network/network_info.dart';
import 'package:elyx_digital_assignment/core/network/rate_limit_tracker.dart';
import 'package:elyx_digital_assignment/core/storage/hive_initializer.dart';
import 'package:elyx_digital_assignment/features/users/data/datasources/api/reqres_users_api.dart';
import 'package:elyx_digital_assignment/features/users/data/datasources/api/users_api.dart';
import 'package:elyx_digital_assignment/features/users/data/datasources/user_local_data_source.dart';
import 'package:elyx_digital_assignment/features/users/data/models/cached_page_model.dart';
import 'package:elyx_digital_assignment/features/users/data/models/user_detail_model.dart';
import 'package:elyx_digital_assignment/features/users/domain/entities/paginated_users.dart';
import 'package:elyx_digital_assignment/features/users/domain/entities/user_summary.dart';
import 'package:elyx_digital_assignment/features/users/domain/repositories/user_repository.dart';
import 'package:elyx_digital_assignment/features/users/domain/usecases/filter_users.dart';
import 'package:elyx_digital_assignment/features/users/domain/usecases/get_user_detail.dart';
import 'package:elyx_digital_assignment/features/users/domain/usecases/get_users.dart';
import 'package:elyx_digital_assignment/features/users/presentation/bloc/user_detail_bloc.dart';
import 'package:elyx_digital_assignment/features/users/presentation/bloc/user_detail_state.dart';
import 'package:elyx_digital_assignment/features/users/presentation/bloc/users_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:mockito/mockito.dart';

import '../../helpers/entity_fixtures.dart';
import '../../helpers/mocks.mocks.dart';

/// A DI graph only fails at runtime, on the screen that needs it. Resolving
/// every registration once in CI turns that into a build failure instead.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late HiveBoxes boxes;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('di_test');
    // HiveInitializer.init() cannot run here: initFlutter() needs
    // path_provider, which has no implementation under flutter_test.
    Hive.init(tempDir.path);
    HiveInitializer.registerAdaptersOnce();
    boxes = HiveBoxes(
      pages: await Hive.openBox<CachedPageModel>(CacheConstants.usersPageBox),
      details:
          await Hive.openBox<UserDetailModel>(CacheConstants.userDetailBox),
    );
    await init(boxes: boxes);
  });

  tearDown(() async {
    await resetDependencies();
    await Hive.deleteFromDisk();
    await tempDir.delete(recursive: true);
  });

  group('graph', () {
    test('every registration resolves', () {
      expect(sl<RateLimitTracker>(), isNotNull);
      expect(sl<UsersApi>(), isNotNull);
      expect(sl<DioClient>(), isNotNull);
      expect(sl<HiveBoxes>(), isNotNull);
      expect(sl<NetworkInfo>(), isA<NetworkInfoImpl>());
      expect(sl<UserLocalDataSource>(), isA<UserLocalDataSourceImpl>());
      expect(sl<UserRepository>(), isNotNull);
      expect(sl<GetUsers>(), isNotNull);
      expect(sl<GetUserDetail>(), isNotNull);
      expect(sl<FilterUsers>(), isNotNull);
    });

    test('reqres is the default source -- the brief names it in prose', () {
      expect(kApiSource, 'reqres');
      expect(sl<UsersApi>(), isA<ReqresUsersApi>());
      expect(sl<UsersApi>().baseUrl, 'https://reqres.in/api');
      expect(sl<UsersApi>().headers['x-api-key'], isNotEmpty,
          reason: 'reqres 401s without it');
    });

    test('the Dio client takes its host and headers from the source', () {
      // Not hardcoded: switching API_SOURCE must repoint the client too.
      expect(sl<DioClient>(), isNotNull);
      expect(sl<UsersApi>().baseUrl, contains('reqres.in'));
    });

    test('registered against the ABSTRACT types only', () {
      expect(sl<UserRepository>(), isNotNull);
      expect(sl.isRegistered<ReqresUsersApi>(), isFalse,
          reason: 'consumers must not reach for an implementation');
    });
  });

  group('lifetimes', () {
    test('app-scoped services are singletons', () {
      expect(sl<RateLimitTracker>(), same(sl<RateLimitTracker>()),
          reason: 'two trackers would each see half the responses');
      expect(sl<DioClient>(), same(sl<DioClient>()));
      expect(sl<UsersApi>(), same(sl<UsersApi>()));
      expect(sl<UserRepository>(), same(sl<UserRepository>()));
      expect(sl<HiveBoxes>(), same(boxes));
    });

    test('blocs are factories -- fresh per screen, clean disposal', () {
      final UsersBloc a = sl<UsersBloc>();
      final UsersBloc b = sl<UsersBloc>();

      expect(a, isNot(same(b)),
          reason: 'a singleton bloc closed on the first pop would throw on '
              'every later screen, and leak state across back navigation');

      a.close();
      expect(b.isClosed, isFalse);
      b.close();
    });

    test('a detail bloc is a param factory seeded with its UserSummary', () {
      final UserSummary seed = reqresUser(2, first: 'Janet');

      final UserDetailBloc bloc = sl<UserDetailBloc>(param1: seed);

      expect(bloc.state.seed, seed);
      expect(bloc.state.status, UserDetailStatus.initial);
      expect(sl<UserDetailBloc>(param1: seed), isNot(same(bloc)));

      bloc.close();
    });
  });

  group('idempotency', () {
    test('calling init twice does not throw -- survives hot restart',
        () async {
      await expectLater(init(boxes: boxes), completes);
      expect(sl<UserRepository>(), isNotNull);
    });
  });

  group('test overrides', () {
    test('a mock UsersApi can replace the real one', () async {
      final MockUsersApi mockApi = MockUsersApi();
      when(mockApi.fetchUsers(
        cursor: anyNamed('cursor'),
        perPage: anyNamed('perPage'),
      )).thenAnswer(
        (_) async => PaginatedUsers.fromBatch(
          users: <UserSummary>[reqresUser(1, first: 'FromThe', last: 'Mock')],
          nextCursor: 2,
        ),
      );

      final MockNetworkInfo mockNetwork = MockNetworkInfo();
      when(mockNetwork.isConnected).thenAnswer((_) async => true);

      // 1. Permit re-registration of an already-registered type.
      sl.allowReassignment = true;
      // 2. Swap the implementations behind the ABSTRACT types.
      sl
        ..registerLazySingleton<UsersApi>(() => mockApi)
        ..registerLazySingleton<NetworkInfo>(() => mockNetwork);
      // 3. Drop the repository's cached instance so it rebuilds against the
      //    mocks. Without this it keeps the real collaborators it captured on
      //    first resolution -- the step that is easy to forget.
      sl.resetLazySingleton<UserRepository>();

      final Either<Failure, PaginatedUsers> result =
          await sl<UserRepository>().getUsers();

      expect(
        result.fold((Failure f) => fail('expected Right: $f'),
            (PaginatedUsers p) => p.users.single.displayName),
        'FromThe Mock',
      );
    });
  });
}
