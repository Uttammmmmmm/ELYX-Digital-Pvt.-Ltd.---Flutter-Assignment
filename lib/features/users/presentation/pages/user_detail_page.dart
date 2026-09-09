/// The user profile screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/user_detail.dart';
import '../../domain/entities/user_summary.dart';
import '../bloc/user_detail_bloc.dart';
import '../bloc/user_detail_event.dart';
import '../bloc/user_detail_state.dart';
import '../strings/users_strings.dart';
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
/// real avatar and name instead of a spinner. The ONLY `sl<T>()` call here.
class UserDetailPage extends StatelessWidget {
  const UserDetailPage({required this.summary, super.key});

  /// What the list already knew about this user.
  final UserSummary summary;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<UserDetailBloc>(
      // BlocProvider owns the bloc it creates and closes it in its own
      // dispose(), which runs when this route is popped. Combined with the
      // isClosed guard in the bloc, an in-flight request that lands after the
      // pop is discarded instead of emitting into a closed controller.
      create: (_) => sl<UserDetailBloc>(param1: summary)
        ..add(UserDetailRequested(summary.detailId)),
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
          appBar: AppBar(title: Text(state.displayName)),
          body: ListView(
            children: <Widget>[
              // Rendered from the SEED, so it is on screen immediately and
              // stays put through loading, success and failure alike.
              _Header(state: state),
              const SizedBox(height: AppSpacing.md),
              const Divider(height: 1),
              _Body(state: state),
              const SizedBox(height: AppSpacing.xl),
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

    // Never blank -- displayName falls back through name, then handle, then
    // id -- and available from the seed, so it is on screen before the
    // request returns and survives a failure.
    final String displayName = state.displayName;
    final String? handle = detail?.handle ?? state.seed.handle;

    return Column(
      children: <Widget>[
        const SizedBox(height: AppSpacing.lg),
        Center(
          // Shared element with the list tile. Keyed by id, which is unique
          // and stable across both sources.
          child: Hero(
            tag: userAvatarHeroTag(state.seed.id),
            child: UserAvatar(
              url: state.seed.avatarUrl,
              login: displayName,
              radius: AppSizes.avatarLg,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          displayName,
          key: const Key('detail_name'),
          style: theme.textTheme.headlineSmall,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        // Suppressed when the handle IS the display name, and absent entirely
        // on sources that have no handle.
        if (handle != null && handle != displayName)
          Text(
            '@$handle',
            key: const Key('detail_handle'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium,
          ),
        if (detail?.bio != null) ...<Widget>[
          const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Text(
              detail!.bio!,
              key: const Key('detail_bio'),
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
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
      ..showSnackBar(SnackBar(content: Text(UsersStrings.copied(label))));
  }

  @override
  Widget build(BuildContext context) {
    if (state.isLoadingBody) return const DetailBodySkeleton();

    final UserDetail? detail = state.detail;

    if (detail == null) {
      final Failure? failure = state.failure;
      if (failure == null) return const SizedBox.shrink();

      // No fixed height: the state widgets size themselves and scroll when
      // the space is short.
      void onRetry() =>
          context.read<UserDetailBloc>().add(const UserDetailRetried());

      final RateLimitFailure? rateLimited = state.rateLimitFailure;
      return rateLimited != null
          ? RateLimitView(resetAt: rateLimited.resetAt, onRetry: onRetry)
          : ErrorView(failure: failure, onRetry: onRetry);
    }

    return Column(
      children: <Widget>[
        // Hidden entirely on a source with no counters, rather than rendered
        // as three zeros -- which would be fabricated data.
        if (detail.hasStats) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          DetailStatRow(detail: detail),
          const SizedBox(height: AppSpacing.sm),
          const Divider(height: 1),
        ],

        // --- The three the assignment requires: ALWAYS rendered -----------
        DetailInfoRow(
          key: const Key('row_name'),
          icon: Icons.badge_outlined,
          label: UsersStrings.labelName,
          value: detail.displayName,
        ),
        DetailInfoRow(
          key: const Key('row_email'),
          icon: Icons.alternate_email,
          label: UsersStrings.labelEmail,
          value: detail.email ?? UsersStrings.emailUnavailable,
          unavailable: !detail.hasEmail,
          onTap: detail.hasEmail
              ? () => _copy(context, UsersStrings.labelEmail, detail.email!)
              : null,
        ),
        // PHONE: permanently unavailable, and that is CORRECT, not a stub.
        // NEITHER supported API exposes a phone number -- reqres returns id,
        // email, first_name, last_name and avatar; GitHub has no phone
        // concept at any scope. This is a documented gap between the
        // assignment and the APIs it names, stated plainly rather than
        // hidden, and never fabricated. There is no `phone` field on any
        // entity to read from, by construction.
        const DetailInfoRow(
          key: Key('row_phone'),
          icon: Icons.phone_outlined,
          label: UsersStrings.labelPhone,
          value: UsersStrings.phoneUnavailable,
          unavailable: true,
        ),

        const Divider(height: 1),

        // --- Optional: hidden entirely when the source has no value -------
        if (detail.company != null)
          DetailInfoRow(
            key: const Key('row_company'),
            icon: Icons.business_outlined,
            label: UsersStrings.labelCompany,
            value: detail.company!,
          ),
        if (detail.location != null)
          DetailInfoRow(
            key: const Key('row_location'),
            icon: Icons.place_outlined,
            label: UsersStrings.labelLocation,
            value: detail.location!,
          ),
        if (detail.blog != null)
          DetailInfoRow(
            key: const Key('row_blog'),
            icon: Icons.link,
            label: UsersStrings.labelWebsite,
            value: detail.blog!,
            onTap: () => _copy(context, UsersStrings.labelWebsite, detail.blog!),
          ),
        if (detail.createdAt != null)
          DetailInfoRow(
            key: const Key('row_member_since'),
            icon: Icons.calendar_today_outlined,
            label: UsersStrings.labelMemberSince,
            value: DateFormat.yMMMM().format(detail.createdAt!),
          ),
        if (detail.profileUrl != null)
          DetailInfoRow(
            key: const Key('row_profile'),
            icon: Icons.open_in_new,
            label: UsersStrings.labelProfile,
            value: detail.profileUrl!,
            onTap: () =>
                _copy(context, UsersStrings.labelProfile, detail.profileUrl!),
          ),
      ],
    );
  }
}
