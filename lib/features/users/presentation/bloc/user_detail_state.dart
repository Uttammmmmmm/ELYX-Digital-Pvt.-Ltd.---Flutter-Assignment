/// State held by [UserDetailBloc].
library;

import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/user_detail.dart';
import '../../domain/entities/user_summary.dart';

/// Lifecycle of the detail screen.
enum UserDetailStatus {
  /// Nothing requested yet.
  initial,

  /// A load is in flight. The SEED is still renderable.
  loading,

  /// The full profile is available.
  success,

  /// The load failed. The seed is still renderable.
  failure,
}

/// A single state object for the detail screen.
///
/// WHY A SEED: the list already knows the login, avatar and id, so the screen
/// has real content to show the instant it opens. Carrying that through state
/// means the header never renders blank or shimmering, and only the fields
/// that genuinely require the network get a loading treatment. It also means
/// a failure is not a dead end -- the user still sees who they tapped.
///
/// One class rather than a sealed union for the same reason the list uses
/// one: `seed` is present in every status, so a union would repeat it in
/// every variant.
class UserDetailState extends Equatable {
  const UserDetailState({
    required this.seed,
    this.status = UserDetailStatus.initial,
    this.detail,
    this.failure,
  });

  /// What the list already knew. Always present, never null.
  final UserSummary seed;

  /// Current lifecycle.
  final UserDetailStatus status;

  /// The fetched profile; null until [UserDetailStatus.success].
  final UserDetail? detail;

  /// Why the load failed; non-null only alongside [UserDetailStatus.failure].
  final Failure? failure;

  /// The login, always available even before the profile loads.
  String get login => seed.login;

  /// True while the body should show a skeleton.
  bool get isLoadingBody =>
      status == UserDetailStatus.initial || status == UserDetailStatus.loading;

  /// The rate-limit failure, when that is what went wrong. Constraint (d).
  RateLimitFailure? get rateLimitFailure {
    final Failure? f = failure;
    return f is RateLimitFailure ? f : null;
  }

  /// Copy helper. [detail] and [failure] need explicit clearing.
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
