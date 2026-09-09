/// A labelled field on the detail screen.
library;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';

/// One icon / label / value row.
///
/// When [unavailable] is true it renders a muted, italic placeholder rather
/// than hiding the row or showing an empty string. Both alternatives are
/// worse: hiding it makes the absence invisible, so the user cannot tell
/// "GitHub has no value" from "this app forgot to show it"; an empty string
/// looks like a rendering bug. An explicit, visibly-different placeholder
/// says the field exists and the data does not.
class DetailInfoRow extends StatelessWidget {
  const DetailInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.unavailable = false,
    this.onTap,
    super.key,
  });

  /// Leading icon.
  final IconData icon;

  /// Field name.
  final String label;

  /// Field value, or the placeholder when [unavailable].
  final String value;

  /// Whether [value] is a placeholder rather than real data.
  final bool unavailable;

  /// Optional action. Ignored when [unavailable] -- a placeholder must never
  /// look interactive.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final VoidCallback? effectiveOnTap = unavailable ? null : onTap;

    return InkWell(
      onTap: effectiveOnTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm + AppSpacing.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              icon,
              size: AppSizes.iconMd,
              color: unavailable ? scheme.outline : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      // Muted label as well as muted value, so the whole row
                      // reads as "nothing here" at a glance.
                      color: unavailable ? scheme.outline : scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs / 2),
                  Text(
                    // Long blog URLs and bios wrap rather than overflow; a
                    // ceiling keeps one pathological value from taking the
                    // whole screen.
                    value,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: unavailable ? scheme.outline : scheme.onSurface,
                      fontStyle:
                          unavailable ? FontStyle.italic : FontStyle.normal,
                      decoration: effectiveOnTap != null
                          ? TextDecoration.underline
                          : null,
                    ),
                  ),
                ],
              ),
            ),
            if (effectiveOnTap != null)
              Icon(Icons.copy, size: AppSizes.iconSm, color: scheme.outline),
          ],
        ),
      ),
    );
  }
}
