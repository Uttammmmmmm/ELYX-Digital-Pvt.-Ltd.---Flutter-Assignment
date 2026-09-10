library;

import '../../../../core/usecase/usecase.dart';
import '../entities/user_summary.dart';
import '../repositories/user_repository.dart';

/// Every user ever written to the cache, newest batch last.
///
/// Seeds the list on a cold start so an offline launch shows -- and can search
/// -- what previous sessions paged in, rather than only the current one.
///
/// This is a use case rather than a direct repository call from the Bloc so
/// that the presentation layer depends on exactly one kind of thing. A single
/// exception is how a layer boundary starts to rot.
class GetCachedUsers implements InfallibleUseCase<List<UserSummary>, NoParams> {
  const GetCachedUsers(this._repository);

  final UserRepository _repository;

  @override
  Future<List<UserSummary>> call(NoParams params) =>
      _repository.getCachedUsers();
}
