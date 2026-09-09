/// The bottom-of-list slot.
library;

import 'package:flutter/material.dart';

import '../strings/users_strings.dart';

import '../../../../core/theme/app_spacing.dart';

/// What the end of the list is currently doing.
enum PaginationFooterMode {
  /// A page is in flight.
  loading,

  /// The last page failed. The list above stays intact.
  error,

  /// Everything has been loaded.
  end,

  /// Nothing to show.
  idle,
}

/// Renders the three end-of-list affordances.
///
/// The error mode is the important one: it keeps the loaded list on screen
/// and puts the retry INLINE, so a failure on page 5 costs the user nothing
/// they had already scrolled past. A full-screen error here would throw away
/// 40 rows to report one failed request.
class PaginationFooter extends StatelessWidget {
  const PaginationFooter({
    required this.mode,
    this.errorMessage,
    this.onRetry,
    super.key,
  });

  /// Which affordance to render.
  final PaginationFooterMode mode;

  /// Shown in [PaginationFooterMode.error].
  final String? errorMessage;

  /// Retry the failed page.
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
