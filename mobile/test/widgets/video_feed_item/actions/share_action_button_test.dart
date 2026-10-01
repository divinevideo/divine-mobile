// ABOUTME: Tests for ShareActionButton widget
// ABOUTME: Verifies share icon renders, share sheet opens with correct sections,
// ABOUTME: and standard action items display in the unified share sheet.

import 'dart:async';

import 'package:analytics/analytics.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/owner_video_actions/owner_video_actions_cubit.dart';
import 'package:openvine/blocs/share_sheet/share_sheet_bloc.dart';
import 'package:openvine/blocs/video_crosspost/video_crosspost_cubit.dart';
import 'package:openvine/blocs/video_crosspost/video_crosspost_state.dart';
import 'package:openvine/config/official_accounts.dart';
import 'package:openvine/features/oauth/app_oauth_support.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/auth_state.dart';
import 'package:openvine/providers/analytics_providers.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/crossposting_providers.dart';
import 'package:openvine/providers/list_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/inbox/widgets/moderation_identity.dart';
import 'package:openvine/screens/video_metadata/video_metadata_edit_screen.dart';
import 'package:openvine/services/crossposting_api_client.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/services/video_sharing_service.dart';
import 'package:openvine/widgets/crosspost_sheet.dart';
import 'package:openvine/widgets/select_list_sheet/select_list_sheet.dart';
import 'package:openvine/widgets/video_feed_item/actions/share_action_button.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:riverpod/misc.dart' show Override;
import 'package:visibility_detector/visibility_detector.dart';

import '../../../helpers/go_router.dart';
import '../../../helpers/test_provider_overrides.dart';

class _MockFollowRepository extends Mock implements FollowRepository {}

class _MockProfileRepository extends Mock implements ProfileRepository {}

class _MockVideoSharingService extends Mock implements VideoSharingService {}

class _MockCrosspostingApiClient extends Mock
    implements CrosspostingApiClient {}

class _MockCuratedListService extends Mock implements CuratedListService {}

/// Set before each test; read by [_FakeCuratedListsState].
_MockCuratedListService? _fakeListService;

/// Stands in for the real notifier, whose build would sync with relays.
class _FakeCuratedListsState extends CuratedListsState {
  @override
  CuratedListService? get service => _fakeListService;

  @override
  Future<List<CuratedList>> build() async => const [];
}

class _FakeVideoEvent extends Fake implements VideoEvent {}

class _RecordingAnalyticsSink extends NoOpAnalyticsEventSink {
  _RecordingAnalyticsSink({this.pending});

  final Future<void>? pending;
  final events = <({String name, Map<String, Object> parameters})>[];

  @override
  Future<void> logEvent({
    required String name,
    required Map<String, Object> parameters,
  }) async {
    events.add((name: name, parameters: parameters));
    await pending;
  }
}

