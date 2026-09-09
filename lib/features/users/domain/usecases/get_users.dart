/// Load one page of the users list.
library;

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/models/sourced.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/users_page.dart';
import '../repositories/user_repository.dart';

/// Arguments for [GetUsers].
class GetUsersParams extends Equatable {
  const GetUsersParams({this.cursor, this.forceRefresh = false});

  /// Opaque cursor from the previous page; null for the first page.
  final int? cursor;

  /// Bypass the cache on read.
  final bool forceRefresh;

  @override
  List<Object?> get props => <Object?>[cursor, forceRefresh];
}

/// Fetches the next page of users, cache-first.
class GetUsers implements UseCase<Sourced<UsersPage>, GetUsersParams> {
  const GetUsers(this._repository);

  final UserRepository _repository;

  @override
  Future<Either<Failure, Sourced<UsersPage>>> call(GetUsersParams params) =>
      _repository.getUsers(
        cursor: params.cursor,
        forceRefresh: params.forceRefresh,
      );
}
