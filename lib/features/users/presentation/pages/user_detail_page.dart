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

String userAvatarHeroTag(int id) => 'user_avatar_$id';

class UserDetailPage extends StatelessWidget {
  const UserDetailPage({required this.summary, super.key});

  final UserSummary summary;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<UserDetailBloc>(
      create: (_) =>
          sl<UserDetailBloc>(param1: summary)
            ..add(UserDetailRequested(summary.detailId)),
      child: const UserDetailView(),
    );
  }
}

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

    final String displayName = state.displayName;
    final String? handle = detail?.handle ?? state.seed.handle;

    return Column(
      children: <Widget>[
        const SizedBox(height: AppSpacing.lg),
        Center(
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

      void onRetry() =>
          context.read<UserDetailBloc>().add(const UserDetailRetried());

      final RateLimitFailure? rateLimited = state.rateLimitFailure;
      return rateLimited != null
          ? RateLimitView(resetAt: rateLimited.resetAt, onRetry: onRetry)
          : ErrorView(failure: failure, onRetry: onRetry);
    }

    return Column(
      children: <Widget>[
        if (detail.hasStats) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          DetailStatRow(detail: detail),
          const SizedBox(height: AppSpacing.sm),
          const Divider(height: 1),
        ],

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

        const DetailInfoRow(
          key: Key('row_phone'),
          icon: Icons.phone_outlined,
          label: UsersStrings.labelPhone,
          value: UsersStrings.phoneUnavailable,
          unavailable: true,
        ),

        const Divider(height: 1),

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
            onTap: () =>
                _copy(context, UsersStrings.labelWebsite, detail.blog!),
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
