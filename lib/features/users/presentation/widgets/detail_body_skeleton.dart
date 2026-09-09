library;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';

class DetailBodySkeleton extends StatelessWidget {
  const DetailBodySkeleton({this.rowCount = 6, super.key});

  final int rowCount;

  @override
  Widget build(BuildContext context) {
    final Color base = Theme.of(context).colorScheme.surfaceContainerHighest;

    return Column(
      key: const Key('detail_body_skeleton'),
      children: <Widget>[
        for (int i = 0; i < rowCount; i++)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm + AppSpacing.xs,
            ),
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
