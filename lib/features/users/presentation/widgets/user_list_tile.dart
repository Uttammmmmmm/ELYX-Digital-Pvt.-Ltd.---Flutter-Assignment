/// A single row in the users list.
library;

import 'package:flutter/material.dart';

import '../../../../core/widgets/network_avatar.dart';
import '../../domain/entities/user_summary.dart';
import '../formatters/user_display.dart';

/// Renders one [UserSummary].
///
/// Shows only what the LIST endpoint actually returns -- login, avatar, type.
/// No name and no email, because constraint (b) means we do not have them and
/// fetching them would cost one request per row. A trailing badge marks
/// organisations and bots, which are otherwise indistinguishable from users.
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

    return ListTile(
      onTap: onTap,
      leading: NetworkAvatar(url: user.avatarUrl, fallbackInitial: user.login),
      title: Text(
        user.login,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleSmall,
      ),
      subtitle: Text(
        UserDisplay.handle(user.login),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (!isPerson)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, color: theme.colorScheme.outline),
        ],
      ),
    );
  }
}
