part of '../challenge_protocol.dart';

/// Immutable copy of exactly the seven signed Nostr wire fields.
///
/// Construction alone does not establish authenticity. Parsing and builders
/// always reverify these fields, including the event ID and BIP-340 signature.
final class NostrEvent {
  /// Copies all tags, including their inner arrays.
  NostrEvent({
    required this.id,
    required this.pubkey,
    required this.sig,
    required this.createdAt,
    required this.kind,
    required this.content,
    required List<List<String>> tags,
  }) : tags = _freezeTags(tags);

  /// Validates a wire value and copies only its authenticated fields.
  factory NostrEvent.fromJson(Map<String, Object?> json) =>
      _verifiedEvent(json);

  /// Lowercase full-length event ID.
  final String id;

  /// Lowercase full-length public key.
  final String pubkey;

  /// BIP-340 signature.
  final String sig;

  /// Claimed Unix creation seconds.
  final int createdAt;

  /// Nostr event kind.
  final int kind;

  /// Signed text content.
  final String content;

  /// Deeply immutable signed tags.
  final List<List<String>> tags;

  /// Fresh JSON map, in the canonical codec's signed-field order.
  Map<String, Object?> toJson() => {
    'id': id,
    'pubkey': pubkey,
    'sig': sig,
    'created_at': createdAt,
    'kind': kind,
    'content': content,
    'tags': tags.map((tag) => tag.toList()).toList(),
  };
}

List<List<String>> _freezeTags(List<List<String>> tags) =>
    List.unmodifiable(tags.map(List<String>.unmodifiable));

const int _maxEventBytes = 64 * 1024;
const _maxSafeInteger = 9007199254740991;
final _hex = RegExp(r'^[0-9a-f]{64}$');
final _signature = RegExp(r'^[0-9a-f]{128}$');
final _decimal = RegExp(r'^(0|[1-9][0-9]*)$');

bool _safeTimestamp(Object? value) =>
    value is num &&
    value.isFinite &&
    value >= 0 &&
    value <= _maxSafeInteger &&
    value == value.truncateToDouble();

NostrEvent _verifiedEvent(Object? input, {bool enforceSize = true}) {
  final wire = input is NostrEvent ? input.toJson() : input;
  _require(wire is Map<String, Object?>, 'shape', 'Expected a signed event.');
  final e = wire! as Map<String, Object?>;
  _require(
    e['id'] is String &&
        _hex.hasMatch(e['id']! as String) &&
        e['pubkey'] is String &&
        _hex.hasMatch(e['pubkey']! as String) &&
        e['sig'] is String &&
        _signature.hasMatch(e['sig']! as String),
    'shape',
    'Invalid event ID, public key, or signature encoding.',
  );
  final kind = e['kind'];
  _require(
    _safeTimestamp(e['created_at']) &&
        _safeTimestamp(kind) &&
        (kind! as num) <= 65535 &&
        e['content'] is String,
    'shape',
    'Invalid signed event fields.',
  );
  final tags = e['tags'];
  _require(
    tags is List<Object?> &&
        tags.every(
          (tag) =>
              tag is List<Object?> && tag.every((value) => value is String),
        ),
    'shape',
    'Invalid event tags.',
  );
  final event = NostrEvent(
    id: e['id']! as String,
    pubkey: e['pubkey']! as String,
    sig: e['sig']! as String,
    createdAt: (e['created_at']! as num).toInt(),
    kind: (kind! as num).toInt(),
    content: e['content']! as String,
    tags: (tags! as List<Object?>)
        .map((t) => (t! as List<Object?>).cast<String>())
        .toList(),
  );
  if (enforceSize) {
    _require(
      utf8.encode(jsonEncode(event.toJson())).length <= _maxEventBytes,
      'size',
      'Signed records may not exceed 64 KiB.',
    );
  }
  final id = sha256
      .convert(
        utf8.encode(
          jsonEncode([
            0,
            event.pubkey,
            event.createdAt,
            event.kind,
            event.tags,
            event.content,
          ]),
        ),
      )
      .toString();
  var authentic = false;
  if (id == event.id) {
    try {
      authentic = schnorr.verify(event.pubkey, id, event.sig);
    } on Object {
      authentic = false;
    }
  }
  _require(
    authentic,
    'signature',
    'Event ID or signature could not be verified.',
  );
  return event;
}
