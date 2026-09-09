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
      // platform channels).
      PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
        _report(error, stack, context: 'PlatformDispatcher');
        // Returning true marks the error HANDLED and stops it propagating.
        // That is only honest while something is actually handling it -- in
        // debug, the log below. In release `_report` is a no-op, so returning
        // true would discard every uncaught async error with no log, no crash
        // and no report: the app would fail silently in exactly the builds
        // where that is hardest to diagnose. So release lets it through to
        // the platform, which at least records it.
        return kDebugMode;
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

/// THE CRASH-REPORTER SEAM.
///
/// Every uncaught error in the app funnels through here. Wiring Crashlytics
/// or Sentry means adding one call in this function -- e.g.
/// `FirebaseCrashlytics.instance.recordError(error, stack)` -- and nothing
/// else changes. Until then it logs in debug and, in release, deliberately
/// declines to mark errors handled (see PlatformDispatcher.onError above) so
/// the platform still records them.
void _report(Object error, StackTrace? stack, {required String context}) {
  if (!kDebugMode) return;
  debugPrint('[$context] $error');
  if (stack != null) debugPrintStack(stackTrace: stack, maxFrames: 12);
}
