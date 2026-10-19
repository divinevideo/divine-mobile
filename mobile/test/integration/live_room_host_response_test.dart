import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/blocs/live_room/live_room_bloc.dart';
import 'package:openvine/models/live/live_media_state.dart';
import 'package:openvine/models/live/live_room.dart';
import 'package:openvine/models/live/live_room_token.dart';
import 'package:openvine/models/live/live_session.dart';
import 'package:openvine/repositories/live_repository.dart';
import 'package:openvine/services/api_service.dart';
import 'package:openvine/services/live_api_service.dart';
import 'package:openvine/services/live_nostr_codec.dart';
import 'package:openvine/services/livekit_room_service.dart';
import 'package:openvine/services/nip98_auth_service.dart';

class _MockLiveRepository extends Mock implements LiveRepository {}

class _MockNostrClient extends Mock implements NostrClient {}

class _MockLiveKitRoomService extends Mock implements LiveKitRoomService {}

class _MockNip98AuthService extends Mock implements Nip98AuthService {}

class _MockNip98Token extends Mock implements Nip98Token {}

const _host =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _otherHost =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _room = LiveRoom(
  id: 'room:with:colons',
  hostPubkey: _host,
  title: 'Live room',
  summary: '',
  imageUrl: null,
  relays: [],
  visibility: LiveRoomVisibility.public,
);
final _session = LiveSession(
  id: 'session:with:colons',
  roomId: _room.id,
  hostPubkey: _host,
  status: LiveSessionStatus.live,
  startedAt: DateTime.utc(2026, 10, 19),
  endedAt: null,
  speakerPubkeys: const [_host],
  audienceCount: 1,
);
const _token = LiveRoomToken(
  token: 'join-token',
  hostPubkey: _host,
  roomName: 'room:with:colons',
  participantIdentity: _otherHost,
  serverUrl: 'wss://live.example.com',
  canPublish: false,
);

