/// Rate-limit error state with a live countdown.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../constants/api_constants.dart';
import '../error/failures.dart';
import '../utils/duration_format.dart';

/// Full-screen state for an exhausted GitHub rate limit. Constraint (d).
///
/// Deliberately NOT a generic error view:
///  - Retry stays DISABLED until [RateLimitFailure.resetAt]. Offering a button
///    that is guaranteed to fail is worse than offering none.
///  - The countdown ticks, so the user can see progress rather than guessing.
///  - It names the actual cause (60 requests/hour unauthenticated) and the
///    actual fix (supply a token), because "something went wrong" would leave
///    the user retrying forever.
class RateLimitView extends StatefulWidget {
  const RateLimitView({required this.failure, required this.onRetry, super.key});

  /// Carries the reset time.
  final RateLimitFailure failure;

  /// Invoked when the quota has returned and the user taps Retry.
  final VoidCallback onRetry;

  @override
  State<RateLimitView> createState() => _RateLimitViewState();
}

class _RateLimitViewState extends State<RateLimitView> {
  Timer? _ticker;
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    _remaining = widget.failure.remainingFrom(DateTime.now());
    // Cancelled as soon as it hits zero -- no point burning a frame a second
    // for a screen that is now actionable.
    _ticker = Timer.periodic(const Duration(seconds: 1), _tick);
  }

  void _tick(Timer timer) {
    if (!mounted) return;
    final Duration next = widget.failure.remainingFrom(DateTime.now());
    setState(() => _remaining = next);
    if (next == Duration.zero) timer.cancel();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool canRetry = _remaining == Duration.zero;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.hourglass_top, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              'Rate limit reached',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              widget.failure.message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Text(
              canRetry
                  ? 'You can try again now.'
                  : 'Access returns in ${formatCountdown(_remaining)}',
              key: const Key('rate_limit_countdown'),
              style: theme.textTheme.titleSmall?.copyWith(
                color: canRetry
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              // Null disables the button until the window reopens.
              onPressed: canRetry ? widget.onRetry : null,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
            if (!ApiConstants.hasToken) ...<Widget>[
              const SizedBox(height: 24),
              Text(
                'Tip: run with --dart-define=GITHUB_TOKEN=<your token> to '
                'raise the limit from 60 to 5000 requests per hour.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
