@Timeout(Duration(seconds: 20))
library;

import 'package:elyx_digital_assignment/core/error/failures.dart';
import 'package:elyx_digital_assignment/features/users/presentation/widgets/empty_view.dart';
import 'package:elyx_digital_assignment/features/users/presentation/widgets/error_view.dart';
import 'package:elyx_digital_assignment/features/users/presentation/widgets/no_search_results_view.dart';
import 'package:elyx_digital_assignment/features/users/presentation/widgets/rate_limit_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/widget_harness.dart';

/// REGRESSION: RateLimitView overflowed by 4px on a real device.
///
/// The state widgets are ~300dp of Column. Any container shorter than that --
/// a landscape phone, the detail screen's remaining space under the header,
/// or a raised system font size -- produced a RenderFlex overflow, and the
/// striped banner covered the Retry button. So the error was not merely ugly:
/// it hid the only control that could recover from it.
///
/// These pump every full-screen state at heights that used to break, and
/// assert no exception was recorded. `tester.takeException()` is what catches
/// a RenderFlex overflow.
void main() {
  /// Heights that reproduced the bug, plus the pathological case.
  const List<Size> viewports = <Size>[
    Size(400, 300), // the detail screen's leftover space
    Size(568, 320), // iPhone SE landscape
    Size(320, 568), // iPhone SE portrait
    Size(400, 200), // pathological
  ];

  Widget rateLimit() => RateLimitView(
    resetAt: DateTime.now().add(const Duration(minutes: 42)),
    onRetry: () {},
  );

  Widget error() => const ErrorView(failure: NetworkFailure(), onRetry: _noop);

  Widget empty() => const EmptyView();

  Widget noResults() => NoSearchResultsView(
    query: 'zzzz',
    loadedCount: 40,
    onClearSearch: () {},
    onLoadMore: () {},
  );

  final Map<String, Widget Function()> states = <String, Widget Function()>{
    'RateLimitView': rateLimit,
    'ErrorView': error,
    'EmptyView': empty,
    'NoSearchResultsView': noResults,
  };

  for (final MapEntry<String, Widget Function()> entry in states.entries) {
    for (final Size size in viewports) {
      testWidgets('${entry.key} does not overflow at ${size.width.toInt()}x'
          '${size.height.toInt()}', (WidgetTester tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(wrapForTest(Scaffold(body: entry.value())));
        await tester.pump();

        expect(
          tester.takeException(),
          isNull,
          reason: '${entry.key} overflowed at $size',
        );
      });
    }
  }

  testWidgets('the Retry button stays reachable on a short screen', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(400, 300);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrapForTest(Scaffold(body: rateLimit())));
    await tester.pump();

    // Scroll the state view to bring the button into view, then confirm it
    // is really there -- an overflow would have clipped it entirely.
    await tester.dragUntilVisible(
      find.byKey(const Key('rate_limit_retry_button')),
      find.byType(SingleChildScrollView),
      const Offset(0, -60),
    );
    await tester.pump();

    expect(find.byKey(const Key('rate_limit_retry_button')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('still centres vertically when there IS room', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrapForTest(Scaffold(body: empty())));
    await tester.pumpAndSettle();

    final double iconY = tester.getCenter(find.byIcon(Icons.people_outline)).dy;
    expect(
      iconY,
      greaterThan(200),
      reason: 'content should not be hugging the top on a tall screen',
    );
    expect(tester.takeException(), isNull);
  });
}

void _noop() {}
