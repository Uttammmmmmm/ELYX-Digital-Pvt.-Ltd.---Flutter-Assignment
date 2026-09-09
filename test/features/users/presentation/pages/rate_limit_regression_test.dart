@Timeout(Duration(seconds: 25))
library;

// REGRESSION tests for two bugs found running against the live GitHub API.
//
//  1. A 429 mid-pagination put the bloc in `failure` while `canLoadMore` was
//     still true, so the scroll listener refired the SAME cursor in a loop --
//     hammering an endpoint that had already rejected us, and burning the
//     remaining quota. (Rejected requests still count against the limit.)
//  2. The list used `ListView.builder(itemExtent:)`, which applies to EVERY
//     child including the footer slot. The error footer (message + Retry) is
//     taller than a row, so it overflowed by ~32px and clipped the button --
//     hiding the only control that could recover.

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
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../../../../helpers/mocks.mocks.dart';
import '../../../../helpers/widget_harness.dart';

UserSummary _u(int id) => UserSummary(
      id: id,
      detailId: 'user$id',
      handle: 'user$id',
      avatarUrl: '',
      profileUrl: 'https://github.com/user$id',
      accountType: 'User',
    );

/// Enough rows to overflow a phone viewport, so the list really scrolls.
final List<UserSummary> _firstPage =
    List<UserSummary>.generate(20, (int i) => _u(i + 1));

void main() {
  late MockUserRepository repository;
  late StreamController<bool> connectivity;

  setUp(() {
    installFakeAvatars();
    repository = MockUserRepository();
    // Cold-start seed: no prior cache unless a test says otherwise.
    when(repository.getCachedUsers())
        .thenAnswer((_) async => const <UserSummary>[]);
    connectivity = StreamController<bool>.broadcast();
  });

  tearDown(() {
    restoreAvatars();
    connectivity.close();
  });

  Future<UsersBloc> pump(WidgetTester tester, {Size? size}) async {
    tester.view.physicalSize = size ?? const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final UsersBloc bloc = UsersBloc(
      getUsers: GetUsers(repository),
      filterUsers: const FilterUsers(),
      repository: repository,
      searchDebounce: Duration.zero,
    )..add(const UsersFetched());

    await tester.pumpWidget(
      wrapForTest(
        BlocProvider<UsersBloc>.value(
          value: bloc,
          child: UsersListView(connectivity: connectivity.stream),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return bloc;
  }

  /// First page succeeds; every later cursor is rate limited, as GitHub did.
  void stubRateLimitedAfterFirstPage() {
    when(
      repository.getUsers(
        cursor: null,
        perPage: anyNamed('perPage'),
        forceRefresh: anyNamed('forceRefresh'),
      ),
    ).thenAnswer(
      (_) async => Right<Failure, PaginatedUsers>(
        PaginatedUsers.fromBatch(users: _firstPage, nextCursor: 2868),
      ),
    );
    when(
      repository.getUsers(
        cursor: 2868,
        perPage: anyNamed('perPage'),
        forceRefresh: anyNamed('forceRefresh'),
      ),
    ).thenAnswer(
      (_) async => Left<Failure, PaginatedUsers>(
        RateLimitFailure(resetAt: DateTime.now().add(const Duration(minutes: 30))),
      ),
    );
  }

  group('bug 1 - the retry storm', () {
    testWidgets('a 429 mid-pagination does NOT refire the same cursor', (
      WidgetTester tester,
    ) async {
      stubRateLimitedAfterFirstPage();
      await pump(tester);

      // Drive the bottom of the list repeatedly, exactly as a user bouncing
      // at the end would.
      for (int i = 0; i < 6; i++) {
        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -400));
        await tester.pump(const Duration(milliseconds: 30));
      }
      await tester.pumpAndSettle();

      verify(
        repository.getUsers(
          cursor: 2868,
          perPage: anyNamed('perPage'),
          forceRefresh: anyNamed('forceRefresh'),
        ),
      ).called(1);
    });

    testWidgets('canLoadMore is false while rate limited', (
      WidgetTester tester,
    ) async {
      stubRateLimitedAfterFirstPage();
      final UsersBloc bloc = await pump(tester);

      // Far enough to cross the load-more threshold near the bottom.
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -2000));
      await tester.pumpAndSettle();

      expect(bloc.state.isRateLimited, isTrue);
      expect(bloc.state.canLoadMore, isFalse);
      expect(bloc.state.allUsers, hasLength(20),
          reason: 'the loaded rows must survive the failure');
    });

    testWidgets('an explicit retry is also refused while the quota is spent', (
      WidgetTester tester,
    ) async {
      stubRateLimitedAfterFirstPage();
      final UsersBloc bloc = await pump(tester);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -2000));
      await tester.pumpAndSettle();
      clearInteractions(repository);

      bloc.add(const UsersFailedPageRetried());
      await tester.pumpAndSettle();

      verifyNever(
        repository.getUsers(
          cursor: anyNamed('cursor'),
          perPage: anyNamed('perPage'),
          forceRefresh: anyNamed('forceRefresh'),
        ),
      );
    });
  });

  group('bug 2 - the footer overflow', () {
    testWidgets('the inline error footer does not overflow the row extent', (
      WidgetTester tester,
    ) async {
      stubRateLimitedAfterFirstPage();
      await pump(tester);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -2000));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull,
          reason: 'the footer must size itself, not inherit the row extent');
      expect(find.byKey(const Key('pagination_error')), findsOneWidget);
    });

    testWidgets('the Retry button is fully rendered, not clipped', (
      WidgetTester tester,
    ) async {
      stubRateLimitedAfterFirstPage();
      await pump(tester);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -2000));
      await tester.pumpAndSettle();

      final Finder retry = find.byKey(const Key('pagination_retry_button'));
      expect(retry, findsOneWidget);
      // A clipped button would report a height smaller than the Material
      // minimum tap target.
      expect(tester.getSize(retry).height, greaterThanOrEqualTo(36));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the loaded rows stay on screen through the failure', (
      WidgetTester tester,
    ) async {
      stubRateLimitedAfterFirstPage();
      await pump(tester);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -2000));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('user_tile_20')), findsOneWidget);
      expect(find.byKey(const Key('error_view')), findsNothing,
          reason: 'a mid-list failure must not take over the whole screen');
    });
  });
}
