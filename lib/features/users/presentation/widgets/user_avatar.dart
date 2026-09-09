/// Avatar with a disk cache, placeholder and initials fallback.
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// A circular avatar backed by [CachedNetworkImage].
///
/// Three visual states, all required: the cached image, a neutral placeholder
/// while it loads, and an initials fallback when it fails. Without the last
/// one a broken avatar URL leaves a hole in the row.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    required this.url,
    required this.login,
    this.radius = 24,
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

  /// Used for the initials fallback.
  final String login;

  /// Circle radius.
  final double radius;

  @override
  Widget build(BuildContext context) {
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
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Container(
      width: radius * 2,
      height: radius * 2,
      alignment: Alignment.center,
      color: scheme.surfaceContainerHighest,
      child: Text(
        login.isEmpty ? '?' : login[0].toUpperCase(),
        style: TextStyle(
          fontSize: radius * 0.8,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
