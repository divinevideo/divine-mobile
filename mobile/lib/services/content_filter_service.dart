// ABOUTME: Service for per-category content filtering with Show/Warn/Hide preferences
// ABOUTME: Stores preferences in SharedPreferences, enforces age gate for adult categories

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:openvine/models/content_filter_preference.dart';
import 'package:openvine/models/content_label.dart';
import 'package:openvine/services/account_preference_store.dart';
import 'package:openvine/services/age_verification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

export 'package:openvine/models/content_filter_preference.dart'
    show ContentFilterPreference;

/// Service that manages per-category content filter preferences.
///
/// Visible [ContentLabel] categories can be independently set to
/// [ContentFilterPreference] (show, warn, or hide). Categories in
/// [ageRestrictedCategories] are locked to [hide] unless the user has verified
/// they are 18+. Categories in [alwaysFilteredCategories] are always locked to
/// [hide].
///
/// Persists preferences in SharedPreferences as a JSON map.
class ContentFilterService extends ChangeNotifier {
  ContentFilterService({
    required this.ageVerificationService,
    AccountPreferenceStore? accountPreferences,
    Future<void> Function()? onAdultMediaAccessRevoked,
  }) : _accountPreferences = accountPreferences,
       _onAdultMediaAccessRevoked = onAdultMediaAccessRevoked {
    _captureEffectivePreferences();
    _accountSubscription = _accountPreferences?.changes.listen(
      (_) => _reloadAccountPreferences(),
    );
  }

  bool _disposed = false;
  final AccountPreferenceStore? _accountPreferences;
  StreamSubscription<void>? _accountSubscription;
  ContentFilterPreference _lastAccountAdultPreference =
      ContentFilterPreference.hide;
  late Map<ContentLabel, ContentFilterPreference> _lastEffectivePreferences;
  Future<void>? _pendingRevocation;

  void _captureEffectivePreferences() {
    if (_disposed) return;
    _lastEffectivePreferences = allPreferences;
    _lastAccountAdultPreference = adultPlaybackPreference;
  }

  void _reloadAccountPreferences() => unawaited(_refreshEffectivePreferences());

