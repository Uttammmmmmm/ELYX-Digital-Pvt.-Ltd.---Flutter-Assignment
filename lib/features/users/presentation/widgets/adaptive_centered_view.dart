/// Layout for full-screen message states.
library;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';

/// Centres [child] when there is room, and scrolls it when there is not.
///
/// WHY THIS EXISTS. Every full-screen state (error, rate limit, empty, no
/// results) is a `Column` of icon + copy + buttons that has a natural height
/// of roughly 300dp. A bare `Center(child: Column(...))` renders fine on a
/// phone in portrait and OVERFLOWS the moment the available height drops
/// below that -- which happens in three ordinary situations:
///
///   * landscape on a small phone,
///   * the detail screen, where the state sits under a header that has
///     already consumed most of the viewport,
///   * any device with the system font size raised.
///
/// An overflow here is not cosmetic: the striped banner covers the Retry
/// button, so the user is shown an error they cannot act on. Making the
/// content scrollable means it degrades to "scroll a little" instead.
///
/// `minHeight` is taken from the incoming constraints so the content still
/// centres vertically when there IS room, rather than hugging the top. The
/// unbounded case matters too: inside a `ListView` (the detail screen) the
/// height constraint is infinite, and a `minHeight` of infinity would throw.
class AdaptiveCenteredView extends StatelessWidget {
  const AdaptiveCenteredView({
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.xl),
    super.key,
  });

  /// The message content. Should be a `Column` with `MainAxisSize.min`.
  final Widget child;

  /// Padding around [child].
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // Unbounded (e.g. a ListView slot) -> no minimum; the scroll view
        // shrink-wraps and the outer scrollable handles overflow.
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
