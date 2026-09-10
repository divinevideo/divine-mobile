// ABOUTME: Service for per-category content filtering with Show/Warn/Hide preferences
// ABOUTME: Stores preferences in SharedPreferences, enforces age gate for adult categories

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:openvine/models/content_label.dart';
import 'package:openvine/services/age_verification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

/// User preference for how a content category should be handled in feeds.
enum ContentFilterPreference {
  /// Show content normally without any overlay.
  show,

  /// Show content with a blur overlay and "View Anyway" button.
  warn,

  /// Filter content completely from feeds (not visible at all).
  hide,
}

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
    Future<void> Function()? onAdultMediaAccessRevoked,
  }) : _onAdultMediaAccessRevoked = onAdultMediaAccessRevoked;

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
  /// age-verified. The narrow creator-only exception is defined separately in
  /// [creatorSelfLabelWarningCategories]; adult content remains behind the age
  /// gate. See #5303 for the gate and #5062/#8063 for creator visibility.
  static const Set<ContentLabel> ageRestrictedCategories = {
    ...adultCategories,
    ContentLabel.alcohol,
    ContentLabel.tobacco,
    ContentLabel.profanity,
    ContentLabel.gambling,
  };

  /// Creator-applied labels that remain visible to the creator behind a
  /// warning even when age verification would otherwise hide them.
  ///
  /// Adult and always-filtered categories deliberately stay hidden. This
  /// narrow carve-out covers the non-adult labels creators can apply during
  /// publishing without weakening the protected-media policy from #5303.
  static const Set<ContentLabel> creatorSelfLabelWarningCategories = {
    ContentLabel.alcohol,
    ContentLabel.tobacco,
    ContentLabel.profanity,
    ContentLabel.gambling,
  };

  /// Categories that Divine always filters out and does not expose as toggles.
  static const Set<ContentLabel> alwaysFilteredCategories = {
    ContentLabel.graphicMedia,
    ContentLabel.violence,
    ContentLabel.selfHarm,
    ContentLabel.porn,
    ContentLabel.drugs,
    ContentLabel.hate,
    ContentLabel.harassment,
    ContentLabel.aiGenerated,
    ContentLabel.deepfake,
    ContentLabel.spam,
    ContentLabel.scam,
  };

  /// Default preferences for each category.
  static const Map<ContentLabel, ContentFilterPreference> _defaults = {
    // Adult content stays hidden even after age verification; the user must
    // opt in per category via Content Filters.
    ContentLabel.nudity: ContentFilterPreference.hide,
    ContentLabel.sexual: ContentFilterPreference.hide,
    // Always-filtered categories are not user-configurable.
    ContentLabel.graphicMedia: ContentFilterPreference.hide,
    ContentLabel.violence: ContentFilterPreference.hide,
    ContentLabel.selfHarm: ContentFilterPreference.hide,
    ContentLabel.porn: ContentFilterPreference.hide,
    ContentLabel.drugs: ContentFilterPreference.hide,
    ContentLabel.hate: ContentFilterPreference.hide,
    ContentLabel.harassment: ContentFilterPreference.hide,
    ContentLabel.aiGenerated: ContentFilterPreference.hide,
    ContentLabel.deepfake: ContentFilterPreference.hide,
    ContentLabel.spam: ContentFilterPreference.hide,
    ContentLabel.scam: ContentFilterPreference.hide,
    // Visible non-adult categories start at warn.
    ContentLabel.alcohol: ContentFilterPreference.warn,
    ContentLabel.tobacco: ContentFilterPreference.warn,
    ContentLabel.gambling: ContentFilterPreference.warn,
    ContentLabel.profanity: ContentFilterPreference.warn,
    ContentLabel.flashingLights: ContentFilterPreference.warn,
    ContentLabel.spoiler: ContentFilterPreference.warn,
    ContentLabel.misleading: ContentFilterPreference.warn,
  };

  /// Whether the service has been initialized.
  bool get isInitialized => _initialized;

  /// Completes when persisted content-filter preferences have loaded.
  Future<void> get initialized => _initializeFuture ??= _initialize();

  /// Load preferences from SharedPreferences.
  Future<void> initialize() => initialized;

  Future<void> _initialize() async {
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
    return _preferences[label] ?? _defaultFor(label);
  }

  /// Resolves a creator-applied label for the current viewer.
  ContentFilterPreference getCreatorSelfLabelPreference(
    ContentLabel label, {
    required bool isOwner,
  }) {
    final preference = getPreference(label);
    if (isOwner &&
        preference == ContentFilterPreference.hide &&
        creatorSelfLabelWarningCategories.contains(label)) {
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
        notifyListeners();
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

    final previousAdultPreference = adultPlaybackPreference;
    _preferences[label] = preference;
    await _save();
    await _notifyIfAdultPassiveAccessRevoked(
      label: label,
      previousAdultPreference: previousAdultPreference,
    );
    notifyListeners();

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
      Map.unmodifiable(_preferences);

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
    final previousAdultPreference = adultPlaybackPreference;
    for (final label in ageRestrictedCategories) {
      _preferences[label] = ContentFilterPreference.hide;
    }
    await _save();
    await _notifyIfAdultPassiveAccessRevoked(
      previousAdultPreference: previousAdultPreference,
    );
    notifyListeners();
  }

  /// Unlock age-restricted categories when the user enables age verification.
  ///
  /// Adult categories ([adultCategories]) are never promoted: age
  /// verification only unlocks the *ability* to change them, and adult
  /// content stays hidden until the user opts in per category via Content
  /// Filters.
  ///
  /// Non-adult age-restricted categories (alcohol, tobacco, profanity,
  /// gambling) still at [ContentFilterPreference.hide] are promoted to
  /// [ContentFilterPreference.warn]. Categories the user has already
  /// explicitly changed to [warn] or [show] are left untouched, so this
  /// never overwrites a deliberate preference.
  Future<void> unlockAdultCategories() async {
    for (final label in ageRestrictedCategories) {
      if (alwaysFilteredCategories.contains(label)) continue;
      if (adultCategories.contains(label)) continue;
      if ((_preferences[label] ?? _defaultFor(label)) ==
          ContentFilterPreference.hide) {
        _preferences[label] = ContentFilterPreference.warn;
      }
    }
    await _save();
    notifyListeners();
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
    return _defaults[label] ?? ContentFilterPreference.show;
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

  Future<void> _notifyIfAdultPassiveAccessRevoked({
    required ContentFilterPreference previousAdultPreference,
    ContentLabel? label,
  }) async {
    if (label != null && !configurableAdultCategories.contains(label)) {
      return;
    }
    if (previousAdultPreference != ContentFilterPreference.show ||
        adultPlaybackPreference == ContentFilterPreference.show) {
      return;
    }
    await _notifyAdultMediaAccessRevoked();
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
