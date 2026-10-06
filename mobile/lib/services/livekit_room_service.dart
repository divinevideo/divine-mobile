import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:openvine/models/live/live_room_token.dart';

@immutable
class LiveStageParticipant extends Equatable {
  const LiveStageParticipant({
    required this.identity,
    required this.isLocal,
    this.videoTrack,
    this.isMicrophoneEnabled = false,
  });

  final String identity;
  final bool isLocal;
  final lk.VideoTrack? videoTrack;
  final bool isMicrophoneEnabled;

  bool get hasVideo => videoTrack != null;

  @override
  List<Object?> get props => <Object?>[
    identity,
    isLocal,
    videoTrack,
    isMicrophoneEnabled,
  ];
}

enum LiveMediaConnectionStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
  audioOnly,
  failed,
}

@immutable
class LiveMediaState extends Equatable {
  const LiveMediaState({
    this.status = LiveMediaConnectionStatus.disconnected,
    this.canPublish = false,
    this.requestedCameraEnabled = false,
    this.requestedMicrophoneEnabled = false,
    this.cameraBusy = false,
    this.microphoneBusy = false,
    this.cameraEnabled = false,
    this.microphoneEnabled = false,
    this.localParticipantIdentity,
    this.stageParticipants = const <LiveStageParticipant>[],
  });

  final LiveMediaConnectionStatus status;
  final bool canPublish;
  final bool requestedCameraEnabled;
  final bool requestedMicrophoneEnabled;
  final bool cameraBusy;
  final bool microphoneBusy;
  final bool cameraEnabled;
  final bool microphoneEnabled;
  final String? localParticipantIdentity;
  final List<LiveStageParticipant> stageParticipants;

  LiveMediaState copyWith({
    LiveMediaConnectionStatus? status,
    bool? canPublish,
    bool? requestedCameraEnabled,
    bool? requestedMicrophoneEnabled,
    bool? cameraBusy,
    bool? microphoneBusy,
    bool? cameraEnabled,
    bool? microphoneEnabled,
    String? localParticipantIdentity,
    bool clearLocalParticipantIdentity = false,
    List<LiveStageParticipant>? stageParticipants,
  }) {
    return LiveMediaState(
      status: status ?? this.status,
      canPublish: canPublish ?? this.canPublish,
      requestedCameraEnabled:
          requestedCameraEnabled ?? this.requestedCameraEnabled,
      requestedMicrophoneEnabled:
          requestedMicrophoneEnabled ?? this.requestedMicrophoneEnabled,
      cameraBusy: cameraBusy ?? this.cameraBusy,
      microphoneBusy: microphoneBusy ?? this.microphoneBusy,
      cameraEnabled: cameraEnabled ?? this.cameraEnabled,
      microphoneEnabled: microphoneEnabled ?? this.microphoneEnabled,
      localParticipantIdentity: clearLocalParticipantIdentity
          ? null
          : (localParticipantIdentity ?? this.localParticipantIdentity),
      stageParticipants: stageParticipants ?? this.stageParticipants,
    );
  }

  @override
  List<Object?> get props => [
    status,
    canPublish,
    requestedCameraEnabled,
    requestedMicrophoneEnabled,
    cameraBusy,
    microphoneBusy,
    cameraEnabled,
    microphoneEnabled,
    localParticipantIdentity,
    stageParticipants,
  ];
}

enum LiveKitRoomClientEvent {
  connected,
  reconnecting,
  disconnected,
  participantsChanged,
}

abstract class LiveKitRoomClient {
  Stream<LiveKitRoomClientEvent> get events;

  List<LiveStageParticipant> get currentStageParticipants;

  Future<void> prepareConnection(String serverUrl, String token);

  Future<void> connect(
    String serverUrl,
    String token, {
    bool disableFastConnectPublish = false,
  });

  Future<void> disconnect();

  Future<bool> setCameraEnabled(bool enabled);

  Future<bool> setMicrophoneEnabled(bool enabled);

  Future<void> switchCamera();

  Future<void> enableAudioOnly();

  Future<void> dispose();
}

