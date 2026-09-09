/// Placeholder for the detail pane of a split view before a user is picked.
library;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../strings/users_strings.dart';

/// Fills the detail pane of a two-pane layout while nothing is selected.
///
/// A two-pane layout has a hole in it on first open, and an empty grey
/// rectangle reads as a rendering bug. This says what the pane is for.
///
/// Deliberately NOT a `Scaffold`: the pane it sits in already provides one,
/// and nesting Scaffolds would stack two backgrounds and two
/// `ScaffoldMessenger`s, sending SnackBars to the wrong one.
class NoSelectionView extends StatelessWidget {
  const NoSelectionView({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Center(
      // Scrollable so the copy cannot overflow a short landscape pane -- the
      // same failure mode the other full-pane states were fixed for.
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
