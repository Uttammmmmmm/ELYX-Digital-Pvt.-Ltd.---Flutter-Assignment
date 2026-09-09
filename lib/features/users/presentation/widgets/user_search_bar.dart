library;

import 'package:flutter/material.dart';

import '../strings/users_strings.dart';

class UserSearchBar extends StatelessWidget {
  const UserSearchBar({
    required this.controller,
    required this.onChanged,
    required this.onCleared,
    this.hintText = UsersStrings.searchHint,
    super.key,
  });

  final TextEditingController controller;

  final ValueChanged<String> onChanged;

  final VoidCallback onCleared;

  final String hintText;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),

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
                      tooltip: UsersStrings.clearSearchTooltip,
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
