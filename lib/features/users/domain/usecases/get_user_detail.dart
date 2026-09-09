library;

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/user_detail.dart';
import '../repositories/user_repository.dart';

class GetUserDetailParams extends Equatable {
  const GetUserDetailParams(this.detailId);

  final String detailId;

  @override
  List<Object?> get props => <Object?>[detailId];
}

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
