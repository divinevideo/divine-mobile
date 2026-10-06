import 'package:equatable/equatable.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:meta/meta.dart';

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
