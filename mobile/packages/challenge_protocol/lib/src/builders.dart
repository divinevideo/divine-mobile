part of '../challenge_protocol.dart';

/// Immutable unsigned event fields. No signer, identity, or delivery is
/// implied.
final class EventTemplate {
  EventTemplate._(
    this.kind,
    this.createdAt,
    this.content,
    List<List<String>> tags,
  ) : tags = _freezeTags(tags);

  /// Nostr kind (1111 for participant actions).
  final int kind;

  /// Claimed Unix creation seconds.
  final int createdAt;

  /// Signed content to review before consent.
  final String content;

  /// Deeply immutable tags to review before consent.
  final List<List<String>> tags;

  /// Fresh map for a signing adapter.
  Map<String, Object?> toJson() => {
    'kind': kind,
    'created_at': createdAt,
    'content': content,
    'tags': tags.map((t) => t.toList()).toList(),
  };
}

EventTemplate _template(
  int createdAt,
  String content,
  List<List<String>> tags,
) {
  _require(_safeTimestamp(createdAt), 'time', 'Expected integer Unix seconds.');
  final value = EventTemplate._(1111, createdAt, content, tags);
  _require(
    utf8
            .encode(
              jsonEncode({
                ...value.toJson(),
                'pubkey': '0' * 64,
                'id': '0' * 64,
                'sig': '0' * 128,
              }),
            )
            .length <=
        _maxEventBytes,
    'size',
    'Signed record would exceed 64 KiB.',
  );
  return value;
}

List<List<String>> _marker(String action) => [
  ['t', 'divine-challenge'],
  ['challenge', '1', action],
];
List<List<String>> _rootTags(ChallengeDefinition d) => [
  ['A', d.coordinate],
  ['K', '31923'],
  ['P', d.event.pubkey],
];
List<List<String>> _parentTags(ChallengeDefinition d) => [
  ..._rootTags(d),
  ['a', d.coordinate],
  ['k', '31923'],
  ['p', d.event.pubkey],
  ['e', d.event.id],
];

/// Builds entrant consent to an exact signed video under signed challenge
/// rules.
///
/// Revalidates signed sources instead of trusting projected fields. The caller
/// must fetch current rules, check visibility and signer equals video author,
/// obtain consent, sign, then validate the returned event and exact template.
EventTemplate buildEntry(
  ChallengeDefinition definition,
  NostrEvent video,
  int createdAt,
) {
  final d = _parseDefinition(_verifiedEvent(definition.event));
  final v = _verifiedEvent(video);
  _require(
    d.status == 'active' && createdAt >= d.start && createdAt < d.end,
    'time',
    'Challenge is not open.',
  );
  _require(
    [21, 22, 34235, 34236].contains(v.kind),
    'video',
    'Unsupported video kind.',
  );
  if (v.kind >= 30000) {
    final identifiers = _tags(v, 'd');
    _require(
      identifiers.length == 1 &&
          identifiers.first.length > 1 &&
          identifiers.first[1].isNotEmpty,
      'video',
      'Addressable video needs an identifier.',
    );
  }
  return _template(createdAt, 'nostr:${_noteEncode(v.id)}', [
    ..._marker('entry'),
    ..._parentTags(d),
    ['q', v.id],
    ['challenge_snapshot', jsonEncode(d.event.toJson())],
    ['video_snapshot', jsonEncode(v.toJson())],
  ]);
}

/// Builds withdrawal of one exact entry, reparsing both signed sources.
///
/// A future signing adapter must check the signer is the entry author, obtain
/// explicit consent, and revalidate the signed result before publication.
EventTemplate buildWithdrawal(
  ChallengeDefinition definition,
  ChallengeEntry entry,
  int createdAt,
) {
  final d = _parseDefinition(_verifiedEvent(definition.event));
  final parsed = parseChallengeEvent(entry.event).value;
  if (parsed is! ChallengeEntry || parsed.coordinate != d.coordinate) {
    throw const ContractError('entry', 'Expected an entry in this challenge.');
  }
  return _template(createdAt, 'Withdrawing my entry.', [
    ..._marker('withdraw'),
    ..._rootTags(d),
    ['e', parsed.event.id],
    ['k', '1111'],
    ['p', parsed.event.pubkey],
  ]);
}
