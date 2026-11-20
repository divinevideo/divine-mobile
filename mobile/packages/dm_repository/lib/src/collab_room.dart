// ABOUTME: Versioned collaborative recording room messages in NIP-17 DMs.
// ABOUTME: Folds one account's room history into the room it describes.
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:equatable/equatable.dart';
import 'package:models/models.dart';

/// The most people a room holds, its author included.
const collabRoomMaxParticipants = 4;

/// The tag name every room message carries next to the `divine` marker:
/// `["collab-room", <room id>, <type>, <recipient pubkey>]`.
const collabRoomTagName = 'collab-room';

/// The tag carrying the author's room snapshot as JSON.
const collabRoomStateTagName = 'collab-room-state';

const List<String> _markerTag = ['divine', collabRoomTagName, '1'];

final RegExp _roomIdPattern = RegExp(r'^[0-9a-f]{32}$');

final RegExp _callKeyPattern = RegExp(r'^[0-9a-f]{64}$');

/// Creates a random room id: 16 bytes as lowercase hex.
String newCollabRoomId([Random? random]) {
  final source = random ?? Random.secure();
  return List.generate(
    16,
    (_) => source.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

/// Whether [roomId] has the shape [newCollabRoomId] creates.
bool isValidCollabRoomId(String roomId) => _roomIdPattern.hasMatch(roomId);

/// What a room message does.
enum CollabRoomMessageType {
  /// The author asks someone into the room. Carries the room snapshot.
  invite,

  /// An invitee joins.
  join,

  /// An invitee turns the invite down.
  decline,

  /// A member leaves.
  leave,

  /// The author publishes a new room snapshot.
  state,

  /// A member hands the author their finished part, as an encrypted video
  /// file message (kind 15).
  part,
}

/// Where a room is in its life.
enum CollabRoomPhase {
  /// People are joining and the author picks a layout.
  lobby,

  /// The layout is fixed and everyone films their part.
  recording,

  /// The author posted the video.
  posted,

  /// The author called the room off.
  cancelled;

  /// Whether the room still takes parts and members.
  bool get isOpen => this == lobby || this == recording;
}

/// Where one person stands in a room.
enum CollabRoomMemberStatus {
  /// Asked in, no answer yet.
  invited,

  /// In the room.
  joined,

  /// Turned the invite down.
  declined,

  /// Was in the room and left.
  left,

  /// Taken out of the room by the author.
  removed;

  /// Whether the person still takes part.
  bool get isActive => this == invited || this == joined;
}

/// One person in a room and the layout cell they fill.
class CollabRoomMember extends Equatable {
  /// Creates a member.
  const CollabRoomMember({
    required this.pubkey,
    required this.status,
    this.cell,
    this.inviteRevision = 0,
  });

  /// Hex public key.
  final String pubkey;

  /// Where the person stands.
  final CollabRoomMemberStatus status;

  /// Index of the layout cell the person fills, once the author fixed it.
  final int? cell;

  /// The host snapshot revision that last invited this member.
  final int inviteRevision;

  /// Returns a copy with the new status, seat or invitation revision.
  CollabRoomMember copyWith({
    CollabRoomMemberStatus? status,
    int? cell,
    bool clearCell = false,
    int? inviteRevision,
  }) => CollabRoomMember(
    pubkey: pubkey,
    status: status ?? this.status,
    cell: clearCell ? null : cell ?? this.cell,
    inviteRevision: inviteRevision ?? this.inviteRevision,
  );

  @override
  List<Object?> get props => [pubkey, status, cell, inviteRevision];
}

/// A finished part: an encrypted video on Blossom and how to read it.
class CollabRoomPart extends Equatable {
  /// Creates a part.
  const CollabRoomPart({
    required this.pubkey,
    required this.url,
    required this.metadata,
  });

  /// Whose part it is.
  final String pubkey;

  /// Where the ciphertext lives.
  final String url;

  /// The key, nonce and hashes needed to verify and decrypt the ciphertext.
  final DmFileMetadata metadata;

  /// Identity of the uploaded file: two parts with the same hash are the
  /// same take.
  String get fileHash => metadata.fileHash;

  Map<String, Object?> _toJson() => {
    'p': pubkey,
    'url': url,
    'type': metadata.fileType,
    'alg': metadata.encryptionAlgorithm,
    'key': metadata.decryptionKey,
    'nonce': metadata.decryptionNonce,
    'x': metadata.fileHash,
    if (metadata.originalFileHash != null) 'ox': metadata.originalFileHash,
    if (metadata.fileSize != null) 'size': metadata.fileSize,
    if (metadata.dimensions != null) 'dim': metadata.dimensions,
  };

  static CollabRoomPart? _fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final pubkey = json['p'];
    final url = json['url'];
    final type = json['type'];
    final algorithm = json['alg'];
    final key = json['key'];
    final nonce = json['nonce'];
    final hash = json['x'];
    final originalHash = json['ox'];
    final size = json['size'];
    final dimensions = json['dim'];
    if (pubkey is! String ||
        !NostrHexUtils.isValidPubkey(pubkey) ||
        url is! String ||
        !url.startsWith('https://') ||
        type is! String ||
        !type.startsWith('video/') ||
        algorithm is! String ||
        key is! String ||
        nonce is! String ||
        hash is! String ||
        !NostrHexUtils.isValidHex32(hash) ||
        (originalHash != null && originalHash is! String) ||
        (size != null && size is! int) ||
        (dimensions != null && dimensions is! String)) {
      return null;
    }
    return CollabRoomPart(
      pubkey: pubkey,
      url: url,
      metadata: DmFileMetadata(
        fileType: type,
        encryptionAlgorithm: algorithm,
        decryptionKey: key,
        decryptionNonce: nonce,
        fileHash: hash,
        originalFileHash: originalHash as String?,
        fileSize: size as int?,
        dimensions: dimensions as String?,
      ),
    );
  }

  @override
  List<Object?> get props => [pubkey, url, metadata];
}

/// The room as its author last published it.
///
/// Every invite and state message carries one, so an invitee learns the room
/// from the invite alone and the author's device reads its own decisions
/// back from what it sent.
class CollabRoomSnapshot extends Equatable {
  /// Creates a snapshot.
  const CollabRoomSnapshot({
    required this.revision,
    required this.phase,
    required this.members,
    this.layout,
    this.aspectRatio = 'vertical',
    this.soundPubkey,
    this.parts = const [],
    this.videoAddress,
    this.callKey,
  });

  /// Grows with every snapshot the author publishes; the highest wins.
  final int revision;

  /// Where the room is.
  final CollabRoomPhase phase;

  /// Everyone in the room, the author included.
  final List<CollabRoomMember> members;

  /// Name of the split-screen layout, once the author picked one.
  final String? layout;

  /// `vertical` or `square`.
  final String aspectRatio;

  /// Whose part's sound the posted video plays.
  final String? soundPubkey;

  /// The finished parts the author has.
  final List<CollabRoomPart> parts;

  /// The posted video's address, once posted.
  final String? videoAddress;

  /// The room's call key: a private key, as 64 hex characters, that signs and
  /// encrypts the call's connection messages.
  ///
  /// Only the room's people learn it, through these encrypted snapshots, so
  /// the call needs no account signature per message. `null` for a room made
  /// before calls existed, which has no call.
  final String? callKey;

  /// The JSON the state tag carries.
  String encode({bool includeParts = true}) => jsonEncode({
    'rev': revision,
    'phase': phase.name,
    'members': [
      for (final member in members)
        {
          'p': member.pubkey,
          's': member.status.name,
          if (member.cell != null) 'cell': member.cell,
          if (member.inviteRevision > 0) 'invite': member.inviteRevision,
        },
    ],
    if (layout != null) 'layout': layout,
    'aspect': aspectRatio,
    if (soundPubkey != null) 'sound': soundPubkey,
    if (includeParts && parts.isNotEmpty)
      'parts': [for (final part in parts) part._toJson()],
    if (videoAddress != null) 'video': videoAddress,
    if (callKey != null) 'call': callKey,
  });

  /// Reads a snapshot back, or `null` when [source] is not a valid one.
  static CollabRoomSnapshot? decode(String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, Object?>) return null;
    final json = decoded;
    final revision = json['rev'];
    final phaseName = json['phase'];
    final phase = CollabRoomPhase.values
        .where((p) => p.name == phaseName)
        .firstOrNull;
    final rawMembers = json['members'];
    final layout = json['layout'];
    final aspect = json['aspect'];
    final sound = json['sound'];
    final rawParts = json['parts'] ?? const <Object?>[];
    final video = json['video'];
    final call = json['call'];
    if (revision is! int ||
        revision < 0 ||
        phase == null ||
        rawMembers is! List<Object?> ||
        (layout != null && layout is! String) ||
        (aspect != 'vertical' && aspect != 'square') ||
        (sound != null &&
            (sound is! String || !NostrHexUtils.isValidPubkey(sound))) ||
        rawParts is! List<Object?> ||
        (video != null && video is! String) ||
        (call != null &&
            (call is! String || !_callKeyPattern.hasMatch(call)))) {
      return null;
    }
    final members = <CollabRoomMember>[];
    for (final raw in rawMembers) {
      if (raw is! Map<String, Object?>) return null;
      final pubkey = raw['p'];
      final status = CollabRoomMemberStatus.values
          .where((s) => s.name == raw['s'])
          .firstOrNull;
      final cell = raw['cell'];
      final invite = raw['invite'] ?? 0;
      if (pubkey is! String ||
          !NostrHexUtils.isValidPubkey(pubkey) ||
          status == null ||
          invite is! int ||
          invite < 0 ||
          invite > revision ||
          (cell != null && (cell is! int || cell < 0)) ||
          members.any((m) => m.pubkey == pubkey)) {
        return null;
      }
      members.add(
        CollabRoomMember(
          pubkey: pubkey,
          status: status,
          cell: cell as int?,
          inviteRevision: invite,
        ),
      );
    }
    if (members.isEmpty || members.length > collabRoomMaxParticipants) {
      return null;
    }
    final parts = <CollabRoomPart>[];
    for (final raw in rawParts) {
      final part = CollabRoomPart._fromJson(raw);
      if (part == null ||
          !members.any((m) => m.pubkey == part.pubkey) ||
          parts.any((p) => p.pubkey == part.pubkey)) {
        return null;
      }
      parts.add(part);
    }
    return CollabRoomSnapshot(
      revision: revision,
      phase: phase,
      members: members,
      layout: layout as String?,
      aspectRatio: aspect! as String,
      soundPubkey: sound as String?,
      parts: parts,
      videoAddress: video as String?,
      callKey: call as String?,
    );
  }

  @override
  List<Object?> get props => [
    revision,
    phase,
    members,
    layout,
    aspectRatio,
    soundPubkey,
    parts,
    videoAddress,
    callKey,
  ];
}

