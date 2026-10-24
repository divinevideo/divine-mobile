// ABOUTME: Explicit account preference registry and local projection adapter.
// ABOUTME: Captures writes durably in account state before notifying services.

import 'dart:async';
import 'dart:convert';

import 'package:account_state_repository/account_state_repository.dart';
import 'package:openvine/config/official_accounts.dart';
import 'package:openvine/models/content_filter_preference.dart';
import 'package:openvine/models/content_label.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

/// The complete allowlist of account choices. Credentials, local consent,
/// hardware, permissions, caches and developer switches never enter this map.
abstract final class AccountPreferenceRegistry {
  static const strings = {
    'content_language',
    'subtitle_target_language',
    'app_locale',
    'account_content_label',
  };
  static const booleans = {
    'audio_sharing_enabled',
    'following_moderation_enabled',
    'show_divine_hosted_only',
    'show_verified_only',
    'stats_show_total_loops',
    'stats_show_video_loops',
    'stats_show_published_date',
  };
  static const notificationFields = {
    'likesEnabled',
    'commentsEnabled',
    'followsEnabled',
    'mentionsEnabled',
    'repostsEnabled',
    'newPostsEnabled',
    'campaignsEnabled',
  };
  static Set<String> get keys => {
    ...strings,
    ...booleans,
    'subtitle_keep_original_languages',
    'feed_aspect_ratio_preference',
    'appearance_mode_preference',
    for (final label in ContentLabel.values) 'content_filter/${label.value}',
    for (final field in notificationFields) 'notifications/$field',
  };

  static bool accepts(String key, Object? value) {
    if (RegExp(r'^trusted_labeler/[0-9a-f]{64}$').hasMatch(key)) {
      return value == null || value is bool;
    }
    if (!keys.contains(key)) return false;
    if (value == null) return true;
    if (strings.contains(key)) return value is String;
    if (booleans.contains(key) || key.startsWith('notifications/')) {
      return value is bool;
    }
    if (key == 'subtitle_keep_original_languages') {
      return value is List && value.every((element) => element is String);
    }
    if (key == 'feed_aspect_ratio_preference') {
      return value == 'squareOnly' || value == 'squareAndPortrait';
    }
    if (key == 'appearance_mode_preference') {
      return value == 'system' || value == 'light' || value == 'dark';
    }
    return value == 'show' || value == 'warn' || value == 'hide';
  }
}

/// Account-scoped port shared by the existing preference services.
///
/// The provider creates this without auth dependencies, then the app's sync
/// binding attaches a fixed-account repository. This keeps cleanup/auth service
/// construction independent of the Nostr provider graph.
class AccountPreferenceStore {
  AccountPreferenceStore(this._preferences)
    : _projectionQueue = _deviceQueues[_preferences] ??= _ProjectionQueue();

  // Account containers share one native preference store. Serialize its local
  // projection across those containers so an already-issued outgoing write
  // settles before the incoming account projects. Expando does not retain a
  // disposed device store; independent device/test stores have independent queues.
  static final _deviceQueues = Expando<_ProjectionQueue>();
  final _ProjectionQueue _projectionQueue;

  static const projectionOwnerStorageKey =
      'account_preferences_projection_owner';

  /// Device-wide provenance, retained on switch to prevent cross-account seed.
  static const List<String> deviceScopedPrefsKeys = [projectionOwnerStorageKey];

  static String notificationMigrationStorageKey(String pubkey) =>
      'account_notification_preferences_migrated_$pubkey';

  static String migrationStorageKey(String pubkey) =>
      'account_preferences_migrated_$pubkey';

  final _changes = StreamController<void>.broadcast();
  Stream<void> get changes => _changes.stream;
  void _notifyChanges() {
    if (!_closed) _changes.add(null);
  }

  final SharedPreferences _preferences;
  AccountStateRepository? _repository;
  final _nativeWrites = <AccountStateRepository, Set<Future<void>>>{};
  StreamSubscription<Map<String, Object?>>? _subscription;
  bool _bound = false;
  bool _closed = false;
  bool _legacyOwnerMatches = false;
  int _generation = 0;

  bool get isBound => _bound;

  /// Unset/reset fields resolve to the caller's device default, never another
  /// account's unscoped projection. Standalone services retain local behavior.
  Object? read(String key) {
    if (_bound) {
      if (key == 'subscribed_labeler_pubkeys') {
        return [
          for (final entry
              in _repository?.values.entries ??
                  const <MapEntry<String, Object?>>[])
            if (entry.key.startsWith('trusted_labeler/') &&
                entry.value == true &&
                AccountPreferenceRegistry.accepts(entry.key, entry.value))
              entry.key.substring('trusted_labeler/'.length),
        ];
      }
      final value = _repository?.value(key);
      return AccountPreferenceRegistry.accepts(key, value) ? value : null;
    }
    return _preferences.get(key);
  }

