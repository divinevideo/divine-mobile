// ABOUTME: Persists push notification preferences and syncs them to the push service
// ABOUTME: Keeps storage and remote update logic out of the settings UI

import 'dart:async';
import 'dart:convert';

import 'package:hive_ce/hive.dart';
import 'package:openvine/constants/hive_box_names.dart';
import 'package:openvine/models/notification_preferences.dart';
import 'package:openvine/services/account_preference_store.dart';
import 'package:openvine/services/hive_box_opener.dart';
import 'package:unified_logger/unified_logger.dart';

abstract interface class NotificationPreferencesStore {
  Future<NotificationPreferences> loadPreferences();
  Future<void> savePreferences(NotificationPreferences preferences);

  /// Drops the cached preferences shared by every account on this device.
  ///
  /// Unlike the `_dirty_<pubkey>` and `_schema_<pubkey>` entries beside it,
  /// this one carries no pubkey, so it is the departing account's choices
  /// until something clears it (#8314).
  Future<void> clearPreferences();
  Future<void> markDirty(
    String pubkey,
    NotificationPreferences preferences,
  );
  Future<NotificationPreferences?> loadDirty(String pubkey);
  Future<void> clearDirty(String pubkey);
  Future<void> clearDirtyIfMatches(
    String pubkey,
    NotificationPreferences preferences,
  );

  /// Schema version of the kinds list last published for [pubkey], or `null`
  /// when nothing has been published since the marker was introduced.
  Future<int?> loadPublishedSchemaVersion(String pubkey);

  Future<void> savePublishedSchemaVersion(String pubkey, int version);
}

class HiveNotificationPreferencesStore implements NotificationPreferencesStore {
  const HiveNotificationPreferencesStore({
    required Future<Box<dynamic>> Function() openBox,
    Future<Box<dynamic>> Function()? openDirtyBox,
  }) : _openBox = openBox,
       _openDirtyBox =
           openDirtyBox ?? HiveNotificationPreferencesStore.openDirtyBox;

  final Future<Box<dynamic>> Function() _openBox;
  final Future<Box<dynamic>> Function() _openDirtyBox;

  static const String _boxName = HiveBoxNames.notifications;
  static const String _dirtyBoxName =
      HiveBoxNames.pushNotificationPreferencesDirty;
  static const _prefsKey = 'push_preferences';
  static const _dirtyPrefix = 'push_preferences_dirty_';
  static const _schemaVersionPrefix = 'push_preferences_schema_';

  Future<NotificationPreferences?> loadExplicitPreferences() async {
    final box = await _openBox();
    final stored = box.get(_prefsKey);
    if (stored is! String) return null;
    final decoded = jsonDecode(stored);
    if (decoded is! Map<String, dynamic>) return null;
    return NotificationPreferences.fromJson(decoded);
  }

  @override
  Future<NotificationPreferences> loadPreferences() async {
    try {
      final box = await _openBox();
      final stored = box.get(_prefsKey) as String?;
      if (stored == null) {
        return const NotificationPreferences();
      }

      final json = jsonDecode(stored) as Map<String, dynamic>;
      return NotificationPreferences.fromJson(json);
    } on FormatException catch (error) {
      Log.warning(
        'Failed to decode push notification preferences: $error',
        name: 'NotificationPreferencesService',
        category: LogCategory.system,
      );
      return const NotificationPreferences();
    } on Object catch (error) {
      Log.warning(
        'Failed to load push notification preferences from Hive: $error',
        name: 'NotificationPreferencesService',
        category: LogCategory.system,
      );
      return const NotificationPreferences();
    }
  }

  @override
  Future<void> savePreferences(NotificationPreferences preferences) async {
    try {
      final box = await _openBox();
      await box.put(_prefsKey, jsonEncode(preferences.toJson()));
    } on Object catch (error) {
      Log.warning(
        'Failed to persist push notification preferences: $error',
        name: 'NotificationPreferencesService',
        category: LogCategory.system,
      );
    }
  }

  @override
  Future<void> clearPreferences() async {
    try {
      final box = await _openBox();
      await box.delete(_prefsKey);
    } on Object catch (error) {
      Log.warning(
        'Failed to clear push notification preferences: $error',
        name: 'NotificationPreferencesService',
        category: LogCategory.system,
      );
      rethrow;
    }
  }

