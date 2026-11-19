// ABOUTME: Runs collaborative recording rooms over NIP-17 DMs: invites,
// ABOUTME: answers, the author's snapshots, and the encrypted parts.

import 'dart:io';

import 'package:dm_repository/dm_repository.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/client_utils/keys.dart' as keys;
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/services/dm_video_decryptor.dart';
import 'package:openvine/services/dm_video_send_service.dart';
import 'package:path/path.dart' as p;

/// A part's video uploaded, its key not handed to anyone yet.
typedef CollabRoomUpload = ({String url, DmFileMetadata metadata});

/// A room message could not be delivered, or a part could not be uploaded or
/// read back.
///
/// Expected on a flaky network or when a send policy refuses a recipient, so
/// it is reported to the user and never to the crash reporter.
class CollabRoomException implements Exception {
  /// Creates an exception with a diagnostic [message].
  const CollabRoomException(this.message);

  /// Diagnostic description for logs.
  final String message;

  @override
  String toString() => 'CollabRoomException: $message';
}

/// Reads the decrypted bytes of an encrypted video message.
typedef CollabRoomPartDecrypt = Future<List<int>> Function(DmMessage message);

/// Runs one account's collaborative recording rooms.
///
/// A room has no server of its own. The author's device is its source of
/// truth: invitees answer the author in one-to-one DMs and hand in their
/// parts as encrypted video messages, and the author tells everyone what
/// changed by sending a fresh room snapshot. Every device reads its rooms
/// back by folding its own DM history (see [foldCollabRooms]), so a room
/// survives restarts without a store of its own.
class CollabRoomService {
  /// Creates a service for the account [DmRepository.userPubkey] belongs to.
  CollabRoomService({
    required DmRepository dmRepository,
    required DmVideoSendService videoSendService,
    required CollabRoomPartDecrypt decryptPart,
    required AppLocalizations l10n,
    required Future<Directory> Function() storageDirectory,
  }) : _dm = dmRepository,
       _videos = videoSendService,
       _decrypt = decryptPart,
       _l10n = l10n,
       _storageDirectory = storageDirectory;

  /// Builds the decrypt function from the app's [DmVideoDecryptor].
  static CollabRoomPartDecrypt decryptWith(DmVideoDecryptor decryptor) =>
      (message) => decryptor.decrypt(message);

  final DmRepository _dm;
  final DmVideoSendService _videos;
  final CollabRoomPartDecrypt _decrypt;
  final AppLocalizations _l10n;
  final Future<Directory> Function() _storageDirectory;

  /// The account the rooms belong to.
  String get ownerPubkey => _dm.userPubkey;

  /// Every room the account is in, newest first.
  Stream<List<CollabRoom>> watchRooms() {
    final owner = ownerPubkey;
    if (owner.isEmpty) return Stream.value(const []);
    return _dm.watchCollabRoomMessages().map(
      (messages) => foldCollabRooms(messages, ownerPubkey: owner),
    );
  }

  /// The room [roomId], or `null` while the account knows no such room.
  Stream<CollabRoom?> watchRoom(String roomId) => watchRooms()
      .map((rooms) => rooms.where((room) => room.id == roomId).firstOrNull)
      .distinct();

  /// Creates a room with [invitees] and invites each of them.
  ///
  /// Returns the new room's id.
  ///
  /// Throws an [ArgumentError] when [invitees] is empty, too long, repeats
  /// someone or includes the account itself, and a [CollabRoomException]
  /// when no invite could be delivered.
  Future<String> createRoom(List<String> invitees) async {
    final owner = ownerPubkey;
    final unique = invitees.toSet();
    if (unique.isEmpty ||
        unique.length != invitees.length ||
        unique.length >= collabRoomMaxParticipants ||
        unique.contains(owner) ||
        !unique.every(NostrHexUtils.isValidPubkey)) {
      throw ArgumentError.value(invitees, 'invitees');
    }
    final roomId = newCollabRoomId();
    final snapshot = CollabRoomSnapshot(
      revision: 0,
      phase: CollabRoomPhase.lobby,
      callKey: keys.generatePrivateKey(),
      members: [
        CollabRoomMember(pubkey: owner, status: CollabRoomMemberStatus.joined),
        for (final invitee in invitees)
          CollabRoomMember(
            pubkey: invitee,
            status: CollabRoomMemberStatus.invited,
          ),
      ],
    );
    final delivered = await _sendToEach(
      recipients: invitees,
      roomId: roomId,
      type: CollabRoomMessageType.invite,
      snapshot: snapshot,
      content: _l10n.collabRoomInviteDmBody,
    );
    if (delivered == 0) {
      throw const CollabRoomException('No invite could be delivered');
    }
    return roomId;
  }

