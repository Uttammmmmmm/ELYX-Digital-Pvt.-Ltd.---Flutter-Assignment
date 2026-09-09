/// A single row in the users list.
library;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/user_summary.dart';
import '../pages/user_detail_page.dart' show userAvatarHeroTag;
import 'user_avatar.dart';
import 'user_tile_metrics.dart';

/// Renders one [UserSummary] as a list row.
///
/// Shows only what the LIST endpoint returns -- login, avatar, id, type. No
/// name and no email, because constraint (b) means we do not have them and
/// fetching them would cost one request per row against a 60/hour budget.
class UserListTile extends StatelessWidget {
  const UserListTile({required this.user, required this.onTap, super.key});

  /// The user to render.
  final UserSummary user;

  /// Navigation callback.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isPerson = user.type == 'User';

    return SizedBox(
      height: UserTileMetrics.heightFor(context),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            children: <Widget>[
              // Shared element with the detail screen.
              Hero(
                tag: userAvatarHeroTag(user.id),
                child: UserAvatar(
                  url: user.avatarUrl,
                  login: user.login,
                  radius: AppSizes.avatarSm,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // A login can be 39 characters; ellipsize, never overflow.
                    Text(
                      user.login,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: AppSpacing.xs / 2),
                    Text(
                      'id ${user.id} · ${user.type}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (!isPerson) _TypeBadge(type: user.type),
              Icon(Icons.chevron_right, color: theme.colorScheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}

/// Marks organisations and bots, which are otherwise indistinguishable.
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
        style: theme.textTheme.labelSmall
            ?.copyWith(color: theme.colorScheme.onSecondaryContainer),
      ),
    );
  }
}
