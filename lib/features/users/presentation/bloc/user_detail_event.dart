/// Events accepted by [UserDetailBloc].
library;

import 'package:equatable/equatable.dart';

/// Base type for detail-screen events.
sealed class UserDetailEvent extends Equatable {
  const UserDetailEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// Load the profile for [login], cache-first.
final class UserDetailRequested extends UserDetailEvent {
  const UserDetailRequested(this.login);

  /// The handle to fetch. The detail endpoint keys on login, not numeric id.
  final String login;

  @override
  List<Object?> get props => <Object?>[login];
}

/// Force a network refetch, bypassing the 24h cache.
final class UserDetailRefreshRequested extends UserDetailEvent {
  const UserDetailRefreshRequested(this.login);

  /// The handle to refetch.
  final String login;

  @override
  List<Object?> get props => <Object?>[login];
}
