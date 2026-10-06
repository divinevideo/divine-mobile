import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/live_room/live_room_bloc.dart';
import 'package:openvine/models/live/live_presence.dart';
import 'package:openvine/models/live/live_role.dart';
import 'package:openvine/models/live/live_room.dart';
import 'package:openvine/models/live/live_room_token.dart';
import 'package:openvine/models/live/live_session.dart';
import 'package:openvine/repositories/live_repository.dart';
import 'package:openvine/services/live_api_service.dart';
import 'package:openvine/services/livekit_room_service.dart';
import 'package:openvine/services/native_camera_permission_service.dart';
import 'package:permissions_service/permissions_service.dart';

class _MockLiveRepository extends Mock implements LiveRepository {}

class _MockLiveApiService extends Mock implements LiveApiService {}

class _MockLiveKitRoomService extends Mock implements LiveKitRoomService {}

class _MockPermissionsService extends Mock implements PermissionsService {}

class _MockNativeCameraPermissionService extends Mock
    implements NativeCameraPermissionService {}

void main() {
  group('LiveRoomBloc', () {
    late _MockLiveRepository mockRepository;
    late _MockLiveApiService mockApiService;
    late _MockLiveKitRoomService mockMediaService;
    late StreamController<List<LiveSession>> sessionsController;
    late StreamController<List<LivePresence>> presenceController;
    late StreamController<LiveMediaState> mediaController;

    const hostPubkey =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const speakerPubkey =
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
    const audiencePubkey =
        'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
    const audienceTwoPubkey =
        'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
    const audienceThreePubkey =
        'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
    const room = LiveRoom(
      id: 'room-abc',
      hostPubkey: hostPubkey,
      title: 'Divine Live',
      summary: 'Public room',
      imageUrl: null,
      relays: <String>[],
      visibility: LiveRoomVisibility.public,
    );
    final liveSession = LiveSession(
      id: 'session-abc',
      roomId: room.id,
      status: LiveSessionStatus.live,
      startedAt: DateTime.utc(2026, 4, 6, 12),
      endedAt: null,
      speakerPubkeys: const <String>[hostPubkey, speakerPubkey],
      audienceCount: 42,
    );
    final hostPresence = LivePresence(
      sessionId: liveSession.id,
      pubkey: hostPubkey,
      role: LiveRole.host,
      handRaised: false,
      updatedAt: DateTime.utc(2026, 4, 6, 12, 1),
    );
    final speakerPresence = LivePresence(
      sessionId: liveSession.id,
      pubkey: speakerPubkey,
      role: LiveRole.speaker,
      handRaised: false,
      updatedAt: DateTime.utc(2026, 4, 6, 12, 2),
    );
    final raisedHandPresence = LivePresence(
      sessionId: liveSession.id,
      pubkey: audiencePubkey,
      role: LiveRole.audience,
      handRaised: true,
      updatedAt: DateTime.utc(2026, 4, 6, 12, 3),
    );
    final audienceTwoPresence = LivePresence(
      sessionId: liveSession.id,
      pubkey: audienceTwoPubkey,
      role: LiveRole.audience,
      handRaised: true,
      updatedAt: DateTime.utc(2026, 4, 6, 12, 4),
    );
    final audienceThreePresence = LivePresence(
      sessionId: liveSession.id,
      pubkey: audienceThreePubkey,
      role: LiveRole.audience,
      handRaised: true,
      updatedAt: DateTime.utc(2026, 4, 6, 12, 5),
    );
    const joinToken = LiveRoomToken(
      token: 'jwt-token',
      roomName: 'room-abc',
      participantIdentity: hostPubkey,
      serverUrl: 'wss://livekit.example.com',
      canPublish: true,
    );
    const audienceJoinToken = LiveRoomToken(
      token: 'audience-jwt-token',
      roomName: 'room-abc',
      participantIdentity: audiencePubkey,
      serverUrl: 'wss://livekit.example.com',
      canPublish: false,
    );
    const speakerJoinToken = LiveRoomToken(
      token: 'speaker-jwt-token',
      roomName: 'room-abc',
      participantIdentity: audiencePubkey,
      serverUrl: 'wss://livekit.example.com',
      canPublish: true,
    );
    const connectedMediaState = LiveMediaState(
      status: LiveMediaConnectionStatus.connected,
      canPublish: true,
      requestedCameraEnabled: true,
      requestedMicrophoneEnabled: true,
      cameraEnabled: true,
      microphoneEnabled: true,
    );

    setUpAll(() {
      registerFallbackValue(room);
      registerFallbackValue(joinToken);
      registerFallbackValue(liveSession);
      registerFallbackValue(LiveRole.audience);
    });

    setUp(() {
      mockRepository = _MockLiveRepository();
      mockApiService = _MockLiveApiService();
      mockMediaService = _MockLiveKitRoomService();
      sessionsController = StreamController<List<LiveSession>>.broadcast(
        sync: true,
      );
      presenceController = StreamController<List<LivePresence>>.broadcast(
        sync: true,
      );
      mediaController = StreamController<LiveMediaState>.broadcast(sync: true);

      when(
        () => mockRepository.watchSessions(roomAddress: room.address),
      ).thenAnswer((_) => sessionsController.stream);
      when(
        () => mockRepository.watchPresence(
          sessionAddress: '30313:$hostPubkey:${liveSession.id}',
        ),
      ).thenAnswer((_) => presenceController.stream);
      when(
        () => mockApiService.fetchJoinToken(
          roomId: room.id,
          role: LiveRole.host,
        ),
      ).thenAnswer((_) async => joinToken);
      when(
        () => mockApiService.fetchJoinToken(
          roomId: room.id,
          role: LiveRole.audience,
        ),
      ).thenAnswer((_) async => audienceJoinToken);
      when(
        () => mockApiService.fetchJoinToken(
          roomId: room.id,
          role: LiveRole.speaker,
        ),
      ).thenAnswer((_) async => speakerJoinToken);
      when(
        () => mockApiService.endSession(
          roomId: room.id,
          sessionId: liveSession.id,
        ),
      ).thenAnswer((_) async {});
      when(
        () => mockApiService.setParticipantRole(
          roomId: room.id,
          pubkey: any(named: 'pubkey'),
          role: any(named: 'role'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => mockMediaService.watchState(),
      ).thenAnswer((_) => mediaController.stream);
      when(() => mockMediaService.connect(joinToken)).thenAnswer((_) async {});
      when(
        () => mockMediaService.connect(audienceJoinToken),
      ).thenAnswer((_) async {});
      when(
        () => mockMediaService.connect(speakerJoinToken),
      ).thenAnswer((_) async {});
      when(() => mockMediaService.disconnect()).thenAnswer((_) async {});
      when(
        () => mockMediaService.setMicrophoneEnabled(any()),
      ).thenAnswer((_) async {});
      when(
        () => mockMediaService.setCameraEnabled(any()),
      ).thenAnswer((_) async {});
      when(() => mockMediaService.switchCamera()).thenAnswer((_) async {});
      when(() => mockMediaService.enableAudioOnly()).thenAnswer((_) async {});
      when(
        () => mockMediaService.publishLocalTracks(
          cameraEnabled: any(named: 'cameraEnabled'),
          microphoneEnabled: any(named: 'microphoneEnabled'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => mockRepository.publishSession(
          session: any(named: 'session'),
          roomAddress: room.address,
          hostPubkey: room.hostPubkey,
        ),
      ).thenAnswer((_) async => null);
      when(
        () => mockRepository.publishRoom(any()),
      ).thenAnswer((_) async => null);
      when(
        () => mockRepository.publishPresence(
          sessionAddress: any(named: 'sessionAddress'),
          role: any(named: 'role'),
          handRaised: any(named: 'handRaised'),
        ),
      ).thenAnswer((_) async => null);
    });

    tearDown(() async {
      await sessionsController.close();
      await presenceController.close();
      await mediaController.close();
    });

    test(
      'join request watches room state, fetches a token, and exposes host speaker state',
      () async {
        final bloc = LiveRoomBloc(
          liveRepository: mockRepository,
          liveApiService: mockApiService,
          liveKitRoomService: mockMediaService,
        );

        bloc.add(const LiveRoomJoinRequested(room: room, role: LiveRole.host));
        await _flush();

        sessionsController.add(<LiveSession>[liveSession]);
        await _flush();

        presenceController.add(<LivePresence>[hostPresence, speakerPresence]);
        mediaController.add(connectedMediaState);
        await _flush();

        expect(bloc.state.status, LiveRoomStatus.ready);
        expect(bloc.state.room, room);
        expect(bloc.state.session, liveSession);
        expect(
          bloc.state.speakerPubkeys,
          containsAll(<String>[hostPubkey, speakerPubkey]),
        );
        expect(bloc.state.canModerate, isTrue);
        expect(bloc.state.canPublish, isTrue);
        expect(bloc.state.mediaState, connectedMediaState);

        verify(
          () => mockRepository.watchSessions(roomAddress: room.address),
        ).called(1);
        verify(
          () => mockRepository.watchPresence(
            sessionAddress: '30313:$hostPubkey:${liveSession.id}',
          ),
        ).called(1);
        verify(
          () => mockApiService.fetchJoinToken(
            roomId: room.id,
            role: LiveRole.host,
          ),
        ).called(1);
        verify(() => mockMediaService.connect(joinToken)).called(1);

        await bloc.close();
      },
    );

    test(
      'host join does not auto-publish local tracks on room entry',
      () async {
        final bloc = LiveRoomBloc(
          liveRepository: mockRepository,
          liveApiService: mockApiService,
          liveKitRoomService: mockMediaService,
        );

        bloc.add(const LiveRoomJoinRequested(room: room, role: LiveRole.host));
        await _flush();

        sessionsController.add(<LiveSession>[liveSession]);
        await _flush();

        presenceController.add(<LivePresence>[hostPresence, speakerPresence]);
        mediaController.add(
          const LiveMediaState(
            status: LiveMediaConnectionStatus.connected,
            canPublish: true,
          ),
        );
        await _flush();

        verifyNever(
          () => mockMediaService.publishLocalTracks(
            cameraEnabled: any(named: 'cameraEnabled'),
            microphoneEnabled: any(named: 'microphoneEnabled'),
          ),
        );

        await bloc.close();
      },
    );

    test('join request emits failure when token fetch fails', () async {
      when(
        () => mockApiService.fetchJoinToken(
          roomId: room.id,
          role: LiveRole.host,
        ),
      ).thenThrow(Exception('token failed'));

      final bloc = LiveRoomBloc(
        liveRepository: mockRepository,
        liveApiService: mockApiService,
        liveKitRoomService: mockMediaService,
      );

      bloc.add(const LiveRoomJoinRequested(room: room, role: LiveRole.host));
      await _flush();

      sessionsController.add(<LiveSession>[liveSession]);
      await _flush();

      expect(bloc.state.status, LiveRoomStatus.failure);
      expect(bloc.state.errorMessage, contains('token failed'));
      verifyNever(() => mockMediaService.connect(any()));

      await bloc.close();
    });

    test('publish control events delegate to the media service', () async {
      final bloc = LiveRoomBloc(
        liveRepository: mockRepository,
        liveApiService: mockApiService,
        liveKitRoomService: mockMediaService,
      );

      bloc.add(const LiveRoomJoinRequested(room: room, role: LiveRole.host));
      await _flush();

      sessionsController.add(<LiveSession>[liveSession]);
      await _flush();

      mediaController.add(connectedMediaState);
      await _flush();

      bloc
        ..add(const ToggleMicrophoneRequested())
        ..add(const ToggleCameraRequested())
        ..add(const SwitchCameraRequested())
        ..add(const EnableAudioOnlyRequested());
      await _flush();

      verify(() => mockMediaService.setMicrophoneEnabled(false)).called(1);
      verify(() => mockMediaService.setCameraEnabled(false)).called(1);
      verify(() => mockMediaService.switchCamera()).called(1);
      verify(() => mockMediaService.enableAudioOnly()).called(1);

      await bloc.close();
    });

    test(
      'camera toggle follows requested state while local publish is still in flight',
      () async {
        final bloc = LiveRoomBloc(
          liveRepository: mockRepository,
          liveApiService: mockApiService,
          liveKitRoomService: mockMediaService,
        );

        bloc.add(const LiveRoomJoinRequested(room: room, role: LiveRole.host));
        await _flush();

        sessionsController.add(<LiveSession>[liveSession]);
        await _flush();

        mediaController.add(
          const LiveMediaState(
            status: LiveMediaConnectionStatus.connected,
            canPublish: true,
            requestedCameraEnabled: true,
            cameraBusy: true,
          ),
        );
        await _flush();

        bloc.add(const ToggleCameraRequested());
        await _flush();

        verifyNever(() => mockMediaService.setCameraEnabled(any()));

        mediaController.add(
          const LiveMediaState(
            status: LiveMediaConnectionStatus.connected,
            canPublish: true,
            requestedCameraEnabled: true,
          ),
        );
        await _flush();

        bloc.add(const ToggleCameraRequested());
        await _flush();

        verify(() => mockMediaService.setCameraEnabled(false)).called(1);

        await bloc.close();
      },
    );

    test(
      'drops duplicate camera toggles while media publish is in flight',
      () async {
        final cameraCompleter = Completer<void>();
        when(
          () => mockMediaService.setCameraEnabled(false),
        ).thenAnswer((_) => cameraCompleter.future);
        final bloc = LiveRoomBloc(
          liveRepository: mockRepository,
          liveApiService: mockApiService,
          liveKitRoomService: mockMediaService,
        );

        bloc.add(const LiveRoomJoinRequested(room: room, role: LiveRole.host));
        await _flush();

        sessionsController.add(<LiveSession>[liveSession]);
        await _flush();

        mediaController.add(connectedMediaState);
        await _flush();

        bloc
          ..add(const ToggleCameraRequested())
          ..add(const ToggleCameraRequested());
        await _flush();

        verify(() => mockMediaService.setCameraEnabled(false)).called(1);

        cameraCompleter.complete();
        await _flush();

        await bloc.close();
      },
    );

    test(
      'microphone toggle follows requested state while local publish is still in flight',
      () async {
        final bloc = LiveRoomBloc(
          liveRepository: mockRepository,
          liveApiService: mockApiService,
          liveKitRoomService: mockMediaService,
        );

        bloc.add(const LiveRoomJoinRequested(room: room, role: LiveRole.host));
        await _flush();

        sessionsController.add(<LiveSession>[liveSession]);
        await _flush();

        mediaController.add(
          const LiveMediaState(
            status: LiveMediaConnectionStatus.connected,
            canPublish: true,
            requestedMicrophoneEnabled: true,
            microphoneBusy: true,
          ),
        );
        await _flush();

        bloc.add(const ToggleMicrophoneRequested());
        await _flush();

        verifyNever(() => mockMediaService.setMicrophoneEnabled(any()));

        mediaController.add(
          const LiveMediaState(
            status: LiveMediaConnectionStatus.connected,
            canPublish: true,
            requestedMicrophoneEnabled: true,
          ),
        );
        await _flush();

        bloc.add(const ToggleMicrophoneRequested());
        await _flush();

        verify(() => mockMediaService.setMicrophoneEnabled(false)).called(1);

        await bloc.close();
      },
    );

    test(
      'turning the host camera on on macOS explicitly requests native permission before publishing',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);

        final mockPermissionsService = _MockPermissionsService();
        final mockNativeCameraPermissionService =
            _MockNativeCameraPermissionService();
        when(
          mockNativeCameraPermissionService.authorizationStatus,
        ).thenAnswer(
          (_) async => NativeCameraAuthorizationStatus.notDetermined,
        );
        when(
          mockNativeCameraPermissionService.requestPermission,
        ).thenAnswer((_) async => NativeCameraPermissionStatus.granted);
        when(
          mockPermissionsService.checkMicrophoneStatus,
        ).thenAnswer((_) async => PermissionStatus.granted);
        when(
          mockPermissionsService.requestMicrophonePermission,
        ).thenAnswer((_) async => PermissionStatus.granted);

        final bloc = LiveRoomBloc(
          liveRepository: mockRepository,
          liveApiService: mockApiService,
          liveKitRoomService: mockMediaService,
          permissionsService: mockPermissionsService,
          nativeCameraPermissionService: mockNativeCameraPermissionService,
        );

        bloc.add(const LiveRoomJoinRequested(room: room, role: LiveRole.host));
        await _flush();

        sessionsController.add(<LiveSession>[liveSession]);
        await _flush();

        mediaController.add(
          const LiveMediaState(
            status: LiveMediaConnectionStatus.connected,
            canPublish: true,
          ),
        );
        await _flush();

        bloc.add(const ToggleCameraRequested());
        await _flush();

        verify(mockNativeCameraPermissionService.authorizationStatus).called(1);
        verify(mockNativeCameraPermissionService.requestPermission).called(1);
        verify(() => mockMediaService.setCameraEnabled(true)).called(1);
        expect(bloc.state.errorMessage, isNull);

        await bloc.close();
      },
    );

    test(
      'turning the host camera on on macOS surfaces a launch-environment message when macOS blocks the prompt',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);

        final mockPermissionsService = _MockPermissionsService();
        final mockNativeCameraPermissionService =
            _MockNativeCameraPermissionService();
        when(
          mockNativeCameraPermissionService.authorizationStatus,
        ).thenAnswer(
          (_) async => NativeCameraAuthorizationStatus.notDetermined,
        );
        when(
          mockNativeCameraPermissionService.requestPermission,
        ).thenAnswer((_) async => NativeCameraPermissionStatus.promptBlocked);

        final bloc = LiveRoomBloc(
          liveRepository: mockRepository,
          liveApiService: mockApiService,
          liveKitRoomService: mockMediaService,
          permissionsService: mockPermissionsService,
          nativeCameraPermissionService: mockNativeCameraPermissionService,
        );

        bloc.add(const LiveRoomJoinRequested(room: room, role: LiveRole.host));
        await _flush();

        sessionsController.add(<LiveSession>[liveSession]);
        await _flush();

        mediaController.add(
          const LiveMediaState(
            status: LiveMediaConnectionStatus.connected,
            canPublish: true,
          ),
        );
        await _flush();

        bloc.add(const ToggleCameraRequested());
        await _flush();

        verify(mockNativeCameraPermissionService.authorizationStatus).called(1);
        verify(mockNativeCameraPermissionService.requestPermission).called(1);
        verifyNever(() => mockMediaService.setCameraEnabled(true));
        expect(
          bloc.state.errorMessage,
          'macOS blocked the camera prompt for this terminal-launched build. Open Divine directly from Finder or Xcode, then try again.',
        );

        await bloc.close();
      },
    );

    test(
      'turning the host microphone on on macOS explicitly requests native permission before publishing',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);

        final mockPermissionsService = _MockPermissionsService();
        final mockNativeCameraPermissionService =
            _MockNativeCameraPermissionService();
        when(
          mockNativeCameraPermissionService.microphoneAuthorizationStatus,
        ).thenAnswer(
          (_) async => NativeCameraAuthorizationStatus.notDetermined,
        );
        when(
          mockNativeCameraPermissionService.requestMicrophonePermission,
        ).thenAnswer((_) async => NativeCameraPermissionStatus.granted);
        when(
          mockPermissionsService.checkCameraStatus,
        ).thenAnswer((_) async => PermissionStatus.granted);
        when(
          mockPermissionsService.requestCameraPermission,
        ).thenAnswer((_) async => PermissionStatus.granted);
        when(
          mockPermissionsService.checkMicrophoneStatus,
        ).thenAnswer((_) async => PermissionStatus.canRequest);
        when(
          mockPermissionsService.requestMicrophonePermission,
        ).thenAnswer((_) async => PermissionStatus.canRequest);

        final bloc = LiveRoomBloc(
          liveRepository: mockRepository,
          liveApiService: mockApiService,
          liveKitRoomService: mockMediaService,
          permissionsService: mockPermissionsService,
          nativeCameraPermissionService: mockNativeCameraPermissionService,
        );

        bloc.add(const LiveRoomJoinRequested(room: room, role: LiveRole.host));
        await _flush();

        sessionsController.add(<LiveSession>[liveSession]);
        await _flush();

        mediaController.add(
          const LiveMediaState(
            status: LiveMediaConnectionStatus.connected,
            canPublish: true,
          ),
        );
        await _flush();

        bloc.add(const ToggleMicrophoneRequested());
        await _flush();

        verify(
          mockNativeCameraPermissionService.microphoneAuthorizationStatus,
        ).called(1);
        verify(
          mockNativeCameraPermissionService.requestMicrophonePermission,
        ).called(1);
        verifyNever(
          mockPermissionsService.checkMicrophoneStatus,
        );
        verifyNever(
          mockPermissionsService.requestMicrophonePermission,
        );
        verify(() => mockMediaService.setMicrophoneEnabled(true)).called(1);
        expect(bloc.state.errorMessage, isNull);

        await bloc.close();
      },
    );

    test(
      'turning the host microphone on on macOS surfaces a clear error when the native request is denied',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);

        final mockPermissionsService = _MockPermissionsService();
        final mockNativeCameraPermissionService =
            _MockNativeCameraPermissionService();
        when(
          mockNativeCameraPermissionService.microphoneAuthorizationStatus,
        ).thenAnswer(
          (_) async => NativeCameraAuthorizationStatus.notDetermined,
        );
        when(
          mockNativeCameraPermissionService.requestMicrophonePermission,
        ).thenAnswer((_) async => NativeCameraPermissionStatus.denied);

        final bloc = LiveRoomBloc(
          liveRepository: mockRepository,
          liveApiService: mockApiService,
          liveKitRoomService: mockMediaService,
          permissionsService: mockPermissionsService,
          nativeCameraPermissionService: mockNativeCameraPermissionService,
        );

        bloc.add(const LiveRoomJoinRequested(room: room, role: LiveRole.host));
        await _flush();

        sessionsController.add(<LiveSession>[liveSession]);
        await _flush();

        mediaController.add(
          const LiveMediaState(
            status: LiveMediaConnectionStatus.connected,
            canPublish: true,
          ),
        );
        await _flush();

        bloc.add(const ToggleMicrophoneRequested());
        await _flush();

        verify(
          mockNativeCameraPermissionService.microphoneAuthorizationStatus,
        ).called(1);
        verify(
          mockNativeCameraPermissionService.requestMicrophonePermission,
        ).called(1);
        verifyNever(() => mockMediaService.setMicrophoneEnabled(true));
        expect(
          bloc.state.errorMessage,
          'Microphone access is required to speak in the room.',
        );

        await bloc.close();
      },
    );

    test(
      'turning the host microphone on on macOS surfaces a launch-environment message when macOS blocks the prompt',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);

        final mockPermissionsService = _MockPermissionsService();
        final mockNativeCameraPermissionService =
            _MockNativeCameraPermissionService();
        when(
          mockNativeCameraPermissionService.microphoneAuthorizationStatus,
        ).thenAnswer(
          (_) async => NativeCameraAuthorizationStatus.notDetermined,
        );
        when(
          mockNativeCameraPermissionService.requestMicrophonePermission,
        ).thenAnswer((_) async => NativeCameraPermissionStatus.promptBlocked);

        final bloc = LiveRoomBloc(
          liveRepository: mockRepository,
          liveApiService: mockApiService,
          liveKitRoomService: mockMediaService,
          permissionsService: mockPermissionsService,
          nativeCameraPermissionService: mockNativeCameraPermissionService,
        );

        bloc.add(const LiveRoomJoinRequested(room: room, role: LiveRole.host));
        await _flush();

        sessionsController.add(<LiveSession>[liveSession]);
        await _flush();

        mediaController.add(
          const LiveMediaState(
            status: LiveMediaConnectionStatus.connected,
            canPublish: true,
          ),
        );
        await _flush();

        bloc.add(const ToggleMicrophoneRequested());
        await _flush();

        verify(
          mockNativeCameraPermissionService.microphoneAuthorizationStatus,
        ).called(1);
        verify(
          mockNativeCameraPermissionService.requestMicrophonePermission,
        ).called(1);
        verifyNever(() => mockMediaService.setMicrophoneEnabled(true));
        expect(
          bloc.state.errorMessage,
          'macOS blocked the microphone prompt for this terminal-launched build. Open Divine directly from Finder or Xcode, then try again.',
        );

        await bloc.close();
      },
    );

    test(
      'turning the host microphone on on macOS surfaces a settings message when access is denied',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);

        final mockPermissionsService = _MockPermissionsService();
        final mockNativeCameraPermissionService =
            _MockNativeCameraPermissionService();
        when(
          mockNativeCameraPermissionService.microphoneAuthorizationStatus,
        ).thenAnswer(
          (_) async => NativeCameraAuthorizationStatus.denied,
        );
        when(
          mockPermissionsService.checkMicrophoneStatus,
        ).thenAnswer((_) async => PermissionStatus.granted);
        when(
          mockPermissionsService.requestMicrophonePermission,
        ).thenAnswer((_) async => PermissionStatus.granted);

        final bloc = LiveRoomBloc(
          liveRepository: mockRepository,
          liveApiService: mockApiService,
          liveKitRoomService: mockMediaService,
          permissionsService: mockPermissionsService,
          nativeCameraPermissionService: mockNativeCameraPermissionService,
        );

        bloc.add(const LiveRoomJoinRequested(room: room, role: LiveRole.host));
        await _flush();

        sessionsController.add(<LiveSession>[liveSession]);
        await _flush();

        mediaController.add(
          const LiveMediaState(
            status: LiveMediaConnectionStatus.connected,
            canPublish: true,
          ),
        );
        await _flush();

        bloc.add(const ToggleMicrophoneRequested());
        await _flush();

        verify(
          mockNativeCameraPermissionService.microphoneAuthorizationStatus,
        ).called(1);
        verifyNever(
          mockPermissionsService.checkMicrophoneStatus,
        );
        verifyNever(
          mockPermissionsService.requestMicrophonePermission,
        );
        verifyNever(() => mockMediaService.setMicrophoneEnabled(true));
        expect(
          bloc.state.errorMessage,
          'Microphone access is blocked. Allow it in system settings.',
        );

        await bloc.close();
      },
    );

    test(
      'audience members promoted onto the stage reconnect as speakers and gain publish access',
      () async {
        final promotedSession = liveSession.copyWith(
          speakerPubkeys: const <String>[
            hostPubkey,
            speakerPubkey,
            audiencePubkey,
          ],
        );
        final bloc = LiveRoomBloc(
          liveRepository: mockRepository,
          liveApiService: mockApiService,
          liveKitRoomService: mockMediaService,
          currentUserPubkey: audiencePubkey,
        );

        bloc.add(
          const LiveRoomJoinRequested(room: room, role: LiveRole.audience),
        );
        await _flush();

        sessionsController.add(<LiveSession>[liveSession]);
        await _flush();

        expect(bloc.state.canPublish, isFalse);

        sessionsController.add(<LiveSession>[promotedSession]);
        await _flush();

        expect(bloc.state.role, LiveRole.speaker);
        expect(bloc.state.canPublish, isTrue);
        verify(
          () => mockApiService.fetchJoinToken(
            roomId: room.id,
            role: LiveRole.speaker,
          ),
        ).called(1);
        verify(() => mockMediaService.connect(speakerJoinToken)).called(1);

        await bloc.close();
      },
    );

    test(
      'host can promote and demote speakers while enforcing the publisher cap',
      () async {
        final bloc = LiveRoomBloc(
          liveRepository: mockRepository,
          liveApiService: mockApiService,
          liveKitRoomService: mockMediaService,
        );

        bloc.add(const LiveRoomJoinRequested(room: room, role: LiveRole.host));
        await _flush();

        sessionsController.add(<LiveSession>[liveSession]);
        await _flush();

        presenceController.add(<LivePresence>[
          hostPresence,
          speakerPresence,
          raisedHandPresence,
          audienceTwoPresence,
          audienceThreePresence,
        ]);
        await _flush();

        bloc
          ..add(const PromoteSpeakerRequested(audiencePubkey))
          ..add(const PromoteSpeakerRequested(audienceTwoPubkey));
        await _flush();

        expect(
          bloc.state.speakerPubkeys,
          containsAll(<String>[
            hostPubkey,
            speakerPubkey,
            audiencePubkey,
            audienceTwoPubkey,
          ]),
        );

        bloc.add(const PromoteSpeakerRequested(audienceThreePubkey));
        await _flush();

        expect(bloc.state.speakerPubkeys, isNot(contains(audienceThreePubkey)));
        expect(bloc.state.errorMessage, contains('4 active video speakers'));

        bloc.add(const DemoteSpeakerRequested(audiencePubkey));
        await _flush();
        bloc.add(const PromoteSpeakerRequested(audienceThreePubkey));
        await _flush();

        expect(bloc.state.speakerPubkeys, isNot(contains(audiencePubkey)));
        expect(bloc.state.speakerPubkeys, contains(audienceThreePubkey));

        verify(
          () => mockApiService.setParticipantRole(
            roomId: room.id,
            pubkey: audiencePubkey,
            role: LiveRole.speaker,
          ),
        ).called(1);
        verify(
          () => mockApiService.setParticipantRole(
            roomId: room.id,
            pubkey: audienceTwoPubkey,
            role: LiveRole.speaker,
          ),
        ).called(1);
        verify(
          () => mockApiService.setParticipantRole(
            roomId: room.id,
            pubkey: audiencePubkey,
            role: LiveRole.audience,
          ),
        ).called(1);
        verify(
          () => mockApiService.setParticipantRole(
            roomId: room.id,
            pubkey: audienceThreePubkey,
            role: LiveRole.speaker,
          ),
        ).called(1);

        await bloc.close();
      },
    );

    test('audience backgrounds cleanly and reconnects on foreground', () async {
      final bloc = LiveRoomBloc(
        liveRepository: mockRepository,
        liveApiService: mockApiService,
        liveKitRoomService: mockMediaService,
      );

      bloc.add(
        const LiveRoomJoinRequested(room: room, role: LiveRole.audience),
      );
      await _flush();

      sessionsController.add(<LiveSession>[liveSession]);
      await _flush();

      bloc
        ..add(const LiveRoomAppForegroundChanged(false))
        ..add(const LiveRoomAppForegroundChanged(true));
      await _flush();

      verify(
        () => mockApiService.fetchJoinToken(
          roomId: room.id,
          role: LiveRole.audience,
        ),
      ).called(1);
      verify(() => mockMediaService.disconnect()).called(1);
      verify(() => mockMediaService.connect(audienceJoinToken)).called(2);

      await bloc.close();
    });

    test(
      'audience reconnect fetches a fresh token after a stale-token failure',
      () async {
        const refreshedAudienceJoinToken = LiveRoomToken(
          token: 'audience-jwt-token-fresh',
          roomName: 'room-abc',
          participantIdentity: audiencePubkey,
          serverUrl: 'wss://livekit.example.com',
          canPublish: false,
        );
        var audienceTokenCalls = 0;
        var audienceConnectCalls = 0;
        when(
          () => mockApiService.fetchJoinToken(
            roomId: room.id,
            role: LiveRole.audience,
          ),
        ).thenAnswer((_) async {
          audienceTokenCalls += 1;
          return audienceTokenCalls == 1
              ? audienceJoinToken
              : refreshedAudienceJoinToken;
        });
        when(
          () => mockMediaService.connect(audienceJoinToken),
        ).thenAnswer((_) async {
          audienceConnectCalls += 1;
          if (audienceConnectCalls > 1) {
            throw Exception('stale token');
          }
        });
        when(
          () => mockMediaService.connect(refreshedAudienceJoinToken),
        ).thenAnswer((_) async {});

        final bloc = LiveRoomBloc(
          liveRepository: mockRepository,
          liveApiService: mockApiService,
          liveKitRoomService: mockMediaService,
        );

        bloc.add(
          const LiveRoomJoinRequested(room: room, role: LiveRole.audience),
        );
        await _flush();

        sessionsController.add(<LiveSession>[liveSession]);
        await _flush();

        bloc
          ..add(const LiveRoomAppForegroundChanged(false))
          ..add(const LiveRoomAppForegroundChanged(true));
        await _flush();

        verify(
          () => mockApiService.fetchJoinToken(
            roomId: room.id,
            role: LiveRole.audience,
          ),
        ).called(2);
        verify(
          () => mockMediaService.connect(refreshedAudienceJoinToken),
        ).called(1);

        await bloc.close();
      },
    );

    test(
      'joining a second live room disconnects the previous audience connection before reconnecting',
      () async {
        const secondHostPubkey =
            'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';
        const secondRoom = LiveRoom(
          id: 'room-two',
          hostPubkey: secondHostPubkey,
          title: 'Second room',
          summary: 'Another live room',
          imageUrl: null,
          relays: <String>[],
          visibility: LiveRoomVisibility.public,
        );
        final secondSession = LiveSession(
          id: 'session-two',
          roomId: secondRoom.id,
          hostPubkey: secondRoom.hostPubkey,
          status: LiveSessionStatus.live,
          startedAt: DateTime.utc(2026, 4, 6, 12, 30),
          endedAt: null,
          speakerPubkeys: const <String>[secondHostPubkey],
          audienceCount: 18,
        );
        const secondAudienceJoinToken = LiveRoomToken(
          token: 'audience-jwt-token-room-two',
          roomName: 'room-two',
          participantIdentity: audiencePubkey,
          serverUrl: 'wss://livekit.example.com',
          canPublish: false,
        );
        final secondSessionsController =
            StreamController<List<LiveSession>>.broadcast(sync: true);
        final secondPresenceController =
            StreamController<List<LivePresence>>.broadcast(sync: true);
        addTearDown(secondSessionsController.close);
        addTearDown(secondPresenceController.close);

        when(
          () => mockRepository.watchSessions(roomAddress: secondRoom.address),
        ).thenAnswer((_) => secondSessionsController.stream);
        when(
          () => mockRepository.watchPresence(
            sessionAddress: '30313:$secondHostPubkey:${secondSession.id}',
          ),
        ).thenAnswer((_) => secondPresenceController.stream);
        when(
          () => mockApiService.fetchJoinToken(
            roomId: secondRoom.id,
            role: LiveRole.audience,
          ),
        ).thenAnswer((_) async => secondAudienceJoinToken);
        when(
          () => mockMediaService.connect(secondAudienceJoinToken),
        ).thenAnswer((_) async {});

        final bloc = LiveRoomBloc(
          liveRepository: mockRepository,
          liveApiService: mockApiService,
          liveKitRoomService: mockMediaService,
          currentUserPubkey: audiencePubkey,
        );

        bloc.add(
          const LiveRoomJoinRequested(room: room, role: LiveRole.audience),
        );
        await _flush();

        sessionsController.add(<LiveSession>[liveSession]);
        await _flush();

        verify(() => mockMediaService.connect(audienceJoinToken)).called(1);

        bloc.add(
          const LiveRoomJoinRequested(
            room: secondRoom,
            role: LiveRole.audience,
          ),
        );
        await _flush();

        secondSessionsController.add(<LiveSession>[secondSession]);
        await _flush();

        verify(() => mockMediaService.disconnect()).called(1);
        verify(
          () => mockMediaService.connect(secondAudienceJoinToken),
        ).called(1);
        expect(bloc.state.room, secondRoom);
        expect(bloc.state.session, secondSession);

        await bloc.close();
      },
    );

    test(
      'joining a room with no live session disconnects any previous audience connection',
      () async {
        const secondHostPubkey =
            'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';
        const quietRoom = LiveRoom(
          id: 'room-quiet',
          hostPubkey: secondHostPubkey,
          title: 'Quiet room',
          summary: 'No one is live here yet',
          imageUrl: null,
          relays: <String>[],
          visibility: LiveRoomVisibility.public,
        );
        final quietSessionsController =
            StreamController<List<LiveSession>>.broadcast(sync: true);
        addTearDown(quietSessionsController.close);

        when(
          () => mockRepository.watchSessions(roomAddress: quietRoom.address),
        ).thenAnswer((_) => quietSessionsController.stream);

        final bloc = LiveRoomBloc(
          liveRepository: mockRepository,
          liveApiService: mockApiService,
          liveKitRoomService: mockMediaService,
          currentUserPubkey: audiencePubkey,
        );

        bloc.add(
          const LiveRoomJoinRequested(room: room, role: LiveRole.audience),
        );
        await _flush();

        sessionsController.add(<LiveSession>[liveSession]);
        await _flush();

        verify(() => mockMediaService.connect(audienceJoinToken)).called(1);

        bloc.add(
          const LiveRoomJoinRequested(room: quietRoom, role: LiveRole.audience),
        );
        await _flush();

        quietSessionsController.add(const <LiveSession>[]);
        await _flush();

        verify(() => mockMediaService.disconnect()).called(1);
        verifyNever(
          () => mockApiService.fetchJoinToken(
            roomId: quietRoom.id,
            role: LiveRole.audience,
          ),
        );
        expect(bloc.state.room, quietRoom);
        expect(bloc.state.session, isNull);

        await bloc.close();
      },
    );

    test('host can end the live session', () async {
      final bloc = LiveRoomBloc(
        liveRepository: mockRepository,
        liveApiService: mockApiService,
        liveKitRoomService: mockMediaService,
      );

      bloc.add(const LiveRoomJoinRequested(room: room, role: LiveRole.host));
      await _flush();

      sessionsController.add(<LiveSession>[liveSession]);
      await _flush();

      final endedStateFuture = bloc.stream.firstWhere(
        (state) => state.session?.status == LiveSessionStatus.ended,
      );
      bloc.add(const EndSessionRequested());
      await endedStateFuture;

      verify(
        () => mockApiService.endSession(
          roomId: room.id,
          sessionId: liveSession.id,
        ),
      ).called(1);
      expect(bloc.state.session?.status, LiveSessionStatus.ended);
      expect(bloc.state.session?.endedAt, isNotNull);

      await bloc.close();
    });

    test('host can publish room metadata updates', () async {
      final bloc = LiveRoomBloc(
        liveRepository: mockRepository,
        liveApiService: mockApiService,
        liveKitRoomService: mockMediaService,
      );

      bloc.add(const LiveRoomJoinRequested(room: room, role: LiveRole.host));
      await _flush();

      sessionsController.add(<LiveSession>[liveSession]);
      await _flush();

      bloc.add(
        const UpdateRoomMetadataRequested(
          title: 'New title',
          summary: 'Fresh summary',
          visibility: LiveRoomVisibility.private,
        ),
      );
      await _flush();

      verify(
        () => mockRepository.publishRoom(
          any(
            that: isA<LiveRoom>()
                .having((value) => value.title, 'title', 'New title')
                .having((value) => value.summary, 'summary', 'Fresh summary')
                .having(
                  (value) => value.visibility,
                  'visibility',
                  LiveRoomVisibility.private,
                ),
          ),
        ),
      ).called(1);
      expect(bloc.state.room?.title, 'New title');
      expect(bloc.state.room?.summary, 'Fresh summary');
      expect(bloc.state.room?.visibility, LiveRoomVisibility.private);

      await bloc.close();
    });

    test('host can approve and deny raised hands locally', () async {
      final bloc = LiveRoomBloc(
        liveRepository: mockRepository,
        liveApiService: mockApiService,
        liveKitRoomService: mockMediaService,
      );

      bloc.add(const LiveRoomJoinRequested(room: room, role: LiveRole.host));
      await _flush();

      sessionsController.add(<LiveSession>[liveSession]);
      await _flush();

      presenceController.add(<LivePresence>[
        hostPresence,
        speakerPresence,
        raisedHandPresence,
      ]);
      await _flush();

      bloc
        ..add(const DenyRaisedHandRequested(audiencePubkey))
        ..add(const ApproveRaisedHandRequested(audiencePubkey));
      await _flush();

      expect(bloc.state.raisedHands, isEmpty);
      expect(bloc.state.speakerPubkeys, contains(audiencePubkey));

      await bloc.close();
    });

    test('audience members can raise a hand through live presence', () async {
      final bloc = LiveRoomBloc(
        liveRepository: mockRepository,
        liveApiService: mockApiService,
        liveKitRoomService: mockMediaService,
        currentUserPubkey: audiencePubkey,
      );

      bloc.add(
        const LiveRoomJoinRequested(room: room, role: LiveRole.audience),
      );
      await _flush();

      sessionsController.add(<LiveSession>[liveSession]);
      await _flush();

      presenceController.add(<LivePresence>[hostPresence, speakerPresence]);
      await _flush();

      bloc.add(const ToggleHandRaiseRequested());
      await _flush();

      verify(
        () => mockRepository.publishPresence(
          sessionAddress: '30313:$hostPubkey:${liveSession.id}',
          role: LiveRole.audience,
          handRaised: true,
        ),
      ).called(1);
      expect(bloc.state.currentUserHandRaised, isTrue);
      expect(
        bloc.state.presence,
        contains(
          isA<LivePresence>()
              .having((value) => value.pubkey, 'pubkey', audiencePubkey)
              .having((value) => value.handRaised, 'handRaised', isTrue),
        ),
      );

      await bloc.close();
    });

    test(
      'host can hide participants locally without changing their room role',
      () async {
        final bloc = LiveRoomBloc(
          liveRepository: mockRepository,
          liveApiService: mockApiService,
          liveKitRoomService: mockMediaService,
        );

        bloc.add(const LiveRoomJoinRequested(room: room, role: LiveRole.host));
        await _flush();

        sessionsController.add(<LiveSession>[liveSession]);
        await _flush();

        presenceController.add(<LivePresence>[
          hostPresence,
          speakerPresence,
          raisedHandPresence,
        ]);
        await _flush();

        bloc.add(const HideParticipantLocallyRequested(speakerPubkey));
        await _flush();

        expect(bloc.state.hiddenParticipantPubkeys, contains(speakerPubkey));
        verifyNever(
          () => mockApiService.setParticipantRole(
            roomId: any(named: 'roomId'),
            pubkey: speakerPubkey,
            role: any(named: 'role'),
          ),
        );
        expect(bloc.state.visiblePresence, isNot(contains(speakerPresence)));
        expect(bloc.state.speakerPubkeys, isNot(contains(speakerPubkey)));

        await bloc.close();
      },
    );

    test('hosts stay connected when the app backgrounds', () async {
      final bloc = LiveRoomBloc(
        liveRepository: mockRepository,
        liveApiService: mockApiService,
        liveKitRoomService: mockMediaService,
      );

      bloc.add(const LiveRoomJoinRequested(room: room, role: LiveRole.host));
      await _flush();

      sessionsController.add(<LiveSession>[liveSession]);
      await _flush();

      bloc.add(const LiveRoomAppForegroundChanged(false));
      await _flush();

      verifyNever(() => mockMediaService.disconnect());

      await bloc.close();
    });
  });
}

Future<void> _flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}
