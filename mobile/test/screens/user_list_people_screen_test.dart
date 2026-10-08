// ABOUTME: Widget tests for UserListPeopleScreen route-by-id behavior.
// ABOUTME: Verifies BlocSelector reactivity and path constants.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/extensions/safe_pop_extension.dart';
import 'package:openvine/features/people_lists/people_lists.dart';
import 'package:openvine/features/people_lists/view/people_list_hero_header.dart';
import 'package:openvine/features/people_lists/view/people_list_member_tile.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/list_providers.dart';
import 'package:openvine/providers/video_events_providers.dart';
import 'package:openvine/screens/user_list_people_screen.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/follow_list_button.dart';
import 'package:openvine/widgets/share_list_button.dart';
import 'package:people_lists_repository/people_lists_repository.dart';
import 'package:videos_repository/videos_repository.dart';

import '../helpers/finders.dart';
import '../helpers/test_provider_overrides.dart';

class _MockPeopleListsBloc extends MockBloc<PeopleListsEvent, PeopleListsState>
    implements PeopleListsBloc {}

class _MockVideosRepository extends Mock implements VideosRepository {
  _MockVideosRepository() {
    when(
      () => applyContentPreferences(any()),
    ).thenAnswer((call) => call.positionalArguments.single as List<VideoEvent>);
  }
}

class _MockPeopleListsRepository extends Mock
    implements PeopleListsRepository {}

