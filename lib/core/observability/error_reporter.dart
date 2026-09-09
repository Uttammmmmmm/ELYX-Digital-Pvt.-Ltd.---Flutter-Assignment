library;

import 'dart:collection';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

@immutable
class Breadcrumb {
  const Breadcrumb({required this.message, required this.at});

  final String message;
  final DateTime at;

  @override
  String toString() => '${at.toIso8601String()} $message';
}

abstract interface class ErrorReporter {
  void recordError(
    Object error,
    StackTrace? stack, {
    required String context,
    bool fatal,
  });

  void addBreadcrumb(String message);

  List<Breadcrumb> get breadcrumbs;
}

class LoggingErrorReporter implements ErrorReporter {
  LoggingErrorReporter({this.maxBreadcrumbs = 50, DateTime Function()? clock})
    : _now = clock ?? DateTime.now;

  final int maxBreadcrumbs;
  final DateTime Function() _now;

  final Queue<Breadcrumb> _breadcrumbs = Queue<Breadcrumb>();

  @override
  List<Breadcrumb> get breadcrumbs =>
      List<Breadcrumb>.unmodifiable(_breadcrumbs);

  @override
  void addBreadcrumb(String message) {
    _breadcrumbs.addLast(Breadcrumb(message: message, at: _now()));
    while (_breadcrumbs.length > maxBreadcrumbs) {
      _breadcrumbs.removeFirst();
    }
  }

  @override
  void recordError(
    Object error,
    StackTrace? stack, {
    required String context,
    bool fatal = false,
  }) {
    developer.log(
      error.toString(),
      name: 'elyx.$context',
      level: fatal ? 1000 : 900,
      error: error,
      stackTrace: stack,
    );

    if (kDebugMode) {
      debugPrint('[$context] $error');
      if (stack != null) debugPrintStack(stackTrace: stack, maxFrames: 12);
    }
  }
}

class NoopErrorReporter implements ErrorReporter {
  const NoopErrorReporter();

  @override
  void addBreadcrumb(String message) {}

  @override
  List<Breadcrumb> get breadcrumbs => const <Breadcrumb>[];

  @override
  void recordError(
    Object error,
    StackTrace? stack, {
    required String context,
    bool fatal = false,
  }) {}
}
