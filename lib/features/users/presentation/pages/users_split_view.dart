/// Two-pane master-detail layout for tablets and landscape phones.
library;

import 'package:flutter/material.dart';

import '../../domain/entities/user_summary.dart';
import '../strings/users_strings.dart';
import '../widgets/no_selection_view.dart';
import 'user_detail_page.dart';
import 'users_list_view.dart';

/// List and detail side by side, with selection held here rather than on the
/// navigation stack.
///
/// WHY SELECTION IS STATE, NOT A ROUTE. In one pane, "which user" IS the top
/// route, so the Navigator owns it. Side by side, both panes are visible at
/// once, so pushing the detail would cover the list it is supposed to sit
/// beside. The selection therefore lives here and the list is told to call
/// back instead of pushing -- see [UsersListView.onUserSelected].
///
/// WHAT THIS BUYS ON BACK NAVIGATION. Because nothing is pushed, there is no
/// detail route to pop: system back leaves the screen, exactly as it does from
/// the list in one pane. That is the whole reason selection is not a route --
/// a pushed-but-covered route is what makes split views desynchronise from the
/// back button.
///
/// COLLAPSING TO ONE PANE. If the window narrows (rotation, a foldable
/// closing, a resized desktop window) [UsersListPage] swaps this out for the
/// single-pane list. The selection is discarded with it and the user is left
/// on the list, which is a real place to be. The alternative -- synthesising a
/// route push mid-layout to preserve it -- pushes during build and is the
/// crash this design exists to avoid.
class UsersSplitView extends StatefulWidget {
  const UsersSplitView({required this.connectivity, super.key});

  /// Passed straight through to the list pane.
  final Stream<bool> connectivity;

  /// Width of the list pane in logical pixels.
  ///
  /// Fixed, not a fraction: the detail pane is the one with variable-length
  /// content, so it should absorb the extra width. 360dp also keeps the pane
  /// under the 600dp breakpoint, so the list inside it renders as a LIST and
  /// not a grid -- which is why [UsersListView] measures its own constraints
  /// via `ResponsiveBuilder` rather than the window.
  static const double listPaneWidth = 360;

  @override
  State<UsersSplitView> createState() => _UsersSplitViewState();
}

class _UsersSplitViewState extends State<UsersSplitView> {
  /// The user shown in the detail pane; null until one is picked.
  UserSummary? _selected;

  void _select(UserSummary user) => setState(() => _selected = user);

  @override
  Widget build(BuildContext context) {
    final UserSummary? selected = _selected;

    return Scaffold(
      // One app bar spans both panes, so the list pane is told not to add its
      // own. The detail pane keeps its Scaffold for its title and SnackBars.
      appBar: AppBar(title: const Text(UsersStrings.listTitle)),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            width: UsersSplitView.listPaneWidth,
            child: UsersListView(
              connectivity: widget.connectivity,
              onUserSelected: _select,
              selectedDetailId: selected?.detailId,
              showAppBar: false,
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: selected == null
                ? const NoSelectionView()
                : UserDetailPage(
                    // Keying by the user REBUILDS the subtree on selection
                    // change, which disposes the old UserDetailBloc and
                    // creates one for the new user. Without it, BlocProvider
                    // would keep the first bloc and the pane would stay on
                    // the first user forever.
                    key: ValueKey<String>(selected.detailId),
                    summary: selected,
                  ),
          ),
        ],
      ),
    );
  }
}
