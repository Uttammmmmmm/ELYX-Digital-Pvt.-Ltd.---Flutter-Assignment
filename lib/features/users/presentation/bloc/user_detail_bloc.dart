/// Loads one user's profile.
library;

import 'package:dartz/dartz.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/bloc/event_transformers.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/user_detail.dart';
import '../../domain/entities/user_summary.dart';
import '../../domain/usecases/get_user_detail.dart';
import 'user_detail_event.dart';
import 'user_detail_state.dart';

/// Drives the user detail screen.
///
/// Constraint (d): each load costs one of 60 hourly requests, so this is
/// created per-screen and fires on navigation only -- nothing prefetches it
/// across the list. Responses are cached for 6 hours by the repository, so a
/// revisit inside that window is served from disk with no request at all,
/// which is also what makes this screen work offline.
class UserDetailBloc extends Bloc<UserDetailEvent, UserDetailState> {
  UserDetailBloc({
    required GetUserDetail getUserDetail,
    required UserSummary seed,
  })  : _getUserDetail = getUserDetail,
        super(UserDetailState(seed: seed)) {
    // Droppable: a double-tapped Retry, or a rebuild that re-dispatches,
    // must not spend two requests.
    on<UserDetailRequested>(
      (UserDetailRequested e, Emitter<UserDetailState> emit) =>
          _load(emit, e.detailId),
      transformer: dropWhileBusy(),
    );

    on<UserDetailRetried>(
      (UserDetailRetried e, Emitter<UserDetailState> emit) =>
          _load(emit, state.detailId),
      transformer: dropWhileBusy(),
    );
  }

  final GetUserDetail _getUserDetail;

  Future<void> _load(Emitter<UserDetailState> emit, String detailId) async {
    emit(state.copyWith(status: UserDetailStatus.loading, clearFailure: true));

    final Either<Failure, UserDetail> result =
        await _getUserDetail(GetUserDetailParams(detailId));

    // Checked after the await, before emitting. A bloc closed while the
    // request was in flight -- the user tapped back before the profile
    // landed -- would otherwise receive an emit on a closed StreamController
    // and throw `Cannot add new events after calling close`, surfacing as a
    // red screen frames after the navigation.
    if (isClosed) return;

    emit(
      result.fold(
        (Failure failure) => state.copyWith(
          status: UserDetailStatus.failure,
          failure: failure,
        ),
        (UserDetail detail) => state.copyWith(
          status: UserDetailStatus.success,
          detail: detail,
          clearFailure: true,
        ),
      ),
    );
  }
}
