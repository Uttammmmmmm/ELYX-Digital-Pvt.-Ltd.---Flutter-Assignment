library;

import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../../features/users/data/models/cached_page_model.dart';
import '../../features/users/data/models/user_detail_model.dart';
import '../../features/users/data/models/user_summary_model.dart';
import '../constants/cache_constants.dart';
import 'hive_type_ids.dart';

@immutable
class HiveBoxes {
  const HiveBoxes({required this.pages, required this.details});

  final Box<CachedPageModel> pages;

  final Box<UserDetailModel> details;
}

abstract final class HiveInitializer {
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

  static Future<Box<T>> _openBoxSafely<T>(String name) async {
    try {
      return await Hive.openBox<T>(name);
    } catch (error, stackTrace) {
      debugPrint('[hive] box "$name" unreadable, recreating: $error');
      debugPrintStack(stackTrace: stackTrace, maxFrames: 5);

      await Hive.deleteBoxFromDisk(name);
      return Hive.openBox<T>(name);
    }
  }

  static Future<void> dispose() => Hive.close();
}
