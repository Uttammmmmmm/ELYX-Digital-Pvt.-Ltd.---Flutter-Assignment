/// Hive bootstrap.
library;

import 'package:hive_ce_flutter/hive_flutter.dart';

import '../../features/users/data/models/cached_page_model.dart';
import '../../features/users/data/models/user_detail_model.dart';
import '../../hive_registrar.g.dart';
import '../constants/cache_constants.dart';
import 'hive_type_ids.dart';

/// Registers every generated adapter and opens every box, once, before
/// `runApp`.
///
/// STEP 5 (DI) DEPENDS ON THIS HAVING RUN. Order is not negotiable:
///   1. `Hive.initFlutter()` -- resolve the storage directory.
///   2. `Hive.registerAdapters()` -- from the generated `hive_registrar.g.dart`,
///      which lists every `@HiveType` in the app. Opening a typed box before
///      its adapter is registered throws at runtime, not compile time.
///   3. `openBox<T>` -- eagerly, so the data layer can depend on a synchronous
///      `Box<T>` and never carry an "is it open yet" state.
abstract final class HiveInitializer {
  /// Initialises Hive, registers adapters, opens boxes.
  static Future<void> init() async {
    await Hive.initFlutter();

    registerAdaptersOnce();

    await Future.wait(<Future<void>>[
      Hive.openBox<CachedPageModel>(CacheConstants.usersPageBox),
      Hive.openBox<UserDetailModel>(CacheConstants.userDetailBox),
    ]);
  }

  /// Registers every generated adapter, at most once.
  ///
  /// The type registry is global and outlives any single call, and
  /// `registerAdapter` THROWS on a duplicate typeId rather than ignoring it.
  /// That makes a second call fatal -- which happens on hot restart, and in
  /// any test file that sets Hive up per-test. Guarding on a known id keeps
  /// registration idempotent.
  static void registerAdaptersOnce() {
    if (Hive.isAdapterRegistered(HiveTypeIds.userSummary)) return;
    // Generated: adding a new @HiveType regenerates this call automatically,
    // so a forgotten registration is impossible.
    Hive.registerAdapters();
  }

  /// Closes all boxes. For tests and hot-restart hygiene.
  static Future<void> dispose() => Hive.close();
}
