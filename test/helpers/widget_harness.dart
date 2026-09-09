/// Shared widget-test setup.
library;

import 'package:elyx_digital_assignment/core/theme/app_theme.dart';
import 'package:elyx_digital_assignment/features/users/presentation/widgets/user_avatar.dart';
import 'package:flutter/material.dart';

/// Points [UserAvatar] at a synchronous stand-in for the duration of a test.
///
/// Without this the real `CachedNetworkImage` reaches for the network and
/// `path_provider`, neither of which exists under `flutter_test`; the
/// resulting async failures surface as errors in unrelated tests.
void installFakeAvatars() {
  UserAvatar.debugOverrideBuilder = (String url, String login, double radius) =>
      SizedBox(
        key: const Key('fake_avatar'),
        width: radius * 2,
        height: radius * 2,
      );
}

/// Restores the production avatar.
void restoreAvatars() => UserAvatar.debugOverrideBuilder = null;

/// Wraps [child] in the app's theme and a Navigator.
Widget wrapForTest(Widget child) =>
    MaterialApp(theme: AppTheme.light, home: child);
