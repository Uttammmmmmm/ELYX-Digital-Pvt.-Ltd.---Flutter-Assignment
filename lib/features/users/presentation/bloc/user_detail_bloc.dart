/// Loads one user's profile.
library;

import 'package:dartz/dartz.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/bloc/event_transformers.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/models/sourced.dart';
import '../../domain/entities/github_user_detail.dart';
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
    on<UserDetailRequested>(
      (UserDetailRequested e, Emitter<UserDetailState> emit) =>
          _load(emit, e.login, forceRefresh: false),
      transformer: dropWhileBusy(),
    );

    on<UserDetailRefreshRequested>(
      (UserDetailRefreshRequested e, Emitter<UserDetailState> emit) =>
          _load(emit, e.login, forceRefresh: true),
      transformer: dropWhileBusy(),
    );
  }

  final GetUserDetail _getUserDetail;

  Future<void> _load(
    Emitter<UserDetailState> emit,
    String login, {
    required bool forceRefresh,
  }) async {
    // Keep the current profile on screen during a refresh; only a cold load
    // gets a spinner.
    if (state is! UserDetailLoaded) emit(const UserDetailLoading());

    final Either<Failure, Sourced<GithubUserDetail>> result =
        await _getUserDetail(
      GetUserDetailParams(login, forceRefresh: forceRefresh),
    );

    emit(
      result.fold(
        UserDetailError.new,
        (Sourced<GithubUserDetail> sourced) => UserDetailLoaded(
          detail: sourced.value,
          isFromCache: sourced.isFromCache,
          cachedAt: sourced.cachedAt,
        ),
      ),
    );
  }
}
