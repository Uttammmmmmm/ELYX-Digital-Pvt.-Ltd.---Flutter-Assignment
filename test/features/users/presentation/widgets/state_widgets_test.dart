@Timeout(Duration(seconds: 15))
library;

import 'package:elyx_digital_assignment/core/error/failures.dart';
import 'package:elyx_digital_assignment/features/users/domain/entities/user_summary.dart';
import 'package:elyx_digital_assignment/features/users/presentation/widgets/empty_view.dart';
import 'package:elyx_digital_assignment/features/users/presentation/widgets/error_view.dart';
import 'package:elyx_digital_assignment/features/users/presentation/widgets/loading_view.dart';
import 'package:elyx_digital_assignment/features/users/presentation/widgets/no_search_results_view.dart';
import 'package:elyx_digital_assignment/features/users/presentation/widgets/offline_banner.dart';
import 'package:elyx_digital_assignment/features/users/presentation/widgets/pagination_footer.dart';
import 'package:elyx_digital_assignment/features/users/presentation/widgets/rate_limit_view.dart';
import 'package:elyx_digital_assignment/features/users/presentation/widgets/user_list_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/widget_harness.dart';

const UserSummary _user = UserSummary(
  id: 1,
  detailId: 'mojombo',
      handle: 'mojombo',
  avatarUrl: 'https://avatars.githubusercontent.com/u/1?v=4',
  profileUrl: 'https://github.com/mojombo',
  accountType: 'User',
);

