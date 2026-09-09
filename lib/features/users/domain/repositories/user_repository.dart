library;

import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/paginated_users.dart';
import '../entities/user_detail.dart';
import '../entities/user_summary.dart';

abstract interface class UserRepository {
  Future<Either<Failure, PaginatedUsers>> getUsers({
    Object? cursor,
    int perPage,
    bool forceRefresh,
  });

  Future<Either<Failure, UserDetail>> getUserDetail(String detailId);

  Future<List<UserSummary>> getCachedUsers();
}
