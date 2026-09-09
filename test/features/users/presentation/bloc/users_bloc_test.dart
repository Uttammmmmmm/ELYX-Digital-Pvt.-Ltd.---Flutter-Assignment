import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:elyx_digital_assignment/core/error/failures.dart';
import 'package:elyx_digital_assignment/features/users/domain/entities/paginated_users.dart';
import 'package:elyx_digital_assignment/features/users/domain/entities/user_summary.dart';
import 'package:elyx_digital_assignment/features/users/domain/usecases/filter_users.dart';
import 'package:elyx_digital_assignment/features/users/domain/usecases/get_users.dart';
import 'package:elyx_digital_assignment/features/users/presentation/bloc/users_bloc.dart';
import 'package:elyx_digital_assignment/features/users/presentation/bloc/users_event.dart';
import 'package:elyx_digital_assignment/features/users/presentation/bloc/users_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../../../../helpers/mocks.mocks.dart';

UserSummary _u(int id, String login) => UserSummary(
      id: id,
      login: login,
      avatarUrl: 'https://avatars.githubusercontent.com/u/$id?v=4',
      htmlUrl: 'https://github.com/$login',
      type: 'User',
      siteAdmin: false,
    );

final List<UserSummary> _page1 = <UserSummary>[_u(1, 'mojombo'), _u(2, 'defunkt')];
final List<UserSummary> _page2 = <UserSummary>[_u(3, 'pjhyett'), _u(4, 'wycats')];

