/// Dependency wiring.
library;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get_it/get_it.dart';

import '../../features/users/data/datasources/user_local_data_source.dart';
import '../../features/users/data/datasources/user_remote_data_source.dart';
import '../../features/users/data/repositories/user_repository_impl.dart';
import '../../features/users/domain/repositories/user_repository.dart';
import '../../features/users/domain/usecases/filter_users.dart';
import '../../features/users/domain/usecases/get_user_detail.dart';
import '../../features/users/domain/usecases/get_users.dart';
import '../../features/users/presentation/bloc/user_detail_bloc.dart';
import '../../features/users/presentation/bloc/users_bloc.dart';
import '../network/dio_client.dart';
import '../network/link_header_parser.dart';
import '../network/network_info.dart';
import '../network/rate_limit_tracker.dart';
import '../storage/hive_initializer.dart';

/// The service locator.
final GetIt sl = GetIt.instance;

/// Registers every dependency.
///
/// WHY THE ORDER MATTERS
/// GetIt resolves lazily, so a *registration* may reference a type that is not
/// registered yet -- the factory closure does not run until first use. The
/// order below is therefore not a technical requirement of GetIt; it is a
/// requirement of being able to read the file. Registering outside-in
/// (External -> Core -> DataSources -> Repository -> UseCases -> Bloc) means
/// every closure only refers to things already declared above it, so the file
/// reads as the dependency graph itself and a cycle becomes visible as a
/// backwards reference. Two places where order IS load-bearing:
///
///  - [HiveBoxes] must already be open. They are passed in rather than opened
///    here, because opening is async and a `registerSingleton` needs a value
///    NOW. This is also why boxes use `registerSingleton` and never
///    `registerLazySingleton`: you cannot `await` inside a lazy factory, so a
///    lazy box registration would have to hand out a `Future<Box>` and every
///    consumer would become async for no reason.
///  - [RateLimitTracker] must be a single instance shared by the interceptor
///    and the UI. Two trackers would each see half the responses and the app's
///    view of its own quota would be silently wrong.
///
/// Idempotent: safe to call twice (hot restart, or a test that re-initialises).
Future<void> init({required HiveBoxes boxes}) async {
  // Hot restart re-runs main(); a second registration would throw. Bailing
  // out is correct rather than merely convenient -- the graph is stateless
  // apart from the tracker and the boxes, both of which are still valid.
  if (sl.isRegistered<UserRepository>()) return;

  // ---------------------------------------------------------------------
  // External -- things the app does not implement.
  // ---------------------------------------------------------------------
  sl
    ..registerLazySingleton<RateLimitTracker>(RateLimitTracker.new)
    // One Dio for the process: it owns the connection pool and the
    // interceptor chain, both of which are wasteful to duplicate.
    ..registerLazySingleton<DioClient>(
      () => DioClient(rateLimitTracker: sl<RateLimitTracker>()),
    )
    ..registerLazySingleton<Connectivity>(Connectivity.new)
    // Already-open boxes: a concrete instance, so registerSingleton, not lazy.
    ..registerSingleton<HiveBoxes>(boxes);

  // ---------------------------------------------------------------------
  // Core -- stateless infrastructure. All lazy: nothing is built until
  // something asks, and a screen the user never opens costs nothing.
  // ---------------------------------------------------------------------
  sl
    ..registerLazySingleton<NetworkInfo>(
      () => NetworkInfoImpl(sl<Connectivity>()),
    )
    ..registerLazySingleton<LinkHeaderParser>(LinkHeaderParser.new);

  // ---------------------------------------------------------------------
  // Data sources -- registered against their abstract types, so a fake can
  // be substituted in tests without touching anything downstream.
  // ---------------------------------------------------------------------
  sl
    ..registerLazySingleton<UserRemoteDataSource>(
      () => UserRemoteDataSourceImpl(
        client: sl<DioClient>(),
        linkHeaderParser: sl<LinkHeaderParser>(),
      ),
    )
    ..registerLazySingleton<UserLocalDataSource>(
      () => UserLocalDataSourceImpl(
        pagesBox: sl<HiveBoxes>().pages,
        detailsBox: sl<HiveBoxes>().details,
      ),
    );

  // ---------------------------------------------------------------------
  // Repository -- registered as the ABSTRACT UserRepository, never as
  // UserRepositoryImpl. Consumers resolve the contract the domain declares,
  // so the implementation can be swapped (or mocked) without a single
  // consumer changing, and nothing above the data layer can accidentally
  // reach for an impl-only member.
  // ---------------------------------------------------------------------
  sl.registerLazySingleton<UserRepository>(
    () => UserRepositoryImpl(
      remote: sl<UserRemoteDataSource>(),
      local: sl<UserLocalDataSource>(),
      networkInfo: sl<NetworkInfo>(),
    ),
  );

  // ---------------------------------------------------------------------
  // Use cases -- stateless, so lazy singletons. FilterUsers has no
  // dependencies at all and is a const instance.
  // ---------------------------------------------------------------------
  sl
    ..registerLazySingleton<GetUsers>(() => GetUsers(sl<UserRepository>()))
    ..registerLazySingleton<GetUserDetail>(
      () => GetUserDetail(sl<UserRepository>()),
    )
    ..registerLazySingleton<FilterUsers>(() => const FilterUsers());

  // ---------------------------------------------------------------------
  // Blocs -- registerFactory, NEVER a singleton.
  //
  // This is the answer to the brief's back-navigation / memory-leak
  // scenario. A Bloc owns a StreamController and event-transformer
  // subscriptions. As a singleton it would be created once and closed by
  // whichever screen was disposed FIRST -- after which every later screen
  // would push events into a closed controller and throw, while the state
  // from the previous visit leaked into the next one. As a factory, each
  // BlocProvider builds its own instance and disposes it on pop: state does
  // not survive back navigation, and nothing outlives the widget that owns
  // it.
  // ---------------------------------------------------------------------
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

/// Tears the graph down. Used between tests.
Future<void> resetDependencies() => sl.reset();
