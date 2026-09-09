/// First-load skeleton.
library;

import 'package:flutter/material.dart';

/// Eight placeholder rows shown during the very first page load.
///
/// A skeleton rather than a bare centred spinner: it communicates the SHAPE
/// of what is coming, occupies the same space the real rows will, and so
/// avoids the layout jump when they arrive. A spinner communicates only that
/// something is happening.
class LoadingView extends StatelessWidget {
  const LoadingView({this.itemCount = 8, super.key});

  /// How many placeholder rows to draw.
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final Color base = Theme.of(context).colorScheme.surfaceContainerHighest;

    return ListView.builder(
      key: const Key('loading_view'),
      itemCount: itemCount,
      // The skeleton is not interactive; letting it scroll would be a lie.
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (BuildContext context, int index) => SizedBox(
        height: UserTileMetrics.height,
        child: Row(
          children: <Widget>[
            const SizedBox(width: 16),
            CircleAvatar(radius: 24, backgroundColor: base),
            const SizedBox(width: 16),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _Bar(width: 140, height: 14, color: base),
                const SizedBox(height: 8),
                _Bar(width: 80, height: 12, color: base),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Shared row height, so the skeleton and the real tile line up exactly.
abstract final class UserTileMetrics {
  /// Fixed height for every list row.
  ///
  /// Fixed rather than intrinsic so `ListView.builder` can compute extents
  /// without measuring children, which keeps scrolling smooth on long lists
  /// and makes `maxScrollExtent` meaningful before layout settles.
  static const double height = 72;
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
          borderRadius: BorderRadius.circular(4),
        ),
      );
}