/// Each state widget in isolation, found by the Keys the pages rely on.
/// Isolated rather than through the page, so a failure points at one widget.
void main() {
  setUp(installFakeAvatars);
  tearDown(restoreAvatars);

  /// [settle] must be false for anything containing a
  /// CircularProgressIndicator: its animation schedules frames forever, so
  /// pumpAndSettle never settles and the test times out instead of failing.
  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    bool settle = true,
  }) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(wrapForTest(Scaffold(body: child)));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  group('LoadingView', () {
    testWidgets('renders 8 skeleton rows, not a spinner', (
      WidgetTester tester,
    ) async {
      await pump(tester, const LoadingView());

      expect(find.byKey(const Key('loading_view')), findsOneWidget);
      expect(find.byType(CircleAvatar), findsNWidgets(8));
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('EmptyView vs NoSearchResultsView are distinct', () {
    testWidgets('EmptyView says no users exist', (WidgetTester tester) async {
      await pump(tester, const EmptyView());

      expect(find.byKey(const Key('empty_view')), findsOneWidget);
      expect(find.text('No users available'), findsOneWidget);
      expect(find.byKey(const Key('clear_search_button')), findsNothing);
    });

    testWidgets('NoSearchResultsView names the query and the loaded count', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        NoSearchResultsView(
          query: 'zzzz',
          loadedCount: 40,
          onClearSearch: () {},
          onLoadMore: () {},
        ),
      );

      expect(find.byKey(const Key('no_search_results_view')), findsOneWidget);
      expect(find.byKey(const Key('empty_view')), findsNothing);
      expect(find.textContaining('zzzz'), findsOneWidget);
      expect(find.textContaining('40 users'), findsOneWidget);
      expect(find.byKey(const Key('clear_search_button')), findsOneWidget);
    });

    testWidgets('Clear search fires its callback', (WidgetTester tester) async {
      bool cleared = false;
      await pump(
        tester,
        NoSearchResultsView(
          query: 'zzzz',
          loadedCount: 2,
          onClearSearch: () => cleared = true,
        ),
      );

      await tester.tap(find.byKey(const Key('clear_search_button')));
      expect(cleared, isTrue);
    });

    testWidgets('Load more is hidden at the end of the list', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        NoSearchResultsView(
          query: 'zzzz',
          loadedCount: 2,
          onClearSearch: () {},
        ),
      );

      expect(find.byKey(const Key('search_load_more_button')), findsNothing);
    });
  });

  group('ErrorView', () {
    testWidgets('shows the failure message and a working Retry', (
      WidgetTester tester,
    ) async {
      bool retried = false;
      await pump(
        tester,
        ErrorView(
          failure: const NetworkFailure(),
          onRetry: () => retried = true,
        ),
      );

      expect(find.byKey(const Key('error_view')), findsOneWidget);
      expect(find.byKey(const Key('error_message')), findsOneWidget);
      expect(find.textContaining('offline'), findsOneWidget);

      await tester.tap(find.byKey(const Key('error_retry_button')));
      expect(retried, isTrue);
    });
  });

  group('RateLimitView', () {
    testWidgets('shows the reset time and DISABLES retry until then', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        RateLimitView(
          resetAt: DateTime.now().add(const Duration(minutes: 30)),
          onRetry: () {},
        ),
      );

      expect(find.byKey(const Key('rate_limit_view')), findsOneWidget);
      expect(find.textContaining('Limit resets at'), findsOneWidget);

      final FilledButton button = tester.widget<FilledButton>(
        find.byKey(const Key('rate_limit_retry_button')),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('enables retry once the window has already reopened', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        RateLimitView(
          resetAt: DateTime.now().subtract(const Duration(minutes: 1)),
          onRetry: () {},
        ),
      );

      final FilledButton button = tester.widget<FilledButton>(
        find.byKey(const Key('rate_limit_retry_button')),
      );
      expect(button.onPressed, isNotNull);
      expect(find.textContaining('try again now'), findsOneWidget);
    });
  });

  group('PaginationFooter', () {
    testWidgets('loading mode shows a spinner', (WidgetTester tester) async {
      await pump(
        tester,
        const PaginationFooter(mode: PaginationFooterMode.loading),
        settle: false,
      );
      expect(find.byKey(const Key('pagination_loading')), findsOneWidget);
    });

    testWidgets('error mode shows the message and an inline Retry', (
      WidgetTester tester,
    ) async {
      bool retried = false;
      await pump(
        tester,
        PaginationFooter(
          mode: PaginationFooterMode.error,
          errorMessage: 'Boom',
          onRetry: () => retried = true,
        ),
      );

      expect(find.byKey(const Key('pagination_error')), findsOneWidget);
      expect(find.text('Boom'), findsOneWidget);

      await tester.tap(find.byKey(const Key('pagination_retry_button')));
      expect(retried, isTrue);
    });

    testWidgets('end mode says so', (WidgetTester tester) async {
      await pump(tester, const PaginationFooter(mode: PaginationFooterMode.end));

      expect(find.byKey(const Key('pagination_end')), findsOneWidget);
      expect(find.text("You've reached the end"), findsOneWidget);
    });

    testWidgets('idle mode renders nothing visible', (
      WidgetTester tester,
    ) async {
      await pump(tester, const PaginationFooter(mode: PaginationFooterMode.idle));

      expect(find.byKey(const Key('pagination_idle')), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('OfflineBanner', () {
    testWidgets('assumes online before the stream emits', (
      WidgetTester tester,
    ) async {
      await pump(tester, OfflineBanner(isOnline: const Stream<bool>.empty()));

      expect(find.byKey(const Key('offline_banner')), findsNothing,
          reason: 'flashing an offline bar on every cold start cries wolf');
    });

    testWidgets('appears when the stream reports offline', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        OfflineBanner(isOnline: Stream<bool>.value(false)),
      );

      expect(find.byKey(const Key('offline_banner')), findsOneWidget);
    });
  });

  group('UserListTile', () {
    testWidgets('renders the display name and identifier, and fires onTap', (
      WidgetTester tester,
    ) async {
      bool tapped = false;
      await pump(
        tester,
        UserListTile(user: _user, onTap: () => tapped = true),
      );

      // A GitHub-shaped user has no name, so displayName is the handle and
      // the subtitle repeats it as the @handle.
      expect(find.text('mojombo'), findsOneWidget);
      expect(find.text('@mojombo'), findsOneWidget);

      await tester.tap(find.byType(UserListTile));
      expect(tapped, isTrue);
    });

    testWidgets('a very long login ellipsizes instead of overflowing', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        UserListTile(
          // 39 characters is GitHub's maximum login length.
          user: const UserSummary(
            id: 2,
            detailId: 'a-very-long-github-login-name-abcdefghi',
      handle: 'a-very-long-github-login-name-abcdefghi',
            avatarUrl: '',
            profileUrl: '',
            accountType: 'User',
          ),
          onTap: () {},
        ),
      );

      expect(tester.takeException(), isNull);
      final Text title = tester.widget<Text>(
        find.text('a-very-long-github-login-name-abcdefghi'),
      );
      expect(title.maxLines, 1);
      expect(title.overflow, TextOverflow.ellipsis);
    });

    testWidgets('an Organization gets a type badge', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        UserListTile(
          user: const UserSummary(
            id: 3,
            detailId: 'github',
      handle: 'github',
            avatarUrl: '',
            profileUrl: '',
            accountType: 'Organization',
          ),
          onTap: () {},
        ),
      );

      expect(find.text('Organization'), findsWidgets);
    });
  });
}
