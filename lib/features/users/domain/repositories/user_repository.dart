/// The users contract. Declared by the domain, implemented by the data layer.
library;

import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/paginated_users.dart';
import '../entities/user_detail.dart';

/// Access to GitHub users, from wherever the data layer chooses to get them.
///
/// Nothing in this file mentions HTTP, Dio, Hive, JSON or caching. Those are
/// the implementation's business; a caller only needs to know it will receive
/// either a [Failure] or the data.
abstract interface class UserRepository {
  /// Fetches one batch of users.
  ///
  /// CURSOR, NOT PAGE INDEX: [since] is an opaque cursor obtained from a
  /// previous [PaginatedUsers.nextSince]; passing null requests the first
  /// batch. Callers therefore CANNOT jump to an arbitrary page -- there is no
  /// "page 7". Pages are only reachable by walking forward from the start,
  /// one request at a time, which is why the UI offers infinite scroll rather
  /// than a numbered pager, and why a refresh restarts from the beginning
  /// instead of reloading "the current page".
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
    int? since,
    int perPage,
    bool forceRefresh,
  });

  /// Fetches the full profile for [login].
  ///
  /// Keyed by login, not numeric id -- that is what the endpoint accepts.
  /// This is the ONLY source of name, email, bio and location, and each call
  /// costs one of 60 hourly requests, so callers should invoke it on
  /// navigation and never prefetch it across a list.
  Future<Either<Failure, UserDetail>> getUserDetail(String login);
}
