library;

import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/user_detail.dart';
import '../../domain/entities/user_summary.dart';

enum UserDetailStatus { initial, loading, success, failure }

class UserDetailState extends Equatable {
  const UserDetailState({
    required this.seed,
    this.status = UserDetailStatus.initial,
    this.detail,
    this.failure,
  });

  final UserSummary seed;

  final UserDetailStatus status;

  final UserDetail? detail;

  final Failure? failure;

  String get detailId => seed.detailId;

  String get displayName => detail?.displayName ?? seed.displayName;

  bool get isLoadingBody =>
      status == UserDetailStatus.initial || status == UserDetailStatus.loading;

  RateLimitFailure? get rateLimitFailure {
    final Failure? f = failure;
    return f is RateLimitFailure ? f : null;
  }

  UserDetailState copyWith({
    UserSummary? seed,
    UserDetailStatus? status,
    UserDetail? detail,
    bool clearDetail = false,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return UserDetailState(
      seed: seed ?? this.seed,
      status: status ?? this.status,
      detail: clearDetail ? null : (detail ?? this.detail),
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  List<Object?> get props => <Object?>[seed, status, detail, failure];
}
