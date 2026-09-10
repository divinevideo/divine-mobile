// ABOUTME: Tests for the curated list detail screen: hero header, viewer
// ABOUTME: follow/share actions, owner actions sheet, and manage-posts mode.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/extensions/safe_pop_extension.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/list_providers.dart';
import 'package:openvine/screens/curated_list_feed_screen.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/widgets/composable_video_grid.dart';
import 'package:riverpod/misc.dart' show Override;

import '../helpers/go_router.dart';
import '../helpers/test_provider_overrides.dart';

class _MockCuratedListService extends Mock implements CuratedListService {}

class _TestCuratedListsState extends CuratedListsState {
  _TestCuratedListsState(this._mockService, this._list);

  final CuratedListService? _mockService;
  final CuratedList _list;

  @override
  CuratedListService? get service => _mockService;

  @override
  Future<List<CuratedList>> build() async => [_list];
}

VideoEvent _videoEvent({String id = 'video-one'}) => VideoEvent(
  id: id,
  pubkey: 'b' * 64,
  content: 'A cat video',
  title: 'A cat video',
  videoUrl: 'https://example.com/video.mp4',
  thumbnailUrl: 'https://example.com/thumb.jpg',
  duration: 5,
  createdAt: DateTime(2026).millisecondsSinceEpoch ~/ 1000,
  timestamp: DateTime(2026),
);

