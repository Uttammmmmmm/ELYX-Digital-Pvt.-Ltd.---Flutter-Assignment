/// The users list screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/empty_view.dart';
import '../../../../core/widgets/user_tile_shimmer.dart';
import '../../domain/entities/user_summary.dart';
import '../bloc/users_bloc.dart';
import '../bloc/users_event.dart';
import '../bloc/users_state.dart';
import '../widgets/pagination_footer.dart';
import '../widgets/user_list_tile.dart';
import '../widgets/user_search_bar.dart';
import 'user_detail_page.dart';

/// Route-level wrapper that supplies the [UsersBloc].
///
/// Split from [UsersListView] so widget tests can drive the view with a bloc
/// they control, without booting the service locator.
class UsersListPage extends StatelessWidget {
  const UsersListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<UsersBloc>(
      create: (_) => sl<UsersBloc>()..add(const UsersStarted()),
      child: const UsersListView(),
    );
  }
}

/// The list itself. Expects a [UsersBloc] above it.
class UsersListView extends StatefulWidget {
  const UsersListView({super.key});

  @override
  State<UsersListView> createState() => _UsersListViewState();
}

class _UsersListViewState extends State<UsersListView> {
  final ScrollController _controller = ScrollController();

  /// Trigger a page early enough that the spinner is rarely seen.
  static const double _loadMoreThreshold = 300;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_controller.hasClients) return;
    final double remaining =
        _controller.position.maxScrollExtent - _controller.position.pixels;
    if (remaining > _loadMoreThreshold) return;

    // Safe to fire repeatedly: the bloc's droppable() transformer collapses a
    // burst into one request, and short-circuits at the end of the list.
    context.read<UsersBloc>().add(const UsersLoadMoreRequested());
  }

  Future<void> _onRefresh() async {
    final UsersBloc bloc = context.read<UsersBloc>()
      ..add(const UsersRefreshRequested());
    // Hold the indicator until the refresh actually settles, rather than
    // dismissing it on the next frame.
    await bloc.stream.firstWhere((UsersState s) => !s.isRefreshing);
  }

  void _openDetail(UserSummary user) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => UserDetailPage(login: user.login),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('GitHub Users')),
      body: Column(
        children: <Widget>[
          UserSearchBar(
            onChanged: (String q) =>
                context.read<UsersBloc>().add(UsersSearchChanged(q)),
          ),
          Expanded(
            child: BlocBuilder<UsersBloc, UsersState>(
              builder: (BuildContext context, UsersState state) =>
                  _body(context, state),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, UsersState state) {
    // Cold load: skeleton rows rather than a bare spinner.
    if (state.status == UsersStatus.initial ||
        (state.status == UsersStatus.loading && state.users.isEmpty)) {
      return const UserTileShimmer();
    }

    // Something failed and there is nothing behind it. AppErrorView routes a
    // RateLimitFailure to the countdown view automatically.
    if (state.hasBlockingFailure) {
      return AppErrorView(
        failure: state.failure!,
        onRetry: () =>
            context.read<UsersBloc>().add(const UsersRetryRequested()),
      );
    }

    // A search with no matches is not an error -- and must not imply the user
    // does not exist on GitHub, only that they are not among those loaded.
    if (state.visibleUsers.isEmpty && state.isFiltering) {
      return EmptyView(
        message: 'No loaded user matches "${state.query}".\n'
            'GitHub has no name filter, so only the '
            '${state.users.length} users loaded so far are searched.',
        action: state.hasReachedEnd
            ? null
            : OutlinedButton(
                onPressed: () => context
                    .read<UsersBloc>()
                    .add(const UsersLoadMoreRequested()),
                child: const Text('Load more users'),
              ),
      );
    }

    if (state.visibleUsers.isEmpty) {
      return const EmptyView(
        message: 'No users to show.',
        icon: Icons.people_outline,
      );
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: ListView.separated(
        controller: _controller,
        // Always scrollable so pull-to-refresh works even on a short list.
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: state.visibleUsers.length + 1,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (BuildContext context, int index) {
          if (index == state.visibleUsers.length) {
            return PaginationFooter(
              state: state,
              onRetry: () =>
                  context.read<UsersBloc>().add(const UsersRetryRequested()),
              onLoadMore: () =>
                  context.read<UsersBloc>().add(const UsersLoadMoreRequested()),
            );
          }

          final UserSummary user = state.visibleUsers[index];
          return UserListTile(
            key: ValueKey<int>(user.id),
            user: user,
            onTap: () => _openDetail(user),
          );
        },
      ),
    );
  }
}
