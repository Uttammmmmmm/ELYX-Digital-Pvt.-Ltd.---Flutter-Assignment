library;

import 'package:flutter/material.dart';

import '../../features/users/domain/entities/user_summary.dart';
import '../../features/users/presentation/pages/user_detail_page.dart';
import '../../features/users/presentation/pages/users_list_page.dart';
import 'app_routes.dart';
import 'not_found_page.dart';

abstract final class RouteGenerator {
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
