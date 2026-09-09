// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'dart:async' as _i7;

import 'package:dartz/dartz.dart' as _i4;
import 'package:elyx_digital_assignment/core/error/failures.dart' as _i13;
import 'package:elyx_digital_assignment/core/network/network_info.dart' as _i11;
import 'package:elyx_digital_assignment/features/users/data/datasources/api/users_api.dart'
    as _i5;
import 'package:elyx_digital_assignment/features/users/data/datasources/user_local_data_source.dart'
    as _i8;
import 'package:elyx_digital_assignment/features/users/data/models/user_detail_model.dart'
    as _i9;
import 'package:elyx_digital_assignment/features/users/domain/entities/paginated_users.dart'
    as _i2;
import 'package:elyx_digital_assignment/features/users/domain/entities/user_detail.dart'
    as _i3;
import 'package:elyx_digital_assignment/features/users/domain/entities/user_summary.dart'
    as _i10;
import 'package:elyx_digital_assignment/features/users/domain/repositories/user_repository.dart'
    as _i12;
import 'package:mockito/mockito.dart' as _i1;
import 'package:mockito/src/dummies.dart' as _i6;

// ignore_for_file: type=lint
// ignore_for_file: avoid_redundant_argument_values
// ignore_for_file: avoid_setters_without_getters
// ignore_for_file: comment_references
// ignore_for_file: deprecated_member_use
// ignore_for_file: deprecated_member_use_from_same_package
// ignore_for_file: implementation_imports
// ignore_for_file: invalid_use_of_visible_for_testing_member
// ignore_for_file: must_be_immutable
// ignore_for_file: prefer_const_constructors
// ignore_for_file: unnecessary_parenthesis
// ignore_for_file: camel_case_types
// ignore_for_file: subtype_of_sealed_class
// ignore_for_file: invalid_use_of_internal_member

class _FakePaginatedUsers_0 extends _i1.SmartFake
    implements _i2.PaginatedUsers {
  _FakePaginatedUsers_0(Object parent, Invocation parentInvocation)
    : super(parent, parentInvocation);
}

class _FakeUserDetail_1 extends _i1.SmartFake implements _i3.UserDetail {
  _FakeUserDetail_1(Object parent, Invocation parentInvocation)
    : super(parent, parentInvocation);
}

class _FakeEither_2<L, R> extends _i1.SmartFake implements _i4.Either<L, R> {
  _FakeEither_2(Object parent, Invocation parentInvocation)
    : super(parent, parentInvocation);
}

class MockUsersApi extends _i1.Mock implements _i5.UsersApi {
  MockUsersApi() {
    _i1.throwOnMissingStub(this);
  }

