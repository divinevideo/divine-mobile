// Need to decide header
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:clock/clock.dart';
import 'package:bip340/bip340.dart' as schnorr;
import 'package:hex/hex.dart';

import 'client_utils/keys.dart';

/// A Nostr event
///
/// For more details about Nostr events refer to [NIP-01](https://github.com/nostr-protocol/nips/blob/master/01.md).
class Event {
  /// Creates a new Nostr event.
  ///
  /// [pubkey] is the author's public key.
  /// [kind] is the event kind.
  /// [tags] is a JSON object of event tags.
  /// [content] is an arbitrary string.
  ///
  /// Nostr event `id` and `created_at` fields are calculated automatically.
  ///
  /// An [ArgumentError] is thrown if [pubkey] is invalid.
  Event(this.pubkey, this.kind, this.tags, this.content, {int? createdAt}) {
    if (!keyIsValid(pubkey)) {
      throw ArgumentError.value(pubkey, 'pubkey', 'Invalid key');
    }
    if (createdAt != null) {
      this.createdAt = createdAt;
    } else {
      this.createdAt = _secondsSinceEpoch();
    }
    id = _getId(pubkey, this.createdAt, kind, tags, content);
  }

  Event._(this.id, this.pubkey, this.createdAt, this.kind, this.tags,
      this.content, this.sig);

  factory Event.fromJson(Map<String, dynamic> data) {
    final id = data['id'] as String;
    final pubkey = data['pubkey'] as String;
    final createdAt = data['created_at'] as int;
    final kind = data['kind'] as int;
    final tags = data['tags'];
    final content = data['content'] as String;
    final sig = data['sig'] == null ? "" : data['sig'] as String;

    return Event._(id, pubkey, createdAt, kind, tags, content, sig);
  }

  /// The event ID is a 32-byte SHA256 hash of the serialised event data.
  String id = '';

  /// The event author's public key.
  final String pubkey;

  /// Event creation timestamp in Unix time.
  late int createdAt;

  /// Event kind identifier (e.g. text_note, set_metadata, etc).
  final int kind;

  /// A JSON array of event tags.
  List<dynamic> tags; // Modified by proof-of-work

  /// Event content.
  String content;

  /// 64-byte Schnorr signature of [Event.id].
  String sig = '';

  /// Relay that an event was received from.
  List<String> sources = [];

  /// whether this event is from cache relay.
  bool cacheEvent = false;

  /// Returns the Event object as a JSON object
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pubkey': pubkey,
      'created_at': createdAt,
      'kind': kind,
      'tags': tags,
      'content': content,
      'sig': sig
    };
  }

  void doProofOfWork(int difficulty) {
    if (difficulty < 0) {
      throw ArgumentError("PoW difficulty can't be negative", 'difficulty');
    }
    if (difficulty > 0) {
      final difficultyInBytes = (difficulty / 8).ceil();
      List<dynamic> result = [];
      for (List<dynamic> tag in tags) {
        result.add(tag);
      }
      result.add(["nonce", "0", difficulty.toString()]);
      tags = result;
      int nonce = 0;
      do {
        const int nonceIndex = 1;
        tags.last[nonceIndex] = (++nonce).toString();
        id = _getId(pubkey, createdAt, kind, tags, content);
      } while (_countLeadingZeroBytes(id) < difficultyInBytes);
    }
  }

  void sign(String privateKey) {
    if (keyIsValid(privateKey)) {
      final aux = getRandomHexString();
      sig = schnorr.sign(privateKey, id, aux);
    }
  }

  bool get isValid {
    // Validate event data
    if (id != _getId(pubkey, createdAt, kind, tags, content)) {
      return false;
    }
    return true;
  }

  bool get isSigned {
    if (sig.isEmpty) {
      return false;
    }
    try {
      return schnorr.verify(pubkey, id, sig);
    } catch (e) {
      return false;
    }
  }

  // Individual events with the same "id" are equivalent
  @override
  bool operator ==(other) => other is Event && id == other.id;
  @override
  int get hashCode => id.hashCode;

  static int _secondsSinceEpoch() {
    final now = clock.now();
    final secondsSinceEpoch = now.millisecondsSinceEpoch ~/ 1000;
    return secondsSinceEpoch;
  }

  static String _getId(String publicKey, int createdAt, int kind,
      List<dynamic> tags, String content) {
    final jsonData =
        json.encode([0, publicKey, createdAt, kind, tags, content]);
    final bytes = utf8.encode(jsonData);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  int _countLeadingZeroBytes(String eventId) {
    List<int> bytes = HEX.decode(eventId);
    int zeros = 0;
    for (int i = 0; i < bytes.length; i++) {
      if (bytes[i] == 0) {
        zeros = (i + 1);
      } else {
        break;
      }
    }
    return zeros;
  }
}