class LiveKitRoomService {
  LiveKitRoomService({
    LiveKitRoomClient Function()? clientFactory,
  }) : _client = (clientFactory ?? _defaultClientFactory).call() {
    _eventsSubscription = _client.events.listen(_handleClientEvent);
  }

  final LiveKitRoomClient _client;
  final StreamController<LiveMediaState> _stateController =
      StreamController<LiveMediaState>.broadcast(sync: true);
  late final StreamSubscription<LiveKitRoomClientEvent> _eventsSubscription;

  LiveMediaState _currentState = const LiveMediaState();
  bool _isDisposed = false;
  bool _disconnectRequested = false;

  static LiveKitRoomClient _defaultClientFactory() => _SdkLiveKitRoomClient();

  LiveMediaState get currentState => _currentState;

  Stream<LiveMediaState> watchState() {
    late final StreamController<LiveMediaState> controller;
    StreamSubscription<LiveMediaState>? subscription;

    controller = StreamController<LiveMediaState>(
      sync: true,
      onListen: () {
        controller.add(_currentState);
        subscription = _stateController.stream.listen(
          controller.add,
          onError: controller.addError,
          onDone: controller.close,
        );
      },
      onCancel: () async {
        await subscription?.cancel();
      },
    );

    return controller.stream;
  }

  Future<void> connect(LiveRoomToken token) async {
    _disconnectRequested = false;
    _updateState(
      LiveMediaState(
        status: LiveMediaConnectionStatus.connecting,
        canPublish: token.canPublish,
        localParticipantIdentity: token.participantIdentity,
      ),
    );

    try {
      await _client.prepareConnection(token.serverUrl, token.token);
      await _client.connect(
        token.serverUrl,
        token.token,
        disableFastConnectPublish: true,
      );
      final localStageParticipant = _localStageParticipantSnapshot();
      final publishedCameraEnabled = localStageParticipant?.hasVideo ?? false;
      final publishedMicrophoneEnabled =
          localStageParticipant?.isMicrophoneEnabled ?? false;
      _refreshStageParticipants(
        _currentState.copyWith(
          status: _connectedStatusForTracks(
            cameraEnabled: publishedCameraEnabled,
            microphoneEnabled: publishedMicrophoneEnabled,
          ),
          requestedCameraEnabled: publishedCameraEnabled,
          requestedMicrophoneEnabled: publishedMicrophoneEnabled,
          cameraBusy: false,
          microphoneBusy: false,
        ),
      );
    } catch (_) {
      _updateState(
        LiveMediaState(
          status: LiveMediaConnectionStatus.failed,
          canPublish: token.canPublish,
          localParticipantIdentity: token.participantIdentity,
        ),
      );
      rethrow;
    }
  }

  Future<void> publishLocalTracks({
    required bool cameraEnabled,
    required bool microphoneEnabled,
  }) async {
    if (!_currentState.canPublish) {
      return;
    }

    await setCameraEnabled(cameraEnabled);
    await setMicrophoneEnabled(microphoneEnabled);
  }

  Future<void> setCameraEnabled(bool enabled) async {
    if (!_currentState.canPublish) {
      return;
    }

    if (enabled) {
      _updateState(
        _currentState.copyWith(
          requestedCameraEnabled: true,
          cameraBusy: true,
        ),
      );
    }

    final applied = await _client.setCameraEnabled(enabled);
    if (enabled && !applied) {
      _refreshStageParticipants(
        _currentState.copyWith(
          requestedCameraEnabled: false,
          cameraBusy: false,
          status: _connectedStatusForTracks(
            cameraEnabled: false,
            microphoneEnabled: _currentState.microphoneEnabled,
          ),
        ),
      );
      throw StateError('Unable to start the camera right now.');
    }

    _refreshStageParticipants(
      _currentState.copyWith(
        status: _localTrackStatus(
          cameraEnabled: enabled,
          microphoneEnabled: _currentState.requestedMicrophoneEnabled,
        ),
        requestedCameraEnabled: enabled,
        cameraBusy: enabled,
      ),
    );
  }

