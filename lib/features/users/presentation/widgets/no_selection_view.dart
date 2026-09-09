library;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../strings/users_strings.dart';

class NoSelectionView extends StatelessWidget {
  const NoSelectionView({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.person_search_outlined,
              size: 48,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              UsersStrings.noSelectionTitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              UsersStrings.noSelectionBody,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
