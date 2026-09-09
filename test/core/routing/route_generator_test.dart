import 'package:elyx_digital_assignment/core/routing/app_routes.dart';
import 'package:elyx_digital_assignment/core/routing/not_found_page.dart';
import 'package:elyx_digital_assignment/core/routing/route_generator.dart';
import 'package:elyx_digital_assignment/features/users/domain/entities/user_summary.dart';
import 'package:elyx_digital_assignment/features/users/presentation/pages/user_detail_page.dart';
import 'package:elyx_digital_assignment/features/users/presentation/pages/users_list_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const UserSummary _summary = UserSummary(
  id: 1,
  login: 'mojombo',
  avatarUrl: 'a',
  htmlUrl: 'h',
  type: 'User',
  siteAdmin: false,
);

/// `RouteSettings.arguments` is `Object?`, so wrong arguments are invisible to
/// the compiler. These tests pin the runtime behaviour at that boundary.
void main() {
  Widget buildFor(RouteSettings settings, WidgetTester tester) {
    final Route<dynamic> route = RouteGenerator.generate(settings);
    expect(route, isA<MaterialPageRoute<void>>());
    return (route as MaterialPageRoute<void>).builder(
      tester.element(find.byType(Placeholder)),
    );
  }

  testWidgets('the list route builds the list page', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: Placeholder()));

    expect(
      buildFor(const RouteSettings(name: AppRoutes.usersList), tester),
      isA<UsersListPage>(),
    );
  });

  testWidgets('the detail route builds the detail page with its summary', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: Placeholder()));

    final Widget page = buildFor(
      const RouteSettings(name: AppRoutes.userDetail, arguments: _summary),
      tester,
    );

    expect(page, isA<UserDetailPage>());
    expect((page as UserDetailPage).summary, _summary);
  });

  testWidgets('a detail route with NO argument returns 404, does not throw', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: Placeholder()));

    expect(
      buildFor(const RouteSettings(name: AppRoutes.userDetail), tester),
      isA<NotFoundPage>(),
    );
  });

  testWidgets('a detail route with the WRONG argument type returns 404', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: Placeholder()));

    expect(
      buildFor(
        const RouteSettings(name: AppRoutes.userDetail, arguments: 'mojombo'),
        tester,
      ),
      isA<NotFoundPage>(),
      reason: 'a String login is exactly the mistake a refactor would make',
    );
  });

  testWidgets('an unknown route name returns 404', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: Placeholder()));

    expect(
      buildFor(const RouteSettings(name: '/nope'), tester),
      isA<NotFoundPage>(),
    );
  });
}
