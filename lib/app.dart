/// Root widget: theme and routing.
library;

import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/users/presentation/pages/users_list_page.dart';

/// The application shell.
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
