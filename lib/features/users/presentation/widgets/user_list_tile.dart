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
  const UserListTile({
    required this.user,
    required this.onTap,
    this.selected = false,
    this.heroEnabled = true,
    super.key,
  });

  /// The user to render.
  final UserSummary user;

  /// Navigation callback.
  final VoidCallback onTap;

  /// Whether this row is the one shown in the detail pane of a split view.
  ///
  /// Only ever true in two-pane layouts: in single-pane the detail screen has
  /// replaced the list, so there is nothing to indicate a selection against.
  final bool selected;

  /// Whether to wrap the avatar in a [Hero].
  ///
  /// MUST be false in a split view. The detail pane renders a Hero with the
  /// SAME tag, and in two-pane layouts both are mounted at once -- two heroes
  /// sharing a tag under one Navigator is a hard assertion failure, not a
  /// visual glitch. There is also no route transition to animate, so the Hero
  /// has nothing to do there anyway.
  final bool heroEnabled;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    // Only some sources label account types; absent means an ordinary user.
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
        // Selection is a background, not a border: a border would change the
        // row's height and make the list jump as selection moves.
        color: selected
            ? theme.colorScheme.secondaryContainer
            : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: <Widget>[
                // Shared element with the detail screen -- but only when a
                // route transition can actually happen. See [heroEnabled].
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
                      // Names and logins both run long; ellipsize, never overflow.
                      Text(
                        user.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: AppSpacing.xs / 2),
                      Text(
                        // Handle where the source has one, else the email,
                        // else the id -- always something identifying.
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
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}
