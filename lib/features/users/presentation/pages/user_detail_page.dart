/// The user profile screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../core/widgets/network_avatar.dart';
import '../../domain/entities/user_detail.dart';
import '../bloc/user_detail_bloc.dart';
import '../bloc/user_detail_event.dart';
import '../bloc/user_detail_state.dart';
import '../formatters/user_display.dart';
import '../widgets/detail_field_tile.dart';
import '../widgets/detail_stat_row.dart';

/// Route-level wrapper that supplies the [UserDetailBloc].
class UserDetailPage extends StatelessWidget {
  const UserDetailPage({required this.login, super.key});

  /// The handle to load.
  final String login;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<UserDetailBloc>(
      create: (_) => sl<UserDetailBloc>()..add(UserDetailRequested(login)),
      child: UserDetailView(login: login),
    );
  }
}

/// The profile itself. Expects a [UserDetailBloc] above it.
class UserDetailView extends StatelessWidget {
  const UserDetailView({required this.login, super.key});

  /// The handle being shown; used for the title and retry events.
  final String login;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(login)),
      body: BlocBuilder<UserDetailBloc, UserDetailState>(
        builder: (BuildContext context, UserDetailState state) {
          // Sealed state -> exhaustive switch; a new state cannot be forgotten.
          return switch (state) {
            UserDetailInitial() || UserDetailLoading() => const AppLoader(),
            UserDetailError(:final Failure failure) => AppErrorView(
                failure: failure,
                onRetry: () => context
                    .read<UserDetailBloc>()
                    .add(UserDetailRequested(login)),
              ),
            UserDetailLoaded(:final UserDetail detail) => _Profile(detail),
          };
        },
      ),
    );
  }
}

class _Profile extends StatelessWidget {
  const _Profile(this.detail);

  final UserDetail detail;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    // No pull-to-refresh here: `UserRepository.getUserDetail` takes no
    // force-refresh flag, so a re-request inside the 24h TTL would be
    // answered from cache and the gesture would silently do nothing. An
    // affordance that does nothing is worse than none.
    return ListView(
      children: <Widget>[
        const SizedBox(height: 24),
        Center(
          child: NetworkAvatar(
            url: detail.avatarUrl,
            fallbackInitial: detail.login,
            radius: 48,
          ),
        ),
        const SizedBox(height: 16),

        // displayName falls back to the login, so this is never empty.
        Center(
          child: Text(
            detail.displayName,
            key: const Key('detail_name'),
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
        ),
        // Skipped when the name already IS the login -- no point repeating it.
        if (!UserDisplay.namesAreSame(detail))
          Center(
            child: Text(
              UserDisplay.handle(detail.login),
              key: const Key('detail_handle'),
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),

        if (detail.bio != null) ...<Widget>[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              detail.bio!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],

        const SizedBox(height: 24),
        DetailStatRow(detail: detail),
        const SizedBox(height: 16),
        const Divider(height: 1),

        DetailFieldTile(
          icon: Icons.alternate_email,
          label: 'Email',
          value: UserDisplay.email(detail),
          isUnavailable: !detail.hasEmail,
        ),

        // Constraint (c): GitHub has no phone field at all. This value is NOT
        // read from the entity -- there is no `phone` property to read, by
        // design. It is a static row, styled as unavailable, because
        // inventing a plausible number would be fabricating data.
        const DetailFieldTile(
          key: Key('detail_phone'),
          icon: Icons.phone_outlined,
          label: 'Phone',
          value: UserDisplay.phoneUnavailable,
          isUnavailable: true,
        ),

        DetailFieldTile(
          icon: Icons.place_outlined,
          label: 'Location',
          value: UserDisplay.orUnavailable(detail.location),
          isUnavailable: detail.location == null,
        ),
        DetailFieldTile(
          icon: Icons.business_outlined,
          label: 'Company',
          value: UserDisplay.orUnavailable(detail.company),
          isUnavailable: detail.company == null,
        ),
        DetailFieldTile(
          icon: Icons.link,
          label: 'Website',
          value: UserDisplay.orUnavailable(detail.blog),
          isUnavailable: detail.blog == null,
        ),
        DetailFieldTile(
          icon: Icons.code,
          label: 'Profile',
          value: detail.htmlUrl,
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}
