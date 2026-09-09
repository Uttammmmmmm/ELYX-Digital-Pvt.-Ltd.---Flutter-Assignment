library;

import 'package:flutter/material.dart';

import '../strings/users_strings.dart';

import '../../../../core/theme/app_spacing.dart';

enum PaginationFooterMode { loading, error, end, idle }

class PaginationFooter extends StatelessWidget {
  const PaginationFooter({
    required this.mode,
    this.errorMessage,
    this.onRetry,
    super.key,
  });

  final PaginationFooterMode mode;

  final String? errorMessage;

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    switch (mode) {
      case PaginationFooterMode.loading:
        return const Padding(
          key: Key('pagination_loading'),
          padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
          child: Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );

      case PaginationFooterMode.error:
        return Padding(
          key: const Key('pagination_error'),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            children: <Widget>[
              Text(
                errorMessage ?? UsersStrings.couldNotLoadMore,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                key: const Key('pagination_retry_button'),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: AppSizes.iconMd),
                label: const Text(UsersStrings.retry),
              ),
            ],
          ),
        );

      case PaginationFooterMode.end:
        return Padding(
          key: const Key('pagination_end'),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          child: Center(
            child: Text(
              UsersStrings.endOfList,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
        );

      case PaginationFooterMode.idle:
        return const SizedBox(key: Key('pagination_idle'), height: 8);
    }
  }
}