  @override
  Future<void> markDirty(
    String pubkey,
    NotificationPreferences preferences,
  ) async {
    try {
      final box = await _openDirtyBox();
      await box.put(_dirtyKey(pubkey), jsonEncode(preferences.toJson()));
    } on Object catch (error) {
      Log.warning(
        'Failed to mark push notification preferences dirty: $error',
        name: 'NotificationPreferencesService',
        category: LogCategory.system,
      );
    }
  }

  @override
  Future<NotificationPreferences?> loadDirty(String pubkey) async {
    try {
      final box = await _openDirtyBox();
      final stored = box.get(_dirtyKey(pubkey)) as String?;
      if (stored == null) return null;

      final json = jsonDecode(stored) as Map<String, dynamic>;
      return NotificationPreferences.fromJson(json);
    } on Object catch (error) {
      Log.warning(
        'Failed to load dirty push notification preferences: $error',
        name: 'NotificationPreferencesService',
        category: LogCategory.system,
      );
      return null;
    }
  }

  @override
  Future<void> clearDirty(String pubkey) async {
    try {
      final box = await _openDirtyBox();
      await box.delete(_dirtyKey(pubkey));
    } on Object catch (error) {
      Log.warning(
        'Failed to clear dirty push notification preferences: $error',
        name: 'NotificationPreferencesService',
        category: LogCategory.system,
      );
    }
  }

  @override
  Future<void> clearDirtyIfMatches(
    String pubkey,
    NotificationPreferences preferences,
  ) async {
    try {
      final box = await _openDirtyBox();
      final stored = box.get(_dirtyKey(pubkey)) as String?;
      if (stored == null) return;

      final json = jsonDecode(stored) as Map<String, dynamic>;
      final currentPreferences = NotificationPreferences.fromJson(json);
      if (currentPreferences == preferences) {
        await box.delete(_dirtyKey(pubkey));
      }
    } on Object catch (error) {
      Log.warning(
        'Failed to conditionally clear dirty push notification preferences: $error',
        name: 'NotificationPreferencesService',
        category: LogCategory.system,
      );
    }
  }

  @override
  Future<int?> loadPublishedSchemaVersion(String pubkey) async {
    try {
      final box = await _openDirtyBox();
      return box.get(_schemaVersionKey(pubkey)) as int?;
    } on Object catch (error) {
      Log.warning(
        'Failed to load published preferences schema version: $error',
        name: 'NotificationPreferencesService',
        category: LogCategory.system,
      );
      return null;
    }
  }

  @override
  Future<void> savePublishedSchemaVersion(String pubkey, int version) async {
    try {
      final box = await _openDirtyBox();
      await box.put(_schemaVersionKey(pubkey), version);
    } on Object catch (error) {
      Log.warning(
        'Failed to persist published preferences schema version: $error',
        name: 'NotificationPreferencesService',
        category: LogCategory.system,
      );
    }
  }

  static Future<Box<dynamic>> openBox() =>
      HiveBoxOpener.open<dynamic>(_boxName);
  static Future<Box<dynamic>> openDirtyBox() =>
      HiveBoxOpener.open<dynamic>(_dirtyBoxName);

  static String _dirtyKey(String pubkey) => '$_dirtyPrefix$pubkey';

  static String _schemaVersionKey(String pubkey) =>
      '$_schemaVersionPrefix$pubkey';
}

enum NotificationPreferencesSyncOutcome {
  nothingToDrain,
  publishedAndCleared,
  stillDirty,
}

class NotificationPreferencesService {
  NotificationPreferencesService({
    required NotificationPreferencesStore store,
    required String? Function() currentPubkey,
    required Future<bool> Function(String pubkey, NotificationPreferences prefs)
    publishPreferences,
    AccountPreferenceStore? accountPreferences,
    void Function(String pubkey)? onStillDirty,
  }) : _accountPreferences = accountPreferences,
       _store = store,
       _currentPubkey = currentPubkey,
       _publishPreferences = publishPreferences,
       _onStillDirty = onStillDirty {
    _accountSubscription = _accountPreferences?.changes.listen(
      (_) => _accountChanged(),
    );
  }

