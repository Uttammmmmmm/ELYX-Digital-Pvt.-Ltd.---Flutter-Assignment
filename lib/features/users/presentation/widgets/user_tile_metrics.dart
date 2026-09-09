/// Shared row geometry for the users list.
library;

import 'package:flutter/material.dart';

/// Row height, shared by the real tile and the skeleton so they line up.
abstract final class UserTileMetrics {
  /// Height at the default text scale.
  static const double baseHeight = 72;

  /// Row height for [context], grown for the user's text-scale setting.
  ///
  /// A FIXED height per build is what lets `ListView.builder` use `itemExtent`
  /// and compute scroll extents without measuring children -- smoother
  /// scrolling, and a meaningful `maxScrollExtent` before layout settles.
  /// But a height fixed at 72 *overflows* the moment someone raises their
  /// system font size, which is a real accessibility failure, not a cosmetic
  /// one. Scaling the constant keeps both properties: every row is still the
  /// same height, and that height respects the setting.
  ///
  /// Clamped to 2.0 because beyond that a list row stops being a list row;
  /// the text ellipsizes rather than growing without bound.
  static double heightFor(BuildContext context) {
    final double scale = MediaQuery.textScalerOf(
      context,
    ).scale(1).clamp(1.0, 2.0);
    return baseHeight * scale;
  }

  /// Grid card height, likewise text-scale aware.
  static double cardHeightFor(BuildContext context) {
    final double scale = MediaQuery.textScalerOf(
      context,
    ).scale(1).clamp(1.0, 2.0);
    // 32 padding + 64 avatar + 8 gap + ~20 title + 2 + ~16 subtitle = 142.
    // 152 leaves headroom for a font whose metrics run slightly taller.
    return 152 * scale;
  }
}
