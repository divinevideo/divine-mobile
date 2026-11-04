import 'dart:convert';

import 'package:concord_protocol/concord_protocol.dart';
import 'package:test/test.dart';

void main() {
  test('CORD-05 v4 explicit relays preserve token and skip unknown ids', () {
    final fragment = base64Url.encode([
      4,
      0,
      2,
      200,
      0,
      12,
      ...utf8.encode('chat.example'),
      ...List.filled(16, 7),
    ]);
    final parsed = ConcordInviteFragment.decode(fragment);
    expect(parsed.relays, ['wss://chat.example']);
    expect(parsed.token, List.filled(16, 7));
  });
  test('rejects legacy, future, truncated and trailing invite fragments', () {
    for (final bytes in [
      [3, 1, ...List.filled(16, 7)],
      [5, 1, ...List.filled(16, 7)],
      [4, 0, 4],
      [4, 1, ...List.filled(17, 7)],
      [4, 1],
    ]) {
      expect(
        () => ConcordInviteFragment.decode(base64Url.encode(bytes)),
        throwsFormatException,
      );
    }
  });
  test(
    'bundle identity self-certifies owner and rejects expired membership',
    () {
      final owner = '11' * 32;
      final salt = '22' * 32;
      final json = <String, dynamic>{
        'community_id': deriveCommunityId(owner, salt),
        'owner': owner,
        'owner_salt': salt,
        'community_root': '33' * 32,
        'root_epoch': 2,
        'channels': <dynamic>[],
        'relays': <String>[],
        'name': 'Synthetic',
        'expires_at': 1000,
      };
      expect(ConcordInviteBundle.fromJson(json, nowMs: 1000).rootEpoch, 2);
      expect(
        () => ConcordInviteBundle.fromJson(json, nowMs: 1001),
        throwsFormatException,
      );
      json['owner'] = '44' * 32;
      expect(
        () => ConcordInviteBundle.fromJson(json, nowMs: 0),
        throwsFormatException,
      );
    },
  );
  test(
    'bundle normalizes bounded relay and description previews like CORD-05',
    () {
      final owner = '11' * 32;
      final salt = '22' * 32;
      final bundle = ConcordInviteBundle.fromJson({
        'community_id': deriveCommunityId(owner, salt),
        'owner': owner,
        'owner_salt': salt,
        'community_root': '33' * 32,
        'root_epoch': 0,
        'channels': <dynamic>[],
        'relays': [
          '',
          'wss://a',
          'wss://a',
          1,
          'wss://b',
          'wss://c',
          'wss://d',
          'wss://e',
          'wss://f',
        ],
        'description': 'é' * 251,
      }, nowMs: 0);
      expect(bundle.raw['relays'], [
        'wss://a',
        'wss://b',
        'wss://c',
        'wss://d',
        'wss://e',
      ]);
      expect(bundle.raw['description'], 'é' * 250);
    },
  );
}