void main() {
  group(CuratedListFeedScreen, () {
    late _MockCuratedListService mockService;
    var isSubscribed = true;
    final l10n = lookupAppLocalizations(const Locale('en'));

    setUp(() {
      mockService = _MockCuratedListService();
      isSubscribed = true;

      when(
        () => mockService.isSubscribedToList('external-list'),
      ).thenAnswer((_) => isSubscribed);
      when(() => mockService.isOwnedList('external-list')).thenReturn(false);
      when(
        () => mockService.unsubscribeFromList('external-list'),
      ).thenAnswer((_) async => true);
      when(
        () => mockService.deleteOwnedList('owned-list'),
      ).thenAnswer((_) async => true);
    });

    Widget buildSubject({
      String listId = 'external-list',
      String listName = 'External List',
      String? authorPubkey = 'external-pubkey',
      List<String>? videoIds = const [],
      bool isPublic = true,
      MockGoRouter? goRouter,
      List<Override> extraOverrides = const [],
      bool overrideVideoEvents = true,
      List<VideoEvent> videoEvents = const [],
      CuratedList? discoveredList,
    }) {
      final list = CuratedList(
        id: listId,
        name: listName,
        videoEventIds: videoIds ?? const ['one', 'two', 'three'],
        pubkey: authorPubkey,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        isPublic: isPublic,
      );

      final screen = CuratedListFeedScreen(
        listId: listId,
        listName: listName,
        videoIds: videoIds,
        authorPubkey: authorPubkey,
        discoveredList: discoveredList,
      );

      final app = ProviderScope(
        overrides: [
          ...getStandardTestOverrides(),
          curatedListsStateProvider.overrideWith(
            () => _TestCuratedListsState(mockService, list),
          ),
          // Keep the real subscribed-list cache out of the tile chain, as
          // the grid's own tests do: its sync would hit unstubbed service
          // members the moment a tile renders.
          subscribedListVideoCacheProvider.overrideWithValue(null),
          // The hero header and grid live in the videos provider's data
          // branch, so resolve it with an empty grid instead of leaving the
          // screen on the loading spinner. Callers that override the same
          // providers themselves win via extraOverrides (last one applies).
          if (overrideVideoEvents) ...[
            if (videoIds != null)
              videoEventsByIdsProvider(
                videoIds,
              ).overrideWith((ref) => Stream.value(videoEvents)),
            curatedListVideoEventsProvider(
              listId,
            ).overrideWith((ref) => Stream.value(videoEvents)),
          ],
          ...extraOverrides,
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: goRouter == null
              ? screen
              : MockGoRouterProvider(goRouter: goRouter, child: screen),
        ),
      );

      return app;
    }

    void stubOwnedList({
      String listId = 'owned-list',
      String name = 'Owned List',
      String? pubkey = 'owned-pubkey',
      List<String> videoEventIds = const [],
      bool isPublic = true,
    }) {
      when(() => mockService.isOwnedList(listId)).thenReturn(true);
      when(() => mockService.isSubscribedToList(listId)).thenReturn(false);
      when(() => mockService.getListById(listId)).thenReturn(
        CuratedList(
          id: listId,
          name: name,
          pubkey: pubkey,
          videoEventIds: videoEventIds,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
          isPublic: isPublic,
        ),
      );
    }

    Future<void> openOwnerSheet(WidgetTester tester) async {
      await tester.tap(find.byTooltip(l10n.curatedListActionsTooltip));
      await tester.pumpAndSettle();
    }

    group('navigation', () {
      testWidgets('back button pops when the router can pop', (tester) async {
        final goRouter = MockGoRouter();
        when(goRouter.canPop).thenReturn(true);
        when(() => goRouter.pop<Object?>()).thenReturn(null);

        await tester.pumpWidget(buildSubject(goRouter: goRouter));
        await tester.pump();
        await tester.pump();

        await tester.tap(find.byTooltip('Back'));

        verify(() => goRouter.pop<Object?>()).called(1);
      });

      testWidgets(
        'back button falls back to the home feed when there is nothing to pop '
        '(cold-start deep link)',
        (tester) async {
          final goRouter = MockGoRouter();
          when(goRouter.canPop).thenReturn(false);
          when(() => goRouter.go(any())).thenReturn(null);

          await tester.pumpWidget(buildSubject(goRouter: goRouter));
          await tester.pump();
          await tester.pump();

          await tester.tap(find.byTooltip('Back'));

          verify(() => goRouter.go(defaultSafePopFallback)).called(1);
          verifyNever(() => goRouter.pop<Object?>());
        },
      );
    });

    group('hero header', () {
      testWidgets('shows title, count, and visibility for an owned list', (
        tester,
      ) async {
        stubOwnedList(
          name: 'Puppets',
          videoEventIds: const ['one', 'two', 'three'],
          isPublic: false,
        );

        await tester.pumpWidget(
          buildSubject(
            listId: 'owned-list',
            listName: 'Puppets',
            authorPubkey: null,
            videoIds: null,
            isPublic: false,
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('Puppets'), findsOneWidget);
        expect(find.text(l10n.listVideoCount(3)), findsOneWidget);
        expect(find.text(l10n.listVisibilityPrivate), findsOneWidget);
        expect(find.text(l10n.listByAuthorPrefix), findsNothing);
      });

      testWidgets("shows author attribution for someone else's list", (
        tester,
      ) async {
        when(() => mockService.isOwnedList('external-list')).thenReturn(false);
        when(() => mockService.getListById('external-list')).thenReturn(
          CuratedList(
            id: 'external-list',
            name: 'Subscribed List',
            pubkey:
                'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
                'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            videoEventIds: const ['one', 'two', 'three'],
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
        );

        await tester.pumpWidget(
          buildSubject(
            listName: 'Subscribed List',
            authorPubkey: null,
            videoIds: null,
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text(l10n.listByAuthorPrefix), findsOneWidget);
        expect(find.text(l10n.listVideoCount(3)), findsOneWidget);
        expect(find.text(l10n.listVisibilityPublic), findsNothing);
      });

      testWidgets('shows the list description when one exists', (tester) async {
        stubOwnedList(name: 'Puppets');
        when(() => mockService.getListById('owned-list')).thenReturn(
          CuratedList(
            id: 'owned-list',
            name: 'Puppets',
            pubkey: 'owned-pubkey',
            description: 'Hands in socks.',
            videoEventIds: const [],
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
        );

        await tester.pumpWidget(
          buildSubject(listId: 'owned-list', listName: 'Puppets'),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('Hands in socks.'), findsOneWidget);
      });
    });

    group('viewer actions', () {
      testWidgets('shows follow pill and share action for a public list', (
        tester,
      ) async {
        isSubscribed = false;
        when(() => mockService.getListById('external-list')).thenReturn(
          CuratedList(
            id: 'external-list',
            name: 'External List',
            pubkey: 'external-pubkey',
            videoEventIds: const [],
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
        );

        await tester.pumpWidget(buildSubject());
        await tester.pump();
        await tester.pump();

        expect(find.text(l10n.listFollowButton), findsOneWidget);
        expect(find.byTooltip(l10n.listShareAction), findsOneWidget);
        expect(find.byTooltip(l10n.curatedListActionsTooltip), findsNothing);

        // Share is the rightmost control in the row, after the follow pill.
        final followRight = tester
            .getTopRight(find.text(l10n.listFollowButton))
            .dx;
        final shareLeft = tester
            .getTopLeft(find.byTooltip(l10n.listShareAction))
            .dx;
        expect(shareLeft, greaterThan(followRight));
      });

      testWidgets('follow pill reads Following when subscribed', (
        tester,
      ) async {
        await tester.pumpWidget(buildSubject());
        await tester.pump();
        await tester.pump();

        expect(find.text(l10n.listFollowingButton), findsOneWidget);
        expect(find.text(l10n.listFollowButton), findsNothing);
      });

      testWidgets(
        'shows share and description for a deep-linked discovered list',
        (tester) async {
          // The local store has never seen the list; only the relay-resolved
          // record carries its shareability and description (#8453 review).
          final discovered = CuratedList(
            id: 'external-list',
            name: 'External List',
            pubkey: 'external-pubkey',
            description: 'From the relay.',
            videoEventIds: const [],
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          );

          await tester.pumpWidget(buildSubject(discoveredList: discovered));
          await tester.pump();
          await tester.pump();

          expect(find.byTooltip(l10n.listShareAction), findsOneWidget);
          expect(find.text('From the relay.'), findsOneWidget);
        },
      );

      testWidgets('keeps share hidden when the discovered list is private', (
        tester,
      ) async {
        final discovered = CuratedList(
          id: 'external-list',
          name: 'External List',
          pubkey: 'external-pubkey',
          isPublic: false,
          videoEventIds: const [],
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        );

        await tester.pumpWidget(buildSubject(discoveredList: discovered));
        await tester.pump();
        await tester.pump();

        expect(find.byTooltip(l10n.listShareAction), findsNothing);
      });

      testWidgets('subscribing caches the relay-resolved list', (
        tester,
      ) async {
        isSubscribed = false;
        final discovered = CuratedList(
          id: 'external-list',
          name: 'External List',
          pubkey: 'external-pubkey',
          description: 'From the relay.',
          videoEventIds: const [],
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        );
        when(
          () => mockService.subscribeToList('external-list', discovered),
        ).thenAnswer((_) async => true);

        await tester.pumpWidget(buildSubject(discoveredList: discovered));
        await tester.pump();
        await tester.pump();

        await tester.tap(find.text(l10n.listFollowButton));
        await tester.pumpAndSettle();

        // The full record, not the lossy synthetic fallback, is what the
        // cache serves from then on.
        verify(
          () => mockService.subscribeToList('external-list', discovered),
        ).called(1);
      });

      testWidgets('hides the share action for a private or unknown list', (
        tester,
      ) async {
        when(
          () => mockService.getListById('external-list'),
        ).thenReturn(null);

        await tester.pumpWidget(buildSubject());
        await tester.pump();
        await tester.pump();

        expect(find.byTooltip(l10n.listShareAction), findsNothing);
      });

      testWidgets('tapping the pill toggles the subscription', (tester) async {
        when(() => mockService.unsubscribeFromList('external-list')).thenAnswer(
          (_) async {
            isSubscribed = false;
            return true;
          },
        );

        await tester.pumpWidget(buildSubject());
        await tester.pump();
        await tester.pump();

        await tester.tap(find.text(l10n.listFollowingButton));
        await tester.pumpAndSettle();

        verify(
          () => mockService.unsubscribeFromList('external-list'),
        ).called(1);
        expect(find.text(l10n.listFollowButton), findsOneWidget);
      });

      testWidgets('viewer never sees the owner actions menu', (tester) async {
        isSubscribed = false;

        await tester.pumpWidget(buildSubject());
        await tester.pump();
        await tester.pump();

        expect(find.byTooltip(l10n.curatedListActionsTooltip), findsNothing);
      });
    });

    group('owner actions sheet', () {
      testWidgets('owner sees the menu and no follow pill', (tester) async {
        stubOwnedList();

        await tester.pumpWidget(
          buildSubject(listId: 'owned-list', listName: 'Owned List'),
        );
        await tester.pump();
        await tester.pump();

        expect(find.byTooltip(l10n.curatedListActionsTooltip), findsOneWidget);
        expect(find.text(l10n.listFollowButton), findsNothing);
        expect(find.text(l10n.listFollowingButton), findsNothing);
        final appBar = tester.widget<DiVineAppBar>(find.byType(DiVineAppBar));
        expect(appBar.customActions, isEmpty);
      });

      testWidgets('sheet offers edit, manage posts, share, and delete', (
        tester,
      ) async {
        stubOwnedList();

        await tester.pumpWidget(
          buildSubject(listId: 'owned-list', listName: 'Owned List'),
        );
        await tester.pump();
        await tester.pump();
        await openOwnerSheet(tester);

        expect(find.text(l10n.listEditInfoAction), findsOneWidget);
        expect(find.text(l10n.listManageVideosAction), findsOneWidget);
        expect(find.text(l10n.listShareAction), findsOneWidget);
        expect(find.text(l10n.listDeleteAction), findsOneWidget);
      });

      testWidgets('sheet tiles activate through the semantics owner', (
        tester,
      ) async {
        // The tiles exclude their child semantics, so the tap action must
        // live on the Semantics node itself — a pointer tap stays green on
        // the broken shape, only owner activation proves it (#7950).
        stubOwnedList();
        final semantics = tester.ensureSemantics();

        await tester.pumpWidget(
          buildSubject(
            listId: 'owned-list',
            listName: 'Owned List',
            videoEvents: [_videoEvent()],
          ),
        );
        await tester.pump();
        await openOwnerSheet(tester);

        tester.semantics.tap(
          find.semantics.byPredicate(
            (node) => node.identifier == 'list_manage_posts_option',
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(l10n.listRemoveVideosButton(0)), findsOneWidget);
        semantics.dispose();
      });

      testWidgets('disables manage posts while the list is empty', (
        tester,
      ) async {
        stubOwnedList();
        final semantics = tester.ensureSemantics();

        await tester.pumpWidget(
          buildSubject(listId: 'owned-list', listName: 'Owned List'),
        );
        await tester.pump();
        await openOwnerSheet(tester);

        final node = find.semantics
            .byPredicate(
              (node) => node.identifier == 'list_manage_posts_option',
            )
            .evaluate()
            .single;
        expect(node, isSemantics(hasEnabledState: true, isEnabled: false));

        await tester.tap(find.text(l10n.listManageVideosAction));
        await tester.pumpAndSettle();

        // The tap is inert: no manage mode, and the sheet stays up.
        expect(find.text(l10n.listRemoveVideosButton(0)), findsNothing);
        expect(find.text(l10n.listManageVideosAction), findsOneWidget);
        semantics.dispose();
      });

      testWidgets('disables manage posts when the videos fail to load', (
        tester,
      ) async {
        stubOwnedList();

        await tester.pumpWidget(
          buildSubject(
            listId: 'owned-list',
            listName: 'Owned List',
            videoIds: null,
            overrideVideoEvents: false,
            extraOverrides: [
              curatedListVideoEventsProvider('owned-list').overrideWith(
                (ref) =>
                    Stream<List<VideoEvent>>.error(Exception('relay failure')),
              ),
            ],
          ),
        );
        await tester.pump();
        await tester.pump();
        await openOwnerSheet(tester);

        await tester.tap(find.text(l10n.listManageVideosAction));
        await tester.pumpAndSettle();

        expect(find.text(l10n.listRemoveVideosButton(0)), findsNothing);
        expect(find.text(l10n.listManageVideosAction), findsOneWidget);
      });

      testWidgets('sheet hides share for a list without an author', (
        tester,
      ) async {
        stubOwnedList(pubkey: null);

        await tester.pumpWidget(
          buildSubject(listId: 'owned-list', listName: 'Owned List'),
        );
        await tester.pump();
        await tester.pump();
        await openOwnerSheet(tester);

        expect(find.text(l10n.listShareAction), findsNothing);
        expect(find.text(l10n.listEditInfoAction), findsOneWidget);
        expect(find.text(l10n.listDeleteAction), findsOneWidget);
      });

      testWidgets('delete confirms then calls service and pops', (
        tester,
      ) async {
        stubOwnedList();
        final goRouter = MockGoRouter();
        when(goRouter.canPop).thenReturn(true);
        when(() => goRouter.pop<Object?>()).thenReturn(null);

        await tester.pumpWidget(
          buildSubject(
            listId: 'owned-list',
            listName: 'Owned List',
            goRouter: goRouter,
          ),
        );
        await tester.pump();
        await tester.pump();

        await openOwnerSheet(tester);
        await tester.tap(find.text(l10n.listDeleteAction));
        await tester.pumpAndSettle();
        expect(find.text(l10n.curatedListDeleteConfirmTitle), findsOneWidget);

        await tester.tap(find.text(l10n.commonDelete));
        await tester.pumpAndSettle();

        verify(() => mockService.deleteOwnedList('owned-list')).called(1);
        verify(() => goRouter.pop<Object?>()).called(1);
        expect(find.text(l10n.curatedListDeletedSnack), findsOneWidget);
      });

      testWidgets('delete cancel dismisses without deleting', (tester) async {
        stubOwnedList();

        await tester.pumpWidget(
          buildSubject(listId: 'owned-list', listName: 'Owned List'),
        );
        await tester.pump();
        await tester.pump();

        await openOwnerSheet(tester);
        await tester.tap(find.text(l10n.listDeleteAction));
        await tester.pumpAndSettle();
        expect(find.text(l10n.curatedListDeleteConfirmTitle), findsOneWidget);

        await tester.tap(find.text(l10n.commonCancel));
        await tester.pumpAndSettle();

        verifyNever(() => mockService.deleteOwnedList('owned-list'));
        expect(find.text(l10n.curatedListDeleteConfirmTitle), findsNothing);
      });

      testWidgets(
        'delete confirmation buttons no-op once their route is torn down',
        (tester) async {
          stubOwnedList();

          await tester.pumpWidget(
            buildSubject(listId: 'owned-list', listName: 'Owned List'),
          );
          await tester.pump();
          await tester.pump();

          await openOwnerSheet(tester);
          await tester.tap(find.text(l10n.listDeleteAction));
          await tester.pumpAndSettle();

          VoidCallback actionFor(String label) => tester
              .widget<TextButton>(
                find.ancestor(
                  of: find.text(label),
                  matching: find.byType(TextButton),
                ),
              )
              .onPressed!;

          final cancel = actionFor(l10n.commonCancel);
          final confirm = actionFor(l10n.commonDelete);

          // Stands in for anything that drops the dialog's route while the
          // tap is in flight — a feature-flag flip re-inflating the app
          // shell, a redirect, a deep link.
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();

          expect(cancel, returnsNormally);
          expect(confirm, returnsNormally);
        },
      );
    });

    group('grid viewport', () {
      testWidgets('clips the scrolling grid region at the top corners', (
        tester,
      ) async {
        stubOwnedList();

        await tester.pumpWidget(
          buildSubject(listId: 'owned-list', listName: 'Owned List'),
        );
        await tester.pump();
        await tester.pump();

        final clip = tester.widget<ClipRRect>(
          find
              .ancestor(
                of: find.byType(ComposableVideoGrid),
                matching: find.byType(ClipRRect),
              )
              .first,
        );
        expect(
          clip.borderRadius,
          const BorderRadius.vertical(
            top: Radius.circular(VineTheme.shellInnerCornerRadius),
          ),
        );
      });
    });

    group('grid panel', () {
      testWidgets('feeds surface-container-high to the grid', (tester) async {
        stubOwnedList();

        await tester.pumpWidget(
          buildSubject(listId: 'owned-list', listName: 'Owned List'),
        );
        await tester.pump();
        await tester.pump();

        final grid = tester.widget<ComposableVideoGrid>(
          find.byType(ComposableVideoGrid),
        );
        expect(
          grid.backgroundColor,
          VineTheme.darkColors.surfaceContainerHigh,
        );
        // No top padding: the first row sits flush on the panel's rounded
        // edge instead of floating on a strip of panel color.
        expect(grid.padding, const EdgeInsets.only(bottom: 4));
      });
    });

    group('manage posts mode', () {
      Future<void> enterManageMode(WidgetTester tester) async {
        await openOwnerSheet(tester);
        await tester.tap(find.text(l10n.listManageVideosAction));
        await tester.pumpAndSettle();
      }

      testWidgets('entering shows the inline title and disabled remove bar', (
        tester,
      ) async {
        stubOwnedList();

        await tester.pumpWidget(
          buildSubject(
            listId: 'owned-list',
            listName: 'Owned List',
            videoEvents: [_videoEvent()],
          ),
        );
        await tester.pump();
        await tester.pump();
        await enterManageMode(tester);

        // Title moves from the hero into the app bar; with the hero hidden
        // the name renders exactly once.
        expect(find.text('Owned List'), findsOneWidget);
        expect(find.text(l10n.listRemoveVideosButton(0)), findsOneWidget);
        final button = tester.widget<DivineButton>(
          find.ancestor(
            of: find.text(l10n.listRemoveVideosButton(0)),
            matching: find.byType(DivineButton),
          ),
        );
        expect(button.onPressed, isNull);
        // Hero header is hidden while managing.
        expect(find.text(l10n.listVideoCount(0)), findsNothing);
        // The manage-mode grid keeps the design panel.
        final grid = tester.widget<ComposableVideoGrid>(
          find.byType(ComposableVideoGrid),
        );
        expect(
          grid.backgroundColor,
          VineTheme.darkColors.surfaceContainerHigh,
        );
      });

      testWidgets('removal refreshes the id provider so the tile disappears', (
        tester,
      ) async {
        stubOwnedList();
        when(
          () => mockService.removeVideoFromList('owned-list', any()),
        ).thenAnswer((_) async => true);

        final video = VideoEvent(
          id: 'a' * 64,
          pubkey: 'b' * 64,
          content: 'A cat video',
          title: 'A cat video',
          videoUrl: 'https://example.com/video.mp4',
          thumbnailUrl: 'https://example.com/thumb.jpg',
          duration: 5,
          createdAt: DateTime(2026).millisecondsSinceEpoch ~/ 1000,
          timestamp: DateTime(2026),
        );

        // Mirrors production's two cached layers: the video stream watches
        // the id-list provider. The id provider serves one id on the first
        // read and none after that, so the removed tile only disappears if
        // the removal listener invalidates the ID layer too — invalidating
        // just the stream re-runs it against the cached ids (the bug).
        var idReads = 0;
        await tester.pumpWidget(
          buildSubject(
            listId: 'owned-list',
            listName: 'Owned List',
            videoIds: null,
            overrideVideoEvents: false,
            extraOverrides: [
              curatedListVideosProvider('owned-list').overrideWith((ref) async {
                idReads++;
                return idReads == 1 ? [video.id] : const <String>[];
              }),
              curatedListVideoEventsProvider('owned-list').overrideWith((
                ref,
              ) async* {
                final ids = await ref.watch(
                  curatedListVideosProvider('owned-list').future,
                );
                yield [for (final _ in ids) video];
              }),
            ],
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('A cat video'), findsOneWidget);

        await enterManageMode(tester);
        await tester.tap(find.text('A cat video'));
        await tester.pump();
        await tester.tap(find.text(l10n.listRemoveVideosButton(1)));
        await tester.pumpAndSettle();

        verify(
          () => mockService.removeVideoFromList('owned-list', video.id),
        ).called(1);
        expect(find.text(l10n.listRemoveVideosSuccess(1)), findsOneWidget);
        expect(find.text('A cat video'), findsNothing);
        expect(find.text(l10n.curatedListEmptyTitle), findsOneWidget);
      });

      testWidgets(
        'removal refreshes the grid when navigated with frozen ids (feed chip)',
        (tester) async {
          stubOwnedList();
          when(
            () => mockService.removeVideoFromList('owned-list', any()),
          ).thenAnswer((_) async => true);

          final video = _videoEvent(id: 'a' * 64);

          // The feed chip and search rows navigate with videoIds frozen at
          // navigation time. The frozen-ids provider always serves the video,
          // so the tile only disappears if the screen leaves that path for
          // the invalidatable local-list providers (#8453 review).
          var idReads = 0;
          await tester.pumpWidget(
            buildSubject(
              listId: 'owned-list',
              listName: 'Owned List',
              videoIds: [video.id],
              overrideVideoEvents: false,
              extraOverrides: [
                videoEventsByIdsProvider(
                  [video.id],
                ).overrideWith((ref) => Stream.value([video])),
                curatedListVideosProvider('owned-list').overrideWith((
                  ref,
                ) async {
                  idReads++;
                  return idReads == 1 ? [video.id] : const <String>[];
                }),
                curatedListVideoEventsProvider('owned-list').overrideWith((
                  ref,
                ) async* {
                  final ids = await ref.watch(
                    curatedListVideosProvider('owned-list').future,
                  );
                  yield [for (final _ in ids) video];
                }),
              ],
            ),
          );
          await tester.pump();
          await tester.pump();

          expect(find.text('A cat video'), findsOneWidget);

          await enterManageMode(tester);
          await tester.tap(find.text('A cat video'));
          await tester.pump();
          await tester.tap(find.text(l10n.listRemoveVideosButton(1)));
          await tester.pumpAndSettle();

          expect(find.text('A cat video'), findsNothing);
          expect(find.text(l10n.curatedListEmptyTitle), findsOneWidget);
        },
      );

      testWidgets('back is held while a removal is in flight', (
        tester,
      ) async {
        stubOwnedList();
        // Completer-gated so the test holds the racer at the race instead of
        // depending on wall-clock timing.
        final removal = Completer<bool>();
        when(
          () => mockService.removeVideoFromList('owned-list', any()),
        ).thenAnswer((_) => removal.future);

        await tester.pumpWidget(
          buildSubject(
            listId: 'owned-list',
            listName: 'Owned List',
            videoEvents: [_videoEvent()],
          ),
        );
        await tester.pump();
        await tester.pump();
        await enterManageMode(tester);

        await tester.tap(find.text('A cat video'));
        await tester.pump();
        await tester.tap(find.text(l10n.listRemoveVideosButton(1)));
        await tester.pump();

        // Both exit routes are inert while the batch runs: the removals
        // would keep publishing after close() with their completion dropped.
        await tester.tap(find.byTooltip('Back'));
        await tester.pump();
        final popScope = tester.widget(
          find.byWidgetPredicate((widget) => widget is PopScope).first,
        ) as PopScope;
        popScope.onPopInvokedWithResult!(false, null);
        await tester.pump();
        expect(find.text('Owned List'), findsOneWidget);
        expect(find.byTooltip(l10n.curatedListActionsTooltip), findsNothing);

        removal.complete(true);
        await tester.pumpAndSettle();

        // The batch settled: completion ran (snackbar) and the mode exited.
        expect(find.text(l10n.listRemoveVideosSuccess(1)), findsOneWidget);
        expect(find.byTooltip(l10n.curatedListActionsTooltip), findsOneWidget);
      });

      testWidgets('back exits manage mode instead of popping the route', (
        tester,
      ) async {
        stubOwnedList();
        final goRouter = MockGoRouter();
        when(goRouter.canPop).thenReturn(true);
        when(() => goRouter.pop<Object?>()).thenReturn(null);

        await tester.pumpWidget(
          buildSubject(
            listId: 'owned-list',
            listName: 'Owned List',
            goRouter: goRouter,
            videoEvents: [_videoEvent()],
          ),
        );
        await tester.pump();
        await tester.pump();
        await enterManageMode(tester);

        await tester.tap(find.byTooltip('Back'));
        await tester.pumpAndSettle();

        verifyNever(() => goRouter.pop<Object?>());
        expect(find.text(l10n.listRemoveVideosButton(0)), findsNothing);
        expect(find.byTooltip(l10n.curatedListActionsTooltip), findsOneWidget);
      });
    });
  });
}
