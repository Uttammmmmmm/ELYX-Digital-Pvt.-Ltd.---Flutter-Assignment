library;

import 'package:elyx_digital_assignment/app.dart';
import 'package:elyx_digital_assignment/core/di/injection_container.dart' as di;
import 'package:elyx_digital_assignment/core/storage/hive_initializer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  final IntegrationTestWidgetsFlutterBinding binding =
      IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final HiveBoxes boxes = await HiveInitializer.init();
    await di.init(boxes: boxes);
  });

  Future<void> settleWithNetwork(WidgetTester tester) async {
    await tester.pumpAndSettle();
    for (int i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    await tester.pumpAndSettle();
  }

  testWidgets('capture every documented state', (WidgetTester tester) async {
    await tester.pumpWidget(const ElyxApp());
    await settleWithNetwork(tester);

    await binding.takeScreenshot('01-list-light');

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pumpAndSettle();
    await binding.takeScreenshot('02-list-dark');
    tester.platformDispatcher.clearPlatformBrightnessTestValue();
    await tester.pumpAndSettle();

    final Finder search = find.byType(TextField).first;
    await tester.enterText(search, 'geo');
    await settleWithNetwork(tester);
    await binding.takeScreenshot('03-search');

    await tester.enterText(search, 'zzzzzz');
    await settleWithNetwork(tester);
    await binding.takeScreenshot('04-no-results');

    await tester.enterText(search, '');
    await settleWithNetwork(tester);

    final Finder firstTile = find.byKey(const Key('user_tile_1'));
    if (firstTile.evaluate().isNotEmpty) {
      await tester.tap(firstTile);
      await settleWithNetwork(tester);
      await binding.takeScreenshot('05-detail');
    }
  });
}
