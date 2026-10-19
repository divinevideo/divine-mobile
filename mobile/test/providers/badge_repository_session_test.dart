// ABOUTME: Verifies badge subscription absence proofs end with the auth session.

import 'dart:async';

import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/models/environment_config.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockAuthService extends Mock implements AuthService {}

class _MockBlocklist extends Mock implements ContentBlocklistRepository {}

void main() {
  group('badgeRepositoryProvider', () {
    test('authenticated nudges preserve a verified empty session', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final authChanges = StreamController<AuthState>.broadcast();
      addTearDown(authChanges.close);
      final auth = _MockAuthService();
      when(() => auth.currentPublicKeyHex).thenReturn('1' * 64);
      when(() => auth.authStateStream).thenAnswer((_) => authChanges.stream);
      final client = _MockNostrClient();
      when(
        () => client.queryEventsDetailed(any(), requireAllRelaysSettled: true),
      ).thenAnswer(
        (_) async => (events: <Event>[], timedOut: false, noRelays: false),
      );
      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(auth),
          nostrServiceProvider.overrideWithValue(client),
          contentBlocklistRepositoryProvider.overrideWithValue(
            _MockBlocklist(),
          ),
          currentEnvironmentProvider.overrideWithValue(
            EnvironmentConfig.production,
          ),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);
      final repository = container.read(badgeRepositoryProvider);
      await repository.loadSubscribedHolders();
      // Upgrade/resume re-emits authenticated while account and session stay put.
      authChanges.add(AuthState.authenticated);
      authChanges.add(AuthState.authenticated);
      await pumpEventQueue();
      final pending =
          Completer<({List<Event> events, bool timedOut, bool noRelays})>();
      when(
        () => client.queryEventsDetailed(any(), requireAllRelaysSettled: true),
      ).thenAnswer((_) => pending.future);
      var completed = false;
      final next = repository.loadSubscribedHolders().then(
        (_) => completed = true,
      );
      await pumpEventQueue();
      final completedBeforeRead = completed;
      pending.complete((events: <Event>[], timedOut: false, noRelays: false));
      await next;
      expect(completedBeforeRead, isTrue);
    });

    for (final queuedSignOut in [false, true]) {
      test(
        'queued account transition cannot cancel the successor first read: $queuedSignOut',
        () async {
          SharedPreferences.setMockInitialValues({});
          final prefs = await SharedPreferences.getInstance();
          final authChanges = StreamController<AuthState>.broadcast();
          addTearDown(authChanges.close);
          var account = '1' * 64;
          final auth = _MockAuthService();
          when(() => auth.currentPublicKeyHex).thenAnswer((_) => account);
          when(() => auth.authStateStream)
              .thenAnswer((_) => authChanges.stream);
          final client = _MockNostrClient();
          when(
            () => client.queryEventsDetailed(
              any(),
              requireAllRelaysSettled: true,
            ),
          ).thenAnswer(
            (_) async => (events: <Event>[], timedOut: false, noRelays: false),
          );
          final container = ProviderContainer(
            overrides: [
              authServiceProvider.overrideWithValue(auth),
              nostrServiceProvider.overrideWithValue(client),
              contentBlocklistRepositoryProvider.overrideWithValue(
                _MockBlocklist(),
              ),
              currentEnvironmentProvider.overrideWithValue(
                EnvironmentConfig.production,
              ),
              sharedPreferencesProvider.overrideWithValue(prefs),
            ],
          );
          addTearDown(container.dispose);
          final repository = container.read(badgeRepositoryProvider);
          await repository.loadSubscribedHolders();
          if (queuedSignOut) {
            account = '';
            authChanges.add(AuthState.unauthenticated);
          }
          account = '2' * 64;
          authChanges.add(AuthState.authenticated);
          final pending =
              Completer<({List<Event> events, bool timedOut, bool noRelays})>();
          when(
            () => client.queryEventsDetailed(
              any(),
              requireAllRelaysSettled: true,
            ),
          ).thenAnswer((_) => pending.future);
          var completed = false;
          final next = repository.loadSubscribedHolders().then(
            (_) => completed = true,
          );
          await pumpEventQueue();
          final completedBeforeRead = completed;
          pending.complete((
            events: <Event>[],
            timedOut: false,
            noRelays: false,
          ));
          await next;
          expect(completedBeforeRead, isFalse);
        },
      );
    }

    test(
      'signing out and back into the same account requires a new empty read',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final authChanges = StreamController<AuthState>.broadcast();
        addTearDown(authChanges.close);
        var account = '1' * 64;
        final auth = _MockAuthService();
        when(() => auth.currentPublicKeyHex).thenAnswer((_) => account);
        when(() => auth.authStateStream).thenAnswer((_) => authChanges.stream);
        final client = _MockNostrClient();
        when(
          () =>
              client.queryEventsDetailed(any(), requireAllRelaysSettled: true),
        ).thenAnswer(
          (_) async => (events: <Event>[], timedOut: false, noRelays: false),
        );
        final container = ProviderContainer(
          overrides: [
            authServiceProvider.overrideWithValue(auth),
            nostrServiceProvider.overrideWithValue(client),
            contentBlocklistRepositoryProvider.overrideWithValue(
              _MockBlocklist(),
            ),
            currentEnvironmentProvider.overrideWithValue(
              EnvironmentConfig.production,
            ),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
        );
        addTearDown(container.dispose);
        final repository = container.read(badgeRepositoryProvider);
        await repository.loadSubscribedHolders();
        account = '';
        authChanges.add(AuthState.unauthenticated);
        await pumpEventQueue();
        account = '1' * 64;
        authChanges.add(AuthState.authenticated);
        await pumpEventQueue();
        final pending =
            Completer<({List<Event> events, bool timedOut, bool noRelays})>();
        when(
          () =>
              client.queryEventsDetailed(any(), requireAllRelaysSettled: true),
        ).thenAnswer((_) => pending.future);
        var completed = false;
        final next = container
            .read(badgeRepositoryProvider)
            .loadSubscribedHolders()
            .then((_) => completed = true);
        await pumpEventQueue();
        final completedBeforeRead = completed;
        pending.complete((events: <Event>[], timedOut: false, noRelays: false));
        await next;
        expect(completedBeforeRead, isFalse);
      },
    );
  });
}