void main() {
  late MockUserRepository repository;

  UsersBloc build({Duration debounce = Duration.zero}) => UsersBloc(
        getUsers: GetUsers(repository),
        filterUsers: const FilterUsers(),
        searchDebounce: debounce,
      );

  void stub(
    List<UserSummary> users, {
    int? nextSince,
    int? forSince,
    bool? forceRefresh,
  }) {
    when(
      repository.getUsers(
        since: forSince,
        perPage: anyNamed('perPage'),
        forceRefresh: forceRefresh ?? anyNamed('forceRefresh'),
      ),
    ).thenAnswer(
      (_) async => Right<Failure, PaginatedUsers>(
        PaginatedUsers.fromBatch(users: users, nextSince: nextSince),
      ),
    );
  }

  void stubFailure(Failure failure) => when(
        repository.getUsers(
          since: anyNamed('since'),
          perPage: anyNamed('perPage'),
          forceRefresh: anyNamed('forceRefresh'),
        ),
      ).thenAnswer((_) async => Left<Failure, PaginatedUsers>(failure));

  setUp(() => repository = MockUserRepository());

  group('UsersStarted', () {
    blocTest<UsersBloc, UsersState>(
      'emits loading then success with the first batch',
      setUp: () => stub(_page1, nextSince: 2, forSince: null),
      build: build,
      act: (UsersBloc bloc) => bloc.add(const UsersStarted()),
      expect: () => <Matcher>[
        isA<UsersState>()
            .having((UsersState s) => s.status, 'status', UsersStatus.loading),
        isA<UsersState>()
            .having((UsersState s) => s.status, 'status', UsersStatus.success)
            .having((UsersState s) => s.users, 'users', _page1)
            .having((UsersState s) => s.visibleUsers, 'visibleUsers', _page1)
            .having((UsersState s) => s.nextSince, 'nextSince', 2)
            .having((UsersState s) => s.hasReachedEnd, 'hasReachedEnd', false),
      ],
    );

    blocTest<UsersBloc, UsersState>(
      'is a no-op once the list has already loaded',
      setUp: () => stub(_page1, nextSince: 2, forSince: null),
      build: build,
      act: (UsersBloc bloc) async {
        bloc.add(const UsersStarted());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const UsersStarted());
      },
      verify: (_) => verify(
        repository.getUsers(
          since: null,
          perPage: anyNamed('perPage'),
          forceRefresh: anyNamed('forceRefresh'),
        ),
      ).called(1),
    );

    blocTest<UsersBloc, UsersState>(
      'a batch with no next cursor marks the end of the list',
      setUp: () => stub(_page1, forSince: null),
      build: build,
      act: (UsersBloc bloc) => bloc.add(const UsersStarted()),
      skip: 1,
      expect: () => <Matcher>[
        isA<UsersState>()
            .having((UsersState s) => s.hasReachedEnd, 'hasReachedEnd', true)
            .having((UsersState s) => s.nextSince, 'nextSince', isNull),
      ],
    );
  });

  group('UsersLoadMoreRequested (constraint a)', () {
    blocTest<UsersBloc, UsersState>(
      'appends the next batch and advances the cursor',
      setUp: () {
        stub(_page1, nextSince: 2, forSince: null);
        stub(_page2, nextSince: 4, forSince: 2);
      },
      build: build,
      act: (UsersBloc bloc) async {
        bloc.add(const UsersStarted());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const UsersLoadMoreRequested());
      },
      skip: 3,
      expect: () => <Matcher>[
        isA<UsersState>()
            .having((UsersState s) => s.users, 'users',
                <UserSummary>[..._page1, ..._page2])
            .having((UsersState s) => s.nextSince, 'nextSince', 4)
            .having((UsersState s) => s.isLoadingMore, 'isLoadingMore', false),
      ],
    );

    blocTest<UsersBloc, UsersState>(
      'does nothing once the end has been reached -- no wasted request',
      setUp: () => stub(_page1, forSince: null),
      build: build,
      act: (UsersBloc bloc) async {
        bloc.add(const UsersStarted());
        await Future<void>.delayed(Duration.zero);
        bloc
          ..add(const UsersLoadMoreRequested())
          ..add(const UsersLoadMoreRequested());
      },
      verify: (_) => verifyNever(
        repository.getUsers(
          since: argThat(isNotNull, named: 'since'),
          perPage: anyNamed('perPage'),
          forceRefresh: anyNamed('forceRefresh'),
        ),
      ),
    );

    blocTest<UsersBloc, UsersState>(
      'droppable(): a burst of scroll events issues ONE request',
      setUp: () {
        stub(_page1, nextSince: 2, forSince: null);
        when(
          repository.getUsers(
            since: 2,
            perPage: anyNamed('perPage'),
            forceRefresh: anyNamed('forceRefresh'),
          ),
        ).thenAnswer((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return Right<Failure, PaginatedUsers>(
            PaginatedUsers.fromBatch(users: _page2, nextSince: 4),
          );
        });
      },
      build: build,
      act: (UsersBloc bloc) async {
        bloc.add(const UsersStarted());
        await Future<void>.delayed(Duration.zero);
        bloc
          ..add(const UsersLoadMoreRequested())
          ..add(const UsersLoadMoreRequested())
          ..add(const UsersLoadMoreRequested());
      },
      wait: const Duration(milliseconds: 120),
      verify: (_) => verify(
        repository.getUsers(
          since: 2,
          perPage: anyNamed('perPage'),
          forceRefresh: anyNamed('forceRefresh'),
        ),
      ).called(1),
    );

    blocTest<UsersBloc, UsersState>(
      'ignores load-more before the first batch has produced a cursor',
      build: build,
      act: (UsersBloc bloc) => bloc.add(const UsersLoadMoreRequested()),
      expect: () => <UsersState>[],
      verify: (_) => verifyZeroInteractions(repository),
    );
  });

  group('UsersSearchChanged (constraint e)', () {
    blocTest<UsersBloc, UsersState>(
      'filters visibleUsers but never touches the loaded list or cursor',
      setUp: () => stub(_page1, nextSince: 2, forSince: null),
      build: build,
      act: (UsersBloc bloc) async {
        bloc.add(const UsersStarted());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const UsersSearchChanged('mojo'));
      },
      wait: const Duration(milliseconds: 20),
      skip: 2,
      expect: () => <Matcher>[
        isA<UsersState>()
            .having(
                (UsersState s) =>
                    s.visibleUsers.map((UserSummary u) => u.login),
                'visibleUsers',
                <String>['mojombo'])
            .having((UsersState s) => s.users, 'users is untouched', _page1)
            .having((UsersState s) => s.nextSince, 'cursor survives', 2)
            .having((UsersState s) => s.isFiltering, 'isFiltering', true),
      ],
    );

    blocTest<UsersBloc, UsersState>(
      'clearing the query restores the full list',
      setUp: () => stub(_page1, nextSince: 2, forSince: null),
      build: build,
      act: (UsersBloc bloc) async {
        bloc.add(const UsersStarted());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const UsersSearchChanged('mojo'));
        await Future<void>.delayed(const Duration(milliseconds: 20));
        bloc.add(const UsersSearchChanged(''));
      },
      wait: const Duration(milliseconds: 20),
      skip: 3,
      expect: () => <Matcher>[
        isA<UsersState>()
            .having((UsersState s) => s.visibleUsers, 'visibleUsers', _page1)
            .having((UsersState s) => s.isFiltering, 'isFiltering', false),
      ],
    );

    blocTest<UsersBloc, UsersState>(
      'debounces: a burst of keystrokes filters once',
      setUp: () => stub(_page1, nextSince: 2, forSince: null),
      build: () => build(debounce: const Duration(milliseconds: 100)),
      act: (UsersBloc bloc) async {
        bloc.add(const UsersStarted());
        await Future<void>.delayed(const Duration(milliseconds: 10));
        bloc
          ..add(const UsersSearchChanged('m'))
          ..add(const UsersSearchChanged('mo'))
          ..add(const UsersSearchChanged('moj'));
      },
      wait: const Duration(milliseconds: 250),
      skip: 2,
      expect: () => <Matcher>[
        isA<UsersState>().having((UsersState s) => s.query, 'query', 'moj'),
      ],
    );
  });

  group('UsersRefreshRequested', () {
    blocTest<UsersBloc, UsersState>(
      'restarts the walk from the beginning with forceRefresh',
      setUp: () {
        stub(_page1, nextSince: 2, forSince: null, forceRefresh: false);
        stub(_page2, nextSince: 4, forSince: 2, forceRefresh: false);
        stub(<UserSummary>[_u(9, 'octocat')],
            nextSince: 9, forSince: null, forceRefresh: true);
      },
      build: build,
      act: (UsersBloc bloc) async {
        bloc.add(const UsersStarted());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const UsersLoadMoreRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const UsersRefreshRequested());
      },
      skip: 5,
      expect: () => <Matcher>[
        isA<UsersState>()
            .having((UsersState s) => s.users.map((UserSummary u) => u.login),
                'list replaced, not appended', <String>['octocat'])
            .having((UsersState s) => s.nextSince, 'cursor reset', 9)
            .having((UsersState s) => s.isRefreshing, 'isRefreshing', false),
      ],
      verify: (_) => verify(
        repository.getUsers(
          since: null,
          perPage: anyNamed('perPage'),
          forceRefresh: true,
        ),
      ).called(1),
    );
  });

  group('failures', () {
    blocTest<UsersBloc, UsersState>(
      'a cold failure is blocking -- nothing to show behind it',
      setUp: () => stubFailure(const NetworkFailure()),
      build: build,
      act: (UsersBloc bloc) => bloc.add(const UsersStarted()),
      skip: 1,
      expect: () => <Matcher>[
        isA<UsersState>()
            .having((UsersState s) => s.hasBlockingFailure, 'blocking', true)
            .having((UsersState s) => s.hasInlineFailure, 'inline', false),
      ],
    );

    blocTest<UsersBloc, UsersState>(
      'a failure mid-list is inline and PRESERVES the loaded users',
      setUp: () {
        stub(_page1, nextSince: 2, forSince: null);
        when(
          repository.getUsers(
            since: 2,
            perPage: anyNamed('perPage'),
            forceRefresh: anyNamed('forceRefresh'),
          ),
        ).thenAnswer(
          (_) async => const Left<Failure, PaginatedUsers>(ServerFailure()),
        );
      },
      build: build,
      act: (UsersBloc bloc) async {
        bloc.add(const UsersStarted());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const UsersLoadMoreRequested());
      },
      skip: 3,
      expect: () => <Matcher>[
        isA<UsersState>()
            .having((UsersState s) => s.users, 'users survive', _page1)
            .having((UsersState s) => s.hasInlineFailure, 'inline', true)
            .having((UsersState s) => s.hasBlockingFailure, 'blocking', false)
            .having((UsersState s) => s.isLoadingMore, 'spinner cleared', false),
      ],
    );

    blocTest<UsersBloc, UsersState>(
      'a rate limit surfaces resetAt for the countdown (constraint d)',
      setUp: () =>
          stubFailure(RateLimitFailure(resetAt: DateTime.utc(2026, 9, 9, 12))),
      build: build,
      act: (UsersBloc bloc) => bloc.add(const UsersStarted()),
      skip: 1,
      expect: () => <Matcher>[
        isA<UsersState>().having(
          (UsersState s) => s.rateLimitFailure?.resetAt,
          'resetAt',
          DateTime.utc(2026, 9, 9, 12),
        ),
      ],
    );

    blocTest<UsersBloc, UsersState>(
      'retry resumes from the current cursor -- it does not restart the list',
      setUp: () {
        stub(_page1, nextSince: 2, forSince: null);
        when(
          repository.getUsers(
            since: 2,
            perPage: anyNamed('perPage'),
            forceRefresh: anyNamed('forceRefresh'),
          ),
        ).thenAnswer(
          (_) async => const Left<Failure, PaginatedUsers>(ServerFailure()),
        );
      },
      build: build,
      act: (UsersBloc bloc) async {
        bloc.add(const UsersStarted());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const UsersLoadMoreRequested());
        await Future<void>.delayed(Duration.zero);
        stub(_page2, nextSince: 4, forSince: 2);
        bloc.add(const UsersRetryRequested());
      },
      skip: 5,
      expect: () => <Matcher>[
        isA<UsersState>()
            .having((UsersState s) => s.users, 'appended, not replaced',
                <UserSummary>[..._page1, ..._page2])
            .having((UsersState s) => s.failure, 'failure cleared', isNull),
      ],
    );
  });

  group('deduplication', () {
    blocTest<UsersBloc, UsersState>(
      'an overlapping batch does not duplicate users',
      setUp: () {
        stub(_page1, nextSince: 2, forSince: null);
        stub(<UserSummary>[_u(2, 'defunkt'), _u(3, 'pjhyett')],
            nextSince: 3, forSince: 2);
      },
      build: build,
      act: (UsersBloc bloc) async {
        bloc.add(const UsersStarted());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const UsersLoadMoreRequested());
      },
      skip: 3,
      expect: () => <Matcher>[
        isA<UsersState>().having(
          (UsersState s) => s.users.map((UserSummary u) => u.id),
          'ids are unique',
          <int>[1, 2, 3],
        ),
      ],
    );
  });
}
