/// Search field for the users list.
library;

import 'package:flutter/material.dart';

/// Text field that reports query changes and clears.
///
/// NO DEBOUNCE HERE. The bloc's `restartable() + 300ms` transformer owns that
/// timing. Debouncing in both places would compound to ~600ms of lag and, more
/// importantly, would put a timing policy in a widget where it cannot be
/// unit-tested. This widget reports keystrokes; the bloc decides when to act.
///
/// Stateless: the [TextEditingController] is owned by the view, which is also
/// what disposes it.
class UserSearchBar extends StatelessWidget {
  const UserSearchBar({
    required this.controller,
    required this.onChanged,
    required this.onCleared,
    this.hintText = 'Search loaded users',
    super.key,
  });

  /// Owned and disposed by the parent view.
  final TextEditingController controller;

  /// Called on every keystroke.
  final ValueChanged<String> onChanged;

  /// Called when the clear button is tapped. Separate from [onChanged] so the
  /// bloc can skip the debounce -- clearing must feel immediate.
  final VoidCallback onCleared;

  /// Placeholder copy.
  final String hintText;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      // Rebuilds only this subtree as the text changes, so the clear button
      // can appear without the whole screen rebuilding.
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (BuildContext context, TextEditingValue value, Widget? _) {
          return TextField(
            key: const Key('user_search_field'),
            controller: controller,
            textInputAction: TextInputAction.search,
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText: hintText,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: value.text.isEmpty
                  ? null
                  : IconButton(
                      key: const Key('search_clear_button'),
                      icon: const Icon(Icons.clear),
                      tooltip: 'Clear search',
                      onPressed: () {
                        controller.clear();
                        onCleared();
                      },
                    ),
              isDense: true,
            ),
          );
        },
      ),
    );
  }
}
