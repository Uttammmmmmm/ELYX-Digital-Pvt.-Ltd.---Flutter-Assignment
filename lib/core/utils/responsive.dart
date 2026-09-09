/// Material 3 window size classes.
library;

import 'package:flutter/widgets.dart';

/// Material 3 window size classes, using Material's own breakpoints and
/// names rather than invented ones.
///
/// See m3.material.io/foundations/layout/applying-layout/window-size-classes.
enum WindowSizeClass {
  /// < 600dp. Phones in portrait. One pane.
  compact,

  /// 600-839dp. Large phones in landscape, small tablets. Two panes fit.
  medium,

  /// >= 840dp. Tablets, desktop, foldables open. Two or three panes.
  expanded;

  /// Classifies a width in logical pixels.
  static WindowSizeClass fromWidth(double width) {
    if (width < 600) return WindowSizeClass.compact;
    if (width < 840) return WindowSizeClass.medium;
    return WindowSizeClass.expanded;
  }

  /// Grid columns appropriate to this class.
  int get gridColumns => switch (this) {
        WindowSizeClass.compact => 1,
        WindowSizeClass.medium => 2,
        WindowSizeClass.expanded => 3,
      };
}

/// Rebuilds its child with the [WindowSizeClass] of the space it was given.
///
/// BUILT ON LayoutBuilder, NOT MediaQuery, for two reasons. MediaQuery reports
/// the whole window, so a widget inside a navigation rail, a dialog, or the
/// list pane of a split view would be told it has 900dp when it actually has
/// 320 -- and would lay out for a tablet inside a phone-width column.
/// LayoutBuilder reports the constraints this box actually received, which is
/// the only number that can be laid out against correctly.
class ResponsiveBuilder extends StatelessWidget {
  const ResponsiveBuilder({required this.builder, super.key});

  /// Called with the size class of the available width.
  final Widget Function(BuildContext context, WindowSizeClass sizeClass)
      builder;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) =>
            builder(context, WindowSizeClass.fromWidth(constraints.maxWidth)),
      );
}
