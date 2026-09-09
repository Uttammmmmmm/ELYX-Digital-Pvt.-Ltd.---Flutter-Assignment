/// The user profile screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/user_detail.dart';
import '../../domain/entities/user_summary.dart';
import '../bloc/user_detail_bloc.dart';
import '../bloc/user_detail_event.dart';
import '../bloc/user_detail_state.dart';
import '../widgets/detail_body_skeleton.dart';
import '../widgets/detail_info_row.dart';
import '../widgets/detail_stat_row.dart';
import '../widgets/error_view.dart';
import '../widgets/rate_limit_view.dart';
import '../widgets/user_avatar.dart';

/// Hero tag for a user's avatar, shared by the list tile and this screen.
String userAvatarHeroTag(int id) => 'user_avatar_$id';

/// Route-level wrapper.
///
/// Takes the [UserSummary] the list already had, so the screen opens with a
/// real avatar and login instead of a spinner. The ONLY `sl<T>()` call on
/// this screen.
class UserDetailPage extends StatelessWidget {
  const UserDetailPage({required this.summary, super.key});

  /// What the list already knew about this user.
  final UserSummary summary;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<UserDetailBloc>(
      // BlocProvider owns the bloc it creates and calls close() in its own
      // dispose(), which runs when this route is popped. Combined with the
      // isClosed guard in the bloc, an in-flight request that lands after the
      // pop is discarded instead of emitting into a closed controller.
      create: (_) => sl<UserDetailBloc>(param1: summary)
        ..add(UserDetailRequested(summary.login)),
      child: const UserDetailView(),
    );
  }
}

/// The profile itself. Expects a [UserDetailBloc] above it.
class UserDetailView extends StatelessWidget {
  const UserDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<UserDetailBloc, UserDetailState>(
      builder: (BuildContext context, UserDetailState state) {
        return Scaffold(
          appBar: AppBar(title: Text(state.login)),
          body: ListView(
            children: <Widget>[
              // Rendered from the SEED, so it is on screen immediately and
              // stays put through loading, success and failure alike.
              _Header(state: state),
              const SizedBox(height: 16),
              const Divider(height: 1),
              _Body(state: state),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.state});

  final UserDetailState state;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final UserDetail? detail = state.detail;

    // Name falls back to the login, so this line is never blank -- not while
    // loading, not on failure, not when GitHub has no name for the user.
    final String displayName = detail?.displayName ?? state.seed.login;

    return Column(
      children: <Widget>[
        const SizedBox(height: 24),
        Center(
          // Shared element with the list tile. The tag is keyed by id, which
          // is unique and stable; keying by login would break if two routes
          // ever showed the same user.
          child: Hero(
            tag: userAvatarHeroTag(state.seed.id),
            child: UserAvatar(
              url: state.seed.avatarUrl,
              login: state.seed.login,
              radius: 48,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          displayName,
          key: const Key('detail_name'),
          style: theme.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        // Suppressed when the name IS the login -- no point printing it twice.
        if (displayName != state.seed.login)
          Text(
            '@${state.seed.login}',
            key: const Key('detail_handle'),
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        if (detail?.bio != null) ...<Widget>[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              detail!.bio!,
              key: const Key('detail_bio'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ],
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state});

  final UserDetailState state;

  void _copy(BuildContext context, String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$label copied')));
  }

  @override
  Widget build(BuildContext context) {
    if (state.isLoadingBody) return const DetailBodySkeleton();

    final UserDetail? detail = state.detail;

    if (detail == null) {
      final Failure? failure = state.failure;
      if (failure == null) return const SizedBox.shrink();

      final RateLimitFailure? rateLimited = state.rateLimitFailure;
      return SizedBox(
        height: 360,
        child: rateLimited != null
            ? RateLimitView(
                resetAt: rateLimited.resetAt,
                onRetry: () =>
                    context.read<UserDetailBloc>().add(const UserDetailRetried()),
              )
            : ErrorView(
                failure: failure,
                onRetry: () =>
                    context.read<UserDetailBloc>().add(const UserDetailRetried()),
              ),
      );
    }

    return Column(
      children: <Widget>[
        const SizedBox(height: 16),
        DetailStatRow(detail: detail),
        const SizedBox(height: 8),
        const Divider(height: 1),

        // --- The three the assignment requires: always rendered -----------
        DetailInfoRow(
          key: const Key('row_name'),
          icon: Icons.badge_outlined,
          label: 'Name',
          value: detail.displayName,
        ),
        DetailInfoRow(
          key: const Key('row_email'),
          icon: Icons.alternate_email,
          label: 'Email',
          value: detail.email ?? 'Not publicly listed',
          unavailable: !detail.hasEmail,
          onTap: detail.hasEmail
              ? () => _copy(context, 'Email', detail.email!)
              : null,
        ),
        // PHONE: permanently unavailable, and that is CORRECT, not a stub.
        //
        // The assignment asks for a phone number. The GitHub REST API exposes
        // none -- not null, not optional: there is no phone concept anywhere
        // in the user resource. This is a documented gap between the
        // assignment spec and the API it was pointed at, so the screen states
        // it plainly instead of hiding the row or, far worse, generating a
        // plausible-looking fake number. A fabricated value would be
        // indistinguishable from real data to anyone reading the screen.
        // There is deliberately no `phone` field on UserDetail to read from.
        const DetailInfoRow(
          key: Key('row_phone'),
          icon: Icons.phone_outlined,
          label: 'Phone',
          value: 'Not provided by the GitHub API',
          unavailable: true,
        ),

        const Divider(height: 1),

        // --- Optional: hidden entirely when null --------------------------
        if (detail.company != null)
          DetailInfoRow(
            key: const Key('row_company'),
            icon: Icons.business_outlined,
            label: 'Company',
            value: detail.company!,
          ),
        if (detail.location != null)
          DetailInfoRow(
            key: const Key('row_location'),
            icon: Icons.place_outlined,
            label: 'Location',
            value: detail.location!,
          ),
        if (detail.blog != null)
          DetailInfoRow(
            key: const Key('row_blog'),
            icon: Icons.link,
            label: 'Website',
            value: detail.blog!,
            onTap: () => _copy(context, 'Website', detail.blog!),
          ),
        DetailInfoRow(
          key: const Key('row_member_since'),
          icon: Icons.calendar_today_outlined,
          label: 'Member since',
          value: DateFormat.yMMMM().format(detail.createdAt),
        ),
        DetailInfoRow(
          key: const Key('row_profile'),
          icon: Icons.open_in_new,
          label: 'Profile',
          value: detail.htmlUrl,
          onTap: () => _copy(context, 'Profile URL', detail.htmlUrl),
        ),
      ],
    );
  }
}
