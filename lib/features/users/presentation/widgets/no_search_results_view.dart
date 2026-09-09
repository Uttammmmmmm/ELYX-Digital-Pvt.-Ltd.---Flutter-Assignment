/// A search matched nothing among the loaded users.
library;

import 'package:flutter/material.dart';

/// Shown when the query is non-empty and `visibleUsers` is empty.
///
/// Deliberately different from `EmptyView` in icon, copy and action, because
/// it means something different and demands a different response. It must
/// NOT imply the user does not exist on GitHub -- client-side filtering
/// cannot know that. It says exactly what was searched: the users loaded so
/// far. Constraint (e).
class NoSearchResultsView extends StatelessWidget {
  const NoSearchResultsView({
    required this.query,
    required this.loadedCount,
    required this.onClearSearch,
    this.onLoadMore,
    super.key,
  });

  /// The query that matched nothing, echoed back so the user can spot typos.
  final String query;

  /// How many users the search actually covered.
  final int loadedCount;

  /// Clears the query and restores the full list.
  final VoidCallback onClearSearch;

  /// Widens the corpus by loading another page. Null at the end of the list.
  final VoidCallback? onLoadMore;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Center(
      key: const Key('no_search_results_view'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.search_off, size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text('No matches for "$query"', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'GitHub has no username filter, so only the $loadedCount users '
              'loaded so far were searched.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              alignment: WrapAlignment.center,
              children: <Widget>[
                FilledButton.tonalIcon(
                  key: const Key('clear_search_button'),
                  onPressed: onClearSearch,
                  icon: const Icon(Icons.clear, size: 18),
                  label: const Text('Clear search'),
                ),
                if (onLoadMore != null)
                  OutlinedButton(
                    key: const Key('search_load_more_button'),
                    onPressed: onLoadMore,
                    child: const Text('Load more users'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
