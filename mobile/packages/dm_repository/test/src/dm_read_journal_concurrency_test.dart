// ABOUTME: Exercises concurrent read-journal recovery and failed native writes.
// ABOUTME: Successful intents survive quarantine, rollback and stale acks.

import 'dart:async';

import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class _HeldStore extends InMemorySharedPreferencesStore {
  _HeldStore(this.heldKey, {this.refuse = false}) : super.withData({});

  final String heldKey;
  final bool refuse;
  final entered = Completer<void>();
  final release = Completer<void>();

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key == 'flutter.$heldKey' && !entered.isCompleted) {
      entered.complete();
      await release.future;
      if (refuse) return false;
    }
    return super.setValue(valueType, key, value);
  }
}

void main() {
  group('concurrent DM read journals', () {
    const owner =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const other =
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
    final key = DmSyncState.readStateStorageKey(owner);
    late SharedPreferences prefs;
    late DmSyncState state;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      state = DmSyncState(prefs);
    });

    _HeldStore hold(String heldKey, {bool refuse = false}) {
      final original = SharedPreferencesStorePlatform.instance;
      final store = _HeldStore(heldKey, refuse: refuse);
      SharedPreferencesStorePlatform.instance = store;
      addTearDown(() => SharedPreferencesStorePlatform.instance = original);
      return store;
    }

    test(
      'overlapping corrupt recovery retains both successful boundaries',
      () async {
        final store = hold('${key}_quarantine');
        await prefs.setString(key, '{corrupt');
        final first = state.rememberReadCursors(
          owner,
          {'first': 100},
          boundaryMessageIds: {
            'first': {'1' * 64},
          },
        );
        await store.entered.future;
        final second = DmSyncState(prefs).rememberReadCursors(
          owner,
          {'second': 200},
          boundaryMessageIds: {
            'second': {'2' * 64},
          },
        );
        await state.rememberReadCursors(other, {'other': 300});
        store.release.complete();
        await Future.wait([first, second]);
        await prefs.reload();
        expect(state.readCursors(owner), {'first': 100, 'second': 200});
        expect(state.readBoundaryMessageIds(owner, 'first'), {'1' * 64});
        expect(state.readBoundaryMessageIds(owner, 'second'), {'2' * 64});
        expect(state.pendingReadRevision(owner), 2);
        expect(state.readCursors(other), {'other': 300});
        expect(prefs.getString('${key}_quarantine'), '{corrupt');
      },
    );

    test(
      'refused earlier write cannot roll back later successful read',
      () async {
        final store = hold(key, refuse: true);
        final first = expectLater(
          state.rememberReadCursors(owner, {'refused': 100}),
          throwsStateError,
        );
        await store.entered.future;
        final second = state.rememberReadCursors(owner, {'saved': 200});
        await state.rememberReadCursors(other, {'other': 300});
        store.release.complete();
        await Future.wait([first, second]);
        await prefs.reload();
        expect(state.readCursors(owner), {'saved': 200});
        expect(state.readCursors(other), {'other': 300});
        await state.rememberReadCursors(owner, {'retried': 100});
        await prefs.reload();
        expect(state.readCursors(owner), {'saved': 200, 'retried': 100});
      },
    );

    test(
      'acknowledgment waits for recovery and preserves a newer read',
      () async {
        final store = hold('${key}_quarantine');
        await prefs.setString(key, '{corrupt');
        final first = state.rememberReadCursors(owner, {'first': 100});
        await store.entered.future;
        final ack = state.acknowledgeReadRevision(owner, 1);
        final second = state.rememberReadCursors(owner, {'second': 200});
        store.release.complete();
        await Future.wait([first, ack, second]);
        await prefs.reload();
        expect(state.readCursors(owner), {'first': 100, 'second': 200});
        expect(state.pendingReadRevision(owner), 2);
      },
    );
  });
}
