// ABOUTME: Unit tests for ProtectedMinorStickyStore — the persisted fail-safe
// ABOUTME: state machine backing the protected-minor seam (#175).

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/protected_minor_status.dart';
import 'package:openvine/services/protected_minor_sticky_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final pubkey = 'a' * 64;
  final otherPubkey = 'b' * 64;

  late SharedPreferences prefs;
  late ProtectedMinorStickyStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    store = ProtectedMinorStickyStore(prefs: prefs);
  });

  group('isProtectedMinorFor', () {
    test('unconfirmed account is not protected', () {
      expect(store.isProtectedMinorFor(pubkey), false);
      expect(store.isProtectedMinorFor(null), false);
    });
  });

  group('applyLiveStatus', () {
    test('confirmed protected persists true', () async {
      await store.applyLiveStatus(pubkey, ProtectedMinorStatus.protected());
      expect(store.isProtectedMinorFor(pubkey), true);
    });

    test('confirmed not-protected lifts to false (positive signal)', () async {
      await store.applyLiveStatus(pubkey, ProtectedMinorStatus.protected());
      await store.applyLiveStatus(pubkey, ProtectedMinorStatus.notProtected());
      expect(store.isProtectedMinorFor(pubkey), false);
    });

    test('unknown status retains last-known (sticky, never weakens)', () async {
      await store.applyLiveStatus(pubkey, ProtectedMinorStatus.protected());
      await store.applyLiveStatus(pubkey, ProtectedMinorStatus.unknown());
      expect(store.isProtectedMinorFor(pubkey), true);
    });

    test('is per-account', () async {
      await store.applyLiveStatus(pubkey, ProtectedMinorStatus.protected());
      expect(store.isProtectedMinorFor(otherPubkey), false);
    });

    test('null pubkey never persists', () async {
      await store.applyLiveStatus(null, ProtectedMinorStatus.protected());
      expect(store.isProtectedMinorFor(null), false);
    });

    test('persists across instances (cold-start read)', () async {
      await store.applyLiveStatus(pubkey, ProtectedMinorStatus.protected());
      final fresh = ProtectedMinorStickyStore(prefs: prefs);
      expect(fresh.isProtectedMinorFor(pubkey), true);
    });
  });

  group('lastKnownFor (tri-state read, #176)', () {
    test('never-seen account reads null, distinct from not-protected', () {
      // The #176 DM gate fails closed on "no verdict yet"; collapsing
      // never-seen into false would read as a positive not-protected and
      // lift the restriction before any Keycast answer exists.
      expect(store.lastKnownFor(pubkey), isNull);
      expect(store.lastKnownFor(null), isNull);
    });

    test('reads false after a positive not-protected signal', () async {
      await store.applyLiveStatus(pubkey, ProtectedMinorStatus.notProtected());
      expect(store.lastKnownFor(pubkey), isFalse);
    });

    test('reads true after a confirmed protected signal', () async {
      await store.applyLiveStatus(pubkey, ProtectedMinorStatus.protected());
      expect(store.lastKnownFor(pubkey), isTrue);
    });

    test('unknown retains the last-known verdict', () async {
      await store.applyLiveStatus(pubkey, ProtectedMinorStatus.notProtected());
      await store.applyLiveStatus(pubkey, ProtectedMinorStatus.unknown());
      expect(store.lastKnownFor(pubkey), isFalse);
    });

    test('is per-account', () async {
      await store.applyLiveStatus(pubkey, ProtectedMinorStatus.notProtected());
      expect(store.lastKnownFor(otherPubkey), isNull);
    });
  });

  group('wasKeycastAccountFor', () {
    test('unmarked account reads false', () {
      expect(store.wasKeycastAccountFor(pubkey), false);
      expect(store.wasKeycastAccountFor(null), false);
    });

    test('markKeycastAccount persists per account', () async {
      await store.markKeycastAccount(pubkey);

      expect(store.wasKeycastAccountFor(pubkey), true);
      expect(store.wasKeycastAccountFor(otherPubkey), false);
    });

    test('persists across instances', () async {
      await store.markKeycastAccount(pubkey);

      final fresh = ProtectedMinorStickyStore(prefs: prefs);
      expect(fresh.wasKeycastAccountFor(pubkey), true);
    });
  });
}
