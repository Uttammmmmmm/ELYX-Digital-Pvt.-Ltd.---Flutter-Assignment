/// The users contract. Declared by the domain, implemented by the data layer.
library;

import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/paginated_users.dart';
import '../entities/user_detail.dart';
import '../entities/user_summary.dart';

/// Access to GitHub users, from wherever the data layer chooses to get them.
///
/// Nothing in this file mentions HTTP, Dio, Hive, JSON or caching. Those are
/// the implementation's business; a caller only needs to know it will receive
/// either a [Failure] or the data.
abstract interface class UserRepository {
  /// Fetches one batch of users.
  ///
  /// OPAQUE CURSOR: [cursor] is whatever the previous batch reported as
  /// [PaginatedUsers.nextCursor]; passing null requests the first batch. Its
  /// MEANING belongs to the active source -- a page number for reqres.in, a
  /// user id for GitHub -- and callers must never inspect or arithmetic on
  /// it. Pages are reached by walking forward, which is why the UI offers
  /// infinite scroll rather than a numbered pager, and why a refresh restarts
  /// from the beginning instead of reloading "the current page".
  ///
  /// [perPage] is a hint; GitHub caps it at 100 and may return fewer.
  ///
  /// FORCE REFRESH: when false (the default) the implementation may answer
  /// from cache if what it holds is still fresh. When true it must bypass the
  /// cache ON READ and go to the network -- this is what pull-to-refresh
  /// passes, and without it a refresh could be served the very data the user
  /// is trying to replace. It does NOT disable writing to the cache: a forced
  /// fetch still updates it. Nor does it promise a network result: if the
  /// request fails, the implementation may still fall back to cached data
  /// rather than showing an error over nothing.
  Future<Either<Failure, PaginatedUsers>> getUsers({
    Object? cursor,
    int perPage,
    bool forceRefresh,
  });

  /// Fetches the full profile for [login].
  ///
  /// Keyed by [UserSummary.detailId], which each source populates with
  /// whatever its own detail endpoint accepts.
  /// This is the ONLY source of name, email, bio and location, and each call
  /// costs one of 60 hourly requests, so callers should invoke it on
  /// navigation and never prefetch it across a list.
  Future<Either<Failure, UserDetail>> getUserDetail(String detailId);

  /// Every user ever cached, across all batches, deduplicated and in order.
  ///
  /// Seeds the list on a cold start so search covers everything previously
  /// loaded rather than only this session's pages -- which is what makes
  /// offline search useful rather than nominal. Deliberately NOT `Either`: an
  /// empty result and a read failure both mean "nothing to seed with", and
  /// neither is worth an error path.
  Future<List<UserSummary>> getCachedUsers();
}
