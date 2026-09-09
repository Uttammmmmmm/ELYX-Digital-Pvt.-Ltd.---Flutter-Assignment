/// A user as a card, for medium and expanded layouts.
library;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/user_summary.dart';
import '../pages/user_detail_page.dart' show userAvatarHeroTag;
import 'user_avatar.dart';

/// The grid counterpart to `UserListTile`.
///
/// Same data, same tap target, same Hero tag -- only the arrangement differs.
/// Reusing the tile in a grid would waste the width; a row of avatar + text
/// pinned left looks broken in a 280dp-wide cell.
class UserGridCard extends StatelessWidget {
  const UserGridCard({required this.user, required this.onTap, super.key});

  /// The user to render.
  final UserSummary user;

  /// Navigation callback.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Hero(
                tag: userAvatarHeroTag(user.id),
                child: UserAvatar(
                  url: user.avatarUrl,
                  login: user.login,
                  radius: AppSizes.avatarMd,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                user.login,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: AppSpacing.xs / 2),
              Text(
                'id ${user.id}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
