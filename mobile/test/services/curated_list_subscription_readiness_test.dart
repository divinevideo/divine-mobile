// ABOUTME: Subscription metadata decoding must not infer an empty Home snapshot.
// ABOUTME: Corrupt records remain unavailable for preference migration.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/committed_list_account.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockAuthService extends Mock implements AuthService {}

const _owner =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

void main() {
  group('curated subscription metadata readiness', () {
    Future<CuratedListService> open(Object? subscriptions) async {
      SharedPreferences.setMockInitialValues({
        CuratedListService.subscribedListsStorageKey: ?subscriptions,
      });
      final prefs = await SharedPreferences.getInstance();
      final auth = _MockAuthService();
      when(() => auth.currentPublicKeyHex).thenReturn(_owner);
      when(() => auth.isAuthenticated).thenReturn(true);
      await stubCommittedListAccount(auth: auth, preferences: prefs);
      final service = CuratedListService(
        authService: auth,
        nostrService: _MockNostrClient(),
        prefs: prefs,
      );
      addTearDown(service.dispose);
      return service;
    }

    test(
      'absent metadata is a decoded empty set before initialization',
      () async {
        final service = await open(null);

        expect(service.hasLoadedSubscriptionIds, isTrue);
        expect(service.subscribedListIds, isEmpty);
        expect(service.isInitialized, isFalse);
      },
    );

    test(
      'valid empty and qualified IDs are decoded without hydration',
      () async {
        final empty = await open('[]');
        expect(empty.hasLoadedSubscriptionIds, isTrue);
        expect(empty.subscribedListIds, isEmpty);

        const coordinate = '$_owner:series:cats';
        final followed = await open(jsonEncode([coordinate]));
        expect(followed.hasLoadedSubscriptionIds, isTrue);
        expect(followed.subscribedListIds, {coordinate});
        expect(followed.subscribedLists, isEmpty);
      },
    );

    for (final malformed in ['{', '{}', '["valid", null]', '[123]']) {
      test(
        'unreadable metadata "$malformed" cannot become authoritative',
        () async {
          final service = await open(malformed);
          final prefs = await SharedPreferences.getInstance();

          expect(service.hasLoadedSubscriptionIds, isFalse);
          expect(service.subscribedListIds, isEmpty);
          expect(
            prefs.getString(CuratedListService.subscribedListsStorageKey),
            malformed,
          );
        },
      );
    }
    for (final raw in <Object>[
      123,
      true,
      <String>['known'],
    ]) {
      test(
        'wrong preferences ${raw.runtimeType} is unreadable and retains raw evidence',
        () async {
          final service = await open(raw);
          final prefs = await SharedPreferences.getInstance();

          expect(service.hasLoadedSubscriptionIds, isFalse);
          expect(service.subscribedListIds, isEmpty);
          expect(prefs.get(CuratedListService.subscribedListsStorageKey), raw);
        },
      );
    }

    test(
      'reopening after a verified metadata repair captures new readiness',
      () async {
        final unreadable = await open('{');
        expect(unreadable.hasLoadedSubscriptionIds, isFalse);
        unreadable.dispose();
        final repaired = await open(jsonEncode(['$_owner:series::cats']));

        expect(repaired.hasLoadedSubscriptionIds, isTrue);
        expect(repaired.subscribedListIds, {'$_owner:series::cats'});
        expect(unreadable.isCurrentSession, isFalse);
      },
    );
  });
}
