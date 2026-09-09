/// Root widget: theme and routing.
library;

import 'package:flutter/material.dart';

import 'core/routing/app_routes.dart';
import 'core/routing/route_generator.dart';
import 'core/theme/app_theme.dart';

/// The application shell.
///
/// Holds no dependencies and calls no `sl<T>()`. Routing goes through
/// [RouteGenerator], which is also where an unknown route is turned into a
/// 404 page instead of an exception.
class ElyxApp extends StatelessWidget {
  const ElyxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GitHub Users',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      // Follows the OS setting; both themes come from the same seed colour,
      // so every state is legible in either.
      themeMode: ThemeMode.system,
      initialRoute: AppRoutes.usersList,
      onGenerateRoute: RouteGenerator.generate,
      // Catches a pushNamed for a name the generator does not know at all.
      onUnknownRoute: RouteGenerator.generate,
    );
  }
}
