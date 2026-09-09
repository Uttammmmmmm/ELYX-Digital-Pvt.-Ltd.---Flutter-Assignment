/// A labelled field on the detail screen.
library;

import 'package:flutter/material.dart';

/// One label/value row, styled differently when the value is unavailable.
///
/// [isUnavailable] drives a muted, italic treatment so "Not provided by GitHub
/// API" is visibly not real data. Rendering an absent value in the same style
/// as a real one is how users end up believing a placeholder.
class DetailFieldTile extends StatelessWidget {
  const DetailFieldTile({
    required this.icon,
    required this.label,
    required this.value,
    this.isUnavailable = false,
    super.key,
  });

  /// Leading icon.
  final IconData icon;

  /// Field name.
  final String label;

  /// Field value, or fallback copy.
  final String value;

  /// Whether [value] is a placeholder rather than real data.
  final bool isUnavailable;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color muted = theme.colorScheme.outline;

    return ListTile(
      dense: true,
      leading: Icon(
        icon,
        size: 20,
        color: isUnavailable ? muted : theme.colorScheme.onSurfaceVariant,
      ),
      title: Text(
        label,
        style: theme.textTheme.labelMedium
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
      subtitle: Text(
        value,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: isUnavailable ? muted : theme.colorScheme.onSurface,
          fontStyle: isUnavailable ? FontStyle.italic : FontStyle.normal,
        ),
      ),
    );
  }
}
