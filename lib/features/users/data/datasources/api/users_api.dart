/// The contract every supported users backend implements.
library;

import '../../../domain/entities/paginated_users.dart';
import '../../../domain/entities/user_detail.dart';

/// One users backend.
///
/// WHY THIS EXISTS. The assignment brief's TEXT names `reqres.in`, while its
/// HYPERLINKS resolve to `api.github.com`. Rather than guess, both are
/// implemented behind this interface and selected at build time. That is also
/// the honest architectural answer: "which host" is exactly the kind of
/// detail the domain must not depend on.
///
/// Implementations own their pagination scheme, their auth header and their
/// JSON shape, and return domain entities. Nothing source-specific escapes:
/// the cursor is `Object?`, the entities are the union of both shapes.
///
/// Implementations throw `AppException` subtypes; they never return `Either`.
/// Exceptions in, `Either` out at the repository boundary.
abstract interface class UsersApi {
  /// Human-readable source name, for logs and the about screen.
  String get sourceName;

  /// Root URL for this source.
  String get baseUrl;

  /// Headers sent on every request to this source.
  Map<String, String> get headers;

  /// One batch of users.
  ///
  /// [cursor] is whatever this implementation put in
  /// [PaginatedUsers.nextCursor] last time; null requests the first batch.
  Future<PaginatedUsers> fetchUsers({Object? cursor, int perPage});

  /// One user's full profile, keyed by [UserSummary.detailId].
  Future<UserDetail> fetchUserDetail(String id);
}
