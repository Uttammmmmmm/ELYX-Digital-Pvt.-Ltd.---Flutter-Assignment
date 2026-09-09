library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'core/di/injection_container.dart' as di;
import 'core/observability/error_reporter.dart';
import 'core/storage/hive_initializer.dart';

Future<void> main() async {
  final ErrorReporter reporter = LoggingErrorReporter();

  runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
        reporter.recordError(
          details.exception,
          details.stack,
          context: 'FlutterError',
        );
      };

      PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
        reporter.recordError(
          error,
          stack,
          context: 'PlatformDispatcher',
          fatal: true,
        );

        return false;
      };

      reporter.addBreadcrumb('hive:init');
      final HiveBoxes boxes = await HiveInitializer.init();

      reporter.addBreadcrumb('di:init');
      await di.init(boxes: boxes, reporter: reporter);

      reporter.addBreadcrumb('runApp');
      runApp(const ElyxApp());
    },
    (Object error, StackTrace stack) => reporter.recordError(
      error,
      stack,
      context: 'runZonedGuarded',
      fatal: true,
    ),
  );
}
