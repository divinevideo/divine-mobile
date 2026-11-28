// ABOUTME: Exercises persistence, account isolation and removal of share recents.
// ABOUTME: Local cached identities can be shown synchronously on sheet open.

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/services/share_recents_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_pubkeys.dart';

class _MockSharedPreferences extends Mock implements SharedPreferences {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(ShareRecentsStore, () {
    final owner = testPubkeyFromSeed(100);
    final other = testPubkeyFromSeed(101);
    final keys = List.generate(8, (i) => testPubkeyFromSeed(i + 1));
    late SharedPreferences prefs;

    UserProfile profile(String key) => UserProfile(
      pubkey: key,
      rawData: const {},
      createdAt: DateTime.utc(2026),
      eventId: 'a' * 64,
      displayName: 'Test recipient',
    );

    ShareRecentsStore newStore() => ShareRecentsStore(
      prefs,
      loadProfiles: (keys) async => keys.map(profile).toList(),
    );

    List<String>? stored(String owner) {
      final raw = prefs.getString(ShareRecentsStore.storageKey(owner));
      return raw == null ? null : List<String>.from(jsonDecode(raw) as List);
    }

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test(
      'warm and concurrent shares preserve six unique keys per owner',
      () async {
        final store = newStore();
        expect(store.snapshot(owner), isEmpty);
        await Future.wait([
          store.recordQueued(owner, keys.take(4)),
          store.recordQueued(owner, [keys[2], ...keys.skip(4)]),
          store.recordQueued(other, [keys.first]),
        ]);
        final expected = [keys[2], ...keys.skip(4), keys.first];
        expect(stored(owner), expected);
        expect(stored(other), [keys.first]);
        expect(store.snapshot(owner).map((u) => u.pubkey), expected);
        expect(store.snapshot(other).single.pubkey, keys.first);

        final reopened = newStore();
        expect(reopened.snapshot(owner), isEmpty);
        await reopened.warm(owner);
        expect(reopened.snapshot(owner).first.displayName, 'Test recipient');
        expect(reopened.snapshot(owner).map((u) => u.pubkey), expected);
        // Warming one owner loads only that owner's row.
        expect(reopened.snapshot(other), isEmpty);
        await reopened.warm(other);
        expect(reopened.snapshot(other).map((u) => u.pubkey), [keys.first]);
        expect(reopened.snapshot(owner).map((u) => u.pubkey), expected);
      },
    );

    test('a missing profile stays on disk and off the visible row', () async {
      final store = ShareRecentsStore(
        prefs,
        loadProfiles: (_) async => [profile(keys[1])],
      );
      await store.recordQueued(owner, keys.take(2));
      expect(store.snapshot(owner).map((user) => user.pubkey), [keys[1]]);
      final reopened = newStore();
      await reopened.warm(owner);
      expect(reopened.snapshot(owner).map((user) => user.pubkey), keys.take(2));
    });

    test(
      'clear invalidates a pending warm and queued write for just one owner',
      () async {
        await prefs.setString(
          ShareRecentsStore.storageKey(owner),
          jsonEncode([keys.first]),
        );
        await prefs.setString(
          ShareRecentsStore.storageKey(other),
          jsonEncode([keys[2]]),
        );
        final entered = Completer<void>();
        final profiles = Completer<List<UserProfile>>();
        final store = ShareRecentsStore(
          prefs,
          loadProfiles: (keys) {
            if (!entered.isCompleted) {
              entered.complete();
              return profiles.future;
            }
            return Future.value(keys.map(profile).toList());
          },
        );
        final warm = store.warm(owner);
        await entered.future;
        final write = store.recordQueued(owner, [keys[1]]);
        final otherWrite = store.recordQueued(other, [keys[3]]);
        final clear = store.clearFor(owner);
        profiles.complete([profile(keys.first)]);
        await Future.wait([warm, write, otherWrite, clear]);

        expect(store.snapshot(owner), isEmpty);
        expect(prefs.containsKey(ShareRecentsStore.storageKey(owner)), isFalse);
        expect(stored(other), [keys[3], keys[2]]);
        expect(store.snapshot(other).map((u) => u.pubkey), [keys[3], keys[2]]);
      },
    );

    group('storage refusals', () {
      late _MockSharedPreferences refusingPrefs;

      setUp(() {
        refusingPrefs = _MockSharedPreferences();
        when(() => refusingPrefs.get(any())).thenReturn(null);
        when(() => refusingPrefs.containsKey(any())).thenReturn(true);
        when(
          () => refusingPrefs.setString(any(), any()),
        ).thenAnswer((_) async => false);
        when(() => refusingPrefs.remove(any())).thenAnswer((_) async => false);
      });

      ShareRecentsStore refusingStore() => ShareRecentsStore(
        refusingPrefs,
        loadProfiles: (keys) async => keys.map(profile).toList(),
      );

      test('a refused write throws a storage exception, not an Error', () {
        expect(
          refusingStore().recordQueued(owner, [keys.first]),
          throwsA(
            isA<ShareRecentsStorageException>().having(
              (e) => e.operation,
              'operation',
              'persist',
            ),
          ),
        );
      });

      test('a refused removal throws a storage exception, not an Error', () {
        expect(
          refusingStore().clearFor(owner),
          throwsA(
            isA<ShareRecentsStorageException>().having(
              (e) => e.operation,
              'operation',
              'remove',
            ),
          ),
        );
      });
    });
  });
}