/// The application tags of a room message to [recipientPubkey].
///
/// [snapshot] is required for [CollabRoomMessageType.invite] and
/// [CollabRoomMessageType.state] and refused for every other type.
List<List<String>> collabRoomTags({
  required String roomId,
  required CollabRoomMessageType type,
  required String recipientPubkey,
  CollabRoomSnapshot? snapshot,
  int? inviteRevision,
}) {
  final carriesSnapshot =
      type == CollabRoomMessageType.invite ||
      type == CollabRoomMessageType.state;
  if (!isValidCollabRoomId(roomId) ||
      !NostrHexUtils.isValidPubkey(recipientPubkey) ||
      (inviteRevision != null && (carriesSnapshot || inviteRevision < 0)) ||
      carriesSnapshot != (snapshot != null)) {
    throw ArgumentError('Invalid collab room message');
  }
  return [
    _markerTag,
    [
      collabRoomTagName,
      roomId,
      type.name,
      recipientPubkey,
      if (inviteRevision != null && inviteRevision > 0) '$inviteRevision',
    ],
    if (snapshot != null)
      [
        collabRoomStateTagName,
        snapshot.encode(
          includeParts:
              snapshot.phase.isOpen &&
              snapshot.members.any(
                (m) =>
                    m.pubkey == recipientPubkey &&
                    m.status == CollabRoomMemberStatus.joined,
              ),
        ),
      ],
  ];
}

