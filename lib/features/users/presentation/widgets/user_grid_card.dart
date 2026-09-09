library;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/user_summary.dart';
import '../pages/user_detail_page.dart' show userAvatarHeroTag;
import 'user_avatar.dart';

class UserGridCard extends StatelessWidget {
  const UserGridCard({required this.user, required this.onTap, super.key});

  final UserSummary user;

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
                  login: user.displayName,
                  radius: AppSizes.avatarMd,
                ),
              ),
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
