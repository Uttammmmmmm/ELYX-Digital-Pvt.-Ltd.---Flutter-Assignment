/// Pull-to-refresh: discard cached pages and reload from the top.
library;

import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/models/sourced.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/users_page.dart';
import '../repositories/user_repository.dart';

/// Clears cached list pages and re-fetches the first page from the network.
///
/// A distinct use case rather than a boolean on [GetUsers] because it does
/// strictly more: it invalidates the cache first, so a refresh cannot be
/// answered from the very data the user is trying to replace. The cursor is
/// intentionally reset -- refreshing mid-list and keeping the old cursor would
/// leave a hole in the sequence.
class RefreshUsers implements UseCase<Sourced<UsersPage>, NoParams> {
  const RefreshUsers(this._repository);

  final UserRepository _repository;

  @override
  Future<Either<Failure, Sourced<UsersPage>>> call(NoParams params) async {
    await _repository.clearUsersCache();
    return _repository.getUsers(forceRefresh: true);
  }
}