/// One validated room message.
class CollabRoomMessage extends Equatable {
  /// Creates a validated message.
  const CollabRoomMessage({
    required this.type,
    required this.roomId,
    required this.messageId,
    required this.senderPubkey,
    required this.recipientPubkey,
    required this.createdAt,
    this.inviteRevision = 0,
    this.snapshot,
    this.part,
  });

  /// What the message does.
  final CollabRoomMessageType type;

  /// The room it belongs to.
  final String roomId;

  /// Full rumor id.
  final String messageId;

  /// Who sent it.
  final String senderPubkey;

  /// Who it was sent to.
  final String recipientPubkey;

  /// Unix seconds.
  final int createdAt;

  /// The invitation this reply or part belongs to.
  final int inviteRevision;

  /// The room snapshot on an invite or state message.
  final CollabRoomSnapshot? snapshot;

  /// The finished part on a part message.
  final CollabRoomPart? part;

  @override
  List<Object?> get props => [
    type,
    roomId,
    messageId,
    senderPubkey,
    recipientPubkey,
    createdAt,
    inviteRevision,
    snapshot,
    part,
  ];
}

/// Validates a stored DM as a room message between [ownerPubkey] and one
/// other person, or returns `null`.
///
/// The recipient named in the room tag must be the other side of the
/// message's one-to-one conversation, so a message cannot claim to have been
/// sent to someone it was not.
CollabRoomMessage? parseCollabRoomMessage(
  DmMessage message, {
  required String ownerPubkey,
}) {
  if (!NostrHexUtils.isValidPubkey(ownerPubkey) ||
      !NostrHexUtils.isValidPubkey(message.senderPubkey) ||
      !NostrHexUtils.isValidEventId(message.id)) {
    return null;
  }
  final tags = message.tags;
  final markers = tags
      .where((t) => t.length >= 2 && t[0] == 'divine' && t[1] == 'collab-room')
      .toList();
  if (markers.length != 1 ||
      markers.single.length != 3 ||
      markers.single[2] != '1') {
    return null;
  }
  final roomTags = tags
      .where((t) => t.isNotEmpty && t[0] == collabRoomTagName)
      .toList();
  if (roomTags.length != 1 ||
      roomTags.single.length < 4 ||
      roomTags.single.length > 5) {
    return null;
  }
  final [_, roomId, typeName, recipient, ...extra] = roomTags.single;
  final inviteRevision = extra.isEmpty ? 0 : int.tryParse(extra.single);
  final type = CollabRoomMessageType.values
      .where((t) => t.name == typeName)
      .firstOrNull;
  if (!isValidCollabRoomId(roomId) ||
      type == null ||
      inviteRevision == null ||
      inviteRevision < 0 ||
      !NostrHexUtils.isValidPubkey(recipient) ||
      recipient == message.senderPubkey) {
    return null;
  }
  final pair = [recipient, message.senderPubkey]..sort();
  final conversation = sha256.convert(utf8.encode(pair.join(':'))).toString();
  if (!pair.contains(ownerPubkey) || message.conversationId != conversation) {
    return null;
  }

  final isPart = type == CollabRoomMessageType.part;
  if (message.messageKind != (isPart ? 15 : 14)) return null;

  CollabRoomSnapshot? snapshot;
  CollabRoomPart? part;
  final stateTags = tags
      .where((t) => t.isNotEmpty && t[0] == collabRoomStateTagName)
      .toList();
  if (type == CollabRoomMessageType.invite ||
      type == CollabRoomMessageType.state) {
    if (extra.isNotEmpty) return null;
    if (stateTags.length != 1 || stateTags.single.length != 2) return null;
    snapshot = CollabRoomSnapshot.decode(stateTags.single[1]);
    if (snapshot == null) return null;
  } else if (stateTags.isNotEmpty) {
    return null;
  }
  if (isPart) {
    final metadata = message.fileMetadata;
    if (metadata == null ||
        !metadata.isVideo ||
        !NostrHexUtils.isValidHex32(metadata.fileHash) ||
        !message.content.startsWith('https://')) {
      return null;
    }
    part = CollabRoomPart(
      pubkey: message.senderPubkey,
      url: message.content,
      metadata: metadata,
    );
  }
  return CollabRoomMessage(
    type: type,
    roomId: roomId,
    messageId: message.id,
    senderPubkey: message.senderPubkey,
    recipientPubkey: recipient,
    createdAt: message.createdAt,
    inviteRevision: inviteRevision,
    snapshot: snapshot,
    part: part,
  );
}

