/// First-load skeleton.
library;

import 'package:flutter/material.dart';

/// Placeholder rows shown during the very first page load.
///
/// A skeleton rather than a bare spinner because it communicates the shape of
/// what is coming and avoids the layout jump when real rows arrive.
class UserTileShimmer extends StatelessWidget {
  const UserTileShimmer({this.itemCount = 8, super.key});

  /// How many placeholder rows to draw.
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final Color base = Theme.of(context).colorScheme.surfaceContainerHighest;

    return ListView.builder(
      itemCount: itemCount,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (BuildContext context, int index) => ListTile(
        leading: CircleAvatar(radius: 24, backgroundColor: base),
        title: Container(
          height: 14,
          width: 140,
          decoration: BoxDecoration(
            color: base,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        subtitle: Container(
          height: 12,
          width: 80,
          margin: const EdgeInsets.only(top: 6),
          decoration: BoxDecoration(
            color: base,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}
