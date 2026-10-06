import 'dart:async';

import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/models/live/live_chat_message.dart';
import 'package:openvine/models/live/live_presence.dart';
import 'package:openvine/models/live/live_role.dart';
import 'package:openvine/models/live/live_room.dart';
import 'package:openvine/models/live/live_room_token.dart';
import 'package:openvine/models/live/live_session.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/live_providers.dart';
import 'package:openvine/repositories/live_chat_repository.dart';
import 'package:openvine/repositories/live_repository.dart';
import 'package:openvine/screens/live/live_discovery_page.dart';
import 'package:openvine/screens/live/live_room_page.dart';
import 'package:openvine/screens/live/live_route_data.dart';
import 'package:openvine/services/content_moderation_types.dart';
import 'package:openvine/services/content_reporting_service.dart';
import 'package:openvine/services/live_api_service.dart';
import 'package:openvine/services/livekit_room_service.dart';
import 'package:openvine/services/native_camera_permission_service.dart';
import 'package:permissions_service/permissions_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockLiveRepository extends Mock implements LiveRepository {}

class _MockLiveChatRepository extends Mock implements LiveChatRepository {}

class _MockLiveApiService extends Mock implements LiveApiService {}

class _MockLiveKitRoomService extends Mock implements LiveKitRoomService {}

class _MockPermissionsService extends Mock implements PermissionsService {}

