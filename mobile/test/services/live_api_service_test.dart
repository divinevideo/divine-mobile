import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/models/live/live_role.dart';
import 'package:openvine/models/live/live_room_recording.dart';
import 'package:openvine/models/live/live_session.dart';
import 'package:openvine/services/live_api_service.dart';
import 'package:openvine/services/nip98_auth_service.dart';

class _MockHttpClient extends Mock implements http.Client {}

class _MockNip98AuthService extends Mock implements Nip98AuthService {}

void main() {
  late _MockHttpClient mockClient;
  late _MockNip98AuthService mockNip98AuthService;
  late LiveApiService service;
  late Nip98Token authToken;

  setUpAll(() {
    registerFallbackValue(Uri.parse('https://example.com'));
    registerFallbackValue(<String, String>{});
    registerFallbackValue(HttpMethod.get);
  });

  setUp(() {
    mockClient = _MockHttpClient();
    mockNip98AuthService = _MockNip98AuthService();
    when(() => mockNip98AuthService.canCreateTokens).thenReturn(true);
    authToken = Nip98Token(
      token: 'mock-token-base64',
      signedEvent: _createMockEvent(),
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(minutes: 10)),
    );
    service = LiveApiService(
      client: mockClient,
      baseUrl: 'https://live.api.example.com',
      nip98AuthService: mockNip98AuthService,
    );
  });

  group('LiveApiService', () {
    test(
      'createRoomDraft signs the exact request URL and attaches NIP-98 auth',
      () async {
        const payload = {
          'title': 'Divine Live',
          'summary': 'Public room for mobile creators',
          'imageUrl': 'https://example.com/cover.jpg',
          'relays': ['wss://relay.example.com'],
        };
        when(
          () => mockNip98AuthService.createAuthToken(
            url: any(named: 'url'),
            method: any(named: 'method'),
            payload: any(named: 'payload'),
          ),
        ).thenAnswer((_) async => authToken);
        when(
          () => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer(
          (_) async => http.Response(
            jsonEncode({
              'status': 'created',
              'id': 'room-abc',
              'hostPubkey': 'host-pubkey',
              'title': 'Divine Live',
              'summary': 'Public room for mobile creators',
              'imageUrl': 'https://example.com/cover.jpg',
              'relays': ['wss://relay.example.com'],
              'visibility': 'public',
            }),
            200,
          ),
        );

        final roomDraft = await service.createRoomDraft(
          title: 'Divine Live',
          summary: 'Public room for mobile creators',
          imageUrl: 'https://example.com/cover.jpg',
          relays: const ['wss://relay.example.com'],
        );

        expect(roomDraft.status, LiveRoomDraftStatus.created);
        expect(roomDraft.room.id, 'room-abc');
        expect(roomDraft.room.title, 'Divine Live');
        expect(roomDraft.room.summary, 'Public room for mobile creators');
        expect(roomDraft.activeSession, isNull);

        verify(
          () => mockNip98AuthService.createAuthToken(
            url: 'https://live.api.example.com/v1/live/rooms',
            method: HttpMethod.post,
            payload: jsonEncode(payload),
          ),
        ).called(1);
        verify(
          () => mockClient.post(
            Uri.parse('https://live.api.example.com/v1/live/rooms'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'User-Agent': 'divine-Mobile/1.0',
              'Authorization': authToken.authorizationHeader,
            },
            body: jsonEncode(payload),
          ),
        ).called(1);
      },
    );

    test(
      'createRoomDraft parses an existing active session response',
      () async {
        when(
          () => mockNip98AuthService.createAuthToken(
            url: any(named: 'url'),
            method: any(named: 'method'),
            payload: any(named: 'payload'),
          ),
        ).thenAnswer((_) async => authToken);
        when(
          () => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer(
          (_) async => http.Response(
            jsonEncode({
              'status': 'existing_active',
              'id': 'room-abc',
              'hostPubkey': 'host-pubkey',
              'title': 'Divine Live',
              'summary': 'Public room for mobile creators',
              'imageUrl': 'https://example.com/cover.jpg',
              'relays': ['wss://relay.example.com'],
              'visibility': 'public',
              'activeSession': {
                'id': 'session-abc',
                'roomId': 'room-abc',
                'status': 'live',
                'startedAt': '2026-04-06T12:00:00.000Z',
                'endedAt': null,
                'speakerPubkeys': ['host-pubkey'],
                'audienceCount': 7,
              },
            }),
            200,
          ),
        );

        final roomDraft = await service.createRoomDraft(
          title: 'Divine Live',
          summary: 'Public room for mobile creators',
          imageUrl: 'https://example.com/cover.jpg',
          relays: const ['wss://relay.example.com'],
        );

        expect(roomDraft.status, LiveRoomDraftStatus.existingActive);
        expect(roomDraft.room.id, 'room-abc');
        expect(roomDraft.activeSession, isNotNull);
        expect(roomDraft.activeSession!.id, 'session-abc');
        expect(roomDraft.activeSession!.roomId, 'room-abc');
        expect(roomDraft.activeSession!.status, LiveSessionStatus.live);
        expect(
          roomDraft.activeSession!.startedAt,
          DateTime.parse(
            '2026-04-06T12:00:00.000Z',
          ),
        );
        expect(roomDraft.activeSession!.speakerPubkeys, ['host-pubkey']);
        expect(roomDraft.activeSession!.audienceCount, 7);
      },
    );

    test('startSession signs the request body before posting', () async {
      when(
        () => mockNip98AuthService.createAuthToken(
          url: any(named: 'url'),
          method: any(named: 'method'),
          payload: any(named: 'payload'),
        ),
      ).thenAnswer((_) async => authToken);
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => http.Response('', 200));

      await service.startSession(roomId: 'room-abc', sessionId: 'session-abc');

      verify(
        () => mockNip98AuthService.createAuthToken(
          url: 'https://live.api.example.com/v1/live/rooms/room-abc/sessions',
          method: HttpMethod.post,
          payload: jsonEncode({'sessionId': 'session-abc'}),
        ),
      ).called(1);
      verify(
        () => mockClient.post(
          Uri.parse(
            'https://live.api.example.com/v1/live/rooms/room-abc/sessions',
          ),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'User-Agent': 'divine-Mobile/1.0',
            'Authorization': authToken.authorizationHeader,
          },
          body: jsonEncode({'sessionId': 'session-abc'}),
        ),
      ).called(1);
    });

    test('fetchJoinToken signs the exact join URL and role payload', () async {
      when(
        () => mockNip98AuthService.createAuthToken(
          url: any(named: 'url'),
          method: any(named: 'method'),
          payload: any(named: 'payload'),
        ),
      ).thenAnswer((_) async => authToken);
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer(
        (_) async => http.Response(
          jsonEncode({
            'token': 'jwt-token',
            'roomName': 'room-abc',
            'participantIdentity': 'host-pubkey',
            'serverUrl': 'wss://livekit.example.com',
            'canPublish': true,
          }),
          200,
        ),
      );

      final token = await service.fetchJoinToken(
        roomId: 'room-abc',
        role: LiveRole.host,
      );

      expect(token.token, 'jwt-token');
      expect(token.roomName, 'room-abc');
      expect(token.participantIdentity, 'host-pubkey');
      expect(token.serverUrl, 'wss://livekit.example.com');
      expect(token.canPublish, isTrue);

      verify(
        () => mockNip98AuthService.createAuthToken(
          url: 'https://live.api.example.com/v1/live/rooms/room-abc/join',
          method: HttpMethod.post,
          payload: jsonEncode({'role': 'host'}),
        ),
      ).called(1);
    });

    test('endSession signs the empty JSON body it posts', () async {
      when(
        () => mockNip98AuthService.createAuthToken(
          url: any(named: 'url'),
          method: any(named: 'method'),
          payload: any(named: 'payload'),
        ),
      ).thenAnswer((_) async => authToken);
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => http.Response('', 200));

      await service.endSession(roomId: 'room-abc', sessionId: 'session-abc');

      verify(
        () => mockNip98AuthService.createAuthToken(
          url: 'https://live.api.example.com/v1/live/rooms/room-abc/sessions/session-abc/end',
          method: HttpMethod.post,
          payload: jsonEncode(const <String, dynamic>{}),
        ),
      ).called(1);
      verify(
        () => mockClient.post(
          Uri.parse(
            'https://live.api.example.com/v1/live/rooms/room-abc/sessions/session-abc/end',
          ),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'User-Agent': 'divine-Mobile/1.0',
            'Authorization': authToken.authorizationHeader,
          },
          body: jsonEncode(const <String, dynamic>{}),
        ),
      ).called(1);
    });

    test('setParticipantRole signs the exact PUT URL and body', () async {
      when(
        () => mockNip98AuthService.createAuthToken(
          url: any(named: 'url'),
          method: any(named: 'method'),
          payload: any(named: 'payload'),
        ),
      ).thenAnswer((_) async => authToken);
      when(
        () => mockClient.put(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => http.Response('', 200));

      await service.setParticipantRole(
        roomId: 'room-abc',
        pubkey: 'speaker-pubkey',
        role: LiveRole.speaker,
      );

      verify(
        () => mockNip98AuthService.createAuthToken(
          url: 'https://live.api.example.com/v1/live/rooms/room-abc/participants/speaker-pubkey/role',
          method: HttpMethod.put,
          payload: jsonEncode({'role': 'speaker'}),
        ),
      ).called(1);
      verify(
        () => mockClient.put(
          Uri.parse(
            'https://live.api.example.com/v1/live/rooms/room-abc/participants/speaker-pubkey/role',
          ),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'User-Agent': 'divine-Mobile/1.0',
            'Authorization': authToken.authorizationHeader,
          },
          body: jsonEncode({'role': 'speaker'}),
        ),
      ).called(1);
    });

    test('fetchRecording parses recording status when present', () async {
      when(
        () => mockClient.get(any(), headers: any(named: 'headers')),
      ).thenAnswer(
        (_) async => http.Response(
          jsonEncode({
            'status': 'ready',
            'playbackUrl': 'https://example.com/replay.m3u8',
          }),
          200,
        ),
      );

      final recording = await service.fetchRecording(roomId: 'room-abc');

      expect(recording, isNotNull);
      expect(recording!.status, RecordingStatus.ready);
      expect(recording.playbackUrl, 'https://example.com/replay.m3u8');
      verifyNever(
        () => mockNip98AuthService.createAuthToken(
          url: any(named: 'url'),
          method: any(named: 'method'),
          payload: any(named: 'payload'),
        ),
      );
    });

    test(
      'fetchRecording returns null when the room has no replay yet',
      () async {
        when(
          () => mockClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('', 404));

        final recording = await service.fetchRecording(roomId: 'room-abc');

        expect(recording, isNull);
      },
    );
  });
}

Event _createMockEvent() {
  final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  return Event.fromJson({
    'id': 'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
    'kind': 27235,
    'pubkey':
        'aabbccdd0123456789abcdef0123456789abcdef0123456789abcdef01234567',
    'created_at': timestamp,
    'content': '',
    'tags': [
      ['u', 'https://live.api.example.com/v1/live/rooms'],
      ['method', 'POST'],
      ['created_at', '$timestamp'],
    ],
    'sig':
        'deadbeef0123456789abcdef0123456789abcdef0123456789abcdef01234567'
        '89abcdef0123456789abcdef0123456789abcdef0123456789abcdef01234567'
        '89ab',
  });
}
