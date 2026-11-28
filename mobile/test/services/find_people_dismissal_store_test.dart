// ABOUTME: Tests durable, account-isolated suggestion dismissals.
// ABOUTME: Rejected preference writes remain visible to the caller for retry.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/find_people_dismissal_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class _FailingPreferences extends InMemorySharedPreferencesStore {
  _FailingPreferences({
    required this.throwsError,
    Map<String, Object> data = const {},
  }) : super.withData(data);

  final bool throwsError;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (throwsError) throw StateError('storage unavailable');
    return false;
  }
}

class _DelayedRejectionPreferences extends InMemorySharedPreferencesStore {
  _DelayedRejectionPreferences(this.rejectedKey) : super.empty();

  final String rejectedKey;
  final requested = Completer<void>();
  final result = Completer<bool>();

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key == rejectedKey) {
      requested.complete();
      return result.future;
    }
    return super.setValue(valueType, key, value);
  }
}

void main() {
  group('FindPeopleDismissalStore', () {
    const firstOwner =
        '79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798';
    const secondOwner =
        'c6047f9441ed7d6d3045406e95c07cd85c778e4b8cef3ca7abac09b95c709ee5';
    const candidate =
        'f9308a019258c31049344f85f89d5229b531c845836f99b08601f113bce036f9';
    const otherCandidate =
        'e493dbf1c10d80f3581e4904930b1404cc6c13900ee0758474fa94abe8c4cd13';

    late SharedPreferencesStorePlatform originalStore;
    setUp(() {
      originalStore = SharedPreferencesStorePlatform.instance;
      SharedPreferences.setMockInitialValues({});
    });
    tearDown(() {
      SharedPreferences.resetStatic();
      SharedPreferencesStorePlatform.instance = originalStore;
    });

    test('reads and persists each account independently', () async {
      final preferences = await SharedPreferences.getInstance();
      final store = FindPeopleDismissalStore(preferences);
      expect(store.read(firstOwner), isEmpty);
      await store.write(firstOwner, [candidate]);
      expect(store.read(firstOwner), [candidate]);
      expect(store.read(secondOwner), isEmpty);
      await store.write(secondOwner, [otherCandidate]);
      final reopened = FindPeopleDismissalStore(preferences);
      expect(reopened.read(firstOwner), [candidate]);
      expect(reopened.read(secondOwner), [otherCandidate]);
    });

    test('caps stored dismissals to maxEntries keeping the newest', () async {
      final preferences = await SharedPreferences.getInstance();
      final store = FindPeopleDismissalStore(preferences);
      final entries = List.generate(
        FindPeopleDismissalStore.maxEntries + 5,
        (index) => index.toRadixString(16).padLeft(64, '0'),
      );
      await store.write(firstOwner, [...entries, entries.first]);
      final stored = store.read(firstOwner);
      expect(stored, hasLength(FindPeopleDismissalStore.maxEntries));
      // Re-dismissing entries[0] moved it to the newest end; entries[1..5]
      // were evicted as the oldest.
      expect(stored.last, equals(entries.first));
      expect(stored.first, equals(entries[6]));
      expect(stored, isNot(contains(entries[1])));
    });

    for (final throwsError in [false, true]) {
      for (final hadPrevious in [false, true]) {
        test(
          '${throwsError ? 'thrown' : 'rejected'} write restores ${hadPrevious ? 'previous' : 'empty'} dismissals',
          () async {
            final previous = [otherCandidate];
            SharedPreferencesStorePlatform.instance = _FailingPreferences(
              throwsError: throwsError,
              data: {
                if (hadPrevious)
                  'flutter.${FindPeopleDismissalStore.storageKey(firstOwner)}':
                      previous,
              },
            );
            final preferences = await SharedPreferences.getInstance();
            final store = FindPeopleDismissalStore(preferences);
            expect(store.read(firstOwner), hadPrevious ? previous : isEmpty);
            await expectLater(
              store.write(firstOwner, [candidate]),
              throwsA(isA<StateError>()),
            );
            expect(store.read(firstOwner), hadPrevious ? previous : isEmpty);
            expect(
              FindPeopleDismissalStore(preferences).read(firstOwner),
              hadPrevious ? previous : isEmpty,
            );
            await preferences.reload();
            expect(store.read(firstOwner), hadPrevious ? previous : isEmpty);
          },
        );
      }
    }

    test(
      'repairing a failed owner write preserves another owner cache',
      () async {
        final platform = _DelayedRejectionPreferences(
          'flutter.${FindPeopleDismissalStore.storageKey(firstOwner)}',
        );
        SharedPreferencesStorePlatform.instance = platform;
        final preferences = await SharedPreferences.getInstance();
        final first = FindPeopleDismissalStore(preferences);
        final second = FindPeopleDismissalStore(preferences);
        final pending = first.write(firstOwner, [candidate]);
        final failure = expectLater(pending, throwsA(isA<StateError>()));
        await platform.requested.future;
        await second.write(secondOwner, [otherCandidate]);
        expect(second.read(secondOwner), [otherCandidate]);
        platform.result.complete(false);
        await failure;
        expect(first.read(firstOwner), isEmpty);
        expect(second.read(secondOwner), [otherCandidate]);
        await preferences.reload();
        expect(second.read(secondOwner), [otherCandidate]);
      },
    );
  });
}
