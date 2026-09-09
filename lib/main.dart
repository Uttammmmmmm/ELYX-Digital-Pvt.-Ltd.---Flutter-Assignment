library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'core/di/injection_container.dart' as di;
import 'core/storage/hive_initializer.dart';

Future<void> main() async {
  runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
        _report(details.exception, details.stack, context: 'FlutterError');
      };

      PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
        _report(error, stack, context: 'PlatformDispatcher');
        return kDebugMode;
      };

      final HiveBoxes boxes = await HiveInitializer.init();
      await di.init(boxes: boxes);

      runApp(const ElyxApp());
    },
    (Object error, StackTrace stack) =>
        _report(error, stack, context: 'runZonedGuarded'),
  );
}

void _report(Object error, StackTrace? stack, {required String context}) {
  if (!kDebugMode) return;
  debugPrint('[$context] $error');
  if (stack != null) debugPrintStack(stackTrace: stack, maxFrames: 12);
}
