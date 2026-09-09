/// The cache-vs-network policy for users data.
library;

import 'package:dartz/dartz.dart';

import '../../../../core/constants/cache_constants.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/models/sourced.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/storage/cache_entry.dart';
import '../../domain/entities/github_user_detail.dart';
import '../../domain/entities/users_page.dart';
import '../../domain/repositories/user_repository.dart';
import '../datasources/user_local_data_source.dart';
import '../datasources/user_remote_data_source.dart';
import '../models/github_user_detail_model.dart';
import '../models/users_page_model.dart';

/// [UserRepository] backed by GitHub plus a Hive cache.
///
/// This is the only class that decides *where* data comes from. The policy,
/// applied identically to lists and details:
///
///   1. Fresh cache (within TTL) and no force-refresh -> serve it, no request.
///   2. Offline -> serve cache at any age; only fail if there is none.
///   3. Online -> fetch, cache, serve.
///   4. Request failed -> fall back to cache at any age, tagged as cached so
///      the UI can say so; only surface the failure when the cache is empty.
///
/// Step 4 is what makes a spent rate limit survivable: 60 requests/hour is
/// easy to exhaust, and stale data plus a banner beats an error screen.
/// It also converts [AppException] into [Failure], which is the point at which
/// transport concerns stop and the domain begins.
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
  Future<Either<Failure, Sourced<UsersPage>>> getUsers({
    int? cursor,
    bool forceRefresh = false,
  }) async {
    final CacheEntry<UsersPageModel>? cached = _local.readUsersPage(cursor);

    if (!forceRefresh &&
        cached != null &&
        !cached.isStale(CacheConstants.usersPageTtl)) {
      return Right<Failure, Sourced<UsersPage>>(
        Sourced<UsersPage>.cache(cached.value, cached.cachedAt),
      );
    }

    // Cheap pre-check only: connectivity reports interface availability, not
    // reachability, so a "connected" device can still fail below.
    if (!await _network.isConnected) {
      return _fallback<UsersPage>(cached, const NetworkFailure());
    }

    try {
      final UsersPageModel page = await _remote.getUsers(since: cursor);
      await _local.cacheUsersPage(cursor, page);
      return Right<Failure, Sourced<UsersPage>>(Sourced<UsersPage>.network(page));
    } on AppException catch (e) {
      return _fallback<UsersPage>(cached, failureFromException(e));
    }
  }

  @override
  Future<Either<Failure, Sourced<GithubUserDetail>>> getUserDetail(
    String login, {
    bool forceRefresh = false,
  }) async {
    final CacheEntry<GithubUserDetailModel>? cached =
        _local.readUserDetail(login);

    if (!forceRefresh &&
        cached != null &&
        !cached.isStale(CacheConstants.userDetailTtl)) {
      return Right<Failure, Sourced<GithubUserDetail>>(
        Sourced<GithubUserDetail>.cache(cached.value, cached.cachedAt),
      );
    }

    if (!await _network.isConnected) {
      return _fallback<GithubUserDetail>(cached, const NetworkFailure());
    }

    try {
      final GithubUserDetailModel detail = await _remote.getUserDetail(login);
      await _local.cacheUserDetail(detail);
      return Right<Failure, Sourced<GithubUserDetail>>(
        Sourced<GithubUserDetail>.network(detail),
      );
    } on AppException catch (e) {
      // A 404 is authoritative: the account is gone, so any cached copy is
      // now wrong and must not be served as a fallback.
      if (e is NotFoundException) {
        return const Left<Failure, Sourced<GithubUserDetail>>(
          NotFoundFailure(),
        );
      }
      return _fallback<GithubUserDetail>(cached, failureFromException(e));
    }
  }

  @override
  Future<Map<String, String>> cachedDisplayNames() async {
    try {
      return _local.displayNames();
    } on Object {
      // Degraded search (login-only) is an acceptable outcome; an error is not.
      return const <String, String>{};
    }
  }

  @override
  Future<void> clearUsersCache() => _local.clearUsersPages();

  /// Serves [cached] at any age when the network path failed, otherwise
  /// surfaces [failure].
  Either<Failure, Sourced<T>> _fallback<T>(
    CacheEntry<T>? cached,
    Failure failure,
  ) {
    if (cached == null) return Left<Failure, Sourced<T>>(failure);
    return Right<Failure, Sourced<T>>(
      Sourced<T>.cache(cached.value, cached.cachedAt),
    );
  }
}
