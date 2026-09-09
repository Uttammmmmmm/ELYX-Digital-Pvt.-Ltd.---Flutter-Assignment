/// Events accepted by [UsersBloc].
library;

import 'package:equatable/equatable.dart';

/// Base type for users-list events.
sealed class UsersEvent extends Equatable {
  const UsersEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// First load. Emitted once when the list page mounts.
final class UsersStarted extends UsersEvent {
  const UsersStarted();
}

/// The user scrolled near the bottom.
///
/// Safe to emit repeatedly: the bloc drops it while a load is in flight and
/// short-circuits once the end of the list is known.
final class UsersLoadMoreRequested extends UsersEvent {
  const UsersLoadMoreRequested();
}

/// Pull-to-refresh: drop cached pages and reload from the first page.
final class UsersRefreshRequested extends UsersEvent {
  const UsersRefreshRequested();
}

/// The search text changed. Debounced by the bloc.
final class UsersSearchChanged extends UsersEvent {
  const UsersSearchChanged(this.query);

  /// Raw text from the field; trimming and casing are the use case's job.
  final String query;

  @override
  List<Object?> get props => <Object?>[query];
}

/// The user tapped Retry after a failure.
///
/// Distinct from [UsersStarted] because it must resume from the current
/// cursor rather than restart the list from the top.
final class UsersRetryRequested extends UsersEvent {
  const UsersRetryRequested();
}
