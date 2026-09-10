library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../strings/users_strings.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/responsive.dart';
import '../../domain/entities/user_summary.dart';
import '../bloc/users_bloc.dart';
import '../bloc/users_event.dart';
import '../bloc/users_state.dart';
import '../widgets/empty_view.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_view.dart';
import '../widgets/no_search_results_view.dart';
import '../widgets/offline_banner.dart';
import '../widgets/pagination_footer.dart';
import '../widgets/rate_limit_view.dart';
import '../widgets/user_grid_card.dart';
import '../widgets/user_list_tile.dart';
import '../widgets/user_tile_metrics.dart';
import '../widgets/user_search_bar.dart';

class UsersListView extends StatefulWidget {
  const UsersListView({
    required this.connectivity,
    this.onUserSelected,
    this.selectedDetailId,
    this.showAppBar = true,
    super.key,
  });

  final Stream<bool> connectivity;

  final void Function(UserSummary user)? onUserSelected;

  final String? selectedDetailId;

  final bool showAppBar;

  @override
  State<UsersListView> createState() => _UsersListViewState();
}

class _UsersListViewState extends State<UsersListView> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  static const double _loadMoreThreshold = 200;

  int _lastAutoFillCount = -1;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) => _fillViewport());
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _fillViewport() {
    if (!mounted || !_scrollController.hasClients) return;
    if (_scrollController.position.maxScrollExtent > 0) return;

    final UsersState state = context.read<UsersBloc>().state;
    if (!state.canLoadMore) return;

    if (state.allUsers.length <= _lastAutoFillCount) return;
    _lastAutoFillCount = state.allUsers.length;

    context.read<UsersBloc>().add(const UsersNextPageRequested());
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final ScrollPosition position = _scrollController.position;
    if (position.pixels < position.maxScrollExtent - _loadMoreThreshold) {
      return;
    }

    context.read<UsersBloc>().add(const UsersNextPageRequested());
  }

  Future<void> _onRefresh() async {
    final UsersBloc bloc = context.read<UsersBloc>()
      ..add(const UsersRefreshed());

    try {
      await bloc.stream.firstWhere(
        (UsersState s) => s.status != UsersStatus.refreshing,
      );
    } on StateError {
      // The bloc closed before the refresh settled -- the page was popped
      // mid-pull. `firstWhere` completes with an error when its stream ends
      // without a match, and that error would surface as an unhandled
      // exception through RefreshIndicator's future. There is nothing left to
      // show, so end the indicator quietly.
    }
  }

  void _openDetail(UserSummary user) {
    final void Function(UserSummary)? select = widget.onUserSelected;
    if (select != null) {
      select(user);
      return;
    }
    Navigator.of(context).pushNamed(AppRoutes.userDetail, arguments: user);
  }

  void _retry() =>
      context.read<UsersBloc>().add(const UsersFailedPageRetried());

  void _loadMore() =>
      context.read<UsersBloc>().add(const UsersNextPageRequested());

  void _clearSearch() {
    _searchController.clear();
    context.read<UsersBloc>().add(const UsersSearchCleared());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(title: const Text(UsersStrings.listTitle))
          : null,
      body: Column(
        children: <Widget>[
          UserSearchBar(
            controller: _searchController,
            onChanged: (String q) =>
                context.read<UsersBloc>().add(UsersSearchQueryChanged(q)),
            onCleared: _clearSearch,
          ),
          OfflineBanner(isOnline: widget.connectivity),
          Expanded(
            child: BlocConsumer<UsersBloc, UsersState>(
              listener: (_, _) => WidgetsBinding.instance.addPostFrameCallback(
                (_) => _fillViewport(),
              ),
              builder: _body,
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, UsersState state) {
    if (state.status == UsersStatus.initial ||
        (state.status == UsersStatus.loading && state.allUsers.isEmpty)) {
      return const LoadingView();
    }

    if (state.hasBlockingFailure) {
      final DateTime? resetAt = state.rateLimitResetAt;
      if (state.rateLimitFailure != null && resetAt != null) {
        return RateLimitView(resetAt: resetAt, onRetry: _retry);
      }
      return ErrorView(failure: state.failure!, onRetry: _retry);
    }

    if (state.isSearchEmpty) {
      return NoSearchResultsView(
        query: state.searchQuery,
        loadedCount: state.allUsers.length,
        onClearSearch: _clearSearch,
        onLoadMore: state.hasReachedEnd ? null : _loadMore,
      );
    }

    if (state.allUsers.isEmpty) {
      return EmptyView(onRefresh: () => unawaited(_onRefresh()));
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,

      child: ResponsiveBuilder(
        builder: (BuildContext context, WindowSizeClass sizeClass) =>
            sizeClass == WindowSizeClass.compact
            ? _buildList(context, state)
            : _buildGrid(context, state, sizeClass),
      ),
    );
  }

  Widget _buildList(BuildContext context, UsersState state) {
    return CustomScrollView(
      key: const PageStorageKey<String>('users_list'),
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: <Widget>[
        SliverFixedExtentList(
          itemExtent: UserTileMetrics.heightFor(context),
          delegate: SliverChildBuilderDelegate((
            BuildContext context,
            int index,
          ) {
            final UserSummary user = state.visibleUsers[index];
            return UserListTile(
              key: Key('user_tile_${user.id}'),
              user: user,
              onTap: () => _openDetail(user),
              selected: user.detailId == widget.selectedDetailId,
              heroEnabled: widget.onUserSelected == null,
            );
          }, childCount: state.visibleUsers.length),
        ),
        SliverToBoxAdapter(child: _footer(state)),
      ],
    );
  }

  Widget _buildGrid(
    BuildContext context,
    UsersState state,
    WindowSizeClass sizeClass,
  ) {
    final int columns = sizeClass.gridColumns;

    return CustomScrollView(
      key: const PageStorageKey<String>('users_grid'),
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: <Widget>[
        SliverPadding(
          padding: const EdgeInsets.all(AppSpacing.md),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: AppSpacing.md,
              crossAxisSpacing: AppSpacing.md,
              mainAxisExtent: UserTileMetrics.cardHeightFor(context),
            ),
            delegate: SliverChildBuilderDelegate((
              BuildContext context,
              int index,
            ) {
              final UserSummary user = state.visibleUsers[index];
              return UserGridCard(
                key: Key('user_tile_${user.id}'),
                user: user,
                onTap: () => _openDetail(user),
                selected: user.detailId == widget.selectedDetailId,
                heroEnabled: widget.onUserSelected == null,
              );
            }, childCount: state.visibleUsers.length),
          ),
        ),
        SliverToBoxAdapter(child: _footer(state)),
      ],
    );
  }

  Widget _footer(UsersState state) => PaginationFooter(
    mode: _footerMode(state),
    errorMessage: state.failure?.message,
    onRetry: _retry,
  );

  PaginationFooterMode _footerMode(UsersState state) {
    if (state.isFiltering) return PaginationFooterMode.idle;
    if (state.status == UsersStatus.loadingMore) {
      return PaginationFooterMode.loading;
    }
    if (state.hasInlineFailure) return PaginationFooterMode.error;
    if (state.hasReachedEnd) return PaginationFooterMode.end;
    return PaginationFooterMode.idle;
  }
}