  Future<void> setMicrophoneEnabled(bool enabled) async {
    if (!_currentState.canPublish) {
      return;
    }

    if (enabled) {
      _updateState(
        _currentState.copyWith(
          requestedMicrophoneEnabled: true,
          microphoneBusy: true,
        ),
      );
    }

    final applied = await _client.setMicrophoneEnabled(enabled);
    if (enabled && !applied) {
      _refreshStageParticipants(
        _currentState.copyWith(
          requestedMicrophoneEnabled: false,
          microphoneBusy: false,
          status: _connectedStatusForTracks(
            cameraEnabled: _currentState.cameraEnabled,
            microphoneEnabled: false,
          ),
        ),
      );
      throw StateError('Unable to start the microphone right now.');
    }

    _refreshStageParticipants(
      _currentState.copyWith(
        status: _localTrackStatus(
          cameraEnabled: _currentState.requestedCameraEnabled,
          microphoneEnabled: enabled,
        ),
        requestedMicrophoneEnabled: enabled,
        microphoneBusy: enabled,
      ),
    );
  }

  Future<void> switchCamera() async {
    if (!_currentState.canPublish) {
      return;
    }

    await _client.switchCamera();
  }

  Future<void> enableAudioOnly() async {
    if (!_currentState.canPublish) {
      return;
    }

    await _client.setCameraEnabled(false);
    await _client.setMicrophoneEnabled(true);
    _refreshStageParticipants(
      _currentState.copyWith(
        status: LiveMediaConnectionStatus.audioOnly,
        requestedCameraEnabled: false,
        requestedMicrophoneEnabled: true,
        cameraBusy: false,
        microphoneBusy: false,
      ),
    );
  }

  Future<void> disconnect() async {
    _disconnectRequested = true;
    try {
      await _client.disconnect();
    } finally {
      _updateState(const LiveMediaState());
    }
  }

  Future<void> dispose() async {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;

    await _eventsSubscription.cancel();
    await _client.dispose();
    await _stateController.close();
  }

  void _handleClientEvent(LiveKitRoomClientEvent event) {
    switch (event) {
      case LiveKitRoomClientEvent.connected:
        _disconnectRequested = false;
        _refreshStageParticipants(
          _currentState.copyWith(
            status: _connectedStatusForTracks(
              cameraEnabled: _currentState.requestedCameraEnabled,
              microphoneEnabled: _currentState.requestedMicrophoneEnabled,
            ),
          ),
        );
      case LiveKitRoomClientEvent.reconnecting:
        _updateState(
          _currentState.copyWith(
            status: LiveMediaConnectionStatus.reconnecting,
          ),
        );
      case LiveKitRoomClientEvent.disconnected:
        if (_disconnectRequested) {
          _updateState(const LiveMediaState());
          return;
        }
        _updateState(
          _currentState.copyWith(
            status: LiveMediaConnectionStatus.failed,
            requestedCameraEnabled: false,
            requestedMicrophoneEnabled: false,
            cameraBusy: false,
            microphoneBusy: false,
            cameraEnabled: false,
            microphoneEnabled: false,
            stageParticipants: const <LiveStageParticipant>[],
          ),
        );
      case LiveKitRoomClientEvent.participantsChanged:
        _refreshStageParticipants(_currentState);
    }
  }

  void _refreshStageParticipants(LiveMediaState nextState) {
    final localStageParticipant = _localStageParticipantSnapshot();
    final publishedCameraEnabled = localStageParticipant?.hasVideo ?? false;
    final publishedMicrophoneEnabled =
        localStageParticipant?.isMicrophoneEnabled ?? false;
    _updateState(
      nextState.copyWith(
        cameraBusy:
            nextState.cameraBusy &&
            nextState.requestedCameraEnabled &&
            !publishedCameraEnabled,
        microphoneBusy:
            nextState.microphoneBusy &&
            nextState.requestedMicrophoneEnabled &&
            !publishedMicrophoneEnabled,
        cameraEnabled: publishedCameraEnabled,
        microphoneEnabled: publishedMicrophoneEnabled,
        stageParticipants: List<LiveStageParticipant>.unmodifiable(
          _client.currentStageParticipants,
        ),
      ),
    );
  }

  void _updateState(LiveMediaState nextState) {
    if (_isDisposed || _stateController.isClosed) {
      return;
    }

    _currentState = nextState;
    _stateController.add(nextState);
  }

