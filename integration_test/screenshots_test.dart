/// Drives the real app through each documented state and captures a PNG.
///
/// Run against a booted simulator:
///
///   flutter drive \
///     --driver=test_driver/integration_test.dart \
///     --target=integration_test/screenshots_test.dart \
///     -d DEVICE_ID
///
/// Images land in `screenshots/`. Regenerating them is one command, so the
/// README images cannot silently drift away from the UI they document.
///
/// This hits the LIVE API. It is not part of `flutter test` and never runs in
/// CI; `flutter test` only discovers `test/`.
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
    // Same order as main(): Hive first, DI second.
    final HiveBoxes boxes = await HiveInitializer.init();
    await di.init(boxes: boxes);
  });

  /// Pumps and waits for the live request to land.
  ///
  /// `pumpAndSettle` alone is not enough: it settles when ANIMATIONS stop,
  /// which happens long before a network round trip completes. So settle,
  /// then wait, then settle again.
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

    // -- Dark: the app follows the OS, so flip the OS value, not the theme.
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pumpAndSettle();
    await binding.takeScreenshot('02-list-dark');
    tester.platformDispatcher.clearPlatformBrightnessTestValue();
    await tester.pumpAndSettle();

    // -- Search that matches.
    final Finder search = find.byType(TextField).first;
    await tester.enterText(search, 'geo');
    await settleWithNetwork(tester);
    await binding.takeScreenshot('03-search');

    // -- Search that matches nothing: a distinct state, not "empty".
    await tester.enterText(search, 'zzzzzz');
    await settleWithNetwork(tester);
    await binding.takeScreenshot('04-no-results');

    // -- Back to the full list, then open a profile.
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
