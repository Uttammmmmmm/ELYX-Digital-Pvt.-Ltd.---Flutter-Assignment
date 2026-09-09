library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../strings/users_strings.dart';

import '../../../../core/theme/app_spacing.dart';
import 'adaptive_centered_view.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/utils/duration_format.dart';

class RateLimitView extends StatefulWidget {
  const RateLimitView({
    required this.resetAt,
    required this.onRetry,
    super.key,
  });

  final DateTime resetAt;

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

    return AdaptiveCenteredView(
      key: const Key('rate_limit_view'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.hourglass_top,
            size: AppSizes.iconXl,
            color: theme.colorScheme.error,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(UsersStrings.rateLimitTitle, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            UsersStrings.rateLimitBody,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            canRetry
                ? UsersStrings.rateLimitReady
                : UsersStrings.rateLimitResetsAt(
                    formatClockTime(widget.resetAt),
                    formatCountdown(_remaining),
                  ),
            key: const Key('rate_limit_reset_text'),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall?.copyWith(
              color: canRetry
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            key: const Key('rate_limit_retry_button'),

            onPressed: canRetry ? widget.onRetry : null,
            icon: const Icon(Icons.refresh),
            label: const Text(UsersStrings.tryAgain),
          ),
          if (!ApiConstants.hasToken) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            Text(
              UsersStrings.rateLimitTokenTip,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
