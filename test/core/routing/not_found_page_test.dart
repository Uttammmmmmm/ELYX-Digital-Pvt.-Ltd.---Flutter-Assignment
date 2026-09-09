import 'package:elyx_digital_assignment/core/routing/app_routes.dart';
import 'package:elyx_digital_assignment/core/routing/not_found_page.dart';
import 'package:elyx_digital_assignment/core/routing/route_generator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A routing mistake must degrade to a screen the user can leave, not a crash.
void main() {
  testWidgets('renders the offending route name', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: NotFoundPage(routeName: '/nope')),
    );

    expect(find.byKey(const Key('not_found_page')), findsOneWidget);
    expect(find.text("That screen doesn't exist"), findsOneWidget);
    expect(find.textContaining('/nope'), findsOneWidget);
  });

  testWidgets('handles a null route name', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: NotFoundPage(routeName: null)),
    );

    expect(find.text('Unknown route.'), findsOneWidget);
  });

  testWidgets('its escape hatch pops back to the first route', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        initialRoute: AppRoutes.usersList,
        onGenerateRoute: (RouteSettings settings) =>
            settings.name == AppRoutes.usersList
            ? MaterialPageRoute<void>(
                builder: (BuildContext context) => Scaffold(
                  body: TextButton(
                    onPressed: () => Navigator.of(context).pushNamed('/bogus'),
                    child: const Text('go'),
                  ),
                ),
              )
            : RouteGenerator.generate(settings),
      ),
    );

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('not_found_page')), findsOneWidget);

    await tester.tap(find.text('Back to users'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('not_found_page')), findsNothing);
    expect(find.text('go'), findsOneWidget);
  });
}
