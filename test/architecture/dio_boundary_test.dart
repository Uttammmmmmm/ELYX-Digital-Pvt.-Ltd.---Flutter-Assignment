/// Executable architecture rule: `package:dio` may not leak out of the
/// networking core.
///
/// The Dart analyzer has no built-in import-ban, and pulling in `custom_lint`
/// or `dart_code_metrics` for one rule is not worth the dependency. A test is
/// cheap, has zero production cost, runs in CI with everything else, and fails
/// with an actionable message naming the offending file.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The only files permitted to import Dio. Adding to this list should require
/// a conversation in code review -- that is the point.
const Set<String> kDioAllowlist = <String>{
  'lib/core/network/dio_client.dart',
  'lib/core/network/header_reader.dart',
  'lib/core/network/rate_limit_interceptor.dart',
  // Produces the app's error vocabulary from Dio's. Move it into
  // core/network/ if you want the allowlist down to three entries.
  'lib/core/error/error_mapper.dart',
};

void main() {
  test('package:dio is imported only inside the networking core', () {
    final Directory lib = Directory('lib');
    expect(lib.existsSync(), isTrue, reason: 'run this from the package root');

    final List<String> offenders = <String>[];

    for (final FileSystemEntity entity in lib.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;

      final String relative = entity.path.replaceAll(r'\', '/');
      if (kDioAllowlist.contains(relative)) continue;

      final bool importsDio = entity
          .readAsLinesSync()
          .any((String l) => RegExp(r'''^\s*import\s+['"]package:dio/''')
              .hasMatch(l));

      if (importsDio) offenders.add(relative);
    }

    expect(
      offenders,
      isEmpty,
      reason: 'These files import package:dio outside the allowlist:\n'
          '${offenders.join('\n')}\n\n'
          'Depend on DioClient/ApiResponse instead, or justify an allowlist '
          'entry.',
    );
  });
}
