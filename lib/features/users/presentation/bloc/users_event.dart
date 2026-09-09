library;

import 'package:equatable/equatable.dart';

sealed class UsersEvent extends Equatable {
  const UsersEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

final class UsersFetched extends UsersEvent {
  const UsersFetched();
}

final class UsersNextPageRequested extends UsersEvent {
  const UsersNextPageRequested();
}

final class UsersRefreshed extends UsersEvent {
  const UsersRefreshed();
}

final class UsersSearchQueryChanged extends UsersEvent {
  const UsersSearchQueryChanged(this.query);

  final String query;

  @override
  List<Object?> get props => <Object?>[query];
}

final class UsersSearchCleared extends UsersEvent {
  const UsersSearchCleared();
}

final class UsersFailedPageRetried extends UsersEvent {
  const UsersFailedPageRetried();
}