  final AccountPreferenceStore? _accountPreferences;
  StreamSubscription<void>? _accountSubscription;
  Stream<void>? get changes => _accountPreferences?.changes;
  int _generation = 0;
  int _refreshRequest = 0;
  String? _lastAccountPubkey;
  bool _disposed = false;
  NotificationPreferences? _lastAccountPreferences;
  Future<void>? _migration;
  AccountPreferenceWriteLease? _migrationOwner;
  int _localMutations = 0;

  void _accountChanged() {
    if (_localMutations != 0 || _disposed) return;
    unawaited(
      _refreshAccount().catchError((Object error, StackTrace stack) {
        Log.warning(
          'Unable to refresh account notification preferences',
          name: 'NotificationPreferencesService',
          category: LogCategory.system,
        );
      }),
    );
  }

  Future<void> _refreshAccount() async {
    final pubkey = _currentPubkey();
    final request = ++_refreshRequest;
    final preferences = await loadPreferences();
    if (_disposed || request != _refreshRequest || pubkey != _currentPubkey()) {
      return;
    }
    if (preferences == _lastAccountPreferences &&
        pubkey == _lastAccountPubkey) {
      return;
    }
    final generation = ++_generation;
    _lastAccountPreferences = preferences;
    _lastAccountPubkey = pubkey;
    // Apply received choices to this device's push registration. This does not
    // write account state and therefore cannot echo the incoming event.
    if (pubkey == null) return;
    await _store.markDirty(pubkey, preferences);
    if (_disposed || generation != _generation || pubkey != _currentPubkey()) {
      return;
    }
    final outcome = await _publishAndClearDirtyPreferences(pubkey, preferences);
    if (!_disposed &&
        outcome == NotificationPreferencesSyncOutcome.stillDirty) {
      _onStillDirty?.call(pubkey);
    }
  }

  void dispose() {
    _disposed = true;
    ++_generation;
    ++_refreshRequest;
    unawaited(_accountSubscription?.cancel());
  }

  final NotificationPreferencesStore _store;
  final String? Function() _currentPubkey;
  final Future<bool> Function(String pubkey, NotificationPreferences prefs)
  _publishPreferences;
  final void Function(String pubkey)? _onStillDirty;

  /// Reads the active account after migration, including if it changed while
  /// Hive was opening. Stale reads cancel migration without failing UI refreshes;
  /// mutations retain their own initiating-account lease.
  Future<NotificationPreferences> loadPreferences() async {
    final account = _accountPreferences;
    if (account == null || !account.isBound) return _store.loadPreferences();
    final write = account.captureWrite();
    if (!(_migrationOwner?.isCurrent ?? false)) {
      _migration = null;
      _migrationOwner = write;
    }
    if (_store case final HiveNotificationPreferencesStore legacyStore) {
      await (_migration ??= () async {
        NotificationPreferences? legacy;
        try {
          legacy = await legacyStore.loadExplicitPreferences();
        } on Object {
          // A missing/corrupt legacy cache cannot replace account state.
        }
        if (!_disposed && write.isCurrent) {
          final defaults = const NotificationPreferences().toJson();
          // Seeding captures the fixed repository synchronously and cancels its
          // projection on a switch. Reads do not need mutation-lease errors.
          await account.seedLegacyNotificationPreferences({
            if (legacy != null)
              for (final entry in legacy.toJson().entries)
                if (entry.value != defaults[entry.key])
                  'notifications/${entry.key}': entry.value,
          });
        }
      }());
    }
    return NotificationPreferences.fromJson({
      for (final field in AccountPreferenceRegistry.notificationFields)
        if (account.read('notifications/$field') is bool)
          field: account.read('notifications/$field'),
    });
  }

