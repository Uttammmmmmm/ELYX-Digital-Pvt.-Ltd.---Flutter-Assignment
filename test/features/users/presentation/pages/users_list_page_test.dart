@Timeout(Duration(seconds: 15))
library;

// NOTE ON BLOC DISPOSAL: these tests deliberately do NOT close the bloc.
// `Bloc.close()` never completes inside `testWidgets`, whose clock is faked --
// it completes normally in a plain `test()` and in `bloc_test`, both of which
// run in a real async zone, and `BlocProvider` never awaits it in production.
// Awaiting it here (directly, via addTearDown, or via runAsync) deadlocks the
// isolate hard enough that even the test timeout cannot fire. The blocs die
// with the test isolate.

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
import 'package:elyx_digital_assignment/features/users/presentation/pages/users_list_page.dart';
import 'package:elyx_digital_assignment/features/users/presentation/widgets/user_list_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../../../../helpers/mocks.mocks.dart';
import '../../../../helpers/widget_harness.dart';

GithubUser _user(int id, String login) => GithubUser(
      id: id,
      login: login,
      avatarUrl: 'https://avatars.githubusercontent.com/u/$id?v=4',
      htmlUrl: 'https://github.com/$login',
      type: 'User',
      isSiteAdmin: false,
    );

final List<GithubUser> _users = <GithubUser>[
  _user(1, 'mojombo'),
  _user(2, 'defunkt'),
];

