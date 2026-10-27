import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nip04/nip04.dart';

// Synthetic keys. The payload was produced by `nak` 0.20.6, an independent
// NIP-04 implementation, so these tests do not lean on [NIP04.encrypt] to say
// what valid ciphertext looks like.
const _senderPubkey =
    '6f84e1157c594a3a30ee25943c44a96106076e9184aded89c2f73946e0252286';
const _recipientPrivateKey =
    '1d2c3b4a59687766554433221100ffeeddccbbaa99887766554433221100ff01';
const _ciphertext =
    'WpJTI8eH70aeA/LAneRTOtppZ37p3cR1vsG+FosC3b9FtIwqknvTc6qvL2RUOGrp';
const _iv = '7nPnLlh3IwQzb+Z8xwpdkg==';
const _payload = '$_ciphertext?iv=$_iv';

/// From the same sender to a different recipient, also produced by `nak`.
const _payloadForAnotherRecipient =
    'frkb1N4rnki0zNjn4gnQKSbcUEcgY2X8lgN8zk+MT4qUxMB2IIlUH9dURh0H014W'
    '?iv=KR5RbN4CZE7tdq9XxeeLsA==';

const _malformedPayloads = <String, String>{
  'no ?iv= separator': 'garbage!!!',
  'an empty payload': '',
  'ciphertext without an iv': _ciphertext,
  'two ?iv= separators': '$_ciphertext?iv=$_iv?iv=$_iv',
  'an iv that is not base64': '$_ciphertext?iv=!!!',
  'an iv shorter than 16 bytes': '$_ciphertext?iv=AAAAAA==',
  'an iv longer than 16 bytes':
      '$_ciphertext?iv=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
  'ciphertext that is not whole AES blocks': 'AQIDBAU=?iv=$_iv',
  'empty ciphertext': '?iv=$_iv',
  'ciphertext that is not base64': '!!!!?iv=$_iv',
};

void main() {
  group(NIP04, () {
    group('isWellFormedPayload', () {
      test('accepts a payload produced by another implementation', () {
        expect(NIP04.isWellFormedPayload(_payload), isTrue);
      });

      for (final MapEntry(key: shape, value: payload)
          in _malformedPayloads.entries) {
        test('rejects $shape', () {
          expect(NIP04.isWellFormedPayload(payload), isFalse);
        });
      }
    });

    group('decrypt', () {
      test('decrypts a payload produced by another implementation', () {
        expect(
          NIP04.decrypt(
            _payload,
            NIP04.getAgreement(_recipientPrivateKey),
            _senderPubkey,
          ),
          equals('hello from an independent implementation'),
        );
      });

      test('throws FormatException for a payload sent to another key', () {
        expect(
          () => NIP04.decrypt(
            _payloadForAnotherRecipient,
            NIP04.getAgreement(_recipientPrivateKey),
            _senderPubkey,
          ),
          throwsFormatException,
        );
      });

      for (final MapEntry(key: shape, value: payload)
          in _malformedPayloads.entries) {
        test('throws FormatException for $shape', () {
          expect(
            () => NIP04.decrypt(
              payload,
              NIP04.getAgreement(_recipientPrivateKey),
              _senderPubkey,
            ),
            throwsFormatException,
          );
        });
      }
    });
  });
}