  LiveMediaConnectionStatus _localTrackStatus({
    required bool cameraEnabled,
    required bool microphoneEnabled,
  }) {
    final currentStatus = _currentState.status;
    if (currentStatus == LiveMediaConnectionStatus.connecting ||
        currentStatus == LiveMediaConnectionStatus.reconnecting ||
        currentStatus == LiveMediaConnectionStatus.failed ||
        currentStatus == LiveMediaConnectionStatus.disconnected) {
      return currentStatus;
    }

    if (!cameraEnabled && microphoneEnabled) {
      return LiveMediaConnectionStatus.audioOnly;
    }

    return LiveMediaConnectionStatus.connected;
  }

  LiveStageParticipant? _localStageParticipantSnapshot() {
    for (final participant in _client.currentStageParticipants) {
      if (participant.isLocal) {
        return participant;
      }
    }

    return null;
  }

  LiveMediaConnectionStatus _connectedStatusForTracks({
    required bool cameraEnabled,
    required bool microphoneEnabled,
  }) {
    if (!cameraEnabled && microphoneEnabled) {
      return LiveMediaConnectionStatus.audioOnly;
    }

    return LiveMediaConnectionStatus.connected;
  }
}

class _SdkLiveKitRoomClient implements LiveKitRoomClient {
  _SdkLiveKitRoomClient({
    lk.Room? room,
  }) : _room = room ?? lk.Room() {
    _roomEventsListener = _room.createListener();
    _roomEventsListener.on<lk.RoomConnectedEvent>(
      (_) => _eventsController.add(LiveKitRoomClientEvent.connected),
    );
    _roomEventsListener.on<lk.RoomReconnectedEvent>(
      (_) => _eventsController.add(LiveKitRoomClientEvent.connected),
    );
    _roomEventsListener.on<lk.RoomReconnectingEvent>(
      (_) => _eventsController.add(LiveKitRoomClientEvent.reconnecting),
    );
    _roomEventsListener.on<lk.RoomDisconnectedEvent>(
      (_) => _eventsController.add(LiveKitRoomClientEvent.disconnected),
    );
    _roomEventsListener.on<lk.ParticipantConnectedEvent>(
      (_) => _eventsController.add(LiveKitRoomClientEvent.participantsChanged),
    );
    _roomEventsListener.on<lk.ParticipantDisconnectedEvent>(
      (_) => _eventsController.add(LiveKitRoomClientEvent.participantsChanged),
    );
    _roomEventsListener.on<lk.TrackPublishedEvent>(
      (_) => _eventsController.add(LiveKitRoomClientEvent.participantsChanged),
    );
    _roomEventsListener.on<lk.TrackUnpublishedEvent>(
      (_) => _eventsController.add(LiveKitRoomClientEvent.participantsChanged),
    );
    _roomEventsListener.on<lk.LocalTrackPublishedEvent>(
      (_) => _eventsController.add(LiveKitRoomClientEvent.participantsChanged),
    );
    _roomEventsListener.on<lk.LocalTrackUnpublishedEvent>(
      (_) => _eventsController.add(LiveKitRoomClientEvent.participantsChanged),
    );
    _roomEventsListener.on<lk.TrackSubscribedEvent>(
      (_) => _eventsController.add(LiveKitRoomClientEvent.participantsChanged),
    );
    _roomEventsListener.on<lk.TrackUnsubscribedEvent>(
      (_) => _eventsController.add(LiveKitRoomClientEvent.participantsChanged),
    );
    _roomEventsListener.on<lk.TrackMutedEvent>(
      (_) => _eventsController.add(LiveKitRoomClientEvent.participantsChanged),
    );
    _roomEventsListener.on<lk.TrackUnmutedEvent>(
      (_) => _eventsController.add(LiveKitRoomClientEvent.participantsChanged),
    );
  }

  final lk.Room _room;
  final StreamController<LiveKitRoomClientEvent> _eventsController =
      StreamController<LiveKitRoomClientEvent>.broadcast();
  late final lk.EventsListener<lk.RoomEvent> _roomEventsListener;

  @override
  Stream<LiveKitRoomClientEvent> get events => _eventsController.stream;

