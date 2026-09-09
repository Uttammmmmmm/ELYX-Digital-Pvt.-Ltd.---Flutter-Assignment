import 'dart:io';

import 'package:elyx_digital_assignment/core/constants/cache_constants.dart';
import 'package:elyx_digital_assignment/core/di/injection_container.dart';
import 'package:elyx_digital_assignment/core/network/dio_client.dart';
import 'package:elyx_digital_assignment/core/network/network_info.dart';
import 'package:elyx_digital_assignment/core/network/rate_limit_tracker.dart';
import 'package:elyx_digital_assignment/features/users/domain/repositories/user_repository.dart';
import 'package:elyx_digital_assignment/features/users/domain/usecases/filter_users.dart';
import 'package:elyx_digital_assignment/features/users/domain/usecases/get_user_detail.dart';
import 'package:elyx_digital_assignment/features/users/domain/usecases/get_users.dart';
import 'package:elyx_digital_assignment/features/users/domain/usecases/refresh_users.dart';
import 'package:elyx_digital_assignment/features/users/presentation/bloc/user_detail_bloc.dart';
import 'package:elyx_digital_assignment/features/users/presentation/bloc/users_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

/// A DI graph only fails at runtime, on the screen that needs it. Resolving
/// every registration once in CI turns that into a build failure instead.
void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('di_test');
    Hive.init(tempDir.path);
    await Hive.openBox<String>(CacheConstants.usersPageBox);
    await Hive.openBox<String>(CacheConstants.userDetailBox);
    await initDependencies();
  });

  tearDown(() async {
    await resetDependencies();
    await Hive.deleteFromDisk();
    await tempDir.delete(recursive: true);
  });

  test('every registration resolves', () {
    expect(sl<RateLimitTracker>(), isNotNull);
    expect(sl<DioClient>(), isNotNull);
    expect(sl<NetworkInfo>(), isA<NetworkInfoImpl>());
    expect(sl<UserRepository>(), isNotNull);
    expect(sl<GetUsers>(), isNotNull);
    expect(sl<RefreshUsers>(), isNotNull);
    expect(sl<GetUserDetail>(), isNotNull);
    expect(sl<FilterUsers>(), isNotNull);
  });

  test('app-scoped services are singletons', () {
    expect(sl<RateLimitTracker>(), same(sl<RateLimitTracker>()),
        reason: 'a second tracker would halve the app view of its own quota');
    expect(sl<DioClient>(), same(sl<DioClient>()));
    expect(sl<UserRepository>(), same(sl<UserRepository>()));
  });

  test('blocs are factories so each screen gets its own', () {
    final UsersBloc a = sl<UsersBloc>();
    final UsersBloc b = sl<UsersBloc>();

    expect(a, isNot(same(b)),
        reason: 'closing one screen must not dispose another stream');

    a.close();
    b.close();
  });

  test('a detail bloc is constructible and starts idle', () {
    final UserDetailBloc bloc = sl<UserDetailBloc>();

    expect(bloc.state.runtimeType.toString(), 'UserDetailInitial');

    bloc.close();
  });
}
