import 'dart:convert';
import 'dart:math';

import 'package:bip340/bip340.dart' as schnorr;
import 'package:challenge_protocol/challenge_protocol.dart';
import 'package:crypto/crypto.dart';

// Fresh test-only identities. No signing key is persisted in source or
// fixtures.
final class SyntheticSigner {
  SyntheticSigner() {
    final random = Random.secure();
    _key = List.generate(
      32,
      (_) => random.nextInt(256),
    ).map((n) => n.toRadixString(16).padLeft(2, '0')).join();
    pubkey = schnorr.getPublicKey(_key);
  }
  late final String _key;
  late final String pubkey;

  Map<String, Object?> sign({
    int kind = 31923,
    int createdAt = 100,
    String content = '',
    List<List<String>> tags = const [],
  }) {
    final id = sha256
        .convert(
          utf8.encode(
            jsonEncode([
              0,
              pubkey,
              createdAt,
              kind,
              tags,
              content,
            ]),
          ),
        )
        .toString();
    return {
      'id': id,
      'pubkey': pubkey,
      'sig': schnorr.sign(_key, id, '00' * 32),
      'created_at': createdAt,
      'kind': kind,
      'content': content,
      'tags': tags,
    };
  }

  Map<String, Object?> template(EventTemplate value) => sign(
    kind: value.kind,
    createdAt: value.createdAt,
    content: value.content,
    tags: value.tags,
  );

  Map<String, Object?> definition({
    int createdAt = 100,
    String title = 'Synthetic challenge',
    String content = 'Human-made synthetic rules.',
    int start = 100,
    int end = 200,
    String timezone = 'UTC',
    String? endTimezone,
    String relay = 'wss://relay.example.test',
    String status = 'active',
    String identifier = 'synthetic:challenge',
    List<List<String>> extra = const [],
  }) => sign(
    createdAt: createdAt,
    content: content,
    tags: [
      ['t', 'divine-challenge'],
      ['challenge', '1', 'definition'],
      ['d', identifier],
      ['title', title],
      ['start', '$start'],
      ['end', '$end'],
      ['start_tzid', timezone],
      if (endTimezone != null) ['end_tzid', endTimezone],
      ['challenge_status', status],
      ['challenge_relay', relay],
      for (var day = start ~/ 86400; day <= (end - 1) ~/ 86400; day++)
        ['D', '$day'],
      ...extra,
    ],
  );
}

ChallengeDefinition definitionOf(Map<String, Object?> event) =>
    parseChallengeEvent(event).value! as ChallengeDefinition;
ChallengeEntry entryOf(Map<String, Object?> event) =>
    parseChallengeEvent(event).value! as ChallengeEntry;
