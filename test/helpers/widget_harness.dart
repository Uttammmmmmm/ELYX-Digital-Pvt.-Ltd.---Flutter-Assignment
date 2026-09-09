/// Shared widget-test setup.
library;

import 'dart:typed_data';

import 'package:elyx_digital_assignment/core/theme/app_theme.dart';
import 'package:elyx_digital_assignment/core/widgets/network_avatar.dart';
import 'package:flutter/material.dart';

/// A 1x1 transparent PNG, so avatars resolve instantly and offline.
final Uint8List kTransparentPng = Uint8List.fromList(<int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

/// Points [NetworkAvatar] at an in-memory image for the duration of a test.
///
/// Without this the real `CachedNetworkImageProvider` tries to hit the network
/// and `path_provider`, neither of which exists under `flutter_test`; the
/// resulting async failures surface as unrelated test errors.
void installFakeAvatars() {
  NetworkAvatar.imageProviderBuilder =
      (String _) => MemoryImage(kTransparentPng);
}

/// Restores the production image provider.
void restoreAvatars() {
  NetworkAvatar.imageProviderBuilder =
      (String url) => NetworkImage(url); // never fetched after a test ends
}

/// Wraps [child] in the app's theme and a Navigator.
Widget wrapForTest(Widget child) => MaterialApp(
      theme: AppTheme.light,
      home: child,
    );
