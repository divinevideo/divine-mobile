// ABOUTME: Activation authority survives only verified writes and a live host.
// ABOUTME: Native failures, cold records and late settlement never grant access.

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/auth/account_activation_coordinator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

const _alice =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _bob = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

class _Backend extends InMemorySharedPreferencesStore {
  _Backend() : super.empty();
  bool refuse = false;
  bool lie = false;
  bool failRead = false;
  String? pausePhase;
  Completer<void>? entered;
  Completer<void>? resume;
  bool pauseRead = false;

  @override
  Future<bool> setValue(String type, String key, Object value) async {
    if (key.endsWith(AccountActivationCoordinator.storageKey)) {
      if (pausePhase != null &&
          value.toString().contains('"phase":"$pausePhase"')) {
        pausePhase = null;
        entered!.complete();
        await resume!.future;
      }
      if (refuse) return false;
      if (lie) return true;
    }
    return super.setValue(type, key, value);
  }

  @override
  Future<Map<String, Object>> getAll() async {
    if (pauseRead) {
      pauseRead = false;
      entered!.complete();
      await resume!.future;
    }
    if (failRead) throw StateError('native read unavailable');
    return super.getAll();
  }
}

void main() {
  late SharedPreferencesStorePlatform original;
  late _Backend backend;
  late SharedPreferences prefs;
  late AccountActivationCoordinator coordinator;
  var live = true;

  setUp(() async {
    original = SharedPreferencesStorePlatform.instance;
    backend = _Backend();
    SharedPreferencesStorePlatform.instance = backend;
    SharedPreferences.resetStatic();
    prefs = await SharedPreferences.getInstance();
    coordinator = AccountActivationCoordinator.forPreferences(prefs);
    live = true;
  });
  tearDown(() {
    SharedPreferences.resetStatic();
    SharedPreferencesStorePlatform.instance = original;
  });

  Future<AccountActivationTicket> begin() =>
      coordinator.begin(ownerPubkey: _alice, isCurrent: () => live);

  group('account activation receipts', () {
    test(
      'a live verified terminal receipt grants only its full owner',
      () async {
        final ticket = await begin();
        expect(coordinator.hasUnresolvedActivation, isTrue);
        await coordinator.markIdentityReady(ticket);
        expect(coordinator.committedOwnerPubkey, isNull);
        final receipt = await coordinator.commit(ticket);
        expect(receipt.isCurrent, isTrue);
        expect(coordinator.committedOwnerPubkey, _alice);
        expect(coordinator.hasUnresolvedActivation, isFalse);
        live = false;
        expect(receipt.isCurrent, isFalse);
        expect(coordinator.hasUnresolvedActivation, isTrue);
        expect(coordinator.committedOwnerPubkey, isNull);
      },
    );

    for (final failure in ['refused', 'lying', 'readback']) {
      test('$failure terminal storage cannot open the gate', () async {
        final ticket = await begin();
        backend.refuse = failure == 'refused';
        backend.lie = failure == 'lying';
        backend.failRead = failure == 'readback';
        await expectLater(coordinator.commit(ticket), throwsStateError);
        expect(coordinator.hasUnresolvedActivation, isTrue);
        expect(coordinator.committedOwnerPubkey, isNull);
      });
    }

    for (final phase in ['identityReady', 'committed']) {
      for (final point in ['write', 'readback']) {
        test('retired host during $phase $point remains unresolved', () async {
          final ticket = await begin();
          backend.entered = Completer<void>();
          backend.resume = Completer<void>();
          backend.pausePhase = point == 'write' ? phase : null;
          backend.pauseRead = point == 'readback';
          final operation = phase == 'identityReady'
              ? coordinator.markIdentityReady(ticket)
              : coordinator.commit(ticket);
          final assertion = expectLater(
            operation,
            throwsA(isA<AccountActivationRetiredException>()),
          );
          await backend.entered!.future;
          live = false;
          backend.resume!.complete();
          await assertion;
          expect(coordinator.hasUnresolvedActivation, isTrue);
          expect(coordinator.committedOwnerPubkey, isNull);
          expect(
            prefs.containsKey(AccountActivationCoordinator.storageKey),
            isTrue,
          );
        });
      }
    }

    test(
      'a cold terminal record cannot replace current-process proof',
      () async {
        final ticket = await begin();
        await coordinator.commit(ticket);
        SharedPreferences.resetStatic();
        final cold = await SharedPreferences.getInstance();
        final gate = AccountActivationCoordinator.forPreferences(cold);
        expect(gate.hasUnresolvedActivation, isTrue);
        expect(gate.committedOwnerPubkey, isNull);
      },
    );

    test('the exact cold terminal owner can be proved afresh', () async {
      final ticket = await begin();
      await coordinator.commit(ticket);
      await prefs.setString('current_user_pubkey_hex', _alice);
      SharedPreferences.resetStatic();
      final cold = await SharedPreferences.getInstance();
      final gate = AccountActivationCoordinator.forPreferences(cold);
      final next = await gate.begin(ownerPubkey: _alice, isCurrent: () => live);
      expect(gate.committedOwnerPubkey, isNull);
      await gate.commit(next);
      expect(gate.committedOwnerPubkey, _alice);
    });

    for (final phase in ['pending', 'identityReady']) {
      test(
        'verified owner retry preserves the cold $phase operation token',
        () async {
          final ticket = await begin();
          if (phase == 'identityReady') {
            await coordinator.markIdentityReady(ticket);
          }
          final retained = jsonDecode(
            prefs.getString(AccountActivationCoordinator.storageKey)!,
          ) as Map;
          SharedPreferences.resetStatic();
          final cold = await SharedPreferences.getInstance();
          final gate = AccountActivationCoordinator.forPreferences(cold);
          final next = await gate.begin(
            ownerPubkey: _alice,
            isCurrent: () => live,
            recoverInterruptedOwner: true,
          );
          final retry = jsonDecode(
            cold.getString(AccountActivationCoordinator.storageKey)!,
          ) as Map;
          expect(retry['token'], retained['token']);
          expect(gate.hasUnresolvedActivation, isTrue);
          await gate.commit(next);
          expect(gate.committedOwnerPubkey, _alice);
        },
      );
    }

    for (final evidence in ['damaged', 'foreignPending', 'wrongNativeOwner']) {
      test('cold $evidence retains exact bytes and stays fenced', () async {
        final ticket = await begin();
        if (evidence == 'damaged') {
          await prefs.setString(
            AccountActivationCoordinator.storageKey,
            '{broken',
          );
        } else if (evidence == 'wrongNativeOwner') {
          await coordinator.commit(ticket);
          await prefs.setString('current_user_pubkey_hex', _bob);
        }
        final raw = prefs.get(AccountActivationCoordinator.storageKey);
        SharedPreferences.resetStatic();
        final cold = await SharedPreferences.getInstance();
        final gate = AccountActivationCoordinator.forPreferences(cold);
        await expectLater(
          gate.begin(
            ownerPubkey: evidence == 'wrongNativeOwner' ? _alice : _bob,
            isCurrent: () => true,
            recoverInterruptedOwner: true,
          ),
          throwsStateError,
        );
        expect(cold.get(AccountActivationCoordinator.storageKey), raw);
        expect(gate.hasUnresolvedActivation, isTrue);
        expect(gate.committedOwnerPubkey, isNull);
      });
    }

    test('an obsolete retirement cannot close a newer owner receipt', () async {
      final old = await begin();
      live = false;
      final next = await coordinator.begin(
        ownerPubkey: _bob,
        isCurrent: () => true,
      );
      final receipt = await coordinator.commit(next);
      coordinator.retire(old);
      expect(receipt.isCurrent, isTrue);
      expect(coordinator.committedOwnerPubkey, _bob);
    });

    test(
      'another live account cannot be overwritten by a late setup',
      () async {
        final ticket = await begin();
        await coordinator.commit(ticket);
        await expectLater(
          coordinator.begin(ownerPubkey: _bob, isCurrent: () => true),
          throwsStateError,
        );
        expect(coordinator.committedOwnerPubkey, _alice);
      },
    );

    test(
      'verified logout permits either account without granting old authority',
      () async {
        final ticket = await begin();
        await coordinator.completeSignOut(ticket);
        expect(coordinator.hasUnresolvedActivation, isFalse);
        expect(coordinator.committedOwnerPubkey, isNull);
        SharedPreferences.resetStatic();
        final cold = await SharedPreferences.getInstance();
        final gate = AccountActivationCoordinator.forPreferences(cold);
        final next = await gate.begin(ownerPubkey: _bob, isCurrent: () => true);
        expect(gate.committedOwnerPubkey, isNull);
        await gate.commit(next);
        expect(gate.committedOwnerPubkey, _bob);
      },
    );

    test(
      'a logout receipt cannot hide a still-persisted active owner',
      () async {
        final ticket = await begin();
        await prefs.setString('current_user_pubkey_hex', _alice);
        await expectLater(
          coordinator.completeSignOut(ticket),
          throwsStateError,
        );
        expect(coordinator.hasUnresolvedActivation, isTrue);
        expect(coordinator.committedOwnerPubkey, isNull);
      },
    );

    test('a late native write drains before the newer owner settles', () async {
      final old = await begin();
      backend.entered = Completer<void>();
      backend.resume = Completer<void>();
      backend.pausePhase = 'committed';
      final oldCommit = coordinator.commit(old);
      final rejected = expectLater(
        oldCommit,
        throwsA(isA<AccountActivationRetiredException>()),
      );
      await backend.entered!.future;
      live = false;
      var bobStarted = false;
      final next = coordinator
          .begin(ownerPubkey: _bob, isCurrent: () => true)
          .then((ticket) {
            bobStarted = true;
            return ticket;
          });
      await pumpEventQueue();
      expect(bobStarted, isFalse);
      backend.resume!.complete();
      await rejected;
      final bob = await next;
      final receipt = await coordinator.commit(bob);
      expect(receipt.isCurrent, isTrue);
      await prefs.reload();
      expect(coordinator.committedOwnerPubkey, _bob);
      expect(receipt.isCurrent, isTrue);
    });
  });
}
