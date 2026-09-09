/// Application entry point.
library;

import 'package:flutter/material.dart';

import 'app.dart';
import 'core/di/injection_container.dart';
import 'core/storage/hive_initializer.dart';

/// Boots the app.
///
/// Order matters: Hive boxes must be open before [initDependencies] runs,
/// because the local data source is registered with already-open boxes rather
/// than a future. That keeps the data layer synchronous and removes an
/// "is the box ready yet" state from every read.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await HiveInitializer.init();
  await initDependencies();

  runApp(const ElyxApp());
}
