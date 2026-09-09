/// Load one batch of the users list.
library;

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/paginated_users.dart';
import '../repositories/user_repository.dart';

/// Arguments for [GetUsers].
///
/// Equatable so a Bloc can compare two requests -- useful for dropping a
/// duplicate load-more, and it makes the params printable in test failures.
class GetUsersParams extends Equatable {
  const GetUsersParams({
    this.cursor,
    this.perPage = 10,
    this.forceRefresh = false,
  });

  /// Opaque cursor from a previous [PaginatedUsers.nextCursor]; null for the
  /// first batch. Its meaning belongs to the active source -- a page number
  /// for reqres, a user id for GitHub -- and is never inspected here.
  final Object? cursor;

  /// Requested batch size. GitHub caps this at 100.
  final int perPage;

  /// Bypass the cache on read. Set by pull-to-refresh.
  final bool forceRefresh;

  @override
  List<Object?> get props => <Object?>[cursor, perPage, forceRefresh];
}

/// Fetches the next batch of users.
///
/// A thin pass-through by design. The temptation is to "simplify" it away and
/// let the Bloc hold the repository directly, but the indirection is what
/// keeps the Bloc depending on a one-method contract instead of the whole
/// repository surface, and it gives the operation a name that matches how the
/// feature is discussed.
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
