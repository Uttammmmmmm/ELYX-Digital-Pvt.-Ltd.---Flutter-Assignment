/// Named-route resolution.
library;

import 'package:flutter/material.dart';

import '../../features/users/domain/entities/user_summary.dart';
import '../../features/users/presentation/pages/user_detail_page.dart';
import '../../features/users/presentation/pages/users_list_page.dart';
import 'app_routes.dart';
import 'not_found_page.dart';

/// Builds routes from names and arguments.
///
/// TYPE SAFETY: `RouteSettings.arguments` is `Object?`, so a wrong or missing
/// argument is invisible to the compiler and blows up as a cast error deep
/// inside a page build. Every argument is therefore CHECKED here, at the one
/// boundary where an untyped value enters the app, and a mismatch resolves to
/// [NotFoundPage] rather than throwing. A routing bug becomes a screen the
/// user can leave, not a crash.
abstract final class RouteGenerator {
  /// Resolves [settings] to a route.
  static Route<dynamic> generate(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.usersList:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const UsersListPage(),
        );

      case AppRoutes.userDetail:
        final Object? args = settings.arguments;
        if (args is! UserSummary) {
          // Missing or wrong-typed argument: not a crash, a 404.
          return _notFound(settings);
        }
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => UserDetailPage(summary: args),
        );

      default:
        return _notFound(settings);
    }
  }

  static Route<dynamic> _notFound(RouteSettings settings) =>
      MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => NotFoundPage(routeName: settings.name),
      );
}
