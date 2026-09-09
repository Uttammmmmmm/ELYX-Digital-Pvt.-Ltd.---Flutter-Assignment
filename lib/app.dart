/// Root widget: theme and the first route.
library;

import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/users/presentation/pages/users_list_page.dart';

/// The application shell.
///
/// Holds no dependencies of its own and calls no `sl<T>()`. The service
/// locator is touched at exactly one kind of place -- a `BlocProvider`'s
/// `create` callback -- and nowhere else in the widget tree.
class ElyxApp extends StatelessWidget {
  const ElyxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GitHub Users',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: const UsersListPage(),
    );
  }
}