  /// Capture before an operation's first await, including service initialization.
  /// A lease fails explicitly if an account switch interrupts that operation.
  AccountPreferenceWriteLease captureWrite() =>
      AccountPreferenceWriteLease._(this, _generation);

  Future<void> write(String key, Object? value) => writeValues({key: value});

  Future<void> writeValues(Map<String, Object?> values) async {
    if (_closed) throw StateError('Account preferences are closed');
    for (final entry in values.entries) {
      if (!AccountPreferenceRegistry.accepts(entry.key, entry.value)) {
        throw ArgumentError.value(
          entry.value,
          entry.key,
          'Unsupported account preference',
        );
      }
    }
    final repository = _repository;
    final generation = _generation;
    if (_bound && repository == null) {
      throw StateError('Account preferences are changing accounts');
    }
    if (repository != null) {
      await repository.setValues(values);
      if (_closed || generation != _generation) {
        throw StateError('Account changed during preference write');
      }
      await _project(generation);
    } else {
      for (final entry in values.entries) {
        await _writeProjection(entry.key, entry.value);
      }
      if (!_closed && generation == _generation) _notifyChanges();
    }
  }

  /// Called once per identity/client binding, before relay reconciliation.
  Future<void> bind(AccountStateRepository repository) async {
    if (_closed) return;
    final generation = ++_generation;
    _bound = true;
    _repository = repository;
    await _subscription?.cancel();
    if (_closed || generation != _generation) return;
    _subscription = repository.changes.listen((_) {
      unawaited(
        _project(generation).catchError((Object error, StackTrace stack) {
          Log.warning(
            'Unable to refresh account preference projection',
            name: 'AccountPreferenceStore',
            category: LogCategory.system,
          );
        }),
      );
    });

    // Only a proven local owner may contribute pre-sync explicit choices.
    // Older category JSON materialized defaults, so import deviations only.
    final marker = migrationStorageKey(repository.pubkey);
    _legacyOwnerMatches =
        _preferences.getString('current_user_pubkey_hex') ==
            repository.pubkey &&
        (_preferences.getString(projectionOwnerStorageKey) == null ||
            _preferences.getString(projectionOwnerStorageKey) ==
                repository.pubkey);
    if (!_legacyOwnerMatches) {
      await _writeOwnedProjection(
        repository,
        notificationMigrationStorageKey(repository.pubkey),
        true,
      );
      if (_closed || generation != _generation) return;
    }
    if (_preferences.getBool(marker) != true && _legacyOwnerMatches) {
      final legacy = <String, Object?>{};
      for (final key in AccountPreferenceRegistry.keys) {
        if (key.contains('/')) continue;
        final value = _preferences.get(key);
        if (value != null && AccountPreferenceRegistry.accepts(key, value)) {
          legacy[key] = value;
        }
      }
      for (final pubkey
          in _preferences.getStringList('subscribed_labeler_pubkeys') ??
              <String>[]) {
        final key = 'trusted_labeler/$pubkey';
        if (!isModerationAccount(pubkey) &&
            AccountPreferenceRegistry.accepts(key, true)) {
          legacy[key] = true;
        }
      }
      final categoryJson = _preferences.getString('content_filter_prefs');
      if (categoryJson != null) {
        try {
          final categories = jsonDecode(categoryJson);
          if (categories is Map) {
            for (final label in ContentLabel.values) {
              final value = categories[label.value];
              final key = 'content_filter/${label.value}';
              final defaultValue =
                  (contentFilterDefaults[label] ?? ContentFilterPreference.show)
                      .name;
              if (value != null &&
                  value != defaultValue &&
                  AccountPreferenceRegistry.accepts(key, value)) {
                legacy[key] = value;
              }
            }
          }
        } on FormatException {
          // Malformed legacy JSON is not account state.
        }
      }
      await repository.seed(legacy);
      if (_closed || generation != _generation) return;
      await _writeOwnedProjection(repository, marker, true);
    }
    await _project(generation);
  }

  /// Migrates an explicitly present Hive push record only with the same
  /// ownership evidence used for the SharedPreferences migration.
  Future<void> seedLegacyNotificationPreferences(
    Map<String, Object?> values,
  ) async {
    final repository = _repository;
    if (repository == null || !_legacyOwnerMatches || _closed) return;
    final generation = _generation;
    final marker = notificationMigrationStorageKey(repository.pubkey);
    if (_preferences.getBool(marker) == true) return;
    await repository.seed({
      for (final entry in values.entries)
        if (AccountPreferenceRegistry.accepts(entry.key, entry.value))
          entry.key: entry.value,
    });
    if (_closed || generation != _generation) return;
    await _writeOwnedProjection(repository, marker, true);
    await _project(generation);
  }

