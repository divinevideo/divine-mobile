part of 'collab_room_cubit.dart';

/// Whether the room is known yet.
enum CollabRoomStatus {
  /// Reading the room from the DM history.
  loading,

  /// The room is in [CollabRoomState.room].
  ready,

  /// The account knows no such room.
  missing,
}

/// The last thing the user asked the room to do.
enum CollabRoomAction {
  /// Nothing yet.
  none,

  /// Join, as an invitee.
  join,

  /// Turn the invite down.
  decline,

  /// Leave, as a member.
  leave,

  /// Start filming, as the author.
  start,

  /// Change the room's layout or members, as the author.
  update,

  /// Call the room off, as the author.
  cancel,
}

/// How the last [CollabRoomAction] went.
enum CollabRoomActionStatus {
  /// No action running.
  idle,

  /// The action is being sent.
  busy,

  /// The action could not be delivered.
  failed,
}

/// How putting the parts together is going.
enum CollabRoomComposeStatus {
  /// Not started.
  idle,

  /// Downloading the parts and rendering the video.
  running,

  /// The video is in [CollabRoomState.composedClip].
  done,

  /// A part could not be read or the render failed.
  failed,
}

/// A part's video, decrypted on this device, and a still of it for its cell.
typedef CollabRoomPartFile = ({
  String fileHash,
  String path,
  String? thumbnailPath,
});

/// State of [CollabRoomCubit].
class CollabRoomState extends Equatable {
  /// Creates a state.
  const CollabRoomState({
    this.status = CollabRoomStatus.loading,
    this.room,
    this.layout,
    this.soundPubkey,
    this.action = CollabRoomAction.none,
    this.actionStatus = CollabRoomActionStatus.idle,
    this.partFiles = const {},
    this.fetchingParts = const {},
    this.composeStatus = CollabRoomComposeStatus.idle,
    this.composedClip,
    this.selectedSeat,
    this.pendingSeats,
    this.lobbyRevision,
  });

  /// Whether the room is known.
  final CollabRoomStatus status;

  /// The room, once known.
  final CollabRoom? room;

  /// The layout the author is about to film in. Follows the room's own once
  /// filming started.
  final SplitScreenLayoutPreset? layout;

  /// Whose sound the author picked for the video; the room's own until then.
  final String? soundPubkey;

  /// The last action asked for.
  final CollabRoomAction action;

  /// How [action] went.
  final CollabRoomActionStatus actionStatus;

  /// The parts read on this device, by pubkey.
  final Map<String, CollabRoomPartFile> partFiles;

  /// File hashes of the parts being read.
  final Set<String> fetchingParts;

  /// How putting the parts together is going.
  final CollabRoomComposeStatus composeStatus;

  /// The finished video, once [composeStatus] is done.
  final DivineVideoClip? composedClip;

  /// The seat the author selected to swap, waiting for the second one.
  final int? selectedSeat;

  /// Who sits where in the lobby, by pubkey in cell order, ahead of the
  /// room's last snapshot: the author's swaps until they are published, and
  /// for everyone else what the author's call said before its snapshot came.
  final List<String>? pendingSeats;

  /// The newest snapshot revision the lobby builds on. On the author's device
  /// the newest it published; elsewhere the one the author's call message
  /// built on, so a snapshot past it replaces [pendingSeats] and the hinted
  /// layout.
  final int? lobbyRevision;

  /// The people who fill a cell in the lobby, in cell order, with
  /// [pendingSeats] applied: whoever it names first, then anyone it does not
  /// know in the room's own order.
  List<CollabRoomMember> get lobbySeats {
    final seats = room?.seats ?? const <CollabRoomMember>[];
    final pending = pendingSeats;
    if (pending == null) return seats;
    final byPubkey = {for (final member in seats) member.pubkey: member};
    return [
      for (final pubkey in pending) ?byPubkey[pubkey],
      ...seats.where((member) => !pending.contains(member.pubkey)),
    ];
  }

