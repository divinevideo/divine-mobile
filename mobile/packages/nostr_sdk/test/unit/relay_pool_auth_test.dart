// ABOUTME: Regression tests for RelayPool AUTH branch empty-pubkey race.
// ABOUTME: Ensures NIP-42 AUTH challenges do not crash when the cached
// ABOUTME: public key is empty (post-signOut, mid-init, account switch), and
// ABOUTME: that fire-and-forget temp-relay publishes survive the handshake.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:nostr_sdk/relay/client_connected.dart';

/// A signer that returns null for getPublicKey (simulates unconfigured signer).
class _NullKeySigner implements NostrSigner {
  @override
  Future<String?> getPublicKey() async => null;

  @override
  Future<Event?> signEvent(Event event) async => null;

  @override
  Future<Map?> getRelays() async => null;

  @override
  Future<String?> encrypt(String pubkey, String plaintext) async => null;

  @override
  Future<String?> decrypt(String pubkey, String ciphertext) async => null;

  @override
  Future<String?> nip44Encrypt(String pubkey, String plaintext) async => null;

  @override
  Future<String?> nip44Decrypt(String pubkey, String ciphertext) async => null;

  @override
  void close() {}
}

/// A fake relay that records sent messages and allows tests to drive
/// `onMessage` directly. No real network I/O.
class _AuthFakeRelay extends Relay {
  _AuthFakeRelay(String url) : super(url, RelayStatus(url));

  final List<List<dynamic>> sentMessages = [];