  Future<void> _refreshEffectivePreferences() {
    if (_disposed) return _pendingRevocation ?? Future<void>.value();
    final current = allPreferences;
    if (mapEquals(current, _lastEffectivePreferences)) {
      return _pendingRevocation ?? Future<void>.value();
    }
    final previous = _lastAccountAdultPreference;
    _lastEffectivePreferences = current;
    _lastAccountAdultPreference = adultPlaybackPreference;
    // Both the stream and a local setter can observe the same durable write.
    // Reconcile once, including the awaited adult-media revocation callback.
    // Later snapshots must retain any revocation that is still in flight.
    final revocation = _notifyIfAdultPassiveAccessRevoked(
      previousAdultPreference: previous,
    );
    if (revocation != null) {
      final previousPending = _pendingRevocation;
      late final Future<void> pending;
      pending =
          Future.wait<void>([
            ?previousPending,
            revocation,
          ]).then((_) {}).whenComplete(() {
            if (identical(_pendingRevocation, pending)) {
              _pendingRevocation = null;
            }
          });
      _pendingRevocation = pending;
    }
    notifyListeners();
    return _pendingRevocation ?? Future<void>.value();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_accountSubscription?.cancel());
    super.dispose();
  }

  /// Public so `UserDataCleanupService` can clear it by reference.
  /// A copied literal cannot detect that this key was renamed (#8314).
  static const String filterPrefsStorageKey = 'content_filter_prefs';

  /// One-shot migration flag for [filterPrefsStorageKey].
  ///
  /// Must be cleared *with* the preferences it guards. Clearing the
  /// preferences alone leaves this set, the migration never re-runs, and
  /// the next account gets an empty map instead of the defaults.
  static const String filterMigratedStorageKey = 'content_filter_migrated';

  /// Legacy adult-content preference migrated into [filterPrefsStorageKey].
  ///
  /// This must be cleared with the migration flag at an account boundary so
  /// one account cannot seed the next account's filter defaults.
  static const String legacyAdultContentPreferenceStorageKey =
      'adult_content_preference';

  final AgeVerificationService ageVerificationService;
  final Future<void> Function()? _onAdultMediaAccessRevoked;

  final Map<ContentLabel, ContentFilterPreference> _preferences = {};
  bool _initialized = false;
  Future<void>? _initializeFuture;

  /// Categories considered "adult content" — locked to hide unless 18+ verified.
  static const Set<ContentLabel> adultCategories = {
    ContentLabel.nudity,
    ContentLabel.sexual,
    ContentLabel.porn,
  };

  /// Adult categories the user can actually opt into for generic protected
  /// media playback. [ContentLabel.porn] stays in [adultCategories] so label
  /// filtering always hides it, but it is not a settings toggle.
  static const Set<ContentLabel> configurableAdultCategories = {
    ContentLabel.nudity,
    ContentLabel.sexual,
  };

  /// Categories age-gated to [ContentFilterPreference.hide] until the viewer is
  /// self-attested as an adult. Known minors also stay hidden when viewing
  /// their own videos. Ordinary creators retain warnings for the legacy
  /// alcohol, tobacco, profanity and gambling exception before attestation.
  static const Set<ContentLabel> ageRestrictedCategories = {
    ...adultCategories,
    ContentLabel.alcohol,
    ContentLabel.tobacco,
    ContentLabel.profanity,
    ContentLabel.gambling,
    ContentLabel.drugs,
  };

  /// Age-restricted categories that stay hidden until an adult has attested and
  /// then opted in, instead of being promoted to a warning on attestation.
  static const Set<ContentLabel> _adultOptInCategories = {
    ...adultCategories,
    ContentLabel.drugs,
  };

  /// Categories that Divine always filters out and does not expose as toggles.
  static const Set<ContentLabel> alwaysFilteredCategories = {
    ContentLabel.graphicMedia,
    ContentLabel.violence,
    ContentLabel.selfHarm,
    ContentLabel.porn,
    ContentLabel.hate,
    ContentLabel.harassment,
    ContentLabel.aiGenerated,
    ContentLabel.deepfake,
    ContentLabel.spam,
    ContentLabel.scam,
  };

  /// Whether the service has been initialized.
  bool get isInitialized => _initialized;

  /// Completes when persisted content-filter preferences have loaded.
  Future<void> get initialized => _initializeFuture ??= _initialize();

  /// Load preferences from SharedPreferences.
  Future<void> initialize() => initialized;

  /// Reloads the stored preferences, notifying only when they changed.
  ///
  /// The account-boundary sweep clears the stored preferences and calls this,
  /// so every holder of this instance sees the incoming account's filters.
  Future<void> reloadFromStorage() async {
    await initialized;

    // Cleanup may already have removed the unbound projection. Keep the last
    // observed effective snapshot until the reloaded values are reconciled.
    _preferences.clear();
    _initialized = false;
    _initializeFuture = _initialize(captureEffectivePreferences: false);
    await initialized;
    await _refreshEffectivePreferences();
  }

  Future<void> _initialize({bool captureEffectivePreferences = true}) async {
    if (_initialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();

      // Run migration from the old adult-content playback integer if needed
      await _migrateFromOldPreferences(prefs);

      // Load saved preferences
      final json = prefs.getString(filterPrefsStorageKey);
      if (json != null) {
        final map = jsonDecode(json) as Map<String, dynamic>;
        for (final entry in map.entries) {
          final label = ContentLabel.fromValue(entry.key);
          final pref = _preferenceFromString(entry.value as String);
          if (label != null && pref != null) {
            _preferences[label] = pref;
          }
        }
      }

      // Fill in defaults for any missing categories
      for (final label in ContentLabel.values) {
        if (label == ContentLabel.other) continue;
        _preferences.putIfAbsent(label, () => _defaultFor(label));
      }
      if (_enforceAlwaysFilteredCategories()) {
        await _save();
      }

      _initialized = true;

      Log.debug(
        'Content filter preferences loaded: ${_preferences.length} categories',
        name: 'ContentFilterService',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Error loading content filter preferences: $e',
        name: 'ContentFilterService',
        category: LogCategory.system,
      );
      // Fall back to defaults
      for (final label in ContentLabel.values) {
        if (label == ContentLabel.other) continue;
        _preferences.putIfAbsent(label, () => _defaultFor(label));
      }
      _enforceAlwaysFilteredCategories();
      _initialized = true;
    }
    if (captureEffectivePreferences) _captureEffectivePreferences();
  }

  /// Get the preference for a specific content label.
  ContentFilterPreference getPreference(ContentLabel label) {
    if (alwaysFilteredCategories.contains(label)) {
      return ContentFilterPreference.hide;
    }
    // Enforce the #5303 age gate for both creator self-labels and moderation
    // labels.
    if (ageRestrictedCategories.contains(label) &&
        !ageVerificationService.isAdultContentVerified) {
      return ContentFilterPreference.hide;
    }
    if (_accountPreferences != null) {
      final value = _accountPreferences.read('content_filter/${label.value}');
      if (value is String) {
        return _preferenceFromString(value) ?? _defaultFor(label);
      }
      if (_accountPreferences.isBound) return _defaultFor(label);
    }
    return _preferences[label] ?? _defaultFor(label);
  }

  /// Resolves a creator-applied label for the current viewer.
  ///
  /// Known minors cannot bypass age restrictions on their own uploads.
  /// Self-attested adults keep their chosen age-restricted preference, including
  /// hide. Adult content and drug use require attestation even for creators.
  /// Other self-labels keep the creator's video behind a warning rather than
  /// hiding it, including before ordinary adult self-attestation. Trusted
  /// labelers and server-side moderation do not go through here and still hide
  /// the video for everyone.
  ContentFilterPreference getCreatorSelfLabelPreference(
    ContentLabel label, {
    required bool isOwner,
  }) {
    final preference = getPreference(label);
    if (isOwner && ageRestrictedCategories.contains(label)) {
      if (ageVerificationService.isProtectedMinor) {
        return ContentFilterPreference.hide;
      }
      if (ageVerificationService.isAdultContentVerified) return preference;
      if (_adultOptInCategories.contains(label)) {
        return ContentFilterPreference.hide;
      }
    }
    if (isOwner && preference == ContentFilterPreference.hide) {
      return ContentFilterPreference.warn;
    }
    return preference;
  }

  /// Set the preference for a specific content label.
  ///
  /// Age-restricted categories cannot be set to anything other than [hide]
  /// unless the user is age-verified.
  Future<void> setPreference(
    ContentLabel label,
    ContentFilterPreference preference,
  ) async {
    if (alwaysFilteredCategories.contains(label)) {
      final changed = _preferences[label] != ContentFilterPreference.hide;
      _preferences[label] = ContentFilterPreference.hide;
      if (changed) {
        await _save();
        await _refreshEffectivePreferences();
      }
      if (preference != ContentFilterPreference.hide) {
        Log.warning(
          'Cannot set always-filtered category $label to $preference',
          name: 'ContentFilterService',
          category: LogCategory.system,
        );
      }
      return;
    }

    // Enforce age gate for restricted categories.
    if (ageRestrictedCategories.contains(label) &&
        !ageVerificationService.isAdultContentVerified &&
        preference != ContentFilterPreference.hide) {
      Log.warning(
        'Cannot set age-restricted category $label to $preference without age '
        'verification',
        name: 'ContentFilterService',
        category: LogCategory.system,
      );
      return;
    }

    if (_accountPreferences != null) {
      await _accountPreferences.write(
        'content_filter/${label.value}',
        preference.name,
      );
    } else {
      _preferences[label] = preference;
      await _save();
    }
    await _refreshEffectivePreferences();

    Log.debug(
      'Content filter updated: ${label.displayName} → ${preference.name}',
      name: 'ContentFilterService',
      category: LogCategory.system,
    );
  }

  /// Get the most restrictive preference for a list of label value strings.
  ///
  /// Returns the most restrictive match:
  /// hide > warn > show
  ///
  /// Returns [ContentFilterPreference.show] if no labels match.
  ContentFilterPreference getPreferenceForLabels(List<String> labelValues) {
    var mostRestrictive = ContentFilterPreference.show;

    for (final value in labelValues) {
      final label = ContentLabel.fromValue(value);
      if (label == null) continue;

      final pref = getPreference(label);
      if (pref == ContentFilterPreference.hide) {
        return ContentFilterPreference.hide;
      }
      if (pref == ContentFilterPreference.warn) {
        mostRestrictive = ContentFilterPreference.warn;
      }
    }

    return mostRestrictive;
  }

  /// Get all current preferences as a map.
  Map<ContentLabel, ContentFilterPreference> get allPreferences =>
      Map.unmodifiable({
        for (final label in ContentLabel.values) label: getPreference(label),
      });

  /// Aggregate the adult-category preferences for generic 18+ media playback.
  ///
  /// Age-restricted media requests do not tell us whether the server flagged
  /// the content as nudity, sexual, or porn. To avoid letting a stale legacy
  /// preference override the current settings UI, derive a single playback
  /// policy from the new per-category source of truth:
  ///
  /// - any configurable adult category at `hide` -> verified users are blocked
  /// - all configurable adult categories at `show` -> verified users can
  ///   auto-allow
  /// - any remaining mixed state -> require an explicit retry/confirmation path
  ContentFilterPreference get adultPlaybackPreference {
    final preferences = configurableAdultCategories.map(getPreference).toSet();
    if (preferences.contains(ContentFilterPreference.hide)) {
      return ContentFilterPreference.hide;
    }
    if (preferences.every((pref) => pref == ContentFilterPreference.show)) {
      return ContentFilterPreference.show;
    }
    return ContentFilterPreference.warn;
  }

  /// Reset all adult categories to hide.
  ///
  /// Called when the user un-checks age verification.
  Future<void> lockAdultCategories() async {
    final write = _accountPreferences?.captureWrite();
    if (write != null) {
      await write.writeValues({
        for (final label in ageRestrictedCategories)
          'content_filter/${label.value}': ContentFilterPreference.hide.name,
      });
    } else {
      for (final label in ageRestrictedCategories) {
        _preferences[label] = ContentFilterPreference.hide;
      }
      await _save();
    }
    await _refreshEffectivePreferences();
    write?.ensureCurrent();
  }

  /// Unlock age-restricted categories when the user enables age verification.
  ///
  /// Adult categories ([adultCategories]) are never promoted: age
  /// verification only unlocks the *ability* to change them, and adult
  /// content stays hidden until the user opts in per category via Content
  /// Filters.
  ///
  /// Drug use also stays hidden until the adult explicitly opts in.
  /// Other age-restricted categories (alcohol, tobacco, profanity,
  /// gambling) still at [ContentFilterPreference.hide] are promoted to
  /// [ContentFilterPreference.warn]. Categories the user has already
  /// explicitly changed to [warn] or [show] are left untouched, so this
  /// never overwrites a deliberate preference.
  Future<void> unlockAdultCategories() async {
    final write = _accountPreferences?.captureWrite();
    if (write != null && !ageVerificationService.isAdultContentVerified) return;
    final promoted = <ContentLabel>{};
    for (final label in ageRestrictedCategories) {
      if (alwaysFilteredCategories.contains(label)) continue;
      if (_adultOptInCategories.contains(label)) continue;
      final preference = write == null
          ? _preferences[label] ?? _defaultFor(label)
          : getPreference(label);
      if (preference == ContentFilterPreference.hide) promoted.add(label);
    }
    if (write != null) {
      await write.writeValues({
        for (final label in promoted)
          'content_filter/${label.value}': ContentFilterPreference.warn.name,
      });
    } else {
      for (final label in promoted) {
        _preferences[label] = ContentFilterPreference.warn;
      }
      await _save();
    }
    await _refreshEffectivePreferences();
  }

  /// Migrate from the old `adult_content_preference` integer.
  ///
  /// Maps:
  /// - `0` (alwaysShow) → adult categories set to show
  /// - `1` (askEachTime) → adult categories set to warn
  /// - `2` (neverShow) → adult categories set to hide
  Future<void> _migrateFromOldPreferences(SharedPreferences prefs) async {
    // Only migrate once
    if (prefs.getBool(filterMigratedStorageKey) == true) return;

    final oldPreferenceIndex = prefs.getInt(
      legacyAdultContentPreferenceStorageKey,
    );
    final newPref = switch (oldPreferenceIndex) {
      0 => ContentFilterPreference.show,
      1 => ContentFilterPreference.warn,
      2 => ContentFilterPreference.hide,
      _ => null,
    };

    if (newPref != null) {
      final persistedPreferences = <String, String>{};
      final savedPreferencesJson = prefs.getString(filterPrefsStorageKey);
      if (savedPreferencesJson != null) {
        try {
          final savedPreferences =
              jsonDecode(savedPreferencesJson) as Map<String, dynamic>;
          for (final entry in savedPreferences.entries) {
            final value = entry.value;
            if (ContentLabel.fromValue(entry.key) != null &&
                value is String &&
                _preferenceFromString(value) != null) {
              persistedPreferences[entry.key] = value;
            }
          }
        } catch (e) {
          Log.warning(
            'Ignoring invalid content filter preferences during migration: $e',
            name: 'ContentFilterService',
            category: LogCategory.system,
          );
        }
      }

      // Apply to all adult categories
      for (final label in adultCategories) {
        _preferences[label] = newPref;
        persistedPreferences.putIfAbsent(label.value, () => newPref.name);
      }

      await prefs.setString(
        filterPrefsStorageKey,
        jsonEncode(persistedPreferences),
      );

      Log.info(
        'Migrated old adult content preference '
        '($oldPreferenceIndex) → ${newPref.name} for adult categories',
        name: 'ContentFilterService',
        category: LogCategory.system,
      );
    }

    await prefs.setBool(filterMigratedStorageKey, true);
  }

  /// Persist current preferences to SharedPreferences.
  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = <String, String>{};
      for (final entry in _preferences.entries) {
        map[entry.key.value] = entry.value.name;
      }
      await prefs.setString(filterPrefsStorageKey, jsonEncode(map));
    } catch (e) {
      Log.error(
        'Error saving content filter preferences: $e',
        name: 'ContentFilterService',
        category: LogCategory.system,
      );
    }
  }

  /// Get the default preference for a given label.
  static ContentFilterPreference _defaultFor(ContentLabel label) {
    return contentFilterDefaults[label] ?? ContentFilterPreference.show;
  }

  bool _enforceAlwaysFilteredCategories() {
    var changed = false;
    for (final label in alwaysFilteredCategories) {
      if (_preferences[label] != ContentFilterPreference.hide) {
        _preferences[label] = ContentFilterPreference.hide;
        changed = true;
      }
    }
    return changed;
  }

  Future<void>? _notifyIfAdultPassiveAccessRevoked({
    required ContentFilterPreference previousAdultPreference,
  }) {
    if (previousAdultPreference != ContentFilterPreference.show ||
        adultPlaybackPreference == ContentFilterPreference.show ||
        _onAdultMediaAccessRevoked == null) {
      return null;
    }
    return _notifyAdultMediaAccessRevoked();
  }

  Future<void> _notifyAdultMediaAccessRevoked() async {
    final callback = _onAdultMediaAccessRevoked;
    if (callback == null) return;
    try {
      await callback();
    } catch (e) {
      Log.error(
        'Error clearing adult media access caches: $e',
        name: 'ContentFilterService',
        category: LogCategory.system,
      );
    }
  }

  /// Parse a preference from its string name.
  static ContentFilterPreference? _preferenceFromString(String value) {
    for (final pref in ContentFilterPreference.values) {
      if (pref.name == value) return pref;
    }
    return null;
  }
}
