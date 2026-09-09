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
import 'package:elyx_digital_assignment/features/users/domain/entities/paginated_users.dart';
import 'package:elyx_digital_assignment/features/users/domain/entities/user_summary.dart';
import 'package:elyx_digital_assignment/features/users/domain/usecases/filter_users.dart';
import 'package:elyx_digital_assignment/features/users/domain/usecases/get_users.dart';
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

UserSummary _u(int id, String login) => UserSummary(
      id: id,
      login: login,
      avatarUrl: 'https://avatars.githubusercontent.com/u/$id?v=4',
      htmlUrl: 'https://github.com/$login',
      type: 'User',
      siteAdmin: false,
    );

final List<UserSummary> _users = <UserSummary>[
  _u(1, 'mojombo'),
  _u(2, 'defunkt'),
];

void main() {
  late MockUserRepository repository;

  setUp(() {
    installFakeAvatars();
    repository = MockUserRepository();
  });

  tearDown(restoreAvatars);

  UsersBloc buildBloc() => UsersBloc(
        getUsers: GetUsers(repository),
        filterUsers: const FilterUsers(),
        searchDebounce: Duration.zero,
      );

  void stubSuccess({List<UserSummary>? users, int? nextSince}) => when(
        repository.getUsers(
          since: anyNamed('since'),
          perPage: anyNamed('perPage'),
          forceRefresh: anyNamed('forceRefresh'),
        ),
      ).thenAnswer(
        (_) async => Right<Failure, PaginatedUsers>(
          PaginatedUsers.fromBatch(
            users: users ?? _users,
            nextSince: nextSince,
          ),
        ),
      );

  void stubFailure(Failure failure) => when(
        repository.getUsers(
          since: anyNamed('since'),
          perPage: anyNamed('perPage'),
          forceRefresh: anyNamed('forceRefresh'),
        ),
      ).thenAnswer((_) async => Left<Failure, PaginatedUsers>(failure));

  Future<void> pumpList(WidgetTester tester) async {
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
  }

  testWidgets('shows a skeleton before the first batch arrives', (
    WidgetTester tester,
  ) async {
    stubSuccess(nextSince: 2);
    await tester.pumpWidget(
      wrapForTest(
        BlocProvider<UsersBloc>.value(
          value: buildBloc(),
          child: const UsersListView(),
        ),
      ),
    );
    await tester.pump(); // initial frame only -- do not settle

    expect(find.byType(UserListTile), findsNothing);
    expect(find.byType(CircleAvatar), findsWidgets, reason: 'skeleton rows');
  });

  testWidgets('renders one tile per user', (WidgetTester tester) async {
    stubSuccess(nextSince: 2);
    await pumpList(tester);

    expect(find.byType(UserListTile), findsNWidgets(2));
    expect(find.text('mojombo'), findsOneWidget);
    expect(find.text('defunkt'), findsOneWidget);
  });

  testWidgets('typing filters the visible tiles', (WidgetTester tester) async {
    stubSuccess(nextSince: 2);
    await pumpList(tester);

    await tester.enterText(find.byKey(const Key('user_search_field')), 'mojo');
    await tester.pumpAndSettle();

    expect(find.text('mojombo'), findsOneWidget);
    expect(find.text('defunkt'), findsNothing);
  });

  testWidgets('a regex metacharacter in the field does not throw or wildcard '
      '(constraint e)', (WidgetTester tester) async {
    stubSuccess(nextSince: 2);
    await pumpList(tester);

    await tester.enterText(
      find.byKey(const Key('user_search_field')),
      'm.jombo',
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(UserListTile), findsNothing);
  });

  testWidgets('a search with no match explains the client-side limit, '
      'not "user does not exist"', (WidgetTester tester) async {
    stubSuccess(nextSince: 2);
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
    stubSuccess(nextSince: 2);
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

    stubSuccess(nextSince: 2);
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

  testWidgets('the end of the list is marked', (WidgetTester tester) async {
    stubSuccess(); // no next cursor
    await pumpList(tester);

    expect(find.byKey(const Key('pagination_end')), findsOneWidget);
    expect(find.text('No more users'), findsOneWidget);
  });

  testWidgets('pull to refresh restarts the walk with forceRefresh', (
    WidgetTester tester,
  ) async {
    stubSuccess(nextSince: 2);
    await pumpList(tester);

    await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    verify(
      repository.getUsers(
        since: null,
        perPage: anyNamed('perPage'),
        forceRefresh: true,
      ),
    ).called(1);
  });
}
