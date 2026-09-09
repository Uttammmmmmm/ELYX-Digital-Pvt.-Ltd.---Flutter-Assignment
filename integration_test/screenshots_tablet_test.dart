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

  testWidgets('capture the split view', (WidgetTester tester) async {
    await tester.pumpWidget(const ElyxApp());
    await settleWithNetwork(tester);

    await binding.takeScreenshot('06-tablet-split-empty');

    final Finder firstTile = find.byKey(const Key('user_tile_2'));
    if (firstTile.evaluate().isNotEmpty) {
      await tester.tap(firstTile);
      await settleWithNetwork(tester);

      await binding.takeScreenshot('07-tablet-split-selected');
    }
  });
}
