library;

import 'package:equatable/equatable.dart';

import '../../../../core/usecase/usecase.dart';
import '../entities/user_summary.dart';

class FilterUsersParams extends Equatable {
  const FilterUsersParams({required this.users, required this.query});

  final List<UserSummary> users;

  final String query;

  @override
  List<Object?> get props => <Object?>[users, query];
}

class FilterUsers implements SyncUseCase<List<UserSummary>, FilterUsersParams> {
  const FilterUsers();

  static final RegExp _whitespaceRun = RegExp(r'\s+');

  @override
  List<UserSummary> call(FilterUsersParams params) {
    final String needle = _normalise(params.query);

    if (needle.isEmpty) return params.users;

    return params.users
        .where((UserSummary user) {
          if (_normalise(user.displayName).contains(needle)) return true;

          final String? email = user.email;
          return email != null && _normalise(email).contains(needle);
        })
        .toList(growable: false);
  }

  static String _normalise(String raw) =>
      raw.trim().replaceAll(_whitespaceRun, ' ').toLowerCase();
}
