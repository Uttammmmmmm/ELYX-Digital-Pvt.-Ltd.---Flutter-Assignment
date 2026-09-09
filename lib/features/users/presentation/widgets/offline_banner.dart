library;

import 'package:flutter/material.dart';

import '../strings/users_strings.dart';

import '../../../../core/theme/app_spacing.dart';

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({required this.isOnline, super.key});

  final Stream<bool> isOnline;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: isOnline,
      builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
        final bool online = snapshot.data ?? true;
        if (online) return const SizedBox.shrink();

        final ThemeData theme = Theme.of(context);
        return Material(
          key: const Key('offline_banner'),
          color: theme.colorScheme.secondaryContainer,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
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
                    UsersStrings.offlineBanner,
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
