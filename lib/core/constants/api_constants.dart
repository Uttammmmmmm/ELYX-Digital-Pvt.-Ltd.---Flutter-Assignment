library;

abstract final class ApiConstants {
  static const String baseUrl = 'https://api.github.com';

  static const String usersPath = '/users';

  static String userDetailPath(String login) => '/users/$login';

  static const String paramPerPage = 'per_page';

  static const String paramSince = 'since';

  static const int defaultPerPage = 10;

  static const String headerAccept = 'Accept';
  static const String headerApiVersion = 'X-GitHub-Api-Version';
  static const String headerUserAgent = 'User-Agent';
  static const String headerAuthorization = 'Authorization';

  static const String headerRateLimitRemaining = 'x-ratelimit-remaining';

  static const String headerRateLimitReset = 'x-ratelimit-reset';

  static const String headerRetryAfter = 'retry-after';

  static const String headerLink = 'Link';

  static const String acceptJson = 'application/vnd.github+json';

  static const String apiVersion = '2026-03-10';

  static const String userAgent = 'elyx-digital-assignment';

  static const String githubToken = String.fromEnvironment('GITHUB_TOKEN');

  static bool get hasToken => githubToken.isNotEmpty;

  static Map<String, String> get defaultHeaders => <String, String>{
    headerAccept: acceptJson,
    headerApiVersion: apiVersion,
    headerUserAgent: userAgent,
    if (hasToken) headerAuthorization: 'Bearer $githubToken',
  };
}
