part of '../challenge_protocol.dart';

const _day = 86400;
List<List<String>> _tags(NostrEvent e, String name) =>
    e.tags.where((t) => t.isNotEmpty && t[0] == name).toList();
String _one(NostrEvent e, String name) {
  final found = _tags(e, name);
  _require(
    found.length == 1 && found[0].length > 1,
    'tags',
    'Expected one $name tag.',
  );
  return found[0][1];
}

String? _optionalOne(NostrEvent e, String name) =>
    _tags(e, name).isEmpty ? null : _one(e, name);
int _timestamp(String value) {
  final parsed = num.tryParse(value);
  _require(
    _decimal.hasMatch(value) && _safeTimestamp(parsed),
    'time',
    'Expected integer Unix seconds.',
  );
  return parsed!.toInt();
}

// ECMAScript String.trim whitespace differs from Dart (notably U+0085).
final _nonBlank = RegExp(
  r'[^\u0009-\u000D\u0020\u00A0\u1680\u2000-\u200A'
  r'\u2028\u2029\u202F\u205F\u3000\uFEFF]',
);

void _checkTitle(String value, int maximum) {
  _require(
    _nonBlank.hasMatch(value) && value.characters.length <= maximum,
    'length',
    'Text must contain 1–$maximum graphemes.',
  );
}

void _checkTimeZone(String value) {
  _require(
    recognizedTimeZones.contains(value.toLowerCase()),
    'timezone',
    'Unknown IANA timezone.',
  );
}

