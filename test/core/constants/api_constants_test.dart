import 'package:elyx_digital_assignment/core/constants/api_constants.dart';
import 'package:flutter_test/flutter_test.dart';

/// Verifies the `--dart-define` token wiring.
///
/// `String.fromEnvironment` is resolved at COMPILE time, so a single run can
/// only exercise one branch. These tests therefore assert against
/// [ApiConstants.hasToken] rather than hardcoding an expectation, which means
/// the same file is meaningful in both modes:
///
///   flutter test                                        -> unauthenticated
///   flutter test --dart-define=GITHUB_TOKEN=ghp_xxx     -> authenticated
///
/// Both are worth running; CI should run the first.
/// Set alongside the token to assert the define actually reached the compiler.
///
/// Without this the "if and only if" test below would pass TRIVIALLY when the
/// flag is silently dropped -- both sides would simply be false. Passing the
/// expectation in as a second define makes a broken flag a red test.
const bool kExpectToken = bool.fromEnvironment('EXPECT_TOKEN');

void main() {
  test('the --dart-define actually reached the compiler', () {
    expect(ApiConstants.hasToken, kExpectToken,
        reason: kExpectToken
            ? 'ran with EXPECT_TOKEN=true but no GITHUB_TOKEN was compiled in'
            : 'a token leaked into an unauthenticated build');
  });

  group('required GitHub headers', () {
    test('always sends Accept, API version and User-Agent', () {
      final Map<String, String> headers = ApiConstants.defaultHeaders;

      expect(headers[ApiConstants.headerAccept], ApiConstants.acceptJson);
      expect(headers[ApiConstants.headerApiVersion], ApiConstants.apiVersion);
      expect(headers[ApiConstants.headerUserAgent], isNotEmpty,
          reason: 'GitHub rejects requests with no User-Agent');
    });

    test('the User-Agent identifies this app', () {
      expect(ApiConstants.userAgent, 'elyx-digital-assignment');
    });
  });

  group('optional token (constraint d)', () {
    test('hasToken agrees with the compiled-in value', () {
      expect(ApiConstants.hasToken, ApiConstants.githubToken.isNotEmpty);
    });

    test('Authorization is present if and only if a token was defined', () {
      final Map<String, String> headers = ApiConstants.defaultHeaders;
      final bool hasAuthHeader =
          headers.containsKey(ApiConstants.headerAuthorization);

      expect(hasAuthHeader, ApiConstants.hasToken,
          reason: 'an empty Bearer token is a hard 401 -- worse than being '
              'unauthenticated, so the header must be omitted entirely');
    });

    test('a defined token is sent as a Bearer credential', () {
      if (!ApiConstants.hasToken) {
        // Unauthenticated build: assert the negative instead.
        expect(
          ApiConstants.defaultHeaders,
          isNot(contains(ApiConstants.headerAuthorization)),
        );
        return;
      }

      expect(
        ApiConstants.defaultHeaders[ApiConstants.headerAuthorization],
        'Bearer ${ApiConstants.githubToken}',
      );
    });
  });
}