/// A room as one account sees it: the author's last snapshot, brought up to
/// date with what the account knows that the snapshot does not show yet.
class CollabRoom extends Equatable {
  /// Creates a room.
  const CollabRoom({
    required this.id,
    required this.authorPubkey,
    required this.ownerPubkey,
    required this.snapshot,
    required this.members,
    required this.parts,
    required this.updatedAt,
  });

  /// Room id.
  final String id;

  /// Who created the room and posts the video.
  final String authorPubkey;

  /// The account this view belongs to.
  final String ownerPubkey;

  /// The author's last published snapshot.
  final CollabRoomSnapshot snapshot;

  /// Everyone in the room with their current status, the author first.
  final List<CollabRoomMember> members;

  /// The newest finished part of each person, by pubkey.
  final Map<String, CollabRoomPart> parts;

  /// Unix seconds of the newest message about the room.
  final int updatedAt;

  /// Whether this account created the room.
  bool get isAuthor => ownerPubkey == authorPubkey;

  /// Where the room is.
  CollabRoomPhase get phase => snapshot.phase;

  /// The split-screen layout's name, once picked.
  String? get layout => snapshot.layout;

  /// `vertical` or `square`.
  String get aspectRatio => snapshot.aspectRatio;

  /// Whose sound the posted video plays: the author's until they pick, and
  /// again once the person picked is no longer in the room, whose part would
  /// leave the video silent.
  String get soundPubkey {
    final picked = snapshot.soundPubkey;
    return picked != null && participants.any((m) => m.pubkey == picked)
        ? picked
        : authorPubkey;
  }

