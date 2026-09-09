/// The bottom-of-list affordance.
library;

import 'package:flutter/material.dart';

import '../bloc/users_state.dart';

/// Renders whatever the end of the list currently needs.
///
/// Four mutually exclusive cases, in priority order:
///  1. loading more -> spinner
///  2. inline failure -> message + Retry, WITHOUT hiding the loaded users
///  3. searching a short list -> invite loading more, so "no results" is not
///     mistaken for "no such user exists" (constraint e)
///  4. end of list -> a terminal marker, so the user knows to stop scrolling
class PaginationFooter extends StatelessWidget {
  const PaginationFooter({
    required this.state,
    required this.onRetry,
    required this.onLoadMore,
    super.key,
  });

  /// Current list state.
  final UsersState state;

  /// Retry the failed page.
  final VoidCallback onRetry;

  /// Request the next page explicitly.
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    if (state.isLoadingMore) {
      return const Padding(
        key: Key('pagination_loading'),
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (state.hasInlineFailure) {
      return Padding(
        key: const Key('pagination_error'),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          children: <Widget>[
            Text(
              state.failure?.message ?? 'Could not load more users.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.error),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (state.shouldOfferMoreForSearch) {
      return Padding(
        key: const Key('pagination_search_more'),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          children: <Widget>[
            Text(
              'Searching ${state.users.length} loaded users. GitHub has no '
              'name filter, so load more to widen the search.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: onLoadMore,
              child: const Text('Load more users'),
            ),
          ],
        ),
      );
    }

    if (state.hasReachedEnd && state.users.isNotEmpty) {
      return Padding(
        key: const Key('pagination_end'),
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'No more users',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
          ),
        ),
      );
    }

    return const SizedBox(height: 8);
  }
}
