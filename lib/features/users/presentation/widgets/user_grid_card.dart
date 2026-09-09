library;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/user_summary.dart';
import '../pages/user_detail_page.dart' show userAvatarHeroTag;
import 'user_avatar.dart';

class UserGridCard extends StatelessWidget {
  const UserGridCard({
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

    final Widget avatar = UserAvatar(
      url: user.avatarUrl,
      login: user.displayName,
      radius: AppSizes.avatarMd,
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      color: selected ? theme.colorScheme.secondaryContainer : null,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (heroEnabled)
                Hero(tag: userAvatarHeroTag(user.id), child: avatar)
              else
                avatar,
              const SizedBox(height: AppSpacing.sm),
              Text(
                user.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
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
      ),
    );
  }
}
