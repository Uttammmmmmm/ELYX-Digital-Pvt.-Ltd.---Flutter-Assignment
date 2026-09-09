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

class GitHubUsersApi implements UsersApi {
  const GitHubUsersApi({
    required DioClient client,
    LinkHeaderParser linkHeaderParser = const LinkHeaderParser(),
  }) : _client = client,
       _linkParser = linkHeaderParser;

  final DioClient _client;

  final LinkHeaderParser _linkParser;

  @override
  String get sourceName => 'api.github.com';

  @override
  String get baseUrl => ApiConstants.baseUrl;

  @override
  Map<String, String> get headers => ApiConstants.defaultHeaders;

  @override
  Future<PaginatedUsers> fetchUsers({Object? cursor, int perPage = 10}) async {
    final int? since = cursor is int ? cursor : null;

    final ApiResponse<List<dynamic>> response = await _client
        .get<List<dynamic>>(
          ApiConstants.usersPath,
          queryParameters: <String, dynamic>{
            ApiConstants.paramPerPage: perPage,

            ApiConstants.paramSince: ?since,
          },
        );

    final List<UserSummary> users = (response.data ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(_userFromJson)
        .toList(growable: false);

    return PaginatedUsers.fromBatch(
      users: users,
      nextCursor: _linkParser.nextSince(
        response.header(ApiConstants.headerLink),
      ),
    );
  }

  @override
  Future<UserDetail> fetchUserDetail(String id) async {
    final ApiResponse<Map<String, dynamic>> response = await _client
        .get<Map<String, dynamic>>(
          ApiConstants.userDetailPath(Uri.encodeComponent(id)),
        );

    final Map<String, dynamic>? body = response.data;
    if (body == null) {
      throw const ServerException('Empty profile response from GitHub');
    }

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

    final String? name = asOptionalString(json, 'name');

    return UserSummary(
      id: asInt(json, 'id'),

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
