library;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';

class DetailInfoRow extends StatelessWidget {
  const DetailInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.unavailable = false,
    this.onTap,
    super.key,
  });

  final IconData icon;

  final String label;

  final String value;

  final bool unavailable;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final VoidCallback? effectiveOnTap = unavailable ? null : onTap;

    return InkWell(
      onTap: effectiveOnTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + AppSpacing.xs,
        ),
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
                      color: unavailable
                          ? scheme.outline
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs / 2),
                  Text(
                    value,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: unavailable ? scheme.outline : scheme.onSurface,
                      fontStyle: unavailable
                          ? FontStyle.italic
                          : FontStyle.normal,
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
