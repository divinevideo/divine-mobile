// MPL-2.0
import 'dart:convert';
import 'dart:typed_data';

import 'package:bip340/bip340.dart' as schnorr;
import 'package:concord_protocol/concord_protocol.dart';
import 'package:concord_repository/src/sealed_transport.dart';
import 'package:test/test.dart';

// Synthetic identities, never used outside these tests.
final String _authorSecret = '01'.padLeft(64, '0');
final String _author = schnorr.getPublicKey(_authorSecret);
final String _channel = '12' * 32;
final GroupKey _stream = publicChannelKey('34' * 32, _channel, 0);

Map<String, dynamic> _rumor({List<List<String>>? tags}) {
  final event = <String, dynamic>{
    'pubkey': _author,
    'created_at': 1700000000,
    'kind': 9,
    'tags':
        tags ??
        [
          ['channel', _channel],
          ['epoch', '0'],
        ],
    'content': 'hello',
  };
  return {...event, 'id': _id(event)};
}

String _id(Map<String, dynamic> event) => sha256Hex(
  jsonEncode([
    0,
    event['pubkey'],
    event['created_at'],
    event['kind'],
    event['tags'],
    event['content'],
  ]),
);

Map<String, dynamic> _sign(Map<String, dynamic> event, String secret) {
  final id = _id(event);
  return {...event, 'id': id, 'sig': schnorr.sign(secret, id, '00' * 32)};
}

Future<Map<String, dynamic>> _seal(
  Map<String, dynamic> rumor, {
  int kind = 20013,
}) => sealRumor(
  rumor: rumor,
  sealKind: kind,
  streamSeedHex: _stream.seedHex,
  streamPubkey: _stream.pubkey,
  authorSecretHex: _authorSecret,
);

Future<Map<String, dynamic>> _wrap(Map<String, dynamic> seal) => wrapSeal(
  seal: seal,
  streamSeedHex: _stream.seedHex,
  streamPubkey: _stream.pubkey,
);

Future<Map<String, dynamic>> _open(Map<String, dynamic> wrap) => openWrap(
  wrap: wrap,
  expectedChannelId: _channel,
  expectedEpoch: 0,
  streamSeedHex: _stream.seedHex,
  streamPubkey: _stream.pubkey,
);

Matcher _failure(String message) => throwsA(
  isA<FormatException>().having(
    (error) => error.message,
    'message',
    contains(message),
  ),
);

