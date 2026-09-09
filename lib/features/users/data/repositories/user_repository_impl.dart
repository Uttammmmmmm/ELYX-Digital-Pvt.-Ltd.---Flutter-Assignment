library;

import 'package:dartz/dartz.dart';

import '../../../../core/constants/cache_constants.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/observability/error_reporter.dart';
import '../../domain/entities/paginated_users.dart';
import '../../domain/entities/user_detail.dart';
import '../../domain/entities/user_summary.dart';
import '../../domain/repositories/user_repository.dart';
import '../datasources/api/users_api.dart';
import '../datasources/user_local_data_source.dart';
import '../models/cached_page_model.dart';
import '../models/user_detail_model.dart';

class UserRepositoryImpl implements UserRepository {
  const UserRepositoryImpl({
    required UsersApi api,
    required UserLocalDataSource local,
    required NetworkInfo networkInfo,
    ErrorReporter reporter = const NoopErrorReporter(),
  }) : _api = api,
       _local = local,
       _network = networkInfo,
       _reporter = reporter;

  final UsersApi _api;
  final UserLocalDataSource _local;
  final NetworkInfo _network;
  final ErrorReporter _reporter;

  @override
  Future<Either<Failure, PaginatedUsers>> getUsers({
    Object? cursor,
    int perPage = 10,
    bool forceRefresh = false,
  }) async {
    if (forceRefresh) await _local.clearUsersPages();

    final CachedPageModel? cached = forceRefresh
        ? null
        : _local.getCachedUsersPage(cursor);

    if (cached != null && !cached.isStale(CacheConstants.pagesTtl)) {
      return Right<Failure, PaginatedUsers>(cached.toEntity());
    }

    if (!await _network.isConnected) {
      if (cached != null) {
        return Right<Failure, PaginatedUsers>(cached.toEntity());
      }
      return const Left<Failure, PaginatedUsers>(NetworkFailure());
    }

    try {
      final PaginatedUsers page = await _api.fetchUsers(
        cursor: cursor,
        perPage: perPage,
      );

      await _local.cacheUsersPage(cursor, page);
      return Right<Failure, PaginatedUsers>(page);
    } on AppException catch (e) {
      if (cached != null) {
        return Right<Failure, PaginatedUsers>(cached.toEntity());
      }
      return Left<Failure, PaginatedUsers>(failureFromException(e));
    } catch (e, stack) {
      _reporter.recordError(e, stack, context: 'repository.getUsers');
      if (cached != null) {
        return Right<Failure, PaginatedUsers>(cached.toEntity());
      }
      return Left<Failure, PaginatedUsers>(
        ServerFailure('Unexpected error loading users: $e'),
      );
    }
  }

  @override
  Future<Either<Failure, UserDetail>> getUserDetail(String detailId) async {
    final UserDetailModel? cached = _local.getCachedUserDetail(detailId);

    if (cached != null && !cached.isStale(CacheConstants.detailsTtl)) {
      return Right<Failure, UserDetail>(cached);
    }

    if (!await _network.isConnected) {
      if (cached != null) return Right<Failure, UserDetail>(cached);
      return const Left<Failure, UserDetail>(NetworkFailure());
    }

    try {
      final UserDetail detail = await _api.fetchUserDetail(detailId);
      await _local.cacheUserDetail(detail);
      return Right<Failure, UserDetail>(detail);
    } on NotFoundException {
      return const Left<Failure, UserDetail>(NotFoundFailure());
    } on AppException catch (e) {
      if (cached != null) return Right<Failure, UserDetail>(cached);
      return Left<Failure, UserDetail>(failureFromException(e));
    } catch (e, stack) {
      _reporter.recordError(e, stack, context: 'repository.getUserDetail');
      if (cached != null) return Right<Failure, UserDetail>(cached);
      return Left<Failure, UserDetail>(
        ServerFailure('Unexpected error loading profile: $e'),
      );
    }
  }

  @override
  Future<List<UserSummary>> getCachedUsers() async {
    try {
      return _local.getAllCachedUsers();
    } on Object {
      return const <UserSummary>[];
    }
  }
}
