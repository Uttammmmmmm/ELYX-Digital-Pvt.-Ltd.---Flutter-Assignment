/// The API returned no users at all.
library;

import 'package:flutter/material.dart';

/// Shown when GitHub returned zero users and no search is active.
///
/// Visually and textually distinct from [NoSearchResultsView]: this one means
/// "there is nothing here", which is a property of the data. That one means
/// "nothing you loaded matches", which is a property of your query. Same
/// blank screen, completely different next action.
class EmptyView extends StatelessWidget {
  const EmptyView({this.onRefresh, super.key});

  /// Optional retry, since an empty result is usually transient.
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Center(
      key: const Key('empty_view'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.people_outline, size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text('No users available', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'GitHub returned no users for this request.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            if (onRefresh != null) ...<Widget>[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Refresh'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
