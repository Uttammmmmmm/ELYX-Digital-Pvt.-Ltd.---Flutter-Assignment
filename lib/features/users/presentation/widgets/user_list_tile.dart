library;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/user_summary.dart';
import '../pages/user_detail_page.dart' show userAvatarHeroTag;
import 'user_avatar.dart';
import 'user_tile_metrics.dart';

class UserListTile extends StatelessWidget {
  const UserListTile({
    required this.user,
    required this.onTap,
    this.selected = false,
    this.heroEnabled = true,
    super.key,
  });

  final UserSummary user;

  final VoidCallback onTap;

  final bool selected;

  final bool heroEnabled;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    final String? type = user.accountType;
    final bool isOrganisation = type != null && type != 'User';

    final Widget avatar = UserAvatar(
      url: user.avatarUrl,
      login: user.displayName,
      radius: AppSizes.avatarSm,
    );

    return SizedBox(
      height: UserTileMetrics.heightFor(context),
      child: Material(
        color: selected
            ? theme.colorScheme.secondaryContainer
            : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: <Widget>[
                if (heroEnabled)
                  Hero(tag: userAvatarHeroTag(user.id), child: avatar)
                else
                  avatar,
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        user.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: AppSpacing.xs / 2),
                      Text(
                        user.handle != null
                            ? '@${user.handle}'
                            : (user.email ?? 'id ${user.id}'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (isOrganisation) _TypeBadge(type: type),
                Icon(Icons.chevron_right, color: theme.colorScheme.outline),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(right: AppSpacing.xs),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs / 2,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        type,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}
