library;

import 'package:flutter/widgets.dart';

enum WindowSizeClass {
  compact,

  medium,

  expanded;

  static WindowSizeClass fromWidth(double width) {
    if (width < 600) return WindowSizeClass.compact;
    if (width < 840) return WindowSizeClass.medium;
    return WindowSizeClass.expanded;
  }

  int get gridColumns => switch (this) {
    WindowSizeClass.compact => 1,
    WindowSizeClass.medium => 2,
    WindowSizeClass.expanded => 3,
  };
}

class ResponsiveBuilder extends StatelessWidget {
  const ResponsiveBuilder({required this.builder, super.key});

  final Widget Function(BuildContext context, WindowSizeClass sizeClass)
  builder;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) =>
        builder(context, WindowSizeClass.fromWidth(constraints.maxWidth)),
  );
}
