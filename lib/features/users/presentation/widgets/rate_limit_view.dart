/// Rate-limit state with a reset time and a disabled retry.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/utils/duration_format.dart';

/// Full-screen state for an exhausted GitHub quota. Constraint (d).
///
/// Deliberately not a generic error:
///  - Retry stays DISABLED until [resetAt]. A button guaranteed to fail is
///    worse than no button: it invites the user to keep trying, and each
///    attempt is another 403.
///  - It shows the wall-clock reset time AND a live countdown, so the wait is
///    a known quantity rather than an indefinite one.
///  - It names the real cause (60/hour unauthenticated) and the real fix (a
///    token), because "something went wrong" leaves the user retrying forever.
class RateLimitView extends StatefulWidget {
  const RateLimitView({
    required this.resetAt,
    required this.onRetry,
    super.key,
  });

  /// When the quota returns.
  final DateTime resetAt;

  /// Invoked only once the window has reopened.
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
    _remaining = _remainingNow();
    _ticker = Timer.periodic(const Duration(seconds: 1), _tick);
  }

  Duration _remainingNow() {
    final Duration d = widget.resetAt.difference(DateTime.now());
    return d.isNegative ? Duration.zero : d;
  }

  void _tick(Timer timer) {
    if (!mounted) return;
    final Duration next = _remainingNow();
    setState(() => _remaining = next);
    // Stop once actionable: no point burning a frame a second thereafter.
    if (next == Duration.zero) timer.cancel();
  }

  @override
  void dispose() {
    // Without this the timer keeps firing setState on a disposed State after
    // the user navigates away, which throws.
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool canRetry = _remaining == Duration.zero;

    return Center(
      key: const Key('rate_limit_view'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.hourglass_top, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text('Rate limit reached', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'GitHub allows 60 requests per hour without a token.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Text(
              canRetry
                  ? 'You can try again now.'
                  : 'Limit resets at ${formatClockTime(widget.resetAt)} '
                      '(${formatCountdown(_remaining)})',
              key: const Key('rate_limit_reset_text'),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall?.copyWith(
                color: canRetry
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              key: const Key('rate_limit_retry_button'),
              // Null disables the button until the window reopens.
              onPressed: canRetry ? widget.onRetry : null,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
            if (!ApiConstants.hasToken) ...<Widget>[
              const SizedBox(height: 24),
              Text(
                'Tip: run with --dart-define=GITHUB_TOKEN=<token> to raise the '
                'limit to 5000 requests per hour.',
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
