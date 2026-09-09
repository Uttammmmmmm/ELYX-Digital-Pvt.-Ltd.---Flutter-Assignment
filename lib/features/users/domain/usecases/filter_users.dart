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

/// Filters loaded users by display name and email.
///
/// Neither supported source offers a server-side name filter, so search is
/// entirely client-side over what has already been paged in. It matches
/// [UserSummary.displayName] -- which resolves to a real name on reqres and to
/// the handle on GitHub, whose list response carries no name (constraint b) --
/// and [UserSummary.email], because on reqres that is present and is a
/// perfectly natural thing to search for.
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

    return params.users.where((UserSummary user) {
      if (_normalise(user.displayName).contains(needle)) return true;

      final String? email = user.email;
      return email != null && _normalise(email).contains(needle);
    }).toList(growable: false);
  }

  /// Trim, collapse internal whitespace runs, lowercase.
  ///
  /// Applied to BOTH sides so the comparison is symmetric -- normalising only
  /// the query is a classic source of "why doesn't this match" bugs.
  ///
  /// Collapsing internal runs means `"mo   jo"` and `"mo jo"` behave the
  /// same -- which matters now that display names can contain spaces
  /// ("George Bluth"), so a double space between first and last name still
  /// matches rather than silently failing.
  ///
  /// UNICODE / DIACRITICS -- chosen behaviour, stated rather than skipped:
  /// diacritics are NOT folded. Searching `"jose"` will not match `"José"`.
  /// Dart ships no Unicode normaliser in core, so folding would mean an extra
  /// dependency. This is now a REAL limitation rather than a theoretical one:
  /// search covers display names, which are free-form Unicode, so a user with
  /// an accented name is reachable only by typing the accent. Fixing it means
  /// adding NFD normalisation, and it is the first thing I would change if
  /// the dataset were not `reqres`'s twelve Anglophone names.
  ///
  /// [String.toLowerCase] uses the locale-INDEPENDENT Unicode default case
  /// mapping, which is what we want: a locale-sensitive lowercase would map
  /// `I` to a dotless `ı` under a Turkish locale and silently break matching
  /// for those users.
  static String _normalise(String raw) =>
      raw.trim().replaceAll(_whitespaceRun, ' ').toLowerCase();
}
