/// Persistent "you are offline" bar.
library;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';

/// A thin bar shown while the device is offline and cached data is on screen.
///
/// Its whole purpose is honesty: the repository deliberately serves stale
/// cached users rather than an error when there is no connection, which is
/// the right behaviour ONLY if the user is told. Without this the app
/// silently presents old data as current.
///
/// Takes a [Stream] rather than reaching for `NetworkInfo` itself, so no
/// widget touches the service locator and tests can drive it directly.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({required this.isOnline, super.key});

  /// Emits false when the device has no network interface.
  final Stream<bool> isOnline;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: isOnline,
      builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
        // Absent data means "not known yet" -- assume online, because
        // flashing an offline bar on every cold start would cry wolf.
        final bool online = snapshot.data ?? true;
        if (online) return const SizedBox.shrink();

        final ThemeData theme = Theme.of(context);
        return Material(
          key: const Key('offline_banner'),
          color: theme.colorScheme.secondaryContainer,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.cloud_off,
                  size: AppSizes.iconSm,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    "You're offline — showing saved users, which may be "
                    'out of date.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
