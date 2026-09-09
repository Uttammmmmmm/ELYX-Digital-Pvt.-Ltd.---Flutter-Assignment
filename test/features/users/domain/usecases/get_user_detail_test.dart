import 'package:dartz/dartz.dart';
import 'package:elyx_digital_assignment/core/error/failures.dart';
import 'package:elyx_digital_assignment/features/users/domain/entities/user_detail.dart';
import 'package:elyx_digital_assignment/features/users/domain/usecases/get_user_detail.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../../../../helpers/mocks.mocks.dart';

final UserDetail _detail = UserDetail(
  id: 1,
  login: 'mojombo',
  avatarUrl: 'https://avatars.githubusercontent.com/u/1?v=4',
  htmlUrl: 'https://github.com/mojombo',
  publicRepos: 66,
  followers: 23000,
  following: 11,
  createdAt: DateTime.utc(2007, 10, 20),
  name: 'Tom Preston-Werner',
);

void main() {
  late MockUserRepository repository;
  late GetUserDetail useCase;

  setUp(() {
    repository = MockUserRepository();
    useCase = GetUserDetail(repository);
  });

  test('delegates a valid login to the repository', () async {
    when(repository.getUserDetail('mojombo'))
        .thenAnswer((_) async => Right<Failure, UserDetail>(_detail));

    final Either<Failure, UserDetail> result =
        await useCase(const GetUserDetailParams('mojombo'));

    expect(result, Right<Failure, UserDetail>(_detail));
    verify(repository.getUserDetail('mojombo')).called(1);
  });

  test('trims the login before delegating', () async {
    when(repository.getUserDetail('mojombo'))
        .thenAnswer((_) async => Right<Failure, UserDetail>(_detail));

    await useCase(const GetUserDetailParams('  mojombo  '));

    verify(repository.getUserDetail('mojombo')).called(1);
  });

  test('an empty login fails validation WITHOUT spending a request', () async {
    final Either<Failure, UserDetail> result =
        await useCase(const GetUserDetailParams(''));

    expect(result.fold((Failure f) => f, (_) => null), isA<ValidationFailure>());
    verifyZeroInteractions(repository);
  });

  test('a whitespace-only login fails validation', () async {
    final Either<Failure, UserDetail> result =
        await useCase(const GetUserDetailParams('   '));

    expect(result.fold((Failure f) => f, (_) => null), isA<ValidationFailure>());
    verifyZeroInteractions(repository);
  });

  test('propagates a repository failure unchanged', () async {
    when(repository.getUserDetail('ghost')).thenAnswer(
      (_) async => const Left<Failure, UserDetail>(NotFoundFailure()),
    );

    final Either<Failure, UserDetail> result =
        await useCase(const GetUserDetailParams('ghost'));

    expect(result.fold((Failure f) => f, (_) => null), isA<NotFoundFailure>());
  });
}
