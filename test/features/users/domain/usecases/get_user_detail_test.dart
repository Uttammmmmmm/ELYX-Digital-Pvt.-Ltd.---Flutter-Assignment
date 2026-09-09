import 'package:dartz/dartz.dart';
import 'package:elyx_digital_assignment/core/error/failures.dart';
import 'package:elyx_digital_assignment/features/users/domain/entities/user_detail.dart';
import 'package:elyx_digital_assignment/features/users/domain/usecases/get_user_detail.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../../../../helpers/entity_fixtures.dart';
import '../../../../helpers/mocks.mocks.dart';

void main() {
  late MockUserRepository repository;
  late GetUserDetail useCase;

  final UserDetail detail = reqresDetail(2, first: 'Janet');

  setUp(() {
    repository = MockUserRepository();
    useCase = GetUserDetail(repository);
  });

  test('delegates a valid id to the repository', () async {
    when(
      repository.getUserDetail('2'),
    ).thenAnswer((_) async => Right<Failure, UserDetail>(detail));

    expect(
      await useCase(const GetUserDetailParams('2')),
      Right<Failure, UserDetail>(detail),
    );
    verify(repository.getUserDetail('2')).called(1);
  });

  test('trims before delegating', () async {
    when(
      repository.getUserDetail('2'),
    ).thenAnswer((_) async => Right<Failure, UserDetail>(detail));

    await useCase(const GetUserDetailParams('  2  '));

    verify(repository.getUserDetail('2')).called(1);
  });

  test('an empty id fails validation WITHOUT spending a request', () async {
    final Either<Failure, UserDetail> result = await useCase(
      const GetUserDetailParams(''),
    );

    expect(
      result.fold((Failure f) => f, (_) => null),
      isA<ValidationFailure>(),
    );
    verifyZeroInteractions(repository);
  });

  test('a whitespace-only id fails validation', () async {
    final Either<Failure, UserDetail> result = await useCase(
      const GetUserDetailParams('   '),
    );

    expect(
      result.fold((Failure f) => f, (_) => null),
      isA<ValidationFailure>(),
    );
    verifyZeroInteractions(repository);
  });

  test('propagates a repository failure unchanged', () async {
    when(repository.getUserDetail('ghost')).thenAnswer(
      (_) async => const Left<Failure, UserDetail>(NotFoundFailure()),
    );

    expect(
      (await useCase(
        const GetUserDetailParams('ghost'),
      )).fold((Failure f) => f, (_) => null),
      isA<NotFoundFailure>(),
    );
  });
}
