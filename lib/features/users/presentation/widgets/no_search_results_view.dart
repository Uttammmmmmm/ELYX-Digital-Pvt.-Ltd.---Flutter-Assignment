library;

import 'package:flutter/material.dart';

import '../strings/users_strings.dart';

import '../../../../core/theme/app_spacing.dart';
import 'adaptive_centered_view.dart';

class NoSearchResultsView extends StatelessWidget {
  const NoSearchResultsView({
    required this.query,
    required this.loadedCount,
    required this.onClearSearch,
    this.onLoadMore,
    super.key,
  });

  final String query;

  final int loadedCount;

  final VoidCallback onClearSearch;

  final VoidCallback? onLoadMore;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AdaptiveCenteredView(
      key: const Key('no_search_results_view'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.search_off,
            size: AppSizes.iconXl,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            UsersStrings.noMatchesTitle(query),
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            UsersStrings.noMatchesBody(loadedCount),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md + AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.sm + AppSpacing.xs,
            alignment: WrapAlignment.center,
            children: <Widget>[
              FilledButton.tonalIcon(
                key: const Key('clear_search_button'),
                onPressed: onClearSearch,
                icon: const Icon(Icons.clear, size: AppSizes.iconMd),
                label: const Text(UsersStrings.clearSearch),
              ),
              if (onLoadMore != null)
                OutlinedButton(
                  key: const Key('search_load_more_button'),
                  onPressed: onLoadMore,
                  child: const Text(UsersStrings.loadMoreUsers),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
