/// Where users data comes from, and what happens when it cannot be fetched.
library;

import 'package:dartz/dartz.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/constants/cache_constants.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/paginated_users.dart';
import '../../domain/entities/user_detail.dart';
import '../../domain/repositories/user_repository.dart';
import '../datasources/user_local_data_source.dart';
import '../datasources/user_remote_data_source.dart';
import '../models/cached_page_model.dart';
import '../models/user_detail_model.dart';

/// [UserRepository] backed by GitHub plus a Hive cache.
///
/// ============================================================================
/// DECISION ORDER for [getUsers] -- evaluated top to bottom, first match wins:
///
///   1. forceRefresh == true
///        -> go remote. On success, overwrite the cached batch and return it.
///           On failure, fall through to the stale-cache fallback (5) rather
///           than punishing a pull-to-refresh with an error screen.
///
///   2. fresh cache hit (cached and within pagesTtl)
///        -> return the cache. NO network call at all. This is the branch
///           that protects the 60 requests/hour budget.
///
///   3. offline (connectivity reports no interface)
///        -> return cached data if ANY exists, at ANY age. Only when the
///           cache is empty does this become NetworkFailure.
///           Never fail while usable data is sitting on disk.
///
///   4. stale cache + online
///        -> go remote to refresh it.
///
///   5. remote failed (from 1 or 4)
///        -> fall back to the stale cache if there is one, rather than
///           surfacing the error. A rate-limited or flaky network should
///           degrade to old data, not to a blank screen. Only with no cache
///           does the mapped Failure reach the caller.
///
///   6. remote succeeded
///        -> write to cache, then return.
///
///   7. empty batch from a successful request
///        -> a PaginatedUsers with hasReachedEnd == true. This is the normal
///           end of the list, NOT a failure. Returning a Failure here would
///           make reaching the end of GitHub look like an outage.
/// ============================================================================
///
/// [getUserDetail] follows the same shape with a 6-hour TTL, minus the
/// force-refresh branch, which its contract does not expose.
///
/// This is also the boundary where [AppException] becomes [Failure]: every
/// path is wrapped, so no transport exception escapes into the domain.
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
    final CachedPageModel? cached = _local.getCachedUsersPage(since);

    // (2) Fresh cache hit -- answered without touching the network.
    if (!forceRefresh &&
        cached != null &&
        !cached.isStale(CacheConstants.pagesTtl)) {
      return Right<Failure, PaginatedUsers>(cached.toEntity());
    }

    // (3) Offline. Serve whatever is on disk regardless of age; only an
    //     empty cache is a failure.
    if (!await _network.isConnected) {
      if (cached != null) {
        return Right<Failure, PaginatedUsers>(cached.toEntity());
      }
      return const Left<Failure, PaginatedUsers>(NetworkFailure());
    }

    // (1) and (4) both arrive here: go remote.
    try {
      final PaginatedUsers page =
          await _remote.getUsers(since: since, perPage: perPage);

      // (6) and (7). An empty batch is cached and returned like any other --
      //     `hasReachedEnd` is already true on it, and that is a fact worth
      //     remembering so the end of the list is not rediscovered by
      //     spending another request.
      await _local.cacheUsersPage(since, page);
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
  Future<Either<Failure, UserDetail>> getUserDetail(String login) async {
    final UserDetailModel? cached = _local.getCachedUserDetail(login);

    // Fresh cache hit.
    if (cached != null && !cached.isStale(CacheConstants.detailsTtl)) {
      return Right<Failure, UserDetail>(cached);
    }

    // Offline: any cached copy beats an error.
    if (!await _network.isConnected) {
      if (cached != null) return Right<Failure, UserDetail>(cached);
      return const Left<Failure, UserDetail>(NetworkFailure());
    }

    try {
      final UserDetailModel detail = await _remote.getUserDetail(login);
      await _local.cacheUserDetail(detail);
      return Right<Failure, UserDetail>(detail);
    } on NotFoundException {
      // The one failure that must NOT fall back to cache: a 404 is
      // authoritative. The account is gone, so the cached copy is now wrong,
      // and showing it would be showing a user who no longer exists.
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
}
