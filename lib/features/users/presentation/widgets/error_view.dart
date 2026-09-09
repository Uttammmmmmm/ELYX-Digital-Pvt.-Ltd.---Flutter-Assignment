library;

import 'package:flutter/material.dart';

import '../strings/users_strings.dart';

import '../../../../core/theme/app_spacing.dart';
import 'adaptive_centered_view.dart';

import '../../../../core/error/failures.dart';

class ErrorView extends StatelessWidget {
  const ErrorView({required this.failure, required this.onRetry, super.key});

  final Failure failure;

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AdaptiveCenteredView(
      key: const Key('error_view'),
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
            size: AppSizes.iconXl,
            color: theme.colorScheme.error,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            failure.message,
            key: const Key('error_message'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            key: const Key('error_retry_button'),
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text(UsersStrings.tryAgain),
          ),
        ],
      ),
    );
  }
}
