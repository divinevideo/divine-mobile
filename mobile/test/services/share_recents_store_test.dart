// ABOUTME: Exercises persistence, account isolation and removal of share recents.
// ABOUTME: Local cached identities can be shown synchronously on sheet open.

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/services/share_recents_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final owner = 'f' * 64;
  final other = 'e' * 64;
  final keys = List.generate(8, (i) => i.toRadixString(16).padLeft(64, '0'));
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
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('ShareRecentsStore', () {
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
        expect(
          jsonDecode(prefs.getString(ShareRecentsStore.storageKey(owner))!),
          expected,
        );
        expect(store.snapshot(owner).map((u) => u.pubkey), expected);
        expect(store.snapshot(other).single.pubkey, keys.first);
        final reopened = newStore();
        expect(reopened.snapshot(owner), isEmpty);
        await reopened.warm(owner);
        expect(reopened.snapshot(owner).first.displayName, 'Test recipient');
        expect(reopened.snapshot(owner).map((u) => u.pubkey), expected);
        expect(reopened.snapshot(other), isEmpty);
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
        final entered = Completer<void>();
        final profiles = Completer<List<UserProfile>>();
        final store = ShareRecentsStore(
          prefs,
          loadProfiles: (_) {
            entered.complete();
            return profiles.future;
          },
        );
        final warm = store.warm(owner);
        await entered.future;
        final write = store.recordQueued(owner, [keys[1]]);
        final clear = store.clearFor(owner);
        profiles.complete([profile(keys.first)]);
        await Future.wait([warm, write, clear]);
        expect(store.snapshot(owner), isEmpty);
        expect(prefs.containsKey(ShareRecentsStore.storageKey(owner)), isFalse);
      },
    );
  });
}
