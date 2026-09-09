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
///
/// There is no separate "force refresh" event: [UserRepository.getUserDetail]
/// takes no such flag, so a re-request inside the 24h TTL is answered from
/// cache. Retry after a failure still works, because a failure leaves nothing
/// cached to answer from.
final class UserDetailRequested extends UserDetailEvent {
  const UserDetailRequested(this.login);

  /// The handle to fetch.
  final String login;

  @override
  List<Object?> get props => <Object?>[login];
}