  /// [lobbySeats] as pubkeys.
  List<String> get lobbySeatOrder => [
    for (final member in lobbySeats) member.pubkey,
  ];

  /// The revision the next snapshot the author publishes takes: past every
  /// one it published before, even those not back from the relays yet.
  int get nextRevision =>
      math.max(room?.snapshot.revision ?? 0, lobbyRevision ?? 0) + 1;

  /// Whose sound the video plays.
  String? get effectiveSoundPubkey => soundPubkey ?? room?.soundPubkey;

  /// The layouts the room's current number of people fits.
  List<SplitScreenLayoutPreset> get layoutChoices =>
      collabRoomLayoutsFor(room?.participants.length ?? 0);

  /// Whether the author can start filming.
  bool get canStart {
    final room = this.room;
    return room != null &&
        room.isAuthor &&
        room.phase == CollabRoomPhase.lobby &&
        room.participants.length >= collabRoomMinParticipants &&
        layout?.cellCount == room.participants.length &&
        actionStatus != CollabRoomActionStatus.busy;
  }

  /// Whether the room's layout fits everyone still in it.
  bool get layoutFits {
    final room = this.room;
    final count = room?.layoutPreset?.cellCount;
    if (room == null || count == null) return false;
    final cells = room.participants.map((member) => member.cell).toList();
    return cells.length == count &&
        cells.toSet().length == count &&
        cells.every((cell) => cell != null && cell >= 0 && cell < count);
  }

  /// Whether the author can put the video together.
  bool get canCompose {
    final room = this.room;
    return room != null &&
        room.isAuthor &&
        room.phase == CollabRoomPhase.recording &&
        layoutFits &&
        room.allPartsIn &&
        composeStatus != CollabRoomComposeStatus.running;
  }

  /// Whether the author ended the room for this account: called it off, or
  /// took the account out of it.
  bool get endedByHost {
    final room = this.room;
    if (room == null || room.isAuthor) return false;
    return room.phase == CollabRoomPhase.cancelled ||
        room.me?.status == CollabRoomMemberStatus.removed;
  }

  /// The video the author posted, once they did.
  AId? get postedVideo {
    final address = room?.snapshot.videoAddress;
    return address == null ? null : AId.fromString(address);
  }

  /// Returns a copy with the given fields replaced.
  CollabRoomState copyWith({
    CollabRoomStatus? status,
    CollabRoom? room,
    SplitScreenLayoutPreset? layout,
    bool clearLayout = false,
    String? soundPubkey,
    CollabRoomAction? action,
    CollabRoomActionStatus? actionStatus,
    Map<String, CollabRoomPartFile>? partFiles,
    Set<String>? fetchingParts,
    CollabRoomComposeStatus? composeStatus,
    DivineVideoClip? composedClip,
    int? selectedSeat,
    bool clearSelectedSeat = false,
    List<String>? pendingSeats,
    bool clearPendingSeats = false,
    int? lobbyRevision,
  }) => CollabRoomState(
    status: status ?? this.status,
    room: room ?? this.room,
    layout: clearLayout ? null : layout ?? this.layout,
    soundPubkey: soundPubkey ?? this.soundPubkey,
    action: action ?? this.action,
    actionStatus: actionStatus ?? this.actionStatus,
    partFiles: partFiles ?? this.partFiles,
    fetchingParts: fetchingParts ?? this.fetchingParts,
    composeStatus: composeStatus ?? this.composeStatus,
    composedClip: composedClip ?? this.composedClip,
    selectedSeat: clearSelectedSeat ? null : selectedSeat ?? this.selectedSeat,
    pendingSeats: clearPendingSeats ? null : pendingSeats ?? this.pendingSeats,
    lobbyRevision: lobbyRevision ?? this.lobbyRevision,
  );

  @override
  List<Object?> get props => [
    status,
    room,
    layout,
    soundPubkey,
    action,
    actionStatus,
    partFiles,
    fetchingParts,
    composeStatus,
    composedClip,
    selectedSeat,
    pendingSeats,
    lobbyRevision,
  ];
}
