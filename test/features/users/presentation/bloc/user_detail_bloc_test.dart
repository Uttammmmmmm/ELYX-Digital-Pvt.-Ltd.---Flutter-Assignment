import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:elyx_digital_assignment/core/error/failures.dart';
import 'package:elyx_digital_assignment/features/users/domain/entities/user_detail.dart';
import 'package:elyx_digital_assignment/features/users/domain/usecases/get_user_detail.dart';
import 'package:elyx_digital_assignment/features/users/presentation/bloc/user_detail_bloc.dart';
import 'package:elyx_digital_assignment/features/users/presentation/bloc/user_detail_event.dart';
import 'package:elyx_digital_assignment/features/users/presentation/bloc/user_detail_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../../../../helpers/mocks.mocks.dart';

final UserDetail _detail = UserDetail(
  id: 1,
  login: 'mojombo',
  avatarUrl: 'https://avatars.githubusercontent.com/u/1?v=4',
  htmlUrl: 'https://github.com/mojombo',
  publicRepos: 66,
  followers: 23000,
  following: 11,
  createdAt: DateTime.utc(2007, 10, 20),
  name: 'Tom Preston-Werner',
  // email stays null: the common case, not an edge case. Constraint (c).
);

void main() {
  late MockUserRepository repository;

  UserDetailBloc build() =>
      UserDetailBloc(getUserDetail: GetUserDetail(repository));

  setUp(() => repository = MockUserRepository());

  blocTest<UserDetailBloc, UserDetailState>(
    'emits loading then loaded',
    setUp: () => when(repository.getUserDetail('mojombo'))
        .thenAnswer((_) async => Right<Failure, UserDetail>(_detail)),
    build: build,
    act: (UserDetailBloc bloc) =>
        bloc.add(const UserDetailRequested('mojombo')),
    expect: () => <Matcher>[
      isA<UserDetailLoading>(),
      isA<UserDetailLoaded>()
          .having((UserDetailLoaded s) => s.detail.displayName, 'displayName',
              'Tom Preston-Werner')
          .having((UserDetailLoaded s) => s.detail.hasEmail, 'hasEmail', false),
    ],
  );

  blocTest<UserDetailBloc, UserDetailState>(
    'a blank login is rejected by the use case, sparing a request',
    build: build,
    act: (UserDetailBloc bloc) => bloc.add(const UserDetailRequested('   ')),
    skip: 1,
    expect: () => <Matcher>[
      isA<UserDetailError>().having(
          (UserDetailError s) => s.failure, 'failure', isA<ValidationFailure>()),
    ],
    verify: (_) => verifyZeroInteractions(repository),
  );

  blocTest<UserDetailBloc, UserDetailState>(
    'a 404 becomes NotFoundFailure',
    setUp: () => when(repository.getUserDetail('ghost')).thenAnswer(
      (_) async => const Left<Failure, UserDetail>(NotFoundFailure()),
    ),
    build: build,
    act: (UserDetailBloc bloc) => bloc.add(const UserDetailRequested('ghost')),
    skip: 1,
    expect: () => <Matcher>[
      isA<UserDetailError>()
          .having((UserDetailError s) => s.failure, 'failure',
              isA<NotFoundFailure>())
          .having((UserDetailError s) => s.rateLimitFailure, 'not rate limited',
              isNull),
    ],
  );

  blocTest<UserDetailBloc, UserDetailState>(
    'a rate limit exposes resetAt for the countdown (constraint d)',
    setUp: () => when(repository.getUserDetail('mojombo')).thenAnswer(
      (_) async => Left<Failure, UserDetail>(
        RateLimitFailure(resetAt: DateTime.utc(2026, 9, 9, 13)),
      ),
    ),
    build: build,
    act: (UserDetailBloc bloc) =>
        bloc.add(const UserDetailRequested('mojombo')),
    skip: 1,
    expect: () => <Matcher>[
      isA<UserDetailError>().having(
        (UserDetailError s) => s.rateLimitFailure?.resetAt,
        'resetAt',
        DateTime.utc(2026, 9, 9, 13),
      ),
    ],
  );

  blocTest<UserDetailBloc, UserDetailState>(
    'droppable(): a double-tapped Retry spends only one request',
    setUp: () => when(repository.getUserDetail('mojombo')).thenAnswer(
      (_) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return Right<Failure, UserDetail>(_detail);
      },
    ),
    build: build,
    act: (UserDetailBloc bloc) => bloc
      ..add(const UserDetailRequested('mojombo'))
      ..add(const UserDetailRequested('mojombo'))
      ..add(const UserDetailRequested('mojombo')),
    wait: const Duration(milliseconds: 120),
    verify: (_) => verify(repository.getUserDetail('mojombo')).called(1),
  );
}
