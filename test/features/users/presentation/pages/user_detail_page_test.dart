@Timeout(Duration(seconds: 15))
library;

import 'package:dartz/dartz.dart';
import 'package:elyx_digital_assignment/core/error/failures.dart';
import 'package:elyx_digital_assignment/features/users/domain/entities/user_detail.dart';
import 'package:elyx_digital_assignment/features/users/domain/entities/user_summary.dart';
import 'package:elyx_digital_assignment/features/users/domain/usecases/get_user_detail.dart';
import 'package:elyx_digital_assignment/features/users/presentation/bloc/user_detail_bloc.dart';
import 'package:elyx_digital_assignment/features/users/presentation/bloc/user_detail_event.dart';
import 'package:elyx_digital_assignment/features/users/presentation/pages/user_detail_page.dart';
import 'package:elyx_digital_assignment/features/users/presentation/strings/users_strings.dart';
import 'package:elyx_digital_assignment/features/users/presentation/widgets/detail_info_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../../../../helpers/entity_fixtures.dart';
import '../../../../helpers/mocks.mocks.dart';
import '../../../../helpers/widget_harness.dart';

void main() {
  late MockUserRepository repository;

  final UserSummary seed = reqresUser(2, first: 'Janet', last: 'Weaver');

  UserDetail detailWith({
    String? first = 'Janet',
    String? last = 'Weaver',
    String? email = 'janet.weaver@reqres.in',
  }) => UserDetail(
    user: UserSummary(
      id: 2,
      detailId: '2',
      avatarUrl: 'https://reqres.in/img/faces/2-image.jpg',
      firstName: first,
      lastName: last,
      email: email,
    ),
  );

  setUp(() {
    installFakeAvatars();
    repository = MockUserRepository();
  });

  tearDown(restoreAvatars);

  void stubDetail(UserDetail detail) => when(
    repository.getUserDetail('2'),
  ).thenAnswer((_) async => Right<Failure, UserDetail>(detail));

  void stubFailure(Failure failure) => when(
    repository.getUserDetail(any),
  ).thenAnswer((_) async => Left<Failure, UserDetail>(failure));

  Future<void> pump(
    WidgetTester tester, {
    bool request = true,
    UserSummary? withSeed,
  }) async {
    final UserDetailBloc bloc = UserDetailBloc(
      getUserDetail: GetUserDetail(repository),
      seed: withSeed ?? seed,
    );
    if (request) bloc.add(UserDetailRequested((withSeed ?? seed).detailId));

    await tester.pumpWidget(
      wrapForTest(
        BlocProvider<UserDetailBloc>.value(
          value: bloc,
          child: const UserDetailView(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('seed rendering', () {
    testWidgets('the header is populated before the profile loads', (
      WidgetTester tester,
    ) async {
      stubDetail(detailWith());
      await pump(tester, request: false);

      expect(find.text('Janet Weaver'), findsWidgets);
      expect(find.byKey(const Key('detail_body_skeleton')), findsOneWidget);
      verifyZeroInteractions(repository);
    });

    testWidgets('only the BODY shows a skeleton, never the whole screen', (
      WidgetTester tester,
    ) async {
      stubDetail(detailWith());
      await pump(tester, request: false);

      expect(find.byKey(const Key('detail_name')), findsOneWidget);
      expect(find.byKey(const Key('detail_body_skeleton')), findsOneWidget);
    });
  });

  group('required fields always render', () {
    testWidgets('name shows the real name from the source', (
      WidgetTester tester,
    ) async {
      stubDetail(detailWith());
      await pump(tester);

      final DetailInfoRow row = tester.widget<DetailInfoRow>(
        find.byKey(const Key('row_name')),
      );
      expect(row.value, 'Janet Weaver');
      expect(row.unavailable, isFalse);
    });

    testWidgets('name falls back and is never blank when the source has none', (
      WidgetTester tester,
    ) async {
      const UserSummary bare = UserSummary(
        id: 2,
        detailId: '2',
        avatarUrl: 'a',
      );
      when(repository.getUserDetail('2')).thenAnswer(
        (_) async => const Right<Failure, UserDetail>(UserDetail(user: bare)),
      );
      await pump(tester, withSeed: bare);

      final DetailInfoRow row = tester.widget<DetailInfoRow>(
        find.byKey(const Key('row_name')),
      );
      expect(row.value, 'User 2');
    });

    testWidgets('a public email renders as real, tappable data', (
      WidgetTester tester,
    ) async {
      stubDetail(detailWith());
      await pump(tester);

      final DetailInfoRow row = tester.widget<DetailInfoRow>(
        find.byKey(const Key('row_email')),
      );
      expect(row.value, 'janet.weaver@reqres.in');
      expect(row.unavailable, isFalse);
      expect(row.onTap, isNotNull);
    });

    testWidgets('a missing email renders as unavailable, not blank or absent', (
      WidgetTester tester,
    ) async {
      stubDetail(detailWith(email: null));
      await pump(tester);

      final DetailInfoRow row = tester.widget<DetailInfoRow>(
        find.byKey(const Key('row_email')),
      );
      expect(row.value, UsersStrings.emailUnavailable);
      expect(row.unavailable, isTrue);
      expect(row.onTap, isNull, reason: 'a placeholder must not look tappable');
    });

    testWidgets('phone is ALWAYS present, ALWAYS unavailable, and '
        'source-neutral', (WidgetTester tester) async {
      stubDetail(detailWith());
      await pump(tester);

      final DetailInfoRow row = tester.widget<DetailInfoRow>(
        find.byKey(const Key('row_phone')),
      );
      expect(row.label, UsersStrings.labelPhone);
      expect(row.value, 'Not provided by the API');
      expect(row.unavailable, isTrue);

      expect(row.value.contains('GitHub'), isFalse);
      expect(row.value.contains('reqres'), isFalse);
    });
  });

  group('optional fields', () {
    testWidgets('a source without stats hides the row rather than showing '
        'zeros', (WidgetTester tester) async {
      stubDetail(detailWith());
      await pump(tester);

      expect(find.text(UsersStrings.statFollowers), findsNothing);
      expect(find.byKey(const Key('row_member_since')), findsNothing);
      expect(find.byKey(const Key('row_company')), findsNothing);
    });

    testWidgets('a source WITH stats renders them, abbreviated', (
      WidgetTester tester,
    ) async {
      final UserSummary ghSeed = githubUser(1, 'mojombo');
      when(repository.getUserDetail('mojombo')).thenAnswer(
        (_) async => Right<Failure, UserDetail>(
          githubDetail(1, 'mojombo', bio: 'Cofounder', location: 'SF'),
        ),
      );
      await pump(tester, withSeed: ghSeed);

      expect(find.text('66'), findsOneWidget);
      expect(find.text('23k'), findsOneWidget);
      expect(find.text('SF'), findsOneWidget);
      expect(find.text('Cofounder'), findsOneWidget);

      final DetailInfoRow row = tester.widget<DetailInfoRow>(
        find.byKey(const Key('row_member_since')),
      );
      expect(row.value, 'October 2007');
    });
  });

  group('failure states', () {
    testWidgets('a 404 shows ErrorView but KEEPS the seed header', (
      WidgetTester tester,
    ) async {
      stubFailure(const NotFoundFailure());
      await pump(tester);

      expect(find.byKey(const Key('error_view')), findsOneWidget);
      expect(
        find.byKey(const Key('detail_name')),
        findsOneWidget,
        reason: 'the user must still see who they tapped',
      );
    });

    testWidgets('retry recovers', (WidgetTester tester) async {
      stubFailure(const ServerFailure());
      await pump(tester);

      stubDetail(detailWith());
      await tester.tap(find.byKey(const Key('error_retry_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('row_phone')), findsOneWidget);
    });

    testWidgets('a rate limit reuses the countdown view with retry disabled', (
      WidgetTester tester,
    ) async {
      stubFailure(
        RateLimitFailure(
          resetAt: DateTime.now().add(const Duration(minutes: 12)),
        ),
      );
      await pump(tester);

      expect(find.byKey(const Key('rate_limit_view')), findsOneWidget);
      final FilledButton button = tester.widget<FilledButton>(
        find.byKey(const Key('rate_limit_retry_button')),
      );
      expect(button.onPressed, isNull);
    });
  });
}