  /// When true, [send] records the frame but reports transport failure, so the
  /// failing post-auth resend path can be exercised.
  bool failSends = false;
  bool? lastQueueIfFailed;
  DateTime? lastDeadline;

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
    sentMessages.add(message);
    lastQueueIfFailed = queueIfFailed;
    lastDeadline = deadline;
    return !failSends;
  }

  /// Drive an inbound message through the handler registered by RelayPool,
  /// awaiting the async result so exceptions surface to the test.
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
  const testPrivateKey =
      '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';
  const challenge =
      'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789';

  List<List<dynamic>> sentMessagesOfType(_AuthFakeRelay relay, String type) {
    return relay.sentMessages
        .where((m) => m.isNotEmpty && m.first == type)
        .toList(growable: false);
  }

  String sentAuthEventId(_AuthFakeRelay relay) {
    final authMessages = sentMessagesOfType(relay, 'AUTH');
    expect(authMessages, hasLength(1));
    final authEvent = authMessages.single[1] as Map<String, dynamic>;
    final id = authEvent['id'];
    expect(id, isA<String>());
    return id as String;
  }

  group('RelayPool AUTH branch empty-pubkey guard', () {
    Relay dummyTempRelay(String url) => RelayBase(url, RelayStatus(url));

    test(
      'lazily refreshes publicKey from signer when cache is empty',
      () async {
        final signer = LocalNostrSigner(testPrivateKey);
        final nostr = Nostr(signer, [], dummyTempRelay);
        // Deliberately skip refreshPublicKey() — simulates the race window
        // where the relay delivers an AUTH challenge before init populated
        // the cache (post-signOut, mid-init, account switch).
        expect(nostr.publicKey, isEmpty);

        final fakeRelay = _AuthFakeRelay('wss://auth-fake.example');
        final added = await nostr.relayPool.add(fakeRelay);
        expect(added, isTrue);

        // BEFORE FIX: Event constructor throws ArgumentError because
        // Nostr.publicKey is '' and keyIsValid('') returns false. The
        // async _onEvent returns a rejected Future which relay_base
        // discards (fire-and-forget), so in production it escapes to
        // runZonedGuarded. In this test we await the handler result and
        // the ArgumentError propagates — failing the test.
        // AFTER FIX: ensurePublicKey refreshes the cache and the AUTH
        // response is signed and sent.
        await fakeRelay.deliver(['AUTH', challenge]);

        expect(
          nostr.publicKey,
          isNotEmpty,
          reason: 'AUTH handler should refresh the cached pubkey from signer',
        );
        final sentAuth = sentMessagesOfType(fakeRelay, 'AUTH');
        expect(
          sentAuth,
          hasLength(1),
          reason: 'AUTH handler should send one AUTH response',
        );
      },
    );

    test('does not leak async error when signer has no key', () async {
      final signer = _NullKeySigner();
      final nostr = Nostr(signer, [], dummyTempRelay);

      final fakeRelay = _AuthFakeRelay('wss://auth-fake.example');
      final added = await nostr.relayPool.add(fakeRelay);
      expect(added, isTrue);

      // BEFORE FIX: Event() throws ArgumentError — surfaces as unhandled
      // async error. AFTER FIX: the AUTH branch catches StateError from
      // ensurePublicKey and logs, returning normally.
      await expectLater(fakeRelay.deliver(['AUTH', challenge]), completes);

      // No AUTH response should have been produced since no key is
      // available to sign one.
      final sentAuth = sentMessagesOfType(fakeRelay, 'AUTH');
      expect(sentAuth, isEmpty);
    });

    test('marks relay alwaysAuth after AUTH challenge', () async {
      final signer = LocalNostrSigner(testPrivateKey);
      final nostr = Nostr(signer, [], dummyTempRelay);
      await nostr.refreshPublicKey();

      final fakeRelay = _AuthFakeRelay('wss://auth-fake.example');
      final added = await nostr.relayPool.add(fakeRelay);
      expect(added, isTrue);
      expect(fakeRelay.relayStatus.alwaysAuth, isFalse);

      await fakeRelay.deliver(['AUTH', challenge]);

      expect(fakeRelay.relayStatus.alwaysAuth, isTrue);
      expect(sentMessagesOfType(fakeRelay, 'AUTH'), hasLength(1));
    });
  });

  group('RelayPool auth-required publish retry', () {
    late LocalNostrSigner signer;
    late Nostr nostr;
    late _AuthFakeRelay relay;

    setUp(() async {
      signer = LocalNostrSigner(testPrivateKey);
      nostr = Nostr(signer, [], (url) => RelayBase(url, RelayStatus(url)));
      await nostr.refreshPublicKey();
      relay = _AuthFakeRelay('wss://auth-required.example');
      final added = await nostr.relayPool.add(relay);
      expect(added, isTrue);
    });

    test('republishes an awaited EVENT once after NIP-42 succeeds', () async {
      const eventId =
          '1111111111111111111111111111111111111111111111111111111111111111';
      final outcomeFuture = nostr.relayPool.sendEventAwaitOk(
        [
          'EVENT',
          {'id': eventId, 'kind': EventKind.giftWrap},
        ],
        eventId: eventId,
        targetRelays: [relay.url],
        timeout: const Duration(seconds: 1),
      );

      expect(sentMessagesOfType(relay, 'EVENT'), hasLength(1));

      await relay.deliver([
        'OK',
        eventId,
        false,
        'auth-required: you must auth',
      ]);
      var completed = false;
      unawaited(outcomeFuture.then((_) => completed = true));
      await Future<void>.delayed(Duration.zero);
      expect(
        completed,
        isFalse,
        reason: 'auth-required rejection should wait for AUTH retry',
      );

      await relay.deliver(['AUTH', challenge]);
      final authEventId = sentAuthEventId(relay);
      await relay.deliver(['OK', authEventId, true, '']);

      expect(
        sentMessagesOfType(relay, 'EVENT'),
        hasLength(2),
        reason: 'the original EVENT should be retried once after AUTH',
      );

      await relay.deliver(['OK', eventId, true, '']);
      final outcome = await outcomeFuture;

      expect(outcome.confirmed, isTrue);
      expect(outcome.acceptedBy, equals([relay.url]));
      expect(outcome.rejectedBy, isEmpty);
      expect(relay.relayStatus.alwaysAuth, isTrue);
    });

    test(
      'registers auth-required query even when trigger send fails',
      () async {
        relay.relayStatus.alwaysAuth = true;
        relay.failSends = true;
        final subscription = Subscription([
          Filter(kinds: [EventKind.textNote]).toJson(),
        ], (_) {});

        final result = await nostr.relayPool.relayDoQuery(
          relay,
          subscription,
          false,
        );

        expect(result, isTrue);
        expect(relay.checkQuery(subscription.id), isTrue);
        expect(sentMessagesOfType(relay, 'REQ'), hasLength(1));
        expect(relay.lastQueueIfFailed, isFalse);
        expect(relay.lastDeadline, isNotNull);
      },
    );

    test('bounds an auth-required subscription trigger at the send', () async {
      relay.relayStatus.alwaysAuth = true;
      relay.failSends = true;
      final subscription = Subscription([
        Filter(kinds: [EventKind.textNote]).toJson(),
      ], (_) {});

      final result = await nostr.relayPool.relayDoSubscribe(
        relay,
        subscription,
        false,
      );

      expect(result, isFalse);
      expect(relay.getSubscriptions(), contains(subscription));
      expect(relay.lastQueueIfFailed, isFalse);
      expect(relay.lastDeadline, isNotNull);
    });

    test('republishes when AUTH OK arrives before EVENT rejection', () async {
      const eventId =
          '3333333333333333333333333333333333333333333333333333333333333333';
      final outcomeFuture = nostr.relayPool.sendEventAwaitOk(
        [
          'EVENT',
          {'id': eventId, 'kind': EventKind.giftWrap},
        ],
        eventId: eventId,
        targetRelays: [relay.url],
        timeout: const Duration(seconds: 1),
      );

      await relay.deliver(['AUTH', challenge]);
      final authEventId = sentAuthEventId(relay);
      await relay.deliver(['OK', authEventId, true, '']);
      await relay.deliver([
        'OK',
        eventId,
        false,
        'auth-required: you must auth',
      ]);

      expect(sentMessagesOfType(relay, 'EVENT'), hasLength(2));

      await relay.deliver(['OK', eventId, true, '']);
      final outcome = await outcomeFuture;

      expect(outcome.confirmed, isTrue);
      expect(outcome.acceptedBy, equals([relay.url]));
    });

    test('does not loop when the relay keeps rejecting after AUTH', () async {
      const eventId =
          '2222222222222222222222222222222222222222222222222222222222222222';
      final outcomeFuture = nostr.relayPool.sendEventAwaitOk(
        [
          'EVENT',
          {'id': eventId, 'kind': EventKind.giftWrap},
        ],
        eventId: eventId,
        targetRelays: [relay.url],
        timeout: const Duration(seconds: 1),
      );

      await relay.deliver([
        'OK',
        eventId,
        false,
        'auth-required: you must auth',
      ]);
      await relay.deliver(['AUTH', challenge]);
      final authEventId = sentAuthEventId(relay);
      await relay.deliver(['OK', authEventId, true, '']);
      // A second auth-required after AUTH would re-trigger a retry if the
      // dedup marker were missing; the tracked entry must suppress it. Using
      // an auth-required reason here (not "restricted") isolates the dedup
      // guard as the sole reason the second republish does not happen.
      await relay.deliver(['OK', eventId, false, 'auth-required: still no']);

      final outcome = await outcomeFuture;

      expect(outcome.failed, isTrue);
      expect(outcome.acceptedBy, isEmpty);
      expect(
        outcome.rejectedBy,
        equals({relay.url: 'auth-required: still no'}),
      );
      expect(
        sentMessagesOfType(relay, 'EVENT'),
        hasLength(2),
        reason: 'the dedup marker must prevent a second post-auth republish',
      );
    });

    test('fails fast on restricted rejection with no AUTH offered', () async {
      const eventId =
          '4444444444444444444444444444444444444444444444444444444444444444';
      final outcomeFuture = nostr.relayPool.sendEventAwaitOk(
        [
          'EVENT',
          {'id': eventId, 'kind': EventKind.giftWrap},
        ],
        eventId: eventId,
        targetRelays: [relay.url],
        timeout: const Duration(seconds: 1),
      );

      // The relay never sends an AUTH challenge (alwaysAuth stays false), so a
      // bare "restricted" is a permanent members-only rejection, not NIP-42.
      await relay.deliver([
        'OK',
        eventId,
        false,
        'restricted: not on allow list',
      ]);

      final outcome = await outcomeFuture;

      expect(outcome.failed, isTrue);
      expect(
        outcome.rejectedBy,
        equals({relay.url: 'restricted: not on allow list'}),
      );
      expect(
        sentMessagesOfType(relay, 'EVENT'),
        hasLength(1),
        reason: 'a members-only relay that never offers AUTH must not retry',
      );
    });

    test('rejects the publish when the relay AUTH fails', () async {
      const eventId =
          '5555555555555555555555555555555555555555555555555555555555555555';
      final outcomeFuture = nostr.relayPool.sendEventAwaitOk(
        [
          'EVENT',
          {'id': eventId, 'kind': EventKind.giftWrap},
        ],
        eventId: eventId,
        targetRelays: [relay.url],
        timeout: const Duration(seconds: 1),
      );

      await relay.deliver([
        'OK',
        eventId,
        false,
        'auth-required: you must auth',
      ]);
      await relay.deliver(['AUTH', challenge]);
      final authEventId = sentAuthEventId(relay);
      await relay.deliver([
        'OK',
        authEventId,
        false,
        'auth failed: bad signature',
      ]);

      final outcome = await outcomeFuture;

      expect(outcome.failed, isTrue);
      expect(
        outcome.rejectedBy,
        equals({relay.url: 'auth failed: bad signature'}),
      );
      expect(
        sentMessagesOfType(relay, 'EVENT'),
        hasLength(1),
        reason: 'a failed AUTH must not retry the EVENT',
      );
    });

    test('reports auth-required reason when relay never challenges', () async {
      const eventId =
          '7777777777777777777777777777777777777777777777777777777777777777';
      final outcomeFuture = nostr.relayPool.sendEventAwaitOk(
        [
          'EVENT',
          {'id': eventId, 'kind': EventKind.giftWrap},
        ],
        eventId: eventId,
        targetRelays: [relay.url],
        timeout: const Duration(milliseconds: 10),
      );

      await relay.deliver([
        'OK',
        eventId,
        false,
        'auth-required: you must auth',
      ]);

      final outcome = await outcomeFuture;

      expect(outcome.failed, isTrue);
      expect(
        outcome.rejectedBy,
        equals({relay.url: 'auth-required: you must auth'}),
      );
      expect(outcome.noResponseFrom, isEmpty);
    });

    test('rejects with stored reason when AUTH cannot be signed', () async {
      const eventId =
          '8888888888888888888888888888888888888888888888888888888888888888';
      final unauthenticatedNostr = Nostr(
        _NullKeySigner(),
        [],
        (url) => RelayBase(url, RelayStatus(url)),
      );
      final unauthenticatedRelay = _AuthFakeRelay(
        'wss://auth-required-no-key.example',
      );
      final added = await unauthenticatedNostr.relayPool.add(
        unauthenticatedRelay,
      );
      expect(added, isTrue);
      final outcomeFuture = unauthenticatedNostr.relayPool.sendEventAwaitOk(
        [
          'EVENT',
          {'id': eventId, 'kind': EventKind.giftWrap},
        ],
        eventId: eventId,
        targetRelays: [unauthenticatedRelay.url],
        timeout: const Duration(seconds: 1),
      );

      await unauthenticatedRelay.deliver([
        'OK',
        eventId,
        false,
        'auth-required: you must auth',
      ]);
      await unauthenticatedRelay.deliver(['AUTH', challenge]);

      final outcome = await outcomeFuture;

      expect(outcome.failed, isTrue);
      expect(
        outcome.rejectedBy,
        equals({unauthenticatedRelay.url: 'auth-required: you must auth'}),
      );
      expect(sentMessagesOfType(unauthenticatedRelay, 'AUTH'), isEmpty);
    });

    test(
      'reports what the relay said when the post-auth resend fails',
      () async {
        const eventId =
            '6666666666666666666666666666666666666666666666666666666666666666';
        final outcomeFuture = nostr.relayPool.sendEventAwaitOk(
          [
            'EVENT',
            {'id': eventId, 'kind': EventKind.giftWrap},
          ],
          eventId: eventId,
          targetRelays: [relay.url],
          timeout: const Duration(seconds: 1),
        );

        await relay.deliver([
          'OK',
          eventId,
          false,
          'auth-required: you must auth',
        ]);
        await relay.deliver(['AUTH', challenge]);
        final authEventId = sentAuthEventId(relay);
        relay.failSends = true;
        await relay.deliver(['OK', authEventId, true, '']);

        final outcome = await outcomeFuture;

        expect(outcome.failed, isTrue);
        expect(outcome.acceptedBy, isEmpty);
        // The relay answered — `auth-required` is why the retry existed — so
        // it must not be reported as a target we never reached, and its
        // reason is the only thing that tells the caller to fix the auth
        // rather than the network.
        expect(
          outcome.rejectedBy,
          equals({relay.url: 'auth-required: you must auth'}),
        );
        expect(outcome.unreachableTargets, isEmpty);
        expect(outcome.noResponseFrom, isEmpty);
        expect(
          sentMessagesOfType(relay, 'EVENT'),
          hasLength(2),
          reason: 'the resend is attempted once before giving up',
        );
      },
    );
  });

  // Regression coverage for #7701: a fire-and-forget `RelayPool.send` to a temp
  // relay creates no PublishTracker, so the auth-required recovery the awaited
  // path relies on never runs and the event used to vanish silently.
  group('fire-and-forget temp-relay publish across NIP-42', () {
    const tempRelayUrl = 'wss://temp-auth.example';
    late LocalNostrSigner signer;
    late Nostr nostr;
    late _AuthFakeRelay tempRelay;

    setUp(() async {
      signer = LocalNostrSigner(testPrivateKey);
      tempRelay = _AuthFakeRelay(tempRelayUrl);
      nostr = Nostr(signer, [], (_) => tempRelay);
      await nostr.refreshPublicKey();
    });

    List<dynamic> eventFrame(String id) => [
      'EVENT',
      {'id': id, 'kind': EventKind.giftWrap},
    ];

    /// Completes the NIP-42 handshake the relay is asking for, returning the
    /// id of the AUTH event the pool signed.
    Future<String> completeHandshake({bool succeed = true}) async {
      await tempRelay.deliver(['AUTH', challenge]);
      final authEventId = sentAuthEventId(tempRelay);
      await tempRelay.deliver([
        'OK',
        authEventId,
        succeed,
        succeed ? '' : 'auth failed: bad signature',
      ]);
      return authEventId;
    }

    test('replays the first-round frame the relay answered with '
        'auth-required', () async {
      const eventId =
          'aaaa111111111111111111111111111111111111111111111111111111111111';

      final sent = await nostr.relayPool.send(
        eventFrame(eventId),
        tempRelays: [tempRelayUrl],
      );

      expect(sent, isTrue);
      // alwaysAuth is still false on a fresh connection, so the frame has to go
      // out to provoke the challenge — it cannot be parked up front.
      expect(sentMessagesOfType(tempRelay, 'EVENT'), hasLength(1));

      await tempRelay.deliver([
        'OK',
        eventId,
        false,
        'auth-required: you must auth',
      ]);
      await completeHandshake();

      // BEFORE FIX: nothing recorded the written frame, so the post-AUTH flush
      // had nothing to replay and the event was gone.
      expect(
        sentMessagesOfType(tempRelay, 'EVENT'),
        hasLength(2),
        reason: 'the retained first-round frame must be replayed after AUTH',
      );
      expect(
        sentMessagesOfType(tempRelay, 'EVENT').last,
        equals(eventFrame(eventId)),
      );
    });

    test('replays even when the relay challenges without answering the '
        'EVENT', () async {
      const eventId =
          'aaaa222222222222222222222222222222222222222222222222222222222222';

      await nostr.relayPool.send(
        eventFrame(eventId),
        tempRelays: [tempRelayUrl],
      );
      // Some relays send the challenge and never OK the frame that provoked it.
      await completeHandshake();

      expect(sentMessagesOfType(tempRelay, 'EVENT'), hasLength(2));
    });

    test(
      'parks instead of sending once the relay is known to need auth',
      () async {
        const firstEventId =
            'aaaa333333333333333333333333333333333333333333333333333333333333';
        const parkedEventId =
            'aaaa444444444444444444444444444444444444444444444444444444444444';

        // First publish creates the temp relay and provokes the challenge.
        await nostr.relayPool.send(
          eventFrame(firstEventId),
          tempRelays: [tempRelayUrl],
        );
        await tempRelay.deliver(['AUTH', challenge]);
        expect(tempRelay.relayStatus.alwaysAuth, isTrue);
        expect(tempRelay.relayStatus.authed, isFalse);

        final sent = await nostr.relayPool.send(
          eventFrame(parkedEventId),
          tempRelays: [tempRelayUrl],
        );

        expect(
          sent,
          isTrue,
          reason: 'a parked frame is queued for delivery, not dropped',
        );
        expect(
          tempRelay.pendingAuthedMessages,
          contains(equals(eventFrame(parkedEventId))),
        );
        expect(
          sentMessagesOfType(tempRelay, 'EVENT'),
          hasLength(1),
          reason: 'the parked frame must not be written before AUTH completes',
        );

        final authEventId = sentAuthEventId(tempRelay);
        await tempRelay.deliver(['OK', authEventId, true, '']);

        expect(tempRelay.pendingAuthedMessages, isEmpty);
        expect(
          sentMessagesOfType(
            tempRelay,
            'EVENT',
          ).where((e) => (e[1] as Map)['id'] == parkedEventId),
          hasLength(1),
          reason: 'the parked frame is sent exactly once, after AUTH',
        );
      },
    );

    test('does not replay an event the relay already accepted', () async {
      const eventId =
          'aaaa555555555555555555555555555555555555555555555555555555555555';

      await nostr.relayPool.send(
        eventFrame(eventId),
        tempRelays: [tempRelayUrl],
      );
      await tempRelay.deliver(['OK', eventId, true, '']);
      // A challenge for some later frame must not resurrect an accepted event.
      await completeHandshake();

      expect(
        sentMessagesOfType(tempRelay, 'EVENT'),
        hasLength(1),
        reason: 'an accepted event must not be published twice',
      );
    });

    test('does not replay an event rejected for a non-auth reason', () async {
      const eventId =
          'aaaa666666666666666666666666666666666666666666666666666666666666';

      await nostr.relayPool.send(
        eventFrame(eventId),
        tempRelays: [tempRelayUrl],
      );
      await tempRelay.deliver(['OK', eventId, false, 'invalid: bad signature']);
      await completeHandshake();

      expect(
        sentMessagesOfType(tempRelay, 'EVENT'),
        hasLength(1),
        reason: 'NIP-42 cannot fix an invalid event, so it must not be resent',
      );
    });

    test(
      'releases parked and retained frames when the handshake fails',
      () async {
        const retainedEventId =
            'aaaa777777777777777777777777777777777777777777777777777777777777';
        const parkedEventId =
            'aaaa888888888888888888888888888888888888888888888888888888888888';

        await nostr.relayPool.send(
          eventFrame(retainedEventId),
          tempRelays: [tempRelayUrl],
        );
        await tempRelay.deliver([
          'OK',
          retainedEventId,
          false,
          'auth-required: you must auth',
        ]);
        // The challenge is what flips alwaysAuth, so only publishes after it
        // take the parking branch.
        await tempRelay.deliver(['AUTH', challenge]);
        await nostr.relayPool.send(
          eventFrame(parkedEventId),
          tempRelays: [tempRelayUrl],
        );
        expect(tempRelay.pendingAuthedMessages, isNotEmpty);

        await tempRelay.deliver([
          'OK',
          sentAuthEventId(tempRelay),
          false,
          'auth failed: bad signature',
        ]);

        // `_isTempRelayReapable` refuses to close a relay while
        // pendingAuthedMessages is non-empty, so a handshake that fails without
        // clearing the queue would pin this socket open for the life of the pool.
        expect(tempRelay.pendingAuthedMessages, isEmpty);
        expect(tempRelay.drainSentFramesForAuthRetry(), isEmpty);
        expect(
          sentMessagesOfType(tempRelay, 'EVENT'),
          hasLength(1),
          reason: 'a failed handshake must not replay anything',
        );
      },
    );
  });

  group('fire-and-forget pool-relay publish across NIP-42', () {
    late LocalNostrSigner signer;
    late Nostr nostr;
    late _AuthFakeRelay relay;

    setUp(() async {
      signer = LocalNostrSigner(testPrivateKey);
      nostr = Nostr(signer, [], (url) => RelayBase(url, RelayStatus(url)));
      await nostr.refreshPublicKey();
      relay = _AuthFakeRelay('wss://pool-auth.example');
      expect(await nostr.relayPool.add(relay), isTrue);
    });

    List<dynamic> eventFrame(String id) => [
      'EVENT',
      {'id': id, 'kind': EventKind.giftWrap},
    ];

    // A user's NIP-65 list can put a NIP-42 relay in the configured pool, so
    // the main-relay loop needs the same first-round retention the temp loop
    // has. Without it this publish is dropped exactly as in #7701 — and no
    // other test in the suite covers that loop's `_retainForAuthRetry` call.
    test('replays the first-round frame a pool relay refused', () async {
      const eventId =
          'cccc111111111111111111111111111111111111111111111111111111111111';

      final sent = await nostr.relayPool.send(eventFrame(eventId));

      expect(sent, isTrue);
      expect(sentMessagesOfType(relay, 'EVENT'), hasLength(1));

      await relay.deliver([
        'OK',
        eventId,
        false,
        'auth-required: you must auth',
      ]);
      await relay.deliver(['AUTH', challenge]);
      await relay.deliver(['OK', sentAuthEventId(relay), true, '']);

      expect(
        sentMessagesOfType(relay, 'EVENT'),
        hasLength(2),
        reason: 'the retained first-round frame must be replayed after AUTH',
      );
      expect(
        sentMessagesOfType(relay, 'EVENT').last,
        equals(eventFrame(eventId)),
      );
    });

    test('does not replay a pool-relay event the relay accepted', () async {
      const eventId =
          'cccc222222222222222222222222222222222222222222222222222222222222';

      await nostr.relayPool.send(eventFrame(eventId));
      await relay.deliver(['OK', eventId, true, '']);
      await relay.deliver(['AUTH', challenge]);
      await relay.deliver(['OK', sentAuthEventId(relay), true, '']);

      expect(
        sentMessagesOfType(relay, 'EVENT'),
        hasLength(1),
        reason: 'an accepted event must not be replayed by a later AUTH',
      );
    });
  });

  group('Relay.recordSentFrame', () {
    test('only retains client publish frames', () {
      final relay = _AuthFakeRelay('wss://shape.example');
      const eventId =
          'bbbb111111111111111111111111111111111111111111111111111111111111';

      // The three-element shape is the relay-to-client direction; this client
      // never sends it, so it is not a retry candidate.
      relay.recordSentFrame([
        'EVENT',
        'sub-id',
        {'id': eventId},
      ]);
      relay.recordSentFrame(['REQ', 'sub-id', <String, dynamic>{}]);
      expect(relay.drainSentFramesForAuthRetry(), isEmpty);

      relay.recordSentFrame([
        'EVENT',
        {'id': eventId},
      ]);
      expect(relay.drainSentFramesForAuthRetry(), hasLength(1));
    });

    test('is bounded, evicting the oldest frame first', () {
      final relay = _AuthFakeRelay('wss://bounded.example');
      // One past the cap, so the very first frame must have been evicted.
      for (var i = 0; i <= 32; i++) {
        relay.recordSentFrame([
          'EVENT',
          {'id': 'event-$i'},
        ]);
      }

      final retained = relay.drainSentFramesForAuthRetry();
      expect(retained, hasLength(32));
      expect(
        retained.map((f) => (f[1] as Map)['id']),
        isNot(contains('event-0')),
      );
      expect(retained.map((f) => (f[1] as Map)['id']), contains('event-32'));
    });
  });
}
