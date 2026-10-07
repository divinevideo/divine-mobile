// ABOUTME: Verifies durable Home choices through device/account lease replacement.
// ABOUTME: Uses the real preferences cache and controlled native write/removal outcomes.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/feed_mode_persistence.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

const _viewer =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
const _other =
    'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
const _key = 'selected_feed_mode_$_viewer';
const _a =
    'curated:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa:crew';
const _b =
    'curated:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb:crew';

enum _NativeResult { succeeds, throwsError, returnsFalse }

class _NativeGate extends InMemorySharedPreferencesStore {
  _NativeGate({this.removal = false, this.result = _NativeResult.succeeds})
    : super.withData({
        'flutter.$_key': _a,
        'flutter.selected_feed_mode': 'classic',
      });

  final bool removal;
  final _NativeResult result;
  final started = Completer<void>();
  final release = Completer<void>();
  bool _blocked = false;

  Future<bool> _finish() async {
    _blocked = true;
    started.complete();
    await release.future;
    if (result == _NativeResult.throwsError) {
      throw StateError('Native operation failed.');
    }
    return result != _NativeResult.returnsFalse;
  }

  @override
  Future<bool> setValue(String type, String key, Object value) async {
    if (!removal && !_blocked && key == 'flutter.$_key' && value == 'forYou') {
      if (!await _finish()) return false;
    }
    return super.setValue(type, key, value);
  }

  @override
  Future<bool> remove(String key) async {
    if (removal && !_blocked && key == 'flutter.selected_feed_mode') {
      if (!await _finish()) return false;
    }
    return super.remove(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SharedPreferences> preferences(_NativeGate backend) async {
    SharedPreferences.setMockInitialValues({});
    SharedPreferencesStorePlatform.instance = backend;
    addTearDown(() {
      if (!backend.release.isCompleted) backend.release.complete();
      SharedPreferences.setMockInitialValues({});
    });
    return SharedPreferences.getInstance();
  }

  test('returning account native storage keeps its latest choice after an old lease finishes', () async {
    final backend = _NativeGate();
    final prefs = await preferences(backend);
    final registry = FeedModePersistenceRegistry(sharedPreferences: prefs);
    final first = registry.forAccount(_viewer).claim();
    final pending = first.prepare('forYou');
    await backend.started.future.timeout(const Duration(seconds: 5));
    first.release();
    final other = registry.forAccount(_other).claim();
    await other.persist('classic');
    other.release();
    final returned = registry.forAccount(_viewer).claim();
    expect(returned.savedValue, _a);
    await returned.persist(_b);
    backend.release.complete();
    final obsolete = await pending;
    expect(obsolete.accept(), isFalse);
    await obsolete.discard();
    await prefs.reload();
    expect(returned.savedValue, _b);
    expect(prefs.getString(_key), _b);
    expect(prefs.getString('selected_feed_mode_$_other'), 'classic');
  });

  for (final result in _NativeResult.values) {
    test(
      'late legacy removal $result preserves accepted and durable guest selection',
      () async {
        final backend = _NativeGate(removal: true, result: result);
        final prefs = await preferences(backend);
        final registry = FeedModePersistenceRegistry(sharedPreferences: prefs);
        final account = registry.forAccount(_viewer).claim();
        // Observe failure immediately, before releasing the platform callback.
        final pending = account
            .prepare('forYou')
            .then<Object>(
              (transaction) => transaction,
              onError: (Object error, StackTrace _) => error,
            );
        await backend.started.future.timeout(const Duration(seconds: 5));
        account.release();
        final guest = registry.forAccount(null).claim();
        expect(guest.savedValue, 'classic');
        await guest.persist('latest');
        backend.release.complete();
        final outcome = await pending;
        if (result == _NativeResult.succeeds) {
          expect(outcome, isA<ProvisionalFeedModeWrite>());
          final transaction = outcome as ProvisionalFeedModeWrite;
          expect(transaction.accept(), isFalse);
          await transaction.discard();
        } else {
          expect(outcome, isA<StateError>());
          expect(
            outcome.toString(),
            contains(
              result == _NativeResult.throwsError
                  ? 'Native operation failed.'
                  : 'The Home selection could not be persisted.',
            ),
          );
        }
        await prefs.reload();
        expect(guest.savedValue, 'latest');
        expect(prefs.getString('selected_feed_mode'), 'latest');
        expect(prefs.getString(_key), _a);
      },
    );
  }
}
