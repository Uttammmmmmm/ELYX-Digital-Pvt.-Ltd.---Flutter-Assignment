library;

import 'package:elyx_digital_assignment/core/observability/error_reporter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LoggingErrorReporter', () {
    test('records breadcrumbs in order', () {
      final LoggingErrorReporter reporter = LoggingErrorReporter()
        ..addBreadcrumb('first')
        ..addBreadcrumb('second');

      expect(reporter.breadcrumbs.map((Breadcrumb b) => b.message), <String>[
        'first',
        'second',
      ]);
    });

    test('evicts the OLDEST breadcrumb once the cap is reached', () {
      final LoggingErrorReporter reporter = LoggingErrorReporter(
        maxBreadcrumbs: 3,
      );

      for (int i = 1; i <= 5; i++) {
        reporter.addBreadcrumb('crumb$i');
      }

      expect(reporter.breadcrumbs, hasLength(3));
      expect(
        reporter.breadcrumbs.map((Breadcrumb b) => b.message),
        <String>['crumb3', 'crumb4', 'crumb5'],
        reason: 'a ring buffer keeps the most RECENT context, not the first',
      );
    });

    test('the exposed breadcrumb list cannot be mutated by callers', () {
      final LoggingErrorReporter reporter = LoggingErrorReporter()
        ..addBreadcrumb('only');

      expect(
        () => reporter.breadcrumbs.add(
          Breadcrumb(message: 'injected', at: DateTime.now()),
        ),
        throwsUnsupportedError,
      );
    });

    test('stamps each breadcrumb with the injected clock', () {
      final DateTime fixed = DateTime.utc(2026, 9, 9, 12);
      final LoggingErrorReporter reporter = LoggingErrorReporter(
        clock: () => fixed,
      )..addBreadcrumb('stamped');

      expect(reporter.breadcrumbs.single.at, fixed);
    });

    test('recording an error never throws, with or without a stack', () {
      final LoggingErrorReporter reporter = LoggingErrorReporter();

      expect(
        () => reporter.recordError(
          StateError('boom'),
          StackTrace.current,
          context: 'test',
          fatal: true,
        ),
        returnsNormally,
      );
      expect(
        () =>
            reporter.recordError(Exception('no stack'), null, context: 'test'),
        returnsNormally,
      );
    });
  });

  group('NoopErrorReporter', () {
    test('discards everything and stays empty', () {
      const NoopErrorReporter reporter = NoopErrorReporter();
      reporter.addBreadcrumb('ignored');

      reporter.recordError(StateError('boom'), null, context: 'test');

      expect(reporter.breadcrumbs, isEmpty);
    });
  });
}
