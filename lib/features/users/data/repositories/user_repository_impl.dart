/// The cache-vs-network policy for users data.
library;

import 'package:dartz/dartz.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/constants/cache_constants.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/storage/cache_entry.dart';
import '../../domain/entities/paginated_users.dart';
import '../../domain/entities/user_detail.dart';
import '../../domain/repositories/user_repository.dart';
import '../datasources/user_local_data_source.dart';
import '../datasources/user_remote_data_source.dart';
import '../models/paginated_users_model.dart';
import '../models/user_detail_model.dart';

/// [UserRepository] backed by GitHub plus a Hive cache.
///
/// The only class that decides WHERE data comes from. The policy, applied
/// identically to batches and details:
///
///   1. Fresh cache (within TTL) and no force-refresh -> serve it, no request.
///   2. Offline -> serve cache at any age; fail only if there is none.
///   3. Online -> fetch, cache, serve.
///   4. Request failed -> fall back to cache at any age; surface the failure
///      only when the cache is empty.
///
/// Step 4 is what makes a spent rate limit survivable: 60 requests/hour is
/// easy to exhaust, and stale data beats an error screen. It also converts
/// [AppException] into [Failure] -- the point where transport concerns stop
/// and the domain begins.
class UserRepositoryImpl implements UserRepository {
  const UserRepositoryImpl({
    required UserRemoteDataSource remote,
    required UserLocalDataSource local,
    required NetworkInfo networkInfo,
  })  : _remote = remote,
        _local = local,
        _network = networkInfo;

  final UserRemoteDataSource _remote;
  final UserLocalDataSource _local;
  final NetworkInfo _network;

  @override
  Future<Either<Failure, PaginatedUsers>> getUsers({
    int? since,
    int perPage = ApiConstants.defaultPerPage,
    bool forceRefresh = false,
  }) async {
    final CacheEntry<PaginatedUsersModel>? cached = _local.readUsersPage(since);

    if (!forceRefresh &&
        cached != null &&
        !cached.isStale(CacheConstants.usersPageTtl)) {
      return Right<Failure, PaginatedUsers>(cached.value);
    }

    // A forced refresh must not be answerable from the very data the user is
    // trying to replace, so the stored batches go first.
    if (forceRefresh) await _local.clearUsersPages();

    // Cheap pre-check only: connectivity reports interface availability, not
    // reachability, so a "connected" device can still fail below.
    if (!await _network.isConnected) {
      return _fallback<PaginatedUsers>(cached, const NetworkFailure());
    }

    try {
      final PaginatedUsersModel page =
          await _remote.getUsers(since: since, perPage: perPage);
      await _local.cacheUsersPage(since, page);
      return Right<Failure, PaginatedUsers>(page);
    } on AppException catch (e) {
      return _fallback<PaginatedUsers>(cached, failureFromException(e));
    }
  }

  @override
  Future<Either<Failure, UserDetail>> getUserDetail(String login) async {
    final CacheEntry<UserDetailModel>? cached = _local.readUserDetail(login);

    if (cached != null && !cached.isStale(CacheConstants.userDetailTtl)) {
      return Right<Failure, UserDetail>(cached.value);
    }

    if (!await _network.isConnected) {
      return _fallback<UserDetail>(cached, const NetworkFailure());
    }

    try {
      final UserDetailModel detail = await _remote.getUserDetail(login);
      await _local.cacheUserDetail(detail);
      return Right<Failure, UserDetail>(detail);
    } on AppException catch (e) {
      // A 404 is authoritative: the account is gone, so any cached copy is
      // now wrong and must not be served as a fallback.
      if (e is NotFoundException) {
        return const Left<Failure, UserDetail>(NotFoundFailure());
      }
      return _fallback<UserDetail>(cached, failureFromException(e));
    }
  }

  /// Serves [cached] at any age when the network path failed, otherwise
  /// surfaces [failure].
  Either<Failure, T> _fallback<T>(CacheEntry<T>? cached, Failure failure) {
    if (cached == null) return Left<Failure, T>(failure);
    return Right<Failure, T>(cached.value);
  }
}
