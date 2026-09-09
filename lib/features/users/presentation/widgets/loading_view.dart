library;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import 'user_tile_metrics.dart';

class LoadingView extends StatelessWidget {
  const LoadingView({this.itemCount = 8, super.key});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final Color base = Theme.of(context).colorScheme.surfaceContainerHighest;

    return ListView.builder(
      key: const Key('loading_view'),
      itemCount: itemCount,
      itemExtent: UserTileMetrics.heightFor(context),
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (BuildContext context, int index) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Row(
          children: <Widget>[
            CircleAvatar(radius: AppSizes.avatarSm, backgroundColor: base),
            const SizedBox(width: AppSpacing.md),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _Bar(width: 140, height: 14, color: base),
                const SizedBox(height: AppSpacing.sm),
                _Bar(width: 80, height: 12, color: base),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.width, required this.height, required this.color});

  final double width;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(AppRadius.xs),
    ),
  );
}
