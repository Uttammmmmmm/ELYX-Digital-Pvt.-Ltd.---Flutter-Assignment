library;

import 'package:flutter/material.dart';

abstract final class UserTileMetrics {
  static const double baseHeight = 72;

  static double heightFor(BuildContext context) {
    final double scale = MediaQuery.textScalerOf(
      context,
    ).scale(1).clamp(1.0, 2.0);
    return baseHeight * scale;
  }

  static double cardHeightFor(BuildContext context) {
    final double scale = MediaQuery.textScalerOf(
      context,
    ).scale(1).clamp(1.0, 2.0);
    return 152 * scale;
  }
}
