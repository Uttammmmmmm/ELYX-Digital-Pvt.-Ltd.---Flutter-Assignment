library;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get_it/get_it.dart';

import '../../features/users/data/datasources/user_local_data_source.dart';
import '../../features/users/data/datasources/api/api_source.dart';
import '../../features/users/data/datasources/api/github_users_api.dart';
import '../../features/users/data/datasources/api/link_header_parser.dart';
import '../../features/users/data/datasources/api/reqres_users_api.dart';
import '../../features/users/data/datasources/api/users_api.dart';
import '../../features/users/data/repositories/user_repository_impl.dart';
import '../../features/users/domain/entities/user_summary.dart';
import '../../features/users/domain/repositories/user_repository.dart';
import '../../features/users/domain/usecases/filter_users.dart';
import '../../features/users/domain/usecases/get_user_detail.dart';
import '../../features/users/domain/usecases/get_users.dart';
import '../../features/users/presentation/bloc/user_detail_bloc.dart';
import '../../features/users/presentation/bloc/users_bloc.dart';
import '../network/dio_client.dart';
import '../observability/error_reporter.dart';
import '../network/network_info.dart';
import '../network/rate_limit_tracker.dart';
import '../storage/hive_initializer.dart';

final GetIt sl = GetIt.instance;

Future<void> init({
  required HiveBoxes boxes,
  ErrorReporter reporter = const NoopErrorReporter(),
}) async {
  if (sl.isRegistered<UserRepository>()) return;

  sl
    ..registerLazySingleton<RateLimitTracker>(RateLimitTracker.new)
    ..registerLazySingleton<Connectivity>(Connectivity.new)
    ..registerSingleton<HiveBoxes>(boxes)
    ..registerSingleton<ErrorReporter>(reporter);

  sl
    ..registerLazySingleton<NetworkInfo>(
      () => NetworkInfoImpl(sl<Connectivity>()),
    )
    ..registerLazySingleton<LinkHeaderParser>(LinkHeaderParser.new);

  sl
    ..registerLazySingleton<ApiSourceConfig>(
      () => ApiSource.fromName(kApiSource).config(reqresApiKey: kReqresApiKey),
    )
    ..registerLazySingleton<DioClient>(
      () => DioClient(
        rateLimitTracker: sl<RateLimitTracker>(),
        baseUrl: sl<ApiSourceConfig>().baseUrl,
        headers: sl<ApiSourceConfig>().headers,
      ),
    )
    ..registerLazySingleton<UsersApi>(_buildUsersApi);

  sl.registerLazySingleton<UserLocalDataSource>(
    () => UserLocalDataSourceImpl(
      pagesBox: sl<HiveBoxes>().pages,
      detailsBox: sl<HiveBoxes>().details,
    ),
  );

  sl.registerLazySingleton<UserRepository>(
    () => UserRepositoryImpl(
      api: sl<UsersApi>(),
      local: sl<UserLocalDataSource>(),
      networkInfo: sl<NetworkInfo>(),
      reporter: sl<ErrorReporter>(),
    ),
  );

  sl
    ..registerLazySingleton<GetUsers>(() => GetUsers(sl<UserRepository>()))
    ..registerLazySingleton<GetUserDetail>(
      () => GetUserDetail(sl<UserRepository>()),
    )
    ..registerLazySingleton<FilterUsers>(() => const FilterUsers());

  sl
    ..registerFactory<UsersBloc>(
      () => UsersBloc(
        getUsers: sl<GetUsers>(),
        filterUsers: sl<FilterUsers>(),
        repository: sl<UserRepository>(),
      ),
    )
    ..registerFactoryParam<UserDetailBloc, UserSummary, void>(
      (UserSummary seed, _) =>
          UserDetailBloc(getUserDetail: sl<GetUserDetail>(), seed: seed),
    );
}

const String kApiSource = String.fromEnvironment(
  'API_SOURCE',
  defaultValue: 'github',
);

UsersApi _buildUsersApi() => switch (kApiSource.toLowerCase()) {
  'reqres' => ReqresUsersApi(
    client: sl<DioClient>(),
    apiKey: const String.fromEnvironment(
      ReqresUsersApi.apiKeyDefine,
      defaultValue: ReqresUsersApi.defaultApiKey,
    ),
  ),
  _ => GitHubUsersApi(
    client: sl<DioClient>(),
    linkHeaderParser: sl<LinkHeaderParser>(),
  ),
};

Future<void> resetDependencies() => sl.reset();
