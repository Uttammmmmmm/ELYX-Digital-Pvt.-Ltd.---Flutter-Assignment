/// Static, compile-time configuration for the GitHub REST API.
///
/// Everything wire-facing lives here: base URL, paths, query-parameter names,
/// header names and header values. Isolating them means an API change (a new
/// `X-GitHub-Api-Version`, a different accept type) is a one-file edit, and it
/// keeps magic strings out of the data layer.
library;

/// Compile-time constants describing the GitHub REST API surface we consume.
abstract final class ApiConstants {
  // ---------------------------------------------------------------------------
  // Endpoints
  // ---------------------------------------------------------------------------

  /// Root of the GitHub REST API.
  static const String baseUrl = 'https://api.github.com';

  /// Cursor-paginated list of all users. See [paramSince].
  static const String usersPath = '/users';

  /// Detail document for a single user, keyed by `login` (not by numeric id).
  static String userDetailPath(String login) => '/users/$login';

  // ---------------------------------------------------------------------------
  // Query parameters
  // ---------------------------------------------------------------------------

  /// Page size. GitHub caps this at 100.
  static const String paramPerPage = 'per_page';

  /// The pagination cursor: a user id. `/users` is cursor-based, NOT offset
  /// based -- a `page` parameter is silently ignored. See constraint (a).
  static const String paramSince = 'since';

  /// Default page size for the users list.
  static const int defaultPerPage = 10;

  // ---------------------------------------------------------------------------
  // Header names
  // ---------------------------------------------------------------------------

  static const String headerAccept = 'Accept';
  static const String headerApiVersion = 'X-GitHub-Api-Version';
  static const String headerUserAgent = 'User-Agent';
  static const String headerAuthorization = 'Authorization';

  /// Requests left in the current rate-limit window.
  static const String headerRateLimitRemaining = 'x-ratelimit-remaining';

  /// Window ceiling (60 unauthenticated, 5000 with a token).
  static const String headerRateLimitLimit = 'x-ratelimit-limit';

  /// Unix epoch *seconds* at which the window resets.
  static const String headerRateLimitReset = 'x-ratelimit-reset';

  /// Seconds to wait, sent on secondary (abuse) rate limits instead of
  /// `x-ratelimit-reset`.
  static const String headerRetryAfter = 'retry-after';

  /// RFC 5988 pagination header carrying the `rel="next"` cursor.
  static const String headerLink = 'Link';

  // ---------------------------------------------------------------------------
  // Header values
  // ---------------------------------------------------------------------------

  /// GitHub's versioned media type.
  static const String acceptJson = 'application/vnd.github+json';

  /// Pinned API version. An unrecognised value here yields a 400, so verify
  /// this against https://docs.github.com/rest/about-the-rest-api/api-versions
  /// before changing it.
  static const String apiVersion = '2026-03-10';

  /// GitHub rejects requests without a User-Agent. Keep this in sync with the
  /// package name in pubspec.yaml.
  static const String userAgent = 'elyx-digital-assignment';

  // ---------------------------------------------------------------------------
  // Optional authentication
  // ---------------------------------------------------------------------------

  /// Personal access token injected at build time; empty when absent.
  ///
  /// Lifts the unauthenticated 60 req/hour per-IP limit to 5000 req/hour.
  /// Read via [String.fromEnvironment] so the token is never committed:
  ///
  ///   flutter run --dart-define=GITHUB_TOKEN=ghp_xxxxxxxxxxxx
  ///
  /// Constraint (d).
  static const String githubToken = String.fromEnvironment('GITHUB_TOKEN');

  /// Whether a token was supplied at build time.
  static bool get hasToken => githubToken.isNotEmpty;

  /// Headers sent on every request. The `Authorization` entry is omitted
  /// entirely when no token was provided -- GitHub treats an empty or
  /// malformed Bearer token as a hard 401, which is worse than being
  /// unauthenticated.
  static Map<String, String> get defaultHeaders => <String, String>{
    headerAccept: acceptJson,
    headerApiVersion: apiVersion,
    headerUserAgent: userAgent,
    if (hasToken) headerAuthorization: 'Bearer $githubToken',
  };
}
