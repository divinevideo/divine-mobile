// ABOUTME: Tests session and identity boundaries for registered-key recovery context
// ABOUTME: Prevents stale Keycast conflicts from affecting another signed-in key

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/services/auth/registered_key_conflict_store.dart';
import 'package:openvine/services/auth_service.dart';

class _MockAuthService extends Mock implements AuthService {}

void main() {
  group(RegisteredKeyConflictStore, () {
    const firstPubkey =
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
    const secondPubkey =
        'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789';

    late _MockAuthService authService;
    late RegisteredKeyConflictStore store;

    setUp(() {
      authService = _MockAuthService();
      when(() => authService.currentPublicKeyHex).thenReturn(firstPubkey);
      store = RegisteredKeyConflictStore(authService);
    });

    tearDown(() async {
      await store.dispose();
    });

    test('records a conflict only for the active key', () {
      store.record(
        expectedPubkeyHex: secondPubkey,
        email: 'late@example.com',
      );
      expect(store.current, isNull);

      store.record(
        expectedPubkeyHex: firstPubkey,
        email: 'existing@example.com',
      );

      expect(store.current?.pubkeyHex, firstPubkey);
      expect(store.current?.email, 'existing@example.com');
    });

    test('clears recovery context when authentication ends', () async {
      store.record(
        expectedPubkeyHex: firstPubkey,
        email: 'existing@example.com',
      );
      final cleared = store.stream.firstWhere((value) => value == null);

      store.syncAuthState(AuthState.unauthenticated);

      await expectLater(cleared, completion(isNull));
      expect(store.current, isNull);
    });

    test('clears recovery context when the active key changes', () async {
      store.record(
        expectedPubkeyHex: firstPubkey,
        email: 'existing@example.com',
      );
      when(() => authService.currentPublicKeyHex).thenReturn(secondPubkey);
      final cleared = store.stream.firstWhere((value) => value == null);

      store.syncAuthState(AuthState.authenticated);

      await expectLater(cleared, completion(isNull));
      expect(store.current, isNull);
    });

    test('keeps recovery context while auth re-checks the same key', () {
      store.record(
        expectedPubkeyHex: firstPubkey,
        email: 'existing@example.com',
      );

      store.syncAuthState(AuthState.checking);
      store.syncAuthState(AuthState.authenticating);

      expect(store.current?.email, 'existing@example.com');
    });
  });
}
