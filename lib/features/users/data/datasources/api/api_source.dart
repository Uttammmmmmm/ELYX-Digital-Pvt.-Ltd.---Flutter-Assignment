/// Which backend the app talks to, and how to reach it.
library;

import 'package:flutter/foundation.dart';

import 'reqres_users_api.dart';

/// The connection details for one source.
///
/// WHY THIS EXISTS SEPARATELY FROM [UsersApi]. `DioClient` needs a base URL
/// and headers to be constructed; the API implementations need a `DioClient`
/// to be constructed. Reading the URL off the API instance therefore creates a
/// dependency CYCLE -- and get_it resolves lazily, so it does not fail at
/// registration: it stack-overflows the first time anything is resolved.
/// Splitting the *configuration* out of the *implementation* breaks it, and
/// the config is what a client should depend on anyway.
@immutable
class ApiSourceConfig {
  const ApiSourceConfig({
    required this.name,
    required this.baseUrl,
    required this.headers,
  });

  /// Human-readable source name, for logs.
  final String name;

  /// Root URL.
  final String baseUrl;

  /// Headers sent on every request.
  final Map<String, String> headers;
}

/// The supported sources.
///
/// The brief's TEXT names reqres.in; its HYPERLINKS resolve to
/// api.github.com. Both are supported, reqres by default.
enum ApiSource {
  /// `https://reqres.in/api` -- the default.
  reqres,

  /// `https://api.github.com` -- retained because the brief links to it.
  github;

  /// Parses the `API_SOURCE` define.
  ///
  /// An unrecognised value falls back to the default rather than throwing: a
  /// typo in a build flag should not be a launch crash.
  static ApiSource fromName(String name) => switch (name.toLowerCase()) {
        'github' => ApiSource.github,
        _ => ApiSource.reqres,
      };

  /// Connection details for this source.
  ApiSourceConfig config({required String reqresApiKey}) => switch (this) {
        ApiSource.reqres => ApiSourceConfig(
            name: 'reqres.in',
            baseUrl: 'https://reqres.in/api',
            headers: <String, String>{
              'Accept': 'application/json',
              // REQUIRED. Without it reqres returns
              // 401 {"error":"missing_api_key"} on every call.
              'x-api-key': reqresApiKey,
            },
          ),
        ApiSource.github => const ApiSourceConfig(
            name: 'api.github.com',
            baseUrl: 'https://api.github.com',
            headers: <String, String>{
              'Accept': 'application/vnd.github+json',
              'X-GitHub-Api-Version': '2022-11-28',
              'User-Agent': 'elyx-digital-assignment',
            },
          ),
      };
}

/// The reqres key, injected at build time.
const String kReqresApiKey = String.fromEnvironment(
  ReqresUsersApi.apiKeyDefine,
  defaultValue: ReqresUsersApi.defaultApiKey,
);
