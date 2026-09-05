// ABOUTME: Unit tests for NostrConnectSession class
// ABOUTME: Tests state machine transitions and URL generation

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:nostr_sdk/nip46/nostr_remote_response.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:test/test.dart';

import '../support/test_relay_server.dart';

void main() {
  group('NostrRemoteSignerInfo nostrconnect:// support', () {
    test('isNostrConnectUrl returns true for nostrconnect:// URLs', () {
      expect(
        NostrRemoteSignerInfo.isNostrConnectUrl('nostrconnect://abc123'),
        isTrue,
      );
      expect(
        NostrRemoteSignerInfo.isNostrConnectUrl(
          'nostrconnect://abc?relay=wss://relay.example.com',
        ),
        isTrue,
      );
    });

    test('isNostrConnectUrl returns false for bunker:// URLs', () {
      expect(
        NostrRemoteSignerInfo.isNostrConnectUrl('bunker://abc123'),
        isFalse,
      );
    });

    test('isNostrConnectUrl returns false for null', () {
      expect(NostrRemoteSignerInfo.isNostrConnectUrl(null), isFalse);
    });

    test('isNostrConnectUrl returns false for empty string', () {
      expect(NostrRemoteSignerInfo.isNostrConnectUrl(''), isFalse);
    });

    test(
      'generateNostrConnectUrl creates valid info with ephemeral keypair',
      () {
        final info = NostrRemoteSignerInfo.generateNostrConnectUrl(
          relays: ['wss://relay.example.com'],
          appName: 'TestApp',
          appUrl: 'https://test.com',
        );

        // Should have client pubkey (64 hex chars)
        expect(info.clientPubkey, isNotNull);
        expect(info.clientPubkey!.length, equals(64));
        expect(
          RegExp(r'^[0-9a-f]+$').hasMatch(info.clientPubkey!),
          isTrue,
          reason: 'clientPubkey should be hex',
        );

        // Should have nsec
        expect(info.nsec, isNotNull);
        expect(info.nsec!.startsWith('nsec1'), isTrue);

        // Should have secret (16 hex chars = 8 bytes)
        expect(info.optionalSecret, isNotNull);
        expect(info.optionalSecret!.length, equals(16));

        // Should be marked as client-initiated
        expect(info.isClientInitiated, isTrue);

        // Should have relays
        expect(info.relays, equals(['wss://relay.example.com']));

        // Should have app info
        expect(info.appName, equals('TestApp'));
        expect(info.appUrl, equals('https://test.com'));

        // remoteSignerPubkey should be empty (unknown until bunker responds)
        expect(info.remoteSignerPubkey, isEmpty);
      },
    );

    test('generateNostrConnectUrl creates unique keypairs each time', () {
      final info1 = NostrRemoteSignerInfo.generateNostrConnectUrl(
        relays: ['wss://relay.example.com'],
      );
      final info2 = NostrRemoteSignerInfo.generateNostrConnectUrl(
        relays: ['wss://relay.example.com'],
      );

      expect(info1.clientPubkey, isNot(equals(info2.clientPubkey)));
      expect(info1.nsec, isNot(equals(info2.nsec)));
      expect(info1.optionalSecret, isNot(equals(info2.optionalSecret)));
    });

    test('toNostrConnectUrl generates valid URL', () {
      final info = NostrRemoteSignerInfo.generateNostrConnectUrl(
        relays: ['wss://relay.example.com', 'wss://relay2.example.com'],
        appName: 'TestApp',
        appUrl: 'https://test.com',
      );

      final url = info.toNostrConnectUrl();

      // Should start with nostrconnect://
      expect(url.startsWith('nostrconnect://'), isTrue);

      // Should contain client pubkey as host
      expect(url.contains(info.clientPubkey!), isTrue);

      // Should contain relays
      expect(url.contains('relay='), isTrue);
      expect(
        url.contains(Uri.encodeComponent('wss://relay.example.com')),
        isTrue,
      );
      expect(
        url.contains(Uri.encodeComponent('wss://relay2.example.com')),
        isTrue,
      );

      // Should contain secret
      expect(url.contains('secret='), isTrue);
      expect(url.contains(info.optionalSecret!), isTrue);

      // Should contain app name and url as separate params (per NIP-46)
      expect(url.contains('name='), isTrue);
      expect(url.contains('TestApp'), isTrue);
      expect(url.contains('url='), isTrue);

      // Should contain perms
      expect(url.contains('perms='), isTrue);
      expect(url.contains('sign_event'), isTrue);
    });

    test('toNostrConnectUrl throws if clientPubkey is missing', () {
      final info = NostrRemoteSignerInfo(
        remoteSignerPubkey: 'abc',
        relays: ['wss://relay.example.com'],
        optionalSecret: 'secret123',
        // clientPubkey is null
      );

      expect(() => info.toNostrConnectUrl(), throwsA(isA<StateError>()));
    });

    test('toNostrConnectUrl throws if secret is missing', () {
      final info = NostrRemoteSignerInfo(
        remoteSignerPubkey: '',
        relays: ['wss://relay.example.com'],
        clientPubkey: 'abc123',
        // optionalSecret is null
      );

      expect(() => info.toNostrConnectUrl(), throwsA(isA<StateError>()));
    });

    test('toNostrConnectUrl with custom permissions', () {
      final info = NostrRemoteSignerInfo.generateNostrConnectUrl(
        relays: ['wss://relay.example.com'],
      );

      final url = info.toNostrConnectUrl(permissions: 'sign_event:0');

      expect(url.contains('perms=sign_event%3A0'), isTrue);
    });

    test('toNostrConnectUrl includes callback when provided', () {
      final info = NostrRemoteSignerInfo.generateNostrConnectUrl(
        relays: ['wss://relay.example.com'],
      );

      final url = info.toNostrConnectUrl(callback: 'divine');

      expect(url.contains('callback=divine'), isTrue);
    });

    test('toNostrConnectUrl URL-encodes callback value', () {
      final info = NostrRemoteSignerInfo.generateNostrConnectUrl(
        relays: ['wss://relay.example.com'],
      );

      final url = info.toNostrConnectUrl(
        callback: 'https://example.com/callback',
      );

      expect(
        url.contains(
          'callback=${Uri.encodeComponent("https://example.com/callback")}',
        ),
        isTrue,
      );
      // Should not contain the raw unencoded URL
      expect(url.contains('callback=https://example.com/callback'), isFalse);
    });

    test('toNostrConnectUrl omits callback when null', () {
      final info = NostrRemoteSignerInfo.generateNostrConnectUrl(
        relays: ['wss://relay.example.com'],
      );

      final url = info.toNostrConnectUrl();

      expect(url.contains('callback'), isFalse);
    });

    test('toNostrConnectUrl omits callback when empty', () {
      final info = NostrRemoteSignerInfo.generateNostrConnectUrl(
        relays: ['wss://relay.example.com'],
      );

      final url = info.toNostrConnectUrl(callback: '');

      expect(url.contains('callback'), isFalse);
    });
  });

  group('NostrConnectSession', () {
    test('initial state is idle', () {
      final session = NostrConnectSession(relays: ['wss://relay.example.com']);

      expect(session.state, equals(NostrConnectState.idle));
      expect(session.connectUrl, isNull);
      expect(session.info, isNull);

      session.dispose();
    });

    test(
      'uses a 12-character subscription id from the name alphabet',
      () async {
        final relay = await TestRelayServer.start();
        addTearDown(relay.close);
        final session = NostrConnectSession(relays: [relay.url]);
        addTearDown(session.dispose);

        await session.start();
        await _waitUntil(() => relay.receivedMessages.any(_isReqMessage));
        final request = relay.receivedMessages.firstWhere(_isReqMessage);
        final subscriptionId = request[1] as String;

        expect(subscriptionId, hasLength(12));
        expect(RegExp(r'^[0-9a-z]{12}$').hasMatch(subscriptionId), isTrue);
      },
    );

    test('cancel from idle state transitions to cancelled', () {
      final session = NostrConnectSession(relays: ['wss://relay.example.com']);

      session.cancel();

      expect(session.state, equals(NostrConnectState.cancelled));

      session.dispose();
    });

    test('state stream emits state changes', () async {
      final session = NostrConnectSession(relays: ['wss://relay.example.com']);

      final states = <NostrConnectState>[];
      final subscription = session.stateStream.listen(states.add);

      session.cancel();

      // Give time for stream to emit
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(states, contains(NostrConnectState.cancelled));

      await subscription.cancel();
      session.dispose();
    });

    test('waitForConnection throws if not in listening state', () {
      final session = NostrConnectSession(relays: ['wss://relay.example.com']);

      expect(() => session.waitForConnection(), throwsA(isA<StateError>()));

      session.dispose();
    });

    test('start throws if already started', () {
      // Test that start() can only be called from idle state
      // We use cancel() to transition out of idle state without any network calls
      final session = NostrConnectSession(relays: ['wss://relay.example.com']);

      // Verify initial state
      expect(session.state, equals(NostrConnectState.idle));

      // Cancel transitions from idle to cancelled
      session.cancel();
      expect(session.state, equals(NostrConnectState.cancelled));

      // Now start() should throw because we're not in idle state
      expect(
        () => session.start(),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('already started'),
          ),
        ),
      );

      session.dispose();
    });

    test('addRelay dedupes configured and connected relays', () async {
      final primaryRelay = await TestRelayServer.start();
      final callbackRelay = await TestRelayServer.start();
      addTearDown(primaryRelay.close);
      addTearDown(callbackRelay.close);

      final session = NostrConnectSession(relays: [primaryRelay.url]);
      addTearDown(session.dispose);

      await session.start();
      expect(primaryRelay.connectionCount, equals(1));

      await session.addRelay(primaryRelay.url);
      expect(
        primaryRelay.connectionCount,
        equals(1),
        reason: 'configured relays should not be added a second time',
      );

      await session.addRelay(callbackRelay.url);
      expect(callbackRelay.connectionCount, equals(1));

      await session.addRelay(callbackRelay.url);
      expect(
        callbackRelay.connectionCount,
        equals(1),
        reason: 'already-connected callback relays should be deduped',
      );
    });

    test('addRelay stops admitting signer relays at the cap', () async {
      final primaryRelay = await TestRelayServer.start();
      addTearDown(primaryRelay.close);

      final session = NostrConnectSession(relays: [primaryRelay.url]);
      addTearDown(session.dispose);

      await session.start();

      final callbackRelays = <TestRelayServer>[];
      for (var i = 0; i <= RelayListCaps.nip46Callback; i++) {
        final relay = await TestRelayServer.start();
        addTearDown(relay.close);
        callbackRelays.add(relay);
        await session.addRelay(relay.url);
      }

      for (final relay in callbackRelays.take(RelayListCaps.nip46Callback)) {
        expect(relay.connectionCount, equals(1));
      }
      expect(
        callbackRelays.last.connectionCount,
        equals(0),
        reason: 'a signer relay past the cap must never be dialed',
      );
    });

    test('addRelay does not spend the cap on a relay that failed', () async {
      final primaryRelay = await TestRelayServer.start();
      final failedPort = await _unusedLoopbackPort();
      addTearDown(primaryRelay.close);

      final session = NostrConnectSession(relays: [primaryRelay.url]);
      addTearDown(session.dispose);

      await session.start();

      for (var i = 0; i < RelayListCaps.nip46Callback; i++) {
        await session.addRelay('ws://127.0.0.1:$failedPort');
      }

      final callbackRelay = await TestRelayServer.start();
      addTearDown(callbackRelay.close);

      await session.addRelay(callbackRelay.url);
      expect(
        callbackRelay.connectionCount,
        equals(1),
        reason: 'only retained relays count against the cap',
      );
    });

    test('addRelay holds the cap when callbacks arrive together', () async {
      final primaryRelay = await TestRelayServer.start();
      addTearDown(primaryRelay.close);

      final session = NostrConnectSession(relays: [primaryRelay.url]);
      addTearDown(session.dispose);

      await session.start();

      final callbackRelays = <TestRelayServer>[];
      for (var i = 0; i < RelayListCaps.nip46Callback + 3; i++) {
        final relay = await TestRelayServer.start();
        addTearDown(relay.close);
        callbackRelays.add(relay);
      }

      // The coordinator dispatches every callback with `unawaited`, so these
      // all land between the cap check and the first dial completing.
      await Future.wait([
        for (final relay in callbackRelays) session.addRelay(relay.url),
      ]);

      expect(
        callbackRelays.fold<int>(0, (n, relay) => n + relay.connectionCount),
        equals(RelayListCaps.nip46Callback),
        reason: 'concurrent callbacks must not each spend the same free slot',
      );
    });

    test('addRelay dials a repeated callback relay once', () async {
      final primaryRelay = await TestRelayServer.start();
      addTearDown(primaryRelay.close);

      final session = NostrConnectSession(relays: [primaryRelay.url]);
      addTearDown(session.dispose);

      await session.start();

      final callbackRelay = await TestRelayServer.start();
      addTearDown(callbackRelay.close);

      await Future.wait([
        for (var i = 0; i < RelayListCaps.nip46Callback; i++)
          session.addRelay(callbackRelay.url),
      ]);

      expect(
        callbackRelay.connectionCount,
        equals(1),
        reason: 'an in-flight dial must absorb a repeat of the same URL',
      );
    });

    test('addRelay treats a trailing slash as the same relay', () async {
      final primaryRelay = await TestRelayServer.start();
      addTearDown(primaryRelay.close);

      final session = NostrConnectSession(relays: [primaryRelay.url]);
      addTearDown(session.dispose);

      await session.start();

      final callbackRelay = await TestRelayServer.start();
      addTearDown(callbackRelay.close);

      await session.addRelay(callbackRelay.url);
      await session.addRelay('${callbackRelay.url}/');

      expect(
        callbackRelay.connectionCount,
        equals(1),
        reason: 'a respelling must not cost a second slot of the cap',
      );
    });

    test('addRelay is a no-op unless the session is listening', () async {
      final callbackRelay = await TestRelayServer.start();
      addTearDown(callbackRelay.close);

      final idleSession = NostrConnectSession(relays: ['ws://127.0.0.1:9']);
      addTearDown(idleSession.dispose);

      await idleSession.addRelay(callbackRelay.url);
      expect(callbackRelay.connectionCount, equals(0));

      idleSession.cancel();
      await idleSession.addRelay(callbackRelay.url);
      expect(callbackRelay.connectionCount, equals(0));
    });

    test('addRelay excludes relays whose connect returns false', () async {
      final primaryRelay = await TestRelayServer.start();
      final failedPort = await _unusedLoopbackPort();
      final callbackUrl = 'ws://127.0.0.1:$failedPort';
      addTearDown(primaryRelay.close);

      final session = NostrConnectSession(relays: [primaryRelay.url]);
      addTearDown(session.dispose);

      await session.start();
      await session.addRelay(callbackUrl);

      final callbackRelay = await TestRelayServer.start(port: failedPort);
      addTearDown(callbackRelay.close);

      await session.addRelay(callbackUrl);
      expect(
        callbackRelay.connectionCount,
        equals(1),
        reason: 'failed relay attempts must not be retained as connected',
      );
    });

    test('addRelay excludes relays whose connect times out', () async {
      final primaryRelay = await TestRelayServer.start();
      final blackhole = await _BlackholeServer.start();
      final callbackUrl = blackhole.url;
      addTearDown(primaryRelay.close);
      addTearDown(blackhole.close);

      final session = NostrConnectSession(relays: [primaryRelay.url]);
      addTearDown(session.dispose);

      await session.start();
      await session.addRelay(callbackUrl);

      final failedPort = blackhole.port;
      await blackhole.close();
      final callbackRelay = await TestRelayServer.start(port: failedPort);
      addTearDown(callbackRelay.close);

      await session.addRelay(callbackUrl);
      expect(
        callbackRelay.connectionCount,
        equals(1),
        reason: 'timed-out relay attempts must not be retained as connected',
      );
    }, timeout: const Timeout(Duration(seconds: 20)));

    test(
      'addRelay disconnects a relay that connects after the session timeout',
      () async {
        final primaryRelay = await TestRelayServer.start();
        final delayedRelay = await _DelayedUpgradeRelayServer.start(
          delay: const Duration(seconds: 9),
        );
        addTearDown(primaryRelay.close);
        addTearDown(delayedRelay.close);

        final session = NostrConnectSession(relays: [primaryRelay.url]);
        addTearDown(session.dispose);

        await session.start();
        await session.addRelay(delayedRelay.url);

        await Future<void>.delayed(const Duration(seconds: 2));

        expect(
          delayedRelay.receivedMessages.where(_isReqMessage),
          isEmpty,
          reason: 'a relay that missed the session timeout must not subscribe',
        );
        expect(
          delayedRelay.activeSocketCount,
          equals(0),
          reason: 'timed-out relays must not stay connected invisibly',
        );
      },
      timeout: const Timeout(Duration(seconds: 20)),
    );
  });

  group('relay lifecycle after cancel (#7962)', () {
    test('a reconnect in flight when the session is cancelled opens no '
        'socket', () async {
      final server = await TestRelayServer.start();
      addTearDown(server.close);

      final logs = <String>[];
      final session = NostrConnectSession(
        relays: [server.url],
        logger: logs.add,
      );
      addTearDown(session.dispose);

      await session.start();
      expect(server.connectionCount, equals(1));

      // Drop the relay the way a flaky network would, then let the session
      // notice before asking it to recover.
      await server.dropConnections();
      await _waitForSockets(server, open: 0);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      unawaited(session.ensureConnected());
      session.cancel();

      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(
        logs.where((line) => line.contains('Reconnecting to')),
        isNotEmpty,
        reason:
            'the session never attempted a reconnect, so this test would '
            'pass without exercising anything',
      );
      expect(
        server.connectionCount,
        equals(1),
        reason:
            'a reconnect resuming after cancel() opens a socket and arms '
            'a heartbeat that nothing is left holding',
      );
      expect(server.openConnectionCount, isZero);
    });

    test('a relay that finishes dialing after cancel is shut down', () async {
      final server = await TestRelayServer.start();
      addTearDown(server.close);

      final session = NostrConnectSession(relays: [server.url]);
      addTearDown(session.dispose);

      // start() suspends inside the dial, so the cancel lands while the relay
      // is still connecting and the socket opens after the cleanup has run.
      final starting = session.start();
      session.cancel();
      await starting;

      await _waitForSockets(server, open: 0);

      expect(
        server.openConnectionCount,
        isZero,
        reason:
            'a relay adopted after _cleanup() is a live socket on a list '
            'nothing will ever walk again',
      );
      expect(session.state, equals(NostrConnectState.cancelled));
    });
  });

  group('NostrConnectState enum', () {
    test('all states are defined', () {
      expect(NostrConnectState.values, hasLength(7));
      expect(NostrConnectState.values, contains(NostrConnectState.idle));
      expect(NostrConnectState.values, contains(NostrConnectState.generating));
      expect(NostrConnectState.values, contains(NostrConnectState.listening));
      expect(NostrConnectState.values, contains(NostrConnectState.connected));
      expect(NostrConnectState.values, contains(NostrConnectState.timeout));
      expect(NostrConnectState.values, contains(NostrConnectState.cancelled));
      expect(NostrConnectState.values, contains(NostrConnectState.error));
    });
  });

  group('NostrConnectResult', () {
    test('stores all required fields', () {
      final info = NostrRemoteSignerInfo(
        remoteSignerPubkey: 'bunker123',
        relays: ['wss://relay.example.com'],
        isClientInitiated: true,
      );

      final result = NostrConnectResult(
        remoteSignerPubkey: 'bunker123',
        userPubkey: 'user456',
        info: info,
      );

      expect(result.remoteSignerPubkey, equals('bunker123'));
      expect(result.userPubkey, equals('user456'));
      expect(result.info, equals(info));
    });

    test('userPubkey can be null', () {
      final info = NostrRemoteSignerInfo(
        remoteSignerPubkey: 'bunker123',
        relays: ['wss://relay.example.com'],
      );

      final result = NostrConnectResult(
        remoteSignerPubkey: 'bunker123',
        userPubkey: null,
        info: info,
      );

      expect(result.userPubkey, isNull);
    });
  });

  group('validateConnectResponse', () {
    NostrRemoteResponse buildResponse(String result, {String? error}) {
      return NostrRemoteResponse('req-id', result, error: error);
    }

    test('returns match when response.result equals the secret exactly', () {
      final validation = validateConnectResponse(
        response: buildResponse('s3cret'),
        expectedSecret: 's3cret',
      );
      expect(validation, equals(NostrConnectResponseValidation.match));
    });

    test(
      'returns ignore when response.result is "ack" (bunker:// flow token)',
      () {
        final validation = validateConnectResponse(
          response: buildResponse('ack'),
          expectedSecret: 's3cret',
        );
        expect(validation, equals(NostrConnectResponseValidation.ignore));
      },
    );

    test('returns ignore when response.result is "connect"', () {
      final validation = validateConnectResponse(
        response: buildResponse('connect'),
        expectedSecret: 's3cret',
      );
      expect(validation, equals(NostrConnectResponseValidation.ignore));
    });

    test('returns ignore on any other non-matching result', () {
      final validation = validateConnectResponse(
        response: buildResponse('attacker-guess'),
        expectedSecret: 's3cret',
      );
      expect(validation, equals(NostrConnectResponseValidation.ignore));
    });

    test('returns ignore on an empty result string', () {
      final validation = validateConnectResponse(
        response: buildResponse(''),
        expectedSecret: 's3cret',
      );
      expect(validation, equals(NostrConnectResponseValidation.ignore));
    });

    test('returns ignore when response.error is non-empty — signer errors are '
        'non-terminal because the sender is unauthenticated pre-secret', () {
      final validation = validateConnectResponse(
        response: buildResponse('', error: 'user denied'),
        expectedSecret: 's3cret',
      );
      expect(validation, equals(NostrConnectResponseValidation.ignore));
    });

    test('returns ignore even when result happens to match — '
        'a response carrying an error must never bind the session', () {
      final validation = validateConnectResponse(
        response: buildResponse('s3cret', error: 'user denied'),
        expectedSecret: 's3cret',
      );
      expect(validation, equals(NostrConnectResponseValidation.ignore));
    });

    test('returns authChallenge for auth_url challenge responses', () {
      final validation = validateConnectResponse(
        response: buildResponse(
          'auth_url',
          error: 'https://example.com/approve?token=untrusted',
        ),
        expectedSecret: 's3cret',
      );
      expect(validation, equals(NostrConnectResponseValidation.authChallenge));
    });

    test('NostrRemoteResponse.isAuthChallenge requires the auth_url marker '
        'and a non-empty URL', () {
      expect(
        NostrRemoteResponse(
          'id',
          'auth_url',
          error: 'https://example.com/x',
        ).isAuthChallenge,
        isTrue,
      );
      expect(NostrRemoteResponse('id', 'auth_url').isAuthChallenge, isFalse);
      expect(
        NostrRemoteResponse('id', 'auth_url', error: '').isAuthChallenge,
        isFalse,
      );
      expect(
        NostrRemoteResponse('id', 'ack', error: 'https://x').isAuthChallenge,
        isFalse,
      );
    });

    test('returns ignore for an auth_url result with no challenge URL in '
        'error — malformed challenges are dropped, not surfaced', () {
      expect(
        validateConnectResponse(
          response: buildResponse('auth_url'),
          expectedSecret: 's3cret',
        ),
        equals(NostrConnectResponseValidation.ignore),
      );
      expect(
        validateConnectResponse(
          response: buildResponse('auth_url', error: ''),
          expectedSecret: 's3cret',
        ),
        equals(NostrConnectResponseValidation.ignore),
      );
    });

    test('returns invalidSession when expectedSecret is null', () {
      final validation = validateConnectResponse(
        response: buildResponse('anything'),
        expectedSecret: null,
      );
      expect(validation, equals(NostrConnectResponseValidation.invalidSession));
    });

    test('returns invalidSession when expectedSecret is empty', () {
      final validation = validateConnectResponse(
        response: buildResponse('anything'),
        expectedSecret: '',
      );
      expect(validation, equals(NostrConnectResponseValidation.invalidSession));
    });

    test(
      'returns ignore on equal-length secret with one differing character '
      '(constant-time compare path runs to end without short-circuiting)',
      () {
        final validation = validateConnectResponse(
          response: buildResponse('s3cretA'),
          expectedSecret: 's3cretB',
        );
        expect(validation, equals(NostrConnectResponseValidation.ignore));
      },
    );
  });

  group('terminal failure reasons and log redaction', () {
    test(
      'never logs the matched secret while handling a successful response',
      () async {
        final relay = await TestRelayServer.start();
        addTearDown(relay.close);

        final logs = <String>[];
        final session = NostrConnectSession(
          relays: [relay.url],
          logger: logs.add,
        );
        addTearDown(session.dispose);

        await session.start();
        final info = session.info!;
        final secret = info.optionalSecret!;
        // The connect URL legitimately carries the secret and is logged at
        // start(); drop those lines so the assertion only covers RESPONSE
        // handling — the surface the #3760 redaction contract guards.
        logs.clear();

        final wait = session.waitForConnection(
          timeout: const Duration(seconds: 5),
        );
        relay.push([
          'EVENT',
          'sub',
          await _encryptedResponseEvent(
            clientPubkey: info.clientPubkey!,
            result: secret,
          ),
        ]);
        final result = await wait;

        expect(result, isNotNull, reason: 'a matching secret should connect');
        expect(session.state, equals(NostrConnectState.connected));
        // Guard the guard: the response-handling path must actually route
        // through the injected logger, or the redaction assertion below
        // passes vacuously. This `Decrypted response` line is precisely
        // where `response.result` (== the secret on a match) would most
        // plausibly be interpolated by a future edit, so it must be one of
        // the lines `logs` captures.
        expect(
          logs.any((line) => line.contains('Decrypted response')),
          isTrue,
          reason:
              '_handleResponse must log via the injected logger so the '
              'secret-redaction assertion covers the response path',
        );
        expect(
          logs.where((line) => line.contains(secret)),
          isEmpty,
          reason: 'the matched secret must never reach the logs',
        );
      },
    );

    test(
      'logs neither the response result nor the expected secret on a mismatch',
      () async {
        final relay = await TestRelayServer.start();
        addTearDown(relay.close);

        final logs = <String>[];
        final session = NostrConnectSession(
          relays: [relay.url],
          logger: logs.add,
        );
        addTearDown(session.dispose);

        await session.start();
        final info = session.info!;
        final secret = info.optionalSecret!;
        const junkResult = 'junk-result-value-should-never-be-logged';
        logs.clear();

        unawaited(
          session.waitForConnection(timeout: const Duration(seconds: 5)),
        );
        relay.push([
          'EVENT',
          'sub',
          await _encryptedResponseEvent(
            clientPubkey: info.clientPubkey!,
            result: junkResult,
          ),
        ]);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Guard the guard: prove the mismatch path actually ran through the
        // injected logger so the redaction assertion below is not vacuous.
        expect(
          logs.any((line) => line.contains('Decrypted response')),
          isTrue,
          reason:
              '_handleResponse must log via the injected logger so the '
              'redaction assertion covers the mismatch path',
        );
        expect(
          logs.where(
            (line) => line.contains(junkResult) || line.contains(secret),
          ),
          isEmpty,
          reason: 'neither the result nor the expected secret may be logged',
        );
      },
    );

    test('keeps listening through an injected error response and still binds '
        'on the real secret (pairing-DoS regression, #5683)', () async {
      final relay = await TestRelayServer.start();
      addTearDown(relay.close);

      final session = NostrConnectSession(relays: [relay.url]);
      addTearDown(session.dispose);

      await session.start();
      final info = session.info!;
      final secret = info.optionalSecret!;

      final wait = session.waitForConnection(
        timeout: const Duration(seconds: 5),
      );
      relay.push([
        'EVENT',
        'sub',
        await _encryptedResponseEvent(
          clientPubkey: info.clientPubkey!,
          result: '',
          error: 'user rejected',
        ),
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(
        session.state,
        equals(NostrConnectState.listening),
        reason: 'an unauthenticated error must not terminate pairing',
      );
      expect(session.failureReason, isNull);

      relay.push([
        'EVENT',
        'sub',
        await _encryptedResponseEvent(
          clientPubkey: info.clientPubkey!,
          result: secret,
          requestId: 'real-signer-request-id',
        ),
      ]);
      final result = await wait;

      expect(
        result,
        isNotNull,
        reason: 'the legitimate secret must still bind after the junk error',
      );
      expect(session.state, equals(NostrConnectState.connected));
    });

    test('reports startFailed when no relay can be reached', () async {
      final deadPort = await _unusedLoopbackPort();
      final session = NostrConnectSession(relays: ['ws://127.0.0.1:$deadPort']);
      addTearDown(session.dispose);

      await expectLater(session.start(), throwsA(isA<StateError>()));

      expect(session.state, equals(NostrConnectState.error));
      expect(
        session.failureReason,
        equals(NostrConnectFailureReason.startFailed),
      );
    });
  });

  group('auth challenge (non-terminal, #5683)', () {
    const challengeUrl = 'https://example.com/approve?token=untrusted';

    test('keeps listening through an auth_url challenge, dedupes relay '
        'replays of the same id, and still binds on the real secret', () async {
      final relay = await TestRelayServer.start();
      addTearDown(relay.close);

      final logs = <String>[];
      final session = NostrConnectSession(
        relays: [relay.url],
        logger: logs.add,
      );
      addTearDown(session.dispose);

      await session.start();
      final info = session.info!;
      final secret = info.optionalSecret!;
      logs.clear();

      final wait = session.waitForConnection(
        timeout: const Duration(seconds: 5),
      );
      final challengeEvent = await _encryptedResponseEvent(
        clientPubkey: info.clientPubkey!,
        result: 'auth_url',
        error: challengeUrl,
        requestId: 'challenge-id',
      );
      relay.push(['EVENT', 'sub', challengeEvent]);
      await _waitUntil(
        () => logs.any((line) => line.contains('Auth challenge')),
      );

      expect(
        session.state,
        equals(NostrConnectState.listening),
        reason: 'an auth challenge must not terminate pairing',
      );
      expect(session.failureReason, isNull);

      // A relay replay of the identical event and a signer re-send of the
      // same challenge id as a fresh event must both be deduped.
      relay.push(['EVENT', 'sub', challengeEvent]);
      relay.push([
        'EVENT',
        'sub',
        await _encryptedResponseEvent(
          clientPubkey: info.clientPubkey!,
          result: 'auth_url',
          error: challengeUrl,
          requestId: 'challenge-id',
        ),
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(
        logs.where((line) => line.contains('Auth challenge')),
        hasLength(1),
        reason: 'a replayed challenge id must be logged once',
      );

      relay.push([
        'EVENT',
        'sub',
        await _encryptedResponseEvent(
          clientPubkey: info.clientPubkey!,
          result: secret,
          requestId: 'challenge-id',
        ),
      ]);
      final result = await wait;

      expect(
        result,
        isNotNull,
        reason: 'the post-challenge secret on the same id must bind',
      );
      expect(session.state, equals(NostrConnectState.connected));
    });

    test(
      'restarts the wait window exactly once across multiple challenges',
      () async {
        final relay = await TestRelayServer.start();
        addTearDown(relay.close);

        final logs = <String>[];
        final session = NostrConnectSession(
          relays: [relay.url],
          logger: logs.add,
        );
        addTearDown(session.dispose);

        await session.start();
        final info = session.info!;
        logs.clear();

        unawaited(
          session.waitForConnection(timeout: const Duration(seconds: 5)),
        );
        relay.push([
          'EVENT',
          'sub',
          await _encryptedResponseEvent(
            clientPubkey: info.clientPubkey!,
            result: 'auth_url',
            error: challengeUrl,
            requestId: 'challenge-1',
          ),
        ]);
        relay.push([
          'EVENT',
          'sub',
          await _encryptedResponseEvent(
            clientPubkey: info.clientPubkey!,
            result: 'auth_url',
            error: challengeUrl,
            requestId: 'challenge-2',
          ),
        ]);
        await _waitUntil(
          () =>
              logs.where((line) => line.contains('Auth challenge')).length == 2,
        );

        expect(
          logs.where((line) => line.contains('Wait window restarted once')),
          hasLength(1),
          reason: 'injected challenges must not extend the wait repeatedly',
        );
      },
    );

    test('extends the deadline once: a challenge mid-wait moves the timeout '
        'to a full window from the challenge, then still times out', () async {
      final relay = await TestRelayServer.start();
      addTearDown(relay.close);

      final logs = <String>[];
      final session = NostrConnectSession(
        relays: [relay.url],
        logger: logs.add,
      );
      addTearDown(session.dispose);

      await session.start();
      final info = session.info!;

      const timeout = Duration(milliseconds: 1500);
      const challengeDelay = Duration(milliseconds: 500);
      final stopwatch = Stopwatch()..start();
      final wait = session.waitForConnection(timeout: timeout);

      await Future<void>.delayed(challengeDelay);
      relay.push([
        'EVENT',
        'sub',
        await _encryptedResponseEvent(
          clientPubkey: info.clientPubkey!,
          result: 'auth_url',
          error: challengeUrl,
        ),
      ]);
      // The restart must land while the original window is still open, or
      // the elapsed-time assertion below would be measuring the wrong thing.
      await _waitUntil(
        () => logs.any((line) => line.contains('Wait window restarted once')),
        timeout: timeout - challengeDelay,
      );

      final result = await wait;
      stopwatch.stop();

      expect(result, isNull);
      expect(session.state, equals(NostrConnectState.timeout));
      // Lower bound only (slow machines can only make it larger): the
      // challenge was pushed at >= 500ms and the restarted timer runs a
      // full 1500ms from there, so completing before ~2000ms means the
      // original, un-cancelled timer fired instead of the restarted one.
      expect(
        stopwatch.elapsedMilliseconds,
        greaterThanOrEqualTo(1990),
        reason: 'the restart must extend the deadline, not just re-log',
      );
    });

    test('ignores a secret match that arrives after the wait timed out — '
        'the session must not flip to connected with nobody waiting', () async {
      final relay = await TestRelayServer.start();
      addTearDown(relay.close);

      final logs = <String>[];
      final session = NostrConnectSession(
        relays: [relay.url],
        logger: logs.add,
      );
      addTearDown(session.dispose);

      await session.start();
      final info = session.info!;
      final secret = info.optionalSecret!;

      final result = await session.waitForConnection(
        timeout: const Duration(milliseconds: 300),
      );
      expect(result, isNull);
      expect(session.state, equals(NostrConnectState.timeout));

      relay.push([
        'EVENT',
        'sub',
        await _encryptedResponseEvent(
          clientPubkey: info.clientPubkey!,
          result: secret,
        ),
      ]);
      await _waitUntil(
        () => logs.any((line) => line.contains('Ignoring late secret match')),
      );

      expect(session.state, equals(NostrConnectState.timeout));
    });

    test('never logs the challenge URL (#3760 redaction contract)', () async {
      final relay = await TestRelayServer.start();
      addTearDown(relay.close);

      final logs = <String>[];
      final session = NostrConnectSession(
        relays: [relay.url],
        logger: logs.add,
      );
      addTearDown(session.dispose);

      await session.start();
      final info = session.info!;
      logs.clear();

      unawaited(session.waitForConnection(timeout: const Duration(seconds: 5)));
      relay.push([
        'EVENT',
        'sub',
        await _encryptedResponseEvent(
          clientPubkey: info.clientPubkey!,
          result: 'auth_url',
          error: challengeUrl,
        ),
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Guard the guard: the challenge path must actually route through
      // the injected logger, or the redaction assertion is vacuous.
      expect(
        logs.any((line) => line.contains('Auth challenge')),
        isTrue,
        reason: 'the challenge path must log via the injected logger',
      );
      expect(
        logs.where(
          (line) =>
              line.contains(challengeUrl) ||
              line.contains('token=untrusted') ||
              line.contains('example.com'),
        ),
        isEmpty,
        reason: 'the attacker-suppliable challenge URL must never be logged',
      );
    });
  });

  group('event id integrity (#6151)', () {
    test('drops a tampered relay copy that reuses the real response id, so the '
        'genuine secret still binds instead of being deduped away', () async {
      final relay = await TestRelayServer.start();
      addTearDown(relay.close);

      final logs = <String>[];
      final session = NostrConnectSession(
        relays: [relay.url],
        logger: logs.add,
      );
      addTearDown(session.dispose);

      await session.start();
      final info = session.info!;
      final secret = info.optionalSecret!;
      logs.clear();

      final wait = session.waitForConnection(
        timeout: const Duration(seconds: 5),
      );

      // The genuine signer's binding response. Its `id` is public relay
      // metadata that any pubkey on the listening relays can observe.
      final genuineEvent = await _encryptedResponseEvent(
        clientPubkey: info.clientPubkey!,
        result: secret,
      );

      // An attacker races a copy that reuses the real id but swaps in
      // junk content that fails NIP-44 decryption. Without the NIP-01
      // id-integrity guard this copy would reserve the real id in the
      // replay-dedup cache, and the genuine response arriving next would
      // be dropped as a "duplicate" — stranding sign-in until timeout.
      final tamperedEvent = Map<String, dynamic>.from(genuineEvent)
        ..['content'] = 'not-a-valid-nip44-ciphertext';
      relay.push(['EVENT', 'sub', tamperedEvent]);
      await _waitUntil(
        () => logs.any((line) => line.contains('failed event verification')),
      );
      expect(
        session.state,
        equals(NostrConnectState.listening),
        reason: 'a tampered copy must neither terminate nor bind pairing',
      );

      // The genuine response, still carrying the real id, must bind: the
      // tampered copy must not have reserved that id in the dedup cache.
      relay.push(['EVENT', 'sub', genuineEvent]);
      final result = await wait;

      expect(
        result,
        isNotNull,
        reason:
            'the genuine secret must still bind after a tampered copy '
            'reused its id',
      );
      expect(session.state, equals(NostrConnectState.connected));
    });
  });

  group('event signature verification', () {
    test('drops an unsigned response before replay deduplication', () async {
      final relay = await TestRelayServer.start();
      addTearDown(relay.close);

      final logs = <String>[];
      final session = NostrConnectSession(
        relays: [relay.url],
        logger: logs.add,
      );
      addTearDown(session.dispose);

      await session.start();
      final info = session.info!;
      final secret = info.optionalSecret!;
      logs.clear();

      final wait = session.waitForConnection(
        timeout: const Duration(seconds: 5),
      );
      final genuineEvent = await _encryptedResponseEvent(
        clientPubkey: info.clientPubkey!,
        result: secret,
      );
      final unsignedEvent = Map<String, dynamic>.from(genuineEvent)
        ..['sig'] = '';

      relay.push(['EVENT', 'sub', unsignedEvent]);
      await _waitUntil(
        () => logs.any((line) => line.contains('failed event verification')),
      );
      expect(session.state, equals(NostrConnectState.listening));

      relay.push(['EVENT', 'sub', genuineEvent]);
      expect(await wait, isNotNull);
      expect(session.state, equals(NostrConnectState.connected));
    });
  });
}

/// Builds a NIP-44-encrypted kind-24133 response event addressed to
/// [clientPubkey], as a `nostrconnect://` signer would send it. The signer
/// keypair is ephemeral and signs the response as a real remote signer would.
Future<Map<String, dynamic>> _encryptedResponseEvent({
  required String clientPubkey,
  required String result,
  String? error,
  String requestId = 'test-request-id',
}) async {
  final signer = LocalNostrSigner(generatePrivateKey());
  final remoteSignerPubkey = (await signer.getPublicKey())!;
  final response = NostrRemoteResponse(requestId, result, error: error);
  final ciphertext = (await response.encrypt(signer, clientPubkey))!;
  final event = Event(remoteSignerPubkey, EventKind.nostrRemoteSigning, [
    ['p', clientPubkey],
  ], ciphertext);
  return (await signer.signEvent(event))!.toJson();
}

/// Polls [condition] until it holds, failing the test after [timeout].
/// Prefer this over fixed sleeps so slow CI machines cannot flake a
/// positive assertion; negative assertions still need a bounded delay.
Future<void> _waitUntil(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('condition not met within $timeout');
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

Future<int> _unusedLoopbackPort() async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  await socket.close();
  return port;
}

bool _isReqMessage(List<dynamic> message) =>
    message.isNotEmpty && message.first == 'REQ';

class _DelayedUpgradeRelayServer {
  _DelayedUpgradeRelayServer._(this._server, this._delay) {
    _requests = _server.listen(_handleRequest);
  }

  final HttpServer _server;
  final Duration _delay;
  final _sockets = <WebSocket>[];
  final receivedMessages = <List<dynamic>>[];
  late final StreamSubscription<HttpRequest> _requests;
  bool _closed = false;

  String get url => 'ws://127.0.0.1:${_server.port}';
  int get activeSocketCount => _sockets.where((socket) {
    return socket.readyState == WebSocket.open ||
        socket.readyState == WebSocket.connecting;
  }).length;

  static Future<_DelayedUpgradeRelayServer> start({
    required Duration delay,
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    return _DelayedUpgradeRelayServer._(server, delay);
  }

  Future<void> _handleRequest(HttpRequest request) async {
    if (!WebSocketTransformer.isUpgradeRequest(request)) {
      request.response.statusCode = HttpStatus.badRequest;
      await request.response.close();
      return;
    }

    await Future<void>.delayed(_delay);
    if (_closed) return;

    final socket = await WebSocketTransformer.upgrade(request);
    _sockets.add(socket);
    socket.listen((message) {
      receivedMessages.add(jsonDecode(message as String) as List<dynamic>);
    });
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    for (final socket in _sockets) {
      await socket.close();
    }
    await _requests.cancel();
    await _server.close(force: true);
  }
}

class _BlackholeServer {
  _BlackholeServer._(this._server) {
    _requests = _server.listen((socket) {
      _sockets.add(socket);
    });
  }

  final ServerSocket _server;
  final _sockets = <Socket>[];
  late final StreamSubscription<Socket> _requests;
  bool _closed = false;

  int get port => _server.port;
  String get url => 'ws://127.0.0.1:$port';

  static Future<_BlackholeServer> start() async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    return _BlackholeServer._(server);
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    for (final socket in _sockets) {
      socket.destroy();
    }
    await _requests.cancel();
    await _server.close();
  }
}

/// Waits until the server holds exactly [open] client sockets.
///
/// A socket the client closes takes a turn or two to register server-side, so
/// asserting straight after a teardown reads the pre-close count.
///
/// Throws rather than returning on timeout: callers use this to establish a
/// precondition, and giving up quietly would let the scenario be set up wrong
/// and the test pass without exercising anything.
Future<void> _waitForSockets(
  TestRelayServer server, {
  required int open,
}) async {
  final deadline = DateTime.now().add(const Duration(seconds: 2));
  while (server.openConnectionCount != open) {
    if (DateTime.now().isAfter(deadline)) {
      throw StateError(
        'server still holds ${server.openConnectionCount} open sockets, '
        'expected $open',
      );
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}
