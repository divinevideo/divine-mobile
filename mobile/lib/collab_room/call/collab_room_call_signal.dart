// ABOUTME: The connection messages of a Together room's call, sealed with the
// ABOUTME: room's call key into ephemeral Nostr events nobody else can read

import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:models/models.dart' show NostrHexUtils;
import 'package:nostr_sdk/client_utils/keys.dart' as keys;
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';
import 'package:nostr_sdk/signer/nostr_signer.dart';

/// Kind the call's connection messages travel as: a NIP-59 wrap addressed to
/// the call key.
///
/// relay.divine.video accepts only an allowlist of kinds, and no ephemeral
/// kind on it fits; a wrap is accepted and passed on to live subscribers. An
/// `expiration` tag (NIP-40) asks relays to drop each message soon after.
const collabRoomCallSignalKind = 1059;

/// How long relays should keep a connection message.
const collabRoomCallSignalLifetime = Duration(minutes: 10);

/// What a connection message does.
enum CollabRoomCallSignalType {
  /// Someone opened the room and is in the call.
  hello,

  /// A connection offer to one person.
  offer,

  /// The answer to an offer.
  answer,

  /// Someone's microphone or camera changed.
  state,

  /// Someone left the call.
  bye,

  /// The author's lobby as it stands: the layout and who sits where, ahead
  /// of the snapshot that publishes it.
  lobby,
}

/// The longest seat list a lobby message carries: a room holds four people.
const _maxLobbySeats = 4;

/// One connection message between two people in a room's call.
class CollabRoomCallSignal extends Equatable {
  /// Creates a message.
  const CollabRoomCallSignal({
    required this.type,
    required this.from,
    required this.session,
    this.to,
    this.toSession,
    this.sdp,
    this.sdpType,
    this.micOn = true,
    this.cameraOn = false,
    this.layout,
    this.seats,
    this.revision,
    this.sentAt,
  });

  /// What the message does.
  final CollabRoomCallSignalType type;

  /// Who sent it.
  final String from;

  /// The sender's call session: a fresh one each time they open the room, so
  /// an answer meant for an earlier visit is told apart.
  final String session;

  /// Who it is for, or `null` for everyone in the call.
  final String? to;

  /// The recipient's session it answers, when it answers one.
  final String? toSession;

  /// The session description of an offer or answer, ICE candidates included.
  final String? sdp;

  /// `offer` or `answer`.
  final String? sdpType;

  /// Whether the sender's microphone is on.
  final bool micOn;

  /// Whether the sender's camera is on.
  final bool cameraOn;

  /// A lobby message's layout, by name.
  final String? layout;

  /// A lobby message's seats: pubkeys in cell order.
  final List<String>? seats;

  /// A lobby message's newest snapshot revision the author had published.
  final int? revision;

  /// When a lobby message was sent, in microseconds since the epoch, so a
  /// late one never replaces a newer one.
  final int? sentAt;

  /// Whether [pubkey] should read the message.
  bool isFor(String pubkey) => from != pubkey && (to == null || to == pubkey);

  Map<String, Object?> _toJson() => {
    'v': 1,
    't': type.name,
    'f': from,
    's': session,
    if (to != null) 'to': to,
    if (toSession != null) 'ts': toSession,
    if (sdp != null) 'sdp': sdp,
    if (sdpType != null) 'st': sdpType,
    'mic': micOn,
    'cam': cameraOn,
    if (layout != null) 'l': layout,
    if (seats != null) 'seats': seats,
    if (revision != null) 'rev': revision,
    if (sentAt != null) 'n': sentAt,
  };

  static CollabRoomCallSignal? _fromJson(Object? json) {
    if (json is! Map<String, Object?> || json['v'] != 1) return null;
    final type = CollabRoomCallSignalType.values
        .where((t) => t.name == json['t'])
        .firstOrNull;
    final from = json['f'];
    final session = json['s'];
    final to = json['to'];
    final toSession = json['ts'];
    final sdp = json['sdp'];
    final sdpType = json['st'];
    final mic = json['mic'];
    final cam = json['cam'];
    final layout = json['l'];
    final rawSeats = json['seats'];
    final revision = json['rev'];
    final sentAt = json['n'];
    if (type == null ||
        from is! String ||
        !NostrHexUtils.isValidPubkey(from) ||
        session is! String ||
        session.isEmpty ||
        (to != null && (to is! String || !NostrHexUtils.isValidPubkey(to))) ||
        (toSession != null && toSession is! String) ||
        (sdp != null && sdp is! String) ||
        (sdpType != null && sdpType != 'offer' && sdpType != 'answer') ||
        mic is! bool ||
        cam is! bool) {
      return null;
    }
    final needsSdp =
        type == CollabRoomCallSignalType.offer ||
        type == CollabRoomCallSignalType.answer;
    if (needsSdp && (sdp == null || sdpType != type.name || to == null)) {
      return null;
    }
    List<String>? seats;
    if (type == CollabRoomCallSignalType.lobby) {
      if ((layout != null && (layout is! String || layout.length > 64)) ||
          rawSeats is! List<Object?> ||
          rawSeats.length > _maxLobbySeats ||
          rawSeats.any(
            (seat) => seat is! String || !NostrHexUtils.isValidPubkey(seat),
          ) ||
          revision is! int ||
          revision < 0 ||
          sentAt is! int) {
        return null;
      }
      seats = rawSeats.cast<String>();
      if (seats.toSet().length != seats.length) return null;
    }
    return CollabRoomCallSignal(
      type: type,
      from: from,
      session: session,
      to: to as String?,
      toSession: toSession as String?,
      sdp: sdp as String?,
      sdpType: sdpType as String?,
      micOn: mic,
      cameraOn: cam,
      layout: seats == null ? null : layout as String?,
      seats: seats,
      revision: seats == null ? null : revision as int?,
      sentAt: seats == null ? null : sentAt as int?,
    );
  }

