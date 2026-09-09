import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:elyx_digital_assignment/core/error/failures.dart';
import 'package:elyx_digital_assignment/core/models/sourced.dart';
import 'package:elyx_digital_assignment/features/users/domain/entities/github_user.dart';
import 'package:elyx_digital_assignment/features/users/domain/entities/github_user_detail.dart';
import 'package:elyx_digital_assignment/features/users/domain/usecases/get_user_detail.dart';
import 'package:elyx_digital_assignment/features/users/presentation/bloc/user_detail_bloc.dart';
import 'package:elyx_digital_assignment/features/users/presentation/bloc/user_detail_event.dart';
import 'package:elyx_digital_assignment/features/users/presentation/bloc/user_detail_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../../../../helpers/mocks.mocks.dart';

const GithubUser _mojombo = GithubUser(
  id: 1,
  login: 'mojombo',
  avatarUrl: 'https://avatars.githubusercontent.com/u/1?v=4',
  htmlUrl: 'https://github.com/mojombo',
  type: 'User',
  isSiteAdmin: false,
);

const GithubUserDetail _detail = GithubUserDetail(
  user: _mojombo,
  publicRepos: 66,
  publicGists: 62,
  followers: 23000,
  following: 11,
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
    setUp: () => when(
      repository.getUserDetail('mojombo', forceRefresh: false),
    ).thenAnswer(
      (_) async => Right<Failure, Sourced<GithubUserDetail>>(
        const Sourced<GithubUserDetail>.network(_detail),
      ),
    ),
    build: build,
    act: (UserDetailBloc bloc) =>
        bloc.add(const UserDetailRequested('mojombo')),
    expect: () => <Matcher>[
      isA<UserDetailLoading>(),
      isA<UserDetailLoaded>()
          .having((UserDetailLoaded s) => s.detail.name, 'name',
              'Tom Preston-Werner')
          .having((UserDetailLoaded s) => s.detail.email, 'email', isNull)
          .having((UserDetailLoaded s) => s.isFromCache, 'isFromCache', false),
    ],
  );

  blocTest<UserDetailBloc, UserDetailState>(
    'flags a cache-served profile with its age',
    setUp: () => when(
      repository.getUserDetail('mojombo', forceRefresh: false),
    ).thenAnswer(
      (_) async => Right<Failure, Sourced<GithubUserDetail>>(
        Sourced<GithubUserDetail>.cache(_detail, DateTime(2026, 9, 8, 10)),
      ),
    ),
    build: build,
    act: (UserDetailBloc bloc) =>
        bloc.add(const UserDetailRequested('mojombo')),
    skip: 1,
    expect: () => <Matcher>[
      isA<UserDetailLoaded>()
          .having((UserDetailLoaded s) => s.isFromCache, 'isFromCache', true)
          .having((UserDetailLoaded s) => s.cachedAt, 'cachedAt',
              DateTime(2026, 9, 8, 10)),
    ],
  );

  blocTest<UserDetailBloc, UserDetailState>(
    'a 404 becomes NotFoundFailure',
    setUp: () => when(
      repository.getUserDetail('ghost', forceRefresh: false),
    ).thenAnswer(
      (_) async => const Left<Failure, Sourced<GithubUserDetail>>(
        NotFoundFailure(),
      ),
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
    setUp: () => when(
      repository.getUserDetail('mojombo', forceRefresh: false),
    ).thenAnswer(
      (_) async => Left<Failure, Sourced<GithubUserDetail>>(
        RateLimitFailure(resetAt: DateTime(2026, 9, 8, 13)),
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
        DateTime(2026, 9, 8, 13),
      ),
    ],
  );

  blocTest<UserDetailBloc, UserDetailState>(
    'a refresh keeps the current profile on screen -- no spinner flash',
    setUp: () {
      when(repository.getUserDetail('mojombo', forceRefresh: false))
          .thenAnswer(
        (_) async => Right<Failure, Sourced<GithubUserDetail>>(
          Sourced<GithubUserDetail>.cache(_detail, DateTime(2026, 9, 8, 10)),
        ),
      );
      when(repository.getUserDetail('mojombo', forceRefresh: true)).thenAnswer(
        (_) async => Right<Failure, Sourced<GithubUserDetail>>(
          const Sourced<GithubUserDetail>.network(_detail),
        ),
      );
    },
    build: build,
    act: (UserDetailBloc bloc) async {
      bloc.add(const UserDetailRequested('mojombo'));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const UserDetailRefreshRequested('mojombo'));
    },
    skip: 2,
    expect: () => <Matcher>[
      isA<UserDetailLoaded>()
          .having((UserDetailLoaded s) => s.isFromCache, 'now live', false),
    ],
    verify: (_) =>
        verify(repository.getUserDetail('mojombo', forceRefresh: true))
            .called(1),
  );

  blocTest<UserDetailBloc, UserDetailState>(
    'droppable(): a double-tapped Retry spends only one request',
    setUp: () => when(
      repository.getUserDetail('mojombo', forceRefresh: false),
    ).thenAnswer((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return Right<Failure, Sourced<GithubUserDetail>>(
        const Sourced<GithubUserDetail>.network(_detail),
      );
    }),
    build: build,
    act: (UserDetailBloc bloc) => bloc
      ..add(const UserDetailRequested('mojombo'))
      ..add(const UserDetailRequested('mojombo'))
      ..add(const UserDetailRequested('mojombo')),
    wait: const Duration(milliseconds: 120),
    verify: (_) =>
        verify(repository.getUserDetail('mojombo', forceRefresh: false))
            .called(1),
  );
}
