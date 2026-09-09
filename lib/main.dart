/// Application entry point.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'core/di/injection_container.dart' as di;
import 'core/storage/hive_initializer.dart';

/// Boots the app.
///
/// Everything runs inside [runZonedGuarded] so that an async error with no
/// local handler is logged rather than silently swallowed. Two handlers are
/// needed, not one: [FlutterError.onError] catches errors raised inside the
/// framework's synchronous build/layout/paint phases, while the zone handler
/// catches uncaught async errors that never pass through the framework at
/// all -- a failed `Future` in a Bloc handler, for instance. Neither covers
/// the other.
///
/// Both are debug-only reporting today. In production this is where Crashlytics
/// or Sentry would be called instead; the seam exists so adding one is a
/// two-line change rather than a refactor.
Future<void> main() async {
  runZonedGuarded<Future<void>>(
    () async {
      // Must be inside the zone: binding initialisation installs the
      // framework's own error plumbing, and doing it outside would attach it
      // to the root zone instead of ours.
      WidgetsFlutterBinding.ensureInitialized();

      FlutterError.onError = (FlutterErrorDetails details) {
        // Preserve the framework's formatting, then add our own hook.
        FlutterError.presentError(details);
        _report(details.exception, details.stack, context: 'FlutterError');
      };

      // Errors from the engine that never reach the framework (image decode,
      // platform channels). Returning true marks them handled.
      PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
        _report(error, stack, context: 'PlatformDispatcher');
        return true;
      };

      // ORDER: Hive must be ready before DI, because the container registers
      // the already-open boxes as concrete singletons.
      final HiveBoxes boxes = await HiveInitializer.init();
      await di.init(boxes: boxes);

      runApp(const ElyxApp());
    },
    (Object error, StackTrace stack) =>
        _report(error, stack, context: 'runZonedGuarded'),
  );
}

/// Single reporting seam. Debug-only; swap for a crash reporter in release.
void _report(Object error, StackTrace? stack, {required String context}) {
  if (!kDebugMode) return;
  debugPrint('[$context] $error');
  if (stack != null) debugPrintStack(stackTrace: stack, maxFrames: 12);
}