void _checkRelay(String value) {
  // WHATWG special URLs ignore surrounding C0 whitespace and normalize slashes.
  final normalized = value
      .replaceAll(RegExp(r'[\t\r\n]'), '')
      .replaceAll(RegExp(r'^[\x00-\x20]+|[\x00-\x20]+$'), '')
      .replaceAll(r'\', '/');
  final prefix = RegExp(
    '^(wss?):/*',
    caseSensitive: false,
  ).firstMatch(normalized);
  _require(prefix != null, 'relay', 'Expected a WebSocket relay URL.');
  Uri? uri;
  try {
    uri = Uri.parse(
      '${prefix!.group(1)!.toLowerCase()}://${normalized.substring(prefix.end)}',
    );
  } on FormatException {
    throw const ContractError('relay', 'Invalid relay URL.');
  }
  _require(
    uri.host.isNotEmpty &&
        uri.userInfo.isEmpty &&
        uri.fragment.isEmpty &&
        !RegExp(r'[\x00-\x20<>^|]').hasMatch(uri.host) &&
        uri.port <= 65535,
    'relay',
    'Expected a WebSocket relay URL.',
  );
}

String _actionOf(NostrEvent e) {
  final marker = _tags(e, 'challenge');
  _require(
    marker.length == 1 && marker[0].length == 3,
    'marker',
    'Expected exactly one challenge marker.',
  );
  _require(
    marker[0][1] == '1',
    'unsupported_version',
    'Unsupported challenge version.',
  );
  final action = marker[0][2];
  _require(
    ['definition', 'entry', 'withdraw', 'result'].contains(action),
    'marker',
    'Unknown challenge action.',
  );
  _require(
    _tags(e, 't').any((t) => t.length > 1 && t[1] == 'divine-challenge'),
    'marker',
    'Missing discovery hashtag.',
  );
  return action;
}

ChallengeDefinition _parseDefinition(NostrEvent e) {
  _require(
    e.tags.every((t) => t.isNotEmpty),
    'shape',
    'Event tags must not be empty.',
  );
  _require(
    _actionOf(e) == 'definition' && e.kind == 31923,
    'kind',
    'Expected a challenge definition.',
  );
  final identifier = _one(e, 'd');
  _require(
    identifier.isNotEmpty,
    'coordinate',
    'A challenge needs an identifier.',
  );
  final title = _one(e, 'title');
  _checkTitle(title, 120);
  _require(
    utf8.encode(e.content).length <= 8192,
    'size',
    'Prompt must fit in 8 KiB.',
  );
  final start = _timestamp(_one(e, 'start'));
  final end = _timestamp(_one(e, 'end'));
  _require(
    end > start && end - start <= 90 * _day,
    'time',
    'Entry window must be positive and at most 90 days.',
  );
  final timeZone = _one(e, 'start_tzid');
  final endTimeZone = _optionalOne(e, 'end_tzid') ?? timeZone;
  _checkTimeZone(timeZone);
  _checkTimeZone(endTimeZone);
  final days = _tags(e, 'D').map((t) => t.length > 1 ? t[1] : null).toSet();
  for (var day = start ~/ _day; day <= (end - 1) ~/ _day; day++) {
    _require(days.contains('$day'), 'days', 'Missing UTC day index.');
  }
  for (final day in days) {
    final number = day == null ? null : num.tryParse(day);
    _require(
      day != null &&
          _decimal.hasMatch(day) &&
          number != null &&
          number >= start ~/ _day &&
          number <= (end - 1) ~/ _day,
      'days',
      'Invalid UTC day index.',
    );
  }
  final relayTags = _tags(e, 'challenge_relay');
  _require(
    relayTags.isNotEmpty &&
        relayTags.length <= 4 &&
        relayTags.every((t) => t.length > 1),
    'relay',
    'A challenge needs 1–4 relays.',
  );
  final relays = relayTags.map((t) => t[1]).toList()..forEach(_checkRelay);
  final status = _one(e, 'challenge_status');
  _require(
    status == 'active' || status == 'cancelled',
    'status',
    'Invalid challenge status.',
  );
  return ChallengeDefinition(
    event: e,
    coordinate: '31923:${e.pubkey}:$identifier',
    identifier: identifier,
    title: title,
    start: start,
    end: end,
    timeZone: timeZone,
    endTimeZone: endTimeZone,
    relays: relays,
    status: status,
  );
}

String _root(NostrEvent e) {
  final coordinate = _one(e, 'A');
  final parsed = _parseCoordinate(coordinate);
  _require(
    _one(e, 'K') == '31923' &&
        _one(e, 'P') == parsed.pubkey &&
        _tags(e, 'E').isEmpty &&
        _tags(e, 'I').isEmpty,
    'root',
    'Invalid challenge root.',
  );
  return coordinate;
}

NostrEvent _snapshot(NostrEvent e, String name) {
  Object? parsed;
  try {
    // Dart's JSON parser uses an explicit state stack. The signed outer record
    // bounds this string; no recursive copying of unsigned extensions occurs.
    parsed = jsonDecode(_one(e, name));
  } on Object {
    throw ContractError('snapshot', 'Invalid $name.');
  }
  return _verifiedEvent(parsed);
}

ChallengeDefinition _definitionSnapshot(NostrEvent e, String coordinate) {
  final definition = _parseDefinition(_snapshot(e, 'challenge_snapshot'));
  _require(
    definition.coordinate == coordinate &&
        _one(e, 'a') == coordinate &&
        _one(e, 'k') == '31923' &&
        _one(e, 'p') == definition.event.pubkey &&
        _one(e, 'e') == definition.event.id &&
        _tags(e, 'i').isEmpty,
    'parent',
    'Parent and snapshot must match the challenge root.',
  );
  return definition;
}

void _requireCitation(NostrEvent e, String id) {
  _require(
    _tags(e, 'q').any((t) => t.length > 1 && t[1] == id) &&
        _citedIds(e.content).contains(id),
    'citation',
    'Missing event citation.',
  );
}

ChallengeEntry _parseEntry(NostrEvent e, String coordinate) {
  final definition = _definitionSnapshot(e, coordinate);
  final video = _snapshot(e, 'video_snapshot');
  _require(
    [21, 22, 34235, 34236].contains(video.kind),
    'video',
    'Unsupported video kind.',
  );
  _require(
    e.pubkey == video.pubkey,
    'author',
    'Only the video author may enter it.',
  );
  _require(
    definition.status == 'active' &&
        e.createdAt >= definition.start &&
        e.createdAt < definition.end,
    'time',
    'Entry must reference an active, open definition.',
  );
  _requireCitation(e, video.id);
  var videoIdentity = video.id;
  if (video.kind >= 30000) {
    final d = _one(video, 'd');
    _require(d.isNotEmpty, 'video', 'Addressable video needs an identifier.');
    videoIdentity = '${video.kind}:${video.pubkey}:$d';
  }
  return ChallengeEntry(
    event: e,
    coordinate: coordinate,
    definition: definition,
    video: video,
    videoIdentity: videoIdentity,
  );
}

ChallengeWithdrawal _parseWithdrawal(NostrEvent e, String coordinate) {
  final entryId = _one(e, 'e');
  _require(
    _hex.hasMatch(entryId) &&
        _one(e, 'k') == '1111' &&
        _one(e, 'p') == e.pubkey &&
        _tags(e, 'a').isEmpty &&
        _tags(e, 'i').isEmpty,
    'parent',
    "Withdrawal must target the author's entry.",
  );
  return ChallengeWithdrawal._(e, coordinate, entryId);
}

ChallengeResult _parseResult(NostrEvent e, String coordinate) {
  final definition = _definitionSnapshot(e, coordinate);
  _require(
    e.pubkey == definition.event.pubkey,
    'author',
    'Only the organizer may publish results.',
  );
  _require(
    definition.status == 'active' && e.createdAt >= definition.end,
    'time',
    'Results require a closed entry window.',
  );
  final selection = _tags(e, 'winner');
  _require(
    selection.isNotEmpty && selection.length <= 20,
    'winners',
    'Results need 1–20 winners.',
  );
  final winners = selection.map((tag) {
    _require(
      tag.length == 3 && _hex.hasMatch(tag[1]),
      'winners',
      'Invalid winner tag.',
    );
    _checkTitle(tag[2], 80);
    _requireCitation(e, tag[1]);
    return Winner(entryId: tag[1], label: tag[2]);
  }).toList();
  _require(
    winners.map((w) => w.entryId).toSet().length == winners.length,
    'winners',
    'Winning entries must be unique.',
  );
  return ChallengeResult._(e, coordinate, definition, winners);
}

/// Verifies fresh signed fields, snapshots, and challenge convention semantics.
///
/// Unsigned outer extensions are ignored. Malformed input returns the canonical
/// error code; it never becomes an authoritative projection.
ParseResult parseChallengeEvent(Object? input) {
  try {
    final event = _verifiedEvent(input);
    _require(
      event.tags.every((t) => t.isNotEmpty),
      'shape',
      'Event tags must not be empty.',
    );
    final action = _actionOf(event);
    if (action == 'definition') {
      return ParseResult._(_parseDefinition(event), null, null);
    }
    _require(event.kind == 1111, 'kind', 'Challenge actions must be comments.');
    final coordinate = _root(event);
    final value = switch (action) {
      'entry' => _parseEntry(event, coordinate),
      'withdraw' => _parseWithdrawal(event, coordinate),
      _ => _parseResult(event, coordinate),
    };
    return ParseResult._(value, null, null);
  } on ContractError catch (error) {
    return ParseResult._(null, error.code, error.message);
  } on Object {
    return const ParseResult._(null, 'shape', 'Invalid challenge event.');
  }
}
