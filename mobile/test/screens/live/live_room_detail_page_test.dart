import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/models/live/live_chat_message.dart';
import 'package:openvine/models/live/live_presence.dart';
import 'package:openvine/models/live/live_role.dart';
import 'package:openvine/models/live/live_room.dart';
import 'package:openvine/models/live/live_room_recording.dart';
import 'package:openvine/models/live/live_room_token.dart';
import 'package:openvine/models/live/live_session.dart';
import 'package:openvine/providers/live_providers.dart';
import 'package:openvine/repositories/live_chat_repository.dart';
import 'package:openvine/repositories/live_repository.dart';
import 'package:openvine/screens/live/live_discovery_page.dart';
import 'package:openvine/screens/live/live_room_detail_page.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/live_api_service.dart';
import 'package:openvine/services/livekit_room_service.dart';
import 'package:share_plus_platform_interface/method_channel/method_channel_share.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockLiveRepository extends Mock implements LiveRepository {}

class _MockLiveChatRepository extends Mock implements LiveChatRepository {}

class _MockLiveApiService extends Mock implements LiveApiService {}

class _MockLiveKitRoomService extends Mock implements LiveKitRoomService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LiveRoomDetailPage', () {
    late _MockLiveRepository mockLiveRepository;
    late _MockLiveChatRepository mockLiveChatRepository;
    late _MockLiveApiService mockLiveApiService;
    late _MockLiveKitRoomService mockLiveKitRoomService;
    late AuthService mockAuthService;

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
      speakerPubkeys: const <String>['host-pubkey'],
      audienceCount: 64,
    );
    final endedSession = LiveSession(
      id: 'session-ended',
      roomId: 'room-123',
      status: LiveSessionStatus.ended,
      startedAt: DateTime.utc(2026, 4, 6, 7),
      endedAt: DateTime.utc(2026, 4, 6, 9),
      speakerPubkeys: const <String>['host-pubkey'],
      audienceCount: 64,
    );
    const sessionAddress = '30313:host-pubkey:session-123';
    const token = LiveRoomToken(
      token: 'join-token',
      serverUrl: 'wss://live.example.com',
      roomName: 'room-123',
      participantIdentity: 'audience-pubkey',
      canPublish: false,
    );

    setUp(() {
      mockLiveRepository = _MockLiveRepository();
      mockLiveChatRepository = _MockLiveChatRepository();
      mockLiveApiService = _MockLiveApiService();
      mockLiveKitRoomService = _MockLiveKitRoomService();
      mockAuthService = createMockAuthService();

      when(() => mockAuthService.currentPublicKeyHex).thenReturn(
        'audience-pubkey',
      );
      when(() => mockLiveKitRoomService.watchState()).thenAnswer(
        (_) => Stream<LiveMediaState>.value(const LiveMediaState()),
      );
      when(
        () => mockLiveKitRoomService.connect(token),
      ).thenAnswer((_) async {});
      when(() => mockLiveKitRoomService.disconnect()).thenAnswer((_) async {});
      when(
        () => mockLiveRepository.watchSessions(roomAddress: room.address),
      ).thenAnswer(
        (_) => Stream<List<LiveSession>>.value(<LiveSession>[session]),
      );
      when(
        () => mockLiveRepository.watchPresence(sessionAddress: sessionAddress),
      ).thenAnswer(
        (_) => Stream<List<LivePresence>>.value(const <LivePresence>[]),
      );
      when(
        () => mockLiveApiService.fetchJoinToken(
          roomId: room.id,
          role: LiveRole.audience,
        ),
      ).thenAnswer((_) async => token);
      when(
        () => mockLiveChatRepository.watchChatMessages(
          sessionAddress: sessionAddress,
        ),
      ).thenAnswer(
        (_) => Stream<List<LiveChatMessage>>.value(
          const <LiveChatMessage>[],
        ),
      );
    });

    testWidgets('join button opens room page when live beta is enabled', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      SharedPreferences.setMockInitialValues(<String, Object>{});
      final sharedPreferences = await SharedPreferences.getInstance();
      final router = GoRouter(
        routes: <RouteBase>[
          GoRoute(
            path: '/',
            builder: (context, state) => LiveRoomDetailPage(
              roomId: room.id,
              initialRoom: room,
              initialSession: session,
            ),
          ),
          GoRoute(
            path: '/live/room/:roomId/session/:sessionId',
            builder: (context, state) {
              return const Scaffold(
                body: Center(child: Text('room page')),
              );
            },
          ),
        ],
      );

      await tester.pumpWidget(
        testProviderScope(
          mockSharedPreferences: sharedPreferences,
          mockAuthService: mockAuthService,
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
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();

      expect(find.text('Join live'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Join live'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Join live'));
      await tester.pumpAndSettle();

      expect(find.text('room page'), findsOneWidget);
    });

    testWidgets('ended rooms show a replay banner when recording exists', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final sharedPreferences = await SharedPreferences.getInstance();
      when(
        () => mockLiveRepository.fetchRecording(roomId: room.id),
      ).thenAnswer(
        (_) async => const LiveRoomRecording(
          playbackUrl: 'https://example.com/replay.m3u8',
          status: RecordingStatus.ready,
        ),
      );

      await tester.pumpWidget(
        testMaterialApp(
          mockSharedPreferences: sharedPreferences,
          mockAuthService: mockAuthService,
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
          home: LiveRoomDetailPage(
            roomId: room.id,
            initialRoom: room,
            initialSession: endedSession,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Replay ready'), findsOneWidget);
      expect(find.text('Open replay'), findsOneWidget);
    });

    testWidgets('ended rooms hide replay UI when recording is absent', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final sharedPreferences = await SharedPreferences.getInstance();
      when(
        () => mockLiveRepository.fetchRecording(roomId: room.id),
      ).thenAnswer((_) async => null);

      await tester.pumpWidget(
        testMaterialApp(
          mockSharedPreferences: sharedPreferences,
          mockAuthService: mockAuthService,
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
          home: LiveRoomDetailPage(
            roomId: room.id,
            initialRoom: room,
            initialSession: endedSession,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Replay ready'), findsNothing);
      expect(find.text('Open replay'), findsNothing);
    });

    testWidgets('shows schedule and speaker metadata for the room', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final sharedPreferences = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        testMaterialApp(
          mockSharedPreferences: sharedPreferences,
          mockAuthService: mockAuthService,
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
          home: LiveRoomDetailPage(
            roomId: room.id,
            initialRoom: room,
            initialSession: session,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Schedule'), findsOneWidget);
      expect(find.text('Speakers'), findsOneWidget);
      expect(find.text('host-pubkey'), findsOneWidget);
    });

    testWidgets('share room sends a public live URL', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final sharedPreferences = await SharedPreferences.getInstance();
      final shareCalls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannelShare.channel, (call) async {
            shareCalls.add(call);
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(MethodChannelShare.channel, null);
      });

      await tester.pumpWidget(
        testMaterialApp(
          mockSharedPreferences: sharedPreferences,
          mockAuthService: mockAuthService,
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
          home: LiveRoomDetailPage(
            roomId: room.id,
            initialRoom: room,
            initialSession: session,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.scrollUntilVisible(
        find.text('Share room'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Share room'));
      await tester.pumpAndSettle();

      expect(shareCalls, hasLength(1));
      expect(shareCalls.single.method, 'share');
      expect(
        shareCalls.single.arguments,
        isA<Map>().having(
          (arguments) => arguments['text'] as String,
          'text',
          contains('https://divine.video/live/room/room-123'),
        ),
      );
      expect(
        shareCalls.single.arguments,
        isA<Map>().having(
          (arguments) => arguments['subject'] as String,
          'subject',
          contains('Signal from the stage'),
        ),
      );
    });

    testWidgets(
      'shows a back button that falls back to live discovery when opened directly',
      (tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final sharedPreferences = await SharedPreferences.getInstance();
        final router = GoRouter(
          initialLocation: LiveRoomDetailPage.pathFor(room.id),
          routes: <RouteBase>[
            GoRoute(
              path: LiveDiscoveryPage.path,
              builder: (context, state) => const Scaffold(
                body: Center(child: Text('live discovery')),
              ),
            ),
            GoRoute(
              path: LiveRoomDetailPage.pathPattern,
              builder: (context, state) => LiveRoomDetailPage(
                roomId: room.id,
                initialRoom: room,
                initialSession: session,
              ),
            ),
          ],
        );

        await tester.pumpWidget(
          testProviderScope(
            mockSharedPreferences: sharedPreferences,
            mockAuthService: mockAuthService,
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
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.byType(BackButton), findsOneWidget);

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();

        expect(find.text('live discovery'), findsOneWidget);
      },
    );
  });
}
