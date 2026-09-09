/// Load one user's full profile.
library;

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/user_detail.dart';
import '../repositories/user_repository.dart';

/// Arguments for [GetUserDetail].
class GetUserDetailParams extends Equatable {
  const GetUserDetailParams(this.detailId);

  /// The source-specific detail key, from [UserSummary.detailId]. Validated
  /// by the use case before any I/O.
  final String detailId;

  @override
  List<Object?> get props => <Object?>[detailId];
}

/// Fetches one user's profile, rejecting a blank handle before any request.
///
/// The guard is not defensive noise. An empty login would produce a request
/// to `/users/` -- a different endpoint that returns a *list*, so the failure
/// would surface as a confusing parse error rather than "you asked for
/// nothing". It would also spend one of 60 hourly requests to learn something
/// knowable locally. Validating here, rather than in the repository, keeps
/// the rule next to the operation it constrains.
class GetUserDetail implements UseCase<UserDetail, GetUserDetailParams> {
  const GetUserDetail(this._repository);

  final UserRepository _repository;

  @override
  Future<Either<Failure, UserDetail>> call(GetUserDetailParams params) async {
    final String detailId = params.detailId.trim();
    if (detailId.isEmpty) {
      return const Left<Failure, UserDetail>(
        ValidationFailure('A user id is required.'),
      );
    }
    return _repository.getUserDetail(detailId);
  }
}
