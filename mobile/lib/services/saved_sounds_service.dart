// ABOUTME: Persistence service for user-saved reusable sounds.
// ABOUTME: Stores selected AudioEvent records for the Library Sounds tab.

import 'dart:async';
import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/models/saved_sound.dart';
import 'package:openvine/utils/draft_audio_path_resolver.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

enum SavedSoundSaveResult { saved, alreadySaved }

/// Reclaims the draft-local audio file at [audioFilePath] once nothing else
/// on the device references it.
///
/// A port rather than a direct dependency: proving a file is unreferenced
/// needs the draft and clip tables, and this service owns nothing but
/// `SharedPreferences`. `LocalAudioCleanupService.reclaimUnreferencedAudio`
/// is the production implementation, wired in `savedSoundsServiceProvider`.
typedef LocalAudioReclaimer = Future<void> Function(String audioFilePath);

class SavedSoundsService {
  SavedSoundsService(
    this._preferences, {
    String? pubkeyHex,
    String documentsPath = '',
    LocalAudioReclaimer? audioReclaimer,
  }) : _pubkeyHex = pubkeyHex,
       _documentsPath = documentsPath,
       _audioReclaimer = audioReclaimer;

  /// Prefix for the per-account storage keys.
  static const _keyPrefix = 'saved_reusable_sounds';

  /// The pre-namespacing device-wide key (no account suffix). Read once at
  /// upgrade to migrate existing saves into the first account that loads.
  static const String _legacyStorageKey = _keyPrefix;

  /// Process-wide guard so the one-shot legacy migration is claimed by exactly
  /// one account. Set synchronously the instant an account claims it — before
  /// the async write — so a second account loading during that write can't also
  /// adopt the same device-wide list (#6330). Released only when the account
  /// write fails, so a failed migration retries on a later load.
  static bool _legacyMigrationClaimed = false;

  /// Resets the process-wide legacy-migration claim. Tests share one isolate,
  /// so each migration test must start from an unclaimed state.
  @visibleForTesting
  static void resetLegacyMigrationClaimForTesting() {
    _legacyMigrationClaimed = false;
  }

  final SharedPreferences _preferences;

  /// Signed-in pubkey (hex) whose saved sounds this instance manages, or
  /// `null` when signed out.
  final String? _pubkeyHex;

  /// Application documents directory that draft-local audio paths are stored
  /// relative to. Empty on web, and in tests that never persist a local file.
  final String _documentsPath;

  /// Reclaims a removed sound's audio file, or `null` when this instance
  /// cannot reach the stores that would prove the file unreferenced — in
  /// which case removal leaves the file in place, as it did before #8025.
  final LocalAudioReclaimer? _audioReclaimer;

  /// SharedPreferences key for a specific account's saved sounds.
  ///
  /// Saved sounds are scoped per account so a sound one account adopts never
  /// leaks into another account on a shared device. The signed-out state uses
  /// a dedicated anonymous bucket. Exposed so account teardown can target the
  /// deleted account's bucket without duplicating the key format.
  static String accountStorageKey(String pubkeyHex) =>
      pubkeyHex.isEmpty ? '${_keyPrefix}_anon' : '${_keyPrefix}_$pubkeyHex';

  /// SharedPreferences key for the current account's saved sounds.
  String get storageKey => accountStorageKey(_pubkeyHex ?? '');

  List<AudioEvent> loadSounds() =>
      loadSavedSounds().map((sound) => sound.audio).toList(growable: false);

