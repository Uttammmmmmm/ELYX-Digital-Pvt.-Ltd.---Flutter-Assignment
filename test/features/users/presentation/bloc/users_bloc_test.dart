import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:elyx_digital_assignment/core/error/failures.dart';
import 'package:elyx_digital_assignment/core/models/sourced.dart';
import 'package:elyx_digital_assignment/features/users/domain/entities/github_user.dart';
import 'package:elyx_digital_assignment/features/users/domain/entities/users_page.dart';
import 'package:elyx_digital_assignment/features/users/domain/usecases/filter_users.dart';
import 'package:elyx_digital_assignment/features/users/domain/usecases/get_users.dart';
import 'package:elyx_digital_assignment/features/users/domain/usecases/refresh_users.dart';
import 'package:elyx_digital_assignment/features/users/presentation/bloc/users_bloc.dart';
import 'package:elyx_digital_assignment/features/users/presentation/bloc/users_event.dart';
import 'package:elyx_digital_assignment/features/users/presentation/bloc/users_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../../../../helpers/mocks.mocks.dart';

GithubUser _user(int id, String login) => GithubUser(
      id: id,
      login: login,
      avatarUrl: 'https://avatars.githubusercontent.com/u/$id?v=4',
      htmlUrl: 'https://github.com/$login',
      type: 'User',
      isSiteAdmin: false,
    );

final List<GithubUser> _page1 = <GithubUser>[
  _user(1, 'mojombo'),
  _user(2, 'defunkt'),
];
final List<GithubUser> _page2 = <GithubUser>[
  _user(3, 'pjhyett'),
  _user(4, 'wycats'),
];

