/// One page of the users list, plus the cursor for the next one.
library;

import 'package:equatable/equatable.dart';

import 'github_user.dart';

/// A slice of the users list and the cursor that follows it.
///
/// Constraint (a): `GET /users` is CURSOR-paginated via `since`, not
/// offset-paginated -- a `page` parameter is silently ignored. [nextCursor] is
/// treated as OPAQUE above the data layer: the Bloc stores it and hands it
/// back untouched, and nothing outside `data/` is allowed to know it happens
/// to be the last user's id. Swap in a backend that uses string tokens and
/// only the model changes.
class UsersPage extends Equatable {
  const UsersPage({required this.users, required this.nextCursor});

  /// An explicitly empty final page.
  const UsersPage.empty()
      : users = const <GithubUser>[],
        nextCursor = null;

  /// The users in this page, in the order GitHub returned them.
  final List<GithubUser> users;

  /// Opaque cursor for the following page; null at the end of the list.
  final int? nextCursor;

  /// True when there is nothing more to load.
  ///
  /// Derived from the cursor rather than from `users.isEmpty`, so the UI can
  /// stop scheduling loads without spending a request to discover the end.
  bool get hasReachedEnd => nextCursor == null;

  @override
  List<Object?> get props => <Object?>[users, nextCursor];
}