void main() {
  late MockUserRepository repository;

  setUp(() {
    installFakeAvatars();
    repository = MockUserRepository();
    when(repository.cachedDisplayNames())
        .thenAnswer((_) async => const <String, String>{});
    when(repository.clearUsersCache()).thenAnswer((_) async {});
  });

  tearDown(restoreAvatars);

  UsersBloc buildBloc() => UsersBloc(
        getUsers: GetUsers(repository),
        refreshUsers: RefreshUsers(repository),
        filterUsers: const FilterUsers(),
        repository: repository,
        searchDebounce: Duration.zero,
      );

  void stubSuccess({
    List<GithubUser>? users,
    int? nextCursor,
    bool fromCache = false,
    DateTime? cachedAt,
  }) {
    final UsersPage page =
        UsersPage(users: users ?? _users, nextCursor: nextCursor);
    when(
      repository.getUsers(
        cursor: anyNamed('cursor'),
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

  void stubFailure(Failure failure) => when(
        repository.getUsers(
          cursor: anyNamed('cursor'),
          forceRefresh: anyNamed('forceRefresh'),
        ),
      ).thenAnswer(
        (_) async => Left<Failure, Sourced<UsersPage>>(failure),
      );

  Future<UsersBloc> pumpList(WidgetTester tester) async {
    final UsersBloc bloc = buildBloc()..add(const UsersStarted());
    await tester.pumpWidget(
      wrapForTest(
        BlocProvider<UsersBloc>.value(
          value: bloc,
          child: const UsersListView(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return bloc;
  }

  testWidgets('shows a skeleton before the first page arrives', (
    WidgetTester tester,
  ) async {
    stubSuccess(nextCursor: 2);
    final UsersBloc bloc = buildBloc();

    await tester.pumpWidget(
      wrapForTest(
        BlocProvider<UsersBloc>.value(value: bloc, child: const UsersListView()),
      ),
    );
    await tester.pump(); // initial frame only -- do not settle

    expect(find.byType(UserListTile), findsNothing);
    expect(find.byType(CircleAvatar), findsWidgets, reason: 'skeleton rows');
  });

  testWidgets('renders one tile per user', (WidgetTester tester) async {
    stubSuccess(nextCursor: 2);
    await pumpList(tester);

    expect(find.byType(UserListTile), findsNWidgets(2));
    expect(find.text('mojombo'), findsOneWidget);
    expect(find.text('defunkt'), findsOneWidget);
  });

  testWidgets('typing filters the visible tiles', (WidgetTester tester) async {
    stubSuccess(nextCursor: 2);
    await pumpList(tester);

    await tester.enterText(find.byKey(const Key('user_search_field')), 'mojo');
    await tester.pumpAndSettle();

    expect(find.text('mojombo'), findsOneWidget);
    expect(find.text('defunkt'), findsNothing);
  });

  testWidgets('a search with no match explains the client-side limit, '
      'not "user does not exist" (constraint e)', (WidgetTester tester) async {
    stubSuccess(nextCursor: 2);
    await pumpList(tester);

    await tester.enterText(find.byKey(const Key('user_search_field')), 'zzzz');
    await tester.pumpAndSettle();

    expect(find.byType(UserListTile), findsNothing);
    expect(find.textContaining('GitHub has no name filter'), findsOneWidget);
    expect(find.text('Load more users'), findsOneWidget);
  });

  testWidgets('clearing the query restores every tile', (
    WidgetTester tester,
  ) async {
    stubSuccess(nextCursor: 2);
    await pumpList(tester);

    await tester.enterText(find.byKey(const Key('user_search_field')), 'mojo');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('search_clear_button')));
    await tester.pumpAndSettle();

    expect(find.byType(UserListTile), findsNWidgets(2));
  });

  testWidgets('a cold failure shows a blocking error with Retry', (
    WidgetTester tester,
  ) async {
    stubFailure(const NetworkFailure());
    await pumpList(tester);

    expect(find.byKey(const Key('error_message')), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.byType(UserListTile), findsNothing);
  });

  testWidgets('Retry re-requests and recovers', (WidgetTester tester) async {
    stubFailure(const NetworkFailure());
    await pumpList(tester);

    stubSuccess(nextCursor: 2);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.byType(UserListTile), findsNWidgets(2));
  });

  testWidgets('a rate limit shows a countdown and DISABLES retry '
      '(constraint d)', (WidgetTester tester) async {
    stubFailure(
      RateLimitFailure(resetAt: DateTime.now().add(const Duration(minutes: 42))),
    );
    await pumpList(tester);

    expect(find.byKey(const Key('rate_limit_countdown')), findsOneWidget);
    expect(find.textContaining('Access returns in'), findsOneWidget);
    expect(find.textContaining('41m'), findsOneWidget);

    final FilledButton button =
        tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull,
        reason: 'a Retry guaranteed to fail is worse than none');
  });

  testWidgets('the rate-limit view suggests a token when none is set', (
    WidgetTester tester,
  ) async {
    stubFailure(
      RateLimitFailure(resetAt: DateTime.now().add(const Duration(minutes: 5))),
    );
    await pumpList(tester);

    expect(find.textContaining('GITHUB_TOKEN'), findsOneWidget);
  });

  testWidgets('cached data shows the stale banner', (
    WidgetTester tester,
  ) async {
    stubSuccess(
      nextCursor: 2,
      fromCache: true,
      cachedAt: DateTime.now().subtract(const Duration(minutes: 20)),
    );
    await pumpList(tester);

    expect(find.byKey(const Key('stale_banner_text')), findsOneWidget);
    expect(find.textContaining('Showing saved data'), findsOneWidget);
    expect(find.textContaining('20 minutes ago'), findsOneWidget);
  });

  testWidgets('live data shows no stale banner', (WidgetTester tester) async {
    stubSuccess(nextCursor: 2);
    await pumpList(tester);

    expect(find.byKey(const Key('stale_banner_text')), findsNothing);
  });

  testWidgets('the end of the list is marked', (WidgetTester tester) async {
    stubSuccess(); // no next cursor
    await pumpList(tester);

    expect(find.byKey(const Key('pagination_end')), findsOneWidget);
    expect(find.text('No more users'), findsOneWidget);
  });

  testWidgets('pull to refresh re-requests the first page', (
    WidgetTester tester,
  ) async {
    stubSuccess(nextCursor: 2);
    await pumpList(tester);

    await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    verify(repository.clearUsersCache()).called(1);
  });
}
