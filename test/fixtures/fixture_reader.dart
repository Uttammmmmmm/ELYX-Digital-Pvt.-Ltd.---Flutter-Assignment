library;

import 'dart:convert';
import 'dart:io';

String fixture(String name) => File('test/fixtures/$name').readAsStringSync();

Map<String, dynamic> fixtureMap(String name) =>
    jsonDecode(fixture(name)) as Map<String, dynamic>;

List<dynamic> fixtureList(String name) =>
    jsonDecode(fixture(name)) as List<dynamic>;