void main() {
  setUpAll(() {
    registerFallbackValue(_token);
    registerFallbackValue(HttpMethod.post);
  });

  group('Live API to room connection', () {
    for (final entry in <String, Object?>{
      'missing': null,
      'short': 'a' * 63,
      'long': 'a' * 65,
      'non-hex': 'g' * 64,
      'different': _otherHost,
    }.entries) {
      test(
        '${entry.key} host never connects or enters the token cache',
        () async {
          var responseHost = entry.value;
          var requests = 0;
          final api = _api(
            MockClient((request) async {
              requests++;
              expect(
                request.url.toString(),
                'https://live.api.example.com/v1/live/rooms/room%3Awith%3Acolons/join',
              );
              expect(jsonDecode(request.body), {'role': 'audience'});
              return _joinResponse(responseHost);
            }),
          );
          final sessions = StreamController<List<LiveSession>>();
          final repository = _repository(sessions.stream);
          final media = _media();
          final bloc = LiveRoomBloc(
            liveRepository: repository,
            liveApiService: api,
            liveKitRoomService: media,
          );
          addTearDown(bloc.close);
          addTearDown(sessions.close);

          bloc.add(const LiveRoomJoinRequested(room: _room));
          await pumpEventQueue();
          sessions.add([_session]);
          await pumpEventQueue();

          expect(bloc.state.error, LiveRoomError.connectionFailed);
          verifyNever(() => media.connect(any()));
          expect(requests, 1);

          // A valid subsequent response must be fetched instead of reusing the
          // rejected result, and can then reconnect from its validated cache.
          responseHost = _host;
          bloc.add(const LiveRoomAppForegroundChanged(true));
          await pumpEventQueue();
          verify(() => media.connect(_token)).called(1);
          expect(requests, 2);
          bloc.add(const LiveRoomAppForegroundChanged(false));
          await pumpEventQueue();
          bloc.add(const LiveRoomAppForegroundChanged(true));
          await pumpEventQueue();
          verify(() => media.connect(_token)).called(1);
          expect(requests, 2);
        },
      );
    }

    test(
      'stale cached token retry rejects an unbound fresh response',
      () async {
        var requests = 0;
        final api = _api(
          MockClient((_) async {
            requests++;
            return _joinResponse(requests == 1 ? _host : _otherHost);
          }),
        );
        final sessions = StreamController<List<LiveSession>>();
        final repository = _repository(sessions.stream);
        final media = _media();
        var connects = 0;
        when(() => media.connect(any())).thenAnswer((_) async {
          if (++connects > 1) throw StateError('Expired cached token');
        });
        final bloc = LiveRoomBloc(
          liveRepository: repository,
          liveApiService: api,
          liveKitRoomService: media,
        );
        addTearDown(bloc.close);
        addTearDown(sessions.close);
        bloc.add(const LiveRoomJoinRequested(room: _room));
        await pumpEventQueue();
        sessions.add([_session]);
        await pumpEventQueue();
        expect(connects, 1);
        bloc.add(const LiveRoomAppForegroundChanged(false));
        await pumpEventQueue();
        bloc.add(const LiveRoomAppForegroundChanged(true));
        await pumpEventQueue();
        expect(requests, 2);
        // Only the original connection and failed cached attempt reached media.
        expect(connects, 2);
        expect(bloc.state.error, LiveRoomError.connectionFailed);

        // Rejected replacement must not remain cached for another foreground.
        bloc.add(const LiveRoomAppForegroundChanged(true));
        await pumpEventQueue();
        expect(requests, 3);
        expect(connects, 2);
      },
    );
  });

  group('Live API through replay repository', () {
    for (final entry in <String, Object?>{
      'missing': null,
      'malformed': 'g' * 64,
      'different': _otherHost,
      'matching': _host,
    }.entries) {
      test(
        '${entry.key} host controls whether playback can be exposed',
        () async {
          final api = _api(
            MockClient((request) async {
              expect(
                request.url.toString(),
                'https://live.api.example.com/v1/live/rooms/room%3Awith%3Acolons/recording',
              );
              expect(request.url.query, isEmpty);
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
          final recording = repository.fetchRecording(
            roomId: _room.id,
            expectedHostPubkey: _room.hostPubkey,
          );
          if (entry.value == _host) {
            final result = await recording;
            expect(result!.isReady, isTrue);
            expect(result.playbackUrl, 'https://example.com/replay.m3u8');
          } else {
            await expectLater(recording, throwsA(isA<ApiException>()));
          }
        },
      );
    }
  });
}

LiveApiService _api(MockClient client) {
  final auth = _MockNip98AuthService();
  final token = _MockNip98Token();
  when(() => token.authorizationHeader).thenReturn('Nostr test-auth');
  when(() => auth.canCreateTokens).thenReturn(true);
  when(
    () => auth.createAuthToken(
      url: any(named: 'url'),
      method: any(named: 'method'),
      payload: any(named: 'payload'),
    ),
  ).thenAnswer((_) async => token);
  return LiveApiService(
    client: client,
    baseUrl: 'https://live.api.example.com',
    nip98AuthService: auth,
  );
}

http.Response _joinResponse(Object? host) => http.Response(
  jsonEncode({
    'token': _token.token,
    'roomName': _token.roomName,
    'participantIdentity': _token.participantIdentity,
    'serverUrl': _token.serverUrl,
    'canPublish': _token.canPublish,
    'hostPubkey': ?host,
  }),
  200,
);

_MockLiveRepository _repository(Stream<List<LiveSession>> sessions) {
  final repository = _MockLiveRepository();
  when(() => repository.watchSessions(roomAddress: _room.address))
      .thenAnswer((_) => sessions);
  when(() => repository.watchPresence(sessionAddress: _session.addressKey))
      .thenAnswer((_) => const Stream.empty());
  return repository;
}

_MockLiveKitRoomService _media() {
  final media = _MockLiveKitRoomService();
  when(media.watchState)
      .thenAnswer((_) => const Stream<LiveMediaState>.empty());
  when(() => media.connect(any())).thenAnswer((_) async {});
  when(media.disconnect).thenAnswer((_) async {});
  return media;
}
