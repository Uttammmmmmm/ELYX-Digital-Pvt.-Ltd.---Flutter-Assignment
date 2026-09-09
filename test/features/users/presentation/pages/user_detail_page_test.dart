@Timeout(Duration(seconds: 15))
library;

// See users_list_page_test.dart for why these tests never close their bloc.

import 'package:dartz/dartz.dart';
import 'package:elyx_digital_assignment/core/error/failures.dart';
import 'package:elyx_digital_assignment/core/models/sourced.dart';
import 'package:elyx_digital_assignment/features/users/domain/entities/github_user.dart';
import 'package:elyx_digital_assignment/features/users/domain/entities/github_user_detail.dart';
import 'package:elyx_digital_assignment/features/users/domain/usecases/get_user_detail.dart';
import 'package:elyx_digital_assignment/features/users/presentation/bloc/user_detail_bloc.dart';
import 'package:elyx_digital_assignment/features/users/presentation/bloc/user_detail_event.dart';
import 'package:elyx_digital_assignment/features/users/presentation/formatters/user_display.dart';
import 'package:elyx_digital_assignment/features/users/presentation/pages/user_detail_page.dart';
import 'package:elyx_digital_assignment/features/users/presentation/widgets/detail_field_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../../../../helpers/mocks.mocks.dart';
import '../../../../helpers/widget_harness.dart';

const GithubUser _mojombo = GithubUser(
  id: 1,
  login: 'mojombo',
  avatarUrl: 'https://avatars.githubusercontent.com/u/1?v=4',
  htmlUrl: 'https://github.com/mojombo',
  type: 'User',
  isSiteAdmin: false,
);

/// A full profile.
const GithubUserDetail _full = GithubUserDetail(
  user: _mojombo,
  publicRepos: 66,
  publicGists: 62,
  followers: 23000,
  following: 11,
  name: 'Tom Preston-Werner',
  location: 'San Francisco',
  bio: 'Cofounder of GitHub',
  email: null, // the common case
);

/// A profile with nothing optional set.
const GithubUserDetail _sparse = GithubUserDetail(
  user: _mojombo,
  publicRepos: 0,
  publicGists: 0,
  followers: 1,
  following: 0,
);

void main() {
  late MockUserRepository repository;

  setUp(() {
    installFakeAvatars();
    repository = MockUserRepository();
  });

  tearDown(restoreAvatars);

  void stubDetail(GithubUserDetail detail, {bool fromCache = false, DateTime? at}) {
    when(repository.getUserDetail('mojombo', forceRefresh: anyNamed('forceRefresh')))
        .thenAnswer(
      (_) async => Right<Failure, Sourced<GithubUserDetail>>(
        fromCache
            ? Sourced<GithubUserDetail>.cache(detail, at ?? DateTime.now())
            : Sourced<GithubUserDetail>.network(detail),
      ),
    );
  }

  void stubFailure(Failure failure) =>
      when(repository.getUserDetail(any, forceRefresh: anyNamed('forceRefresh')))
          .thenAnswer(
        (_) async => Left<Failure, Sourced<GithubUserDetail>>(failure),
      );

  Future<void> pumpDetail(WidgetTester tester, {String login = 'mojombo'}) async {
    final UserDetailBloc bloc =
        UserDetailBloc(getUserDetail: GetUserDetail(repository))
          ..add(UserDetailRequested(login));

    await tester.pumpWidget(
      wrapForTest(
        BlocProvider<UserDetailBloc>.value(
          value: bloc,
          child: UserDetailView(login: login),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders the display name and handle', (
    WidgetTester tester,
  ) async {
    stubDetail(_full);
    await pumpDetail(tester);

    expect(find.byKey(const Key('detail_name')), findsOneWidget);
    expect(find.text('Tom Preston-Werner'), findsOneWidget);
    expect(find.text('@mojombo'), findsOneWidget);
  });

  testWidgets('name falls back to the login when GitHub has none '
      '(constraint c)', (WidgetTester tester) async {
    stubDetail(_sparse);
    await pumpDetail(tester);

    final Text name =
        tester.widget<Text>(find.byKey(const Key('detail_name')));
    expect(name.data, 'mojombo');
    // The handle line is suppressed -- no point printing "mojombo" twice.
    expect(find.byKey(const Key('detail_handle')), findsNothing);
  });

  testWidgets('a hidden email shows the fallback, not a blank', (
    WidgetTester tester,
  ) async {
    stubDetail(_full);
    await pumpDetail(tester);

    expect(find.text(UserDisplay.emailUnavailable), findsOneWidget);
  });

  testWidgets('the phone row says GitHub does not provide it, and is styled '
      'as unavailable (constraint c)', (WidgetTester tester) async {
    stubDetail(_full);
    await pumpDetail(tester);

    expect(find.text('Not provided by GitHub API'), findsOneWidget);

    final DetailFieldTile phone =
        tester.widget<DetailFieldTile>(find.byKey(const Key('detail_phone')));
    expect(phone.label, 'Phone');
    expect(phone.isUnavailable, isTrue,
        reason: 'a placeholder must not look like real data');
  });

  testWidgets('renders the public counters, abbreviated', (
    WidgetTester tester,
  ) async {
    stubDetail(_full);
    await pumpDetail(tester);

    expect(find.text('66'), findsOneWidget);
    expect(find.text('23k'), findsOneWidget, reason: '23000 followers');
    expect(find.text('Followers'), findsOneWidget);
  });

  testWidgets('shows the bio and location when present', (
    WidgetTester tester,
  ) async {
    stubDetail(_full);
    await pumpDetail(tester);

    expect(find.text('Cofounder of GitHub'), findsOneWidget);
    expect(find.text('San Francisco'), findsOneWidget);
  });

  testWidgets('absent optional fields fall back rather than vanish', (
    WidgetTester tester,
  ) async {
    stubDetail(_sparse);
    await pumpDetail(tester);

    // Location, company and website are all missing on this profile.
    expect(find.text(UserDisplay.fieldUnavailable), findsNWidgets(3));
  });

  testWidgets('a 404 renders the not-found failure with Retry', (
    WidgetTester tester,
  ) async {
    stubFailure(const NotFoundFailure());
    await pumpDetail(tester, login: 'ghost');

    expect(find.byKey(const Key('error_message')), findsOneWidget);
    expect(find.textContaining('could not be found'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('a rate limit shows the countdown, not a generic error '
      '(constraint d)', (WidgetTester tester) async {
    stubFailure(
      RateLimitFailure(resetAt: DateTime.now().add(const Duration(minutes: 12))),
    );
    await pumpDetail(tester);

    expect(find.byKey(const Key('rate_limit_countdown')), findsOneWidget);
    expect(find.textContaining('Access returns in'), findsOneWidget);
  });

  testWidgets('a cached profile shows the stale banner', (
    WidgetTester tester,
  ) async {
    stubDetail(
      _full,
      fromCache: true,
      at: DateTime.now().subtract(const Duration(hours: 3)),
    );
    await pumpDetail(tester);

    expect(find.byKey(const Key('stale_banner_text')), findsOneWidget);
    expect(find.textContaining('3 hours ago'), findsOneWidget);
  });

  testWidgets('a live profile shows no stale banner', (
    WidgetTester tester,
  ) async {
    stubDetail(_full);
    await pumpDetail(tester);

    expect(find.byKey(const Key('stale_banner_text')), findsNothing);
  });
}
