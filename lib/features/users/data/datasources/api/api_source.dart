/// Which backend the app talks to, and how to reach it.
library;

import 'package:flutter/foundation.dart';

import '../../../../../core/constants/api_constants.dart';
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
/// api.github.com. Both are supported, github by default.
enum ApiSource {
  /// `https://reqres.in/api` -- a MOCK. Returns the same 12 invented users on
  /// every request, so on a device it looks identical to hardcoded data.
  /// Opt-in only, via `--dart-define=API_SOURCE=reqres`.
  reqres,

  /// `https://api.github.com` -- the default, and the only source that serves
  /// live data.
  github;

  /// Parses the `API_SOURCE` define.
  ///
  /// An unrecognised value falls back to the default rather than throwing: a
  /// typo in a build flag should not be a launch crash. The fallback is the
  /// LIVE source on purpose -- silently serving a static fixture is the harder
  /// failure to spot.
  static ApiSource fromName(String name) => switch (name.toLowerCase()) {
    'reqres' => ApiSource.reqres,
    _ => ApiSource.github,
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
    // Delegates to [ApiConstants] rather than repeating the values. That is
    // not just DRY: `DioClient` is built from THIS map, so a token added to
    // `ApiConstants.defaultHeaders` but not here would never reach the wire --
    // `--dart-define=GITHUB_TOKEN=...` would silently stay unauthenticated at
    // 60 req/hour.
    ApiSource.github => ApiSourceConfig(
      name: 'api.github.com',
      baseUrl: ApiConstants.baseUrl,
      headers: ApiConstants.defaultHeaders,
    ),
  };
}

/// The reqres key, injected at build time.
const String kReqresApiKey = String.fromEnvironment(
  ReqresUsersApi.apiKeyDefine,
  defaultValue: ReqresUsersApi.defaultApiKey,
);
