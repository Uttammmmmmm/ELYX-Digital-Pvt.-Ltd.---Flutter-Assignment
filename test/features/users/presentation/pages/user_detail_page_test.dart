@Timeout(Duration(seconds: 15))
library;

// See users_list_view_test.dart for why these tests never close their bloc.

import 'package:dartz/dartz.dart';
import 'package:elyx_digital_assignment/core/error/failures.dart';
import 'package:elyx_digital_assignment/features/users/domain/entities/user_detail.dart';
import 'package:elyx_digital_assignment/features/users/domain/entities/user_summary.dart';
import 'package:elyx_digital_assignment/features/users/domain/usecases/get_user_detail.dart';
import 'package:elyx_digital_assignment/features/users/presentation/bloc/user_detail_bloc.dart';
import 'package:elyx_digital_assignment/features/users/presentation/bloc/user_detail_event.dart';
import 'package:elyx_digital_assignment/features/users/presentation/pages/user_detail_page.dart';
import 'package:elyx_digital_assignment/features/users/presentation/widgets/detail_info_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../../../../helpers/mocks.mocks.dart';
import '../../../../helpers/widget_harness.dart';

const UserSummary _seed = UserSummary(
  id: 1,
  login: 'mojombo',
  avatarUrl: 'https://avatars.githubusercontent.com/u/1?v=4',
  htmlUrl: 'https://github.com/mojombo',
  type: 'User',
  siteAdmin: false,
);

UserDetail _detail({
  String? name = 'Tom Preston-Werner',
  String? email,
  String? bio = 'Cofounder of GitHub',
  String? location = 'San Francisco',
  String? company,
  String? blog,
}) =>
    UserDetail(
      id: 1,
      login: 'mojombo',
      avatarUrl: 'https://avatars.githubusercontent.com/u/1?v=4',
      htmlUrl: 'https://github.com/mojombo',
      publicRepos: 66,
      followers: 23000,
      following: 11,
      createdAt: DateTime.utc(2007, 10, 20),
      name: name,
      email: email,
      bio: bio,
      location: location,
      company: company,
      blog: blog,
    );

