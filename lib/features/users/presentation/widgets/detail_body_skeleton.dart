/// Placeholder rows for the detail body while the profile loads.
library;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';

/// Skeleton for the lower half of the detail screen.
///
/// Only the BODY is a skeleton -- the header is already real, rendered from
/// the seed the list handed over. So the screen never opens blank.
class DetailBodySkeleton extends StatelessWidget {
  const DetailBodySkeleton({this.rowCount = 6, super.key});

  /// How many placeholder rows to draw.
  final int rowCount;

  @override
  Widget build(BuildContext context) {
    final Color base = Theme.of(context).colorScheme.surfaceContainerHighest;

    return Column(
      key: const Key('detail_body_skeleton'),
      children: <Widget>[
        for (int i = 0; i < rowCount; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm + AppSpacing.xs),
            child: Row(
              children: <Widget>[
                Container(width: 20, height: 20, color: base),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(height: 10, width: 70, color: base),
                      const SizedBox(height: AppSpacing.xs),
                      Container(height: 12, width: 160, color: base),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
