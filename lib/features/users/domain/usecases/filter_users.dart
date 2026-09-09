/// Client-side search over already-loaded users.
library;

import 'package:equatable/equatable.dart';

import '../../../../core/usecase/usecase.dart';
import '../entities/user_summary.dart';

/// Arguments for [FilterUsers].
class FilterUsersParams extends Equatable {
  const FilterUsersParams({required this.users, required this.query});

  /// Every user loaded so far. Not mutated.
  final List<UserSummary> users;

  /// Raw text straight from the search field, untrimmed and uncased.
  final String query;

  @override
  List<Object?> get props => <Object?>[users, query];
}

/// Filters loaded users by login.
///
/// CONSTRAINT (e): `GET /users` supports no name or login filter of any kind,
/// so search is entirely client-side over what has already been paged in. It
/// searches [UserSummary.login] because that is the only human-readable field
/// the list endpoint returns -- names live behind one detail request per user
/// (constraint b), and prefetching them would spend the whole hourly budget
/// in six pages.
///
/// PURE AND SYNCHRONOUS: no repository, no I/O, no `Future`. Making callers
/// `await` a computation that never suspends would be dishonest, and as a
/// plain function this is the cheapest thing in the codebase to test -- no
/// mocks, no async harness, no pumping.
class FilterUsers implements SyncUseCase<List<UserSummary>, FilterUsersParams> {
  const FilterUsers();

  /// Matches any run of whitespace.
  ///
  /// This is a FIXED, author-written pattern, which is the important
  /// distinction: the rule broken below is never "avoid RegExp", it is
  /// "never compile user input into a pattern".
  static final RegExp _whitespaceRun = RegExp(r'\s+');

  @override
  List<UserSummary> call(FilterUsersParams params) {
    final String needle = _normalise(params.query);

    // An empty or whitespace-only query is not a filter that matches nothing;
    // it is the absence of a filter. Return the SAME instance, so the caller
    // can cheaply detect "unfiltered" by identity and the list view does not
    // rebuild against a new-but-equal list.
    if (needle.isEmpty) return params.users;

    return params.users
        .where((UserSummary user) => _normalise(user.login).contains(needle))
        .toList(growable: false);
  }

  /// Trim, collapse internal whitespace runs, lowercase.
  ///
  /// Applied to BOTH sides so the comparison is symmetric -- normalising only
  /// the query is a classic source of "why doesn't this match" bugs.
  ///
  /// Collapsing internal runs means `"mo   jo"` and `"mo jo"` behave the
  /// same. Worth knowing: GitHub logins cannot contain whitespace at all, so
  /// any multi-word query correctly yields no matches. Collapsing does not
  /// change that outcome; it makes it *consistent*, so a stray double space
  /// can never behave differently from a single one.
  ///
  /// UNICODE / DIACRITICS -- chosen behaviour, stated rather than skipped:
  /// diacritics are NOT folded. Searching `"jose"` will not match a login
  /// containing `"josé"`. This is deliberate and safe here because GitHub
  /// logins are restricted to ASCII alphanumerics and single hyphens, so a
  /// login containing `é` cannot exist and folding would be unreachable code.
  /// Dart also ships no Unicode normaliser in core, so folding would mean an
  /// extra dependency to serve inputs the domain forbids. If search is ever
  /// extended to display *names* -- which are free-form Unicode and where
  /// `José` is entirely ordinary -- this decision must be revisited, and
  /// that is the trigger to add proper NFD normalisation.
  ///
  /// [String.toLowerCase] uses the locale-INDEPENDENT Unicode default case
  /// mapping, which is what we want: a locale-sensitive lowercase would map
  /// `I` to a dotless `ı` under a Turkish locale and silently break matching
  /// for those users.
  static String _normalise(String raw) =>
      raw.trim().replaceAll(_whitespaceRun, ' ').toLowerCase();
}
