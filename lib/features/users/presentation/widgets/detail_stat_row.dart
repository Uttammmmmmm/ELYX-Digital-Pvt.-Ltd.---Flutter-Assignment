/// Repo/follower counters.
library;

import 'package:flutter/material.dart';

import '../../domain/entities/user_detail.dart';
import '../formatters/user_display.dart';

/// The public counters from the profile document.
class DetailStatRow extends StatelessWidget {
  const DetailStatRow({required this.detail, super.key});

  /// The profile whose counters to show.
  final UserDetail detail;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        _Stat(label: 'Repos', value: detail.publicRepos),
        _Stat(label: 'Followers', value: detail.followers),
        _Stat(label: 'Following', value: detail.following),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      children: <Widget>[
        Text(
          UserDisplay.count(value),
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.labelSmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
