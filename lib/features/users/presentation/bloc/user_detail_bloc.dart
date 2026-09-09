/// Loads one user's profile.
library;

import 'package:dartz/dartz.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/bloc/event_transformers.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/user_detail.dart';
import '../../domain/usecases/get_user_detail.dart';
import 'user_detail_event.dart';
import 'user_detail_state.dart';

/// Drives the user detail screen.
///
/// Constraint (d): each load costs one of 60 hourly requests, so this is
/// created per-screen and fires on navigation only. Nothing prefetches it
/// across the list.
class UserDetailBloc extends Bloc<UserDetailEvent, UserDetailState> {
  UserDetailBloc({required GetUserDetail getUserDetail})
      : _getUserDetail = getUserDetail,
        super(const UserDetailInitial()) {
    // Droppable so a double tap on Retry cannot spend two requests.
    on<UserDetailRequested>(_onRequested, transformer: dropWhileBusy());
  }

  final GetUserDetail _getUserDetail;

  Future<void> _onRequested(
    UserDetailRequested event,
    Emitter<UserDetailState> emit,
  ) async {
    emit(const UserDetailLoading());

    final Either<Failure, UserDetail> result =
        await _getUserDetail(GetUserDetailParams(event.login));

    emit(result.fold(UserDetailError.new, UserDetailLoaded.new));
  }
}
