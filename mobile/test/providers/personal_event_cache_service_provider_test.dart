// ABOUTME: Tests provider auth reactivity for PersonalEventCacheService.
// ABOUTME: Ensures late auth initialization flushes queued personal events.

import 'dart:async';

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/personal_event_cache_service.dart';

import '../helpers/test_helpers.dart';

class _MockAuthService extends Mock implements AuthService {}

const String _userPubkey =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const String _otherPubkey =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

/// Wall-clock budget for the async-settling helpers in this suite.
///
/// Generous enough to absorb a loaded CI isolate, and well inside the 30s
/// per-test default so an expiry reports itself instead of hanging the shard.
const Duration _settleTimeout = Duration(seconds: 10);

String _hexId(int index) => index.toRadixString(16).padLeft(64, '0');

Event _createEvent({required String pubkey, required String id}) {
  final event = Event(
    pubkey,
    32222,
    const [
      ['d', 'test-video-id'],
      ['title', 'Plants'],
    ],
    'A plant video',
    createdAt: 1700000000,
  );
  event.id = id;
  event.sig = id.padRight(128, '0').substring(0, 128);
  return event;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(personalEventCacheServiceProvider, () {
    late AppDatabase database;
    late _MockAuthService authService;
    late StreamController<AuthState> authStateController;

    setUp(() {
      database = AppDatabase.test(NativeDatabase.memory());
      authService = _MockAuthService();
      authStateController = StreamController<AuthState>.broadcast();
      addTearDown(database.close);
      addTearDown(authStateController.close);
      when(() => authService.authState).thenReturn(AuthState.unauthenticated);
      when(
        () => authService.authStateStream,
      ).thenAnswer((_) => authStateController.stream);
      when(() => authService.isAuthenticated).thenReturn(false);
      when(() => authService.currentPublicKeyHex).thenReturn(null);
    });

    ProviderContainer buildContainer() {
      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(authService),
          databaseProvider.overrideWithValue(database),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    Future<void> authenticate() async {
      when(() => authService.authState).thenReturn(AuthState.authenticated);
      when(() => authService.isAuthenticated).thenReturn(true);
      when(() => authService.currentPublicKeyHex).thenReturn(_userPubkey);

      authStateController.add(AuthState.authenticated);
    }

    void unauthenticate() {
      when(() => authService.authState).thenReturn(AuthState.unauthenticated);
      when(() => authService.isAuthenticated).thenReturn(false);
      when(() => authService.currentPublicKeyHex).thenReturn(null);

      authStateController.add(AuthState.unauthenticated);
    }

    void emitChecking() {
      when(() => authService.authState).thenReturn(AuthState.checking);
      when(() => authService.isAuthenticated).thenReturn(false);
      when(() => authService.currentPublicKeyHex).thenReturn(null);

      authStateController.add(AuthState.checking);
    }

    /// Waits on wall-clock time rather than a fixed pump count because cache
    /// initialization and persistence complete asynchronously.
    Future<void> waitForPersonalCache(
      String description,
      bool Function() isSatisfied,
    ) => TestHelpers.waitForCondition(
      isSatisfied,
      timeout: _settleTimeout,
      description: description,
    );

    Future<void> waitForInitialized(PersonalEventCacheService service) =>
        waitForPersonalCache(
          'PersonalEventCacheService to finish initializing',
          () => service.isInitialized,
        );

    Future<void> waitForCachedEvent(
      PersonalEventCacheService service,
      Event event,
    ) => waitForPersonalCache(
      'event ${event.id} to be added to the kind ${event.kind} index',
      () => service
          .getEventsByKind(event.kind)
          .any((cachedEvent) => cachedEvent.id == event.id),
    );

    test(
      'initializes when auth becomes ready after provider construction',
      () async {
        final container = buildContainer();
        final subscription = container.listen(
          personalEventCacheServiceProvider,
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(subscription.close);

        final service = subscription.read();
        expect(service.isInitialized, isFalse);

        await authenticate();
        await waitForInitialized(service);

        expect(service.isInitialized, isTrue);
      },
    );

    test(
      'flushes queued personal events after late auth initialization',
      () async {
        final container = buildContainer();
        final subscription = container.listen(
          personalEventCacheServiceProvider,
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(subscription.close);
        final ownEvent = _createEvent(pubkey: _userPubkey, id: _hexId(1));
        final otherEvent = _createEvent(pubkey: _otherPubkey, id: _hexId(2));

        final service = subscription.read();
        service.cacheUserEvent(ownEvent);
        service.cacheUserEvent(otherEvent);

        await authenticate();
        await waitForInitialized(service);

        expect(service.hasEvent(ownEvent.id), isTrue);
        expect(service.getEventById(ownEvent.id)?.id, ownEvent.id);
        expect(service.hasEvent(otherEvent.id), isFalse);
        expect(service.getEventById(otherEvent.id), isNull);
      },
    );

    test('keeps queued events through transient non-auth states', () async {
      final container = buildContainer();
      final subscription = container.listen(
        personalEventCacheServiceProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      final ownEvent = _createEvent(pubkey: _userPubkey, id: _hexId(3));

      final service = subscription.read();
      service.cacheUserEvent(ownEvent);

      emitChecking();
      await authenticate();
      await waitForInitialized(service);

      expect(service.hasEvent(ownEvent.id), isTrue);
      expect(service.getEventById(ownEvent.id)?.id, ownEvent.id);
    });

    test(
      'resets active cache session when auth becomes unauthenticated',
      () async {
        final container = buildContainer();
        final subscription = container.listen(
          personalEventCacheServiceProvider,
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(subscription.close);
        final ownEvent = _createEvent(pubkey: _userPubkey, id: _hexId(4));

        final service = subscription.read();
        await authenticate();
        await waitForInitialized(service);
        service.cacheUserEvent(ownEvent);
        await waitForCachedEvent(service, ownEvent);
        expect(service.hasEvent(ownEvent.id), isTrue);

        unauthenticate();
        await pumpEventQueue();

        expect(service.isInitialized, isFalse);
        expect(service.hasEvent(ownEvent.id), isFalse);
        expect(service.getEventById(ownEvent.id), isNull);
      },
    );
  });
}
