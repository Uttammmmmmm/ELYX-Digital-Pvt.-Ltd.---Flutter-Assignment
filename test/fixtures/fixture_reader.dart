/// Loads JSON fixtures from disk.
library;

import 'dart:convert';
import 'dart:io';

/// Reads `test/fixtures/<name>` as a string.
String fixture(String name) => File('test/fixtures/$name').readAsStringSync();

/// Reads `test/fixtures/<name>` and decodes it as a JSON object.
Map<String, dynamic> fixtureMap(String name) =>
    jsonDecode(fixture(name)) as Map<String, dynamic>;

/// Reads `test/fixtures/<name>` and decodes it as a JSON array.
List<dynamic> fixtureList(String name) =>
    jsonDecode(fixture(name)) as List<dynamic>;