  /// Asks [pubkey], who left, declined or was removed, back into [room] with
  /// [snapshot], which lists them as invited again: they get a fresh invite,
  /// everyone else still in the room the update.
  ///
  /// Throws a [CollabRoomException] when the invite could not be delivered.
  Future<void> reinvite(
    CollabRoom room,
    String pubkey,
    CollabRoomSnapshot snapshot,
  ) async {
    if (!room.isAuthor) throw StateError('Only the author invites');
    final invited = await _sendToEach(
      recipients: [pubkey],
      roomId: room.id,
      type: CollabRoomMessageType.invite,
      snapshot: snapshot,
      content: _l10n.collabRoomInviteDmBody,
    );
    if (invited == 0) {
      throw const CollabRoomException('The invite could not be delivered');
    }
    final others = [
      for (final member in snapshot.members)
        if (member.pubkey != room.authorPubkey &&
            member.pubkey != pubkey &&
            member.status.isActive)
          member.pubkey,
    ];
    if (others.isEmpty) return;
    await _sendToEach(
      recipients: others,
      roomId: room.id,
      type: CollabRoomMessageType.state,
      snapshot: snapshot,
      content: _l10n.collabRoomUpdatedDmBody,
    );
  }

  /// Joins [room].
  Future<void> join(CollabRoom room) =>
      _answer(room, CollabRoomMessageType.join, _l10n.collabRoomJoinDmBody);

  /// Turns down the invite to [room].
  Future<void> decline(CollabRoom room) => _answer(
    room,
    CollabRoomMessageType.decline,
    _l10n.collabRoomDeclineDmBody,
  );

  /// Leaves [room].
  Future<void> leave(CollabRoom room) =>
      _answer(room, CollabRoomMessageType.leave, _l10n.collabRoomLeaveDmBody);

  Future<void> _answer(
    CollabRoom room,
    CollabRoomMessageType type,
    String content,
  ) async {
    if (room.isAuthor) throw StateError('The author does not answer a room');
    final delivered = await _sendToEach(
      recipients: [room.authorPubkey],
      roomId: room.id,
      type: type,
      content: content,
    );
    if (delivered == 0) {
      throw CollabRoomException('The ${type.name} could not be delivered');
    }
  }

  /// Sends [snapshot] of [room] to everyone it concerns: the people still in
  /// the room, and anyone the snapshot takes out of it, once — or, with
  /// nobody left in the room, everyone it ever had.
  ///
  /// Throws a [CollabRoomException] when it reached nobody.
  Future<void> publish(CollabRoom room, CollabRoomSnapshot snapshot) async {
    if (!room.isAuthor) throw StateError('Only the author publishes a room');
    final wasActive = {
      for (final member in room.snapshot.members)
        if (member.status.isActive) member.pubkey,
    };
    final others = [
      for (final member in snapshot.members)
        if (member.pubkey != room.authorPubkey) member.pubkey,
    ];
    final active = [
      for (final member in snapshot.members)
        if (member.pubkey != room.authorPubkey &&
            (member.status.isActive || wasActive.contains(member.pubkey)))
          member.pubkey,
    ];
    // The author's device reads the room back from the messages it sent, so
    // a snapshot sent to nobody would never take effect there: calling off a
    // room everyone left would leave it open. With nobody in the room, the
    // update goes to everyone it ever had.
    final recipients = active.isNotEmpty ? active : others;
    if (recipients.isEmpty) return;
    final delivered = await _sendToEach(
      recipients: recipients,
      roomId: room.id,
      type: CollabRoomMessageType.state,
      snapshot: snapshot,
      content: _stateText(room.snapshot, snapshot),
    );
    if (delivered == 0) {
      throw const CollabRoomException('The room update reached nobody');
    }
  }

  String _stateText(CollabRoomSnapshot before, CollabRoomSnapshot after) {
    if (after.phase != before.phase) {
      return switch (after.phase) {
        CollabRoomPhase.recording => _l10n.collabRoomStartedDmBody,
        CollabRoomPhase.posted => _l10n.collabRoomPostedDmBody,
        CollabRoomPhase.cancelled => _l10n.collabRoomCancelledDmBody,
        CollabRoomPhase.lobby => _l10n.collabRoomUpdatedDmBody,
      };
    }
    return _l10n.collabRoomUpdatedDmBody;
  }

