/// Search field for the users list.
library;

import 'package:flutter/material.dart';

/// Text field that reports query changes.
///
/// Stateful only to own its [TextEditingController]; the query itself lives in
/// the Bloc. Debouncing happens in the Bloc's event transformer, not here, so
/// the timing policy is testable without pumping a widget.
class UserSearchBar extends StatefulWidget {
  const UserSearchBar({
    required this.onChanged,
    this.onCleared,
    this.hintText = 'Search loaded users',
    super.key,
  });

  /// Called on every keystroke; the Bloc debounces.
  final ValueChanged<String> onChanged;

  /// Called when the clear button is tapped. Separate from [onChanged] so the
  /// Bloc can skip the debounce -- clearing should feel immediate.
  final VoidCallback? onCleared;

  /// Placeholder copy.
  final String hintText;

  @override
  State<UserSearchBar> createState() => _UserSearchBarState();
}

class _UserSearchBarState extends State<UserSearchBar> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    final VoidCallback? onCleared = widget.onCleared;
    if (onCleared != null) {
      onCleared();
    } else {
      widget.onChanged('');
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: TextField(
        key: const Key('user_search_field'),
        controller: _controller,
        textInputAction: TextInputAction.search,
        onChanged: (String value) {
          widget.onChanged(value);
          setState(() {}); // toggles the clear button only
        },
        decoration: InputDecoration(
          hintText: widget.hintText,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _controller.text.isEmpty
              ? null
              : IconButton(
                  key: const Key('search_clear_button'),
                  icon: const Icon(Icons.clear),
                  onPressed: _clear,
                ),
          isDense: true,
        ),
      ),
    );
  }
}
