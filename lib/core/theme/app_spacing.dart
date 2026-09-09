/// Spacing and radius tokens.
library;

/// A 4pt spacing scale.
///
/// Named steps rather than raw numbers so vertical rhythm is consistent by
/// construction: a reviewer never has to wonder whether a 14 was deliberate
/// or a typo for 16, and changing the scale is one edit rather than a
/// project-wide find-and-replace.
abstract final class AppSpacing {
  /// 4 - hairline gaps, icon-to-label.
  static const double xs = 4;

  /// 8 - within a component.
  static const double sm = 8;

  /// 16 - the default gutter and screen padding.
  static const double md = 16;

  /// 24 - between component groups.
  static const double lg = 24;

  /// 32 - section separation, empty-state padding.
  static const double xl = 32;
}

/// Corner radii.
abstract final class AppRadius {
  /// 4 - skeleton bars.
  static const double xs = 4;

  /// 8 - chips and badges.
  static const double sm = 8;

  /// 12 - inputs and cards.
  static const double md = 12;

  /// 16 - large surfaces.
  static const double lg = 16;
}

/// Sizes that recur across the UI.
abstract final class AppSizes {
  /// Avatar radius in a list row.
  static const double avatarSm = 24;

  /// Avatar radius in a grid card.
  static const double avatarMd = 32;

  /// Avatar radius on the detail header.
  static const double avatarLg = 48;

  /// Leading/trailing icon in a row.
  static const double iconSm = 16;

  /// Standard icon.
  static const double iconMd = 20;

  /// Empty- and error-state illustration.
  static const double iconXl = 48;
}
