// ABOUTME: Account erasure drains badge compatibility writes before removing keys.
// ABOUTME: Offline reopening cannot reimport erased badge decisions.

import 'dart:async';

import 'package:badge_repository/badge_repository.dart';
import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/providers/account_preferences_provider.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/moderation_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class _Client extends Mock implements NostrClient {}

class _Auth extends Mock implements AuthService {}

class _HeldBadgeStore extends InMemorySharedPreferencesStore {
  _HeldBadgeStore(this.key) : super.withData({});
  final String key;
  final entered = Completer<void>();
  final release = Completer<void>();
  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key == 'flutter.${this.key}' && !entered.isCompleted) {
      entered.complete();
      await release.future;
    }
    return super.setValue(valueType, key, value);
  }
}

void main() {
  group('badge account erasure', () {
    final owner = '1' * 64;
    final other = '2' * 64;
    final coordinate = '30009:${'3' * 64}:badge';
    setUpAll(() => registerFallbackValue(<Filter>[]));

    for (final disposed in [false, true]) {
      test(
        'drains ${disposed ? 'disposed' : 'live'} compatibility writes and erases offline',
        () async {
          SharedPreferences.setMockInitialValues({});
          final prefs = await SharedPreferences.getInstance();
          final original = SharedPreferencesStorePlatform.instance;
          final key = 'dismissed_badge_coordinates_$owner';
          final native = _HeldBadgeStore(key);
          SharedPreferencesStorePlatform.instance = native;
          addTearDown(() => SharedPreferencesStorePlatform.instance = original);
          await prefs.setStringList('dismissed_badge_coordinates_$other', [
            coordinate,
          ]);
          await prefs.setStringList('dismissed_badge_awards_$other', [
            '4' * 64,
          ]);
          await prefs.setStringList('dismissed_badge_awards_$owner', [
            '5' * 64,
          ]);
          final client = _Client();
          when(() => client.queryEvents(any())).thenAnswer((_) async => []);
          when(
            () => client.queryEventsDetailed(
              any(),
              useCache: false,
              requireAllRelaysSettled: true,
            ),
          ).thenAnswer(
            (_) async => (events: <Event>[], noRelays: true, timedOut: false),
          );
          final auth = _Auth();
          when(() => auth.currentPublicKeyHex).thenReturn(owner);
          final container = ProviderContainer(
            overrides: [
              authServiceProvider.overrideWithValue(auth),
              nostrServiceProvider.overrideWithValue(client),
              sharedPreferencesProvider.overrideWithValue(prefs),
              contentBlocklistRepositoryProvider.overrideWithValue(
                ContentBlocklistRepository(),
              ),
            ],
          );
          final barrier = container.read(accountStateWriteBarrierProvider);
          final repository = container.read(badgeRepositoryProvider);
          final hide = repository.hideAward(coordinate);
          await native.entered.future;
          if (disposed) container.dispose();
          final cleanup = UserDataCleanupService(
            prefs,
            onAccountStateWritesStop: barrier.stop,
          );
          var erased = false;
          final erase = cleanup
              .clearUserSpecificData(userPubkey: owner, forgetAccount: true)
              .then((_) => erased = true);
          await pumpEventQueue();
          final erasedBeforeWrite = erased;
          native.release.complete();
          await hide;
          await erase;
          if (!disposed) container.dispose();
          await repository.closeAccountState();
          await prefs.reload();
          expect(erasedBeforeWrite, isFalse);
          expect(prefs.containsKey(key), isFalse);
          expect(prefs.containsKey('dismissed_badge_awards_$owner'), isFalse);
          expect(prefs.getStringList('dismissed_badge_coordinates_$other'), [
            coordinate,
          ]);
          expect(prefs.getStringList('dismissed_badge_awards_$other'), [
            '4' * 64,
          ]);
          final reopened = BadgeRepository(
            nostrClient: client,
            sharedPreferences: prefs,
            currentPubkey: () => owner,
            signer: () => LocalNostrSigner('6' * 64),
            signEvent: ({
              required kind,
              required content,
              required tags,
            }) async => null,
          );
          await reopened.loadAwardedBadges();
          expect(
            prefs.getString('badge_dismissal_event_${owner}_state'),
            isNot(contains(coordinate)),
          );
          expect(prefs.containsKey(key), isFalse);
          await reopened.closeAccountState();
        },
      );
    }
  });
}
