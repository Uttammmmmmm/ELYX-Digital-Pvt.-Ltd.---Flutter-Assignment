/// Hive bootstrap: adapters, boxes, and recovery from a corrupted store.
library;

import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../../features/users/data/models/cached_page_model.dart';
import '../../features/users/data/models/user_detail_model.dart';
import '../../features/users/data/models/user_summary_model.dart';
import '../constants/cache_constants.dart';
import 'hive_type_ids.dart';

/// The boxes opened at startup, handed to DI.
///
/// Returned as a value rather than read back out of `Hive.box<T>()` at each
/// call site so the dependency is explicit: DI receives what bootstrap
/// produced, instead of both of them independently trusting global state.
@immutable
class HiveBoxes {
  const HiveBoxes({required this.pages, required this.details});

  /// Cursor-keyed batches of the users list.
  final Box<CachedPageModel> pages;

  /// Login-keyed profile documents.
  final Box<UserDetailModel> details;
}

/// Prepares Hive for use, once, before `runApp`.
///
/// ORDER IS NOT NEGOTIABLE:
///   1. `initFlutter()` resolves the storage directory.
///   2. adapters are registered -- opening a typed box before its adapter
///      exists throws at RUNTIME, not compile time.
///   3. boxes are opened eagerly, so the data layer can depend on a
///      synchronous `Box<T>` and never carry an "is it open yet" state.
abstract final class HiveInitializer {
  /// Runs the full bootstrap and returns the opened boxes.
  static Future<HiveBoxes> init() async {
    await Hive.initFlutter();
    registerAdaptersOnce();
    await _dropIncompatibleBoxes();

    return HiveBoxes(
      pages: await _openBoxSafely<CachedPageModel>(CacheConstants.usersPageBox),
      details: await _openBoxSafely<UserDetailModel>(
        CacheConstants.userDetailBox,
      ),
    );
  }

  /// Registers every generated adapter, at most once.
  ///
  /// `registerAdapter` THROWS on a duplicate typeId rather than ignoring it,
  /// so a second call is fatal. That happens on hot restart and in any test
  /// file that sets Hive up per-test, which is why each registration is
  /// guarded individually rather than trusting a "did we already run" flag --
  /// a flag would go stale if adapters were ever registered elsewhere.
  static void registerAdaptersOnce() {
    if (!Hive.isAdapterRegistered(HiveTypeIds.userSummary)) {
      Hive.registerAdapter(UserSummaryModelAdapter());
    }
    if (!Hive.isAdapterRegistered(HiveTypeIds.userDetail)) {
      Hive.registerAdapter(UserDetailModelAdapter());
    }
    if (!Hive.isAdapterRegistered(HiveTypeIds.cachedPage)) {
      Hive.registerAdapter(CachedPageModelAdapter());
    }
  }

  /// Drops persisted data written by an older schema.
  ///
  /// Hive stores raw FIELD INDICES, not names. Adding or reordering a
  /// `@HiveField` therefore makes old bytes decode into the wrong fields --
  /// which does not throw, it silently produces wrong data, and that is far
  /// worse than a crash. Comparing a stored version against
  /// [CacheConstants.schemaVersion] and dropping the data boxes on a mismatch
  /// turns a silent corruption into one cold fetch.
  static Future<void> _dropIncompatibleBoxes() async {
    final Box<int> meta = await Hive.openBox<int>(CacheConstants.metaBox);
    final int? stored = meta.get(CacheConstants.schemaVersionKey);

    if (stored == CacheConstants.schemaVersion) return;

    debugPrint(
      '[hive] schema $stored -> ${CacheConstants.schemaVersion}, '
      'dropping cached data',
    );
    await Hive.deleteBoxFromDisk(CacheConstants.usersPageBox);
    await Hive.deleteBoxFromDisk(CacheConstants.userDetailBox);
    await meta.put(
      CacheConstants.schemaVersionKey,
      CacheConstants.schemaVersion,
    );
  }

  /// Opens [name], recovering by deleting the box if it cannot be read.
  ///
  /// A corrupted box -- a half-written record from a kill during a flush, or
  /// a file written by an incompatible older schema -- otherwise throws here
  /// and the app never reaches `runApp`. That is the worst possible failure:
  /// a permanent launch crash, fixable only by reinstalling. The cache is by
  /// definition reconstructible from the network, so discarding it is always
  /// preferable to failing to start. The cost is one cold fetch.
  static Future<Box<T>> _openBoxSafely<T>(String name) async {
    try {
      return await Hive.openBox<T>(name);
    } catch (error, stackTrace) {
      debugPrint('[hive] box "$name" unreadable, recreating: $error');
      debugPrintStack(stackTrace: stackTrace, maxFrames: 5);

      // deleteBoxFromDisk also closes it if a partial open left it registered.
      await Hive.deleteBoxFromDisk(name);
      return Hive.openBox<T>(name);
    }
  }

  /// Closes all boxes. For tests and hot-restart hygiene.
  static Future<void> dispose() => Hive.close();
}