class _MockContentReportingService extends Mock
    implements ContentReportingService {}

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LiveRoomPage', () {
    late _MockLiveRepository mockLiveRepository;
    late _MockLiveChatRepository mockLiveChatRepository;
    late _MockLiveApiService mockLiveApiService;
    late _MockLiveKitRoomService mockLiveKitRoomService;
    late _MockContentReportingService mockContentReportingService;
    late _MockContentBlocklistRepository mockContentBlocklistRepository;

    const room = LiveRoom(
      id: 'room-123',
      hostPubkey: 'host-pubkey',
      title: 'Signal from the stage',
      summary: 'A live room for creators and the people following along.',
      imageUrl: null,
      relays: <String>[],
      visibility: LiveRoomVisibility.public,
    );
    final session = LiveSession(
      id: 'session-123',
      roomId: 'room-123',
      status: LiveSessionStatus.live,
      startedAt: DateTime.utc(2026, 4, 6, 8),
      endedAt: null,
      speakerPubkeys: const <String>['host-pubkey', 'speaker-pubkey'],
      audienceCount: 64,
    );
    const sessionAddress = '30313:host-pubkey:session-123';
    const audienceToken = LiveRoomToken(
      token: 'audience-token',
      serverUrl: 'wss://live.example.com',
      roomName: 'room-123',
      participantIdentity: 'audience-pubkey',
      canPublish: false,
    );
    const hostToken = LiveRoomToken(
      token: 'host-token',
      serverUrl: 'wss://live.example.com',
      roomName: 'room-123',
      participantIdentity: 'host-pubkey',
      canPublish: true,
    );
    const speakerToken = LiveRoomToken(
      token: 'speaker-token',
      serverUrl: 'wss://live.example.com',
      roomName: 'room-123',
      participantIdentity: 'speaker-pubkey',
      canPublish: true,
    );
    final hostPresence = LivePresence(
      sessionId: session.id,
      pubkey: 'host-pubkey',
      role: LiveRole.host,
      handRaised: false,
      updatedAt: DateTime.utc(2026, 4, 6, 8, 1),
    );
    final raisedHandPresence = LivePresence(
      sessionId: session.id,
      pubkey: 'audience-pubkey',
      role: LiveRole.audience,
      handRaised: true,
      updatedAt: DateTime.utc(2026, 4, 6, 8, 2),
    );
    setUpAll(() {
      registerFallbackValue(room);
      registerFallbackValue(LiveRole.audience);
    });

    setUp(() {
      mockLiveRepository = _MockLiveRepository();
      mockLiveChatRepository = _MockLiveChatRepository();
      mockLiveApiService = _MockLiveApiService();
      mockLiveKitRoomService = _MockLiveKitRoomService();
      mockContentReportingService = _MockContentReportingService();
      mockContentBlocklistRepository = _MockContentBlocklistRepository();

      when(() => mockLiveKitRoomService.watchState()).thenAnswer(
        (_) => Stream<LiveMediaState>.value(const LiveMediaState()),
      );
      when(
        () => mockLiveRepository.watchSessions(roomAddress: room.address),
      ).thenAnswer(
        (_) => Stream<List<LiveSession>>.value(<LiveSession>[session]),
      );
      when(
        () => mockLiveRepository.watchPresence(sessionAddress: sessionAddress),
      ).thenAnswer(
        (_) => Stream<List<LivePresence>>.value(<LivePresence>[
          hostPresence,
          raisedHandPresence,
        ]),
      );
      when(
        () => mockLiveChatRepository.watchChatMessages(
          sessionAddress: sessionAddress,
        ),
      ).thenAnswer(
        (_) => Stream<List<LiveChatMessage>>.value(
          <LiveChatMessage>[
            LiveChatMessage(
              id: 'chat-1',
              sessionAddress: sessionAddress,
              pubkey: 'audience-pubkey',
              content: 'This room is live.',
              createdAt: DateTime.utc(2026, 4, 6, 8, 1),
            ),
          ],
        ),
      );
      when(() => mockLiveKitRoomService.connect(audienceToken)).thenAnswer(
        (_) async {},
      );
      when(() => mockLiveKitRoomService.connect(hostToken)).thenAnswer(
        (_) async {},
      );
      when(() => mockLiveKitRoomService.connect(speakerToken)).thenAnswer(
        (_) async {},
      );
      when(() => mockLiveKitRoomService.disconnect()).thenAnswer((_) async {});
      when(
        () => mockLiveKitRoomService.publishLocalTracks(
          cameraEnabled: any(named: 'cameraEnabled'),
          microphoneEnabled: any(named: 'microphoneEnabled'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => mockContentReportingService.reportUser(
          userPubkey: 'audience-pubkey',
          reason: ContentFilterReason.other,
          details: 'Reported from live room moderation',
          relatedEventIds: const <String>[],
        ),
      ).thenAnswer(
        (_) async => ReportResult.createSuccess(
          'report-id',
          delivery: ReportDelivery.reached,
        ),
      );
      when(
        () => mockContentBlocklistRepository.blockUser(
          'audience-pubkey',
          ourPubkey: 'host-pubkey',
        ),
      ).thenAnswer((_) async => true);
      when(
        () => mockLiveRepository.publishPresence(
          sessionAddress: any(named: 'sessionAddress'),
          role: any(named: 'role'),
          handRaised: any(named: 'handRaised'),
        ),
      ).thenAnswer((_) async => null);
      when(
        () => mockLiveRepository.publishRoom(any()),
      ).thenAnswer((_) async => null);
      when(
        () => mockLiveApiService.fetchJoinToken(
          roomId: room.id,
          role: LiveRole.audience,
        ),
      ).thenAnswer((_) async => audienceToken);
      when(
        () => mockLiveApiService.fetchJoinToken(
          roomId: room.id,
          role: LiveRole.host,
        ),
      ).thenAnswer((_) async => hostToken);
      when(
        () => mockLiveApiService.fetchJoinToken(
          roomId: room.id,
          role: LiveRole.speaker,
        ),
      ).thenAnswer((_) async => speakerToken);
    });

    testWidgets('host controls appear for hosts, not audience members', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final sharedPreferences = await SharedPreferences.getInstance();
      final hostAuth = createMockAuthService();
      when(() => hostAuth.currentPublicKeyHex).thenReturn('host-pubkey');

      await tester.pumpWidget(
        testMaterialApp(
          mockSharedPreferences: sharedPreferences,
          mockAuthService: hostAuth,
          additionalOverrides: [
            liveRepositoryProvider.overrideWithValue(mockLiveRepository),
            liveChatRepositoryProvider.overrideWithValue(
              mockLiveChatRepository,
            ),
            liveApiServiceProvider.overrideWithValue(mockLiveApiService),
            liveKitRoomServiceProvider.overrideWithValue(
              mockLiveKitRoomService,
            ),
            contentReportingServiceProvider.overrideWith(
              (ref) async => mockContentReportingService,
            ),
            contentBlocklistRepositoryProvider.overrideWithValue(
              mockContentBlocklistRepository,
            ),
          ],
          home: LiveRoomPage(
            roomId: room.id,
            sessionId: session.id,
            initialRoom: room,
            initialSession: session,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Host controls'), findsOneWidget);
      expect(find.text('Turn mic on'), findsOneWidget);
      expect(find.text('Turn camera on'), findsOneWidget);
      expect(find.text('Flip camera'), findsOneWidget);
      expect(find.text('Audio only'), findsOneWidget);
      expect(find.text('Chat'), findsOneWidget);
      expect(find.text('Zap'), findsNothing);

      await tester.scrollUntilVisible(
        find.text('Host controls'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Host controls'));
      await tester.pumpAndSettle();

      expect(find.text('Room details'), findsOneWidget);
      expect(find.text('Update title/status'), findsOneWidget);
      expect(find.text('End session'), findsOneWidget);
      expect(find.text('Manage participants'), findsOneWidget);

      await tester.ensureVisible(find.text('Manage participants'));
      await tester.tap(find.text('Manage participants'));
      await tester.pumpAndSettle();

      expect(find.text('Raised hands'), findsOneWidget);
      expect(find.text('Active speakers'), findsOneWidget);
      expect(find.text('Audience'), findsWidgets);
      expect(find.text('Approve'), findsOneWidget);
      expect(find.text('Deny'), findsOneWidget);
      expect(find.text('Mute'), findsNothing);
      expect(find.text('Hide from my view'), findsOneWidget);
      expect(find.text('Hide chat for me'), findsWidgets);
      expect(find.text('Report user'), findsWidgets);
      expect(find.text('Block user'), findsWidgets);
    });

    testWidgets(
      'camera enable on macOS explicitly requests native permission before publishing',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        final nativeMethodCalls = <MethodCall>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              MethodChannelNativeCameraPermissionService.channel,
              (methodCall) async {
                nativeMethodCalls.add(methodCall);
                if (methodCall.method == 'getAuthorizationStatus') {
                  return 'notDetermined';
                }
                if (methodCall.method == 'requestPermission') {
                  return true;
                }
                return null;
              },
            );
        addTearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(
                MethodChannelNativeCameraPermissionService.channel,
                null,
              );
        });

        final mockPermissionsService = _MockPermissionsService();
        when(
          mockPermissionsService.checkCameraStatus,
        ).thenAnswer((_) async => PermissionStatus.canRequest);
        when(
          mockPermissionsService.requestCameraPermission,
        ).thenAnswer((_) async => PermissionStatus.requiresSettings);
        when(
          mockPermissionsService.checkMicrophoneStatus,
        ).thenAnswer((_) async => PermissionStatus.granted);
        when(
          mockPermissionsService.requestMicrophonePermission,
        ).thenAnswer((_) async => PermissionStatus.granted);
        when(
          mockPermissionsService.openAppSettings,
        ).thenAnswer((_) async => true);
        when(
          mockPermissionsService.checkGalleryStatus,
        ).thenAnswer((_) async => PermissionStatus.granted);
        when(
          mockPermissionsService.requestGalleryPermission,
        ).thenAnswer((_) async => PermissionStatus.granted);
        when(
          () => mockLiveKitRoomService.setCameraEnabled(any()),
        ).thenAnswer((_) async {});

        SharedPreferences.setMockInitialValues(<String, Object>{});
        final sharedPreferences = await SharedPreferences.getInstance();
        final hostAuth = createMockAuthService();
        when(() => hostAuth.currentPublicKeyHex).thenReturn('host-pubkey');

        await tester.pumpWidget(
          testMaterialApp(
            mockSharedPreferences: sharedPreferences,
            mockAuthService: hostAuth,
            additionalOverrides: [
              liveRepositoryProvider.overrideWithValue(mockLiveRepository),
              liveChatRepositoryProvider.overrideWithValue(
                mockLiveChatRepository,
              ),
              liveApiServiceProvider.overrideWithValue(mockLiveApiService),
              liveKitRoomServiceProvider.overrideWithValue(
                mockLiveKitRoomService,
              ),
              permissionsServiceProvider.overrideWithValue(
                mockPermissionsService,
              ),
            ],
            home: LiveRoomPage(
              roomId: room.id,
              sessionId: session.id,
              initialRoom: room,
              initialSession: session,
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        await tester.scrollUntilVisible(
          find.text('Turn camera on'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('Turn camera on'));
        await tester.pump();
        await tester.pump();

        verify(() => mockLiveKitRoomService.setCameraEnabled(true)).called(1);
        verifyNever(mockPermissionsService.checkCameraStatus);
        expect(
          nativeMethodCalls.map((call) => call.method),
          containsAllInOrder(<String>[
            'getAuthorizationStatus',
            'requestPermission',
          ]),
        );
        expect(
          find.text('Camera access is blocked. Allow it in system settings.'),
          findsNothing,
        );

        debugDefaultTargetPlatformOverride = null;
      },
    );

    testWidgets(
      'chat starts for the current session even when the room is ready immediately',
      (tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final sharedPreferences = await SharedPreferences.getInstance();
        final audienceAuth = createMockAuthService();
        when(() => audienceAuth.currentPublicKeyHex).thenReturn(
          'audience-pubkey',
        );

        await tester.pumpWidget(
          testMaterialApp(
            mockSharedPreferences: sharedPreferences,
            mockAuthService: audienceAuth,
            additionalOverrides: [
              liveRepositoryProvider.overrideWithValue(mockLiveRepository),
              liveChatRepositoryProvider.overrideWithValue(
                mockLiveChatRepository,
              ),
              liveApiServiceProvider.overrideWithValue(mockLiveApiService),
              liveKitRoomServiceProvider.overrideWithValue(
                mockLiveKitRoomService,
              ),
            ],
            home: LiveRoomPage(
              roomId: room.id,
              sessionId: session.id,
              initialRoom: room,
              initialSession: session,
            ),
          ),
        );
        await tester.pump();
        await tester.pump();
        await tester.pump();
        await tester.pump();

        await _pumpUntil(
          tester,
          () => tester.any(find.text('This room is live.')),
        );

        expect(find.text('Chat'), findsOneWidget);
        expect(find.text('This room is live.'), findsOneWidget);

        verify(
          () => mockLiveChatRepository.watchChatMessages(
            sessionAddress: sessionAddress,
          ),
        ).called(1);
      },
    );

    testWidgets(
      'host console can report, block, and mute live chat participants',
      (tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final sharedPreferences = await SharedPreferences.getInstance();
        final hostAuth = createMockAuthService();
        when(() => hostAuth.currentPublicKeyHex).thenReturn('host-pubkey');

        await tester.pumpWidget(
          testMaterialApp(
            mockSharedPreferences: sharedPreferences,
            mockAuthService: hostAuth,
            additionalOverrides: [
              liveRepositoryProvider.overrideWithValue(mockLiveRepository),
              liveChatRepositoryProvider.overrideWithValue(
                mockLiveChatRepository,
              ),
              liveApiServiceProvider.overrideWithValue(mockLiveApiService),
              liveKitRoomServiceProvider.overrideWithValue(
                mockLiveKitRoomService,
              ),
              contentReportingServiceProvider.overrideWith(
                (ref) async => mockContentReportingService,
              ),
              contentBlocklistRepositoryProvider.overrideWithValue(
                mockContentBlocklistRepository,
              ),
            ],
            home: LiveRoomPage(
              roomId: room.id,
              sessionId: session.id,
              initialRoom: room,
              initialSession: session,
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        await tester.scrollUntilVisible(
          find.text('Host controls'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('Host controls'));
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Manage participants'));
        await tester.tap(find.text('Manage participants'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Report user').first);
        await tester.pump();
        await tester.pumpAndSettle();
        verify(
          () => mockContentReportingService.reportUser(
            userPubkey: 'audience-pubkey',
            reason: ContentFilterReason.other,
            details: 'Reported from live room moderation',
            relatedEventIds: const <String>[],
          ),
        ).called(1);

        await tester.tap(find.text('Hide chat for me').first);
        await tester.pumpAndSettle();
        expect(find.text('This room is live.'), findsNothing);
        expect(
          find.text('Hidden messages are visible to everyone else.'),
          findsOneWidget,
        );

        await tester.tap(find.text('Block user').first);
        await tester.pump();
        await tester.pumpAndSettle();
        verify(
          () => mockContentBlocklistRepository.blockUser(
            'audience-pubkey',
            ourPubkey: 'host-pubkey',
          ),
        ).called(1);
      },
    );

    testWidgets('audience members do not see host controls', (tester) async {
      when(
        () => mockLiveRepository.watchPresence(sessionAddress: sessionAddress),
      ).thenAnswer(
        (_) => Stream<List<LivePresence>>.value(<LivePresence>[hostPresence]),
      );

      SharedPreferences.setMockInitialValues(<String, Object>{});
      final sharedPreferences = await SharedPreferences.getInstance();
      final audienceAuth = createMockAuthService();
      when(() => audienceAuth.currentPublicKeyHex).thenReturn(
        'audience-pubkey',
      );

      await tester.pumpWidget(
        testMaterialApp(
          mockSharedPreferences: sharedPreferences,
          mockAuthService: audienceAuth,
          additionalOverrides: [
            liveRepositoryProvider.overrideWithValue(mockLiveRepository),
            liveChatRepositoryProvider.overrideWithValue(
              mockLiveChatRepository,
            ),
            liveApiServiceProvider.overrideWithValue(mockLiveApiService),
            liveKitRoomServiceProvider.overrideWithValue(
              mockLiveKitRoomService,
            ),
          ],
          home: LiveRoomPage(
            roomId: room.id,
            sessionId: session.id,
            initialRoom: room,
            initialSession: session,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Host controls'), findsNothing);
      expect(find.text('Participants'), findsOneWidget);
      expect(find.text('Share room'), findsOneWidget);
      expect(find.text('Zap'), findsNothing);
      expect(find.text('Raise hand'), findsOneWidget);
      expect(find.text('Turn mic on'), findsNothing);
      expect(find.text('Turn camera on'), findsNothing);
      expect(find.text('Audio only'), findsNothing);

      await tester.tap(find.text('Raise hand'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Lower hand'), findsOneWidget);
      expect(
        find.text(
          'Your hand is raised. The host can bring you on stage from the speaker queue.',
        ),
        findsOneWidget,
      );
      verify(
        () => mockLiveRepository.publishPresence(
          sessionAddress: sessionAddress,
          role: LiveRole.audience,
          handRaised: true,
        ),
      ).called(1);
    });

    testWidgets(
      'shows a back button that pops to the previous live route when opened from live discovery',
      (tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final sharedPreferences = await SharedPreferences.getInstance();
        final audienceAuth = createMockAuthService();
        when(() => audienceAuth.currentPublicKeyHex).thenReturn(
          'audience-pubkey',
        );
        final router = GoRouter(
          initialLocation: LiveDiscoveryPage.path,
          routes: <RouteBase>[
            GoRoute(
              path: LiveDiscoveryPage.path,
              builder: (context, state) => Scaffold(
                body: Builder(
                  builder: (context) => Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('live discovery'),
                      TextButton(
                        onPressed: () => context.push(
                          LiveRoomPage.pathFor(room.id, session.id),
                          extra: LiveRoomRouteData(
                            room: room,
                            session: session,
                          ),
                        ),
                        child: const Text('open room'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            GoRoute(
              path: LiveRoomPage.pathPattern,
              builder: (context, state) => LiveRoomPage(
                roomId: room.id,
                sessionId: session.id,
                initialRoom: room,
                initialSession: session,
              ),
            ),
          ],
        );

        await tester.pumpWidget(
          testProviderScope(
            mockSharedPreferences: sharedPreferences,
            mockAuthService: audienceAuth,
            additionalOverrides: [
              liveRepositoryProvider.overrideWithValue(mockLiveRepository),
              liveChatRepositoryProvider.overrideWithValue(
                mockLiveChatRepository,
              ),
              liveApiServiceProvider.overrideWithValue(mockLiveApiService),
              liveKitRoomServiceProvider.overrideWithValue(
                mockLiveKitRoomService,
              ),
              contentReportingServiceProvider.overrideWith(
                (ref) async => mockContentReportingService,
              ),
              contentBlocklistRepositoryProvider.overrideWithValue(
                mockContentBlocklistRepository,
              ),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('open room'));
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.byType(BackButton), findsOneWidget);

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();

        expect(find.text('live discovery'), findsOneWidget);
        expect(find.text('open room'), findsOneWidget);
      },
    );

    testWidgets('listed speakers get local publishing controls', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final sharedPreferences = await SharedPreferences.getInstance();
      final speakerAuth = createMockAuthService();
      when(() => speakerAuth.currentPublicKeyHex).thenReturn('speaker-pubkey');

      await tester.pumpWidget(
        testMaterialApp(
          mockSharedPreferences: sharedPreferences,
          mockAuthService: speakerAuth,
          additionalOverrides: [
            liveRepositoryProvider.overrideWithValue(mockLiveRepository),
            liveChatRepositoryProvider.overrideWithValue(
              mockLiveChatRepository,
            ),
            liveApiServiceProvider.overrideWithValue(mockLiveApiService),
            liveKitRoomServiceProvider.overrideWithValue(
              mockLiveKitRoomService,
            ),
          ],
          home: LiveRoomPage(
            roomId: room.id,
            sessionId: session.id,
            initialRoom: room,
            initialSession: session,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Turn mic on'), findsOneWidget);
      expect(find.text('Turn camera on'), findsOneWidget);
      expect(find.text('Flip camera'), findsOneWidget);
      expect(find.text('Audio only'), findsOneWidget);
    });

    testWidgets(
      'hosts see starting labels while camera and microphone are still publishing',
      (tester) async {
        final mediaController = StreamController<LiveMediaState>.broadcast(
          sync: true,
        );

        when(() => mockLiveKitRoomService.watchState()).thenAnswer(
          (_) => mediaController.stream,
        );

        SharedPreferences.setMockInitialValues(<String, Object>{});
        final sharedPreferences = await SharedPreferences.getInstance();
        final hostAuth = createMockAuthService();
        when(() => hostAuth.currentPublicKeyHex).thenReturn('host-pubkey');

        addTearDown(() async {
          await mediaController.close();
        });

        await tester.pumpWidget(
          testMaterialApp(
            mockSharedPreferences: sharedPreferences,
            mockAuthService: hostAuth,
            additionalOverrides: [
              liveRepositoryProvider.overrideWithValue(mockLiveRepository),
              liveChatRepositoryProvider.overrideWithValue(
                mockLiveChatRepository,
              ),
              liveApiServiceProvider.overrideWithValue(mockLiveApiService),
              liveKitRoomServiceProvider.overrideWithValue(
                mockLiveKitRoomService,
              ),
            ],
            home: LiveRoomPage(
              roomId: room.id,
              sessionId: session.id,
              initialRoom: room,
              initialSession: session,
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        mediaController.add(
          const LiveMediaState(
            status: LiveMediaConnectionStatus.connected,
            canPublish: true,
            requestedCameraEnabled: true,
            requestedMicrophoneEnabled: true,
            cameraBusy: true,
            microphoneBusy: true,
            localParticipantIdentity: 'host-pubkey',
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('Starting camera...'), findsOneWidget);
        expect(find.text('Starting microphone...'), findsOneWidget);
        expect(find.text('Turn camera on'), findsNothing);
        expect(find.text('Turn mic on'), findsNothing);
      },
    );

    testWidgets('audience members promoted on stage gain publishing controls', (
      tester,
    ) async {
      final sessionsController = StreamController<List<LiveSession>>.broadcast(
        sync: true,
      );
      final presenceController = StreamController<List<LivePresence>>.broadcast(
        sync: true,
      );
      final promotedSession = session.copyWith(
        speakerPubkeys: const <String>[
          'host-pubkey',
          'speaker-pubkey',
          'audience-pubkey',
        ],
      );
      final promotedAudiencePresence = LivePresence(
        sessionId: session.id,
        pubkey: 'audience-pubkey',
        role: LiveRole.speaker,
        handRaised: false,
        updatedAt: DateTime.utc(2026, 4, 6, 8, 3),
      );

      when(
        () => mockLiveRepository.watchSessions(roomAddress: room.address),
      ).thenAnswer((_) => sessionsController.stream);
      when(
        () => mockLiveRepository.watchPresence(sessionAddress: sessionAddress),
      ).thenAnswer((_) => presenceController.stream);

      SharedPreferences.setMockInitialValues(<String, Object>{});
      final sharedPreferences = await SharedPreferences.getInstance();
      final audienceAuth = createMockAuthService();
      when(() => audienceAuth.currentPublicKeyHex).thenReturn(
        'audience-pubkey',
      );

      await tester.pumpWidget(
        testMaterialApp(
          mockSharedPreferences: sharedPreferences,
          mockAuthService: audienceAuth,
          additionalOverrides: [
            liveRepositoryProvider.overrideWithValue(mockLiveRepository),
            liveChatRepositoryProvider.overrideWithValue(
              mockLiveChatRepository,
            ),
            liveApiServiceProvider.overrideWithValue(mockLiveApiService),
            liveKitRoomServiceProvider.overrideWithValue(
              mockLiveKitRoomService,
            ),
          ],
          home: LiveRoomPage(
            roomId: room.id,
            sessionId: session.id,
            initialRoom: room,
            initialSession: session,
          ),
        ),
      );
      await tester.pump();

      sessionsController.add(<LiveSession>[session]);
      await tester.pump();
      await tester.pump();
      presenceController.add(<LivePresence>[hostPresence]);
      await tester.pump();
      await tester.pump();

      expect(find.text('Raise hand'), findsOneWidget);
      expect(find.text('Turn mic on'), findsNothing);

      sessionsController.add(<LiveSession>[promotedSession]);
      await tester.pump();
      await tester.pump();
      presenceController.add(<LivePresence>[
        hostPresence,
        promotedAudiencePresence,
      ]);
      await tester.pump();
      await tester.pump();

      expect(find.text('Turn mic on'), findsOneWidget);
      expect(find.text('Turn camera on'), findsOneWidget);
      verify(() => mockLiveKitRoomService.connect(speakerToken)).called(1);

      await sessionsController.close();
      await presenceController.close();
    });

    testWidgets(
      'hosts see an audio-only suggestion when the connection reconnects',
      (tester) async {
        final mediaController = StreamController<LiveMediaState>.broadcast(
          sync: true,
        );

        when(() => mockLiveKitRoomService.watchState()).thenAnswer(
          (_) => mediaController.stream,
        );

        SharedPreferences.setMockInitialValues(<String, Object>{});
        final sharedPreferences = await SharedPreferences.getInstance();
        final hostAuth = createMockAuthService();
        when(() => hostAuth.currentPublicKeyHex).thenReturn('host-pubkey');

        addTearDown(() async {
          await mediaController.close();
        });

        await tester.pumpWidget(
          testMaterialApp(
            mockSharedPreferences: sharedPreferences,
            mockAuthService: hostAuth,
            additionalOverrides: [
              liveRepositoryProvider.overrideWithValue(mockLiveRepository),
              liveChatRepositoryProvider.overrideWithValue(
                mockLiveChatRepository,
              ),
              liveApiServiceProvider.overrideWithValue(mockLiveApiService),
              liveKitRoomServiceProvider.overrideWithValue(
                mockLiveKitRoomService,
              ),
            ],
            home: LiveRoomPage(
              roomId: room.id,
              sessionId: session.id,
              initialRoom: room,
              initialSession: session,
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        mediaController.add(
          const LiveMediaState(
            status: LiveMediaConnectionStatus.reconnecting,
            canPublish: true,
            cameraEnabled: true,
            microphoneEnabled: true,
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('Connection looks shaky'), findsOneWidget);
        expect(find.text('Switch to audio only'), findsOneWidget);

        await tester.tap(find.text('Switch to audio only'));
        await tester.pump();

        verify(() => mockLiveKitRoomService.enableAudioOnly()).called(1);
      },
    );
  });
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() predicate, {
  int maxPumps = 20,
}) async {
  for (var i = 0; i < maxPumps && !predicate(); i += 1) {
    await tester.pump();
  }
}
