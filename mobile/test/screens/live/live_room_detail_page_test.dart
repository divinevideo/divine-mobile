import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/live/live_chat_message.dart';
import 'package:openvine/models/live/live_media_state.dart';
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
import 'package:openvine/screens/live/live_room_detail_view.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/live_api_service.dart';
import 'package:openvine/services/live_nostr_codec.dart';
import 'package:openvine/services/livekit_room_service.dart';
import 'package:share_plus_platform_interface/method_channel/method_channel_share.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../../helpers/test_provider_overrides.dart';
import '../../helpers/url_launcher_test_double.dart';

class _MockNostrClient extends Mock implements NostrClient {}

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
      hostPubkey:
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      title: 'Signal from the stage',
      summary: 'A live room for creators and the people following along.',
      imageUrl: null,
      relays: <String>[],
      visibility: LiveRoomVisibility.public,
    );
    final session = LiveSession(
      id: 'session-123',
      roomId: 'room-123',
      hostPubkey: room.hostPubkey,
      status: LiveSessionStatus.live,
      startedAt: DateTime.utc(2026, 4, 6, 8),
      endedAt: null,
      speakerPubkeys: const <String>[
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      ],
      audienceCount: 64,
    );
    final endedSession = LiveSession(
      id: 'session-ended',
      roomId: 'room-123',
      hostPubkey: room.hostPubkey,
      status: LiveSessionStatus.ended,
      startedAt: DateTime.utc(2026, 4, 6, 7),
      endedAt: DateTime.utc(2026, 4, 6, 9),
      speakerPubkeys: const <String>[
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      ],
      audienceCount: 64,
    );
    const sessionAddress =
        '30313:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa:session-123';
    const token = LiveRoomToken(
      hostPubkey:
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
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
        () => mockLiveRepository.watchSessions(
          roomAddress: room.address,
          sessionId: any(named: 'sessionId'),
        ),
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
          expectedHostPubkey: room.hostPubkey,
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

    for (final entry in <String, Object?>{
      'missing': null,
      'malformed': 'g' * 64,
      'different': 'b' * 64,
      'matching': room.hostPubkey,
    }.entries) {
      testWidgets(
        'replay with ${entry.key} API host is checked before playback',
        (
          tester,
        ) async {
          final originalPlatform = UrlLauncherPlatform.instance;
          final launcher = UrlLauncherTestDouble();
          UrlLauncherPlatform.instance = launcher;
          addTearDown(() => UrlLauncherPlatform.instance = originalPlatform);
          final api = LiveApiService(
            baseUrl: 'https://live.api.example.com',
            client: MockClient((request) async {
              expect(request.method, 'GET');
              return http.Response(
                jsonEncode({
                  'status': 'ready',
                  'playbackUrl': 'https://example.com/replay.m3u8',
                  'hostPubkey': ?entry.value,
                }),
                200,
              );
            }),
          );
          final repository = LiveRepository(
            nostrClient: _MockNostrClient(),
            codec: const LiveNostrCodec(),
            liveApiService: api,
          );
          SharedPreferences.setMockInitialValues(<String, Object>{});
          final preferences = await SharedPreferences.getInstance();
          await tester.pumpWidget(
            testMaterialApp(
              mockSharedPreferences: preferences,
              mockAuthService: mockAuthService,
              additionalOverrides: [
                liveRepositoryProvider.overrideWithValue(repository),
              ],
              home: LiveRoomDetailPage(
                roomId: room.id,
                initialRoom: room,
                initialSession: endedSession,
              ),
            ),
          );
          await tester.pumpAndSettle();
          if (entry.value == room.hostPubkey) {
            expect(find.text('Open replay'), findsOneWidget);
            await tester.ensureVisible(find.text('Open replay'));
            await tester.pumpAndSettle();
            await tester.tap(find.text('Open replay'));
            await tester.pumpAndSettle();
            expect(
              launcher.launched.single.url,
              'https://example.com/replay.m3u8',
            );
            expect(launcher.launched.single.useExternalApplication, isTrue);
          } else {
            expect(find.text('Open replay'), findsNothing);
            expect(find.byType(LiveRoomDetailView), findsNothing);
            expect(launcher.launched, isEmpty);
          }
        },
      );
    }

    for (final mismatch in ['host', 'room', 'missing host']) {
      testWidgets('ignores a $mismatch mismatch in the initial session extra', (
        tester,
      ) async {
        final repository = _MockLiveRepository();
        final canonicalSession = session.copyWith(hostPubkey: room.hostPubkey);
        final foreignSession = LiveSession(
          id: 'foreign-session',
          roomId: mismatch == 'room' ? 'another-room' : room.id,
          hostPubkey: mismatch == 'missing host'
              ? null
              : mismatch == 'host'
              ? 'another-host'
              : room.hostPubkey,
          status: LiveSessionStatus.ended,
          startedAt: DateTime.utc(2026),
          endedAt: DateTime.utc(2026, 1, 2),
          speakerPubkeys: const [],
          audienceCount: 0,
        );
        when(() => repository.fetchSessions(roomAddress: room.address))
            .thenAnswer(
              (_) async => [
                foreignSession.copyWith(status: LiveSessionStatus.live),
                canonicalSession,
              ],
            );
        when(
          () => repository.fetchRecording(
            roomId: room.id,
            expectedHostPubkey: room.hostPubkey,
          ),
        ).thenAnswer((_) async => null);
        await tester.pumpWidget(
          testMaterialApp(
            additionalOverrides: [
              liveRepositoryProvider.overrideWithValue(repository),
            ],
            home: LiveRoomDetailPage(
              roomId: room.id,
              initialRoom: room,
              initialSession: foreignSession,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<LiveRoomDetailView>(find.byType(LiveRoomDetailView))
              .session,
          canonicalSession,
        );
        expect(
          find.text(
            tester.element(find.byType(LiveRoomDetailPage)).l10n.liveJoinLive,
          ),
          findsOneWidget,
        );
        verify(() => repository.fetchSessions(roomAddress: room.address))
            .called(1);
        verifyNever(
          () => repository.fetchRecording(
            roomId: room.id,
            expectedHostPubkey: room.hostPubkey,
          ),
        );
        verifyNever(() => repository.fetchRoom(any()));
      });
    }

    testWidgets('missing direct link finishes loading with unavailable state', (
      tester,
    ) async {
      final repository = _MockLiveRepository();
      when(() => repository.fetchRoom('missing')).thenAnswer((_) async => null);
      await tester.pumpWidget(
        testMaterialApp(
          additionalOverrides: [
            liveRepositoryProvider.overrideWithValue(repository),
          ],
          home: const LiveRoomDetailPage(roomId: 'missing'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Room unavailable.'), findsOneWidget);
      verify(() => repository.fetchRoom('missing')).called(1);
      verifyNever(repository.fetchPublicRooms);
    });

    testWidgets('join button preserves path-sensitive room and session IDs', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      SharedPreferences.setMockInitialValues(<String, Object>{});
      final sharedPreferences = await SharedPreferences.getInstance();
      final linkedRoom = room.copyWith(id: 'room/with ?#% 雪');
      final linkedSession = session.copyWith(
        id: 'session/with ?#% 雪',
        roomId: linkedRoom.id,
      );
      when(
        () => mockLiveRepository.fetchRecording(
          roomId: linkedRoom.id,
          expectedHostPubkey: linkedRoom.hostPubkey,
        ),
      ).thenAnswer((_) async => null);
      Map<String, String>? joinedParameters;
      final router = GoRouter(
        routes: <RouteBase>[
          GoRoute(
            path: '/',
            builder: (context, state) => LiveRoomDetailPage(
              roomId: linkedRoom.id,
              initialRoom: linkedRoom,
              initialSession: linkedSession,
            ),
          ),
          GoRoute(
            path: '/live/room/:roomId/session/:sessionId',
            builder: (context, state) {
              joinedParameters = state.pathParameters;
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
          child: MaterialApp.router(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          tester.element(find.byType(LiveRoomDetailPage)).l10n.liveJoinLive,
        ),
        findsOneWidget,
      );

      await tester.scrollUntilVisible(
        find.text(
          tester.element(find.byType(LiveRoomDetailPage)).l10n.liveJoinLive,
        ),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(
          tester.element(find.byType(LiveRoomDetailPage)).l10n.liveJoinLive,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('room page'), findsOneWidget);
      expect(joinedParameters, {
        'roomId': linkedRoom.id,
        'sessionId': linkedSession.id,
      });
    });

    testWidgets('ended rooms show a replay banner when recording exists', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final sharedPreferences = await SharedPreferences.getInstance();
      when(
        () => mockLiveRepository.fetchRecording(
          roomId: room.id,
          expectedHostPubkey: room.hostPubkey,
        ),
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
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();

      expect(find.text('Ended'), findsOneWidget);
      expect(find.text('Scheduled'), findsNothing);
      expect(find.text('Replay ready'), findsOneWidget);
      expect(find.text('Open replay'), findsOneWidget);
    });

    testWidgets('ended rooms hide replay UI when recording is absent', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final sharedPreferences = await SharedPreferences.getInstance();
      when(
        () => mockLiveRepository.fetchRecording(
          roomId: room.id,
          expectedHostPubkey: room.hostPubkey,
        ),
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
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();

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
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();

      expect(find.text('Schedule'), findsOneWidget);
      expect(find.text('Speakers'), findsOneWidget);
      expect(
        find.text(
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        ),
        findsOneWidget,
      );
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
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Share room'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Share room'));
      await tester.pumpAndSettle();

      expect(shareCalls, hasLength(1));
      expect(shareCalls.single.method, 'share');
      final arguments = shareCalls.single.arguments as Map;
      expect(arguments['originWidth'], greaterThan(0));
      expect(arguments['originHeight'], greaterThan(0));
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
            child: MaterialApp.router(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.pumpAndSettle();

        expect(find.byTooltip('Back'), findsOneWidget);

        await tester.tap(find.byTooltip('Back'));
        await tester.pumpAndSettle();

        expect(find.text('live discovery'), findsOneWidget);
      },
    );
  });
}
