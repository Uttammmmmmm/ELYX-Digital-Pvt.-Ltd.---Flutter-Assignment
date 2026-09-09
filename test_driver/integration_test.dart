library;

import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async => integrationDriver(
  onScreenshot:
      (String name, List<int> bytes, [Map<String, Object?>? args]) async {
        final Directory dir = Directory('screenshots')
          ..createSync(recursive: true);
        File('${dir.path}/$name.png').writeAsBytesSync(bytes);
        return true;
      },
);