void main() {
  setUp(() {
    final controller = VisibilityDetectorController.instance;
    final previousInterval = controller.updateInterval;
    controller.updateInterval = Duration.zero;
    addTearDown(() => controller.updateInterval = previousInterval);
  });
  setUpAll(() {
    registerFallbackValue(_FakeVideoEvent());
  });

  group(ShareActionButton, () {
    const ownPubkey =
        'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789';

    late VideoEvent testVideo;
    late _MockFollowRepository mockFollowRepository;
    late _MockProfileRepository mockProfileRepository;
    late _MockVideoSharingService mockVideoSharingService;

    setUp(() {
      mockFollowRepository = _MockFollowRepository();
      mockVideoSharingService = _MockVideoSharingService();
      when(() => mockFollowRepository.followingPubkeys).thenReturn([]);

      mockProfileRepository = _MockProfileRepository();
      when(
        () => mockProfileRepository.getCachedProfile(
          pubkey: any(named: 'pubkey'),
        ),
      ).thenAnswer((_) async => null);
      when(
        () => mockProfileRepository.fetchFreshProfile(
          pubkey: any(named: 'pubkey'),
        ),
      ).thenAnswer((_) async => null);
      when(
        () => mockProfileRepository.getCachedProfiles(
          pubkeys: any(named: 'pubkeys'),
        ),
      ).thenAnswer((_) async => <UserProfile>[]);
      when(
        () => mockProfileRepository.fetchBatchProfiles(
          pubkeys: any(named: 'pubkeys'),
        ),
      ).thenAnswer((_) async => <String, UserProfile>{});

      testVideo = VideoEvent(
        id: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        pubkey: ownPubkey,
        createdAt: 1757385263,
        content: 'Test video',
        timestamp: DateTime.fromMillisecondsSinceEpoch(1757385263 * 1000),
        videoUrl: 'https://example.com/video.mp4',
        title: 'Test Video',
      );
    });

    testWidgets('renders share icon button', (tester) async {
      await tester.pumpWidget(
        testMaterialApp(
          home: Scaffold(body: ShareActionButton(video: testVideo)),
        ),
      );

      expect(find.byType(ShareActionButton), findsOneWidget);
      expect(find.byType(GestureDetector), findsOneWidget);
    });

    testWidgets('renders $ShadowedDivineIcon with shareFatDuo icon', (
      tester,
    ) async {
      await tester.pumpWidget(
        testMaterialApp(
          home: Scaffold(body: ShareActionButton(video: testVideo)),
        ),
      );

      expect(
        tester.widget<ShadowedDivineIcon>(find.byType(ShadowedDivineIcon)).icon,
        equals(DivineIconName.shareFatDuo),
      );
    });

    testWidgets('has correct accessibility semantics', (tester) async {
      await tester.pumpWidget(
        testMaterialApp(
          home: Scaffold(body: ShareActionButton(video: testVideo)),
        ),
      );

      // Find Semantics widget with share button label
      final semanticsFinder = find.bySemanticsLabel('Share video');
      expect(semanticsFinder, findsOneWidget);
    });

    testWidgets('calls onInteracted before opening the share sheet', (
      tester,
    ) async {
      var interacted = false;
      final mockAuth = createMockAuthService();

      await tester.pumpWidget(
        testMaterialApp(
          home: Scaffold(
            body: ShareActionButton(
              video: testVideo,
              onInteracted: () => interacted = true,
            ),
          ),
          additionalOverrides: [
            videoSharingServiceProvider.overrideWith(
              (ref) => mockVideoSharingService,
            ),
          ],
          mockAuthService: mockAuth,
          mockProfileRepository: mockProfileRepository,
        ),
      );

      await tester.tap(find.byType(GestureDetector));
      await tester.pump();

      expect(interacted, isTrue);
    });

    group('share menu', () {
      testWidgets('shows Share with section', (tester) async {
        final mockAuth = createMockAuthService();

        await tester.pumpWidget(
          testMaterialApp(
            home: Scaffold(body: ShareActionButton(video: testVideo)),
            additionalOverrides: [
              videoSharingServiceProvider.overrideWith(
                (ref) => mockVideoSharingService,
              ),
            ],
            mockAuthService: mockAuth,
            mockProfileRepository: mockProfileRepository,
          ),
        );

        await tester.tap(find.byType(GestureDetector));
        await tester.pumpAndSettle();

        expect(find.text('Share with'), findsOneWidget);
      });

      testWidgets('shows Find people button', (tester) async {
        final mockAuth = createMockAuthService();

        await tester.pumpWidget(
          testMaterialApp(
            home: Scaffold(body: ShareActionButton(video: testVideo)),
            additionalOverrides: [
              videoSharingServiceProvider.overrideWith(
                (ref) => mockVideoSharingService,
              ),
            ],
            mockAuthService: mockAuth,
            mockProfileRepository: mockProfileRepository,
          ),
        );

        await tester.tap(find.byType(GestureDetector));
        await tester.pumpAndSettle();

        expect(find.text('Find\npeople'), findsOneWidget);
      });

      testWidgets('shows More actions section', (tester) async {
        final mockAuth = createMockAuthService();

        await tester.pumpWidget(
          testMaterialApp(
            home: Scaffold(body: ShareActionButton(video: testVideo)),
            additionalOverrides: [
              videoSharingServiceProvider.overrideWith(
                (ref) => mockVideoSharingService,
              ),
            ],
            mockAuthService: mockAuth,
            mockProfileRepository: mockProfileRepository,
          ),
        );

        await tester.tap(find.byType(GestureDetector));
        await tester.pumpAndSettle();

        expect(find.text('More actions'), findsOneWidget);
      });

      testWidgets(
        'keeps owner actions aligned with provider scope when auth changes',
        (tester) async {
          final mockAuth = createMockAuthService();
          late StateSetter rebuildHost;
          await tester.pumpWidget(
            testMaterialApp(
              home: StatefulBuilder(
                builder: (context, setState) {
                  rebuildHost = setState;
                  return Scaffold(body: ShareActionButton(video: testVideo));
                },
              ),
              additionalOverrides: [
                videoSharingServiceProvider.overrideWith(
                  (ref) => mockVideoSharingService,
                ),
              ],
              mockAuthService: mockAuth,
              mockProfileRepository: mockProfileRepository,
            ),
          );
          await tester.tap(find.byType(GestureDetector));
          await tester.pumpAndSettle();
          expect(find.text('Delete video'), findsNothing);

          when(() => mockAuth.currentPublicKeyHex).thenReturn(ownPubkey);
          rebuildHost(() {});
          await tester.pump();

          expect(tester.takeException(), isNull);
          expect(find.text('Delete video'), findsNothing);
        },
      );

      testWidgets('shows standard action items', (tester) async {
        final mockAuth = createMockAuthService();

        await tester.pumpWidget(
          testMaterialApp(
            home: Scaffold(body: ShareActionButton(video: testVideo)),
            additionalOverrides: [
              videoSharingServiceProvider.overrideWith(
                (ref) => mockVideoSharingService,
              ),
            ],
            mockAuthService: mockAuth,
            mockProfileRepository: mockProfileRepository,
          ),
        );

        await tester.tap(find.byType(GestureDetector));
        await tester.pumpAndSettle();

        expect(find.text('Save'), findsOneWidget);
        expect(find.text('Save Video'), findsOneWidget);
        expect(find.text('Copy'), findsOneWidget);
        expect(find.text('Share via'), findsOneWidget);
      });

      testWidgets('copy action responds when tapping the icon-label gap', (
        tester,
      ) async {
        final mockAuth = createMockAuthService();
        when(() => mockVideoSharingService.generateShareUrl(any()))
            .thenReturn('https://divine.video/v/test');

        await tester.pumpWidget(
          testMaterialApp(
            home: Scaffold(body: ShareActionButton(video: testVideo)),
            additionalOverrides: [
              videoSharingServiceProvider.overrideWith(
                (ref) => mockVideoSharingService,
              ),
            ],
            mockAuthService: mockAuth,
            mockProfileRepository: mockProfileRepository,
          ),
        );

        await tester.tap(find.byType(GestureDetector));
        await tester.pumpAndSettle();

        final copyIcon = find.byWidgetPredicate(
          (widget) =>
              widget is DivineIcon && widget.icon == DivineIconName.linkSimple,
        );
        final copyLabel = find.text('Copy');
        expect(copyIcon, findsOneWidget);
        expect(copyLabel, findsOneWidget);

        final iconRect = tester.getRect(copyIcon);
        final labelRect = tester.getRect(copyLabel);

        await tester.tapAt(
          Offset(iconRect.center.dx, (iconRect.bottom + labelRect.top) / 2),
        );
        await tester.pumpAndSettle();

        expect(
          find.text(
            lookupAppLocalizations(const Locale('en')).shareCopiedPostLink,
          ),
          findsOneWidget,
        );
      });

      testWidgets('shows own-video download actions for owned content', (
        tester,
      ) async {
        final mockAuth = createMockAuthService(
          authState: AuthState.authenticated,
          currentPublicKeyHex: ownPubkey,
        );

        await tester.pumpWidget(
          testMaterialApp(
            home: Scaffold(body: ShareActionButton(video: testVideo)),
            additionalOverrides: [
              videoSharingServiceProvider.overrideWith(
                (ref) => mockVideoSharingService,
              ),
            ],
            mockAuthService: mockAuth,
            mockProfileRepository: mockProfileRepository,
            mockFollowRepository: mockFollowRepository,
          ),
        );

        await tester.tap(find.byType(GestureDetector));
        await tester.pumpAndSettle();

        expect(find.text('Save to Gallery'), findsOneWidget);
        expect(find.text('Save with Watermark'), findsOneWidget);
      });

      group('owner actions', () {
        late AppLocalizations l10n;

        setUp(() {
          l10n = lookupAppLocalizations(const Locale('en'));
        });

        Future<void> pumpOwnerSheet(
          WidgetTester tester, {
          MockGoRouter? goRouter,
          List<Override>? additionalOverrides,
          bool canSign = true,
        }) async {
          final mockAuth = createMockAuthService(
            authState: AuthState.authenticated,
            currentPublicKeyHex: ownPubkey,
          );
          when(() => mockAuth.canPublishNostrWritesNow).thenReturn(canSign);
          final app = testMaterialApp(
            home: Scaffold(body: ShareActionButton(video: testVideo)),
            additionalOverrides: [
              videoSharingServiceProvider.overrideWith(
                (ref) => mockVideoSharingService,
              ),
              curatedListsStateProvider.overrideWith(
                _FakeCuratedListsState.new,
              ),
              myListsWithThumbnailsProvider.overrideWith(
                (ref) async => const <CuratedList>[],
              ),
              if (goRouter != null)
                goRouterProvider.overrideWithValue(goRouter),
              ...?additionalOverrides,
            ],
            mockAuthService: mockAuth,
            mockProfileRepository: mockProfileRepository,
            mockFollowRepository: mockFollowRepository,
          );

          await tester.pumpWidget(
            goRouter == null
                ? app
                : MockGoRouterProvider(goRouter: goRouter, child: app),
          );

          await tester.tap(find.byType(ShareActionButton));
          await tester.pumpAndSettle();
        }

        testWidgets('tapping Edit Video pushes the metadata editor', (
          tester,
        ) async {
          final goRouter = MockGoRouter();
          when(() => goRouter.push<void>(any(), extra: any(named: 'extra')))
              .thenAnswer((_) async {});

          await pumpOwnerSheet(tester, goRouter: goRouter);

          await tester.tap(find.text(l10n.shareMenuEditVideo));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));

          verify(
            () => goRouter.push<void>(
              VideoMetadataEditScreen.pathFor(testVideo.id),
              extra: testVideo,
            ),
          ).called(1);
        });

        testWidgets('tapping Add to List opens the list picker sheet', (
          tester,
        ) async {
          _fakeListService = _MockCuratedListService();
          when(() => _fakeListService!.myLists).thenReturn(const []);
          await pumpOwnerSheet(tester);

          await tester.tap(find.text(l10n.shareSheetAddToList));
          await tester.pumpAndSettle();

          expect(find.byType(SelectListSheetBody), findsOneWidget);
        });

        testWidgets('opening Share does not request crosspost signing', (
          tester,
        ) async {
          final client = _MockCrosspostingApiClient();
          when(client.getConnections).thenAnswer((_) async => const []);
          await pumpOwnerSheet(
            tester,
            additionalOverrides: [
              crosspostingApiClientProvider.overrideWithValue(client),
            ],
          );
          final cubit = tester
              .element(find.text('Share with'))
              .read<VideoCrosspostCubit>();
          expect(cubit.state.status, VideoCrosspostStatus.initial);
          verifyNever(client.getConnections);
        });

        testWidgets('dispose closes the owner and crosspost cubits', (
          tester,
        ) async {
          await pumpOwnerSheet(tester);

          final sheetContext = tester.element(find.text('Share with'));
          final ownerCubit = sheetContext.read<OwnerVideoActionsCubit>();
          final crosspostCubit = sheetContext.read<VideoCrosspostCubit>();
          expect(ownerCubit.isClosed, isFalse);
          expect(crosspostCubit.isClosed, isFalse);

          await tester.pumpWidget(const SizedBox());

          expect(ownerCubit.isClosed, isTrue);
          expect(crosspostCubit.isClosed, isTrue);
        });

        testWidgets('offers Crosspost when nothing is connected', (
          tester,
        ) async {
          await pumpOwnerSheet(tester);

          expect(find.text(l10n.shareSheetCrosspost), findsOneWidget);
        });

        testWidgets(
          'hides Crosspost for an identity the crossposter cannot serve',
          (tester) async {
            final sink = _RecordingAnalyticsSink();
            await pumpOwnerSheet(
              tester,
              canSign: false,
              additionalOverrides: [
                analyticsEventSinkProvider.overrideWithValue(sink),
              ],
            );

            expect(find.text(l10n.shareMenuEditVideo), findsOneWidget);
            expect(find.text(l10n.shareSheetCrosspost), findsNothing);
            expect(sink.events, isEmpty);
          },
        );

        testWidgets(
          'counts the Crosspost row only once when scrolled into view',
          (
            tester,
          ) async {
            tester.view.physicalSize = const Size(400, 900);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final sink = _RecordingAnalyticsSink();
            final client = _MockCrosspostingApiClient();
            await pumpOwnerSheet(
              tester,
              additionalOverrides: [
                appOAuthSupportProvider.overrideWith((ref) async => true),
                analyticsEventSinkProvider.overrideWithValue(sink),
                crosspostingApiClientProvider.overrideWithValue(client),
              ],
            );
            expect(sink.events, isEmpty);
            final actions = find.byType(ListView).last;
            await tester.drag(actions, const Offset(-500, 0));
            await tester.pumpAndSettle();
            expect(sink.events, hasLength(1));
            expect(sink.events.single.name, 'crosspost_cta_shown');
            expect(sink.events.single.parameters, {
              'surface': 'share_sheet',
              'cta': 'crosspost_row',
            });
            await tester.drag(actions, const Offset(500, 0));
            await tester.pumpAndSettle();
            await tester.drag(actions, const Offset(-500, 0));
            await tester.pumpAndSettle();
            expect(sink.events, hasLength(1));
            verifyNever(client.getConnections);
          },
        );

        testWidgets(
          'Crosspost waits for connections instead of routing to setup',
          (tester) async {
            final goRouter = MockGoRouter();
            when(() => goRouter.push<void>(any(), extra: any(named: 'extra')))
                .thenAnswer((_) async {});
            final client = _MockCrosspostingApiClient();
            final connections = Completer<List<CrosspostingConnection>>();
            when(client.getConnections).thenAnswer((_) => connections.future);
            final sink = _RecordingAnalyticsSink();

            await pumpOwnerSheet(
              tester,
              goRouter: goRouter,
              additionalOverrides: [
                crosspostingApiClientProvider.overrideWithValue(client),
                analyticsEventSinkProvider.overrideWithValue(sink),
              ],
            );

            await tester.tap(find.text(l10n.shareSheetCrosspost));
            await tester.pump();
            expect(sink.events.map((event) => event.name), [
              'crosspost_cta_shown',
              'crosspost_cta_tapped',
            ]);
            verifyNever(
              () => goRouter.push<void>(any(), extra: any(named: 'extra')),
            );

            connections.complete(const [
              CrosspostingConnection(
                id: 'connection-1',
                platform: CrosspostingPlatform.instagram,
                status: CrosspostingConnectionStatus.connected,
              ),
            ]);
            await tester.pumpAndSettle();

            expect(find.byType(CrosspostSheetView), findsOneWidget);
            verifyNever(
              () => goRouter.push<void>(any(), extra: any(named: 'extra')),
            );
            expect(sink.events.map((event) => event.name), [
              'crosspost_cta_shown',
              'crosspost_cta_tapped',
            ]);
            expect(
              sink.events.every(
                (event) => event.parameters['cta'] == 'crosspost_row',
              ),
              isTrue,
            );
          },
        );

        testWidgets('slow analytics does not block crosspost setup', (
          tester,
        ) async {
          final goRouter = MockGoRouter();
          when(() => goRouter.push<void>(any(), extra: any(named: 'extra')))
              .thenAnswer((_) async {});
          final pending = Completer<void>();
          final client = _MockCrosspostingApiClient();
          when(client.getConnections).thenAnswer((_) async => const []);
          await pumpOwnerSheet(
            tester,
            goRouter: goRouter,
            additionalOverrides: [
              appOAuthSupportProvider.overrideWith((ref) async => true),
              analyticsEventSinkProvider.overrideWithValue(
                _RecordingAnalyticsSink(pending: pending.future),
              ),
              crosspostingApiClientProvider.overrideWithValue(client),
            ],
          );
          await tester.tap(find.text(l10n.shareSheetCrosspost));
          await tester.pumpAndSettle();
          verify(() => goRouter.push<void>(RoutePaths.crosspostingSettings))
              .called(1);
          pending.complete();
          await tester.pump();
        });

        testWidgets(
          'a quick tap records exposure before visibility callbacks',
          (
            tester,
          ) async {
            final controller = VisibilityDetectorController.instance;
            controller.updateInterval = const Duration(minutes: 1);
            addTearDown(controller.notifyNow);
            final goRouter = MockGoRouter();
            when(() => goRouter.push<void>(any(), extra: any(named: 'extra')))
                .thenAnswer((_) async {});
            final sink = _RecordingAnalyticsSink();
            final client = _MockCrosspostingApiClient();
            when(client.getConnections).thenAnswer((_) async => const []);
            await pumpOwnerSheet(
              tester,
              goRouter: goRouter,
              additionalOverrides: [
                appOAuthSupportProvider.overrideWith((ref) async => true),
                analyticsEventSinkProvider.overrideWithValue(sink),
                crosspostingApiClientProvider.overrideWithValue(client),
              ],
            );
            expect(sink.events, isEmpty);
            await tester.tap(find.text(l10n.shareSheetCrosspost));
            await tester.pumpAndSettle();
            expect(sink.events.map((event) => event.name), [
              'crosspost_cta_shown',
              'crosspost_cta_tapped',
            ]);
            controller.updateInterval = Duration.zero;
            controller.notifyNow();
            await tester.pumpWidget(const SizedBox());
            await tester.pump();
          },
        );

        testWidgets('Crosspost routes to settings with no connections', (
          tester,
        ) async {
          final goRouter = MockGoRouter();
          when(() => goRouter.push<void>(any(), extra: any(named: 'extra')))
              .thenAnswer((_) async {});

          final sink = _RecordingAnalyticsSink();
          final client = _MockCrosspostingApiClient();
          when(client.getConnections).thenAnswer((_) async => const []);

          // Deliberately not pre-warmed: the async resolver must await the
          // support lookup and still route native on a cold read.
          await pumpOwnerSheet(
            tester,
            goRouter: goRouter,
            additionalOverrides: [
              appOAuthSupportProvider.overrideWith((ref) async => true),
              analyticsEventSinkProvider.overrideWithValue(sink),
              crosspostingApiClientProvider.overrideWithValue(client),
            ],
          );

          expect(sink.events, hasLength(1));
          expect(sink.events.single.name, 'crosspost_cta_shown');
          expect(
            sink.events.single.parameters,
            {'surface': 'share_sheet', 'cta': 'crosspost_row'},
          );
          verifyNever(client.getConnections);
          await tester.tap(find.text(l10n.shareSheetCrosspost));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
          final shownEvents = sink.events
              .where((event) => event.name == 'crosspost_cta_shown')
              .toList();
          expect(shownEvents, hasLength(1));
          expect(
            shownEvents.single.parameters,
            equals({'surface': 'share_sheet', 'cta': 'crosspost_row'}),
          );

          verify(() => goRouter.push<void>(RoutePaths.crosspostingSettings))
              .called(1);
          final tapEvents = sink.events
              .where((event) => event.name == 'crosspost_cta_tapped')
              .toList();
          expect(tapEvents, hasLength(1));
          expect(
            tapEvents.single.parameters,
            equals({'surface': 'share_sheet', 'cta': 'crosspost_row'}),
          );
        });

        testWidgets(
          'Crosspost records the row tap even when connections fail',
          (tester) async {
            final goRouter = MockGoRouter();
            when(() => goRouter.push<void>(any(), extra: any(named: 'extra')))
                .thenAnswer((_) async {});
            final sink = _RecordingAnalyticsSink();
            final client = _MockCrosspostingApiClient();
            when(client.getConnections)
                .thenThrow(const CrosspostingApiException('offline'));

            await pumpOwnerSheet(
              tester,
              goRouter: goRouter,
              additionalOverrides: [
                appOAuthSupportProvider.overrideWith((ref) async => true),
                analyticsEventSinkProvider.overrideWithValue(sink),
                crosspostingApiClientProvider.overrideWithValue(client),
              ],
            );

            await tester.tap(find.text(l10n.shareSheetCrosspost));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 100));

            verify(() => goRouter.push<void>(RoutePaths.crosspostingSettings))
                .called(1);
            expect(sink.events.map((event) => event.name), [
              'crosspost_cta_shown',
              'crosspost_cta_tapped',
            ]);
            expect(
              sink.events.every(
                (event) => event.parameters['cta'] == 'crosspost_row',
              ),
              isTrue,
            );
          },
        );
      });

      group('recipient selection', () {
        const alice = ShareableUser(
          pubkey:
              'fedcba9876543210fedcba9876543210'
              'fedcba9876543210fedcba9876543210',
          displayName: 'Alice',
        );
        const bob = ShareableUser(
          pubkey:
              '11111111111111111111111111111111'
              '11111111111111111111111111111111',
          displayName: 'Bob',
        );

        late AppLocalizations l10n;

        setUp(() {
          l10n = lookupAppLocalizations(const Locale('en'));
          when(() => mockVideoSharingService.recentlySharedWith)
              .thenReturn([alice, bob]);
        });

        // #8421: the "Share with" row is a DM send target — tapping a contact
        // hands it to ShareSheetBloc, which routes to DmRepository.sendMessage
        // — so it must name and picture its peer the way the inbox does.
        group('DM peer identity', () {
          const vanished = ShareableUser(
            pubkey:
                'b75b9a3131f4263add94ba20beb352a1'
                '1032684f2dac07a7e1af827c6f3c1505',
            displayName: 'Aeontropy',
            picture: 'https://example.invalid/aeontropy.png',
          );
          const moderation = ShareableUser(
            pubkey: kModerationPubkeyHex,
            displayName: 'moderation-bot-v2',
          );

          Future<void> pumpWithContact(
            WidgetTester tester,
            ShareableUser contact, {
            bool isVanished = false,
          }) async {
            when(() => mockVideoSharingService.recentlySharedWith)
                .thenReturn([contact]);

            await tester.pumpWidget(
              testMaterialApp(
                home: Scaffold(body: ShareActionButton(video: testVideo)),
                additionalOverrides: [
                  videoSharingServiceProvider.overrideWith(
                    (ref) => mockVideoSharingService,
                  ),
                  profileVanishedProvider(contact.pubkey)
                      .overrideWith((ref) => isVanished),
                ],
                mockAuthService: createMockAuthService(),
                mockProfileRepository: mockProfileRepository,
                mockFollowRepository: mockFollowRepository,
              ),
            );
            await tester.tap(find.byType(ShareActionButton));
            await tester.pumpAndSettle();
          }

          testWidgets('names a vanished peer "Deleted account"', (
            tester,
          ) async {
            await pumpWithContact(tester, vanished, isVanished: true);

            expect(find.text(l10n.profileDeletedAccountName), findsOneWidget);
            expect(find.text('Aeontropy'), findsNothing);
          });

          testWidgets('gives the moderation account its bundled wordmark and '
              'shared name', (tester) async {
            await pumpWithContact(tester, moderation);

            expect(find.byType(ModerationAvatar), findsOneWidget);
            expect(find.text(l10n.inboxSupportRowTitle), findsOneWidget);
            expect(find.text('moderation-bot-v2'), findsNothing);
          });

          testWidgets('announces the resolved name when a peer is selected', (
            tester,
          ) async {
            await pumpWithContact(tester, vanished, isVanished: true);

            await tester.tap(find.text(l10n.profileDeletedAccountName));
            await tester.pumpAndSettle();

            // The selection chip in the composer header names the recipient
            // the row named, not the kind-0 identity behind it.
            expect(find.text('Aeontropy'), findsNothing);
          });
        });

        Future<void> pumpOpenSheet(WidgetTester tester) async {
          final mockAuth = createMockAuthService();

          await tester.pumpWidget(
            testMaterialApp(
              home: Scaffold(body: ShareActionButton(video: testVideo)),
              additionalOverrides: [
                videoSharingServiceProvider.overrideWith(
                  (ref) => mockVideoSharingService,
                ),
              ],
              mockAuthService: mockAuth,
              mockProfileRepository: mockProfileRepository,
              mockFollowRepository: mockFollowRepository,
            ),
          );

          await tester.tap(find.byType(ShareActionButton));
          await tester.pumpAndSettle();
        }

        testWidgets(
          'tapping a contact selects it and swaps more actions for the '
          'message composer without sending',
          (tester) async {
            await pumpOpenSheet(tester);
            expect(find.text('More actions'), findsOneWidget);

            await tester.tap(find.text('Alice'));
            await tester.pumpAndSettle();

            expect(find.byType(TextField), findsOneWidget);
            expect(find.text('More actions'), findsNothing);
            verifyNever(
              () => mockVideoSharingService.shareVideoWithMultipleUsers(
                video: any(named: 'video'),
                recipientPubkeys: any(named: 'recipientPubkeys'),
                personalMessage: any(named: 'personalMessage'),
              ),
            );
          },
        );

        testWidgets('pending cache-miss rows are not selectable', (
          tester,
        ) async {
          const unknownPubkey =
              '22222222222222222222222222222222'
              '22222222222222222222222222222222';
          final hydration = Completer<Map<String, UserProfile>>();
          when(() => mockVideoSharingService.recentlySharedWith).thenReturn([]);
          when(() => mockFollowRepository.followingPubkeys)
              .thenReturn([unknownPubkey]);
          when(
            () => mockProfileRepository.fetchBatchProfiles(
              pubkeys: [unknownPubkey],
            ),
          ).thenAnswer((_) => hydration.future);

          await pumpOpenSheet(tester);

          expect(find.text('Username'), findsOneWidget);

          await tester.tap(find.text('Username'), warnIfMissed: false);
          await tester.pump();

          final blocContext = tester.element(find.text('Share with'));
          expect(
            blocContext.read<ShareSheetBloc>().state.selectedRecipients,
            isEmpty,
          );
          expect(find.byType(TextField), findsNothing);
        });

        testWidgets(
          'tapping the last selected contact again deselects, restores '
          'more actions, and drops the draft',
          (tester) async {
            await pumpOpenSheet(tester);

            await tester.tap(find.text('Alice'));
            await tester.pumpAndSettle();
            await tester.enterText(find.byType(TextField), 'draft text');

            await tester.tap(find.text('Alice'));
            await tester.pumpAndSettle();

            expect(find.byType(TextField), findsNothing);
            expect(find.text('More actions'), findsOneWidget);

            // Re-selecting shows an empty composer — the draft was dropped.
            await tester.tap(find.text('Alice'));
            await tester.pumpAndSettle();
            final field = tester.widget<TextField>(find.byType(TextField));
            expect(field.controller!.text, isEmpty);
          },
        );

        testWidgets(
          'tapping more contacts adds them to the selection and keeps '
          'the draft',
          (tester) async {
            await pumpOpenSheet(tester);

            await tester.tap(find.text('Alice'));
            await tester.pumpAndSettle();
            await tester.enterText(find.byType(TextField), 'draft text');

            await tester.tap(find.text('Bob'));
            await tester.pumpAndSettle();

            final blocContext = tester.element(find.text('Share with'));
            expect(
              blocContext.read<ShareSheetBloc>().state.selectedRecipients.map(
                (u) => u.pubkey,
              ),
              equals([alice.pubkey, bob.pubkey]),
            );
            final field = tester.widget<TextField>(find.byType(TextField));
            expect(field.controller!.text, equals('draft text'));
          },
        );

        testWidgets(
          'deselecting one of several recipients keeps the composer open',
          (tester) async {
            await pumpOpenSheet(tester);

            await tester.tap(find.text('Alice'));
            await tester.pumpAndSettle();
            await tester.tap(find.text('Bob'));
            await tester.pumpAndSettle();
            await tester.enterText(find.byType(TextField), 'draft text');

            await tester.tap(find.text('Alice'));
            await tester.pumpAndSettle();

            final blocContext = tester.element(find.text('Share with'));
            expect(
              blocContext.read<ShareSheetBloc>().state.selectedRecipients.map(
                (u) => u.pubkey,
              ),
              equals([bob.pubkey]),
            );
            final field = tester.widget<TextField>(find.byType(TextField));
            expect(field.controller!.text, equals('draft text'));
          },
        );

        testWidgets(
          'sending to multiple recipients shows the plural snackbar with '
          'no View chat action',
          (tester) async {
            when(
              () => mockVideoSharingService.shareVideoWithMultipleUsers(
                video: any(named: 'video'),
                recipientPubkeys: any(named: 'recipientPubkeys'),
                personalMessage: any(named: 'personalMessage'),
              ),
            ).thenAnswer(
              (_) async => {
                alice.pubkey: ShareResult.createSuccess('msg-1'),
                bob.pubkey: ShareResult.createSuccess('msg-2'),
              },
            );

            await pumpOpenSheet(tester);

            await tester.tap(find.text('Alice'));
            await tester.pumpAndSettle();
            await tester.tap(find.text('Bob'));
            await tester.pumpAndSettle();

            await tester.tap(
              find.byWidgetPredicate(
                (widget) =>
                    widget is DivineIcon &&
                    widget.icon == DivineIconName.arrowUp,
              ),
            );
            await tester.pumpAndSettle();

            expect(find.text('Share with'), findsNothing);
            expect(find.text(l10n.sharePostSharedWithCount(2)), findsOneWidget);
            expect(find.text(l10n.dmReelReplyViewChat), findsNothing);
          },
        );

        testWidgets(
          'send success dismisses the sheet and shows a snackbar with a '
          'View chat action',
          (tester) async {
            when(
              () => mockVideoSharingService.shareVideoWithMultipleUsers(
                video: any(named: 'video'),
                recipientPubkeys: any(named: 'recipientPubkeys'),
                personalMessage: any(named: 'personalMessage'),
              ),
            ).thenAnswer(
              (_) async => {
                alice.pubkey: ShareResult.createSuccess(
                  'msg-event-id',
                  conversationId: 'conversation-1',
                ),
              },
            );

            await pumpOpenSheet(tester);

            await tester.tap(find.text('Alice'));
            await tester.pumpAndSettle();

            await tester.tap(
              find.byWidgetPredicate(
                (widget) =>
                    widget is DivineIcon &&
                    widget.icon == DivineIconName.arrowUp,
              ),
            );
            await tester.pumpAndSettle();

            expect(find.text('Share with'), findsNothing);
            expect(
              find.text(l10n.sharePostSharedWith('Alice')),
              findsOneWidget,
            );
            expect(find.text(l10n.dmReelReplyViewChat), findsOneWidget);
          },
        );

        testWidgets(
          'send success without a conversation id shows no View chat action',
          (tester) async {
            when(
              () => mockVideoSharingService.shareVideoWithMultipleUsers(
                video: any(named: 'video'),
                recipientPubkeys: any(named: 'recipientPubkeys'),
                personalMessage: any(named: 'personalMessage'),
              ),
            ).thenAnswer(
              (_) async => {
                alice.pubkey: ShareResult.createSuccess('msg-event-id'),
              },
            );

            await pumpOpenSheet(tester);

            await tester.tap(find.text('Alice'));
            await tester.pumpAndSettle();

            await tester.tap(
              find.byWidgetPredicate(
                (widget) =>
                    widget is DivineIcon &&
                    widget.icon == DivineIconName.arrowUp,
              ),
            );
            await tester.pumpAndSettle();

            expect(
              find.text(l10n.sharePostSharedWith('Alice')),
              findsOneWidget,
            );
            expect(find.text(l10n.dmReelReplyViewChat), findsNothing);
          },
        );

        group('when not every recipient got the video', () {
          late List<Map<Object?, Object?>> announcements;

          setUp(() {
            announcements = [];
          });

          void captureAnnouncements(WidgetTester tester) {
            tester.binding.defaultBinaryMessenger
                .setMockDecodedMessageHandler<Object?>(
                  SystemChannels.accessibility,
                  (Object? message) async {
                    if (message is Map) announcements.add(message);
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
          }

          bool announced(String text) => announcements.any((message) {
            final data = message['data'];
            return message['type'] == 'announce' &&
                data is Map &&
                data['message'] == text;
          });

          bool snackbarIsError(WidgetTester tester) => tester
              .widget<DivineSnackbarContainer>(
                find.byType(DivineSnackbarContainer),
              )
              .error;

          void stubSend(Map<String, ShareResult> results) {
            when(
              () => mockVideoSharingService.shareVideoWithMultipleUsers(
                video: any(named: 'video'),
                recipientPubkeys: any(named: 'recipientPubkeys'),
                personalMessage: any(named: 'personalMessage'),
              ),
            ).thenAnswer((_) async => results);
          }

          Future<void> send(WidgetTester tester, List<String> names) async {
            await pumpOpenSheet(tester);
            for (final name in names) {
              await tester.tap(find.text(name));
              await tester.pumpAndSettle();
            }
            await tester.tap(
              find.byWidgetPredicate(
                (widget) =>
                    widget is DivineIcon &&
                    widget.icon == DivineIconName.arrowUp,
              ),
            );
            await tester.pumpAndSettle();
          }

          testWidgets(
            'names a refused recipient in an error snackbar instead of '
            'reporting the share as sent (#8672)',
            (tester) async {
              captureAnnouncements(tester);
              stubSend({
                alice.pubkey: ShareResult.createSuccess('msg-1'),
                bob.pubkey: ShareResult.failure(
                  'blocked: recipient not permitted by send policy',
                ),
              });

              await send(tester, ['Alice', 'Bob']);

              final message =
                  '${l10n.sharePostSharedWith('Alice')}\n'
                  '${l10n.shareCouldNotSendTo('Bob')}';
              expect(find.text('Share with'), findsNothing);
              expect(find.text(message), findsOneWidget);
              expect(
                tester
                    .widget<DivineSnackbarContainer>(
                      find.byType(DivineSnackbarContainer),
                    )
                    .error,
                isTrue,
              );
              expect(find.text(l10n.dmReelReplyViewChat), findsNothing);
              expect(announced(message), isTrue);
            },
          );

          testWidgets(
            'reports a lone queued share as still sending, not as failed',
            (tester) async {
              captureAnnouncements(tester);
              stubSend({
                alice.pubkey: ShareResult.retrying('no relay reached'),
              });

              await send(tester, ['Alice']);

              final message = l10n.shareStillTryingToSendTo('Alice');
              expect(find.text(message), findsOneWidget);
              expect(find.text(l10n.shareFailedToSend), findsNothing);
              expect(
                tester
                    .widget<DivineSnackbarContainer>(
                      find.byType(DivineSnackbarContainer),
                    )
                    .error,
                isFalse,
              );
              expect(announced(message), isTrue);
            },
          );

          testWidgets('counts recipients who share an outcome', (tester) async {
            stubSend({
              alice.pubkey: ShareResult.failure('refused'),
              bob.pubkey: ShareResult.failure('refused'),
            });

            await send(tester, ['Alice', 'Bob']);

            expect(find.text(l10n.shareCouldNotSendToCount(2)), findsOneWidget);
          });

          testWidgets(
            'uses the error style when the only recipient was refused',
            (tester) async {
              captureAnnouncements(tester);
              stubSend({
                alice.pubkey: ShareResult.failure(
                  'blocked: recipient not permitted by send policy',
                ),
              });

              await send(tester, ['Alice']);

              final message = l10n.shareCouldNotSendTo('Alice');
              expect(find.text(message), findsOneWidget);
              expect(find.text(l10n.shareFailedToSend), findsNothing);
              expect(snackbarIsError(tester), isTrue);
              expect(announced(message), isTrue);
            },
          );

          testWidgets(
            'names a sent and a still-sending recipient without the error '
            'style',
            (tester) async {
              captureAnnouncements(tester);
              stubSend({
                alice.pubkey: ShareResult.createSuccess('msg-1'),
                bob.pubkey: ShareResult.retrying('no relay reached'),
              });

              await send(tester, ['Alice', 'Bob']);

              final message =
                  '${l10n.sharePostSharedWith('Alice')}\n'
                  '${l10n.shareStillTryingToSendTo('Bob')}';
              expect(find.text(message), findsOneWidget);
              expect(snackbarIsError(tester), isFalse);
              expect(find.text(l10n.dmReelReplyViewChat), findsNothing);
              expect(announced(message), isTrue);
            },
          );

          testWidgets(
            'uses the error style when a still-sending share sits beside a '
            'refusal',
            (tester) async {
              stubSend({
                alice.pubkey: ShareResult.retrying('no relay reached'),
                bob.pubkey: ShareResult.failure('refused'),
              });

              await send(tester, ['Alice', 'Bob']);

              expect(
                find.text(
                  '${l10n.shareStillTryingToSendTo('Alice')}\n'
                  '${l10n.shareCouldNotSendTo('Bob')}',
                ),
                findsOneWidget,
              );
              expect(snackbarIsError(tester), isTrue);
            },
          );

          group('with three recipients', () {
            const carol = ShareableUser(
              pubkey:
                  '22222222222222222222222222222222'
                  '22222222222222222222222222222222',
              displayName: 'Carol',
            );

            setUp(() {
              when(() => mockVideoSharingService.recentlySharedWith)
                  .thenReturn([alice, bob, carol]);
            });

            testWidgets(
              'lists sent, still-sending and refused recipients in that order',
              (tester) async {
                stubSend({
                  alice.pubkey: ShareResult.createSuccess('msg-1'),
                  bob.pubkey: ShareResult.retrying('no relay reached'),
                  carol.pubkey: ShareResult.failure('refused'),
                });

                // Picked in reverse, so the order can only come from the
                // outcome.
                await send(tester, ['Carol', 'Bob', 'Alice']);

                expect(
                  find.text(
                    '${l10n.sharePostSharedWith('Alice')}\n'
                    '${l10n.shareStillTryingToSendTo('Bob')}\n'
                    '${l10n.shareCouldNotSendTo('Carol')}',
                  ),
                  findsOneWidget,
                );
                expect(snackbarIsError(tester), isTrue);
              },
            );

            testWidgets(
              'counts the recipients who got the video beside a refusal',
              (tester) async {
                stubSend({
                  alice.pubkey: ShareResult.createSuccess('msg-1'),
                  bob.pubkey: ShareResult.createSuccess('msg-2'),
                  carol.pubkey: ShareResult.failure('refused'),
                });

                await send(tester, ['Alice', 'Bob', 'Carol']);

                expect(
                  find.text(
                    '${l10n.sharePostSharedWithCount(2)}\n'
                    '${l10n.shareCouldNotSendTo('Carol')}',
                  ),
                  findsOneWidget,
                );
              },
            );

            testWidgets(
              'counts the recipients still being sent to beside a refusal',
              (tester) async {
                stubSend({
                  alice.pubkey: ShareResult.retrying('no relay reached'),
                  bob.pubkey: ShareResult.retrying('no relay reached'),
                  carol.pubkey: ShareResult.failure('refused'),
                });

                await send(tester, ['Alice', 'Bob', 'Carol']);

                expect(
                  find.text(
                    '${l10n.shareStillTryingToSendToCount(2)}\n'
                    '${l10n.shareCouldNotSendTo('Carol')}',
                  ),
                  findsOneWidget,
                );
              },
            );
          });
        });
      });

      testWidgets(
        'lifts message field above the keyboard when a recipient is selected',
        (tester) async {
          // Tall surface + dpr 1 so the short sheet stays bottom-anchored and
          // logical pixels equal physical pixels for the inset math.
          tester.view.devicePixelRatio = 1.0;
          tester.view.physicalSize = const Size(1200, 6000);
          addTearDown(tester.view.reset);

          final mockAuth = createMockAuthService();

          await tester.pumpWidget(
            testMaterialApp(
              home: Scaffold(body: ShareActionButton(video: testVideo)),
              additionalOverrides: [
                videoSharingServiceProvider.overrideWith(
                  (ref) => mockVideoSharingService,
                ),
              ],
              mockAuthService: mockAuth,
              mockProfileRepository: mockProfileRepository,
            ),
          );

          await tester.tap(find.byType(GestureDetector));
          await tester.pumpAndSettle();

          // Select a recipient so the message TextField is shown.
          final blocContext = tester.element(find.text('Share with'));
          blocContext.read<ShareSheetBloc>().add(
            const ShareSheetRecipientToggled(
              ShareableUser(
                pubkey:
                    'fedcba9876543210fedcba9876543210'
                    'fedcba9876543210fedcba9876543210',
                displayName: 'Alice',
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(TextField), findsOneWidget);

          // Simulate the keyboard opening.
          const keyboardHeight = 320.0;
          tester.view.viewInsets = const FakeViewPadding(
            bottom: keyboardHeight,
          );
          await tester.pumpAndSettle();

          final logicalHeight =
              tester.view.physicalSize.height / tester.view.devicePixelRatio;
          final keyboardTop = logicalHeight - keyboardHeight;

          // The field must sit above the keyboard, not behind it.
          expect(
            tester.getBottomLeft(find.byType(TextField)).dy,
            lessThanOrEqualTo(keyboardTop),
          );
        },
      );
    });
  });
}
