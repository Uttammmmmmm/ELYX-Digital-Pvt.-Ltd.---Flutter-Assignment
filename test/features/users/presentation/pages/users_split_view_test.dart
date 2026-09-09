@Timeout(Duration(seconds: 15))
library;

import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:elyx_digital_assignment/core/di/injection_container.dart';
import 'package:elyx_digital_assignment/core/error/failures.dart';
import 'package:elyx_digital_assignment/features/users/domain/entities/paginated_users.dart';
import 'package:elyx_digital_assignment/features/users/domain/entities/user_detail.dart';
import 'package:elyx_digital_assignment/features/users/domain/entities/user_summary.dart';
import 'package:elyx_digital_assignment/features/users/domain/usecases/filter_users.dart';
import 'package:elyx_digital_assignment/features/users/domain/usecases/get_user_detail.dart';
import 'package:elyx_digital_assignment/features/users/domain/usecases/get_users.dart';
import 'package:elyx_digital_assignment/features/users/presentation/bloc/user_detail_bloc.dart';
import 'package:elyx_digital_assignment/features/users/presentation/bloc/users_bloc.dart';
import 'package:elyx_digital_assignment/features/users/presentation/bloc/users_event.dart';
import 'package:elyx_digital_assignment/features/users/presentation/pages/users_list_view.dart';
import 'package:elyx_digital_assignment/features/users/presentation/pages/users_split_view.dart';
import 'package:elyx_digital_assignment/features/users/presentation/widgets/no_selection_view.dart';
import 'package:elyx_digital_assignment/features/users/presentation/widgets/user_list_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../../../../helpers/mocks.mocks.dart';
import '../../../../helpers/widget_harness.dart';

UserSummary _u(int id, String login) => UserSummary(
  id: id,
  detailId: login,
  handle: login,
  avatarUrl: 'https://avatars.githubusercontent.com/u/$id?v=4',
  accountType: 'User',
);

final List<UserSummary> _users = <UserSummary>[
  _u(1, 'mojombo'),
  _u(2, 'defunkt'),
];

const Size _tablet = Size(1200, 900);

const Size _phone = Size(400, 800);

void main() {
  late MockUserRepository repository;
  late StreamController<bool> connectivity;

  setUp(() {
    installFakeAvatars();
    repository = MockUserRepository();
    connectivity = StreamController<bool>.broadcast();

    when(
      repository.getCachedUsers(),
    ).thenAnswer((_) async => const <UserSummary>[]);
    when(
      repository.getUsers(
        cursor: anyNamed('cursor'),
        perPage: anyNamed('perPage'),
        forceRefresh: anyNamed('forceRefresh'),
      ),
    ).thenAnswer(
      (_) async => Right<Failure, PaginatedUsers>(
        PaginatedUsers.fromBatch(users: _users, nextCursor: null),
      ),
    );
    when(repository.getUserDetail(any)).thenAnswer(
      (Invocation i) async => Right<Failure, UserDetail>(
        UserDetail(
          user: _users.firstWhere(
            (UserSummary u) => u.detailId == i.positionalArguments.first,
          ),
          followers: 10,
        ),
      ),
    );

    sl.registerFactoryParam<UserDetailBloc, UserSummary, void>(
      (UserSummary seed, _) =>
          UserDetailBloc(getUserDetail: GetUserDetail(repository), seed: seed),
    );
  });

  tearDown(() async {
    restoreAvatars();
    await connectivity.close();
    await sl.reset();
  });

  Future<void> pump(WidgetTester tester, {required Size size}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final UsersBloc bloc = UsersBloc(
      getUsers: GetUsers(repository),
      filterUsers: const FilterUsers(),
      repository: repository,
      searchDebounce: Duration.zero,
    )..add(const UsersFetched());

    await tester.pumpWidget(
      wrapForTest(
        BlocProvider<UsersBloc>.value(
          value: bloc,
          child: size.width >= 840
              ? UsersSplitView(connectivity: connectivity.stream)
              : UsersListView(connectivity: connectivity.stream),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('two-pane layout', () {
    testWidgets('tablet shows the list beside an empty detail pane', (
      WidgetTester tester,
    ) async {
      await pump(tester, size: _tablet);

      expect(find.byType(UserListTile), findsWidgets);
      expect(find.byType(NoSelectionView), findsOneWidget);
    });

    testWidgets('the list pane renders a LIST, not a grid', (
      WidgetTester tester,
    ) async {
      await pump(tester, size: _tablet);

      expect(find.byType(UserListTile), findsWidgets);
      expect(
        find.byKey(const PageStorageKey<String>('users_grid')),
        findsNothing,
      );
    });

    testWidgets('phone width does not split', (WidgetTester tester) async {
      await pump(tester, size: _phone);

      expect(find.byType(NoSelectionView), findsNothing);
      expect(find.byType(UserListTile), findsWidgets);
    });
  });

  group('selection', () {
    testWidgets('tapping shows the detail BESIDE the list, not over it', (
      WidgetTester tester,
    ) async {
      await pump(tester, size: _tablet);

      await tester.tap(find.byKey(const Key('user_tile_1')));
      await tester.pumpAndSettle();

      expect(find.byType(NoSelectionView), findsNothing);

      expect(find.byType(UserListTile), findsWidgets);
      expect(find.text('Followers'), findsOneWidget);
    });

    testWidgets('no two Heroes share a tag while both panes are mounted', (
      WidgetTester tester,
    ) async {
      await pump(tester, size: _tablet);
      await tester.tap(find.byKey(const Key('user_tile_1')));
      await tester.pumpAndSettle();

      final List<Object> tags = tester
          .widgetList<Hero>(find.byType(Hero))
          .map((Hero h) => h.tag)
          .toList();

      expect(
        tags.length,
        tags.toSet().length,
        reason: 'duplicate Hero tags across the two panes: $tags',
      );
    });

    testWidgets('selecting a second user swaps the detail pane', (
      WidgetTester tester,
    ) async {
      await pump(tester, size: _tablet);

      await tester.tap(find.byKey(const Key('user_tile_1')));
      await tester.pumpAndSettle();
      expect(find.text('mojombo'), findsWidgets);

      await tester.tap(find.byKey(const Key('user_tile_2')));
      await tester.pumpAndSettle();

      expect(find.text('defunkt'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the selected row is highlighted', (WidgetTester tester) async {
      await pump(tester, size: _tablet);

      await tester.tap(find.byKey(const Key('user_tile_1')));
      await tester.pumpAndSettle();

      final UserListTile selected = tester.widget<UserListTile>(
        find.byKey(const Key('user_tile_1')),
      );
      final UserListTile other = tester.widget<UserListTile>(
        find.byKey(const Key('user_tile_2')),
      );
      expect(selected.selected, isTrue);
      expect(other.selected, isFalse);
    });

    testWidgets('selecting pushes NO route, so back does not desynchronise', (
      WidgetTester tester,
    ) async {
      await pump(tester, size: _tablet);

      final NavigatorState nav = tester.state<NavigatorState>(
        find.byType(Navigator),
      );
      await tester.tap(find.byKey(const Key('user_tile_1')));
      await tester.pumpAndSettle();

      expect(nav.canPop(), isFalse);
    });
  });
}
