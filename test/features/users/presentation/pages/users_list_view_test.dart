@Timeout(Duration(seconds: 15))
library;

// NOTE ON BLOC DISPOSAL: these tests deliberately do NOT close the bloc.
// `Bloc.close()` never completes inside `testWidgets`, whose clock is faked --
// it completes normally in a plain `test()` and in `bloc_test`, both of which
// run in a real async zone, and `BlocProvider` never awaits it in production.
// Awaiting it here deadlocks the isolate hard enough that even the test
// timeout cannot fire. The blocs die with the test isolate.

import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:elyx_digital_assignment/core/error/failures.dart';
import 'package:elyx_digital_assignment/features/users/domain/entities/paginated_users.dart';
import 'package:elyx_digital_assignment/features/users/domain/entities/user_summary.dart';
import 'package:elyx_digital_assignment/features/users/domain/usecases/filter_users.dart';
import 'package:elyx_digital_assignment/features/users/domain/usecases/get_users.dart';
import 'package:elyx_digital_assignment/features/users/presentation/bloc/users_bloc.dart';
import 'package:elyx_digital_assignment/features/users/presentation/bloc/users_event.dart';
import 'package:elyx_digital_assignment/features/users/presentation/pages/users_list_view.dart';
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
  late StreamController<bool> connectivity;

  setUp(() {
    installFakeAvatars();
    repository = MockUserRepository();
    connectivity = StreamController<bool>.broadcast();
  });

  tearDown(() {
    restoreAvatars();
    connectivity.close();
  });

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

  Future<void> pump(WidgetTester tester, {bool fetch = true}) async {
    final UsersBloc bloc = buildBloc();
    if (fetch) bloc.add(const UsersFetched());

    await tester.pumpWidget(
      wrapForTest(
        BlocProvider<UsersBloc>.value(
          value: bloc,
          child: UsersListView(connectivity: connectivity.stream),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('loading', () {
    testWidgets('shows skeleton tiles, not a bare spinner', (
      WidgetTester tester,
    ) async {
      stubSuccess(nextSince: 2);
      await pump(tester, fetch: false);

      expect(find.byKey(const Key('loading_view')), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('list', () {
    testWidgets('renders one keyed tile per visible user', (
      WidgetTester tester,
    ) async {
      stubSuccess(nextSince: 2);
      await pump(tester);

      expect(find.byKey(const Key('users_list')), findsOneWidget);
      expect(find.byType(UserListTile), findsNWidgets(2));
      expect(find.byKey(const Key('user_tile_1')), findsOneWidget);
      expect(find.byKey(const Key('user_tile_2')), findsOneWidget);
    });

    testWidgets('shows the end-of-list footer', (WidgetTester tester) async {
      stubSuccess(); // no cursor -> end
      await pump(tester);

      expect(find.byKey(const Key('pagination_end')), findsOneWidget);
      expect(find.text("You've reached the end"), findsOneWidget);
    });
  });

  group('search', () {
    testWidgets('filters tiles as the query is typed', (
      WidgetTester tester,
    ) async {
      stubSuccess(nextSince: 2);
      await pump(tester);

      await tester.enterText(
          find.byKey(const Key('user_search_field')), 'mojo');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('user_tile_1')), findsOneWidget);
      expect(find.byKey(const Key('user_tile_2')), findsNothing);
    });

    testWidgets('no match shows NoSearchResultsView, distinct from empty', (
      WidgetTester tester,
    ) async {
      stubSuccess(nextSince: 2);
      await pump(tester);

      await tester.enterText(
          find.byKey(const Key('user_search_field')), 'zzzz');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('no_search_results_view')), findsOneWidget);
      expect(find.byKey(const Key('empty_view')), findsNothing);
      expect(find.textContaining('no username filter'), findsOneWidget);
    });

    testWidgets('Clear search restores the list', (WidgetTester tester) async {
      stubSuccess(nextSince: 2);
      await pump(tester);

      await tester.enterText(
          find.byKey(const Key('user_search_field')), 'zzzz');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('clear_search_button')));
      await tester.pumpAndSettle();

      expect(find.byType(UserListTile), findsNWidgets(2));
    });

    testWidgets('the footer is hidden entirely while filtering', (
      WidgetTester tester,
    ) async {
      stubSuccess(); // end of list, so the end footer would show unfiltered
      await pump(tester);
      expect(find.byKey(const Key('pagination_end')), findsOneWidget);

      await tester.enterText(
          find.byKey(const Key('user_search_field')), 'mojo');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('pagination_end')), findsNothing,
          reason: '"end" under a filter would read as "no more matches exist"');
    });
  });

  group('empty', () {
    testWidgets('an empty API result shows EmptyView', (
      WidgetTester tester,
    ) async {
      stubSuccess(users: const <UserSummary>[]);
      await pump(tester);

      expect(find.byKey(const Key('empty_view')), findsOneWidget);
      expect(find.text('No users available'), findsOneWidget);
    });
  });

  group('errors', () {
    testWidgets('a cold failure shows ErrorView with Retry', (
      WidgetTester tester,
    ) async {
      stubFailure(const NetworkFailure());
      await pump(tester);

      expect(find.byKey(const Key('error_view')), findsOneWidget);
      expect(find.byKey(const Key('error_retry_button')), findsOneWidget);
    });

    testWidgets('Retry recovers', (WidgetTester tester) async {
      stubFailure(const NetworkFailure());
      await pump(tester);

      stubSuccess(nextSince: 2);
      await tester.tap(find.byKey(const Key('error_retry_button')));
      await tester.pumpAndSettle();

      expect(find.byType(UserListTile), findsNWidgets(2));
    });

    testWidgets('a rate limit shows the reset time and DISABLES retry', (
      WidgetTester tester,
    ) async {
      stubFailure(
        RateLimitFailure(
          resetAt: DateTime.now().add(const Duration(minutes: 42)),
        ),
      );
      await pump(tester);

      expect(find.byKey(const Key('rate_limit_view')), findsOneWidget);
      expect(find.textContaining('Limit resets at'), findsOneWidget);

      final FilledButton button = tester.widget<FilledButton>(
        find.byKey(const Key('rate_limit_retry_button')),
      );
      expect(button.onPressed, isNull,
          reason: 'a retry guaranteed to fail invites repeated 403s');
    });
  });

  group('offline banner', () {
    testWidgets('hidden while online, shown when connectivity drops', (
      WidgetTester tester,
    ) async {
      stubSuccess(nextSince: 2);
      await pump(tester);

      expect(find.byKey(const Key('offline_banner')), findsNothing);

      connectivity.add(false);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('offline_banner')), findsOneWidget);
      expect(find.textContaining('showing saved users'), findsOneWidget);

      connectivity.add(true);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('offline_banner')), findsNothing);
    });
  });

  group('viewport fill', () {
    testWidgets('a short first page requests the next one automatically', (
      WidgetTester tester,
    ) async {
      // Two tiles cannot fill the 600px test viewport, so maxScrollExtent is
      // 0 and the scroll listener can never fire. Without the post-frame
      // fill, pagination would stall here forever.
      stubSuccess(nextSince: 2);
      await pump(tester);

      verify(
        repository.getUsers(
          since: 2,
          perPage: anyNamed('perPage'),
          forceRefresh: anyNamed('forceRefresh'),
        ),
      ).called(greaterThanOrEqualTo(1));
    });
  });

  group('pull to refresh', () {
    testWidgets('dispatches a forced refresh', (WidgetTester tester) async {
      stubSuccess(); // end of list, so no auto viewport fill
      await pump(tester);

      await tester.fling(
          find.byKey(const Key('users_list')), const Offset(0, 400), 1000);
      await tester.pumpAndSettle();

      verify(
        repository.getUsers(
          since: null,
          perPage: anyNamed('perPage'),
          forceRefresh: true,
        ),
      ).called(1);
    });
  });
}
