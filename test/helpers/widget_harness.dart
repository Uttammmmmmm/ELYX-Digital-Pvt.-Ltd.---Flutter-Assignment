library;

import 'package:elyx_digital_assignment/core/theme/app_theme.dart';
import 'package:elyx_digital_assignment/features/users/presentation/widgets/user_avatar.dart';
import 'package:flutter/material.dart';

void installFakeAvatars() {
  UserAvatar.debugOverrideBuilder = (String url, String login, double radius) =>
      SizedBox(
        key: const Key('fake_avatar'),
        width: radius * 2,
        height: radius * 2,
      );
}

void restoreAvatars() => UserAvatar.debugOverrideBuilder = null;

Widget wrapForTest(Widget child) =>
    MaterialApp(theme: AppTheme.light, home: child);
