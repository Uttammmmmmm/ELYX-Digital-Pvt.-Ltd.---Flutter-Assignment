/// Avatar image with a disk cache.
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Builds the [ImageProvider] for a given URL.
typedef AvatarImageBuilder = ImageProvider<Object> Function(String url);

/// A circular avatar backed by [CachedNetworkImageProvider].
///
/// TEST SEAM: [imageProviderBuilder] is overridable because widget tests have
/// no network and no `path_provider` plugin, so the real provider throws
/// asynchronously and leaves pending timers that fail unrelated assertions.
/// Tests swap in an in-memory provider; production never reassigns it.
class NetworkAvatar extends StatelessWidget {
  const NetworkAvatar({
    required this.url,
    required this.fallbackInitial,
    this.radius = 24,
    super.key,
  });

  /// Overridable image source. Reset in `tearDown` if a test changes it.
  static AvatarImageBuilder imageProviderBuilder =
      (String url) => CachedNetworkImageProvider(url);

  /// The avatar URL.
  final String url;

  /// Shown while loading and if the image fails; normally the first letter of
  /// the login.
  final String fallbackInitial;

  /// Circle radius.
  final double radius;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return CircleAvatar(
      radius: radius,
      backgroundColor: scheme.surfaceContainerHighest,
      foregroundImage: url.isEmpty ? null : imageProviderBuilder(url),
      // Rendered underneath the image, so it doubles as placeholder AND error
      // state without needing to distinguish them.
      child: Text(
        fallbackInitial.isEmpty ? '?' : fallbackInitial[0].toUpperCase(),
        style: TextStyle(
          fontSize: radius * 0.8,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