/// An empty feed pool, so the members feed has nothing to paint before its
/// fetch answers.
class _EmptyVideoEventsPool extends VideoEvents {
  @override
  Stream<List<VideoEvent>> build() async* {
    yield const [];
  }
}

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
  List<Override> overrides = const [],
}) async {
  await tester.pumpWidget(
    testProviderScope(
      additionalOverrides: overrides,
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
      GoRoute(
        path: '${UserListPeopleScreen.path}/add-people',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Add people picker'))),
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
  await tester.tap(find.byTooltip(l10n.peopleListsActionsTooltip));
  await tester.pumpAndSettle();
  await tester.tap(find.text(l10n.listDeleteAction));
  await tester.pumpAndSettle();
  await tester.tap(find.text(l10n.commonDelete));
  await tester.pumpAndSettle();
}

void main() {
  group(UserListPeopleScreen, () {
    final l10n = lookupAppLocalizations(const Locale('en'));

    group('sharing a public people list', () {
      Future<void> pumpShareableList(WidgetTester tester) async {
        final bloc = _MockPeopleListsBloc();
        final list = _buildList(
          id: 'crew',
          name: 'Crew',
          isEditable: false,
        );
        whenListen(
          bloc,
          const Stream<PeopleListsState>.empty(),
          initialState: const PeopleListsState(status: PeopleListsStatus.ready),
        );
        await tester.pumpWidget(
          testProviderScope(
            additionalOverrides: [
              publicPeopleListProvider(
                ownerPubkey: _otherOwnerPubkey,
                listId: 'crew',
              ).overrideWith((ref) async => list),
            ],
            child: MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: BlocProvider<PeopleListsBloc>.value(
                value: bloc,
                child: const UserListPeopleScreen(
                  listId: 'crew',
                  ownerPubkey: _otherOwnerPubkey,
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();
      }

      testWidgets('offers Share to a signed-out viewer', (tester) async {
        await pumpShareableList(tester);

        expect(find.byType(ShareListButton), findsOneWidget);
        expect(findByTooltip(l10n.listShareAction), findsOneWidget);
      });

      testWidgets('shares the public web address before following', (
        tester,
      ) async {
        final shareCalls = <Map<Object?, Object?>>[];
        const channel = MethodChannel('dev.fluttercommunity.plus/share');
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              if (call.method != 'share') return null;
              shareCalls.add(call.arguments as Map<Object?, Object?>);
              return 'com.apple.UIKit.activity.CopyToPasteboard';
            });
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMethodCallHandler(channel, null),
        );
        await pumpShareableList(tester);

        await tester.tap(findByTooltip(l10n.listShareAction));
        await tester.pump();
        await tester.pump();

        expect(shareCalls, hasLength(1));
        expect(
          shareCalls.single['text'],
          contains('https://divine.video/people-lists/$_otherOwnerPubkey/crew'),
        );
      });
    });

    for (final listExists in [false, true]) {
      testWidgets('cold list back returns to Home (exists: $listExists)', (
        tester,
      ) async {
        final bloc = _MockPeopleListsBloc();
        final list = _buildList(id: 'cold-list');
        whenListen(
          bloc,
          const Stream<PeopleListsState>.empty(),
          initialState: PeopleListsState(
            status: PeopleListsStatus.ready,
            ownerPubkey: _ownerPubkey,
            lists: listExists ? [list] : [],
          ),
        );
        final router = GoRouter(
          initialLocation: '/people-lists/cold-list',
          routes: [
            GoRoute(
              path: defaultSafePopFallback,
              builder: (_, _) => const Scaffold(body: Text('Home fallback')),
            ),
            GoRoute(
              path: UserListPeopleScreen.path,
              builder: (_, state) =>
                  UserListPeopleScreen(listId: state.pathParameters['listId']!),
            ),
          ],
        );
        addTearDown(router.dispose);
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
        await tester.pumpAndSettle();
        expect(router.canPop(), isFalse);
        expect(find.text('Home fallback'), findsNothing);
        final backLabel = MaterialLocalizations.of(
          tester.element(find.byType(DiVineAppBar)),
        ).backButtonTooltip;
        await tester.tap(find.bySemanticsLabel(backLabel));
        await tester.pumpAndSettle();
        expect(find.text('Home fallback'), findsOneWidget);
      });
    }

    testWidgets('retries a failed member read without exposing the exception', (
      tester,
    ) async {
      final bloc = _MockPeopleListsBloc();
      final list = _buildList(pubkeys: const [_ownerPubkey]);
      whenListen(
        bloc,
        const Stream<PeopleListsState>.empty(),
        initialState: PeopleListsState(
          status: PeopleListsStatus.ready,
          ownerPubkey: _ownerPubkey,
          lists: [list],
        ),
      );
      final repository = _MockVideosRepository();
      when(() => repository.applyContentPreferences(any())).thenAnswer(
        (invocation) =>
            invocation.positionalArguments.single as List<VideoEvent>,
      );
      const error = RelayReadUnavailableException('the read timed out');
      when(
        () => repository.getVideosByAuthors(authorPubkeys: list.pubkeys),
      ).thenThrow(error);

      await tester.pumpWidget(
        testProviderScope(
          additionalOverrides: [
            videosRepositoryProvider.overrideWithValue(repository),
            videoEventsProvider.overrideWith(_EmptyVideoEventsPool.new),
          ],
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
      await tester.pumpAndSettle();

      expect(find.text(l10n.peopleListsFailedToLoadVideos), findsOneWidget);
      expect(find.text(l10n.commonRetry), findsOneWidget);
      expect(find.text(error.toString()), findsNothing);

      final retriedRead = Completer<List<VideoEvent>>();
      when(
        () => repository.getVideosByAuthors(authorPubkeys: list.pubkeys),
      ).thenAnswer((_) => retriedRead.future);
      await tester.tap(find.text(l10n.commonRetry));
      await tester.pump();
      await tester.pump();
      expect(find.byType(DivineCircularProgressIndicator), findsOneWidget);

      retriedRead.complete(const []);
      await tester.pumpAndSettle();
      expect(find.text(l10n.peopleListsNoVideosTitle), findsOneWidget);
      expect(find.text(l10n.peopleListsFailedToLoadVideos), findsNothing);
      expect(find.text(l10n.commonRetry), findsNothing);
      verify(
        () => repository.getVideosByAuthors(authorPubkeys: list.pubkeys),
      ).called(2);
    });

    for (final readStatus in PeopleListsOwnerReadStatus.values) {
      for (final cached in [false, true]) {
        testWidgets(
          'owner read $readStatus preserves cache:$cached and renders settled absence',
          (tester) async {
            final list = _buildList();
            final bloc = _MockPeopleListsBloc();
            whenListen(
              bloc,
              const Stream<PeopleListsState>.empty(),
              initialState: PeopleListsState(
                status: PeopleListsStatus.ready,
                ownerPubkey: _ownerPubkey,
                lists: cached ? [list] : [],
                ownerReadStatus: readStatus,
              ),
            );
            await _pumpPeopleListScreen(tester, bloc: bloc, list: list);
            await tester.pump();
            if (cached) {
              expect(find.text(list.name), findsOneWidget);
              expect(find.text(l10n.peopleListsLoadFailed), findsNothing);
            } else if (readStatus == PeopleListsOwnerReadStatus.pending) {
              expect(find.byType(BrandedLoadingIndicator), findsOneWidget);
              expect(
                find.text(l10n.peopleListsListNotFoundTitle),
                findsNothing,
              );
            } else if (readStatus == PeopleListsOwnerReadStatus.failed) {
              expect(find.text(l10n.peopleListsLoadFailed), findsOneWidget);
              await tester.tap(find.text(l10n.commonRetry));
              verify(() => bloc.add(const PeopleListsOwnerSyncRequested()))
                  .called(1);
            } else {
              expect(
                find.text(l10n.peopleListsListNotFoundTitle),
                findsOneWidget,
              );
            }
          },
        );
      }
    }

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

    testWidgets('a discovered list that fails to load offers a retry', (
      tester,
    ) async {
      // A relay failure must not read as "this list was deleted": the
      // viewer gets the failure copy and a retry that re-runs the read.
      const otherOwner =
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
      final list = _buildList(id: 'crew', name: 'Crew', isEditable: false);
      var attempts = 0;
      final bloc = _MockPeopleListsBloc();
      whenListen(
        bloc,
        const Stream<PeopleListsState>.empty(),
        initialState: const PeopleListsState(
          status: PeopleListsStatus.ready,
          ownerPubkey: _ownerPubkey,
        ),
      );

      await tester.pumpWidget(
        testProviderScope(
          additionalOverrides: [
            publicPeopleListProvider(
              ownerPubkey: otherOwner,
              listId: 'crew',
            ).overrideWith((ref) async {
              attempts++;
              if (attempts == 1) throw Exception('relay timed out');
              return list;
            }),
          ],
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: BlocProvider<PeopleListsBloc>.value(
              value: bloc,
              child: const UserListPeopleScreen(
                listId: 'crew',
                ownerPubkey: otherOwner,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text(l10n.peopleListsLoadFailed), findsOneWidget);
      expect(find.text(l10n.peopleListsListNotFoundTitle), findsNothing);

      await tester.tap(find.text(l10n.commonRetry));
      await tester.pump();
      await tester.pump();
      // The hero lives in the video grid, which paints a frame after the
      // broken-video tracker resolves.
      await tester.pump();

      expect(attempts, 2);
      expect(find.text('Crew'), findsOneWidget);
      expect(find.text(l10n.peopleListsLoadFailed), findsNothing);
    });

    testWidgets(
      'a failed member read shows loading while an explicit retry is pending',
      (tester) async {
        const member =
            'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
        final list = _buildList(pubkeys: const [member]);
        final bloc = _MockPeopleListsBloc();
        whenListen(
          bloc,
          const Stream<PeopleListsState>.empty(),
          initialState: PeopleListsState(
            status: PeopleListsStatus.ready,
            ownerPubkey: _ownerPubkey,
            lists: [list],
          ),
        );
        final videosRepository = _MockVideosRepository();
        var attempts = 0;
        final retryResult = Completer<List<VideoEvent>>();
        when(() => videosRepository.applyContentPreferences(any())).thenAnswer(
          (invocation) =>
              invocation.positionalArguments.single as List<VideoEvent>,
        );
        when(
          () => videosRepository.getVideosByAuthors(
            authorPubkeys: any(named: 'authorPubkeys'),
          ),
        ).thenAnswer((_) async {
          attempts++;
          if (attempts == 1) {
            throw const RelayReadUnavailableException('relay down');
          }
          return retryResult.future;
        });

        await tester.pumpWidget(
          testProviderScope(
            additionalOverrides: [
              videosRepositoryProvider.overrideWithValue(videosRepository),
              videoEventsProvider.overrideWith(_EmptyVideoEventsPool.new),
            ],
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
        await tester.pump();
        await tester.pump();

        // A provider that retries on its own stays loading while it carries
        // the error, and the viewer never reaches this view.
        expect(find.text(l10n.peopleListsFailedToLoadVideos), findsOneWidget);
        expect(attempts, equals(1));

        await tester.tap(find.text(l10n.commonRetry));
        await tester.pump();
        await tester.pump();
        await tester.pump();

        expect(attempts, equals(2));
        expect(find.byType(DivineCircularProgressIndicator), findsOneWidget);
        expect(find.text(l10n.peopleListsFailedToLoadVideos), findsNothing);
        retryResult.complete(const []);
        await tester.pumpAndSettle();
        expect(find.byType(DivineCircularProgressIndicator), findsNothing);
        expect(find.text(l10n.peopleListsFailedToLoadVideos), findsNothing);
      },
    );

    group('Follow', () {
      const listOwner =
          'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
      const member =
          'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';

      late _MockPeopleListsRepository repository;
      late StreamController<List<PeopleListSearchResult>> followedController;
      late UserList discovered;
      late bool durableFollow;

      setUp(() {
        repository = _MockPeopleListsRepository();
        durableFollow = false;
        when(
          () => repository.isFollowingList(
            viewerPubkey: any(named: 'viewerPubkey'),
            ownerPubkey: any(named: 'ownerPubkey'),
            listId: any(named: 'listId'),
          ),
        ).thenAnswer((_) async => durableFollow);
        followedController =
            StreamController<List<PeopleListSearchResult>>.broadcast();
        discovered = _buildList(
          id: 'crew',
          name: 'Crew',
          pubkeys: const [member],
          isEditable: false,
        );
        when(
          () => repository.watchFollowedLists(
            viewerPubkey: any(named: 'viewerPubkey'),
          ),
        ).thenAnswer((_) => followedController.stream);
      });

      setUpAll(() => registerFallbackValue(_buildList()));

      tearDown(() => followedController.close());

      /// Pumps someone else's list as [viewerPubkey], and lets the follows
      /// land so the pill has something to say.
      Future<void> pumpDiscovered(
        WidgetTester tester, {
        String? viewerPubkey = _ownerPubkey,
        List<PeopleListSearchResult> followed = const [],
        Future<UserList?> Function()? resolve,
        bool enabled = true,
      }) async {
        final bloc = _MockPeopleListsBloc();
        whenListen(
          bloc,
          const Stream<PeopleListsState>.empty(),
          initialState: PeopleListsState(
            status: PeopleListsStatus.ready,
            ownerPubkey: viewerPubkey,
            enabled: enabled,
          ),
        );
        final videosRepository = _MockVideosRepository();
        when(
          () => videosRepository.getVideosByAuthors(
            authorPubkeys: any(named: 'authorPubkeys'),
          ),
        ).thenAnswer((_) async => const []);

        await tester.pumpWidget(
          testProviderScope(
            additionalOverrides: [
              publicPeopleListProvider(
                ownerPubkey: listOwner,
                listId: 'crew',
              ).overrideWith(
                (ref) => resolve?.call() ?? Future.value(discovered),
              ),
              peopleListsRepositoryProvider.overrideWithValue(repository),
              videosRepositoryProvider.overrideWithValue(videosRepository),
              videoEventsProvider.overrideWith(_EmptyVideoEventsPool.new),
            ],
            child: MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: BlocProvider<PeopleListsBloc>.value(
                value: bloc,
                child: const UserListPeopleScreen(
                  listId: 'crew',
                  ownerPubkey: listOwner,
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();
        durableFollow = followed.any(
          (list) => list.ownerPubkey == listOwner && list.list.id == 'crew',
        );
        followedController.add(followed);
        await tester.pump();
        await tester.pump();
      }

      for (final missingState in ['loading', 'absent', 'failed']) {
        testWidgets('unfollows an unresolved list while $missingState', (
          tester,
        ) async {
          when(
            () => repository.unfollowList(
              viewerPubkey: any(named: 'viewerPubkey'),
              ownerPubkey: any(named: 'ownerPubkey'),
              listId: any(named: 'listId'),
            ),
          ).thenAnswer((_) async => durableFollow = false);
          final pending = Completer<UserList?>();
          await pumpDiscovered(
            tester,
            followed: [
              PeopleListSearchResult(ownerPubkey: listOwner, list: discovered),
            ],
            resolve: () => switch (missingState) {
              'loading' => pending.future,
              'absent' => Future<UserList?>.value(),
              _ => Future<UserList?>.error(Exception('relay unavailable')),
            },
          );
          expect(find.text(l10n.listFollowingButton), findsOneWidget);
          await tester.tap(find.byType(FollowListButton));
          await tester.pump();
          await tester.pump();
          verify(
            () => repository.unfollowList(
              viewerPubkey: _ownerPubkey,
              ownerPubkey: listOwner,
              listId: 'crew',
            ),
          ).called(1);
          expect(find.byType(FollowListButton), findsNothing);
          verifyNever(
            () => repository.followList(
              viewerPubkey: any(named: 'viewerPubkey'),
              ownerPubkey: any(named: 'ownerPubkey'),
              list: any(named: 'list'),
            ),
          );
          if (missingState == 'loading') pending.complete();
        });
      }

      testWidgets('an unresolved list cannot create a new follow', (
        tester,
      ) async {
        await pumpDiscovered(tester, resolve: () async => null);
        expect(find.byType(FollowListButton), findsNothing);
      });

      testWidgets('disabled lists hide the durable follow control', (
        tester,
      ) async {
        await pumpDiscovered(
          tester,
          enabled: false,
          followed: [
            PeopleListSearchResult(ownerPubkey: listOwner, list: discovered),
          ],
          resolve: () async => null,
        );
        expect(find.byType(FollowListButton), findsNothing);
        verifyNever(
          () => repository.watchFollowedLists(
            viewerPubkey: any(named: 'viewerPubkey'),
          ),
        );
      });

      testWidgets("follows someone else's list for the signed-in viewer", (
        tester,
      ) async {
        when(
          () => repository.followList(
            viewerPubkey: any(named: 'viewerPubkey'),
            ownerPubkey: any(named: 'ownerPubkey'),
            list: any(named: 'list'),
          ),
        ).thenAnswer((_) async {
          durableFollow = true;
        });
        await pumpDiscovered(tester);

        expect(find.text(l10n.listFollowButton), findsOneWidget);

        await tester.tap(find.byType(FollowListButton));
        await tester.pump();

        verify(
          () => repository.followList(
            viewerPubkey: _ownerPubkey,
            ownerPubkey: listOwner,
            list: discovered,
          ),
        ).called(1);
        expect(find.text(l10n.listFollowingButton), findsOneWidget);
      });

      testWidgets('retries an unknown follow read without offering Follow', (
        tester,
      ) async {
        var unavailable = true;
        when(
          () => repository.isFollowingList(
            viewerPubkey: any(named: 'viewerPubkey'),
            ownerPubkey: any(named: 'ownerPubkey'),
            listId: any(named: 'listId'),
          ),
        ).thenAnswer((_) async {
          if (unavailable) throw Exception('durable storage unavailable');
          return true;
        });
        await pumpDiscovered(tester);
        expect(find.byType(FollowListButton), findsNothing);
        expect(
          find.byKey(const ValueKey('retry-people-list-follow')),
          findsOneWidget,
        );
        unavailable = false;
        await tester.tap(
          find.byKey(const ValueKey('retry-people-list-follow')),
        );
        await tester.pump();
        await tester.pump();
        expect(find.text(l10n.listFollowingButton), findsOneWidget);
        expect(
          find.byKey(const ValueKey('retry-people-list-follow')),
          findsNothing,
        );
      });

      testWidgets('unfollows a list that is already followed', (tester) async {
        when(
          () => repository.unfollowList(
            viewerPubkey: any(named: 'viewerPubkey'),
            ownerPubkey: any(named: 'ownerPubkey'),
            listId: any(named: 'listId'),
          ),
        ).thenAnswer((_) async {
          durableFollow = false;
        });
        await pumpDiscovered(
          tester,
          followed: [
            PeopleListSearchResult(ownerPubkey: listOwner, list: discovered),
          ],
        );

        expect(find.text(l10n.listFollowingButton), findsOneWidget);

        await tester.tap(find.byType(FollowListButton));
        await tester.pump();

        verify(
          () => repository.unfollowList(
            viewerPubkey: _ownerPubkey,
            ownerPubkey: listOwner,
            listId: 'crew',
          ),
        ).called(1);
        expect(find.text(l10n.listFollowButton), findsOneWidget);
      });

      testWidgets('says so when the follow cannot be saved', (tester) async {
        when(
          () => repository.followList(
            viewerPubkey: any(named: 'viewerPubkey'),
            ownerPubkey: any(named: 'ownerPubkey'),
            list: any(named: 'list'),
          ),
        ).thenThrow(Exception('disk full'));
        await pumpDiscovered(tester);

        await tester.tap(find.byType(FollowListButton));
        await tester.pump();
        await tester.pump();

        expect(
          find.text(l10n.discoverListsFailedToUpdateSubscription),
          findsOneWidget,
        );
        expect(find.text(l10n.listFollowButton), findsOneWidget);
      });

      testWidgets('shows Share after Follow on a public people list', (
        tester,
      ) async {
        await pumpDiscovered(tester);

        expect(findByTooltip(l10n.listShareAction), findsOneWidget);
        final followRight = tester
            .getTopRight(find.byType(FollowListButton))
            .dx;
        final shareLeft = tester.getTopLeft(find.byType(ShareListButton)).dx;
        expect(shareLeft, greaterThan(followRight));
      });

      testWidgets('offers no Follow to a signed-out viewer', (tester) async {
        await pumpDiscovered(tester, viewerPubkey: null);

        expect(find.text('Crew'), findsOneWidget);
        expect(find.byType(FollowListButton), findsNothing);
      });

      testWidgets("offers no Follow on the viewer's own list", (tester) async {
        final bloc = _MockPeopleListsBloc();
        final own = _buildList(id: 'mine', name: 'Mine');
        whenListen(
          bloc,
          const Stream<PeopleListsState>.empty(),
          initialState: PeopleListsState(
            status: PeopleListsStatus.ready,
            ownerPubkey: _ownerPubkey,
            lists: [own],
          ),
        );

        await tester.pumpWidget(
          testProviderScope(
            additionalOverrides: [
              peopleListsRepositoryProvider.overrideWithValue(repository),
            ],
            child: MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: BlocProvider<PeopleListsBloc>.value(
                value: bloc,
                child: UserListPeopleScreen(listId: own.id),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('Mine'), findsOneWidget);
        expect(find.byType(FollowListButton), findsNothing);
        expect(find.byType(ShareListButton), findsNothing);
        verifyNever(
          () => repository.watchFollowedLists(
            viewerPubkey: any(named: 'viewerPubkey'),
          ),
        );
      });
    });

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

    testWidgets("shows loading until the viewer's lists have arrived", (
      tester,
    ) async {
      // A cold deep link reaches the screen before the bloc has delivered
      // the viewer's lists; that is not "not found" yet.
      final bloc = _MockPeopleListsBloc();
      whenListen(
        bloc,
        const Stream<PeopleListsState>.empty(),
        initialState: const PeopleListsState(
          status: PeopleListsStatus.loading,
          ownerPubkey: _ownerPubkey,
          ownerReadStatus: PeopleListsOwnerReadStatus.pending,
        ),
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

      expect(find.byType(BrandedLoadingIndicator), findsOneWidget);
      expect(find.text(l10n.peopleListsListNotFoundTitle), findsNothing);
    });

    group('members preview', () {
      // Full-length 64-char pubkeys, never truncated.
      final kept = 'a' * 64;
      final blocked = 'b' * 64;
      late ContentBlocklistRepository blocklist;

      setUp(() {
        blocklist = ContentBlocklistRepository();
        addTearDown(blocklist.dispose);
      });

      Future<void> pumpOwnList(WidgetTester tester) async {
        final list = _buildList(id: 'crew', pubkeys: [blocked, kept]);
        final bloc = _MockPeopleListsBloc();
        whenListen(
          bloc,
          const Stream<PeopleListsState>.empty(),
          initialState: PeopleListsState(
            status: PeopleListsStatus.ready,
            ownerPubkey: _ownerPubkey,
            lists: [list],
          ),
        );
        await _pumpPeopleListScreen(
          tester,
          bloc: bloc,
          list: list,
          overrides: [
            contentBlocklistRepositoryProvider.overrideWithValue(blocklist),
          ],
        );
        await tester.pump();
      }

      List<String> previewPubkeys(WidgetTester tester) => tester
          .widget<PeopleListMembersPreview>(
            find.byType(PeopleListMembersPreview),
          )
          .pubkeys;

      testWidgets(
        "leaves a blocked member out of the viewer's own list's preview",
        (tester) async {
          await blocklist.blockUser(blocked);

          await pumpOwnList(tester);

          expect(previewPubkeys(tester), equals([kept]));
        },
      );

      testWidgets('drops a member blocked while the list is open', (
        tester,
      ) async {
        await pumpOwnList(tester);
        expect(previewPubkeys(tester), equals([blocked, kept]));

        await blocklist.blockUser(blocked);
        await tester.pump();

        expect(previewPubkeys(tester), equals([kept]));
      });

      testWidgets('offers no way into the roster when everyone is hidden', (
        tester,
      ) async {
        await blocklist.blockUsers([blocked, kept]);

        await pumpOwnList(tester);

        expect(find.byType(PeopleListMembersPreview), findsNothing);
        expect(find.text(l10n.peopleListsViewAllMembers), findsNothing);
      });
    });

    group('View all', () {
      Future<List<String>> openRoster(
        WidgetTester tester, {
        required PeopleListsBloc bloc,
        required String? ownerPubkey,
        List<Override> overrides = const [],
      }) async {
        final pushed = <String>[];
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => UserListPeopleScreen(
                listId: 'crew',
                ownerPubkey: ownerPubkey,
              ),
            ),
            GoRoute(
              path: '/people-lists/:listId/members',
              builder: (context, state) {
                pushed.add(state.uri.toString());
                return const Scaffold(body: Text('roster'));
              },
            ),
          ],
        );
        await tester.pumpWidget(
          testProviderScope(
            additionalOverrides: overrides,
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
        await tester.pump();
        await tester.pump();
        await tester.tap(find.text(l10n.peopleListsViewAllMembers));
        await tester.pumpAndSettle();
        return pushed;
      }

      testWidgets('carries the author of a discovered list to the roster', (
        tester,
      ) async {
        final bloc = _MockPeopleListsBloc();
        whenListen(
          bloc,
          const Stream<PeopleListsState>.empty(),
          initialState: const PeopleListsState(
            status: PeopleListsStatus.ready,
            ownerPubkey: _ownerPubkey,
          ),
        );
        final list = _buildList(
          id: 'crew',
          name: 'Crew',
          pubkeys: [_otherOwnerPubkey],
          isEditable: false,
        );

        final pushed = await openRoster(
          tester,
          bloc: bloc,
          ownerPubkey: _otherOwnerPubkey,
          overrides: [
            publicPeopleListProvider(
              ownerPubkey: _otherOwnerPubkey,
              listId: 'crew',
            ).overrideWith((ref) async => list),
          ],
        );

        expect(pushed, ['/people-lists/crew/members?owner=$_otherOwnerPubkey']);
      });

      testWidgets("opens the viewer's own roster without an author", (
        tester,
      ) async {
        final bloc = _MockPeopleListsBloc();
        whenListen(
          bloc,
          const Stream<PeopleListsState>.empty(),
          initialState: PeopleListsState(
            status: PeopleListsStatus.ready,
            ownerPubkey: _ownerPubkey,
            lists: [
              _buildList(
                id: 'crew',
                name: 'Crew',
                pubkeys: [_otherOwnerPubkey],
              ),
            ],
          ),
        );

        final pushed = await openRoster(
          tester,
          bloc: bloc,
          ownerPubkey: null,
        );

        expect(pushed, ['/people-lists/crew/members']);
      });
    });

    testWidgets('add people option opens the picker', (tester) async {
      final bloc = _MockPeopleListsBloc();
      final list = _buildList(id: 'punk-friends', name: 'Punk Friends');
      whenListen(
        bloc,
        const Stream<PeopleListsState>.empty(),
        initialState: PeopleListsState(
          status: PeopleListsStatus.ready,
          ownerPubkey: _ownerPubkey,
          lists: [list],
        ),
      );

      await _pumpPushedListRoute(tester, bloc: bloc, list: list);

      await tester.tap(find.byTooltip(l10n.peopleListsActionsTooltip));
      await tester.pumpAndSettle();
      await tester.tap(
        find.bySemanticsIdentifier('people_list_add_people_option'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Add people picker'), findsOneWidget);
    });

    testWidgets('hides the owner actions when current list is read-only', (
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

      expect(find.byTooltip(l10n.peopleListsActionsTooltip), findsNothing);
      expect(find.byTooltip(l10n.peopleListsAddPeopleTooltip), findsNothing);
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

      await tester.tap(find.byTooltip(l10n.peopleListsActionsTooltip));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.listDeleteAction));
      await tester.pumpAndSettle();

      expect(find.text(l10n.peopleListsDeleteConfirmTitle), findsOneWidget);
      expect(find.text(l10n.peopleListsDeleteConfirmBody), findsOneWidget);

      await tester.tap(find.text(l10n.commonCancel));
      await tester.pumpAndSettle();

      verifyNever(() => bloc.submit(any()));
      expect(find.text('Cancel Delete List'), findsOneWidget);
    });

    testWidgets(
      'delete confirmation confirm submits the delete and pops after success',
      (tester) async {
        final bloc = _MockPeopleListsBloc();
        final list = _buildList(
          id: 'confirm-delete-list',
          name: 'Confirm Delete List',
        );
        final result = Completer<PeopleListsOperationResult>();
        when(() => bloc.submit(any())).thenAnswer((_) => result.future);
        whenListen(
          bloc,
          const Stream<PeopleListsState>.empty(),
          initialState: PeopleListsState(
            status: PeopleListsStatus.ready,
            ownerPubkey: _ownerPubkey,
            lists: [list],
          ),
        );

        await _pumpPushedListRoute(tester, bloc: bloc, list: list);
        await _confirmDelete(tester, l10n);

        verify(
          () => bloc.submit(
            const PeopleListsDeleteRequested(listId: 'confirm-delete-list'),
          ),
        ).called(1);
        expect(find.text('Confirm Delete List'), findsOneWidget);

        result.complete(PeopleListsOperationResult.succeeded);
        await tester.pumpAndSettle();

        expect(find.text('Confirm Delete List'), findsNothing);
        expect(find.text('Open list'), findsOneWidget);
      },
    );

    testWidgets('pending deletion does not report the list as missing', (
      tester,
    ) async {
      final bloc = _MockPeopleListsBloc();
      final list = _buildList();
      final states = StreamController<PeopleListsState>();
      addTearDown(states.close);
      final result = Completer<PeopleListsOperationResult>();
      when(() => bloc.submit(any())).thenAnswer((_) => result.future);
      whenListen(
        bloc,
        states.stream,
        initialState: PeopleListsState(
          status: PeopleListsStatus.ready,
          ownerPubkey: _ownerPubkey,
          lists: [list],
        ),
      );
      await _pumpPushedListRoute(tester, bloc: bloc, list: list);
      await _confirmDelete(tester, l10n);
      states.add(
        const PeopleListsState(
          status: PeopleListsStatus.submitting,
          ownerPubkey: _ownerPubkey,
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text(l10n.peopleListsListNotFoundTitle), findsNothing);
      expect(find.byType(BrandedLoadingIndicator), findsOneWidget);

      states.add(
        PeopleListsState(
          status: PeopleListsStatus.failure,
          ownerPubkey: _ownerPubkey,
          lists: [list],
        ),
      );
      result.complete(PeopleListsOperationResult.failed);
      await tester.pumpAndSettle();
      expect(find.text(list.name), findsOneWidget);
      expect(find.text(l10n.peopleListsDeleteFailed), findsOneWidget);
      expect(find.text('Open list'), findsNothing);
    });

    // #6504: a teardown clears `pendingMutations` wholesale, which reads
    // exactly like the delete settling. The relay still has the list, so
    // announcing a delete and popping the route would be a lie. The bloc
    // reports the dropped request as `cancelled`.
    testWidgets('a delete dropped by a flag-off neither announces nor pops', (
      tester,
    ) async {
      final bloc = _MockPeopleListsBloc();
      final list = _buildList(id: 'flag-off-list', name: 'Flag Off List');
      final result = Completer<PeopleListsOperationResult>();
      when(() => bloc.submit(any())).thenAnswer((_) => result.future);
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

      // What `_onEnabledChanged` emits when the curated-lists flag goes off.
      controller.add(
        const PeopleListsState(ownerPubkey: _ownerPubkey, enabled: false),
      );
      result.complete(PeopleListsOperationResult.cancelled);
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
        final result = Completer<PeopleListsOperationResult>();
        when(() => bloc.submit(any())).thenAnswer((_) => result.future);
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

        // What `_onOwnerChanged` emits when another account signs in.
        controller.add(
          const PeopleListsState(
            status: PeopleListsStatus.loading,
            ownerPubkey: _otherOwnerPubkey,
          ),
        );
        result.complete(PeopleListsOperationResult.cancelled);
        // Two frames: one for the states to land, one for the confirmation
        // sheet to be gone. The spinner never settles, so no pumpAndSettle.
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // The new account's lists are still on their way: not "not found"
        // yet, and no announcement or pop either way.
        expect(find.byType(BrandedLoadingIndicator), findsOneWidget);
        expect(find.text(l10n.peopleListsListNotFoundTitle), findsNothing);

        controller.add(
          const PeopleListsState(
            status: PeopleListsStatus.ready,
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

    // A repository swap for the same owner keeps the owner and the lists, so
    // nothing in state tells the screen the delete was abandoned: only the
    // operation result does.
    testWidgets(
      'a delete dropped by a repository swap neither announces nor pops',
      (tester) async {
        final bloc = _MockPeopleListsBloc();
        final list = _buildList(id: 'swap-list', name: 'Swap List');
        final result = Completer<PeopleListsOperationResult>();
        when(() => bloc.submit(any())).thenAnswer((_) => result.future);
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

        // What `_onOwnerChanged` emits for `PeopleListsOwnerChanged.rewire()`.
        controller.add(
          PeopleListsState(
            status: PeopleListsStatus.ready,
            ownerPubkey: _ownerPubkey,
            lists: [list],
          ),
        );
        result.complete(PeopleListsOperationResult.cancelled);
        await tester.pumpAndSettle();

        expect(announcements, isEmpty);
        expect(find.text(l10n.peopleListsDeleteFailed), findsNothing);
        expect(find.text('Open list'), findsNothing);
        expect(find.text('Swap List'), findsOneWidget);
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
      when(
        () => bloc.submit(any()),
      ).thenAnswer((_) async => PeopleListsOperationResult.failed);
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

      await tester.tap(find.byTooltip(l10n.peopleListsActionsTooltip));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.listDeleteAction));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.commonDelete));
      await tester.pumpAndSettle();

      verify(
        () => bloc.submit(
          const PeopleListsDeleteRequested(listId: 'failed-delete-list'),
        ),
      ).called(1);
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
                  body: PeopleListMemberTile(
                    pubkey: memberPubkey,
                    listId: 'list-1',
                    canRemove: true,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        await tester.longPress(find.byType(PeopleListMemberTile));
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
        when(
          () => bloc.submit(
            const PeopleListsPubkeyRemoveRequested(
              listId: 'list-1',
              pubkey: memberPubkey,
            ),
          ),
        ).thenAnswer((_) async => PeopleListsOperationResult.succeeded);
        when(
          () => bloc.submit(
            const PeopleListsPubkeyAddRequested(
              listId: 'list-1',
              pubkey: memberPubkey,
            ),
          ),
        ).thenAnswer((_) async => PeopleListsOperationResult.succeeded);
        whenListen(
          bloc,
          const Stream<PeopleListsState>.empty(),
          initialState: const PeopleListsState(
            status: PeopleListsStatus.ready,
            ownerPubkey: _ownerPubkey,
          ),
        );

        await tester.pumpWidget(
          testProviderScope(
            child: MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: BlocProvider<PeopleListsBloc>.value(
                value: bloc,
                child: const Scaffold(
                  body: PeopleListMemberTile(
                    pubkey: memberPubkey,
                    listId: 'list-1',
                    canRemove: true,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        await tester.longPress(find.byType(PeopleListMemberTile));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Remove'));
        await tester.pumpAndSettle();

        verify(
          () => bloc.submit(
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
      when(
        () => bloc.submit(
          const PeopleListsPubkeyRemoveRequested(
            listId: 'list-1',
            pubkey: memberPubkey,
          ),
        ),
      ).thenAnswer((_) async => PeopleListsOperationResult.succeeded);
      when(
        () => bloc.submit(
          const PeopleListsPubkeyAddRequested(
            listId: 'list-1',
            pubkey: memberPubkey,
          ),
        ),
      ).thenAnswer((_) async => PeopleListsOperationResult.succeeded);
      whenListen(
        bloc,
        const Stream<PeopleListsState>.empty(),
        initialState: const PeopleListsState(
          status: PeopleListsStatus.ready,
          ownerPubkey: _ownerPubkey,
        ),
      );

      await tester.pumpWidget(
        testProviderScope(
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: BlocProvider<PeopleListsBloc>.value(
              value: bloc,
              child: const Scaffold(
                body: PeopleListMemberTile(
                  pubkey: memberPubkey,
                  listId: 'list-1',
                  canRemove: true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.longPress(find.byType(PeopleListMemberTile));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      verify(
        () => bloc.submit(
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
                body: PeopleListMemberTile(
                  pubkey: memberPubkey,
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

        await tester.longPress(find.byType(PeopleListMemberTile));
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
    registerFallbackValue(const PeopleListsDeleteRequested(listId: 'fallback'));
  });
}
