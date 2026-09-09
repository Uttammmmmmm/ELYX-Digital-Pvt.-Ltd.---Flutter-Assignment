library;

import 'package:equatable/equatable.dart';

sealed class UserDetailEvent extends Equatable {
  const UserDetailEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

final class UserDetailRequested extends UserDetailEvent {
  const UserDetailRequested(this.detailId);

  final String detailId;

  @override
  List<Object?> get props => <Object?>[detailId];
}

final class UserDetailRetried extends UserDetailEvent {
  const UserDetailRetried();
}
