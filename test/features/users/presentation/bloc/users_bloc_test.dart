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
      detailId: login,
      handle: login,
      avatarUrl: 'https://avatars.githubusercontent.com/u/$id?v=4',
      profileUrl: 'https://github.com/$login',
      accountType: 'User',
    );

final List<UserSummary> _page1 = <UserSummary>[_u(1, 'mojombo'), _u(2, 'defunkt')];
final List<UserSummary> _page2 = <UserSummary>[_u(3, 'pjhyett'), _u(4, 'wycats')];

/// Zero real network: the repository is mocked and the use cases are real, so
/// the bloc -> use case -> repository wiring is exercised rather than stubbed.
void main() {
  late MockUserRepository repository;

  UsersBloc build({Duration debounce = Duration.zero}) => UsersBloc(
        getUsers: GetUsers(repository),
        filterUsers: const FilterUsers(),
        repository: repository,
        searchDebounce: debounce,
      );

  void stub(
    List<UserSummary> users, {
    Object? nextCursor,
    Object? forCursor,
    bool? forceRefresh,
  }) {
    when(
      repository.getUsers(
        cursor: forCursor,
        perPage: anyNamed('perPage'),
        forceRefresh: forceRefresh ?? anyNamed('forceRefresh'),
      ),
    ).thenAnswer(
      (_) async => Right<Failure, PaginatedUsers>(
        PaginatedUsers.fromBatch(users: users, nextCursor: nextCursor),
      ),
    );
  }

  void stubFailure(Failure failure, {Object? forCursor}) => when(
        repository.getUsers(
          cursor: forCursor,
          perPage: anyNamed('perPage'),
          forceRefresh: anyNamed('forceRefresh'),
        ),
      ).thenAnswer((_) async => Left<Failure, PaginatedUsers>(failure));

  setUp(() {
    repository = MockUserRepository();
    // Cold-start seed: no prior cache unless a test says otherwise.
    when(repository.getCachedUsers())
        .thenAnswer((_) async => const <UserSummary>[]);
  });

  // 1 --------------------------------------------------------------------
  blocTest<UsersBloc, UsersState>(
    'UsersFetched emits loading then success with the first page',
    setUp: () => stub(_page1, nextCursor: 2, forCursor: null),
    build: build,
    act: (UsersBloc bloc) => bloc.add(const UsersFetched()),
    expect: () => <Matcher>[
      isA<UsersState>()
          .having((UsersState s) => s.status, 'status', UsersStatus.loading),
      isA<UsersState>()
          .having((UsersState s) => s.status, 'status', UsersStatus.success)
          .having((UsersState s) => s.allUsers, 'allUsers', _page1)
          .having((UsersState s) => s.visibleUsers, 'visibleUsers', _page1)
          .having((UsersState s) => s.nextCursor, 'nextSince', 2)
          .having((UsersState s) => s.hasReachedEnd, 'hasReachedEnd', false),
    ],
  );

  // 1b -------------------------------------------------------------------
  blocTest<UsersBloc, UsersState>(
    'UsersFetched is idempotent -- a second one does not refetch',
    setUp: () => stub(_page1, nextCursor: 2, forCursor: null),
    build: build,
    act: (UsersBloc bloc) async {
      bloc.add(const UsersFetched());
      await Future<void>.delayed(Duration.zero);
      bloc.add(const UsersFetched());
    },
    verify: (_) => verify(
      repository.getUsers(
        cursor: null,
        perPage: anyNamed('perPage'),
        forceRefresh: anyNamed('forceRefresh'),
      ),
    ).called(1),
  );

  // 2 --------------------------------------------------------------------
  blocTest<UsersBloc, UsersState>(
    'UsersNextPageRequested appends the next page and advances the cursor',
    setUp: () {
      stub(_page1, nextCursor: 2, forCursor: null);
      stub(_page2, nextCursor: 4, forCursor: 2);
    },
    build: build,
    act: (UsersBloc bloc) async {
      bloc.add(const UsersFetched());
      await Future<void>.delayed(Duration.zero);
      bloc.add(const UsersNextPageRequested());
    },
    skip: 2,
    expect: () => <Matcher>[
      isA<UsersState>()
          .having((UsersState s) => s.status, 'status', UsersStatus.loadingMore)
          .having((UsersState s) => s.allUsers, 'list kept during load', _page1),
      isA<UsersState>()
          .having((UsersState s) => s.status, 'status', UsersStatus.success)
          .having((UsersState s) => s.allUsers, 'allUsers',
              <UserSummary>[..._page1, ..._page2])
          .having((UsersState s) => s.nextCursor, 'nextSince', 4),
    ],
  );

  // 3 --------------------------------------------------------------------
  blocTest<UsersBloc, UsersState>(
    'droppable(): duplicate scroll events issue exactly ONE request',
    setUp: () {
      stub(_page1, nextCursor: 2, forCursor: null);
      when(
        repository.getUsers(
          cursor: 2,
          perPage: anyNamed('perPage'),
          forceRefresh: anyNamed('forceRefresh'),
        ),
      ).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return Right<Failure, PaginatedUsers>(
          PaginatedUsers.fromBatch(users: _page2, nextCursor: 4),
        );
      });
    },
    build: build,
    act: (UsersBloc bloc) async {
      bloc.add(const UsersFetched());
      await Future<void>.delayed(Duration.zero);
      bloc
        ..add(const UsersNextPageRequested())
        ..add(const UsersNextPageRequested())
        ..add(const UsersNextPageRequested());
    },
    wait: const Duration(milliseconds: 120),
    verify: (UsersBloc bloc) {
      verify(
        repository.getUsers(
          cursor: 2,
          perPage: anyNamed('perPage'),
          forceRefresh: anyNamed('forceRefresh'),
        ),
      ).called(1);
      // And the page was appended exactly once -- no duplicates.
      expect(bloc.state.allUsers.map((UserSummary u) => u.id), <int>[1, 2, 3, 4]);
    },
  );

  // 4 --------------------------------------------------------------------
  blocTest<UsersBloc, UsersState>(
    'no request once hasReachedEnd, and none before a cursor exists',
    setUp: () => stub(_page1, forCursor: null), // no nextSince -> end
    build: build,
    act: (UsersBloc bloc) async {
      // Before the first page: nextSince is null, so this must be ignored.
      bloc.add(const UsersNextPageRequested());
      bloc.add(const UsersFetched());
      await Future<void>.delayed(Duration.zero);
      bloc
        ..add(const UsersNextPageRequested())
        ..add(const UsersNextPageRequested());
    },
    verify: (UsersBloc bloc) {
      expect(bloc.state.hasReachedEnd, isTrue);
      expect(bloc.state.canLoadMore, isFalse);
      verifyNever(
        repository.getUsers(
          cursor: argThat(isNotNull, named: 'cursor'),
          perPage: anyNamed('perPage'),
          forceRefresh: anyNamed('forceRefresh'),
        ),
      );
    },
  );

  // 5 --------------------------------------------------------------------
  blocTest<UsersBloc, UsersState>(
    'error mid-pagination KEEPS allUsers and nextSince so retry resumes',
    setUp: () {
      stub(_page1, nextCursor: 2, forCursor: null);
      stubFailure(const ServerFailure(), forCursor: 2);
    },
    build: build,
    act: (UsersBloc bloc) async {
      bloc.add(const UsersFetched());
      await Future<void>.delayed(Duration.zero);
      bloc.add(const UsersNextPageRequested());
      await Future<void>.delayed(Duration.zero);
      // Now the same cursor succeeds.
      stub(_page2, nextCursor: 4, forCursor: 2);
      bloc.add(const UsersFailedPageRetried());
    },
    // Emitted: loading, success, loadingMore, failure, loadingMore, success.
    skip: 3,
    expect: () => <Matcher>[
      // The failure preserved progress...
      isA<UsersState>()
          .having((UsersState s) => s.status, 'status', UsersStatus.failure)
          .having((UsersState s) => s.allUsers, 'users survive', _page1)
          .having((UsersState s) => s.nextCursor, 'cursor survives', 2)
          .having((UsersState s) => s.hasInlineFailure, 'inline, not blocking',
              true),
      // ...so the retry resumes from cursor 2 rather than restarting.
      isA<UsersState>()
          .having((UsersState s) => s.status, 'status', UsersStatus.loadingMore),
      isA<UsersState>()
          .having((UsersState s) => s.allUsers, 'appended, not replaced',
              <UserSummary>[..._page1, ..._page2])
          .having((UsersState s) => s.failure, 'failure cleared', isNull),
    ],
  );

  // 6 --------------------------------------------------------------------
  blocTest<UsersBloc, UsersState>(
    'a cold failure is blocking and exposes rateLimitResetAt for the countdown',
    setUp: () => stubFailure(
      RateLimitFailure(resetAt: DateTime.utc(2026, 9, 9, 12)),
      forCursor: null,
    ),
    build: build,
    act: (UsersBloc bloc) => bloc.add(const UsersFetched()),
    skip: 1,
    expect: () => <Matcher>[
      isA<UsersState>()
          .having((UsersState s) => s.hasBlockingFailure, 'blocking', true)
          .having((UsersState s) => s.rateLimitResetAt, 'resetAt',
              DateTime.utc(2026, 9, 9, 12))
          .having((UsersState s) => s.isEmpty, 'isEmpty', true),
    ],
  );

  // 7 --------------------------------------------------------------------
  blocTest<UsersBloc, UsersState>(
    'search filters visibleUsers without a network call or cursor reset',
    setUp: () => stub(_page1, nextCursor: 2, forCursor: null),
    build: build,
    act: (UsersBloc bloc) async {
      bloc.add(const UsersFetched());
      await Future<void>.delayed(Duration.zero);
      bloc.add(const UsersSearchQueryChanged('mojo'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      bloc.add(const UsersSearchCleared());
    },
    wait: const Duration(milliseconds: 20),
    skip: 2,
    expect: () => <Matcher>[
      isA<UsersState>()
          .having((UsersState s) => s.visibleUsers.map((UserSummary u) => u.displayName),
              'filtered', <String>['mojombo'])
          .having((UsersState s) => s.allUsers, 'allUsers untouched', _page1)
          .having((UsersState s) => s.nextCursor, 'cursor untouched', 2)
          .having((UsersState s) => s.isSearchEmpty, 'has matches', false),
      isA<UsersState>()
          .having((UsersState s) => s.visibleUsers, 'restored', _page1)
          .having((UsersState s) => s.isFiltering, 'isFiltering', false),
    ],
    verify: (_) => verify(
      repository.getUsers(
        cursor: null,
        perPage: anyNamed('perPage'),
        forceRefresh: anyNamed('forceRefresh'),
      ),
    ).called(1),
  );

  // 7b -------------------------------------------------------------------
  blocTest<UsersBloc, UsersState>(
    'debounce collapses a burst of keystrokes into a single filter',
    setUp: () => stub(_page1, nextCursor: 2, forCursor: null),
    build: () => build(debounce: const Duration(milliseconds: 100)),
    act: (UsersBloc bloc) async {
      bloc.add(const UsersFetched());
      await Future<void>.delayed(const Duration(milliseconds: 10));
      bloc
        ..add(const UsersSearchQueryChanged('m'))
        ..add(const UsersSearchQueryChanged('mo'))
        ..add(const UsersSearchQueryChanged('moj'));
    },
    wait: const Duration(milliseconds: 250),
    skip: 2,
    expect: () => <Matcher>[
      // One state, for the LAST query only -- not three.
      isA<UsersState>()
          .having((UsersState s) => s.searchQuery, 'query', 'moj')
          .having((UsersState s) => s.visibleUsers.length, 'matches', 1),
    ],
  );

  // 8 --------------------------------------------------------------------
  blocTest<UsersBloc, UsersState>(
    'refresh keeps the old list on screen, then replaces it and dedupes',
    setUp: () {
      stub(_page1, nextCursor: 2, forCursor: null, forceRefresh: false);
      stub(
        <UserSummary>[_u(1, 'mojombo'), _u(9, 'octocat')],
        nextCursor: 9,
        forCursor: null,
        forceRefresh: true,
      );
    },
    build: build,
    act: (UsersBloc bloc) async {
      bloc.add(const UsersFetched());
      await Future<void>.delayed(Duration.zero);
      bloc.add(const UsersRefreshed());
    },
    skip: 2,
    expect: () => <Matcher>[
      // Mid-refresh: status changed, list NOT blanked.
      isA<UsersState>()
          .having((UsersState s) => s.status, 'status', UsersStatus.refreshing)
          .having((UsersState s) => s.allUsers, 'old list still shown', _page1),
      isA<UsersState>()
          .having((UsersState s) => s.status, 'status', UsersStatus.success)
          .having((UsersState s) => s.allUsers.map((UserSummary u) => u.displayName),
              'replaced, not appended', <String>['mojombo', 'octocat'])
          .having((UsersState s) => s.nextCursor, 'cursor restarted', 9),
    ],
    verify: (_) => verify(
      repository.getUsers(
        cursor: null,
        perPage: anyNamed('perPage'),
        forceRefresh: true,
      ),
    ).called(1),
  );

  // Extra: the isClosed guard.
  blocTest<UsersBloc, UsersState>(
    'closing mid-request does not emit on a closed bloc (back navigation)',
    setUp: () => when(
      repository.getUsers(
        cursor: anyNamed('cursor'),
        perPage: anyNamed('perPage'),
        forceRefresh: anyNamed('forceRefresh'),
      ),
    ).thenAnswer((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return Right<Failure, PaginatedUsers>(
        PaginatedUsers.fromBatch(users: _page1, nextCursor: 2),
      );
    }),
    build: build,
    act: (UsersBloc bloc) async {
      bloc.add(const UsersFetched());
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await bloc.close(); // user tapped back before the page landed
      await Future<void>.delayed(const Duration(milliseconds: 80));
    },
    errors: () => <Matcher>[],
  );
}