  /// Whether the stored library is present but undecodable by this build.
  ///
  /// [loadSavedSounds] answers `[]` for an unreadable library exactly as it
  /// does for an empty one, which is the right call for the UI — there is
  /// nothing to draw either way — but not for callers that act on the
  /// absence of a sound. Cross-device sync uses this to tell "the user
  /// saved nothing" apart from "this build cannot read what they saved",
  /// and refuses to publish deletions in the second case.
  ///
  /// Covers a payload from a newer build ([_isForeignPayload]) as well as
  /// one whose JSON no longer parses into a recognized shape.
  bool get isLibraryUnreadable {
    final raw = _preferences.getString(storageKey);
    if (raw == null || raw.isEmpty) return false;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) return false;
      if (decoded is! Map) return true;
      final map = Map<String, dynamic>.from(decoded);
      return _isNewerSchema(map) || map['sounds'] is! List;
    } catch (_) {
      return true;
    }
  }

  /// The account's saved sounds, newest first.
  ///
  /// Draft-local audio is stored relative to the documents directory, so its
  /// path is rebased onto [_documentsPath] on the way out — that is what keeps
  /// an imported sound playable after an iOS app update rewrites the container
  /// path. Pass [resolveLocalPaths] as `false` to get the stored form instead,
  /// which is what cross-device sync publishes: a body carrying this device's
  /// container path would change hash on every app update and republish itself.
  List<SavedSound> loadSavedSounds({bool resolveLocalPaths = true}) {
    _migrateLegacyBucketIfNeeded();
    final rawSounds = _preferences.getString(storageKey);
    if (rawSounds == null || rawSounds.isEmpty) {
      return [];
    }

    final List<SavedSound> sounds;
    try {
      final decoded = jsonDecode(rawSounds);
      if (decoded is List) {
        sounds = _readLegacySounds(decoded);
      } else if (decoded is Map) {
        sounds = _readVersionedSounds(Map<String, dynamic>.from(decoded));
      } else {
        return [];
      }
    } catch (_) {
      return [];
    }

    if (!resolveLocalPaths) return sounds;
    return sounds.map(_resolvedRecord).toList();
  }

  Future<SavedSoundSaveResult> saveSound(AudioEvent sound) async {
    return saveSavedSound(
      SavedSound.fromLegacy(
        _persistableSound(sound),
      ).copyWith(savedAt: DateTime.now().toUtc()),
    );
  }

  Future<SavedSoundSaveResult> saveSavedSound(SavedSound sound) async {
    final sounds = loadSavedSounds();
    if (sounds.any((savedSound) => savedSound.id == sound.id)) {
      return SavedSoundSaveResult.alreadySaved;
    }

    await _writeSavedSounds([_persistableRecord(sound), ...sounds]);
    return SavedSoundSaveResult.saved;
  }

  /// Removes [soundId] from this account's library and reclaims the audio file
  /// it owned when nothing else still references it.
  ///
  /// The reclaim runs *after* the write, so the entry being removed cannot
  /// count as a reference to its own file, and the surviving buckets that
  /// [localAudioReferences] scans are the real survivors.
  Future<void> removeSound(String soundId) async {
    final sounds = loadSavedSounds();
    final removed = sounds
        .where((savedSound) => savedSound.id == soundId)
        .toList();
    await _writeSavedSounds(
      sounds.where((savedSound) => savedSound.id != soundId).toList(),
    );
    for (final sound in removed) {
      await _reclaimAudio(sound.audio.localFilePath);
    }
  }

  /// Hands [audioFilePath] to the reclaimer, absorbing any failure.
  ///
  /// The library write has already succeeded by the time this runs, so a
  /// failed reclaim must not fail [removeSound]: the caller reads a throw as
  /// "the entry is still saved" and would leave a deleted sound on screen.
  /// Nothing retries — the file is simply left where it is.
  Future<void> _reclaimAudio(String? audioFilePath) async {
    final reclaimer = _audioReclaimer;
    if (reclaimer == null || audioFilePath == null || audioFilePath.isEmpty) {
      return;
    }
    try {
      await reclaimer(audioFilePath);
    } catch (error) {
      Log.warning(
        '⚠️ Failed to reclaim audio for a removed saved sound: '
        '$audioFilePath - $error',
        name: 'SavedSoundsService',
        category: LogCategory.video,
      );
    }
  }

  Future<void> replaceSavedSound(SavedSound sound) async {
    final sounds = loadSavedSounds();
    final replacement = _persistableRecord(sound);
    final existingIndex = sounds.indexWhere((saved) => saved.id == sound.id);
    if (existingIndex == -1) {
      await _writeSavedSounds([replacement, ...sounds]);
      return;
    }

    sounds[existingIndex] = replacement;
    await _writeSavedSounds(sounds);
  }

  List<SavedSound> _readLegacySounds(List<dynamic> decoded) {
    final sounds = <SavedSound>[];
    for (final entry in decoded.whereType<Map>()) {
      try {
        sounds.add(
          SavedSound.fromLegacy(
            _persistableSound(
              AudioEvent.fromJson(Map<String, dynamic>.from(entry)),
            ),
          ),
        );
      } catch (_) {
        continue;
      }
    }
    return sounds;
  }

  /// Reads a versioned payload, migrating any schema at or below the current
  /// version into the current record shape.
  ///
  /// Payloads from a *newer* build are reported unreadable rather than
  /// downgraded — [_isForeignPayload] then stops a write from flattening them.
  /// Entries are parsed individually so one malformed record cannot cost the
  /// user the rest of the library.
  List<SavedSound> _readVersionedSounds(Map<String, dynamic> decoded) {
    if (_isNewerSchema(decoded)) return [];

    final rawSounds = decoded['sounds'];
    if (rawSounds is! List) return [];

    final sounds = <SavedSound>[];
    for (final entry in rawSounds.whereType<Map>()) {
      try {
        sounds.add(
          _persistableRecord(
            SavedSound.fromJson(Map<String, dynamic>.from(entry)),
          ),
        );
      } catch (_) {
        continue;
      }
    }
    return sounds;
  }

  /// Basenames of draft-local audio files a saved sound points at, across
  /// *every* account bucket on this device.
  ///
  /// Imported audio lives in library storage, but a draft can still reference
  /// the same file as a My Sounds entry. Draft cleanup consults this and keeps
  /// such a file: a dangling path can heal on load, while a deleted file cannot
  /// (#7977).
  ///
  /// All accounts, not just the signed-in one — draft cleanup already scans
  /// drafts device-wide, and a saved sound outlives the account switch that
  /// hides it. Never throws: an undecodable bucket contributes nothing.
  ///
  /// Callers that *delete* on the absence of a reference want
  /// [localAudioReferences] instead, which additionally reports whether every
  /// bucket was readable.
  static Set<String> referencedLocalAudioFilenames(
    SharedPreferences preferences,
  ) => localAudioReferences(preferences).filenames;

  /// [referencedLocalAudioFilenames] plus whether the scan could read every
  /// bucket and entry it found.
  ///
  /// `isComplete` is false when a bucket does not decode, is not one of the
  /// two recognized shapes (a payload from a newer build reaches this), or
  /// holds an entry that will not parse as an `AudioEvent`. The reference such
  /// an entry might have carried is unknown, so the filename set is a lower
  /// bound rather than the whole truth — see `LocalAudioReferences`.
  static ({Set<String> filenames, bool isComplete}) localAudioReferences(
    SharedPreferences preferences,
  ) {
    final filenames = <String>{};
    var isComplete = true;
    for (final key in preferences.getKeys()) {
      if (!key.startsWith(_keyPrefix)) continue;
      final raw = preferences.getString(key);
      if (raw == null || raw.isEmpty) continue;
      final bucket = _storedAudioJson(raw);
      if (!bucket.isComplete) isComplete = false;
      for (final audioJson in bucket.entries) {
        try {
          final path = AudioEvent.fromJson(audioJson).localFilePath;
          if (path != null && path.isNotEmpty) {
            filenames.add(p.basename(path));
          }
        } catch (_) {
          isComplete = false;
        }
      }
    }
    return (filenames: filenames, isComplete: isComplete);
  }

  /// The `AudioEvent` json of every entry in a stored bucket [raw], in either
  /// the legacy list shape or the versioned `{schemaVersion, sounds}` shape,
  /// and whether the whole bucket was readable in one of those two shapes.
  static ({List<Map<String, dynamic>> entries, bool isComplete})
  _storedAudioJson(String raw) {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return (entries: const [], isComplete: false);
    }
    final List<dynamic> rawEntries;
    if (decoded is List) {
      rawEntries = decoded;
    } else if (decoded is Map && decoded['sounds'] is List) {
      rawEntries = decoded['sounds'] as List<dynamic>;
    } else {
      return (entries: const [], isComplete: false);
    }
    final entries = <Map<String, dynamic>>[];
    var isComplete = true;
    for (final entry in rawEntries) {
      if (entry is! Map) {
        isComplete = false;
        continue;
      }
      // Legacy entries are the AudioEvent itself; versioned ones nest it.
      final audio = entry['audio'];
      entries.add(Map<String, dynamic>.from(audio is Map ? audio : entry));
    }
    return (entries: entries, isComplete: isComplete);
  }

  static bool _isNewerSchema(Map<String, dynamic> decoded) {
    final version = decoded['schemaVersion'];
    return version is int &&
        version > SavedSoundLibraryPayload.currentSchemaVersion;
  }

  /// Whether the stored payload was written by a build this one cannot read.
  bool _isForeignPayload() {
    final raw = _preferences.getString(storageKey);
    if (raw == null || raw.isEmpty) return false;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map &&
          _isNewerSchema(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return false;
    }
  }

  Future<void> _writeSavedSounds(List<SavedSound> sounds) async {
    if (_isForeignPayload()) {
      throw StateError(
        'Refusing to overwrite a saved sound library written by a newer build',
      );
    }
    final payload = SavedSoundLibraryPayload(
      schemaVersion: SavedSoundLibraryPayload.currentSchemaVersion,
      sounds: sounds.map(_persistableRecord).toList(growable: false),
    );
    final didWrite = await _preferences.setString(
      storageKey,
      jsonEncode(payload.toJson()),
    );
    if (!didWrite) {
      throw StateError('Failed to persist saved sounds');
    }
  }

  SavedSound _persistableRecord(SavedSound sound) {
    return sound.copyWith(audio: _persistableSound(sound.audio));
  }

  /// [sound] in the form that is written to disk.
  ///
  /// Strips the editor's clip anchor, and stores a draft-local audio file
  /// relative to the documents directory rather than by absolute path — iOS
  /// rewrites the container path on every app update, so an absolute path
  /// dangles from then on and the saved sound plays nothing (#7977).
  AudioEvent _persistableSound(AudioEvent sound) {
    final unanchored = sound.anchorClipId == null
        ? sound
        : sound.copyWith(clearAnchorClipId: true);
    return _mapLocalAudioPath(unanchored, toPortableAudioPath);
  }

  SavedSound _resolvedRecord(SavedSound sound) =>
      sound.copyWith(audio: _resolvedSound(sound.audio));

  /// [sound] with its stored draft-local path rebased onto [_documentsPath].
  ///
  /// [resolveAudioPath] also accepts an absolute path from a previous
  /// container, so a sound saved before the portable form existed heals the
  /// first time it is loaded.
  AudioEvent _resolvedSound(AudioEvent sound) => _mapLocalAudioPath(
    sound,
    (path) => resolveAudioPath(path, _documentsPath),
  );

  /// Applies [transform] to [sound]'s file path when it is draft-local audio.
  ///
  /// [AudioEvent.localFilePath] is the gate: a published or bundled sound's
  /// `url` is a remote address, and rewriting one would turn a playable url
  /// into a dangling local path.
  static AudioEvent _mapLocalAudioPath(
    AudioEvent sound,
    String Function(String path) transform,
  ) {
    final path = sound.localFilePath;
    if (path == null) return sound;
    final mapped = transform(path);
    return mapped == path ? sound : sound.copyWith(url: mapped);
  }

  /// One-time upgrade migration: adopt the pre-namespacing device-wide list
  /// into the first signed-in account that loads after the update, then retire
  /// the shared key so a second account can't also inherit it.
  ///
  /// Only migrates into a real account bucket (not the signed-out anonymous
  /// one) and only when this account has no bucket yet, so it runs at most once
  /// and never overwrites existing per-account data. The legacy list is
  /// unlabeled, so whichever account loads first adopts all of it — an accepted
  /// upgrade trade-off (see PR #6330).
  void _migrateLegacyBucketIfNeeded() {
    final pubkey = _pubkeyHex;
    if (pubkey == null || pubkey.isEmpty) return;
    if (_preferences.containsKey(storageKey)) return;
    if (_legacyMigrationClaimed) return;
    final legacy = _preferences.getString(_legacyStorageKey);
    if (legacy == null) return;

    // Claim synchronously: there is no await between reading the legacy key and
    // setting this flag, so a second account that loads during the async write
    // below sees the claim and cannot re-adopt the same list. setString also
    // updates the in-memory cache synchronously, so the load right after this
    // call still sees the migrated data.
    _legacyMigrationClaimed = true;
    unawaited(_migrateLegacyBucket(_consentedLegacy(legacy)));
  }

  /// Persists the migrated list into the account bucket, then retires the
  /// legacy key. The claim is released only when the account write itself fails,
  /// so a failed or interrupted write can never drop the data (the migration
  /// retries on the next load while the legacy key survives); once the write
  /// succeeds the claim stays, so no other account can re-adopt the list even if
  /// retiring the legacy key later fails.
  Future<void> _migrateLegacyBucket(String migrated) async {
    try {
      if (!await _preferences.setString(storageKey, migrated)) {
        // The account write was rejected: release the claim and leave the
        // legacy key so the next load retries the whole migration.
        _legacyMigrationClaimed = false;
        return;
      }
    } catch (_) {
      // The account write threw: same as above — retry on the next load.
      _legacyMigrationClaimed = false;
      return;
    }
    try {
      await _preferences.remove(_legacyStorageKey);
    } catch (_) {
      // Account bucket is durably written; leaving the legacy key is harmless
      // now that the claim is permanent for this process.
    }
  }

  /// Filters the pre-namespacing list to entries safe to adopt without
  /// confirming reuse consent.
  ///
  /// A video's original sound (`video_*` id) may have been saved during the
  /// pre-fix device-wide bug even though its creator had disabled reuse. That
  /// consent can't be validated offline, so those entries are dropped (fail
  /// closed). Shared (Kind 1063), bundled, and imported sounds were reusable by
  /// construction and are kept.
  String _consentedLegacy(String legacy) {
    try {
      final decoded = jsonDecode(legacy);
      if (decoded is! List) return '[]';
      final kept = <Map<String, dynamic>>[];
      for (final entry in decoded.whereType<Map>()) {
        try {
          final sound = AudioEvent.fromJson(Map<String, dynamic>.from(entry));
          if (sound.isOriginalSound) continue;
          kept.add(_persistableSound(sound).toJson());
        } catch (_) {
          continue;
        }
      }
      return jsonEncode(kept);
    } catch (_) {
      return '[]';
    }
  }
}