  /// The key the room's call runs on, or `null` for a room without a call.
  String? get callKey => snapshot.callKey;

  /// This account's own entry, or `null` when it is not in the room.
  CollabRoomMember? get me =>
      members.where((m) => m.pubkey == ownerPubkey).firstOrNull;

  /// The people who fill a cell: the author and everyone who joined.
  List<CollabRoomMember> get participants => members
      .where(
        (m) =>
            m.pubkey == authorPubkey ||
            m.status == CollabRoomMemberStatus.joined,
      )
      .toList();

  /// The participant who fills [cell], or `null`.
  CollabRoomMember? memberInCell(int cell) =>
      participants.where((m) => m.cell == cell).firstOrNull;

  /// Whether every participant handed in a part.
  bool get allPartsIn =>
      participants.every((member) => parts.containsKey(member.pubkey));

  /// Whether the author's device knows something its last snapshot does not
  /// show: a member's new status or a new part. The author then publishes a
  /// fresh snapshot so the others learn it too.
  bool get needsBroadcast {
    if (!isAuthor || !phase.isOpen) return false;
    final published = {
      for (final member in snapshot.members) member.pubkey: member.status,
    };
    if (members.any((m) => published[m.pubkey] != m.status)) return true;
    if (participants.length < 2) return false;
    final publishedParts = {
      for (final part in snapshot.parts) part.pubkey: part.fileHash,
    };
    return parts.values.any(
      (part) => publishedParts[part.pubkey] != part.fileHash,
    );
  }

