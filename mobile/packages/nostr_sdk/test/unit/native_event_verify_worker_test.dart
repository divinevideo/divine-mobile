// ABOUTME: Tests for the web relay-event verify worker that delegates BIP-340
// ABOUTME: checks to a native verifier and falls back to Dart if it breaks.

import 'dart:async';

import 'package:bip340/bip340.dart' as bip340;
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

const _privateKey =
    '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';

Future<Event> _signedEvent(String content) async {
  final signer = LocalNostrSigner(_privateKey);
  final pubkey = await signer.getPublicKey();
  final event = Event(
    pubkey!,
    EventKind.textNote,
    [],
    content,
    createdAt: 1780000000,
  );
  await signer.signEvent(event);
  return event;
}

Map<String, dynamic> _json(Event e) => Map<String, dynamic>.from(e.toJson());

typedef _Call = ({String pubkey, String message, String signature});

/// A native verifier backed by the real BIP-340 implementation, recording
/// what it was asked. Mapping the named arguments onto bip340's positional
/// `(publicKey, message, signature)` is what a swapped binding would break.
class _RecordingVerifier {
  final calls = <_Call>[];

  Future<bool> call({
    required String pubkey,
    required String message,
    required String signature,
  }) async {
    calls.add((pubkey: pubkey, message: message, signature: signature));
    return bip340.verify(pubkey, message, signature);
  }
}

void main() {
  group(NativeEventVerifyWorker, () {
    group('verify', () {
      test('passes pubkey, id and signature to the native verifier', () async {
        final native = _RecordingVerifier();
        final worker = NativeEventVerifyWorker(native.call);
        addTearDown(worker.close);
        final event = await _signedEvent('valid');

        expect(await worker.verify(_json(event)), isTrue);
        expect(native.calls, [
          (pubkey: event.pubkey, message: event.id, signature: event.sig),
        ]);
      });

      test('returns false when the native verifier rejects', () async {
        final worker = NativeEventVerifyWorker(({
          required pubkey,
          required message,
          required signature,
        }) async {
          return false;
        });
        addTearDown(worker.close);
        final event = await _signedEvent('valid');

        expect(await worker.verify(_json(event)), isFalse);
      });

      test('rejects an event whose content no longer matches its id '
          'without asking the native verifier', () async {
        final native = _RecordingVerifier();
        final worker = NativeEventVerifyWorker(native.call);
        addTearDown(worker.close);
        final event = await _signedEvent('original');

        final tampered = _json(event)..['content'] = 'tampered';

        expect(await worker.verify(tampered), isFalse);
        expect(native.calls, isEmpty);
      });

      test(
        'rejects a malformed signature without asking the native verifier',
        () async {
          final native = _RecordingVerifier();
          final worker = NativeEventVerifyWorker(native.call);
          addTearDown(worker.close);
          final event = await _signedEvent('valid');

          final malformed = _json(event)..['sig'] = 'zz' * 64;

          expect(await worker.verify(malformed), isFalse);
          expect(native.calls, isEmpty);
          expect(worker.usesNativeVerifier, isTrue);
        },
      );

      test('rejects a payload that is not an event', () async {
        final worker = NativeEventVerifyWorker(_RecordingVerifier().call);
        addTearDown(worker.close);

        expect(await worker.verify({'kind': 'not-a-number'}), isFalse);
      });
    });

    group('backend failure', () {
      test('verifies in Dart and stops using the native verifier', () async {
        var nativeCalls = 0;
        final worker = NativeEventVerifyWorker(({
          required pubkey,
          required message,
          required signature,
        }) async {
          nativeCalls++;
          throw StateError('crypto.subtle is unavailable');
        });
        addTearDown(worker.close);
        final first = await _signedEvent('first');
        final second = await _signedEvent('second');

        expect(await worker.verify(_json(first)), isTrue);
        expect(worker.usesNativeVerifier, isFalse);
        expect(await worker.verify(_json(second)), isTrue);
        expect(nativeCalls, 1);
      });

      test('still rejects a forged signature after falling back', () async {
        final worker = NativeEventVerifyWorker(({
          required pubkey,
          required message,
          required signature,
        }) async {
          throw StateError('crypto.subtle is unavailable');
        });
        addTearDown(worker.close);
        final event = await _signedEvent('real');
        final other = await _signedEvent('other');

        final forged = _json(event)..['sig'] = other.sig;

        expect(await worker.verify(forged), isFalse);
        expect(worker.usesNativeVerifier, isFalse);
      });
    });

    group('close', () {
      test('fails a verify that is still pending', () async {
        final worker = NativeEventVerifyWorker(({
          required pubkey,
          required message,
          required signature,
        }) {
          return Completer<bool>().future;
        });
        final event = await _signedEvent('pending');

        final pending = worker.verify(_json(event));
        await pumpEventQueue();
        worker.close();

        await expectLater(pending, throwsStateError);
      });

      test('throws when verify is called after close', () async {
        final worker = NativeEventVerifyWorker(_RecordingVerifier().call)
          ..close();
        final event = await _signedEvent('late');

        expect(() => worker.verify(_json(event)), throwsStateError);
      });
    });

    group('spawn', () {
      test('throws off the web, where there is no native verifier', () async {
        await expectLater(
          NativeEventVerifyWorker.spawn(),
          throwsUnsupportedError,
        );
      });
    });
  });
}