void main() {
  group('NIP-44 plaintext length', () {
    final key = Uint8List(32);
    test('rejects empty and overflowing UTF-8 plaintext', () async {
      for (final text in ['', 'a' * 65536, 'é' * 32768]) {
        await expectLater(nip44Encrypt(text, key), throwsArgumentError);
      }
    });
    test('round-trips both valid byte boundaries', () async {
      for (final text in ['a', '${'é' * 32767}a']) {
        expect(await nip44Decrypt(await nip44Encrypt(text, key), key), text);
      }
    });
  });

  group('chat envelope validation', () {
    test('accepts valid messages without optional milliseconds', () async {
      expect(
        (await _open(await _wrap(await _seal(_rumor()))))['content'],
        'hello',
      );
    });
    test('authenticates the outer signature and id', () async {
      final wrap = await _wrap(await _seal(_rumor()));
      await expectLater(
        _open({...wrap, 'sig': '00' * 64}),
        _failure('bad-wrap-signature'),
      );
      await expectLater(
        _open({...wrap, 'id': '00' * 32}),
        _failure('bad-wrap-signature'),
      );
    });
    test('wraps include the supplied signed expiration', () async {
      final rumor = _rumor(
        tags: [
          ['channel', _channel],
          ['epoch', '0'],
          ['expiration', '1800000000'],
        ],
      );
      final wrap = await wrapSeal(
        seal: await _seal(rumor),
        streamSeedHex: _stream.seedHex,
        streamPubkey: _stream.pubkey,
        expiresAt: 1800000000,
      );
      expect(wrap['tags'], contains(equals(['expiration', '1800000000'])));
      expect((await _open(wrap))['rumor'], rumor);
    });
    test('wrap timestamps preserve the sealed creation time', () async {
      final seal = await _seal(_rumor());
      expect((await _wrap(seal))['created_at'], seal['created_at']);
    });
    test('checks inner ids inside valid surrounding signatures', () async {
      final rumor = {..._rumor(), 'id': '00' * 32};
      await expectLater(
        _open(await _wrap(await _seal(rumor))),
        _failure('bad-rumor-id'),
      );
      final seal = {...await _seal(_rumor()), 'id': '00' * 32};
      await expectLater(
        _open(await _wrap(seal)),
        _failure('bad-seal-signature'),
      );
    });
    test('rejects malformed JSON event objects at both inner layers', () async {
      final conv = conversationKey(_stream.seedHex, _stream.pubkey);
      final wrap = await _wrap(await _seal(_rumor()));
      final badWrap = _sign({
        ...wrap,
        'content': await nip44Encrypt('[]', conv),
      }, _stream.seedHex);
      await expectLater(_open(badWrap), _failure('event must be an object'));
      final seal = _sign({
        'kind': 20013,
        'pubkey': _author,
        'created_at': 1700000000,
        'tags': <List<String>>[],
        'content': await nip44Encrypt('[]', conv),
      }, _authorSecret);
      await expectLater(
        _open(await _wrap(seal)),
        _failure('event must be an object'),
      );
    });
    test('preserves unknown rumor tags with expiration', () async {
      final rumor = _rumor(
        tags: [
          ['channel', _channel],
          ['epoch', '0'],
          ['ms', '999'],
          ['expiration', '1800000000'],
          ['custom', 'unchanged'],
          ['e', '56' * 32, '', 'reply'],
        ],
      );
      final wrap = await _wrap(await _seal(rumor));
      final expiring = _sign({
        ...wrap,
        'tags': [
          ...(wrap['tags'] as List),
          ['expiration', '1800000000'],
        ],
      }, _stream.seedHex);
      expect((await _open(expiring))['rumor'], rumor);
    });
    test('rejects malformed reference tags and envelope fields', () async {
      final rumor = _rumor(
        tags: [
          ['channel', _channel],
          ['epoch', '0'],
          ['e', 'AB' * 32],
        ],
      );
      await expectLater(
        _open(await _wrap(await _seal(rumor))),
        _failure('malformed reference tag'),
      );
      final wrap = await _wrap(await _seal(_rumor()));
      await expectLater(
        _open(_sign({...wrap, 'kind': 13}, _stream.seedHex)),
        _failure('bad-wrap-kind'),
      );
      await expectLater(
        _open({...wrap, 'sig': null}),
        _failure('malformed event'),
      );
      await expectLater(
        _open({...wrap, 'tags': 'not an array'}),
        _failure('malformed event'),
      );
    });
    test('rejects bad seal signature inside a valid outer wrap', () async {
      final seal = await _seal(_rumor());
      final wrap = await _wrap({...seal, 'sig': '00' * 64});
      expect(
        schnorr.verify(
          _stream.pubkey,
          wrap['id'] as String,
          wrap['sig'] as String,
        ),
        isTrue,
      );
      await expectLater(_open(wrap), _failure('bad-seal-signature'));
    });
    test(
      'rejects author mismatch behind valid seal and wrap signatures',
      () async {
        final rumor = {
          ..._rumor(),
          'pubkey': schnorr.getPublicKey('02'.padLeft(64, '0')),
        };
        rumor['id'] = _id(rumor);
        final seal = await _seal(rumor);
        expect(
          schnorr.verify(_author, seal['id'] as String, seal['sig'] as String),
          isTrue,
        );
        await expectLater(
          _open(await _wrap(seal)),
          _failure('author-mismatch'),
        );
      },
    );
    test('rejects control seals on a chat stream', () async {
      await expectLater(
        _open(await _wrap(await _seal(_rumor(), kind: 20014))),
        _failure('bad-seal-kind'),
      );
    });
    test('requires one exact channel and epoch binding', () async {
      for (final tags in <List<List<String>>>[
        [],
        [
          ['channel', '56' * 32],
          ['epoch', '0'],
        ],
        [
          ['channel', _channel],
          ['epoch', '1'],
        ],
        [
          ['channel', _channel],
          ['epoch', '0'],
          ['epoch', '0'],
        ],
        [
          ['channel', _channel],
          ['channel', _channel],
          ['epoch', '0'],
        ],
      ]) {
        await expectLater(
          _open(await _wrap(await _seal(_rumor(tags: tags)))),
          _failure('binding'),
        );
      }
    });
    test('rejects noncanonical event fields', () async {
      for (final changes in <Map<String, dynamic>>[
        {'created_at': 1.5},
        {'created_at': -1},
        {'created_at': 8640000000001},
        {'kind': 9.5},
        {'content': null},
        {'pubkey': _author.toUpperCase()},
        {
          'tags': [
            ['epoch', 0],
          ],
        },
        {
          'tags': <List<String>>[[]],
        },
      ]) {
        final rumor = {..._rumor(), ...changes};
        rumor['id'] = _id(rumor);
        // Build the seal independently: malformed timestamps are still covered
        // by a valid author signature so event validation must reject them.
        final content = await nip44Encrypt(
          jsonEncode(rumor),
          conversationKey(_stream.seedHex, _stream.pubkey),
        );
        final seal = _sign({
          'kind': 20013,
          'pubkey': _author,
          'created_at': 1700000000,
          'tags': <List<String>>[],
          'content': content,
        }, _authorSecret);
        await expectLater(
          _open(await _wrap(seal)),
          throwsA(isA<FormatException>()),
        );
      }
    });
    test('accepts the last timestamp a DateTime can hold', () async {
      final rumor = {..._rumor(), 'created_at': 8640000000000};
      rumor['id'] = _id(rumor);
      final opened = await _open(await _wrap(await _seal(rumor)));
      expect((opened['rumor'] as Map)['created_at'], 8640000000000);
    });
    test('rejects noncanonical binding and millisecond tags', () async {
      for (final tag in <List<String>>[
        ['epoch', '00'],
        ['epoch', '+0'],
        ['epoch', '-0'],
        ['ms', '1000'],
        ['ms', '-1'],
        ['ms', '01'],
        ['ms', '1.0'],
      ]) {
        final tags = [
          ['channel', _channel],
          if (tag.first != 'epoch') ['epoch', '0'],
          tag,
        ];
        await expectLater(
          _open(await _wrap(await _seal(_rumor(tags: tags)))),
          throwsA(isA<FormatException>()),
        );
      }
    });
    test(
      'valid signatures do not authorize malformed wrap or seal tags',
      () async {
        final seal = await _seal(_rumor());
        final wrap = await _wrap(seal);
        for (final tags in <List<dynamic>>[
          [],
          [
            ['p', 1],
          ],
          [
            ['p', 'AB' * 32],
          ],
          [
            ['p', _author],
            ['p', _author],
          ],
        ]) {
          await expectLater(
            _open(_sign({...wrap, 'tags': tags}, _stream.seedHex)),
            throwsA(isA<FormatException>()),
          );
        }
        final invalidSeal = _sign({
          ...seal,
          'tags': [
            ['p', _author],
          ],
        }, _authorSecret);
        await expectLater(
          _open(await _wrap(invalidSeal)),
          throwsA(isA<FormatException>()),
        );
      },
    );
  });
}
