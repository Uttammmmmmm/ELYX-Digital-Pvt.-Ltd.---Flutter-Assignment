/// The users list screen.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/routing/app_routes.dart';
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
import '../widgets/user_list_tile.dart';
import '../widgets/user_search_bar.dart';

/// The list itself. Expects a [UsersBloc] above it.
///
/// Holds no business logic: it translates gestures into events and state into
/// widgets. Every decision it appears to make -- when more can be loaded,
/// whether a failure is inline or blocking -- is a getter on [UsersState].
class UsersListView extends StatefulWidget {
  const UsersListView({required this.connectivity, super.key});

  /// Emits false when the device has no network interface. Injected rather
  /// than resolved here, so no widget touches the service locator.
  final Stream<bool> connectivity;

  @override
  State<UsersListView> createState() => _UsersListViewState();
}

class _UsersListViewState extends State<UsersListView> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  /// Trigger a page this far from the bottom, so the next rows are usually
  /// already there by the time the user reaches them.
  ///
  /// A THRESHOLD, not equality: `pixels == maxScrollExtent` is almost never
  /// true. Scroll physics overshoot, bounce past the extent on iOS, and land
  /// on fractional pixel values, so an equality check silently never fires.
  static const double _loadMoreThreshold = 200;

  /// How many users existed the last time the viewport auto-filled.
  ///
  /// The termination guard for [_fillViewport]. Without it, a page that
  /// returns a cursor but adds no new rows -- every row a duplicate, or a
  /// backend that keeps handing out cursors -- leaves the viewport unfilled
  /// forever, so the post-frame callback fires again, and again. That is an
  /// unbounded request loop against a 60/hour budget. Requiring strictly more
  /// users than the previous attempt makes progress a precondition.
  int _lastAutoFillCount = -1;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    // A first page that does not fill the viewport produces
    // maxScrollExtent == 0, so the user cannot scroll, so the scroll listener
    // never fires, so pagination stalls permanently. Common on tall screens
    // and tablets with a 10-item page. Ask for the next page explicitly once
    // layout has settled.
    WidgetsBinding.instance.addPostFrameCallback((_) => _fillViewport());
  }

  @override
  void dispose() {
    // Both controllers own resources the widget tree does not reclaim on its
    // own. A ScrollController left with a listener keeps this State alive
    // through the closure, and a TextEditingController is a ChangeNotifier
    // whose listeners keep their subtree reachable -- so skipping either one
    // leaks the entire screen every time the user navigates back to it.
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Requests another page when the list is too short to scroll.
  void _fillViewport() {
    if (!mounted || !_scrollController.hasClients) return;
    if (_scrollController.position.maxScrollExtent > 0) return;

    final UsersState state = context.read<UsersBloc>().state;
    if (!state.canLoadMore) return;

    // Only auto-fill if the last attempt actually grew the list.
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
    // Safe to fire repeatedly: the bloc's droppable() transformer collapses a
    // burst into one request and short-circuits at the end of the list.
    context.read<UsersBloc>().add(const UsersNextPageRequested());
  }

  /// Completes only when the refresh actually settles.
  ///
  /// `RefreshIndicator` keeps its spinner up until this future resolves. The
  /// naive version returns immediately after dispatching, and the spinner
  /// vanishes a frame later while the request is still in flight. Awaiting
  /// the bloc's own stream until the status leaves `refreshing` ties the
  /// indicator to the real work.
  Future<void> _onRefresh() async {
    final UsersBloc bloc = context.read<UsersBloc>()..add(const UsersRefreshed());
    await bloc.stream
        .firstWhere((UsersState s) => s.status != UsersStatus.refreshing);
  }

  /// Pushes the detail screen, handing over what the list already knows so
  /// the next screen opens with a real header rather than a spinner.
  void _openDetail(UserSummary user) => Navigator.of(context).pushNamed(
        AppRoutes.userDetail,
        arguments: user,
      );

  void _retry() => context.read<UsersBloc>().add(const UsersFailedPageRetried());

  void _loadMore() =>
      context.read<UsersBloc>().add(const UsersNextPageRequested());

  void _clearSearch() {
    _searchController.clear();
    context.read<UsersBloc>().add(const UsersSearchCleared());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('GitHub Users')),
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
              // A newly-arrived page may still not fill the viewport.
              listener: (_, _) => WidgetsBinding.instance
                  .addPostFrameCallback((_) => _fillViewport()),
              builder: _body,
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, UsersState state) {
    // Cold load: skeleton rows rather than a bare spinner.
    if (state.status == UsersStatus.initial ||
        (state.status == UsersStatus.loading && state.allUsers.isEmpty)) {
      return const LoadingView();
    }

    // A failure with nothing behind it takes the whole screen. Rate limiting
    // gets its own view, because its retry must stay disabled.
    if (state.hasBlockingFailure) {
      final DateTime? resetAt = state.rateLimitResetAt;
      if (state.rateLimitFailure != null && resetAt != null) {
        return RateLimitView(resetAt: resetAt, onRetry: _retry);
      }
      return ErrorView(failure: state.failure!, onRetry: _retry);
    }

    // A search that matched nothing is NOT the same as no users existing.
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
      child: ListView.builder(
        key: const Key('users_list'),
        controller: _scrollController,
        // Always scrollable, so pull-to-refresh works on a short list too.
        physics: const AlwaysScrollableScrollPhysics(),
        // +1 for the footer slot.
        itemCount: state.visibleUsers.length + 1,
        itemBuilder: (BuildContext context, int index) {
          if (index == state.visibleUsers.length) {
            return PaginationFooter(
              mode: _footerMode(state),
              errorMessage: state.failure?.message,
              onRetry: _retry,
            );
          }

          // Renders visibleUsers, never allUsers: the search filter is the
          // view, the pagination sequence is the model.
          final UserSummary user = state.visibleUsers[index];
          return UserListTile(
            key: Key('user_tile_${user.id}'),
            user: user,
            onTap: () => _openDetail(user),
          );
        },
      ),
    );
  }

  /// Which footer the end of the list should show.
  ///
  /// Hidden entirely while a filter is active: "you've reached the end" under
  /// a filtered subset would be read as "that is every matching user", which
  /// is false -- more matches may exist in pages not yet loaded.
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
