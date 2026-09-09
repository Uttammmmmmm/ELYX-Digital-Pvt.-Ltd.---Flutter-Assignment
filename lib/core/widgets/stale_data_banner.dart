/// "Showing saved data" notice.
library;

import 'package:flutter/material.dart';

import '../utils/duration_format.dart';

/// Tells the user the visible data came from the cache, and how old it is.
///
/// The counterpart to the repository's decision to serve stale data instead of
/// an error when the device is offline or the rate limit is spent: that choice
/// is only honest if the UI says so.
class StaleDataBanner extends StatelessWidget {
  const StaleDataBanner({required this.cachedAt, this.onRefresh, super.key});

  /// When the cached copy was written; null falls back to generic wording.
  final DateTime? cachedAt;

  /// Optional refresh action.
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final DateTime? at = cachedAt;
    final String age =
        at == null ? '' : ' · ${formatAge(DateTime.now().difference(at))}';

    return Material(
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.cloud_off,
              size: 16,
              color: theme.colorScheme.onSecondaryContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Showing saved data$age',
                key: const Key('stale_banner_text'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
            ),
            if (onRefresh != null)
              TextButton(onPressed: onRefresh, child: const Text('Refresh')),
          ],
        ),
      ),
    );
  }
}
