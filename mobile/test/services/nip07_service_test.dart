// ABOUTME: Tests for Nip07Service, the Dart-facing wrapper around a NIP-07
// ABOUTME: browser extension. Covers the optional getRelays handshake.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/nip07_service.dart';
import 'package:openvine/services/nip07_signer_adapter.dart';
import 'package:openvine/services/nip07_types.dart';

const _testPubkey =
    'a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90';

class _FakeExtension extends NostrExtension {
  _FakeExtension({
    this.relays,
    this.relaysFail = false,
    this.relaysCompleter,
    this.relaysQueue,
  });

  /// Relay map to return, or null to model an extension without `getRelays`.
  Map<String, dynamic>? relays;

  /// When true, `getRelays` rejects instead of resolving.
  bool relaysFail;

  String? publicKey;

  Completer<Map<String, dynamic>>? relaysCompleter;

  /// Hands out one future per `getRelays` call, to model concurrent reads
  /// that resolve differently.
  List<Future<Map<String, dynamic>>>? relaysQueue;

  @override
  Future<String> getPublicKey() async => publicKey ?? _testPubkey;

  @override
  Future<Map<String, dynamic>>? getRelays() {
    if (relaysFail) {
      return Future.error(const Nip07Exception('boom', code: 'UNKNOWN_ERROR'));
    }
    final queue = relaysQueue;
    if (queue != null && queue.isNotEmpty) return queue.removeAt(0);
    final completer = relaysCompleter;
    if (completer != null) return completer.future;
    final value = relays;
    if (value == null) return null;
    return Future.value(value);
  }
}

void main() {
  group(Nip07Service, () {
    group('connect', () {
      test('does not read relays eagerly', () async {
        final service = Nip07Service.withExtension(
          _FakeExtension(
            relays: {
              'wss://relay.example.com': {'read': true, 'write': true},
            },
          ),
        );

        final result = await service.connect();

        expect(result.success, isTrue);
        expect(service.userRelays, isNull);
      });
    });

    group('loadUserRelays', () {
      test('reads the relay list the extension advertises', () async {
        final extension = _FakeExtension(
          relays: {
            'wss://relay.example.com': {'read': true, 'write': true},
            'wss://read.example.com': {'read': true, 'write': false},
          },
        );
        final service = Nip07Service.withExtension(extension);
        await service.connect();

        final relays = await service.loadUserRelays();

        expect(relays, hasLength(2));
        expect(
          service.userRelays!['wss://read.example.com'],
          equals({'read': true, 'write': false}),
        );
      });

      test(
        'succeeds without relays when the extension omits getRelays',
        () async {
          final service = Nip07Service.withExtension(_FakeExtension());
          await service.connect();

          final relays = await service.loadUserRelays();

          expect(relays, isNull);
          expect(service.userRelays, isNull);
        },
      );

      test('succeeds without relays when getRelays fails', () async {
        final service = Nip07Service.withExtension(
          _FakeExtension(relaysFail: true),
        );
        await service.connect();

        final relays = await service.loadUserRelays();

        expect(relays, isNull);
        expect(service.publicKey, equals(_testPubkey));
        expect(service.userRelays, isNull);
      });

      test(
        'drops relays from a previous account when public key changes',
        () async {
          final extension = _FakeExtension(
            relays: {
              'wss://relay.example.com': {'read': true, 'write': true},
            },
          );
          final service = Nip07Service.withExtension(extension);
          await service.connect();
          await service.loadUserRelays();
          expect(service.userRelays, isNotNull);

          extension.publicKey = 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';
          await service.connect();

          expect(service.userRelays, isNull);
        },
      );

      test('keeps a concurrent read that succeeded when another '
          'read fails', () async {
        final failing = Completer<Map<String, dynamic>>();
        final succeeding = Completer<Map<String, dynamic>>();
        final service = Nip07Service.withExtension(
          _FakeExtension(relaysQueue: [failing.future, succeeding.future]),
        );
        await service.connect();

        final failed = service.loadUserRelays();
        final succeeded = service.loadUserRelays();

        succeeding.complete({
          'wss://relay.example.com': {'read': true, 'write': true},
        });
        expect(await succeeded, isNotNull);

        failing.completeError(
          const Nip07Exception('boom', code: 'UNKNOWN_ERROR'),
        );

        expect(await failed, isNull);
        expect(service.userRelays, hasLength(1));
      });

      test('does not repopulate relays after disconnect', () async {
        final extension = _FakeExtension(
          relaysCompleter: Completer<Map<String, dynamic>>(),
        );
        final service = Nip07Service.withExtension(extension);
        await service.connect();

        final pending = service.loadUserRelays();
        service.disconnect();
        extension.relaysCompleter!.complete({
          'wss://relay.example.com': {'read': true, 'write': true},
        });

        expect(await pending, isNull);
        expect(service.userRelays, isNull);
      });
    });

    group(Nip07SignerAdapter, () {
      test('does not expose relay cache after disconnect', () async {
        final extension = _FakeExtension(
          relays: {
            'wss://relay.example.com': {'read': true, 'write': true},
          },
        );
        final service = Nip07Service.withExtension(extension);
        final adapter = Nip07SignerAdapter(service);
        await service.connect();
        expect(await adapter.getRelays(), isNotNull);

        service.disconnect();

        expect(await adapter.getRelays(), isNull);
      });
    });
  });
}
