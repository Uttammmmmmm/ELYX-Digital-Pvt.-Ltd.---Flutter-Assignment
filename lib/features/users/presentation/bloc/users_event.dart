/// Events accepted by [UsersBloc].
library;

import 'package:equatable/equatable.dart';

/// Base type for users-list events.
///
/// `sealed` so a handler registration cannot be forgotten silently, and
/// Equatable so `bloc_test` prints readable diffs and `droppable()` can
/// compare events.
sealed class UsersEvent extends Equatable {
  const UsersEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// Initial load. Emitted once when the list screen mounts.
final class UsersFetched extends UsersEvent {
  const UsersFetched();
}

/// The scroll position crossed the load-more threshold.
///
/// Safe to emit repeatedly: the bloc drops it while a request is in flight
/// and short-circuits once the end of the list is known.
final class UsersNextPageRequested extends UsersEvent {
  const UsersNextPageRequested();
}

/// Pull-to-refresh. Fetches with `forceRefresh: true` from the first cursor.
final class UsersRefreshed extends UsersEvent {
  const UsersRefreshed();
}

/// The search field text changed. Debounced by the bloc, not the widget.
final class UsersSearchQueryChanged extends UsersEvent {
  const UsersSearchQueryChanged(this.query);

  /// Raw text; trimming and casing are the use case's job.
  final String query;

  @override
  List<Object?> get props => <Object?>[query];
}

/// The search was cleared.
///
/// Distinct from `UsersSearchQueryChanged('')` on purpose: clearing is an
/// immediate, deliberate action and must NOT wait out the 300ms debounce.
/// Tapping the clear button and watching the list sit filtered for a third of
/// a second reads as a bug.
final class UsersSearchCleared extends UsersEvent {
  const UsersSearchCleared();
}

/// Retry the page that just failed.
///
/// Distinct from [UsersFetched] because it must resume from the CURRENT
/// cursor rather than restart the list from the top.
final class UsersFailedPageRetried extends UsersEvent {
  const UsersFailedPageRetried();
}
