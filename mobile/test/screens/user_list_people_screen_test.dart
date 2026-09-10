// ABOUTME: Widget tests for UserListPeopleScreen route-by-id behavior.
// ABOUTME: Verifies BlocSelector reactivity and path constants.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/features/people_lists/people_lists.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/user_list_people_screen.dart';
import 'package:openvine/widgets/user_avatar.dart';

import '../helpers/finders.dart';
import '../helpers/test_provider_overrides.dart';

class _MockPeopleListsBloc extends MockBloc<PeopleListsEvent, PeopleListsState>
    implements PeopleListsBloc {}

const _ownerPubkey =
    'f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0';
const _otherOwnerPubkey =
    '0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a';

UserList _buildList({
  String id = 'list-1',
  String name = 'Close Friends',
  List<String> pubkeys = const [],
  bool isEditable = true,
}) {
  final now = DateTime.utc(2025);
  return UserList(
    id: id,
    name: name,
    pubkeys: pubkeys,
    createdAt: now,
    updatedAt: now,
    isEditable: isEditable,
  );
}

Future<void> _pumpPeopleListScreen(
  WidgetTester tester, {
  required PeopleListsBloc bloc,
  required UserList list,
}) async {
  await tester.pumpWidget(
    testProviderScope(
      child: MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<PeopleListsBloc>.value(
          value: bloc,
          child: UserListPeopleScreen(listId: list.id),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Pushes the list route on top of a home route, so a pop is observable as
/// `Open list` coming back into view.
Future<void> _pumpPushedListRoute(
  WidgetTester tester, {
  required PeopleListsBloc bloc,
  required UserList list,
}) async {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () =>
                  context.push('/people-lists/${Uri.encodeComponent(list.id)}'),
              child: const Text('Open list'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: UserListPeopleScreen.path,
        name: UserListPeopleScreen.routeName,
        builder: (context, state) {
          final listId = state.pathParameters['listId'];
          if (listId == null || listId.isEmpty) {
            return const Scaffold(body: Center(child: Text('Invalid list')));
          }
          return UserListPeopleScreen(listId: listId);
        },
      ),
    ],
  );

  await tester.pumpWidget(
    testProviderScope(
      child: BlocProvider<PeopleListsBloc>.value(
        value: bloc,
        child: MaterialApp.router(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.tap(find.text('Open list'));
  await tester.pumpAndSettle();
}

/// Collects screen-reader announcements until the test ends.
List<String> _captureAnnouncements(WidgetTester tester) {
  final announcements = <String>[];
  tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(
    SystemChannels.accessibility,
    (Object? message) async {
      if (message is Map && message['type'] == 'announce') {
        final data = message['data'];
        if (data is Map) announcements.add('${data['message']}');
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger
        .setMockDecodedMessageHandler<Object?>(
          SystemChannels.accessibility,
          null,
        ),
  );
  return announcements;
}

/// Opens the delete confirmation from the overflow menu and confirms it.
Future<void> _confirmDelete(WidgetTester tester, AppLocalizations l10n) async {
  await tester.tap(findByTooltip(l10n.peopleListsActionsTooltip));
  await tester.pumpAndSettle();
  await tester.tap(find.text(l10n.listDeleteAction));
  await tester.pumpAndSettle();
  await tester.tap(find.text(l10n.commonDelete));
  await tester.pumpAndSettle();
}

void main() {
  group(UserListPeopleScreen, () {
    final l10n = lookupAppLocalizations(const Locale('en'));

    test('exposes route name and path constants', () {
      expect(UserListPeopleScreen.routeName, equals('people-list-members'));
      expect(UserListPeopleScreen.path, equals('/people-lists/:listId'));
    });

    testWidgets(
      'constructor accepts listId and selects matching list from bloc',
      (tester) async {
        final bloc = _MockPeopleListsBloc();
        final list = _buildList(name: 'Selected List');
        whenListen(
          bloc,
          const Stream<PeopleListsState>.empty(),
          initialState: PeopleListsState(
            status: PeopleListsStatus.ready,
            ownerPubkey: 'f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0',
            lists: [list],
          ),
        );

        await tester.pumpWidget(
          testProviderScope(
            child: MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: BlocProvider<PeopleListsBloc>.value(
                value: bloc,
                child: UserListPeopleScreen(listId: list.id),
              ),
            ),
          ),
        );

        await tester.pump();

        expect(find.text('Selected List'), findsOneWidget);
      },
    );

    testWidgets(
      'reacts to bloc emitting updated list without rebuilding the route',
      (tester) async {
        final bloc = _MockPeopleListsBloc();
        final initialList = _buildList(name: 'Old Name');
        final updatedList = _buildList(name: 'New Name');
        final controller = StreamController<PeopleListsState>.broadcast();
        addTearDown(controller.close);

        const ownerPubkey =
            'aa11bb22cc33dd44ee55ff66aa11bb22cc33dd44ee55ff66aa11bb22cc33dd44';

        whenListen(
          bloc,
          controller.stream,
          initialState: PeopleListsState(
            status: PeopleListsStatus.ready,
            ownerPubkey: ownerPubkey,
            lists: [initialList],
          ),
        );

        await tester.pumpWidget(
          testProviderScope(
            child: MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: BlocProvider<PeopleListsBloc>.value(
                value: bloc,
                child: UserListPeopleScreen(listId: initialList.id),
              ),
            ),
          ),
        );

        await tester.pump();
        expect(find.text('Old Name'), findsOneWidget);

        // Emit the updated state — the open screen must re-select and
        // show the new name without the route being rebuilt.
        controller.add(
          PeopleListsState(
            status: PeopleListsStatus.ready,
            ownerPubkey: ownerPubkey,
            lists: [updatedList],
          ),
        );
        // Allow the broadcast microtask to propagate to BlocSelector.
        await tester.pump(Duration.zero);
        await tester.pump();

        expect(find.text('New Name'), findsOneWidget);
        expect(find.text('Old Name'), findsNothing);
      },
    );

    testWidgets(
      'renders not-found state when listId is missing from bloc state',
      (tester) async {
        final bloc = _MockPeopleListsBloc();
        whenListen(
          bloc,
          const Stream<PeopleListsState>.empty(),
          initialState: const PeopleListsState(status: PeopleListsStatus.ready),
        );

        await tester.pumpWidget(
          testProviderScope(
            child: MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: BlocProvider<PeopleListsBloc>.value(
                value: bloc,
                child: const UserListPeopleScreen(listId: 'missing-id'),
              ),
            ),
          ),
        );

        await tester.pump();

        expect(find.text(l10n.peopleListsListNotFoundTitle), findsOneWidget);
      },
    );

    testWidgets('shows the add-people action when current list is editable', (
      tester,
    ) async {
      final bloc = _MockPeopleListsBloc();
      final list = _buildList(id: 'punk-friends', name: 'Punk Friends');
      whenListen(
        bloc,
        const Stream<PeopleListsState>.empty(),
        initialState: PeopleListsState(
          status: PeopleListsStatus.ready,
          ownerPubkey: 'f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0',
          lists: [list],
        ),
      );

      await tester.pumpWidget(
        testProviderScope(
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: BlocProvider<PeopleListsBloc>.value(
              value: bloc,
              child: UserListPeopleScreen(listId: list.id),
            ),
          ),
        ),
      );

      await tester.pump();

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(
        find.bySemanticsLabel(l10n.peopleListsAddPeopleSemanticLabel),
        findsOneWidget,
      );
    });

    testWidgets('hides the add-people action when current list is read-only', (
      tester,
    ) async {
      final bloc = _MockPeopleListsBloc();
      // Read-only lists (e.g. Divine Team) carry isEditable: false and must
      // not expose the add-people action — editing them is forbidden.
      final list = _buildList(
        id: 'divine-team',
        name: 'Divine Team',
        isEditable: false,
      );
      whenListen(
        bloc,
        const Stream<PeopleListsState>.empty(),
        initialState: PeopleListsState(
          status: PeopleListsStatus.ready,
          ownerPubkey: 'f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0',
          lists: [list],
        ),
      );

      await tester.pumpWidget(
        testProviderScope(
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: BlocProvider<PeopleListsBloc>.value(
              value: bloc,
              child: UserListPeopleScreen(listId: list.id),
            ),
          ),
        ),
      );

      await tester.pump();

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(
        find.bySemanticsLabel(l10n.peopleListsAddPeopleSemanticLabel),
        findsNothing,
      );
    });

    testWidgets('shows delete action when current list is editable', (
      tester,
    ) async {
      final bloc = _MockPeopleListsBloc();
      final list = _buildList(id: 'owned-list', name: 'Owned List');
      whenListen(
        bloc,
        const Stream<PeopleListsState>.empty(),
        initialState: PeopleListsState(
          status: PeopleListsStatus.ready,
          ownerPubkey: _ownerPubkey,
          lists: [list],
        ),
      );

      await _pumpPeopleListScreen(tester, bloc: bloc, list: list);

      expect(findByTooltip(l10n.peopleListsActionsTooltip), findsOneWidget);

      await tester.tap(findByTooltip(l10n.peopleListsActionsTooltip));
      await tester.pumpAndSettle();

      expect(find.text(l10n.listDeleteAction), findsOneWidget);
    });

    testWidgets('hides delete action menu when current list is read-only', (
      tester,
    ) async {
      final bloc = _MockPeopleListsBloc();
      final list = _buildList(
        id: 'divine-team',
        name: 'Divine Team',
        isEditable: false,
      );
      whenListen(
        bloc,
        const Stream<PeopleListsState>.empty(),
        initialState: PeopleListsState(
          status: PeopleListsStatus.ready,
          ownerPubkey: _ownerPubkey,
          lists: [list],
        ),
      );

      await _pumpPeopleListScreen(tester, bloc: bloc, list: list);

      expect(findByTooltip(l10n.peopleListsActionsTooltip), findsNothing);
      expect(find.text(l10n.listDeleteAction), findsNothing);
    });

    testWidgets('delete confirmation cancel does not dispatch', (tester) async {
      final bloc = _MockPeopleListsBloc();
      final list = _buildList(
        id: 'cancel-delete-list',
        name: 'Cancel Delete List',
      );
      whenListen(
        bloc,
        const Stream<PeopleListsState>.empty(),
        initialState: PeopleListsState(
          status: PeopleListsStatus.ready,
          ownerPubkey: _ownerPubkey,
          lists: [list],
        ),
      );

      await _pumpPeopleListScreen(tester, bloc: bloc, list: list);

      await tester.tap(findByTooltip(l10n.peopleListsActionsTooltip));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.listDeleteAction));
      await tester.pumpAndSettle();

      expect(find.text(l10n.peopleListsDeleteConfirmTitle), findsOneWidget);
      expect(find.text(l10n.peopleListsDeleteConfirmBody), findsOneWidget);

      await tester.tap(find.text(l10n.commonCancel));
      await tester.pumpAndSettle();

      verifyNever(() => bloc.add(any()));
      expect(find.text('Cancel Delete List'), findsOneWidget);
    });

    testWidgets(
      'delete confirmation confirm dispatches delete request and pops after success',
      (tester) async {
        final bloc = _MockPeopleListsBloc();
        final list = _buildList(
          id: 'confirm-delete-list',
          name: 'Confirm Delete List',
        );
        final controller = StreamController<PeopleListsState>.broadcast();
        addTearDown(controller.close);
        whenListen(
          bloc,
          controller.stream,
          initialState: PeopleListsState(
            status: PeopleListsStatus.ready,
            ownerPubkey: _ownerPubkey,
            lists: [list],
          ),
        );

        await _pumpPushedListRoute(tester, bloc: bloc, list: list);
        await _confirmDelete(tester, l10n);

        verify(
          () => bloc.add(
            const PeopleListsDeleteRequested(listId: 'confirm-delete-list'),
          ),
        ).called(1);
        expect(find.text('Confirm Delete List'), findsOneWidget);

        controller
          ..add(
            const PeopleListsState(
              status: PeopleListsStatus.submitting,
              ownerPubkey: _ownerPubkey,
              pendingMutations: {
                'delete-1': PeopleListsMutation(
                  id: 'delete-1',
                  kind: PeopleListsMutationKind.deleteList,
                  listId: 'confirm-delete-list',
                ),
              },
            ),
          )
          ..add(
            const PeopleListsState(
              status: PeopleListsStatus.ready,
              ownerPubkey: _ownerPubkey,
            ),
          );
        await tester.pumpAndSettle();

        expect(find.text('Confirm Delete List'), findsNothing);
        expect(find.text('Open list'), findsOneWidget);
      },
    );

    // #6504: a teardown clears `pendingMutations` wholesale, which reads
    // exactly like the delete settling. The relay still has the list, so
    // announcing a delete and popping the route would be a lie.
    testWidgets('a delete dropped by a flag-off neither announces nor pops', (
      tester,
    ) async {
      final bloc = _MockPeopleListsBloc();
      final list = _buildList(id: 'flag-off-list', name: 'Flag Off List');
      final controller = StreamController<PeopleListsState>.broadcast();
      addTearDown(controller.close);
      whenListen(
        bloc,
        controller.stream,
        initialState: PeopleListsState(
          status: PeopleListsStatus.ready,
          ownerPubkey: _ownerPubkey,
          lists: [list],
        ),
      );

      await _pumpPushedListRoute(tester, bloc: bloc, list: list);
      await _confirmDelete(tester, l10n);
      final announcements = _captureAnnouncements(tester);

      controller
        ..add(
          const PeopleListsState(
            status: PeopleListsStatus.submitting,
            ownerPubkey: _ownerPubkey,
            pendingMutations: {
              'delete-1': PeopleListsMutation(
                id: 'delete-1',
                kind: PeopleListsMutationKind.deleteList,
                listId: 'flag-off-list',
              ),
            },
          ),
        )
        // What `_onEnabledChanged` emits when the curated-lists flag goes off.
        ..add(
          const PeopleListsState(ownerPubkey: _ownerPubkey, enabled: false),
        );
      await tester.pumpAndSettle();

      expect(announcements, isEmpty);
      expect(find.text(l10n.peopleListsDeleteFailed), findsNothing);
      expect(find.text('Open list'), findsNothing);
      expect(find.text(l10n.peopleListsListNotFoundTitle), findsOneWidget);
    });

    testWidgets(
      'a delete dropped by an account switch neither announces nor pops',
      (tester) async {
        final bloc = _MockPeopleListsBloc();
        final list = _buildList(id: 'switch-list', name: 'Switch List');
        final controller = StreamController<PeopleListsState>.broadcast();
        addTearDown(controller.close);
        whenListen(
          bloc,
          controller.stream,
          initialState: PeopleListsState(
            status: PeopleListsStatus.ready,
            ownerPubkey: _ownerPubkey,
            lists: [list],
          ),
        );

        await _pumpPushedListRoute(tester, bloc: bloc, list: list);
        await _confirmDelete(tester, l10n);
        final announcements = _captureAnnouncements(tester);

        controller
          ..add(
            const PeopleListsState(
              status: PeopleListsStatus.submitting,
              ownerPubkey: _ownerPubkey,
              pendingMutations: {
                'delete-1': PeopleListsMutation(
                  id: 'delete-1',
                  kind: PeopleListsMutationKind.deleteList,
                  listId: 'switch-list',
                ),
              },
            ),
          )
          // What `_onOwnerChanged` emits when another account signs in.
          ..add(
            const PeopleListsState(
              status: PeopleListsStatus.loading,
              ownerPubkey: _otherOwnerPubkey,
            ),
          );
        await tester.pumpAndSettle();

        expect(announcements, isEmpty);
        expect(find.text(l10n.peopleListsDeleteFailed), findsNothing);
        expect(find.text('Open list'), findsNothing);
        expect(find.text(l10n.peopleListsListNotFoundTitle), findsOneWidget);
      },
    );

    testWidgets('delete failure keeps route open and shows failure feedback', (
      tester,
    ) async {
      final bloc = _MockPeopleListsBloc();
      final list = _buildList(
        id: 'failed-delete-list',
        name: 'Failed Delete List',
      );
      final controller = StreamController<PeopleListsState>.broadcast();
      addTearDown(controller.close);
      whenListen(
        bloc,
        controller.stream,
        initialState: PeopleListsState(
          status: PeopleListsStatus.ready,
          ownerPubkey: _ownerPubkey,
          lists: [list],
        ),
      );

      await _pumpPeopleListScreen(tester, bloc: bloc, list: list);

      await tester.tap(findByTooltip(l10n.peopleListsActionsTooltip));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.listDeleteAction));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.commonDelete));
      await tester.pumpAndSettle();

      verify(
        () => bloc.add(
          const PeopleListsDeleteRequested(listId: 'failed-delete-list'),
        ),
      ).called(1);

      controller
        ..add(
          const PeopleListsState(
            status: PeopleListsStatus.submitting,
            ownerPubkey: _ownerPubkey,
            pendingMutations: {
              'delete-1': PeopleListsMutation(
                id: 'delete-1',
                kind: PeopleListsMutationKind.deleteList,
                listId: 'failed-delete-list',
              ),
            },
          ),
        )
        ..add(
          PeopleListsState(
            status: PeopleListsStatus.failure,
            ownerPubkey: _ownerPubkey,
            lists: [list],
          ),
        );
      await tester.pumpAndSettle();

      expect(find.text('Failed Delete List'), findsOneWidget);
      expect(find.text(l10n.peopleListsDeleteFailed), findsOneWidget);
    });

    testWidgets(
      'long-press on a member of an editable list shows remove confirmation',
      (tester) async {
        final bloc = _MockPeopleListsBloc();
        const memberPubkey =
            '1111222233334444555566667777888899990000aaaabbbbccccddddeeeeffff';
        whenListen(
          bloc,
          const Stream<PeopleListsState>.empty(),
          initialState: const PeopleListsState(status: PeopleListsStatus.ready),
        );

        await tester.pumpWidget(
          testProviderScope(
            child: MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: BlocProvider<PeopleListsBloc>.value(
                value: bloc,
                child: const Scaffold(
                  body: PeopleCarousel(
                    pubkeys: [memberPubkey],
                    listId: 'list-1',
                    canRemove: true,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        await tester.longPress(find.byType(UserAvatar).first);
        await tester.pumpAndSettle();

        expect(find.text('Remove'), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);
      },
    );

    testWidgets(
      'confirming remove dispatches PeopleListsPubkeyRemoveRequested',
      (tester) async {
        final bloc = _MockPeopleListsBloc();
        const memberPubkey =
            '1111222233334444555566667777888899990000aaaabbbbccccddddeeeeffff';
        whenListen(
          bloc,
          const Stream<PeopleListsState>.empty(),
          initialState: const PeopleListsState(status: PeopleListsStatus.ready),
        );

        await tester.pumpWidget(
          testProviderScope(
            child: MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: BlocProvider<PeopleListsBloc>.value(
                value: bloc,
                child: const Scaffold(
                  body: PeopleCarousel(
                    pubkeys: [memberPubkey],
                    listId: 'list-1',
                    canRemove: true,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        await tester.longPress(find.byType(UserAvatar).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Remove'));
        await tester.pumpAndSettle();

        verify(
          () => bloc.add(
            const PeopleListsPubkeyRemoveRequested(
              listId: 'list-1',
              pubkey: memberPubkey,
            ),
          ),
        ).called(1);
      },
    );

    testWidgets('undo snackbar dispatches PeopleListsPubkeyAddRequested', (
      tester,
    ) async {
      final bloc = _MockPeopleListsBloc();
      const memberPubkey =
          '1111222233334444555566667777888899990000aaaabbbbccccddddeeeeffff';
      whenListen(
        bloc,
        const Stream<PeopleListsState>.empty(),
        initialState: const PeopleListsState(status: PeopleListsStatus.ready),
      );

      await tester.pumpWidget(
        testProviderScope(
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: BlocProvider<PeopleListsBloc>.value(
              value: bloc,
              child: const Scaffold(
                body: PeopleCarousel(
                  pubkeys: [memberPubkey],
                  listId: 'list-1',
                  canRemove: true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.longPress(find.byType(UserAvatar).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      verify(
        () => bloc.add(
          const PeopleListsPubkeyAddRequested(
            listId: 'list-1',
            pubkey: memberPubkey,
          ),
        ),
      ).called(1);
    });

    testWidgets(
      'long-press on a read-only list member does NOT show remove dialog',
      (tester) async {
        final bloc = _MockPeopleListsBloc();
        const memberPubkey =
            '1111222233334444555566667777888899990000aaaabbbbccccddddeeeeffff';
        whenListen(
          bloc,
          const Stream<PeopleListsState>.empty(),
          initialState: const PeopleListsState(status: PeopleListsStatus.ready),
        );

        // Wrap in GoRouter since long-press still triggers onTap (no-op
        // long-press when canRemove:false); the tap handler calls
        // context.push(profile) and needs a router.
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const Scaffold(
                body: PeopleCarousel(
                  pubkeys: [memberPubkey],
                  listId: 'divine-team',
                  canRemove: false,
                ),
              ),
            ),
            GoRoute(
              path: '/profile/:npub',
              builder: (context, state) =>
                  const Scaffold(body: Text('profile')),
            ),
          ],
        );

        await tester.pumpWidget(
          testProviderScope(
            child: BlocProvider<PeopleListsBloc>.value(
              value: bloc,
              child: MaterialApp.router(
                localizationsDelegates: appLocalizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                routerConfig: router,
              ),
            ),
          ),
        );
        await tester.pump();

        await tester.longPress(find.byType(UserAvatar).first);
        await tester.pumpAndSettle();

        expect(find.text('Remove'), findsNothing);
        expect(find.text('Cancel'), findsNothing);
      },
    );
  });

  group('GoRouter /people-lists/:listId', () {
    testWidgets(
      'route uses handwritten GoRoute and resolves listId path param',
      (
        tester,
      ) async {
        final bloc = _MockPeopleListsBloc();
        final list = _buildList(id: 'routed-list', name: 'Routed List');
        whenListen(
          bloc,
          const Stream<PeopleListsState>.empty(),
          initialState: PeopleListsState(
            status: PeopleListsStatus.ready,
            ownerPubkey: 'bb11cc22dd33ee44ff55aa66bb11cc22dd33ee44ff55aa66bb11cc22dd33ee44',
            lists: [list],
          ),
        );

        final router = GoRouter(
          initialLocation: '/people-lists/${Uri.encodeComponent(list.id)}',
          routes: [
            GoRoute(
              path: UserListPeopleScreen.path,
              name: UserListPeopleScreen.routeName,
              builder: (context, state) {
                final listId = state.pathParameters['listId'];
                if (listId == null || listId.isEmpty) {
                  return const Scaffold(
                    body: Center(child: Text('Invalid list')),
                  );
                }
                return UserListPeopleScreen(listId: listId);
              },
            ),
          ],
        );

        await tester.pumpWidget(
          testProviderScope(
            child: BlocProvider<PeopleListsBloc>.value(
              value: bloc,
              child: MaterialApp.router(
                localizationsDelegates: appLocalizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                routerConfig: router,
              ),
            ),
          ),
        );

        await tester.pump();

        expect(find.byType(UserListPeopleScreen), findsOneWidget);
        expect(find.text('Routed List'), findsOneWidget);
      },
    );

    testWidgets(
      'route falls back to invalid-list scaffold with back button for '
      'empty listId',
      (tester) async {
        // Exercises the exact same builder shape as the real app router
        // so a regression that drops the fallback back button is caught.
        Widget buildFallbackFor(String? listId) {
          return Builder(
            builder: (context) {
              if (listId == null || listId.isEmpty) {
                return Scaffold(
                  appBar: DiVineAppBar(
                    title: 'People list',
                    showBackButton: true,
                    onBackPressed: context.pop,
                  ),
                  body: const Center(child: Text('Invalid list')),
                );
              }
              return const SizedBox();
            },
          );
        }

        final router = GoRouter(
          initialLocation: '/seed',
          routes: [
            GoRoute(
              path: '/seed',
              builder: (context, state) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => context.push('/invalid-list'),
                    child: const Text('Go'),
                  ),
                ),
              ),
            ),
            GoRoute(
              path: '/invalid-list',
              builder: (context, state) => buildFallbackFor(null),
            ),
          ],
        );

        await tester.pumpWidget(
          MaterialApp.router(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        );

        await tester.pump();
        await tester.tap(find.text('Go'));
        await tester.pumpAndSettle();

        expect(find.text('Invalid list'), findsOneWidget);
        expect(find.text('People list'), findsOneWidget);
        // Identifier, not label: the back label is now
        // MaterialLocalizations.backButtonTooltip and moves per locale.
        expect(find.bySemanticsIdentifier('back_button'), findsOneWidget);

        // Tapping the back button pops the fallback route.
        await tester.tap(find.bySemanticsIdentifier('back_button'));
        await tester.pumpAndSettle();

        expect(find.text('Invalid list'), findsNothing);
        expect(find.text('Go'), findsOneWidget);
      },
    );
  });

  setUpAll(() {
    registerFallbackValue(const PeopleListsStarted());
  });
}
