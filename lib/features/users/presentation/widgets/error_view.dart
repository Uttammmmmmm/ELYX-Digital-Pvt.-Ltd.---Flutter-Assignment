/// Generic failure state with a retry affordance.
library;

import 'package:flutter/material.dart';

import '../../../../core/error/failures.dart';

/// Full-screen error with a Retry button.
///
/// Renders the [Failure]'s own message, which is already user-facing copy
/// written in the failures file -- widgets do not compose error text, so the
/// wording lives in one place and is testable without pumping a widget.
///
/// A [RateLimitFailure] must NOT be routed here; it gets `RateLimitView`,
/// which knows to disable retry until the quota returns.
class ErrorView extends StatelessWidget {
  const ErrorView({required this.failure, required this.onRetry, super.key});

  /// What went wrong.
  final Failure failure;

  /// Retry the failed request.
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Center(
      key: const Key('error_view'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              switch (failure) {
                NetworkFailure() => Icons.wifi_off,
                NotFoundFailure() => Icons.person_off,
                CacheFailure() => Icons.inbox,
                TimeoutFailure() => Icons.hourglass_disabled,
                _ => Icons.error_outline,
              },
              size: 48,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              failure.message,
              key: const Key('error_message'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              key: const Key('error_retry_button'),
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
