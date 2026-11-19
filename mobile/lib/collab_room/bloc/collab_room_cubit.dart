// ABOUTME: Drives one collaborative room's screen: who is in, the layout, the
// ABOUTME: parts handed in, and putting them together into one video

import 'dart:async';
import 'dart:math' as math;

import 'package:bloc/bloc.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/collab_room/collab_room_composer.dart';
import 'package:openvine/collab_room/collab_room_layout.dart';
import 'package:openvine/collab_room/collab_room_service.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/split_screen_layout.dart';
import 'package:openvine/services/video_thumbnail_service.dart';

part 'collab_room_state.dart';

/// Reads a still of the video at [videoPath], or `null`.
typedef CollabRoomThumbnailer = Future<String?> Function(String videoPath);

Future<String?> _extractThumbnail(String videoPath) async =>
    (await VideoThumbnailService.extractThumbnail(videoPath: videoPath))?.path;

/// Drives one collaborative room.
///
/// The author's device also keeps the room in sync: whenever it learns
/// something its last snapshot does not show yet — someone joined or left,
/// a part came in — it publishes a fresh one.
class CollabRoomCubit extends Cubit<CollabRoomState>
    with CloseGuardedEmit<CollabRoomState> {
  /// Creates a cubit for [roomId] and starts watching it.
  CollabRoomCubit({
    required CollabRoomService service,
    required String roomId,
    CollabRoomComposer composer = composeCollabRoom,
    CollabRoomThumbnailer thumbnailer = _extractThumbnail,
    this.keepsRoomInSync = true,
    Duration lobbyPublishDelay = const Duration(milliseconds: 500),
  }) : _service = service,
       _roomId = roomId,
       _lobbyPublishDelay = lobbyPublishDelay,
       _composer = composer,
       _thumbnailer = thumbnailer,
       super(const CollabRoomState()) {
    _subscription = _service
        .watchRoom(roomId)
        .listen(_onRoom, onError: _onRoomError);
  }

  /// Whether this cubit publishes the author's fresh snapshots and reads the
  /// parts. The room screen does; an invite card in a chat, which can sit
  /// under the room screen, only shows the room.
  final bool keepsRoomInSync;

  final CollabRoomService _service;
  final String _roomId;
  final Duration _lobbyPublishDelay;

  /// Holds the lobby's pending publish: a resource handle cancelled on close,
  /// not state.
  Timer? _lobbyPublishTimer;
  final CollabRoomComposer _composer;
  final CollabRoomThumbnailer _thumbnailer;
  late final StreamSubscription<CollabRoom?> _subscription;

  void _onRoom(CollabRoom? room) {
    if (room == null) {
      emitIfOpen(state.copyWith(status: CollabRoomStatus.missing));
      return;
    }
    final choices = collabRoomLayoutsFor(room.participants.length);
    final published = choices.contains(room.layoutPreset)
        ? room.layoutPreset
        : choices.firstOrNull;
    final inLobby = room.phase == CollabRoomPhase.lobby;
    // What the author's call said holds until a snapshot published after it.
    final hinted =
        !room.isAuthor &&
        inLobby &&
        room.snapshot.revision <= (state.lobbyRevision ?? -1);
    // In the lobby the author's own pick leads until it is published; everyone
    // else follows the author's last snapshot, or the call ahead of it.
    final layout = !inLobby
        ? room.layoutPreset
        : (room.isAuthor || hinted) && choices.contains(state.layout)
        ? state.layout
        : published;
    final pending = state.pendingSeats;
    final roomOrder = [for (final member in room.seats) member.pubkey];
    final keepPending =
        pending != null &&
        inLobby &&
        (room.isAuthor
            ? !_sameOrder(_withPending(roomOrder, pending), roomOrder)
            : hinted);
    emitIfOpen(
      state.copyWith(
        status: CollabRoomStatus.ready,
        room: room,
        layout: layout,
        clearLayout: layout == null,
        aspectRatio: inLobby ? null : room.frameAspectRatio,
        clearPendingSeats: !keepPending,
      ),
    );
    if (!keepsRoomInSync) return;
    if (room.needsBroadcast && state.actionStatus != .busy) {
      unawaited(
        _publishNext(.update, room, (revision) {
          return room.toSnapshot(revision: revision);
        }),
      );
    }
    _fetchParts(room);
  }

  void _onRoomError(Object error, StackTrace stackTrace) {
    addError(error, stackTrace);
    emitIfOpen(state.copyWith(status: CollabRoomStatus.missing));
  }

  /// Reads every part not on this device yet, so its cell can show it.
  void _fetchParts(CollabRoom room) {
    for (final part in room.parts.values) {
      final known = state.partFiles[part.pubkey];
      if (known?.fileHash == part.fileHash ||
          state.fetchingParts.contains(part.fileHash)) {
        continue;
      }
      emitIfOpen(
        state.copyWith(fetchingParts: {...state.fetchingParts, part.fileHash}),
      );
      unawaited(_fetchPart(part));
    }
  }

  Future<void> _fetchPart(CollabRoomPart part) async {
    try {
      final file = await _service.partFile(_roomId, part);
      final thumbnail = await _thumbnailer(file.path);
      emitIfOpen(
        state.copyWith(
          partFiles: {
            ...state.partFiles,
            part.pubkey: (
              fileHash: part.fileHash,
              path: file.path,
              thumbnailPath: thumbnail,
            ),
          },
        ),
      );
    } on Exception catch (error, stackTrace) {
      addError(error, stackTrace);
    } finally {
      emitIfOpen(
        state.copyWith(
          fetchingParts: {...state.fetchingParts}..remove(part.fileHash),
        ),
      );
    }
  }

  /// Joins the room, as an invitee.
  Future<void> join() => _run(.join, () => _service.join(state.room!));

  /// Turns the invite down.
  Future<void> decline() => _run(.decline, () => _service.decline(state.room!));

  /// Leaves the room, as a member.
  Future<void> leave() => _run(.leave, () => _service.leave(state.room!));

  /// Picks the layout the room is filmed in, as the author. Once filming
  /// started, the new layout is published straight away.
  Future<void> layoutPicked(SplitScreenLayoutPreset layout) async {
    final room = state.room;
    if (room == null || !room.isAuthor) return;
    emitIfOpen(state.copyWith(layout: layout));
    if (room.phase == CollabRoomPhase.lobby) {
      _scheduleLobbyPublish();
      return;
    }
    if (room.phase != CollabRoomPhase.recording) return;
    await _publishNext(
      .update,
      room,
      (revision) => room.toSnapshot(
        revision: revision,
        layout: layout.name,
        members: _assignCells(room.members, room.authorPubkey),
      ),
    );
  }

  /// Publishes the lobby once the author stops changing it, so the others
  /// get one message for a run of taps. The screen shows each change at once,
  /// and the room's call passes it on to the others straight away.
  void _scheduleLobbyPublish() {
    _lobbyPublishTimer?.cancel();
    _lobbyPublishTimer = Timer(
      _lobbyPublishDelay,
      () => unawaited(_publishLobby()),
    );
  }

  Future<void> _publishLobby() async {
    final room = state.room;
    if (isClosed ||
        room == null ||
        !room.isAuthor ||
        room.phase != CollabRoomPhase.lobby) {
      return;
    }
    final layout = state.layout;
    final order = state.lobbySeatOrder;
    final seatsMoved = !_sameOrder(order, [
      for (final member in room.seats) member.pubkey,
    ]);
    final layoutChanged = layout != null && room.layout != layout.name;
    if (!seatsMoved && !layoutChanged) return;
    // A message already on its way would swallow this one: wait for it.
    if (state.actionStatus == .busy) {
      _scheduleLobbyPublish();
      return;
    }
    await _publishNext(
      .update,
      room,
      (revision) => room.toSnapshot(
        revision: revision,
        layout: layout?.name,
        members: seatsMoved ? _seated(room.members, order) : null,
      ),
    );
    // Undelivered, the swap would show here and nowhere else.
    if (state.actionStatus == .failed) {
      emitIfOpen(state.copyWith(clearPendingSeats: true));
    }
  }

  /// Selects the seat at [cell] for a swap, as the author in the lobby; the
  /// next seat selected swaps places with it. The swap shows at once and is
  /// published with the lobby's next message.
  void seatTapped(int cell) {
    final room = state.room;
    final seats = state.lobbySeats;
    if (room == null ||
        !room.isAuthor ||
        room.phase != CollabRoomPhase.lobby ||
        cell >= seats.length) {
      return;
    }
    final selected = state.selectedSeat;
    if (selected == null) {
      emitIfOpen(state.copyWith(selectedSeat: cell));
      return;
    }
    if (selected == cell || selected >= seats.length) {
      emitIfOpen(state.copyWith(clearSelectedSeat: true));
      return;
    }
    final order = [for (final member in seats) member.pubkey];
    final moved = order[selected];
    order[selected] = order[cell];
    order[cell] = moved;
    emitIfOpen(state.copyWith(clearSelectedSeat: true, pendingSeats: order));
    _scheduleLobbyPublish();
  }

  /// Shows the lobby the author's call described — the layout picked and who
  /// sits where — ahead of the author's next snapshot, which then replaces
  /// it. Only the author's word counts, and only in the lobby.
  ///
  /// [revision] is the newest snapshot the author had published when it
  /// spoke: a snapshot past it already holds what the call said.
  void lobbyHinted({
    required String from,
    required String? layout,
    required List<String> seats,
    required int revision,
  }) {
    final room = state.room;
    if (room == null ||
        room.isAuthor ||
        room.phase != CollabRoomPhase.lobby ||
        from != room.authorPubkey ||
        revision < room.snapshot.revision) {
      return;
    }
    final preset = SplitScreenLayoutPreset.values
        .where((preset) => preset.name == layout)
        .firstOrNull;
    final fits = collabRoomLayoutsFor(
      room.participants.length,
    ).contains(preset);
    emitIfOpen(
      state.copyWith(
        layout: fits ? preset : null,
        pendingSeats: seats,
        lobbyRevision: revision,
      ),
    );
  }

  /// Picks the frame shape, as the author, before filming starts.
  void aspectRatioPicked(model.AspectRatio aspectRatio) {
    if (state.room?.phase != CollabRoomPhase.lobby) return;
    emitIfOpen(state.copyWith(aspectRatio: aspectRatio));
  }

  /// Picks whose sound the video plays, as the author.
  void soundPicked(String pubkey) {
    emitIfOpen(state.copyWith(soundPubkey: pubkey));
  }

  /// Starts filming, as the author: fixes the layout and who fills which
  /// cell. Anyone who has not joined yet is left out.
  Future<void> start() async {
    final room = state.room;
    final layout = state.layout;
    if (!state.canStart || room == null || layout == null) return;
    _lobbyPublishTimer?.cancel();
    // The seats as the author sees them, swaps not published yet included.
    final members = _assignCells(
      _seated(
        room.members,
        state.lobbySeatOrder,
      ).map(_leaveOutIfInvited).toList(),
      room.authorPubkey,
    );
    await _publishNext(
      .start,
      room,
      (revision) => room.toSnapshot(
        revision: revision,
        phase: CollabRoomPhase.recording,
        layout: layout.name,
        aspectRatio: state.aspectRatio.name,
        members: members,
      ),
    );
  }

  /// Takes [pubkey] out of the room, as the author. While filming, the
  /// layout falls back to the first that fits the people left.
  Future<void> removeMember(String pubkey) async {
    final room = state.room;
    if (room == null || !room.isAuthor || pubkey == room.authorPubkey) return;
    final remaining = room.members
        .map(
          (member) => member.pubkey == pubkey
              ? member.copyWith(status: CollabRoomMemberStatus.removed)
              : member,
        )
        .toList();
    final filming = room.phase == CollabRoomPhase.recording;
    final active = remaining
        .where(
          (m) =>
              m.pubkey == room.authorPubkey ||
              m.status == CollabRoomMemberStatus.joined,
        )
        .length;
    final layout = filming
        ? (room.layoutPreset?.cellCount == active
              ? room.layoutPreset
              : collabRoomLayoutsFor(active).firstOrNull)
        : null;
    await _publishNext(
      .update,
      room,
      (revision) => room.toSnapshot(
        revision: revision,
        layout: layout?.name,
        members: filming
            ? _assignCells(remaining, room.authorPubkey)
            : remaining,
      ),
    );
  }

  /// Calls the room off, as the author.
  Future<void> cancel() async {
    final room = state.room;
    if (room == null || !room.isAuthor) return;
    await _publishNext(
      .cancel,
      room,
      (revision) => room.toSnapshot(
        revision: revision,
        phase: CollabRoomPhase.cancelled,
      ),
    );
    if (state.actionStatus == .idle) {
      await _service.deleteRoomFiles(_roomId);
    }
  }

  /// Puts every part together into one video, as the author.
  Future<void> compose() async {
    final room = state.room;
    if (!state.canCompose || room == null) return;
    emitIfOpen(state.copyWith(composeStatus: CollabRoomComposeStatus.running));
    try {
      final rects = room.cellRects;
      final shapes = room.cellShapes;
      final sound = state.effectiveSoundPubkey;
      final cells = <CollabRoomComposeCell>[];
      for (final member in room.participants) {
        final part = room.parts[member.pubkey]!;
        final file = await _service.partFile(_roomId, part);
        cells.add((
          file: file,
          rect: rects[member.cell!],
          shape: shapes[member.cell!],
          withSound: member.pubkey == sound,
        ));
      }
      final clip = await _composer(
        cells: cells,
        aspectRatio: room.frameAspectRatio,
        taskId: 'collab_room_$_roomId',
      );
      if (clip == null) {
        throw const CollabRoomException('The render produced no video');
      }
      emitIfOpen(
        state.copyWith(
          composeStatus: CollabRoomComposeStatus.done,
          composedClip: clip,
        ),
      );
    } on Exception catch (error, stackTrace) {
      addError(error, stackTrace);
      emitIfOpen(state.copyWith(composeStatus: CollabRoomComposeStatus.failed));
    }
  }

  static CollabRoomMember _leaveOutIfInvited(CollabRoomMember member) =>
      member.status == CollabRoomMemberStatus.invited
      ? member.copyWith(status: CollabRoomMemberStatus.removed)
      : member;

  /// Fills the cells in member order, the author first.
  static List<CollabRoomMember> _assignCells(
    List<CollabRoomMember> members,
    String authorPubkey,
  ) {
    bool fillsCell(CollabRoomMember member) =>
        member.pubkey == authorPubkey ||
        member.status == CollabRoomMemberStatus.joined;
    // Keep the seats the author chose; whoever has none follows in order.
    final order = [
      ...members.where((m) => fillsCell(m) && m.cell != null).toList()
        ..sort((a, b) => a.cell!.compareTo(b.cell!)),
      ...members.where((m) => fillsCell(m) && m.cell == null),
    ].map((m) => m.pubkey).toList();
    return [
      for (final member in members)
        if (fillsCell(member))
          CollabRoomMember(
            pubkey: member.pubkey,
            status: member.status,
            cell: order.indexOf(member.pubkey),
          )
        else
          CollabRoomMember(pubkey: member.pubkey, status: member.status),
    ];
  }

  /// [members] with [order], pubkeys in cell order, as their seats; anyone
  /// it does not name has none.
  static List<CollabRoomMember> _seated(
    List<CollabRoomMember> members,
    List<String> order,
  ) => [
    for (final member in members)
      CollabRoomMember(
        pubkey: member.pubkey,
        status: member.status,
        cell: order.contains(member.pubkey)
            ? order.indexOf(member.pubkey)
            : null,
      ),
  ];

  /// [roomOrder] with the people [pending] names moved into its order.
  static List<String> _withPending(
    List<String> roomOrder,
    List<String> pending,
  ) => [
    for (final pubkey in pending)
      if (roomOrder.contains(pubkey)) pubkey,
    ...roomOrder.where((pubkey) => !pending.contains(pubkey)),
  ];

  static bool _sameOrder(List<String> a, List<String> b) =>
      a.length == b.length &&
      Iterable<int>.generate(a.length).every((i) => a[i] == b[i]);

  /// Publishes the snapshot [snapshotAt] makes, as the author, at a revision
  /// past every one this device published before — two in flight never share
  /// one.
  Future<void> _publishNext(
    CollabRoomAction action,
    CollabRoom room,
    CollabRoomSnapshot Function(int revision) snapshotAt,
  ) => _run(action, () async {
    final revision = state.nextRevision;
    emitIfOpen(state.copyWith(lobbyRevision: revision));
    await _service.publish(room, snapshotAt(revision));
  });

  Future<void> _run(
    CollabRoomAction action,
    Future<void> Function() send,
  ) async {
    if (state.actionStatus == .busy) return;
    emitIfOpen(state.copyWith(action: action, actionStatus: .busy));
    try {
      await send();
      emitIfOpen(state.copyWith(actionStatus: .idle));
    } on Exception catch (error, stackTrace) {
      addError(error, stackTrace);
      emitIfOpen(state.copyWith(actionStatus: .failed));
    }
  }

  @override
  Future<void> close() async {
    _lobbyPublishTimer?.cancel();
    await _subscription.cancel();
    return super.close();
  }
}
