/// Load a single user's full profile.
library;

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/models/sourced.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/github_user_detail.dart';
import '../repositories/user_repository.dart';

/// Arguments for [GetUserDetail].
class GetUserDetailParams extends Equatable {
  const GetUserDetailParams(this.login, {this.forceRefresh = false});

  /// The user's handle. The detail endpoint keys on login, not numeric id.
  final String login;

  /// Bypass the cache on read.
  final bool forceRefresh;

  @override
  List<Object?> get props => <Object?>[login, forceRefresh];
}

/// Fetches one user's profile, cache-first.
///
/// Constraint (d): this is the only source of name/email/bio, and each call
/// costs one of 60 hourly requests. It is invoked on navigation only -- never
/// prefetched across a list -- and its results are cached for 24h.
class GetUserDetail
    implements UseCase<Sourced<GithubUserDetail>, GetUserDetailParams> {
  const GetUserDetail(this._repository);

  final UserRepository _repository;

  @override
  Future<Either<Failure, Sourced<GithubUserDetail>>> call(
    GetUserDetailParams params,
  ) =>
      _repository.getUserDetail(
        params.login,
        forceRefresh: params.forceRefresh,
      );
}
