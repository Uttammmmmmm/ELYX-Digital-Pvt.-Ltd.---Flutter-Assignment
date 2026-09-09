/// Where users data comes from, and what happens when it cannot be fetched.
library;

import 'package:dartz/dartz.dart';

import '../../../../core/constants/cache_constants.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/paginated_users.dart';
import '../../domain/entities/user_detail.dart';
import '../../domain/entities/user_summary.dart';
import '../../domain/repositories/user_repository.dart';
import '../datasources/api/users_api.dart';
import '../datasources/user_local_data_source.dart';
import '../models/cached_page_model.dart';
import '../models/user_detail_model.dart';

/// [UserRepository] backed by the active [UsersApi] plus a Hive cache.
///
/// ============================================================================
/// DECISION ORDER for [getUsers] -- evaluated top to bottom, first match wins:
///
///   1. forceRefresh == true
///        -> INVALIDATE every cached batch first, then go remote. Clearing is
///           not optional: overwriting only the requested batch leaves later
///           pages holding pre-refresh data, and within the 15-minute TTL the
///           user scrolls straight back into the stale rows they just pulled
///           to replace.
///
///   2. fresh cache hit (cached and within pagesTtl)
///        -> return the cache. NO network call at all.
///
///   3. offline (connectivity reports no interface)
///        -> return cached data if ANY exists, at ANY age. Only when the
///           cache is empty does this become NetworkFailure.
///
///   4. stale cache + online
///        -> go remote to refresh it.
///
///   5. remote failed (from 1 or 4)
///        -> fall back to the stale cache if there is one. A rate-limited or
///           flaky network should degrade to old data, not a blank screen.
///
///   6. remote succeeded
///        -> write to cache, then return.
///
///   7. empty batch from a successful request
///        -> PaginatedUsers with hasReachedEnd == true. The normal end of the
///           list, NOT a failure.
/// ============================================================================
///
/// This is also the boundary where [AppException] becomes [Failure].
class UserRepositoryImpl implements UserRepository {
  const UserRepositoryImpl({
    required UsersApi api,
    required UserLocalDataSource local,
    required NetworkInfo networkInfo,
  })  : _api = api,
        _local = local,
        _network = networkInfo;

  final UsersApi _api;
  final UserLocalDataSource _local;
  final NetworkInfo _network;

  @override
  Future<Either<Failure, PaginatedUsers>> getUsers({
    Object? cursor,
    int perPage = 10,
    bool forceRefresh = false,
  }) async {
    // (1) A forced refresh must not be answerable from the very data it is
    //     replacing -- neither this batch nor any later one.
    if (forceRefresh) await _local.clearUsersPages();

    final CachedPageModel? cached =
        forceRefresh ? null : _local.getCachedUsersPage(cursor);

    // (2) Fresh cache hit -- answered without touching the network.
    if (cached != null && !cached.isStale(CacheConstants.pagesTtl)) {
      return Right<Failure, PaginatedUsers>(cached.toEntity());
    }

    // (3) Offline. Serve whatever is on disk regardless of age.
    if (!await _network.isConnected) {
      if (cached != null) {
        return Right<Failure, PaginatedUsers>(cached.toEntity());
      }
      return const Left<Failure, PaginatedUsers>(NetworkFailure());
    }

    try {
      final PaginatedUsers page =
          await _api.fetchUsers(cursor: cursor, perPage: perPage);

      // (6) and (7). An empty batch is cached like any other -- its
      //     `hasReachedEnd` is already true, and remembering that avoids
      //     spending a request to rediscover the end.
      await _local.cacheUsersPage(cursor, page);
      return Right<Failure, PaginatedUsers>(page);
    } on AppException catch (e) {
      // (5) Remote failed. Stale data beats an error screen.
      if (cached != null) {
        return Right<Failure, PaginatedUsers>(cached.toEntity());
      }
      return Left<Failure, PaginatedUsers>(failureFromException(e));
    } catch (e) {
      // Nothing should reach here -- DioClient maps everything to
      // AppException -- but an un-mapped throw must not escape the data layer
      // as a raw exception and crash a Bloc.
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
      // The one failure that must NOT fall back to cache: a 404 is
      // authoritative. The account is gone, so the cached copy is now wrong.
      return const Left<Failure, UserDetail>(NotFoundFailure());
    } on AppException catch (e) {
      if (cached != null) return Right<Failure, UserDetail>(cached);
      return Left<Failure, UserDetail>(failureFromException(e));
    } catch (e) {
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
      // A degraded seed (an empty list) is an acceptable outcome; throwing
      // out of a cold start is not.
      return const <UserSummary>[];
    }
  }
}