  /// Encrypts and uploads [video] as a part without handing it in, so the
  /// slow half can run while the user still looks at the part. [onProgress]
  /// hears how much of the upload is done, from 0 to 1.
  ///
  /// Throws a [CollabRoomException] when the upload failed.
  Future<CollabRoomUpload> uploadPart(
    File video, {
    void Function(double fraction)? onProgress,
  }) async {
    final upload = await _videos.uploadVideo(
      videoFile: video,
      mimeType: 'video/mp4',
      onUploadProgress: onProgress,
    );
    if (upload == null) {
      throw const CollabRoomException('The part could not be uploaded');
    }
    return upload;
  }

  /// Hands in [upload], from [uploadPart], as the account's part of [room].
  ///
  /// A member sends its link and key to the author in an encrypted file
  /// message. The author publishes it in a fresh snapshot, so everyone sees
  /// it.
  ///
  /// Throws a [CollabRoomException] when the message reached nobody.
  Future<void> handInPart(CollabRoom room, CollabRoomUpload upload) async {
    if (!room.isAuthor) {
      final result = await _videos.sendUploadedVideo(
        recipientPubkey: room.authorPubkey,
        url: upload.url,
        metadata: upload.metadata,
        extraTags: collabRoomTags(
          roomId: room.id,
          type: CollabRoomMessageType.part,
          recipientPubkey: room.authorPubkey,
        ),
      );
      if (!result.success) {
        throw CollabRoomException(
          'The part was not delivered: '
          '${result.error ?? 'unknown error'}',
        );
      }
      return;
    }
    final part = CollabRoomPart(
      pubkey: room.ownerPubkey,
      url: upload.url,
      metadata: upload.metadata,
    );
    await publish(
      room,
      room.toSnapshot(
        revision: room.snapshot.revision + 1,
        parts: {...room.parts, room.ownerPubkey: part},
      ),
    );
  }

  /// Uploads [video] and hands it in as the account's part of [room] — see
  /// [uploadPart] and [handInPart].
  Future<void> sendPart(CollabRoom room, File video) async =>
      handInPart(room, await uploadPart(video));

  /// Tells everyone in [roomId] that its video was posted at [videoAddress],
  /// and deletes the parts kept on this device.
  ///
  /// Does nothing unless the account is the room's author and the room is
  /// still open. Throws a [CollabRoomException] when the update reached
  /// nobody.
  Future<void> markPosted(String roomId, String videoAddress) async {
    final room = await watchRoom(roomId).first;
    if (room == null || !room.isAuthor || !room.phase.isOpen) return;
    await publish(
      room,
      room.toSnapshot(
        revision: room.snapshot.revision + 1,
        phase: CollabRoomPhase.posted,
        videoAddress: videoAddress,
      ),
    );
    await deleteRoomFiles(roomId);
  }

  /// The decrypted video of [part], downloaded once and kept on the device
  /// until [deleteRoomFiles].
  ///
  /// Throws whatever the download or decryption throws.
  Future<File> partFile(String roomId, CollabRoomPart part) async {
    final directory = await _roomDirectory(roomId);
    final file = File(p.join(directory.path, '${part.fileHash}.mp4'));
    if (file.existsSync()) return file;
    final bytes = await _decrypt(
      DmMessage(
        id: part.fileHash,
        conversationId: roomId,
        senderPubkey: part.pubkey,
        content: part.url,
        createdAt: 0,
        giftWrapId: part.fileHash,
        messageKind: 15,
        fileMetadata: part.metadata,
      ),
    );
    await directory.create(recursive: true);
    final partial = File('${file.path}.part');
    await partial.writeAsBytes(bytes, flush: true);
    return partial.rename(file.path);
  }

  /// Deletes every part of [roomId] kept on this device.
  Future<void> deleteRoomFiles(String roomId) async {
    final directory = await _roomDirectory(roomId);
    if (directory.existsSync()) await directory.delete(recursive: true);
  }

  Future<Directory> _roomDirectory(String roomId) async {
    if (!isValidCollabRoomId(roomId)) {
      throw ArgumentError.value(roomId, 'roomId');
    }
    final root = await _storageDirectory();
    return Directory(p.join(root.path, 'collab_rooms', ownerPubkey, roomId));
  }

  /// Sends the room message to each of [recipients] and returns how many
  /// took it.
  Future<int> _sendToEach({
    required List<String> recipients,
    required String roomId,
    required CollabRoomMessageType type,
    required String content,
    CollabRoomSnapshot? snapshot,
  }) async {
    var delivered = 0;
    for (final recipient in recipients) {
      final result = await _dm.sendMessage(
        recipientPubkey: recipient,
        content: content,
        additionalTags: collabRoomTags(
          roomId: roomId,
          type: type,
          recipientPubkey: recipient,
          snapshot: snapshot,
        ),
        skipNip04Fallback: true,
      );
      if (result.success) delivered++;
    }
    return delivered;
  }
}
