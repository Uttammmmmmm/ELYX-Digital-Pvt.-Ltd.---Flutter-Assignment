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
    // Read the cached batch up front even on a forced refresh. It is the
    // offline fallback, and discarding it before we know a replacement is
    // obtainable would let a pull-to-refresh in airplane mode wipe the only
    // copy of the data the user can still be shown.
    final CachedPageModel? cached = _local.getCachedUsersPage(cursor);

    // A forced refresh never serves the cache, however fresh it looks.
    if (!forceRefresh &&
        cached != null &&
        !cached.isStale(CacheConstants.pagesTtl)) {
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

      // Invalidate only once the replacement is in hand. Later batches must
      // still be dropped -- keeping them would let the user scroll straight
      // back into pre-refresh rows -- but not a moment before the new first
      // batch exists to replace them.
      if (forceRefresh) await _local.clearUsersPages();

      await _local.cacheUsersPage(cursor, page);
      return Right<Failure, PaginatedUsers>(page);
    } on AppException catch (e) {
      return _pageFallback(cached, forceRefresh: forceRefresh) ??
          Left<Failure, PaginatedUsers>(failureFromException(e));
    } catch (e, stack) {
      _reporter.recordError(e, stack, context: 'repository.getUsers');
      return _pageFallback(cached, forceRefresh: forceRefresh) ??
          Left<Failure, PaginatedUsers>(
            ServerFailure('Unexpected error loading users: $e'),
          );
    }
  }

  /// Stale-cache fallback for a failed fetch, or `null` when the failure
  /// should surface instead.
  ///
  /// A forced refresh reports its failure rather than silently re-serving the
  /// rows the user just asked to replace: the Bloc keeps the existing list on
  /// screen and adds an error, which is honest about what happened. A
  /// background read has no such gesture behind it, so stale data beats an
  /// error page.
  Either<Failure, PaginatedUsers>? _pageFallback(
    CachedPageModel? cached, {
    required bool forceRefresh,
  }) => (!forceRefresh && cached != null)
      ? Right<Failure, PaginatedUsers>(cached.toEntity())
      : null;

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