/// Debounce is set to zero in most tests so `bloc_test` need not wait; the
/// debounce behaviour itself gets its own test with a real duration.
void main() {
  late MockUserRepository repository;

  UsersBloc build({Duration debounce = Duration.zero}) => UsersBloc(
        getUsers: GetUsers(repository),
        refreshUsers: RefreshUsers(repository),
        filterUsers: const FilterUsers(),
        repository: repository,
        searchDebounce: debounce,
      );

  void stubPage(
    List<GithubUser> users, {
    int? nextCursor,
    int? forCursor,
    bool fromCache = false,
    DateTime? cachedAt,
  }) {
    final UsersPage page = UsersPage(users: users, nextCursor: nextCursor);
    when(
      repository.getUsers(
        cursor: forCursor,
        forceRefresh: anyNamed('forceRefresh'),
      ),
    ).thenAnswer(
      (_) async => Right<Failure, Sourced<UsersPage>>(
        fromCache
            ? Sourced<UsersPage>.cache(page, cachedAt ?? DateTime.now())
            : Sourced<UsersPage>.network(page),
      ),
    );
  }

  setUp(() {
    repository = MockUserRepository();
    when(repository.cachedDisplayNames())
        .thenAnswer((_) async => const <String, String>{});
    when(repository.clearUsersCache()).thenAnswer((_) async {});
  });

  group('UsersStarted', () {
    blocTest<UsersBloc, UsersState>(
      'emits loading then success with the first page',
      setUp: () => stubPage(_page1, nextCursor: 2, forCursor: null),
      build: build,
      act: (UsersBloc bloc) => bloc.add(const UsersStarted()),
      expect: () => <Matcher>[
        isA<UsersState>()
            .having((UsersState s) => s.status, 'status', UsersStatus.loading),
        isA<UsersState>()
            .having((UsersState s) => s.status, 'status', UsersStatus.success)
            .having((UsersState s) => s.users, 'users', _page1)
            .having((UsersState s) => s.visibleUsers, 'visibleUsers', _page1)
            .having((UsersState s) => s.cursor, 'cursor', 2)
            .having((UsersState s) => s.hasReachedEnd, 'hasReachedEnd', false),
      ],
    );

    blocTest<UsersBloc, UsersState>(
      'is a no-op once the list has already loaded',
      setUp: () => stubPage(_page1, nextCursor: 2, forCursor: null),
      build: build,
      act: (UsersBloc bloc) async {
        bloc.add(const UsersStarted());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const UsersStarted());
      },
      verify: (_) => verify(repository.getUsers(cursor: null)).called(1),
    );

    blocTest<UsersBloc, UsersState>(
      'a page with no next cursor marks the end of the list',
      setUp: () => stubPage(_page1, forCursor: null),
      build: build,
      act: (UsersBloc bloc) => bloc.add(const UsersStarted()),
      skip: 1,
      expect: () => <Matcher>[
        isA<UsersState>()
            .having((UsersState s) => s.hasReachedEnd, 'hasReachedEnd', true)
            .having((UsersState s) => s.cursor, 'cursor', isNull),
      ],
    );
  });

  group('UsersLoadMoreRequested (constraint a)', () {
    blocTest<UsersBloc, UsersState>(
      'appends the next page and advances the cursor',
      setUp: () {
        stubPage(_page1, nextCursor: 2, forCursor: null);
        stubPage(_page2, nextCursor: 4, forCursor: 2);
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
                <GithubUser>[..._page1, ..._page2])
            .having((UsersState s) => s.cursor, 'cursor', 4)
            .having((UsersState s) => s.isLoadingMore, 'isLoadingMore', false),
      ],
      verify: (_) => verify(repository.getUsers(cursor: 2)).called(1),
    );

    blocTest<UsersBloc, UsersState>(
      'does nothing once the end has been reached -- no wasted request',
      setUp: () => stubPage(_page1, forCursor: null),
      build: build,
      act: (UsersBloc bloc) async {
        bloc.add(const UsersStarted());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const UsersLoadMoreRequested());
        bloc.add(const UsersLoadMoreRequested());
      },
      verify: (_) {
        verify(repository.getUsers(cursor: null)).called(1);
        verifyNever(repository.getUsers(cursor: anyNamed('cursor')));
      },
    );

    blocTest<UsersBloc, UsersState>(
      'droppable(): a burst of scroll events issues ONE request',
      setUp: () {
        stubPage(_page1, nextCursor: 2, forCursor: null);
        when(repository.getUsers(cursor: 2, forceRefresh: false)).thenAnswer(
          (_) async {
            await Future<void>.delayed(const Duration(milliseconds: 50));
            return Right<Failure, Sourced<UsersPage>>(
              Sourced<UsersPage>.network(
                UsersPage(users: _page2, nextCursor: 4),
              ),
            );
          },
        );
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
      verify: (_) => verify(repository.getUsers(cursor: 2)).called(1),
    );

    blocTest<UsersBloc, UsersState>(
      'ignores load-more before the first page has produced a cursor',
      build: build,
      act: (UsersBloc bloc) => bloc.add(const UsersLoadMoreRequested()),
      expect: () => <UsersState>[],
      verify: (_) => verifyNever(repository.getUsers(cursor: anyNamed('cursor'))),
    );
  });

  group('UsersSearchChanged (constraint e)', () {
    blocTest<UsersBloc, UsersState>(
      'filters visibleUsers but never touches the loaded list or cursor',
      setUp: () => stubPage(_page1, nextCursor: 2, forCursor: null),
      build: build,
      act: (UsersBloc bloc) async {
        bloc.add(const UsersStarted());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const UsersSearchChanged('mojo'));
      },
      // Even a zero debounce defers past bloc_test's default settle -- the
      // transformer really is deferring, which is the behaviour under test.
      wait: const Duration(milliseconds: 20),
      skip: 2,
      expect: () => <Matcher>[
        isA<UsersState>()
            .having((UsersState s) => s.visibleUsers.map((GithubUser u) => u.login),
                'visibleUsers', <String>['mojombo'])
            .having((UsersState s) => s.users, 'users is untouched', _page1)
            .having((UsersState s) => s.cursor, 'cursor survives', 2)
            .having((UsersState s) => s.isFiltering, 'isFiltering', true),
      ],
    );

    blocTest<UsersBloc, UsersState>(
      'clearing the query restores the full list',
      setUp: () => stubPage(_page1, nextCursor: 2, forCursor: null),
      build: build,
      act: (UsersBloc bloc) async {
        bloc.add(const UsersStarted());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const UsersSearchChanged('mojo'));
        // Must exceed the debounce, or restartable() discards the first query
        // and only the second state is ever emitted.
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
      setUp: () => stubPage(_page1, nextCursor: 2, forCursor: null),
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

    blocTest<UsersBloc, UsersState>(
      'matches a cached display name, not just the login (constraint b)',
      setUp: () {
        stubPage(_page1, nextCursor: 2, forCursor: null);
        when(repository.cachedDisplayNames()).thenAnswer(
          (_) async => const <String, String>{'mojombo': 'Tom Preston-Werner'},
        );
      },
      build: build,
      act: (UsersBloc bloc) async {
        bloc.add(const UsersStarted());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const UsersSearchChanged('preston'));
      },
      wait: const Duration(milliseconds: 20),
      skip: 2,
      expect: () => <Matcher>[
        isA<UsersState>().having(
          (UsersState s) => s.visibleUsers.map((GithubUser u) => u.login),
          'visibleUsers',
          <String>['mojombo'],
        ),
      ],
    );
  });

  group('UsersRefreshRequested', () {
    blocTest<UsersBloc, UsersState>(
      'clears the cache and replaces the list from the top',
      setUp: () {
        stubPage(_page1, nextCursor: 2, forCursor: null);
        stubPage(_page2, nextCursor: 4, forCursor: 2);
      },
      build: build,
      act: (UsersBloc bloc) async {
        bloc.add(const UsersStarted());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const UsersLoadMoreRequested());
        await Future<void>.delayed(Duration.zero);
        stubPage(<GithubUser>[_user(9, 'octocat')],
            nextCursor: 9, forCursor: null);
        bloc.add(const UsersRefreshRequested());
      },
      skip: 5,
      expect: () => <Matcher>[
        isA<UsersState>()
            .having((UsersState s) => s.users.map((GithubUser u) => u.login),
                'list replaced, not appended', <String>['octocat'])
            .having((UsersState s) => s.cursor, 'cursor reset', 9)
            .having((UsersState s) => s.isRefreshing, 'isRefreshing', false),
      ],
      verify: (_) => verify(repository.clearUsersCache()).called(1),
    );
  });

  group('failures', () {
    blocTest<UsersBloc, UsersState>(
      'a cold failure is blocking -- nothing to show behind it',
      setUp: () => when(
        repository.getUsers(
          cursor: anyNamed('cursor'),
          forceRefresh: anyNamed('forceRefresh'),
        ),
      ).thenAnswer(
        (_) async => const Left<Failure, Sourced<UsersPage>>(NetworkFailure()),
      ),
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
        stubPage(_page1, nextCursor: 2, forCursor: null);
        when(repository.getUsers(cursor: 2, forceRefresh: false)).thenAnswer(
          (_) async =>
              const Left<Failure, Sourced<UsersPage>>(ServerFailure()),
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
      setUp: () {
        final DateTime resetAt =
            DateTime(2026, 9, 8, 12).add(const Duration(minutes: 42));
        when(
          repository.getUsers(
            cursor: anyNamed('cursor'),
            forceRefresh: anyNamed('forceRefresh'),
          ),
        ).thenAnswer(
          (_) async => Left<Failure, Sourced<UsersPage>>(
            RateLimitFailure(resetAt: resetAt),
          ),
        );
      },
      build: build,
      act: (UsersBloc bloc) => bloc.add(const UsersStarted()),
      skip: 1,
      expect: () => <Matcher>[
        isA<UsersState>().having(
          (UsersState s) => s.rateLimitFailure?.resetAt,
          'resetAt',
          DateTime(2026, 9, 8, 12).add(const Duration(minutes: 42)),
        ),
      ],
    );

    blocTest<UsersBloc, UsersState>(
      'retry resumes from the current cursor -- it does not restart the list',
      setUp: () {
        stubPage(_page1, nextCursor: 2, forCursor: null);
        when(repository.getUsers(cursor: 2, forceRefresh: false)).thenAnswer(
          (_) async =>
              const Left<Failure, Sourced<UsersPage>>(ServerFailure()),
        );
      },
      build: build,
      act: (UsersBloc bloc) async {
        bloc.add(const UsersStarted());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const UsersLoadMoreRequested());
        await Future<void>.delayed(Duration.zero);
        stubPage(_page2, nextCursor: 4, forCursor: 2);
        bloc.add(const UsersRetryRequested());
      },
      skip: 5,
      expect: () => <Matcher>[
        isA<UsersState>()
            .having((UsersState s) => s.users, 'appended, not replaced',
                <GithubUser>[..._page1, ..._page2])
            .having((UsersState s) => s.failure, 'failure cleared', isNull),
      ],
    );
  });

  group('provenance', () {
    blocTest<UsersBloc, UsersState>(
      'a cache-served page is flagged so the UI can say so',
      setUp: () => stubPage(
        _page1,
        nextCursor: 2,
        forCursor: null,
        fromCache: true,
        cachedAt: DateTime(2026, 9, 8, 11, 30),
      ),
      build: build,
      act: (UsersBloc bloc) => bloc.add(const UsersStarted()),
      skip: 1,
      expect: () => <Matcher>[
        isA<UsersState>()
            .having((UsersState s) => s.isFromCache, 'isFromCache', true)
            .having((UsersState s) => s.cachedAt, 'cachedAt',
                DateTime(2026, 9, 8, 11, 30)),
      ],
    );
  });

  group('deduplication', () {
    blocTest<UsersBloc, UsersState>(
      'a page overlapping the previous one does not duplicate users',
      setUp: () {
        stubPage(_page1, nextCursor: 2, forCursor: null);
        stubPage(<GithubUser>[_user(2, 'defunkt'), _user(3, 'pjhyett')],
            nextCursor: 3, forCursor: 2);
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
          (UsersState s) => s.users.map((GithubUser u) => u.id),
          'ids are unique',
          <int>[1, 2, 3],
        ),
      ],
    );
  });
}
