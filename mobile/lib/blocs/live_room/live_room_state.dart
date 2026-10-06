import 'package:equatable/equatable.dart';
import 'package:openvine/models/live/live_media_state.dart';
import 'package:openvine/models/live/live_presence.dart';
import 'package:openvine/models/live/live_role.dart';
import 'package:openvine/models/live/live_room.dart';
import 'package:openvine/models/live/live_session.dart';

enum LiveRoomStatus { initial, loading, ready, failure }

const int maxActiveVideoSpeakers = 4;

enum LiveRoomError {
  requestFailed,
  connectionFailed,
  subscriptionFailed,
  cameraBlocked,
  cameraRequired,
  cameraUnavailable,
  cameraPromptBlocked,
  microphoneBlocked,
  microphoneRequired,
  microphoneUnavailable,
  microphonePromptBlocked,
  speakerCapacityReached,
}

class LiveRoomState extends Equatable {
  const LiveRoomState({
    this.status = LiveRoomStatus.initial,
    this.room,
    this.session,
    this.role,
    this.presence = const <LivePresence>[],
    this.mediaState = const LiveMediaState(),
    this.error,
    this.stageSpeakerPubkeys,
    this.dismissedHandPubkeys = const <String>[],
    this.hiddenChatParticipantPubkeys = const <String>[],
    this.hiddenParticipantPubkeys = const <String>[],
    this.currentUserHandRaised = false,
  });

  final LiveRoomStatus status;
  final LiveRoom? room;
  final LiveSession? session;
  final LiveRole? role;
  final List<LivePresence> presence;
  final LiveMediaState mediaState;
  final LiveRoomError? error;
  final List<String>? stageSpeakerPubkeys;
  final List<String> dismissedHandPubkeys;
  final List<String> hiddenChatParticipantPubkeys;
  final List<String> hiddenParticipantPubkeys;
  final bool currentUserHandRaised;

  bool get canModerate => role?.canModerate ?? false;

  bool get canPublish => role?.canPublish ?? false;

  List<LivePresence> get visiblePresence {
    if (hiddenParticipantPubkeys.isEmpty) {
      return presence;
    }

    return presence
        .where((member) => !hiddenParticipantPubkeys.contains(member.pubkey))
        .toList(growable: false);
  }

  String? get sessionAddress {
    final currentRoom = room;
    final currentSession = session;
    if (currentRoom == null || currentSession == null) {
      return null;
    }

    return '30313:${currentRoom.hostPubkey}:${currentSession.id}';
  }

  List<String> get speakerPubkeys {
    final stageSpeakerPubkeys = this.stageSpeakerPubkeys;
    if (stageSpeakerPubkeys != null) {
      return stageSpeakerPubkeys
          .where((pubkey) => !hiddenParticipantPubkeys.contains(pubkey))
          .toList(growable: false);
    }

    final speakers = <String>{};
    final currentSession = session;
    if (currentSession != null) {
      speakers.addAll(currentSession.speakerPubkeys);
    }
    speakers.removeAll(hiddenParticipantPubkeys);
    for (final member in visiblePresence) {
      if (member.role.canPublish) {
        speakers.add(member.pubkey);
      }
    }
    return speakers.toList(growable: false);
  }

  List<LivePresence> get raisedHands {
    return visiblePresence
        .where(
          (member) =>
              member.handRaised &&
              !speakerPubkeys.contains(member.pubkey) &&
              !dismissedHandPubkeys.contains(member.pubkey),
        )
        .toList(growable: false);
  }

  bool get speakerCapacityReached =>
      speakerPubkeys.length >= maxActiveVideoSpeakers;

  LiveRoomState copyWith({
    LiveRoomStatus? status,
    LiveRoom? room,
    LiveSession? session,
    bool clearSession = false,
    LiveRole? role,
    List<LivePresence>? presence,
    LiveMediaState? mediaState,
    LiveRoomError? error,
    bool clearError = false,
    List<String>? stageSpeakerPubkeys,
    bool clearStageSpeakerPubkeys = false,
    List<String>? dismissedHandPubkeys,
    bool clearDismissedHandPubkeys = false,
    List<String>? hiddenChatParticipantPubkeys,
    bool clearHiddenChatParticipantPubkeys = false,
    List<String>? hiddenParticipantPubkeys,
    bool clearHiddenParticipantPubkeys = false,
    bool? currentUserHandRaised,
  }) {
    return LiveRoomState(
      status: status ?? this.status,
      room: room ?? this.room,
      session: clearSession ? null : (session ?? this.session),
      role: role ?? this.role,
      presence: presence ?? this.presence,
      mediaState: mediaState ?? this.mediaState,
      error: clearError ? null : (error ?? this.error),
      stageSpeakerPubkeys: clearStageSpeakerPubkeys
          ? null
          : (stageSpeakerPubkeys ?? this.stageSpeakerPubkeys),
      dismissedHandPubkeys: clearDismissedHandPubkeys
          ? const <String>[]
          : (dismissedHandPubkeys ?? this.dismissedHandPubkeys),
      hiddenChatParticipantPubkeys: clearHiddenChatParticipantPubkeys
          ? const <String>[]
          : (hiddenChatParticipantPubkeys ?? this.hiddenChatParticipantPubkeys),
      hiddenParticipantPubkeys: clearHiddenParticipantPubkeys
          ? const <String>[]
          : (hiddenParticipantPubkeys ?? this.hiddenParticipantPubkeys),
      currentUserHandRaised:
          currentUserHandRaised ?? this.currentUserHandRaised,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    status,
    room,
    session,
    role,
    presence,
    mediaState,
    error,
    stageSpeakerPubkeys,
    dismissedHandPubkeys,
    hiddenChatParticipantPubkeys,
    hiddenParticipantPubkeys,
    currentUserHandRaised,
  ];
}
