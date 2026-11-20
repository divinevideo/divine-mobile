// ABOUTME: Runs collaborative recording rooms over NIP-17 DMs: invites,
// ABOUTME: answers, the author's snapshots, and the encrypted parts.

import 'dart:async';
import 'dart:io';

import 'package:dm_repository/dm_repository.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/aid.dart';
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
    bool isDmRestricted = false,
  }) : _dm = dmRepository,
       _videos = videoSendService,
       _decrypt = decryptPart,
       _l10n = l10n,
       _isDmRestricted = isDmRestricted,
       _storageDirectory = storageDirectory;

  /// Builds the decrypt function from the app's [DmVideoDecryptor].
  static CollabRoomPartDecrypt decryptWith(DmVideoDecryptor decryptor) =>
      (message) => decryptor.decrypt(message);

  final DmRepository _dm;
  final DmVideoSendService _videos;
  final CollabRoomPartDecrypt _decrypt;
  final AppLocalizations _l10n;
  final bool _isDmRestricted;
  final Future<Directory> Function() _storageDirectory;
  final _partDownloads = <(String, String, String), Future<File>>{};
  final _roomFileDeletes = <(String, String), Future<void>>{};
  final _roomWrites = <(String, String), Future<void>>{};
  final _publishedRevisions = <(String, String), int>{};

  /// The account the rooms belong to.
  String get ownerPubkey => _dm.userPubkey;

  /// Every room the account is in, newest first.
  Stream<List<CollabRoom>> watchRooms() {
    final owner = ownerPubkey;
    if (owner.isEmpty || _isDmRestricted) return Stream.value(const []);
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
  /// when no invite reached a relay.
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
    final sent = await _sendToEach(
      recipients: invitees,
      roomId: roomId,
      type: CollabRoomMessageType.invite,
      snapshot: snapshot,
      content: _l10n.collabRoomInviteDmBody,
    );
    if (sent.confirmed == 0) {
      await _withdraw(sent.queued);
      throw const CollabRoomException('No invite could be delivered');
    }
    return roomId;
  }

  /// Asks [pubkey], who left, declined or was removed, back into [room] with
  /// [snapshot], which lists them as invited again: they get a fresh invite,
  /// everyone else still in the room the update.
  ///
  /// Throws a [CollabRoomException] when the invite reached no relay.
  Future<void> reinvite(
    CollabRoom room,
    String pubkey,
    CollabRoomSnapshot snapshot,
  ) => _writeSnapshot(room, snapshot, (sent) async {
    if (!room.isAuthor) throw StateError('Only the author invites');
    final invited = await _sendToEach(
      recipients: [pubkey],
      roomId: room.id,
      type: CollabRoomMessageType.invite,
      snapshot: snapshot,
      content: _l10n.collabRoomInviteDmBody,
    );
    if (invited.confirmed == 0) {
      await _withdraw(invited.queued);
      throw const CollabRoomException('The invite could not be delivered');
    }
    sent();
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
  });

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
    final sent = await _sendToEach(
      recipients: [room.authorPubkey],
      roomId: room.id,
      type: type,
      content: content,
      inviteRevision: room.me?.inviteRevision,
    );
    if (sent.confirmed == 0) {
      await _withdraw(sent.queued);
      throw CollabRoomException('The ${type.name} could not be delivered');
    }
  }

  /// Sends [snapshot] of [room] to everyone it concerns: the people still in
  /// the room, and anyone the snapshot takes out of it, once — or, with
  /// nobody left in the room, everyone it ever had.
  ///
  /// Throws a [CollabRoomException] if the update reached no relay, or a
  /// recipient's update could not be sent or queued for retry.
  Future<void> publish(
    CollabRoom room,
    CollabRoomSnapshot snapshot,
  ) => _publish(room, snapshot);

  Future<void> _publish(
    CollabRoom room,
    CollabRoomSnapshot snapshot, {
    Set<String> alreadyNotified = const {},
  }) => _writeSnapshot(room, snapshot, (sent) async {
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
    final recipients = (active.isNotEmpty ? active : others)
        .where((person) => !alreadyNotified.contains(person))
        .toList();
    if (recipients.isEmpty) return;
    final result = await _sendToEach(
      recipients: recipients,
      roomId: room.id,
      type: CollabRoomMessageType.state,
      snapshot: snapshot,
      content: _stateText(room.snapshot, snapshot),
    );
    // A posted room's update may wait in the queue: the post went out, and
    // nothing builds on the update. Any other update the author's device
    // cannot read back until it is out, so one that reached no relay at all
    // is taken back rather than left to arrive after a newer one.
    if (result.confirmed == 0 && snapshot.phase != CollabRoomPhase.posted) {
      await _withdraw(result.queued);
      throw const CollabRoomException('No room update could be sent');
    }
    if (result.confirmed > 0) sent();
    if (result.confirmed + result.queued.length != recipients.length) {
      throw const CollabRoomException('Some room updates could not be sent');
    }
  });

  /// A room screen and its part or post flow can write concurrently. Queue
  /// those writes and reject an update built on a superseded snapshot.
  Future<void> _writeSnapshot(
    CollabRoom room,
    CollabRoomSnapshot snapshot,
    Future<void> Function(void Function() sent) write,
  ) async {
    final key = (room.ownerPubkey, room.id);
    final pending = _roomWrites[key];
    final done = Completer<void>();
    _roomWrites[key] = done.future;
    try {
      if (pending != null) await pending;
      if (ownerPubkey != room.ownerPubkey ||
          room.snapshot.revision < (_publishedRevisions[key] ?? 0)) {
        throw const CollabRoomException('The room changed before the update');
      }
      await write(() => _publishedRevisions[key] = snapshot.revision);
    } finally {
      if (identical(_roomWrites[key], done.future)) {
        unawaited(_roomWrites.remove(key));
      }
      done.complete();
    }
  }

  String _stateText(CollabRoomSnapshot before, CollabRoomSnapshot after) {
    if (after.phase != before.phase || after.phase == CollabRoomPhase.posted) {
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
    if (_isDmRestricted ||
        room.ownerPubkey != ownerPubkey ||
        room.phase != CollabRoomPhase.recording ||
        room.me?.status != CollabRoomMemberStatus.joined) {
      throw const CollabRoomException('The room no longer takes this part');
    }
    if (!room.isAuthor) {
      final result = await _videos.sendUploadedVideo(
        recipientPubkey: room.authorPubkey,
        url: upload.url,
        metadata: upload.metadata,
        extraTags: collabRoomTags(
          roomId: room.id,
          type: CollabRoomMessageType.part,
          recipientPubkey: room.authorPubkey,
          inviteRevision: room.me?.inviteRevision,
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
    if (room.participants.length < 2) {
      throw const CollabRoomException('No other member can receive this part');
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
  /// Retries the same snapshot for recipients whose posted message was
  /// not recorded in the host's history.
  Future<void> markPosted(String roomId, String videoAddress) async {
    final owner = ownerPubkey;
    if (_isDmRestricted || AId.fromString(videoAddress)?.pubkey != owner) {
      return;
    }
    await _roomWrites[(owner, roomId)];
    final messages = await _dm.watchCollabRoomMessages().first;
    final room = foldCollabRooms(
      messages,
      ownerPubkey: owner,
    ).where((room) => room.id == roomId).firstOrNull;
    if (room == null || !room.isAuthor) return;
    final snapshot = room.phase.isOpen
        ? room.toSnapshot(
            revision: room.snapshot.revision + 1,
            phase: CollabRoomPhase.posted,
            videoAddress: videoAddress,
          )
        : room.snapshot;
    if (snapshot.phase != CollabRoomPhase.posted ||
        snapshot.videoAddress != videoAddress) {
      return;
    }
    final delivered = {
      for (final message in messages)
        if (parseCollabRoomMessage(message, ownerPubkey: owner)
            case final parsed?
            when parsed.roomId == roomId &&
                parsed.senderPubkey == owner &&
                parsed.snapshot?.phase == CollabRoomPhase.posted &&
                parsed.snapshot?.videoAddress == videoAddress)
          parsed.recipientPubkey,
    };
    await _publish(
      room,
      snapshot,
      alreadyNotified: delivered,
    );
    await deleteRoomFiles(roomId);
  }

  /// The decrypted video of [part], downloaded once and kept on the device
  /// until [deleteRoomFiles].
  ///
  /// Throws whatever the download or decryption throws.
  Future<File> partFile(String roomId, CollabRoomPart part) async {
    if (!NostrHexUtils.isValidHex32(part.fileHash)) {
      throw const CollabRoomException('Invalid part ciphertext hash');
    }
    final owner = ownerPubkey;
    if (_roomFileDeletes.containsKey((owner, roomId))) {
      throw const CollabRoomException('The room is clearing its local parts');
    }
    final key = (owner, roomId, part.fileHash.toLowerCase());
    final inFlight = _partDownloads[key];
    if (inFlight != null) return inFlight;

    final download = _downloadPart(roomId, part, owner, key.$3);
    _partDownloads[key] = download;
    try {
      return await download;
    } finally {
      unawaited(_partDownloads.remove(key));
    }
  }

  Future<File> _downloadPart(
    String roomId,
    CollabRoomPart part,
    String owner,
    String hash,
  ) async {
    final directory = await _roomDirectory(roomId, owner);
    final file = File(p.join(directory.path, '$hash.mp4'));
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
    if (ownerPubkey != owner) {
      throw const CollabRoomException(
        'The account changed while reading a part',
      );
    }
    await directory.create(recursive: true);
    final partial = File('${file.path}.part');
    await partial.writeAsBytes(bytes, flush: true);
    return partial.rename(file.path);
  }

  /// Deletes every part of [roomId] kept on this device.
  Future<void> deleteRoomFiles(String roomId) async {
    final owner = ownerPubkey;
    final key = (owner, roomId);
    final inFlight = _roomFileDeletes[key];
    if (inFlight != null) return inFlight;
    final deletion = _deleteRoomFiles(roomId, owner);
    _roomFileDeletes[key] = deletion;
    try {
      await deletion;
    } finally {
      unawaited(_roomFileDeletes.remove(key));
    }
  }

  Future<void> _deleteRoomFiles(String roomId, String owner) async {
    final downloads = [
      for (final entry in _partDownloads.entries)
        if (entry.key.$1 == owner && entry.key.$2 == roomId)
          entry.value.then<void>((_) {}, onError: (Object _, StackTrace _) {}),
    ];
    await Future.wait(downloads);
    final directory = await _roomDirectory(roomId, owner);
    if (directory.existsSync()) await directory.delete(recursive: true);
  }

  Future<Directory> _roomDirectory(String roomId, String owner) async {
    if (!isValidCollabRoomId(roomId)) {
      throw ArgumentError.value(roomId, 'roomId');
    }
    final root = await _storageDirectory();
    return Directory(p.join(root.path, 'collab_rooms', owner, roomId));
  }

  /// Sends the room message to each of [recipients]: returns how many a
  /// relay confirmed, and the rumors of those only queued for a retry.
  ///
  /// The device reads a room back only from confirmed messages; a queued one
  /// goes out, and shows, once the relays are back.
  Future<({int confirmed, List<String> queued})> _sendToEach({
    required List<String> recipients,
    required String roomId,
    required CollabRoomMessageType type,
    required String content,
    CollabRoomSnapshot? snapshot,
    int? inviteRevision,
  }) async {
    if (_isDmRestricted) {
      throw const CollabRoomException('The account cannot use Together rooms');
    }
    final owner = ownerPubkey;
    final backgroundDelivery = snapshot?.phase == CollabRoomPhase.posted;
    var confirmed = 0;
    final queued = <String>[];
    for (final recipient in recipients) {
      if (ownerPubkey != owner) {
        throw const CollabRoomException('The account changed while sending');
      }
      final result = await _dm.sendMessage(
        recipientPubkey: recipient,
        content: content,
        additionalTags: collabRoomTags(
          roomId: roomId,
          type: type,
          recipientPubkey: recipient,
          snapshot: snapshot,
          inviteRevision: inviteRevision,
        ),
        skipNip04Fallback: true,
        backgroundDelivery: backgroundDelivery,
      );
      if (result.success) {
        confirmed++;
      } else if (result.queuedRumorId case final rumorId?) {
        queued.add(rumorId);
      }
    }
    return (confirmed: confirmed, queued: queued);
  }

  /// Takes back [queued] messages of a send none of whose messages reached a
  /// relay. The user is told it failed, so the retry queue must not deliver
  /// them later, beside the ones a second try sends.
  Future<void> _withdraw(List<String> queued) async {
    for (final rumorId in queued) {
      await _dm.cancelOutgoingSend(rumorId: rumorId);
    }
  }
}