  /// Stop exposing outgoing-account data immediately during teardown.
  void detach() {
    ++_generation;
    _bound = true;
    _repository = null;
    _legacyOwnerMatches = false;
    unawaited(_subscription?.cancel());
    _subscription = null;
    final generation = _generation;
    scheduleMicrotask(() {
      if (!_closed && generation == _generation) _notifyChanges();
    });
  }

  /// Invalidates only this repository's binding and drains native writes that
  /// were already issued for it. Queued projections are generation-fenced;
  /// another account's active write is never part of this owner's drain.
  Future<void> stopProjection(AccountStateRepository repository) {
    if (identical(_repository, repository)) detach();
    return Future.wait<void>(
      _nativeWrites[repository]?.toList() ?? const [],
    );
  }

  Future<void> _writeOwnedProjection(
    AccountStateRepository repository,
    String key,
    Object? value,
  ) {
    final pending = _nativeWrites.putIfAbsent(repository, () => {});
    final write = _writeProjection(key, value);
    pending.add(write);
    void finished() {
      pending.remove(write);
      if (pending.isEmpty) _nativeWrites.remove(repository);
    }

    // Observe completion without replacing the operation's error for its
    // caller or a concurrently awaiting cleanup barrier.
    unawaited(
      write.then<void>(
        (_) => finished(),
        onError: (Object _, StackTrace _) => finished(),
      ),
    );
    return write;
  }

  Future<void> _project(int generation) {
    final next = _projectionQueue.tail.then((_) async {
      if (_closed || generation != _generation) return;
      final repository = _repository;
      if (repository == null) return;
      await _writeOwnedProjection(
        repository,
        projectionOwnerStorageKey,
        repository.pubkey,
      );
      for (final key in AccountPreferenceRegistry.keys) {
        if (_closed || generation != _generation) return;
        if (key.contains('/')) continue;
        await _writeOwnedProjection(repository, key, read(key));
      }
      if (_closed || generation != _generation) return;
      await _writeOwnedProjection(
        repository,
        'subscribed_labeler_pubkeys',
        (read('subscribed_labeler_pubkeys')! as List).cast<String>(),
      );
      if (_closed || generation != _generation) return;
      final categories = <String, String>{};
      for (final label in ContentLabel.values) {
        final value = read('content_filter/${label.value}');
        if (value is String) categories[label.value] = value;
      }
      await _writeOwnedProjection(
        repository,
        'content_filter_prefs',
        jsonEncode(categories),
      );
      if (!_closed && generation == _generation) _notifyChanges();
    });
    // Keep later projections usable even after a platform-storage error.
    _projectionQueue.tail = next.catchError((Object _, StackTrace _) {});
    return next;
  }

  Future<void> _writeProjection(String key, Object? value) async {
    final bool saved;
    if (value == null) {
      saved = await _preferences.remove(key);
    } else if (value is bool) {
      saved = await _preferences.setBool(key, value);
    } else if (value is String) {
      saved = await _preferences.setString(key, value);
    } else {
      saved = await _preferences.setStringList(
        key,
        (value as List).cast<String>(),
      );
    }
    if (!saved) throw StateError('Unable to persist account preference');
  }

  void dispose() {
    _closed = true;
    ++_generation;
    unawaited(_subscription?.cancel());
    unawaited(_changes.close());
  }
}

class _ProjectionQueue {
  Future<void> tail = Future<void>.value();
}

/// Binds an asynchronous service operation to its initiating account generation.
/// The store still owns durable writes; this lease guards awaits before the
/// first write and between writes, including completion of local projections.
class AccountPreferenceWriteLease {
  AccountPreferenceWriteLease._(this._store, this._generation);

  final AccountPreferenceStore _store;
  final int _generation;

  bool get isCurrent => !_store._closed && _generation == _store._generation;

  void ensureCurrent() {
    if (!isCurrent) {
      throw StateError('Account changed during preference operation');
    }
  }

  Future<void> write(String key, Object? value) => writeValues({key: value});

  Future<void> writeValues(Map<String, Object?> values) async {
    ensureCurrent();
    await _store.writeValues(values);
    ensureCurrent();
  }

  Future<void> seedLegacyNotificationPreferences(
    Map<String, Object?> values,
  ) async {
    ensureCurrent();
    await _store.seedLegacyNotificationPreferences(values);
    ensureCurrent();
  }
}
