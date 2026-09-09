/// Client-side search over already-loaded users.
library;

import 'package:equatable/equatable.dart';

import '../../../../core/usecase/usecase.dart';
import '../entities/github_user.dart';

/// Arguments for [FilterUsers].
class FilterUsersParams extends Equatable {
  const FilterUsersParams({
    required this.users,
    required this.query,
    this.knownNames = const <String, String>{},
  });

  /// Every user loaded so far.
  final List<GithubUser> users;

  /// Raw text from the search field.
  final String query;

  /// Sparse `login -> name` index from cached detail documents.
  ///
  /// Sparse by necessity: the list endpoint carries no names, and fetching
  /// them all would cost one request per user against a 60/hour budget.
  final Map<String, String> knownNames;

  @override
  List<Object?> get props => <Object?>[users, query, knownNames];
}

/// Filters loaded users by login, and by name where the name is known.
///
/// Constraint (e): `GET /users` supports no name filter, so search is entirely
/// client-side over what has already been paged in.
///
/// A [SyncUseCase] with NO repository dependency: it performs no I/O, so
/// forcing callers to `await` would be dishonest and testing it needs no
/// mocks at all. Matching is case-insensitive and substring-based; results
/// keep their original list order so the view does not jump around as the user
/// types.
class FilterUsers implements SyncUseCase<List<GithubUser>, FilterUsersParams> {
  const FilterUsers();

  @override
  List<GithubUser> call(FilterUsersParams params) {
    final String needle = params.query.trim().toLowerCase();
    if (needle.isEmpty) return params.users;

    return params.users.where((GithubUser user) {
      if (user.login.toLowerCase().contains(needle)) return true;

      final String? name = params.knownNames[user.login.toLowerCase()];
      return name != null && name.toLowerCase().contains(needle);
    }).toList(growable: false);
  }
}
