/// Dependency wiring.
library;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_ce/hive.dart';

import '../../features/users/data/datasources/user_local_data_source.dart';
import '../../features/users/data/datasources/user_remote_data_source.dart';
import '../../features/users/data/repositories/user_repository_impl.dart';
import '../../features/users/domain/repositories/user_repository.dart';
import '../../features/users/domain/usecases/filter_users.dart';
import '../../features/users/domain/usecases/get_user_detail.dart';
import '../../features/users/domain/usecases/get_users.dart';
import '../../features/users/presentation/bloc/user_detail_bloc.dart';
import '../../features/users/presentation/bloc/users_bloc.dart';
import '../constants/cache_constants.dart';
import '../network/dio_client.dart';
import '../network/network_info.dart';
import '../network/rate_limit_tracker.dart';
import '../../features/users/data/models/cached_page_model.dart';
import '../../features/users/data/models/user_detail_model.dart';

/// The service locator.
final GetIt sl = GetIt.instance;

/// Registers every dependency. Call after `HiveInitializer.init()`.
///
/// Registration style is deliberate:
///  - `registerLazySingleton` for anything stateless or app-scoped. One Dio,
///    one rate-limit tracker -- a second tracker would silently halve the
///    app's view of its own quota.
///  - `registerFactory` for Blocs, so each screen gets a fresh instance and
///    closing one never disposes another's stream.
Future<void> initDependencies() async {
  // -- External -------------------------------------------------------------
  sl
    ..registerLazySingleton<Connectivity>(Connectivity.new)
    ..registerLazySingleton<RateLimitTracker>(RateLimitTracker.new)
    ..registerLazySingleton<DioClient>(
      () => DioClient(rateLimitTracker: sl<RateLimitTracker>()),
    );

  // -- Core -----------------------------------------------------------------
  sl.registerLazySingleton<NetworkInfo>(
    () => NetworkInfoImpl(sl<Connectivity>()),
  );

  // -- Data sources ---------------------------------------------------------
  sl
    ..registerLazySingleton<UserRemoteDataSource>(
      () => UserRemoteDataSourceImpl(sl<DioClient>()),
    )
    ..registerLazySingleton<UserLocalDataSource>(
      // Boxes are already open and adapters already registered --
      // HiveInitializer.init() ran before this. `Hive.box<T>` is the
      // synchronous accessor for an open box.
      () => UserLocalDataSourceImpl(
        pagesBox: Hive.box<CachedPageModel>(CacheConstants.usersPageBox),
        detailsBox: Hive.box<UserDetailModel>(CacheConstants.userDetailBox),
      ),
    );

  // -- Repository -----------------------------------------------------------
  sl.registerLazySingleton<UserRepository>(
    () => UserRepositoryImpl(
      remote: sl<UserRemoteDataSource>(),
      local: sl<UserLocalDataSource>(),
      networkInfo: sl<NetworkInfo>(),
    ),
  );

  // -- Use cases ------------------------------------------------------------
  sl
    ..registerLazySingleton<GetUsers>(() => GetUsers(sl<UserRepository>()))
    ..registerLazySingleton<GetUserDetail>(
      () => GetUserDetail(sl<UserRepository>()),
    )
    // Pure function, no dependencies -- a const instance is enough.
    ..registerLazySingleton<FilterUsers>(() => const FilterUsers());

  // -- Blocs ----------------------------------------------------------------
  sl
    ..registerFactory<UsersBloc>(
      () => UsersBloc(
        getUsers: sl<GetUsers>(),
        filterUsers: sl<FilterUsers>(),
      ),
    )
    ..registerFactory<UserDetailBloc>(
      () => UserDetailBloc(getUserDetail: sl<GetUserDetail>()),
    );
}

/// Tears everything down. Used between widget tests.
Future<void> resetDependencies() => sl.reset();