  @override
  String get sourceName =>
      (super.noSuchMethod(
            Invocation.getter(#sourceName),
            returnValue: _i6.dummyValue<String>(
              this,
              Invocation.getter(#sourceName),
            ),
          )
          as String);

  @override
  String get baseUrl =>
      (super.noSuchMethod(
            Invocation.getter(#baseUrl),
            returnValue: _i6.dummyValue<String>(
              this,
              Invocation.getter(#baseUrl),
            ),
          )
          as String);

  @override
  Map<String, String> get headers =>
      (super.noSuchMethod(
            Invocation.getter(#headers),
            returnValue: <String, String>{},
          )
          as Map<String, String>);

  @override
  _i7.Future<_i2.PaginatedUsers> fetchUsers({Object? cursor, int? perPage}) =>
      (super.noSuchMethod(
            Invocation.method(#fetchUsers, [], {
              #cursor: cursor,
              #perPage: perPage,
            }),
            returnValue: _i7.Future<_i2.PaginatedUsers>.value(
              _FakePaginatedUsers_0(
                this,
                Invocation.method(#fetchUsers, [], {
                  #cursor: cursor,
                  #perPage: perPage,
                }),
              ),
            ),
          )
          as _i7.Future<_i2.PaginatedUsers>);

  @override
  _i7.Future<_i3.UserDetail> fetchUserDetail(String? id) =>
      (super.noSuchMethod(
            Invocation.method(#fetchUserDetail, [id]),
            returnValue: _i7.Future<_i3.UserDetail>.value(
              _FakeUserDetail_1(
                this,
                Invocation.method(#fetchUserDetail, [id]),
              ),
            ),
          )
          as _i7.Future<_i3.UserDetail>);
}

class MockUserLocalDataSource extends _i1.Mock
    implements _i8.UserLocalDataSource {
  MockUserLocalDataSource() {
    _i1.throwOnMissingStub(this);
  }

  @override
  _i7.Future<void> cacheUsersPage(Object? cursor, _i2.PaginatedUsers? page) =>
      (super.noSuchMethod(
            Invocation.method(#cacheUsersPage, [cursor, page]),
            returnValue: _i7.Future<void>.value(),
            returnValueForMissingStub: _i7.Future<void>.value(),
          )
          as _i7.Future<void>);

  @override
  _i7.Future<void> cacheUserDetail(_i3.UserDetail? detail) =>
      (super.noSuchMethod(
            Invocation.method(#cacheUserDetail, [detail]),
            returnValue: _i7.Future<void>.value(),
            returnValueForMissingStub: _i7.Future<void>.value(),
          )
          as _i7.Future<void>);

  @override
  _i9.UserDetailModel? getCachedUserDetail(String? detailId) =>
      (super.noSuchMethod(Invocation.method(#getCachedUserDetail, [detailId]))
          as _i9.UserDetailModel?);

  @override
  List<_i10.UserSummary> getAllCachedUsers() =>
      (super.noSuchMethod(
            Invocation.method(#getAllCachedUsers, []),
            returnValue: <_i10.UserSummary>[],
          )
          as List<_i10.UserSummary>);

  @override
  _i7.Future<void> clearUsersPages() =>
      (super.noSuchMethod(
            Invocation.method(#clearUsersPages, []),
            returnValue: _i7.Future<void>.value(),
            returnValueForMissingStub: _i7.Future<void>.value(),
          )
          as _i7.Future<void>);

  @override
  _i7.Future<void> clearAll() =>
      (super.noSuchMethod(
            Invocation.method(#clearAll, []),
            returnValue: _i7.Future<void>.value(),
            returnValueForMissingStub: _i7.Future<void>.value(),
          )
          as _i7.Future<void>);
}

class MockNetworkInfo extends _i1.Mock implements _i11.NetworkInfo {
  MockNetworkInfo() {
    _i1.throwOnMissingStub(this);
  }

  @override
  _i7.Future<bool> get isConnected =>
      (super.noSuchMethod(
            Invocation.getter(#isConnected),
            returnValue: _i7.Future<bool>.value(false),
          )
          as _i7.Future<bool>);

  @override
  _i7.Stream<bool> get onConnectivityChanged =>
      (super.noSuchMethod(
            Invocation.getter(#onConnectivityChanged),
            returnValue: _i7.Stream<bool>.empty(),
          )
          as _i7.Stream<bool>);
}

class MockUserRepository extends _i1.Mock implements _i12.UserRepository {
  MockUserRepository() {
    _i1.throwOnMissingStub(this);
  }

  @override
  _i7.Future<_i4.Either<_i13.Failure, _i2.PaginatedUsers>> getUsers({
    Object? cursor,
    int? perPage,
    bool? forceRefresh,
  }) =>
      (super.noSuchMethod(
            Invocation.method(#getUsers, [], {
              #cursor: cursor,
              #perPage: perPage,
              #forceRefresh: forceRefresh,
            }),
            returnValue:
                _i7.Future<_i4.Either<_i13.Failure, _i2.PaginatedUsers>>.value(
                  _FakeEither_2<_i13.Failure, _i2.PaginatedUsers>(
                    this,
                    Invocation.method(#getUsers, [], {
                      #cursor: cursor,
                      #perPage: perPage,
                      #forceRefresh: forceRefresh,
                    }),
                  ),
                ),
          )
          as _i7.Future<_i4.Either<_i13.Failure, _i2.PaginatedUsers>>);

  @override
  _i7.Future<_i4.Either<_i13.Failure, _i3.UserDetail>> getUserDetail(
    String? detailId,
  ) =>
      (super.noSuchMethod(
            Invocation.method(#getUserDetail, [detailId]),
            returnValue:
                _i7.Future<_i4.Either<_i13.Failure, _i3.UserDetail>>.value(
                  _FakeEither_2<_i13.Failure, _i3.UserDetail>(
                    this,
                    Invocation.method(#getUserDetail, [detailId]),
                  ),
                ),
          )
          as _i7.Future<_i4.Either<_i13.Failure, _i3.UserDetail>>);

  @override
  _i7.Future<List<_i10.UserSummary>> getCachedUsers() =>
      (super.noSuchMethod(
            Invocation.method(#getCachedUsers, []),
            returnValue: _i7.Future<List<_i10.UserSummary>>.value(
              <_i10.UserSummary>[],
            ),
          )
          as _i7.Future<List<_i10.UserSummary>>);
}
