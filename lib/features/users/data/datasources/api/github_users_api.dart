/// GitHub implementation of [UsersApi].
library;

import '../../../../../core/constants/api_constants.dart';
import '../../../../../core/error/exceptions.dart';
import '../../../../../core/network/api_response.dart';
import '../../../../../core/network/dio_client.dart';
import '../../../domain/entities/paginated_users.dart';
import '../../../domain/entities/user_detail.dart';
import '../../../domain/entities/user_summary.dart';
import '../../models/json_parsing.dart';
import 'link_header_parser.dart';
import 'users_api.dart';

/// The alternate source: `https://api.github.com`.
///
/// Retained because the brief's hyperlinks point here. Cursor pagination via
/// `?since=`, an optional Bearer token, and no name or email in the list
/// response — constraint (b), which is why those fields arrive null.
class GitHubUsersApi implements UsersApi {
  const GitHubUsersApi({
    required DioClient client,
    LinkHeaderParser linkHeaderParser = const LinkHeaderParser(),
  }) : _client = client,
       _linkParser = linkHeaderParser;

  final DioClient _client;

  /// Injected so the cursor-extraction strategy is visible in the constructor
  /// and replaceable in tests.
  final LinkHeaderParser _linkParser;

  @override
  String get sourceName => 'api.github.com';

  @override
  String get baseUrl => ApiConstants.baseUrl;

  @override
  Map<String, String> get headers => ApiConstants.defaultHeaders;

  @override
  Future<PaginatedUsers> fetchUsers({Object? cursor, int perPage = 10}) async {
    // The cursor IS a user id for this source.
    final int? since = cursor is int ? cursor : null;

    final ApiResponse<List<dynamic>>
    response = await _client.get<List<dynamic>>(
      ApiConstants.usersPath,
      queryParameters: <String, dynamic>{
        ApiConstants.paramPerPage: perPage,
        // Null-aware element: omitted ENTIRELY on the first request.
        // `since=0` is not equivalent -- it is a real cursor meaning "after
        // user id 0" -- and leaving the parameter out is the documented form.
        ApiConstants.paramSince: ?since,
      },
    );

    final List<UserSummary> users = (response.data ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(_userFromJson)
        .toList(growable: false);

    // The Link header is authoritative for "is there more", and honouring it
    // saves one request per exhausted list -- which matters against a
    // 60/hour unauthenticated budget. Constraint (a).
    return PaginatedUsers.fromBatch(
      users: users,
      nextCursor: _linkParser.nextSince(
        response.header(ApiConstants.headerLink),
      ),
    );
  }

  @override
  Future<UserDetail> fetchUserDetail(String id) async {
    // Percent-encode the path segment: this value can reach us from a cache
    // written by an older build or a deep link, and an unencoded '/' or '?'
    // would silently retarget the request at a different endpoint.
    final ApiResponse<Map<String, dynamic>> response = await _client
        .get<Map<String, dynamic>>(
          ApiConstants.userDetailPath(Uri.encodeComponent(id)),
        );

    final Map<String, dynamic>? body = response.data;
    if (body == null) {
      throw const ServerException('Empty profile response from GitHub');
    }

    // GitHub returns `name` as one string; it is split only far enough to
    // populate displayName, which is all the UI reads.
    return UserDetail(
      user: _userFromJson(body),
      bio: asOptionalString(body, 'bio'),
      company: asOptionalString(body, 'company'),
      location: asOptionalString(body, 'location'),
      blog: asOptionalString(body, 'blog'),
      publicRepos: asInt(body, 'public_repos'),
      followers: asInt(body, 'followers'),
      following: asInt(body, 'following'),
      createdAt: asOptionalDate(body, 'created_at'),
    );
  }

  UserSummary _userFromJson(Map<String, dynamic> json) {
    final String login = asString(json, 'login');
    // GitHub's single `name` string maps to firstName so displayName picks it
    // up; there is no reliable way to split a free-form name, and guessing a
    // surname would be inventing structure the API never asserted.
    final String? name = asOptionalString(json, 'name');

    return UserSummary(
      id: asInt(json, 'id'),
      // GitHub keys its detail endpoint on login, not the numeric id.
      detailId: login,
      avatarUrl: asString(json, 'avatar_url'),
      handle: login.isEmpty ? null : login,
      firstName: name,
      email: asOptionalString(json, 'email'),
      profileUrl: asOptionalString(json, 'html_url'),
      accountType: asOptionalString(json, 'type'),
    );
  }
}
