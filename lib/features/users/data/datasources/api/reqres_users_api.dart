/// reqres.in implementation of [UsersApi].
library;

import '../../../../../core/error/exceptions.dart';
import '../../../../../core/network/api_response.dart';
import '../../../../../core/network/dio_client.dart';
import '../../../domain/entities/paginated_users.dart';
import '../../../domain/entities/user_detail.dart';
import '../../../domain/entities/user_summary.dart';
import '../../models/json_parsing.dart';
import 'users_api.dart';

/// The default source: `https://reqres.in/api`.
///
/// Page-number pagination, an API key header, and a `{"data": …}` envelope on
/// the detail endpoint. Everything source-specific stops at this file.
class ReqresUsersApi implements UsersApi {
  const ReqresUsersApi({required DioClient client, required String apiKey})
      : _client = client,
        _apiKey = apiKey;

  /// Injected at build time; see [defaultApiKey].
  static const String apiKeyDefine = 'REQRES_API_KEY';

  /// reqres began requiring a key in 2025. Without it every request returns
  /// 401 `{"error":"missing_api_key"}`, so the free public key is the default
  /// rather than something the app has to be configured with to work at all.
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
        // REQUIRED. A missing key is a 401, not a rate limit. DioClient is
        // built from ApiSourceConfig, which carries the same header; this
        // getter exists so the API can describe itself in isolation.
        'x-api-key': _apiKey,
      };

  @override
  Future<PaginatedUsers> fetchUsers({Object? cursor, int perPage = 10}) async {
    // The cursor IS the page number for this source. Anything else means a
    // cursor from the other implementation leaked through a stale cache.
    final int page = cursor is int ? cursor : 1;

    final ApiResponse<Map<String, dynamic>> response =
        await _client.get<Map<String, dynamic>>(
      _usersPath,
      queryParameters: <String, dynamic>{
        _paramPerPage: perPage,
        _paramPage: page,
      },
    );

    final Map<String, dynamic> body = response.data ?? const <String, dynamic>{};
    final Object? rawData = body['data'];

    final List<UserSummary> users = rawData is List
        // Drops anything that is not a JSON object; the field-level parser
        // handles objects that are merely wrong inside. One malformed record
        // must never discard the whole batch.
        ? rawData
            .whereType<Map<String, dynamic>>()
            .map(_userFromJson)
            .toList(growable: false)
        : const <UserSummary>[];

    // Page count comes from the BODY here -- there is no Link header. This is
    // why `LinkHeaderParser` lives under the GitHub implementation only.
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
    final ApiResponse<Map<String, dynamic>> response =
        await _client.get<Map<String, dynamic>>('$_usersPath/$id');

    final Map<String, dynamic>? body = response.data;
    // The detail endpoint wraps its payload: {"data": {...}, "support": {...}}
    final Object? data = body?['data'];
    if (data is! Map<String, dynamic>) {
      throw const ServerException('Empty profile response from reqres.in');
    }

    // reqres profiles carry no bio, company, location or counters -- those
    // stay null, and the UI hides them rather than rendering blanks.
    return UserDetail(user: _userFromJson(data));
  }

  UserSummary _userFromJson(Map<String, dynamic> json) {
    final int id = asInt(json, 'id');
    return UserSummary(
      id: id,
      // reqres keys its detail endpoint on the numeric id, not a handle.
      detailId: '$id',
      avatarUrl: asString(json, 'avatar'),
      firstName: asOptionalString(json, 'first_name'),
      lastName: asOptionalString(json, 'last_name'),
      email: asOptionalString(json, 'email'),
      // reqres has no handle, profile URL or account type. Left null so the
      // UI can omit them rather than invent placeholders.
    );
  }
}