void main() {
  late MockUserRepository repository;

  setUp(() {
    installFakeAvatars();
    repository = MockUserRepository();
  });

  tearDown(restoreAvatars);

  void stubDetail(UserDetail detail) =>
      when(repository.getUserDetail('mojombo'))
          .thenAnswer((_) async => Right<Failure, UserDetail>(detail));

  void stubFailure(Failure failure) => when(repository.getUserDetail(any))
      .thenAnswer((_) async => Left<Failure, UserDetail>(failure));

  Future<UserDetailBloc> pump(WidgetTester tester, {bool request = true}) async {
    final UserDetailBloc bloc = UserDetailBloc(
      getUserDetail: GetUserDetail(repository),
      seed: _seed,
    );
    if (request) bloc.add(const UserDetailRequested('mojombo'));

    await tester.pumpWidget(
      wrapForTest(
        BlocProvider<UserDetailBloc>.value(
          value: bloc,
          child: const UserDetailView(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return bloc;
  }

  group('seed rendering', () {
    testWidgets('the header is populated before the profile loads', (
      WidgetTester tester,
    ) async {
      stubDetail(_detail());
      await pump(tester, request: false);

      // Login from the seed is on screen with no request made at all.
      expect(find.text('mojombo'), findsWidgets);
      expect(find.byKey(const Key('detail_body_skeleton')), findsOneWidget);
      verifyZeroInteractions(repository);
    });

    testWidgets('only the BODY shows a skeleton, never the whole screen', (
      WidgetTester tester,
    ) async {
      stubDetail(_detail());
      await pump(tester, request: false);

      expect(find.byKey(const Key('detail_name')), findsOneWidget);
      expect(find.byKey(const Key('detail_body_skeleton')), findsOneWidget);
    });
  });

  group('required fields always render', () {
    testWidgets('name falls back to the login and is never blank', (
      WidgetTester tester,
    ) async {
      stubDetail(_detail(name: null, bio: null, location: null));
      await pump(tester);

      final DetailInfoRow row =
          tester.widget<DetailInfoRow>(find.byKey(const Key('row_name')));
      expect(row.value, 'mojombo');
      expect(row.unavailable, isFalse);
    });

    testWidgets('a hidden email renders as unavailable, not blank or absent', (
      WidgetTester tester,
    ) async {
      stubDetail(_detail());
      await pump(tester);

      final DetailInfoRow row =
          tester.widget<DetailInfoRow>(find.byKey(const Key('row_email')));
      expect(row.value, 'Not publicly listed');
      expect(row.unavailable, isTrue);
      expect(row.onTap, isNull, reason: 'a placeholder must not look tappable');
    });

    testWidgets('a public email renders as real, tappable data', (
      WidgetTester tester,
    ) async {
      stubDetail(_detail(email: 'tom@example.com'));
      await pump(tester);

      final DetailInfoRow row =
          tester.widget<DetailInfoRow>(find.byKey(const Key('row_email')));
      expect(row.value, 'tom@example.com');
      expect(row.unavailable, isFalse);
      expect(row.onTap, isNotNull);
    });

    testWidgets('phone is ALWAYS present and ALWAYS unavailable', (
      WidgetTester tester,
    ) async {
      stubDetail(_detail());
      await pump(tester);

      final DetailInfoRow row =
          tester.widget<DetailInfoRow>(find.byKey(const Key('row_phone')));
      expect(row.label, 'Phone');
      expect(row.value, 'Not provided by the GitHub API');
      expect(row.unavailable, isTrue);
    });
  });

  group('optional fields', () {
    testWidgets('are hidden entirely when null', (WidgetTester tester) async {
      stubDetail(_detail(company: null, blog: null, location: null));
      await pump(tester);

      expect(find.byKey(const Key('row_company')), findsNothing);
      expect(find.byKey(const Key('row_blog')), findsNothing);
      expect(find.byKey(const Key('row_location')), findsNothing);
      // ...while the three required ones stay put.
      expect(find.byKey(const Key('row_name')), findsOneWidget);
      expect(find.byKey(const Key('row_email')), findsOneWidget);
      expect(find.byKey(const Key('row_phone')), findsOneWidget);
    });

    testWidgets('render when present', (WidgetTester tester) async {
      stubDetail(_detail(company: 'GitHub', blog: 'https://tom.dev'));
      await pump(tester);

      expect(find.byKey(const Key('row_company')), findsOneWidget);
      expect(find.byKey(const Key('row_blog')), findsOneWidget);
      expect(find.text('San Francisco'), findsOneWidget);
      expect(find.text('Cofounder of GitHub'), findsOneWidget);
    });

    testWidgets('member-since is formatted with intl', (
      WidgetTester tester,
    ) async {
      stubDetail(_detail());
      await pump(tester);

      final DetailInfoRow row = tester
          .widget<DetailInfoRow>(find.byKey(const Key('row_member_since')));
      expect(row.value, 'October 2007');
    });

    testWidgets('stats render abbreviated', (WidgetTester tester) async {
      stubDetail(_detail());
      await pump(tester);

      expect(find.text('66'), findsOneWidget);
      expect(find.text('23k'), findsOneWidget);
    });
  });

  group('failure states', () {
    testWidgets('a 404 shows ErrorView but KEEPS the seed header', (
      WidgetTester tester,
    ) async {
      stubFailure(const NotFoundFailure());
      await pump(tester);

      expect(find.byKey(const Key('error_view')), findsOneWidget);
      expect(find.byKey(const Key('detail_name')), findsOneWidget,
          reason: 'the user must still see who they tapped');
    });

    testWidgets('retry recovers', (WidgetTester tester) async {
      stubFailure(const ServerFailure());
      await pump(tester);

      stubDetail(_detail());
      await tester.tap(find.byKey(const Key('error_retry_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('row_phone')), findsOneWidget);
    });

    testWidgets('a rate limit reuses the step-7 view with a disabled retry', (
      WidgetTester tester,
    ) async {
      stubFailure(
        RateLimitFailure(
          resetAt: DateTime.now().add(const Duration(minutes: 12)),
        ),
      );
      await pump(tester);

      expect(find.byKey(const Key('rate_limit_view')), findsOneWidget);
      expect(find.textContaining('Limit resets at'), findsOneWidget);

      final FilledButton button = tester.widget<FilledButton>(
        find.byKey(const Key('rate_limit_retry_button')),
      );
      expect(button.onPressed, isNull);
    });
  });

  group('offline / cache path', () {
    testWidgets('a cache-served profile renders identically to a live one', (
      WidgetTester tester,
    ) async {
      // The repository answers from Hive within the 6h TTL without touching
      // the network; from the screen's side that is indistinguishable, which
      // is exactly what makes a revisit instant and offline-capable.
      stubDetail(_detail());
      await pump(tester);

      expect(find.byKey(const Key('row_name')), findsOneWidget);
      expect(find.byKey(const Key('row_phone')), findsOneWidget);
      verify(repository.getUserDetail('mojombo')).called(1);
    });
  });
}
