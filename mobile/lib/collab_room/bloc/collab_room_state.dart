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

  /// Bring the others up to what the author's device knows, as the author:
  /// nobody tapped anything, so a failure is retried rather than reported.
  sync,
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
    this.pickedGap,
    this.pickedBorderColor,
    this.pickedArrangement,
    this.pickedPartLength,
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

  /// The gap the author set in the lobby, ahead of the room's snapshot.
  final double? pickedGap;

  /// The gap colour the author picked in the lobby, ahead of the room's
  /// snapshot.
  final Color? pickedBorderColor;

  /// How the author wants the parts to come together, ahead of the room's
  /// snapshot.
  final CollabRoomArrangement? pickedArrangement;

  /// The part length the author picked in the lobby, ahead of the room's
  /// snapshot.
  final Duration? pickedPartLength;

  /// Whether the author's lobby picks lead: on the author's device, before
  /// filming starts. Everyone else follows the room's snapshot.
  bool get _picksLead {
    final room = this.room;
    return room != null && room.isAuthor && room.phase == CollabRoomPhase.lobby;
  }

  /// Space between the cells, as a fraction of the frame's shorter side.
  double get gap =>
      (_picksLead ? pickedGap : null) ?? room?.cellGap ?? collabRoomCellGap;

  /// The colour of the gaps between the cells.
  Color get borderColor =>
      (_picksLead ? pickedBorderColor : null) ??
      room?.borderColor ??
      collabRoomBorderColor;

  /// How the parts come together.
  CollabRoomArrangement get arrangement =>
      (_picksLead ? pickedArrangement : null) ??
      room?.arrangement ??
      CollabRoomArrangement.sideBySide;

  /// Whether the parts play one after another.
  bool get inSeries => arrangement == CollabRoomArrangement.series;

  /// How long each part plays in series, editable only in the host's lobby.
  Duration get partLength => _picksLead
      ? collabRoomPartLengthFor(
          pickedPartLength ?? room?.snapshot.partLength,
          room?.participants.length ?? 0,
        )
      : room?.partLength ?? collabRoomDefaultPartLength;

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

  /// Whose sound the video plays: the pick, while the person picked is still
  /// in the room; the room's otherwise.
  String? get effectiveSoundPubkey {
    final picked = soundPubkey;
    final room = this.room;
    if (picked != null &&
        (room == null || room.participants.any((m) => m.pubkey == picked))) {
      return picked;
    }
    return room?.soundPubkey;
  }

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
  bool get layoutFits => room?.seatsFitLayout ?? false;

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
    double? pickedGap,
    Color? pickedBorderColor,
    CollabRoomArrangement? pickedArrangement,
    Duration? pickedPartLength,
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
    pickedGap: pickedGap ?? this.pickedGap,
    pickedBorderColor: pickedBorderColor ?? this.pickedBorderColor,
    pickedArrangement: pickedArrangement ?? this.pickedArrangement,
    pickedPartLength: pickedPartLength ?? this.pickedPartLength,
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
    pickedGap,
    pickedBorderColor,
    pickedArrangement,
    pickedPartLength,
  ];
}