  @override
  List<Object?> get props => [
    type,
    from,
    session,
    to,
    toSession,
    sdp,
    sdpType,
    micOn,
    cameraOn,
    layout,
    seats,
    revision,
    sentAt,
  ];
}

/// Seals and opens a room's connection messages with its call key.
///
/// The room key conceals the routing information from relays. The signal
/// itself is NIP-44 encrypted between the sender and recipient accounts.
/// Knowing the room key alone neither identifies a sender nor opens a signal.
class CollabRoomCallChannel {
  /// Creates a channel for the call key [callKey] (a private key in hex).
  CollabRoomCallChannel(
    this._callKey, {
    required String accountPubkey,
    required NostrSigner accountSigner,
  }) : pubkey = keys.getPublicKey(_callKey),
       _roomSigner = LocalNostrSigner(_callKey),
       _accountPubkey = accountPubkey,
       _accountSigner = accountSigner;

  final String _callKey;
  final LocalNostrSigner _roomSigner;
  final String _accountPubkey;
  final NostrSigner _accountSigner;

  /// The call key's public key: the author of every message of this call.
  final String pubkey;

  /// Seals [signal] into a short-lived event for [recipient].
  Future<Event> seal(
    CollabRoomCallSignal signal, {
    required String recipient,
  }) async {
    if (signal.from != _accountPubkey ||
        (signal.to != null && signal.to != recipient)) {
      throw ArgumentError('Invalid call signal routing');
    }
    final payload = await _accountSigner.nip44Encrypt(
      recipient,
      jsonEncode({...signal._toJson(), 'to': recipient, 'room': pubkey}),
    );
    if (payload == null) throw StateError('The call signal did not encrypt');
    final content = await _roomSigner.nip44Encrypt(
      pubkey,
      jsonEncode({'from': _accountPubkey, 'to': recipient, 'body': payload}),
    );
    if (content == null) throw StateError('The call message did not encrypt');
    final expiresAt =
        DateTime.now()
            .add(collabRoomCallSignalLifetime)
            .millisecondsSinceEpoch ~/
        1000;
    return Event(pubkey, collabRoomCallSignalKind, [
      ['p', pubkey],
      ['expiration', '$expiresAt'],
    ], content)..sign(_callKey);
  }

  /// Opens a valid signal addressed to this account by one of [others].
  Future<CollabRoomCallSignal?> open(
    Event event, {
    required Set<String> others,
  }) async {
    if (event.kind != collabRoomCallSignalKind ||
        event.pubkey != pubkey ||
        !event.isValid ||
        !event.isSigned) {
      return null;
    }
    try {
      final plaintext = await _roomSigner.nip44Decrypt(pubkey, event.content);
      if (plaintext == null) return null;
      final envelope = jsonDecode(plaintext);
      if (envelope is! Map<String, Object?> ||
          envelope['to'] != _accountPubkey ||
          envelope['from'] is! String ||
          envelope['body'] is! String) {
        return null;
      }
      final from = envelope['from']! as String;
      if (!others.contains(from)) return null;
      final body = await _accountSigner.nip44Decrypt(
        from,
        envelope['body']! as String,
      );
      if (body == null) return null;
      final payload = jsonDecode(body);
      if (payload is! Map<String, Object?> || payload['room'] != pubkey) {
        return null;
      }
      final signal = CollabRoomCallSignal._fromJson(payload);
      if (signal?.from != from || signal?.to != _accountPubkey) return null;
      return signal;
    } on FormatException {
      return null;
    } on Exception {
      // A payload that does not authenticate is someone else's noise.
      return null;
    }
  }
}

/// Whether [me] makes the offer to [other]. Exactly one of the two does, so
/// two offers never cross.
bool collabRoomCallOffers(String me, String other) => me.compareTo(other) < 0;
