// ABOUTME: Regression tests for RelayPool._onEvent signature-verification
// ABOUTME: dedup and known-verified event trust (cold-start CPU optimization).

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:nostr_sdk/relay/client_connected.dart';

/// A fake relay that lets tests drive `onMessage` directly and records
/// nothing else. No real network I/O.
class _FakeRelay extends Relay {
  _FakeRelay(String url, {int relayType = RelayType.normal})
    : super(url, RelayStatus(url, relayType: relayType));

  @override
  Future<bool> doConnect() async {
    relayStatus.connected = ClientConnected.connected;
    return true;
  }

  @override
  Future<void> disconnect() async {
    relayStatus.connected = ClientConnected.disconnect;
  }

  @override
  Future<bool> send(
    List<dynamic> message, {
    bool queueIfFailed = true,
    bool skipReconnect = false,
    DateTime? deadline,
  }) async {
    return true;
  }

  /// Drive an inbound message through the handler RelayPool wired up.
  Future<void> deliver(List<dynamic> json) async {
    final handler = onMessage;
    expect(handler, isNotNull, reason: 'RelayPool did not wire onMessage');
    final dynamic result = handler!(this, json);
    if (result is Future) {
      await result;
    }
  }
}

void main() {
  group('RelayPool._onEvent signature verify', () {
    const privateKey =
        '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';
    const subId = 'sub-verify-dedup';
    // A 64-byte (128 hex char) but cryptographically invalid signature.
    const badSig =
        '0000000000000000000000000000000000000000000000000000000000000000'
        '0000000000000000000000000000000000000000000000000000000000000000';

    Relay dummyTempRelay(String url) => RelayBase(url, RelayStatus(url));

    late Nostr nostr;
    late List<Event> received;

    setUp(() {
      nostr = Nostr(LocalNostrSigner(privateKey), [], dummyTempRelay);
      received = <Event>[];
      nostr.relayPool.subscribe(
        [
          {
            'kinds': [EventKind.textNote],
          },
        ],
        received.add,
        id: subId,
      );
    });

    /// Builds a validly signed text-note event JSON for [content].
    Map<String, dynamic> signedEventJson({String content = 'hello'}) {
      final pubkey = getPublicKey(privateKey);
      final event = Event(
        pubkey,
        EventKind.textNote,
        [],
        content,
        createdAt: 1700000000,
      );
      event.sign(privateKey);
      return event.toJson();
    }

    test('routes a validly signed network event', () async {
      final relay = _FakeRelay('wss://n1.example');
      await nostr.relayPool.add(relay);

      await relay.deliver(['EVENT', subId, signedEventJson()]);

      expect(received, hasLength(1));
      expect(received.single.hasVerifiedSignature, isTrue);
    });

    test('checks a policy-skipped pair when verification is enabled', () async {
      final pool = nostr.relayPool;
      pool.signatureVerificationPolicy =
          SignatureVerificationPolicy.nonDivineRelays;
      final relay = _FakeRelay('wss://relay.divine.video');
      await pool.add(relay);

      final unchecked = signedEventJson()
        ..['sig'] = badSig
        ..['signature_verified'] = true;
      await relay.deliver(['EVENT', subId, unchecked]);

      expect(received.single.hasVerifiedSignature, isFalse);

      pool.signatureVerificationPolicy = SignatureVerificationPolicy.all;
      await relay.deliver(['EVENT', subId, unchecked]);

      expect(received, hasLength(1));
    });

    test('drops a network event with an invalid signature', () async {
      final relay = _FakeRelay('wss://n1.example');
      await nostr.relayPool.add(relay);

      final json = signedEventJson()..['sig'] = badSig;
      await relay.deliver(['EVENT', subId, json]);

      expect(received, isEmpty);
    });

    test('routes a duplicate id from a second relay (dedup skips verify, '
        'never drops)', () async {
      final r1 = _FakeRelay('wss://n1.example');
      final r2 = _FakeRelay('wss://n2.example');
      await nostr.relayPool.add(r1);
      await nostr.relayPool.add(r2);

      final json = signedEventJson();
      await r1.deliver(['EVENT', subId, json]);
      await r2.deliver(['EVENT', subId, Map<String, dynamic>.from(json)]);

      // Both copies route, but the second must be skipped (not re-verified):
      // the counters pin that the session (id, sig) dedup actually fired.
      expect(received, hasLength(2));
      expect(nostr.relayPool.verifiesPerformed, 1);
      expect(nostr.relayPool.verifiesSkippedSessionDup, 1);
    });

    test('re-verifies a same-session duplicate id delivered with a different, '
        'invalid signature', () async {
      // Pins that the *session* dedup key is (id, sig), not id alone. Relay A
      // delivers a valid event (its (id, sig) enters the verified set); relay
      // B replays the same id with a forged signature. Because the pair
      // differs, it must fall through to a full verify, fail, and be dropped.
      // If the session key were id-only this forged copy would be trusted.
      final r1 = _FakeRelay('wss://n1.example');
      final r2 = _FakeRelay('wss://n2.example');
      await nostr.relayPool.add(r1);
      await nostr.relayPool.add(r2);

      final valid = signedEventJson();
      await r1.deliver(['EVENT', subId, valid]);

      final forged = Map<String, dynamic>.from(valid)..['sig'] = badSig;
      await r2.deliver(['EVENT', subId, forged]);

      expect(received, hasLength(1));
      expect(nostr.relayPool.verifiesSkippedSessionDup, 0);
    });

    test(
      'drops a known-verified pair whose body no longer hashes to its id',
      () async {
        // isValid (sha256 id recompute) runs before the skip branches and is the
        // sole body-integrity guard. A "known" (id, sig) pair delivered with a
        // tampered body must be dropped here, before the skip can trust it.
        final relay = _FakeRelay('wss://n1.example');
        await nostr.relayPool.add(relay);

        final valid = signedEventJson();
        final id = valid['id'] as String;
        final sig = valid['sig'] as String;
        nostr.relayPool.isKnownVerifiedEvent = (eventId, eventSig) =>
            eventId == id && eventSig == sig;

        final tampered = Map<String, dynamic>.from(valid)
          ..['content'] = 'tampered body — id no longer matches';
        await relay.deliver(['EVENT', subId, tampered]);

        expect(received, isEmpty);
        expect(nostr.relayPool.verifiesSkippedKnown, 0);
      },
    );

    test(
      'skips verify for (id, sig) pairs known-verified from a prior session',
      () async {
        // The app seeds (id, sig) pairs verified and persisted in a prior
        // session. A network event whose exact pair is known is trusted and
        // routed without re-verifying.
        final relay = _FakeRelay('wss://n1.example');
        await nostr.relayPool.add(relay);

        final json = signedEventJson();
        final id = json['id'] as String;
        final sig = json['sig'] as String;
        nostr.relayPool.isKnownVerifiedEvent = (eventId, eventSig) =>
            eventId == id && eventSig == sig;

        await relay.deliver(['EVENT', subId, json]);

        expect(received, hasLength(1));
        expect(nostr.relayPool.verifiesSkippedKnown, 1);
        expect(nostr.relayPool.verifiesPerformed, 0);
      },
    );

    test('re-verifies and drops a known id carrying a different, invalid '
        'signature', () async {
      // The id is known-verified, but the incoming signature differs from
      // the one that was verified. A Nostr event id commits to the body,
      // not to sig, so the pool must NOT trust the id alone: it re-verifies,
      // the forged signature fails, and the event is dropped.
      final relay = _FakeRelay('wss://n1.example');
      await nostr.relayPool.add(relay);

      final valid = signedEventJson();
      final id = valid['id'] as String;
      final validSig = valid['sig'] as String;
      nostr.relayPool.isKnownVerifiedEvent = (eventId, eventSig) =>
          eventId == id && eventSig == validSig;

      final forged = Map<String, dynamic>.from(valid)..['sig'] = badSig;
      await relay.deliver(['EVENT', subId, forged]);

      expect(received, isEmpty);
      expect(nostr.relayPool.verifiesSkippedKnown, 0);
    });

    test('still verifies ids absent from the known-verified set', () async {
      final relay = _FakeRelay('wss://n1.example');
      await nostr.relayPool.add(relay);
      nostr.relayPool.isKnownVerifiedEvent = (_, _) => false;

      await relay.deliver(['EVENT', subId, signedEventJson(content: 'ok')]);

      expect(received, hasLength(1));
      expect(nostr.relayPool.verifiesPerformed, 1);
      expect(nostr.relayPool.verifiesSkippedKnown, 0);
    });
  });
}