  Future<void> updatePreferences(NotificationPreferences prefs) async {
    final account = _accountPreferences;
    final write = account?.captureWrite();
    final owner = _currentPubkey();
    if (account != null) {
      ++_localMutations;
      ++_generation;
      ++_refreshRequest;
      try {
        final previous = (await loadPreferences()).toJson();
        await write!.writeValues({
          for (final entry in prefs.toJson().entries)
            if (previous[entry.key] != entry.value)
              'notifications/${entry.key}': entry.value,
        });
        if (_disposed || owner != _currentPubkey()) return;
        final effective = await loadPreferences();
        write.ensureCurrent();
        if (_disposed || owner != _currentPubkey()) return;
        _lastAccountPreferences = effective;
        _lastAccountPubkey = owner;
        if (owner != null) {
          await _store.markDirty(owner, effective);
          if (!_disposed && owner == _currentPubkey()) {
            unawaited(
              _publishAndClearDirtyPreferences(owner, effective)
                  .then((outcome) {
                    if (!_disposed &&
                        outcome ==
                            NotificationPreferencesSyncOutcome.stillDirty) {
                      _onStillDirty?.call(owner);
                    }
                  })
                  .catchError((Object error, StackTrace stack) {
                    if (!_disposed) _onStillDirty?.call(owner);
                  }),
            );
          }
        }
      } finally {
        --_localMutations;
      }
      return;
    }
    await _store.savePreferences(prefs);
    if (owner == null) return;
    await _store.markDirty(owner, prefs);
    final outcome = await _publishAndClearDirtyPreferences(owner, prefs);
    if (outcome == NotificationPreferencesSyncOutcome.stillDirty) {
      _onStillDirty?.call(owner);
    }
  }

  Future<void> resetToDefaults() async {
    final write = _accountPreferences?.captureWrite();
    if (write != null) {
      await write.writeValues({
        for (final field in AccountPreferenceRegistry.notificationFields)
          'notifications/$field': null,
      });
    }
    write?.ensureCurrent();
    await updatePreferences(const NotificationPreferences());
    write?.ensureCurrent();
  }

  /// Schema version of the kind list [NotificationPreferences.toKindsList]
  /// currently emits.
  ///
  /// Bump this whenever a kind is added or removed, so already-installed
  /// clients republish instead of leaving the push service acting on a kind
  /// list that predates the change.
  ///
  /// * 1 — added kind 34236 (new-post / "bell" notifications).
  static const int publishedKindsSchemaVersion = 1;

  /// Marks preferences dirty when the last published kind list predates
  /// [publishedKindsSchemaVersion].
  ///
  /// Without this, an upgrading user's stored preferences read back with
  /// new flags enabled locally while the push service still holds the old
  /// kind list — the settings screen shows a notification type switched on
  /// that the service is filtering out, and nothing ever republishes because
  /// only an explicit user edit marks dirty.
  ///
  /// Marking dirty rather than publishing directly reuses the caller's
  /// readiness gating and retry handling.
  Future<bool> markDirtyIfSchemaOutdated(String pubkey) async {
    final write = _accountPreferences?.captureWrite();
    final published = await _store.loadPublishedSchemaVersion(pubkey);
    if (published == publishedKindsSchemaVersion) return false;

    // A pending edit is already queued to publish and will record the marker
    // on success. Overwriting it here would discard the user's change in
    // favour of the last-saved snapshot.
    if (await _store.loadDirty(pubkey) != null) return false;

    final preferences = await loadPreferences();
    write?.ensureCurrent();
    await _store.markDirty(pubkey, preferences);
    write?.ensureCurrent();
    return true;
  }

  Future<NotificationPreferencesSyncOutcome> syncDirtyPreferencesForPubkey(
    String pubkey,
  ) async {
    final prefs = await _store.loadDirty(pubkey);
    if (prefs == null) return NotificationPreferencesSyncOutcome.nothingToDrain;

    return _publishAndClearDirtyPreferences(pubkey, prefs);
  }

  Future<NotificationPreferencesSyncOutcome> _publishAndClearDirtyPreferences(
    String pubkey,
    NotificationPreferences preferences,
  ) async {
    final published = await _publishPreferences(pubkey, preferences);
    if (!published) {
      return NotificationPreferencesSyncOutcome.stillDirty;
    }

    // Recorded only after the publish lands, so a failed publish leaves the
    // marker behind and the next readiness pass retries.
    await _store.savePublishedSchemaVersion(
      pubkey,
      publishedKindsSchemaVersion,
    );
    await _store.clearDirtyIfMatches(pubkey, preferences);
    final dirty = await _store.loadDirty(pubkey);
    return dirty == null
        ? NotificationPreferencesSyncOutcome.publishedAndCleared
        : NotificationPreferencesSyncOutcome.stillDirty;
  }
}
