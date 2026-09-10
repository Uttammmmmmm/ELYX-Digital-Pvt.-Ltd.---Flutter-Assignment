library;

import 'package:flutter/material.dart';

import 'core/routing/app_routes.dart';
import 'core/routing/route_generator.dart';
import 'core/theme/app_theme.dart';

class ElyxApp extends StatelessWidget {
  const ElyxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Users',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,

      themeMode: ThemeMode.system,
      initialRoute: AppRoutes.usersList,
      onGenerateRoute: RouteGenerator.generate,

      onUnknownRoute: RouteGenerator.generate,
    );
  }
}
