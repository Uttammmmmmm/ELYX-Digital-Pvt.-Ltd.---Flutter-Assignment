/// Network access to the GitHub users endpoints.
library;

import '../../../../core/constants/api_constants.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_response.dart';
import '../../../../core/network/dio_client.dart';
import '../models/github_user_detail_model.dart';
import '../models/users_page_model.dart';

/// Fetches users from GitHub.
abstract interface class UserRemoteDataSource {
  /// One page of users after the [since] cursor; null for the first page.
  Future<UsersPageModel> getUsers({int? since, int perPage});

  /// One user's full profile, keyed by login.
  Future<GithubUserDetailModel> getUserDetail(String login);
}

/// [UserRemoteDataSource] over [DioClient].
///
/// This is the ONLY file that knows the cursor is spelled `since` and lives in
/// the query string -- constraint (a). It throws [AppException] (never
/// [DioException]); `DioClient` has already done that translation.
class UserRemoteDataSourceImpl implements UserRemoteDataSource {
  const UserRemoteDataSourceImpl(this._client);

  final DioClient _client;

  @override
  Future<UsersPageModel> getUsers({
    int? since,
    int perPage = ApiConstants.defaultPerPage,
  }) async {
    final ApiResponse<List<dynamic>> response =
        await _client.get<List<dynamic>>(
      ApiConstants.usersPath,
      queryParameters: <String, dynamic>{
        ApiConstants.paramPerPage: perPage,
        // Null-aware element: the entry is omitted entirely for the first
        // page. GitHub treats `since=0` as "from the beginning", but leaving
        // the parameter out is the documented form.
        ApiConstants.paramSince: ?since,
      },
    );

    // The Link header is what makes end-of-list detectable without spending a
    // request on an empty array. Constraint (a).
    return UsersPageModel.fromResponse(
      response.data ?? const <dynamic>[],
      linkHeader: response.header(ApiConstants.headerLink),
    );
  }

  @override
  Future<GithubUserDetailModel> getUserDetail(String login) async {
    final ApiResponse<Map<String, dynamic>> response =
        await _client.get<Map<String, dynamic>>(
      ApiConstants.userDetailPath(login),
    );

    final Map<String, dynamic>? body = response.data;
    if (body == null) {
      throw const ServerException('Empty profile response from GitHub');
    }
    return GithubUserDetailModel.fromJson(body);
  }
}
