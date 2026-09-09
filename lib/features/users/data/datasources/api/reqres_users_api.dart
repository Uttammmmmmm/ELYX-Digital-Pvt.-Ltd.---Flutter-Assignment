library;

import '../../../../../core/error/exceptions.dart';
import '../../../../../core/network/api_response.dart';
import '../../../../../core/network/dio_client.dart';
import '../../../domain/entities/paginated_users.dart';
import '../../../domain/entities/user_detail.dart';
import '../../../domain/entities/user_summary.dart';
import '../../models/json_parsing.dart';
import 'users_api.dart';

class ReqresUsersApi implements UsersApi {
  const ReqresUsersApi({required DioClient client, required String apiKey})
    : _client = client,
      _apiKey = apiKey;

  static const String apiKeyDefine = 'REQRES_API_KEY';

  static const String defaultApiKey = 'reqres-free-v1';

  static const String _usersPath = '/users';
  static const String _paramPage = 'page';
  static const String _paramPerPage = 'per_page';

  final DioClient _client;
  final String _apiKey;

  @override
  String get sourceName => 'reqres.in';

  @override
  String get baseUrl => 'https://reqres.in/api';

  @override
  Map<String, String> get headers => <String, String>{
    'Accept': 'application/json',

    'x-api-key': _apiKey,
  };

  @override
  Future<PaginatedUsers> fetchUsers({Object? cursor, int perPage = 10}) async {
    final int page = cursor is int ? cursor : 1;

    final ApiResponse<Map<String, dynamic>> response = await _client
        .get<Map<String, dynamic>>(
          _usersPath,
          queryParameters: <String, dynamic>{
            _paramPerPage: perPage,
            _paramPage: page,
          },
        );

    final Map<String, dynamic> body =
        response.data ?? const <String, dynamic>{};
    final Object? rawData = body['data'];

    final List<UserSummary> users = rawData is List
        ? rawData
              .whereType<Map<String, dynamic>>()
              .map(_userFromJson)
              .toList(growable: false)
        : const <UserSummary>[];

    final int totalPages = asInt(body, 'total_pages', fallback: page);
    final int currentPage = asInt(body, 'page', fallback: page);
    final bool hasMore = currentPage < totalPages && users.isNotEmpty;

    return PaginatedUsers.fromBatch(
      users: users,
      nextCursor: hasMore ? currentPage + 1 : null,
    );
  }

  @override
  Future<UserDetail> fetchUserDetail(String id) async {
    final ApiResponse<Map<String, dynamic>> response = await _client
        .get<Map<String, dynamic>>('$_usersPath/$id');

    final Map<String, dynamic>? body = response.data;

    final Object? data = body?['data'];
    if (data is! Map<String, dynamic>) {
      throw const ServerException('Empty profile response from reqres.in');
    }

    return UserDetail(user: _userFromJson(data));
  }

  UserSummary _userFromJson(Map<String, dynamic> json) {
    final int id = asInt(json, 'id');
    return UserSummary(
      id: id,

      detailId: '$id',
      avatarUrl: asString(json, 'avatar'),
      firstName: asOptionalString(json, 'first_name'),
      lastName: asOptionalString(json, 'last_name'),
      email: asOptionalString(json, 'email'),
    );
  }
}