  @override
  List<LiveStageParticipant> get currentStageParticipants {
    final participants = <LiveStageParticipant>[];
    final localParticipant = _room.localParticipant;
    if (localParticipant != null) {
      final localSnapshot = _toStageParticipant(
        localParticipant,
        isLocal: true,
      );
      if (localSnapshot != null) {
        participants.add(localSnapshot);
      }
    }

    final remoteParticipants = _room.remoteParticipants.values.toList()
      ..sort((left, right) => left.identity.compareTo(right.identity));
    for (final participant in remoteParticipants) {
      final snapshot = _toStageParticipant(participant, isLocal: false);
      if (snapshot != null) {
        participants.add(snapshot);
      }
    }

    return participants;
  }

  @override
  Future<void> prepareConnection(String serverUrl, String token) {
    return _room.prepareConnection(serverUrl, token);
  }

  @override
  Future<void> connect(
    String serverUrl,
    String token, {
    bool disableFastConnectPublish = false,
  }) {
    return _room.connect(
      serverUrl,
      token,
      fastConnectOptions: disableFastConnectPublish
          ? lk.FastConnectOptions()
          : null,
    );
  }

  @override
  Future<void> disconnect() {
    return _room.disconnect();
  }

  @override
  Future<bool> setCameraEnabled(bool enabled) async {
    final participant = _room.localParticipant;
    if (participant == null) {
      return false;
    }

    final publication = await participant.setCameraEnabled(enabled);
    if (!enabled) {
      return true;
    }

    return publication != null;
  }

  @override
  Future<bool> setMicrophoneEnabled(bool enabled) async {
    final participant = _room.localParticipant;
    if (participant == null) {
      return false;
    }

    final publication = await participant.setMicrophoneEnabled(enabled);
    if (!enabled) {
      return true;
    }

    return publication != null;
  }

  @override
  Future<void> switchCamera() async {
    final devices = await lk.Hardware.instance.videoInputs();
    if (devices.length < 2) {
      return;
    }

    final currentDeviceId =
        lk.Hardware.instance.selectedVideoInput?.deviceId ??
        _room.roomOptions.defaultCameraCaptureOptions.deviceId;
    final currentIndex = devices.indexWhere(
      (device) => device.deviceId == currentDeviceId,
    );
    final nextIndex = currentIndex == -1
        ? 0
        : (currentIndex + 1) % devices.length;

    await _room.setVideoInputDevice(devices[nextIndex]);
  }

  @override
  Future<void> enableAudioOnly() async {
    final participant = _room.localParticipant;
    if (participant == null) {
      return;
    }

    await participant.setCameraEnabled(false);
    await participant.setMicrophoneEnabled(true);
  }

  @override
  Future<void> dispose() async {
    await _roomEventsListener.dispose();
    if (!_eventsController.isClosed) {
      await _eventsController.close();
    }
    await _room.dispose();
  }

  LiveStageParticipant? _toStageParticipant(
    lk.Participant participant, {
    required bool isLocal,
  }) {
    final videoTrack = _firstEnabledVideoTrack(participant);
    final microphoneEnabled = _hasEnabledMicrophone(participant);
    if (videoTrack == null && !microphoneEnabled) {
      return null;
    }

    return LiveStageParticipant(
      identity: participant.identity,
      isLocal: isLocal,
      videoTrack: videoTrack,
      isMicrophoneEnabled: microphoneEnabled,
    );
  }

  lk.VideoTrack? _firstEnabledVideoTrack(lk.Participant participant) {
    for (final publication in participant.videoTrackPublications) {
      final track = publication.track;
      if (publication.source == lk.TrackSource.camera &&
          track is lk.VideoTrack &&
          !publication.muted) {
        return track;
      }
    }

    for (final publication in participant.videoTrackPublications) {
      final track = publication.track;
      if (track is lk.VideoTrack && !publication.muted) {
        return track;
      }
    }

    return null;
  }

  bool _hasEnabledMicrophone(lk.Participant participant) {
    for (final publication in participant.audioTrackPublications) {
      if (publication.source == lk.TrackSource.microphone) {
        return publication.track != null && !publication.muted;
      }
    }

    for (final publication in participant.audioTrackPublications) {
      if (publication.track != null && !publication.muted) {
        return true;
      }
    }

    return false;
  }
}
