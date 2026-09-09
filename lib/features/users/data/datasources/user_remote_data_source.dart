/// Network access to the GitHub users endpoints.
library;

import '../../../../core/constants/api_constants.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_response.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/link_header_parser.dart';
import '../../domain/entities/paginated_users.dart';
import '../models/user_detail_model.dart';
import '../models/user_summary_model.dart';

/// Fetches users from GitHub.
///
/// Throws [AppException] subtypes; it returns no `Either`. Exceptions in,
/// `Either` out at the repository boundary -- a data source has no vocabulary
/// for "failure as a value", and giving it one would duplicate the mapping
/// the repository already owns.
abstract interface class UserRemoteDataSource {
  /// One batch of users after the [since] cursor; null requests the first.
  ///
  /// Returns the parsed users AND the next cursor, read from the `Link`
  /// header -- the body alone cannot tell you whether more pages exist.
  Future<PaginatedUsers> getUsers({int? since, int perPage});

  /// One user's full profile, keyed by login.
  Future<UserDetailModel> getUserDetail(String login);
}

/// [UserRemoteDataSource] over [DioClient].
///
/// The ONLY file that knows the cursor is spelled `since` and travels in the
/// query string. It fetches and parses; it makes no decisions about caching,
/// retries or fallbacks -- those are the repository's.
class UserRemoteDataSourceImpl implements UserRemoteDataSource {
  const UserRemoteDataSourceImpl(this._client);

  final DioClient _client;

  @override
  Future<PaginatedUsers> getUsers({
    int? since,
    int perPage = ApiConstants.defaultPerPage,
  }) async {
    final ApiResponse<List<dynamic>> response =
        await _client.get<List<dynamic>>(
      ApiConstants.usersPath,
      queryParameters: <String, dynamic>{
        ApiConstants.paramPerPage: perPage,
        // Null-aware element: on the first request the parameter is omitted
        // ENTIRELY. `since=0` is not equivalent -- it is a real cursor value
        // meaning "after user id 0", and sending it makes the first request
        // differ from the documented form for no benefit.
        ApiConstants.paramSince: ?since,
      },
    );

    final List<UserSummaryModel> users = (response.data ?? const <dynamic>[])
        // Drops anything that is not a JSON object outright; the model's
        // coercing parser handles objects that are merely wrong inside. One
        // malformed record must never discard the whole batch.
        .whereType<Map<String, dynamic>>()
        .map(UserSummaryModel.fromJson)
        .toList(growable: false);

    return PaginatedUsers.fromBatch(
      users: users,
      // Authoritative source of "is there more". Preferring it over "the
      // array came back empty" saves one whole request per exhausted list,
      // which matters against a 60/hour budget. Constraint (a).
      nextSince: LinkHeaderParser.nextSince(
        response.header(ApiConstants.headerLink),
      ),
    );
  }

  @override
  Future<UserDetailModel> getUserDetail(String login) async {
    // Percent-encode the path segment. Logins are ASCII alphanumerics and
    // hyphens today, but this value can reach us from a cache written by an
    // older build or from a deep link, and an unencoded '/' or '?' would
    // silently retarget the request at a different endpoint.
    final String segment = Uri.encodeComponent(login);

    final ApiResponse<Map<String, dynamic>> response =
        await _client.get<Map<String, dynamic>>(
      ApiConstants.userDetailPath(segment),
    );

    final Map<String, dynamic>? body = response.data;
    if (body == null) {
      throw const ServerException('Empty profile response from GitHub');
    }
    return UserDetailModel.fromJson(body);
  }
}
