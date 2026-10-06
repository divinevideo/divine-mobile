import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:mocktail/mocktail.dart';
import 'package:openvine/models/live/live_room_token.dart';
import 'package:openvine/services/livekit_room_service.dart';

void main() {
  late _FakeLiveKitRoomClient client;
  late LiveKitRoomService service;

  setUp(() {
    client = _FakeLiveKitRoomClient();
    service = LiveKitRoomService(clientFactory: () => client);
  });

  tearDown(() async {
    await service.dispose();
    await client.dispose();
  });

  group('LiveKitRoomService', () {
    test(
      'connect uses the token boundary and publishes connected state',
      () async {
        final states = <LiveMediaState>[];
        final subscription = service.watchState().listen(states.add);

        await service.connect(
          const LiveRoomToken(
            token: 'jwt-token',
            roomName: 'room-abc',
            participantIdentity: 'host-pubkey',
            serverUrl: 'wss://livekit.example.com',
            canPublish: true,
          ),
        );
        await _flush();
        await Future<void>.delayed(Duration.zero);

        expect(client.prepareCalls, 1);
        expect(client.connectCalls, 1);
        expect(client.lastDisableFastConnectPublish, isTrue);
        expect(client.lastUrl, 'wss://livekit.example.com');
        expect(client.lastToken, 'jwt-token');
        expect(
          service.currentState.status,
          LiveMediaConnectionStatus.connected,
        );
        expect(service.currentState.canPublish, isTrue);
        expect(service.currentState.localParticipantIdentity, 'host-pubkey');
        expect(
          states.map((state) => state.status),
          containsAll([
            LiveMediaConnectionStatus.disconnected,
            LiveMediaConnectionStatus.connecting,
            LiveMediaConnectionStatus.connected,
          ]),
        );

        await subscription.cancel();
      },
    );

    test(
      'connect snapshots local and remote stage participants for rendering',
      () async {
        client.stageParticipants = <LiveStageParticipant>[
          const LiveStageParticipant(
            identity: 'host-pubkey',
            isLocal: true,
            isMicrophoneEnabled: true,
          ),
          const LiveStageParticipant(
            identity: 'speaker-pubkey',
            isLocal: false,
            isMicrophoneEnabled: true,
          ),
        ];

        await service.connect(
          const LiveRoomToken(
            token: 'jwt-token',
            roomName: 'room-abc',
            participantIdentity: 'host-pubkey',
            serverUrl: 'wss://livekit.example.com',
            canPublish: true,
          ),
        );
        await _flush();

        expect(
          service.currentState.stageParticipants,
          client.stageParticipants,
        );
      },
    );

    test(
      'participant updates refresh the stage snapshot without reconnecting',
      () async {
        client.stageParticipants = const <LiveStageParticipant>[
          LiveStageParticipant(
            identity: 'host-pubkey',
            isLocal: true,
            isMicrophoneEnabled: true,
          ),
        ];

        await service.connect(
          const LiveRoomToken(
            token: 'jwt-token',
            roomName: 'room-abc',
            participantIdentity: 'host-pubkey',
            serverUrl: 'wss://livekit.example.com',
            canPublish: true,
          ),
        );
        await _flush();

        client.stageParticipants = const <LiveStageParticipant>[
          LiveStageParticipant(
            identity: 'host-pubkey',
            isLocal: true,
            isMicrophoneEnabled: true,
          ),
          LiveStageParticipant(
            identity: 'speaker-pubkey',
            isLocal: false,
            isMicrophoneEnabled: true,
          ),
        ];

        client.emit(LiveKitRoomClientEvent.participantsChanged);
        await _flush();

        expect(
          service.currentState.stageParticipants,
          client.stageParticipants,
        );
        expect(client.connectCalls, 1);
      },
    );

    test(
      'publishLocalTracks delegates camera and microphone toggles',
      () async {
        await service.connect(
          const LiveRoomToken(
            token: 'jwt-token',
            roomName: 'room-abc',
            participantIdentity: 'host-pubkey',
            serverUrl: 'wss://livekit.example.com',
            canPublish: true,
          ),
        );
        await Future<void>.delayed(Duration.zero);

        await service.publishLocalTracks(
          cameraEnabled: true,
          microphoneEnabled: false,
        );

        expect(client.cameraEnabledCalls, [true]);
        expect(client.microphoneEnabledCalls, [false]);
        expect(service.currentState.requestedCameraEnabled, isTrue);
        expect(service.currentState.requestedMicrophoneEnabled, isFalse);
        expect(service.currentState.cameraEnabled, isFalse);
        expect(service.currentState.microphoneEnabled, isFalse);
      },
    );

    test(
      'camera enable only marks video live when a local video track actually exists',
      () async {
        await service.connect(
          const LiveRoomToken(
            token: 'jwt-token',
            roomName: 'room-abc',
            participantIdentity: 'host-pubkey',
            serverUrl: 'wss://livekit.example.com',
            canPublish: true,
          ),
        );
        await Future<void>.delayed(Duration.zero);

        await service.setCameraEnabled(true);
        await _flush();

        expect(service.currentState.requestedCameraEnabled, isTrue);
        expect(service.currentState.cameraEnabled, isFalse);

        final videoTrack = _MockVideoTrack();
        client.stageParticipants = <LiveStageParticipant>[
          LiveStageParticipant(
            identity: 'host-pubkey',
            isLocal: true,
            videoTrack: videoTrack,
          ),
        ];

        client.emit(LiveKitRoomClientEvent.participantsChanged);
        await _flush();

        expect(service.currentState.requestedCameraEnabled, isTrue);
        expect(service.currentState.cameraEnabled, isTrue);
      },
    );

    test('switchCamera delegates to the room client', () async {
      await service.connect(
        const LiveRoomToken(
          token: 'jwt-token',
          roomName: 'room-abc',
          participantIdentity: 'host-pubkey',
          serverUrl: 'wss://livekit.example.com',
          canPublish: true,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      await service.switchCamera();

      expect(client.switchCameraCalls, 1);
    });

    test('reconnecting events surface a reconnecting media state', () async {
      await service.connect(
        const LiveRoomToken(
          token: 'jwt-token',
          roomName: 'room-abc',
          participantIdentity: 'host-pubkey',
          serverUrl: 'wss://livekit.example.com',
          canPublish: true,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      client.emit(LiveKitRoomClientEvent.reconnecting);
      await _flush();
      await Future<void>.delayed(Duration.zero);

      expect(
        service.currentState.status,
        LiveMediaConnectionStatus.reconnecting,
      );
    });

    test('enableAudioOnly disables camera and keeps microphone live', () async {
      client.stageParticipants = const <LiveStageParticipant>[
        LiveStageParticipant(
          identity: 'host-pubkey',
          isLocal: true,
          isMicrophoneEnabled: true,
        ),
      ];

      await service.connect(
        const LiveRoomToken(
          token: 'jwt-token',
          roomName: 'room-abc',
          participantIdentity: 'host-pubkey',
          serverUrl: 'wss://livekit.example.com',
          canPublish: true,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      await service.publishLocalTracks(
        cameraEnabled: true,
        microphoneEnabled: true,
      );

      await service.enableAudioOnly();
      await _flush();

      expect(client.cameraEnabledCalls, [true, false]);
      expect(client.microphoneEnabledCalls, [true, true]);
      expect(service.currentState.requestedCameraEnabled, isFalse);
      expect(service.currentState.requestedMicrophoneEnabled, isTrue);
      expect(service.currentState.cameraEnabled, isFalse);
      expect(service.currentState.microphoneEnabled, isTrue);
      expect(service.currentState.status, LiveMediaConnectionStatus.audioOnly);
    });

    test('connect failures surface a failed media state', () async {
      client.failConnect = true;

      await expectLater(
        () => service.connect(
          const LiveRoomToken(
            token: 'jwt-token',
            roomName: 'room-abc',
            participantIdentity: 'host-pubkey',
            serverUrl: 'wss://livekit.example.com',
            canPublish: true,
          ),
        ),
        throwsA(isA<StateError>()),
      );

      expect(service.currentState.status, LiveMediaConnectionStatus.failed);
      expect(service.currentState.canPublish, isTrue);
    });

    test('disconnect resets the state to disconnected', () async {
      await service.connect(
        const LiveRoomToken(
          token: 'jwt-token',
          roomName: 'room-abc',
          participantIdentity: 'audience-pubkey',
          serverUrl: 'wss://livekit.example.com',
          canPublish: false,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      await service.disconnect();

      expect(client.disconnectCalls, 1);
      expect(
        service.currentState.status,
        LiveMediaConnectionStatus.disconnected,
      );
      expect(service.currentState.canPublish, isFalse);
      expect(service.currentState.localParticipantIdentity, isNull);
      expect(service.currentState.requestedCameraEnabled, isFalse);
      expect(service.currentState.requestedMicrophoneEnabled, isFalse);
      expect(service.currentState.cameraEnabled, isFalse);
      expect(service.currentState.microphoneEnabled, isFalse);
    });
  });
}

Future<void> _flush() async {
  await Future<void>.delayed(Duration.zero);
}

class _FakeLiveKitRoomClient implements LiveKitRoomClient {
  final StreamController<LiveKitRoomClientEvent> _eventsController =
      StreamController<LiveKitRoomClientEvent>.broadcast(sync: true);

  int prepareCalls = 0;
  int connectCalls = 0;
  int disconnectCalls = 0;
  int switchCameraCalls = 0;
  bool failConnect = false;
  bool cameraEnableSucceeds = true;
  bool microphoneEnableSucceeds = true;
  String? lastUrl;
  String? lastToken;
  bool? lastDisableFastConnectPublish;
  List<LiveStageParticipant> stageParticipants = const <LiveStageParticipant>[];
  final List<bool> cameraEnabledCalls = <bool>[];
  final List<bool> microphoneEnabledCalls = <bool>[];

  @override
  Stream<LiveKitRoomClientEvent> get events => _eventsController.stream;

  @override
  List<LiveStageParticipant> get currentStageParticipants => stageParticipants;

  void emit(LiveKitRoomClientEvent event) {
    _eventsController.add(event);
  }

  @override
  Future<void> connect(
    String serverUrl,
    String token, {
    bool disableFastConnectPublish = false,
  }) async {
    connectCalls += 1;
    lastUrl = serverUrl;
    lastToken = token;
    lastDisableFastConnectPublish = disableFastConnectPublish;
    if (failConnect) {
      throw StateError('connect failed');
    }
    _eventsController.add(LiveKitRoomClientEvent.connected);
  }

  @override
  Future<void> disconnect() async {
    disconnectCalls += 1;
    _eventsController.add(LiveKitRoomClientEvent.disconnected);
  }

  @override
  Future<void> enableAudioOnly() async {
    cameraEnabledCalls.add(false);
    microphoneEnabledCalls.add(true);
  }

  @override
  Future<void> prepareConnection(String serverUrl, String token) async {
    prepareCalls += 1;
    lastUrl = serverUrl;
    lastToken = token;
  }

  @override
  Future<bool> setCameraEnabled(bool enabled) async {
    cameraEnabledCalls.add(enabled);
    return !enabled || cameraEnableSucceeds;
  }

  @override
  Future<bool> setMicrophoneEnabled(bool enabled) async {
    microphoneEnabledCalls.add(enabled);
    return !enabled || microphoneEnableSucceeds;
  }

  @override
  Future<void> switchCamera() async {
    switchCameraCalls += 1;
  }

  @override
  Future<void> dispose() async {
    if (!_eventsController.isClosed) {
      await _eventsController.close();
    }
  }
}

class _MockVideoTrack extends Mock implements lk.VideoTrack {}
