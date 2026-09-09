library;

import '../../../domain/entities/paginated_users.dart';
import '../../../domain/entities/user_detail.dart';

abstract interface class UsersApi {
  String get sourceName;

  String get baseUrl;

  Map<String, String> get headers;

  Future<PaginatedUsers> fetchUsers({Object? cursor, int perPage});

  Future<UserDetail> fetchUserDetail(String id);
}
