library;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';

class AdaptiveCenteredView extends StatelessWidget {
  const AdaptiveCenteredView({
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.xl),
    super.key,
  });

  final Widget child;

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double minHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : 0;

        return SingleChildScrollView(
          padding: padding,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Center(child: child),
          ),
        );
      },
    );
  }
}