  /// The snapshot that publishes this view, at [revision].
  CollabRoomSnapshot toSnapshot({
    required int revision,
    CollabRoomPhase? phase,
    String? layout,
    String? aspectRatio,
    String? soundPubkey,
    List<CollabRoomMember>? members,
    Map<String, CollabRoomPart>? parts,
    String? videoAddress,
  }) {
    final nextMembers = members ?? this.members;
    final nextParts = parts ?? this.parts;
    return CollabRoomSnapshot(
      revision: revision,
      phase: phase ?? this.phase,
      members: nextMembers,
      layout: layout ?? this.layout,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      soundPubkey: soundPubkey ?? snapshot.soundPubkey,
      parts: [
        for (final member in nextMembers)
          if (member.status == CollabRoomMemberStatus.joined)
            ?nextParts[member.pubkey],
      ],
      videoAddress: videoAddress ?? snapshot.videoAddress,
      callKey: snapshot.callKey,
    );
  }

  @override
  List<Object?> get props => [
    id,
    authorPubkey,
    ownerPubkey,
    snapshot,
    members,
    parts,
    updatedAt,
  ];
}

/// Folds every room message [ownerPubkey] has into its rooms, newest first.
List<CollabRoom> foldCollabRooms(
  Iterable<DmMessage> messages, {
  required String ownerPubkey,
}) {
  final byRoom = <String, List<CollabRoomMessage>>{};
  for (final message in messages) {
    final parsed = parseCollabRoomMessage(message, ownerPubkey: ownerPubkey);
    if (parsed == null) continue;
    (byRoom[parsed.roomId] ??= []).add(parsed);
  }
  final rooms = [
    for (final MapEntry(:key, :value) in byRoom.entries)
      ?foldCollabRoom(key, value, ownerPubkey: ownerPubkey),
  ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  return rooms;
}

/// Folds the messages of one room into the room [ownerPubkey] sees, or
/// `null` when no invite places the account in it.
CollabRoom? foldCollabRoom(
  String roomId,
  Iterable<CollabRoomMessage> messages, {
  required String ownerPubkey,
}) {
  final ordered = messages.where((m) => m.roomId == roomId).toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  if (ordered.isEmpty) return null;

  // An invite the account sent makes it the author. Otherwise exactly one
  // person may have invited it: room ids are random, so an honest room never
  // has a second inviter, and the timestamps that would pick between two are
  // the senders' own to choose. A second inviter forged an invite for this
  // id, and the room is not shown rather than handed to either of them.
  // Anyone who knows the id, any past member included, can hide the room
  // this way, but only from the accounts they invite, and never take it over.
  final inviters = {
    for (final m in ordered)
      if (m.type == CollabRoomMessageType.invite) m.senderPubkey,
  };
  if (inviters.isEmpty) return null;
  final String author;
  if (inviters.contains(ownerPubkey)) {
    author = ownerPubkey;
  } else if (inviters.length == 1) {
    author = inviters.single;
  } else {
    return null;
  }
  final isAuthor = author == ownerPubkey;

  final fromAuthor = ordered.where(
    (m) =>
        m.senderPubkey == author &&
        (isAuthor || m.recipientPubkey == ownerPubkey),
  );
  CollabRoomSnapshot? snapshot;
  var snapshotReachedMember = false;
  CollabRoomPart? ownPart;
  var ownPartRevision = -1;
  for (final message in fromAuthor) {
    final next = message.snapshot;
    if (next == null) continue;
    final reachedMember = next.members.any(
      (m) =>
          m.pubkey == message.recipientPubkey &&
          m.status == CollabRoomMemberStatus.joined,
    );
    if (snapshot == null ||
        next.revision > snapshot.revision ||
        (next.revision == snapshot.revision &&
            (reachedMember || !snapshotReachedMember))) {
      snapshot = next;
      snapshotReachedMember = reachedMember;
    }
    if (isAuthor && next.revision >= ownPartRevision) {
      final part = next.parts.where((p) => p.pubkey == author).firstOrNull;
      if (part != null) {
        ownPart = part;
        ownPartRevision = next.revision;
      }
    }
  }
  if (snapshot == null) return null;
  final published = snapshot;
  final members = {
    for (final member in published.members) member.pubkey: member,
  };
  if (!isAuthor && !members.containsKey(ownerPubkey)) return null;

  final statuses = {
    for (final member in published.members) member.pubkey: member.status,
  };
  final memberParts = <String, CollabRoomPart>{};

  // What members tell the author: the author's device folds every answer
  // and part in, the member's device only its own, since a member hears
  // about the others through the author's snapshots.
  for (final message in ordered) {
    final sender = message.senderPubkey;
    // Answers to an earlier invite carry an older revision and are skipped
    // below, so inviting someone again needs no reset here. A reset at the
    // invite would also wipe a Join sent by a phone whose clock runs behind.
    final member = members[sender];
    if (sender == author ||
        member == null ||
        message.inviteRevision != member.inviteRevision) {
      continue;
    }
    if (message.recipientPubkey != author) continue;
    if (!isAuthor && sender != ownerPubkey) continue;
    if (statuses[sender] == CollabRoomMemberStatus.removed) continue;
    switch (message.type) {
      case CollabRoomMessageType.join:
        statuses[sender] = CollabRoomMemberStatus.joined;
      case CollabRoomMessageType.decline:
        statuses[sender] = CollabRoomMemberStatus.declined;
        memberParts.remove(sender);
      case CollabRoomMessageType.leave:
        statuses[sender] = CollabRoomMemberStatus.left;
        memberParts.remove(sender);
      case CollabRoomMessageType.part:
        if (statuses[sender] == CollabRoomMemberStatus.joined) {
          memberParts[sender] = message.part!;
        }
      case CollabRoomMessageType.invite:
      case CollabRoomMessageType.state:
        break;
    }
  }

  // A member's device takes the author's word for everyone but the member:
  // they are in only once they said so for this invite. An invite listing
  // them as joined would otherwise put them in the room's call unasked.
  if (!isAuthor && statuses[ownerPubkey] == CollabRoomMemberStatus.joined) {
    final revision = members[ownerPubkey]!.inviteRevision;
    final saidYes = ordered.any(
      (m) =>
          m.senderPubkey == ownerPubkey &&
          m.recipientPubkey == author &&
          m.type == CollabRoomMessageType.join &&
          m.inviteRevision == revision,
    );
    if (!saidYes) statuses[ownerPubkey] = CollabRoomMemberStatus.invited;
  }

  final folded = [
    for (final member in published.members)
      member.copyWith(status: statuses[member.pubkey]),
  ];
  final parts = {
    if (published.phase.isOpen && ownPart != null) author: ownPart,
    for (final part in published.parts) part.pubkey: part,
    ...memberParts,
  };
  return CollabRoom(
    id: roomId,
    authorPubkey: author,
    ownerPubkey: ownerPubkey,
    snapshot: published,
    members: [
      ...folded.where((m) => m.pubkey == author),
      ...folded.where((m) => m.pubkey != author),
    ],
    parts: {
      for (final MapEntry(:key, :value) in parts.entries)
        if (statuses[key] == CollabRoomMemberStatus.joined) key: value,
    },
    updatedAt: ordered.last.createdAt,
  );
}
