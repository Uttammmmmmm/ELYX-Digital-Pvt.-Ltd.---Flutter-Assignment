library;

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/paginated_users.dart';
import '../repositories/user_repository.dart';

class GetUsersParams extends Equatable {
  const GetUsersParams({
    this.cursor,
    this.perPage = 10,
    this.forceRefresh = false,
  });

  final Object? cursor;

  final int perPage;

  final bool forceRefresh;

  @override
  List<Object?> get props => <Object?>[cursor, perPage, forceRefresh];
}

class GetUsers implements UseCase<PaginatedUsers, GetUsersParams> {
  const GetUsers(this._repository);

  final UserRepository _repository;

  @override
  Future<Either<Failure, PaginatedUsers>> call(GetUsersParams params) =>
      _repository.getUsers(
        cursor: params.cursor,
        perPage: params.perPage,
        forceRefresh: params.forceRefresh,
      );
}
