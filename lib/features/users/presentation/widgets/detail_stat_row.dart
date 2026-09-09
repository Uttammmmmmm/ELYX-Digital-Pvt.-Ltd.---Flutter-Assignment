library;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/user_detail.dart';
import '../strings/users_strings.dart';

class DetailStatRow extends StatelessWidget {
  const DetailStatRow({required this.detail, super.key});

  final UserDetail detail;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        if (detail.publicRepos != null)
          _Stat(label: UsersStrings.statRepos, value: detail.publicRepos!),
        if (detail.followers != null)
          _Stat(label: UsersStrings.statFollowers, value: detail.followers!),
        if (detail.following != null)
          _Stat(label: UsersStrings.statFollowing, value: detail.following!),
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

    return Semantics(
      label: '$value $label',
      excludeSemantics: true,
      child: Column(
        children: <Widget>[
          Text(
            UsersStrings.count(value),
            maxLines: 1,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xs / 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}
