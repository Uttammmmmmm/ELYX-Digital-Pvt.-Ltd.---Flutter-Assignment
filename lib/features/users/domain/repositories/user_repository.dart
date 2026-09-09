/// The contract the domain needs; the data layer implements it.
library;

import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/models/sourced.dart';
import '../entities/github_user_detail.dart';
import '../entities/users_page.dart';

/// Access to GitHub users, from network or cache.
///
/// Declared here -- in the layer that *consumes* it, not the one that
/// implements it -- so the dependency arrow points inward. Nothing in this file
/// mentions HTTP, Hive, or Dio.
abstract interface class UserRepository {
  /// Fetches one page of users starting after [cursor].
  ///
  /// [cursor] is the opaque token from a previous [UsersPage.nextCursor];
  /// null requests the first page. When [forceRefresh] is true the cache is
  /// bypassed on the way in (it is still written on the way out).
  /// Returns a [Sourced] result so callers can tell a live page from a cached
  /// one served during an outage or a rate-limit block.
  Future<Either<Failure, Sourced<UsersPage>>> getUsers({
    int? cursor,
    bool forceRefresh = false,
  });

  /// Fetches the full profile for [login].
  Future<Either<Failure, Sourced<GithubUserDetail>>> getUserDetail(
    String login, {
    bool forceRefresh = false,
  });

  /// Best-effort `login -> name` index assembled from cached detail documents.
  ///
  /// Constraint (e): the list endpoint carries no names, so client-side search
  /// can only match names for users whose detail has already been fetched.
  /// Deliberately NOT `Either` -- a failure here degrades search to
  /// login-only, which is not worth an error path.
  Future<Map<String, String>> cachedDisplayNames();

  /// Drops cached list pages. Used by pull-to-refresh so a re-fetch cannot be
  /// served stale data. Detail documents are left alone -- they are expensive
  /// to rebuild and rarely wrong.
  Future<void> clearUsersCache();
}
