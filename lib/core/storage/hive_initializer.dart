/// Hive bootstrap.
library;

import 'package:hive_flutter/hive_flutter.dart';

import '../constants/cache_constants.dart';

/// Opens every box the app needs, once, before `runApp`.
///
/// Boxes are opened eagerly here rather than lazily at first use so that the
/// data layer can depend on a synchronous `Box<String>` and never has to deal
/// with an "is it open yet" state.
abstract final class HiveInitializer {
  /// Initialises Hive against the app documents directory and opens all boxes.
  static Future<void> init() async {
    await Hive.initFlutter();
    await Future.wait(<Future<Box<String>>>[
      Hive.openBox<String>(CacheConstants.usersPageBox),
      Hive.openBox<String>(CacheConstants.userDetailBox),
    ]);
  }

  /// Closes all boxes. Mainly for tests and hot-restart hygiene.
  static Future<void> dispose() => Hive.close();
}
