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
    final firstOwner = 'a' * 64;
    final secondOwner = 'b' * 64;
    final candidate = 'c' * 64;

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
      await store.write(secondOwner, ['d' * 64]);
      final reopened = FindPeopleDismissalStore(preferences);
      expect(reopened.read(firstOwner), [candidate]);
      expect(reopened.read(secondOwner), ['d' * 64]);
    });

    for (final throwsError in [false, true]) {
      for (final hadPrevious in [false, true]) {
        test(
          '${throwsError ? 'thrown' : 'rejected'} write restores ${hadPrevious ? 'previous' : 'empty'} dismissals',
          () async {
            final previous = ['d' * 64];
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
        await second.write(secondOwner, ['d' * 64]);
        expect(second.read(secondOwner), ['d' * 64]);
        platform.result.complete(false);
        await failure;
        expect(first.read(firstOwner), isEmpty);
        expect(second.read(secondOwner), ['d' * 64]);
        await preferences.reload();
        expect(second.read(secondOwner), ['d' * 64]);
      },
    );
  });
}
