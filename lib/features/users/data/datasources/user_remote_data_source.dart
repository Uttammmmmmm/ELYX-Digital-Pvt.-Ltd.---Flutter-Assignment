/// Network access to the GitHub users endpoints.
library;

import '../../../../core/constants/api_constants.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_response.dart';
import '../../../../core/network/dio_client.dart';
import '../models/paginated_users_model.dart';
import '../models/user_detail_model.dart';

/// Fetches users from GitHub.
abstract interface class UserRemoteDataSource {
  /// One batch of users after the [since] cursor; null for the first batch.
  Future<PaginatedUsersModel> getUsers({int? since, int perPage});

  /// One user's full profile, keyed by login.
  Future<UserDetailModel> getUserDetail(String login);
}

/// [UserRemoteDataSource] over [DioClient].
///
/// The ONLY file that knows the cursor is spelled `since` and travels in the
/// query string -- constraint (a). Throws [AppException], never
/// [DioException]; `DioClient` has already made that translation.
class UserRemoteDataSourceImpl implements UserRemoteDataSource {
  const UserRemoteDataSourceImpl(this._client);

  final DioClient _client;

  @override
  Future<PaginatedUsersModel> getUsers({
    int? since,
    int perPage = ApiConstants.defaultPerPage,
  }) async {
    final ApiResponse<List<dynamic>> response =
        await _client.get<List<dynamic>>(
      ApiConstants.usersPath,
      queryParameters: <String, dynamic>{
        ApiConstants.paramPerPage: perPage,
        // Null-aware element: omitted entirely for the first batch. GitHub
        // treats `since=0` as "from the beginning", but leaving the parameter
        // out is the documented form.
        ApiConstants.paramSince: ?since,
      },
    );

    return PaginatedUsersModel.fromResponse(
      response.data ?? const <dynamic>[],
      linkHeader: response.header(ApiConstants.headerLink),
    );
  }

  @override
  Future<UserDetailModel> getUserDetail(String login) async {
    final ApiResponse<Map<String, dynamic>> response =
        await _client.get<Map<String, dynamic>>(
      ApiConstants.userDetailPath(login),
    );

    final Map<String, dynamic>? body = response.data;
    if (body == null) {
      throw const ServerException('Empty profile response from GitHub');
    }
    return UserDetailModel.fromJson(body);
  }
}
