import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:elyx_digital_assignment/core/constants/cache_constants.dart';
import 'package:elyx_digital_assignment/core/di/injection_container.dart';
import 'package:elyx_digital_assignment/core/error/failures.dart';
import 'package:elyx_digital_assignment/core/network/dio_client.dart';
import 'package:elyx_digital_assignment/core/network/link_header_parser.dart';
import 'package:elyx_digital_assignment/core/network/network_info.dart';
import 'package:elyx_digital_assignment/core/network/rate_limit_tracker.dart';
import 'package:elyx_digital_assignment/core/storage/hive_initializer.dart';
import 'package:elyx_digital_assignment/features/users/data/datasources/user_local_data_source.dart';
import 'package:elyx_digital_assignment/features/users/data/datasources/user_remote_data_source.dart';
import 'package:elyx_digital_assignment/features/users/data/models/cached_page_model.dart';
import 'package:elyx_digital_assignment/features/users/data/models/user_detail_model.dart';
import 'package:elyx_digital_assignment/features/users/data/models/user_summary_model.dart';
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

import '../../helpers/mocks.mocks.dart';

/// A DI graph only fails at runtime, on the screen that needs it. Resolving
/// every registration once in CI turns that into a build failure instead.
void main() {
  // Hive and connectivity both reach for platform channels.
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late HiveBoxes boxes;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('di_test');
    // HiveInitializer.init() cannot run here: initFlutter() needs
    // path_provider, which has no implementation under flutter_test. The
    // adapter registration and box opening it performs are exercised
    // directly instead.
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
      expect(sl<DioClient>(), isNotNull);
      expect(sl<HiveBoxes>(), isNotNull);
      expect(sl<NetworkInfo>(), isA<NetworkInfoImpl>());
      expect(sl<LinkHeaderParser>(), isNotNull);
      expect(sl<UserRemoteDataSource>(), isA<UserRemoteDataSourceImpl>());
      expect(sl<UserLocalDataSource>(), isA<UserLocalDataSourceImpl>());
      expect(sl<UserRepository>(), isNotNull);
      expect(sl<GetUsers>(), isNotNull);
      expect(sl<GetUserDetail>(), isNotNull);
      expect(sl<FilterUsers>(), isNotNull);
    });

    test('the repository is registered against the ABSTRACT type', () {
      // Resolving the contract works...
      expect(sl<UserRepository>(), isNotNull);
      // ...and the concrete impl is deliberately NOT resolvable, so no
      // consumer can reach for an implementation-only member.
      expect(sl.isRegistered<UserRemoteDataSourceImpl>(), isFalse);
    });
  });

  group('lifetimes', () {
    test('app-scoped services are singletons', () {
      expect(sl<RateLimitTracker>(), same(sl<RateLimitTracker>()),
          reason: 'two trackers would each see half the responses');
      expect(sl<DioClient>(), same(sl<DioClient>()));
      expect(sl<UserRepository>(), same(sl<UserRepository>()));
      expect(sl<HiveBoxes>(), same(boxes), reason: 'the opened instance');
    });

    test('blocs are factories -- fresh per screen, clean disposal', () {
      final UsersBloc a = sl<UsersBloc>();
      final UsersBloc b = sl<UsersBloc>();

      expect(a, isNot(same(b)),
          reason: 'a singleton bloc closed on the first pop would throw on '
              'every later screen, and leak state across back navigation');

      // Closing one must not affect the other -- the memory-leak scenario.
      a.close();
      expect(b.isClosed, isFalse);
      b.close();
    });

    test('a detail bloc is a param factory seeded with its UserSummary', () {
      const UserSummary seed = UserSummary(
        id: 1,
        login: 'mojombo',
        avatarUrl: 'a',
        htmlUrl: 'h',
        type: 'User',
        siteAdmin: false,
      );

      final UserDetailBloc bloc = sl<UserDetailBloc>(param1: seed);

      // The seed is present before any request, so the screen opens populated.
      expect(bloc.state.seed, seed);
      expect(bloc.state.status, UserDetailStatus.initial);
      // Still a factory: two open detail screens must not share one bloc.
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
    test('a mock remote data source can replace the real one', () async {
      final MockUserRemoteDataSource mockRemote = MockUserRemoteDataSource();
      when(mockRemote.getUsers(
        since: anyNamed('since'),
        perPage: anyNamed('perPage'),
      )).thenAnswer(
        (_) async => PaginatedUsers.fromBatch(
          users: const <UserSummary>[
            UserSummaryModel(
              id: 1,
              login: 'from-the-mock',
              avatarUrl: 'a',
              htmlUrl: 'h',
              type: 'User',
              siteAdmin: false,
            ),
          ],
          nextSince: 1,
        ),
      );

      // The repository also consults NetworkInfo, whose real implementation
      // hits a platform channel. Swapping it keeps the test hermetic.
      final MockNetworkInfo mockNetwork = MockNetworkInfo();
      when(mockNetwork.isConnected).thenAnswer((_) async => true);

      // 1. Permit re-registration of an already-registered type.
      sl.allowReassignment = true;
      // 2. Swap the implementations behind the abstract types.
      sl
        ..registerLazySingleton<UserRemoteDataSource>(() => mockRemote)
        ..registerLazySingleton<NetworkInfo>(() => mockNetwork);
      // 3. Drop the repository's cached instance so it is rebuilt against the
      //    mocks. Without this it keeps the real collaborators it captured on
      //    first resolution -- the step that is easy to forget.
      sl.resetLazySingleton<UserRepository>();

      final Either<Failure, PaginatedUsers> result =
          await sl<UserRepository>().getUsers();

      expect(
        result.fold((Failure f) => fail('expected Right: $f'),
            (PaginatedUsers p) => p.users.single.login),
        'from-the-mock',
        reason: 'the graph now runs entirely against the mock, no network',
      );
      verify(mockRemote.getUsers(since: null, perPage: anyNamed('perPage')))
          .called(1);
    });
  });
}
