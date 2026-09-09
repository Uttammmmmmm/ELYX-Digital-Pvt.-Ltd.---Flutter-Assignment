/// Generic failure state with a retry affordance.
library;

import 'package:flutter/material.dart';

import '../error/failures.dart';
import 'rate_limit_view.dart';

/// Full-screen error with a Retry button.
///
/// Dispatches to [RateLimitView] for a [RateLimitFailure] so the rate-limit
/// case gets its countdown and disabled Retry rather than a button the user
/// can mash to no effect. Callers render this one widget and get the right
/// treatment automatically.
class AppErrorView extends StatelessWidget {
  const AppErrorView({required this.failure, required this.onRetry, super.key});

  /// What went wrong. Its `message` is already user-facing copy.
  final Failure failure;

  /// Invoked when the user taps Retry.
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final Failure f = failure;
    if (f is RateLimitFailure) {
      return RateLimitView(failure: f, onRetry: onRetry);
    }

    final ThemeData theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              switch (f) {
                NetworkFailure() => Icons.wifi_off,
                NotFoundFailure() => Icons.person_off,
                CacheFailure() => Icons.inbox,
                _ => Icons.error_outline,
              },
              size: 48,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              f.message,
              key: const Key('error_message'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
