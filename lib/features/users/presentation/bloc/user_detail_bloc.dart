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

class UserDetailBloc extends Bloc<UserDetailEvent, UserDetailState> {
  UserDetailBloc({
    required GetUserDetail getUserDetail,
    required UserSummary seed,
  }) : _getUserDetail = getUserDetail,
       super(UserDetailState(seed: seed)) {
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

    final Either<Failure, UserDetail> result = await _getUserDetail(
      GetUserDetailParams(detailId),
    );

    if (isClosed) return;

    emit(
      result.fold(
        (Failure failure) =>
            state.copyWith(status: UserDetailStatus.failure, failure: failure),
        (UserDetail detail) => state.copyWith(
          status: UserDetailStatus.success,
          detail: detail,
          clearFailure: true,
        ),
      ),
    );
  }
}
