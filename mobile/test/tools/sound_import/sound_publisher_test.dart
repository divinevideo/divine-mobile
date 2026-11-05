// ABOUTME: Guards publishing against unuploaded URLs and stale signing caches.
// ABOUTME: Uses synthetic hashes and accounts, without keys or network writes.

import 'package:flutter_test/flutter_test.dart';

import '../../../tools/sound_import/import_state.dart';
import '../../../tools/sound_import/sound_publisher.dart';

final String _sha = 'a' * 64;
final String _account = 'b' * 64;
const _server = 'https://media.example/base';

Map<String, dynamic> _event(String url, {String pubkey = ''}) => {
  'pubkey': pubkey,
  'tags': [
    ['x', _sha],
    ['url', url],
  ],
};

void main() {
  group('isSoundPublishEligible', () {
    final record = ImportRecord(
      status: ImportStatus.prepared,
      outputSha256: _sha,
      uploadedTo: [_server],
    );
    bool eligible(Map<String, dynamic> event, {List<ImportRecord>? records}) =>
        isSoundPublishEligible(
          event,
          records ?? [record],
          expectedPubkey: _account,
        );

    test('accepts the complete hash URL on the recorded server', () {
      expect(eligible(_event('$_server/$_sha')), isTrue);
    });
    test('rejects a hash uploaded only to a different server', () {
      expect(eligible(_event('https://other.example/$_sha')), isFalse);
    });
    test('rejects wrong path, hash, query, fragment and missing URL', () {
      for (final url in [
        'https://media.example/$_sha',
        '$_server/${'c' * 64}',
        '$_server/$_sha?download=1',
        '$_server/$_sha#fragment',
        '$_server/$_sha/extra',
      ]) {
        expect(eligible(_event(url)), isFalse, reason: url);
      }
      expect(
        eligible({
          'tags': [
            ['x', _sha],
          ],
        }),
        isFalse,
      );
      expect(
        eligible(
          _event('$_server/$_sha'),
          records: [
            ImportRecord(
              status: ImportStatus.prepared,
              outputSha256: 'c' * 64,
              uploadedTo: [_server],
            ),
          ],
        ),
        isFalse,
      );
    });
    test('validates every URL and rejects ambiguous file hashes', () {
      final event = _event('$_server/$_sha');
      (event['tags'] as List<List<String>>).add([
        'url',
        'https://other.example/$_sha',
      ]);
      expect(eligible(event), isFalse);
      final hashes = _event('$_server/$_sha');
      (hashes['tags'] as List<List<String>>).add(['x', 'c' * 64]);
      expect(eligible(hashes), isFalse);
    });
  });

  group('soundEventForPublish', () {
    test('checks cached URL, not the regenerated unsigned URL', () {
      final cached = _event('https://old.example/$_sha', pubkey: _account);
      final effective = soundEventForPublish(
        _event('$_server/$_sha'),
        cached,
        expectedPubkey: _account,
      );
      expect(effective, same(cached));
      expect(
        isSoundPublishEligible(effective, [
          ImportRecord(
            status: ImportStatus.prepared,
            outputSha256: _sha,
            uploadedTo: [_server],
          ),
        ], expectedPubkey: _account),
        isFalse,
      );
    });
    test('fails safely rather than reusing another account signed event', () {
      expect(
        () => soundEventForPublish(
          _event('$_server/$_sha'),
          _event('$_server/$_sha', pubkey: 'c' * 64),
          expectedPubkey: _account,
        ),
        throwsFormatException,
      );
    });
    test('rejects cached hash mismatch and preserves valid retry identity', () {
      final cached = _event('$_server/$_sha', pubkey: _account)
        ..['id'] = 'd' * 64;
      expect(
        soundEventForPublish(
          _event('$_server/$_sha'),
          cached,
          expectedPubkey: _account,
        ),
        same(cached),
      );
      final changed = _event('$_server/${'c' * 64}')
        ..['tags'] = [
          ['x', 'c' * 64],
          ['url', '$_server/${'c' * 64}'],
        ];
      expect(
        () => soundEventForPublish(changed, cached, expectedPubkey: _account),
        throwsFormatException,
      );
    });
  });
}
