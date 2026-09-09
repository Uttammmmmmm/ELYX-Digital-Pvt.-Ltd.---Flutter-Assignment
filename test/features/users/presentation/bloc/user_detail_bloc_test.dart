import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:elyx_digital_assignment/core/error/failures.dart';
import 'package:elyx_digital_assignment/features/users/domain/entities/user_detail.dart';
import 'package:elyx_digital_assignment/features/users/domain/entities/user_summary.dart';
import 'package:elyx_digital_assignment/features/users/domain/usecases/get_user_detail.dart';
import 'package:elyx_digital_assignment/features/users/presentation/bloc/user_detail_bloc.dart';
import 'package:elyx_digital_assignment/features/users/presentation/bloc/user_detail_event.dart';
import 'package:elyx_digital_assignment/features/users/presentation/bloc/user_detail_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../../../../helpers/entity_fixtures.dart';
import '../../../../helpers/mocks.mocks.dart';

final UserSummary _seed = reqresUser(2, first: 'Janet', last: 'Weaver');

final UserDetail _detail = reqresDetail(2, first: 'Janet', last: 'Weaver');

void main() {
  late MockUserRepository repository;

  UserDetailBloc build() => UserDetailBloc(
        getUserDetail: GetUserDetail(repository),
        seed: _seed,
      );

  setUp(() => repository = MockUserRepository());

  test('the initial state already carries the seed, so nothing renders blank',
      () {
    final UserDetailBloc bloc = build();

    expect(bloc.state.status, UserDetailStatus.initial);
    expect(bloc.state.seed, _seed);
    expect(bloc.state.detailId, '2');
    expect(bloc.state.detail, isNull);

    bloc.close();
  });

  blocTest<UserDetailBloc, UserDetailState>(
    'emits loading then success, keeping the seed throughout',
    setUp: () => when(repository.getUserDetail('2'))
        .thenAnswer((_) async => Right<Failure, UserDetail>(_detail)),
    build: build,
    act: (UserDetailBloc bloc) =>
        bloc.add(const UserDetailRequested('2')),
    expect: () => <Matcher>[
      isA<UserDetailState>()
          .having((UserDetailState s) => s.status, 'status',
              UserDetailStatus.loading)
          .having((UserDetailState s) => s.seed, 'seed kept', _seed),
      isA<UserDetailState>()
          .having((UserDetailState s) => s.status, 'status',
              UserDetailStatus.success)
          .having((UserDetailState s) => s.detail?.displayName, 'displayName',
              'Janet Weaver')
          // reqres always returns an email -- unlike GitHub, where it is
          // null for most accounts.
          .having((UserDetailState s) => s.detail?.hasEmail, 'hasEmail', true)
          .having((UserDetailState s) => s.seed, 'seed still kept', _seed),
    ],
  );

  blocTest<UserDetailBloc, UserDetailState>(
    'a failure keeps the seed so the user still sees who they tapped',
    setUp: () => when(repository.getUserDetail('2')).thenAnswer(
      (_) async => const Left<Failure, UserDetail>(NotFoundFailure()),
    ),
    build: build,
    act: (UserDetailBloc bloc) =>
        bloc.add(const UserDetailRequested('2')),
    skip: 1,
    expect: () => <Matcher>[
      isA<UserDetailState>()
          .having((UserDetailState s) => s.status, 'status',
              UserDetailStatus.failure)
          .having((UserDetailState s) => s.failure, 'failure',
              isA<NotFoundFailure>())
          .having((UserDetailState s) => s.seed, 'seed survives', _seed),
    ],
  );

  blocTest<UserDetailBloc, UserDetailState>(
    'UserDetailRetried refetches using the seed login and recovers',
    setUp: () => when(repository.getUserDetail('2')).thenAnswer(
      (_) async => const Left<Failure, UserDetail>(ServerFailure()),
    ),
    build: build,
    act: (UserDetailBloc bloc) async {
      bloc.add(const UserDetailRequested('2'));
      await Future<void>.delayed(Duration.zero);
      when(repository.getUserDetail('2'))
          .thenAnswer((_) async => Right<Failure, UserDetail>(_detail));
      bloc.add(const UserDetailRetried());
    },
    skip: 2,
    expect: () => <Matcher>[
      isA<UserDetailState>().having(
          (UserDetailState s) => s.status, 'status', UserDetailStatus.loading),
      isA<UserDetailState>()
          .having((UserDetailState s) => s.status, 'status',
              UserDetailStatus.success)
          .having((UserDetailState s) => s.failure, 'failure cleared', isNull),
    ],
  );

  blocTest<UserDetailBloc, UserDetailState>(
    'a rate limit exposes resetAt for the countdown (constraint d)',
    setUp: () => when(repository.getUserDetail('2')).thenAnswer(
      (_) async => Left<Failure, UserDetail>(
        RateLimitFailure(resetAt: DateTime.utc(2026, 9, 9, 13)),
      ),
    ),
    build: build,
    act: (UserDetailBloc bloc) =>
        bloc.add(const UserDetailRequested('2')),
    skip: 1,
    expect: () => <Matcher>[
      isA<UserDetailState>().having(
        (UserDetailState s) => s.rateLimitFailure?.resetAt,
        'resetAt',
        DateTime.utc(2026, 9, 9, 13),
      ),
    ],
  );

  blocTest<UserDetailBloc, UserDetailState>(
    'droppable(): a double-tapped Retry spends only one request',
    setUp: () => when(repository.getUserDetail('2')).thenAnswer(
      (_) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return Right<Failure, UserDetail>(_detail);
      },
    ),
    build: build,
    act: (UserDetailBloc bloc) => bloc
      ..add(const UserDetailRetried())
      ..add(const UserDetailRetried())
      ..add(const UserDetailRetried()),
    wait: const Duration(milliseconds: 120),
    verify: (_) => verify(repository.getUserDetail('2')).called(1),
  );

  blocTest<UserDetailBloc, UserDetailState>(
    'closing mid-request emits nothing (back navigation)',
    setUp: () => when(repository.getUserDetail('2')).thenAnswer(
      (_) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return Right<Failure, UserDetail>(_detail);
      },
    ),
    build: build,
    act: (UserDetailBloc bloc) async {
      bloc.add(const UserDetailRequested('2'));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await bloc.close();
      await Future<void>.delayed(const Duration(milliseconds: 80));
    },
    errors: () => <Matcher>[],
  );
}
