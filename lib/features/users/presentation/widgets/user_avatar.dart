/// Avatar with a disk cache, placeholder, initials fallback and fade-in.
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// A circular avatar backed by [CachedNetworkImage].
///
/// Three visual states, all required: the cached image, a neutral placeholder
/// while it loads, and an initials fallback when it fails. Without the last
/// one a broken avatar URL leaves a hole in the row.
///
/// Wrapped in [Semantics] with `image: true`, so a screen reader announces
/// "Tom's avatar" rather than skipping silently over the most prominent
/// element on the screen.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    required this.url,
    required this.login,
    required this.radius,
    super.key,
  });

  /// TEST SEAM. `CachedNetworkImage` reaches for the network and
  /// `path_provider`, neither of which exists under `flutter_test`; the
  /// resulting async failures surface as errors in unrelated tests. Widget
  /// tests install a synchronous stand-in here. Production never assigns it.
  @visibleForTesting
  static Widget Function(String url, String login, double radius)?
  debugOverrideBuilder;

  /// Image URL.
  final String url;

  /// Used for the initials fallback and the semantic label.
  final String login;

  /// Circle radius.
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: '$login avatar',
      child: ExcludeSemantics(child: _image(context)),
    );
  }

  Widget _image(BuildContext context) {
    final Widget Function(String, String, double)? override =
        debugOverrideBuilder;
    if (override != null) return override(url, login, radius);

    if (url.isEmpty) return _Initials(login: login, radius: radius);

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: url,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        // Softens the pop-in as rows scroll into view.
        fadeInDuration: const Duration(milliseconds: 200),
        fadeOutDuration: const Duration(milliseconds: 100),
        placeholder: (BuildContext context, String _) =>
            _Placeholder(radius: radius),
        errorWidget: (BuildContext context, String _, Object _) =>
            _Initials(login: login, radius: radius),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.radius});

  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    width: radius * 2,
    height: radius * 2,
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
  );
}

class _Initials extends StatelessWidget {
  const _Initials({required this.login, required this.radius});

  final String login;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    // Picks a semantic role by size rather than computing a font size, so the
    // initial still respects the user's text-scale setting.
    final TextStyle? style = radius >= 40
        ? theme.textTheme.headlineMedium
        : radius >= 30
        ? theme.textTheme.titleLarge
        : theme.textTheme.titleMedium;

    return Container(
      width: radius * 2,
      height: radius * 2,
      alignment: Alignment.center,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Text(
        login.isEmpty ? '?' : login[0].toUpperCase(),
        maxLines: 1,
        style: style?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}
