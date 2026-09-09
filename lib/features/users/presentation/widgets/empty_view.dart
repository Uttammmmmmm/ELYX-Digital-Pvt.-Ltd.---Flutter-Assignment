library;

import 'package:flutter/material.dart';

import '../strings/users_strings.dart';

import '../../../../core/theme/app_spacing.dart';
import 'adaptive_centered_view.dart';

class EmptyView extends StatelessWidget {
  const EmptyView({this.onRefresh, super.key});

  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AdaptiveCenteredView(
      key: const Key('empty_view'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.people_outline,
            size: AppSizes.iconXl,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(UsersStrings.emptyTitle, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            UsersStrings.emptyBody,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (onRefresh != null) ...<Widget>[
            const SizedBox(height: AppSpacing.md + AppSpacing.xs),
            OutlinedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh, size: AppSizes.iconMd),
              label: const Text(UsersStrings.refresh),
            ),
          ],
        ],
      ),
    );
  }
}
