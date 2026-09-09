/// A single row in the users list.
library;

import 'package:flutter/material.dart';

import '../../domain/entities/user_summary.dart';
import 'loading_view.dart' show UserTileMetrics;
import '../pages/user_detail_page.dart' show userAvatarHeroTag;
import 'user_avatar.dart';

/// Renders one [UserSummary].
///
/// Shows only what the LIST endpoint returns -- login, avatar, id, type. No
/// name and no email, because constraint (b) means we do not have them and
/// fetching them would cost one request per row against a 60/hour budget.
///
/// Fixed height ([UserTileMetrics.height]) so `ListView.builder` can compute
/// scroll extents without measuring children: smoother scrolling, and a
/// meaningful `maxScrollExtent` before layout settles.
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
      height: UserTileMetrics.height,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: <Widget>[
              // Shared element with the detail screen.
              Hero(
                tag: userAvatarHeroTag(user.id),
                child: UserAvatar(url: user.avatarUrl, login: user.login),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      user.login,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'id ${user.id} · ${user.type}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (!isPerson)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    user.type,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
              Icon(Icons.chevron_right, color: theme.colorScheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}
