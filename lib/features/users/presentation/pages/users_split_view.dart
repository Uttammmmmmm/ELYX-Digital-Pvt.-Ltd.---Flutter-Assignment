library;

import 'package:flutter/material.dart';

import '../../domain/entities/user_summary.dart';
import '../strings/users_strings.dart';
import '../widgets/no_selection_view.dart';
import 'user_detail_page.dart';
import 'users_list_view.dart';

class UsersSplitView extends StatefulWidget {
  const UsersSplitView({required this.connectivity, super.key});

  final Stream<bool> connectivity;

  static const double listPaneWidth = 360;

  @override
  State<UsersSplitView> createState() => _UsersSplitViewState();
}

class _UsersSplitViewState extends State<UsersSplitView> {
  UserSummary? _selected;

  void _select(UserSummary user) => setState(() => _selected = user);

  @override
  Widget build(BuildContext context) {
    final UserSummary? selected = _selected;

    return Scaffold(
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
                    key: ValueKey<String>(selected.detailId),
                    summary: selected,
                  ),
          ),
        ],
      ),
    );
  }
}
