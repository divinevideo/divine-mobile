// ABOUTME: BLoC owning the current account's device-local saved sound library.
// ABOUTME: Persists basic saves first, then quietly enriches optional waveform data.

import 'dart:async';
import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:creator_sync/creator_sync.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/blocs/saved_sounds/saved_sound_media_probe.dart';
import 'package:openvine/blocs/saved_sounds/saved_sounds_event.dart';
import 'package:openvine/blocs/saved_sounds/saved_sounds_reportable_sites.dart';
import 'package:openvine/blocs/saved_sounds/saved_sounds_state.dart';
import 'package:openvine/models/saved_sound.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:openvine/services/saved_sounds_service.dart';

export 'saved_sounds_event.dart';
export 'saved_sounds_state.dart';

class SavedSoundsBloc extends Bloc<SavedSoundsEvent, SavedSoundsState> {
  /// [syncRepositoryStream] must emit each successive [SoundSyncRepository]
  /// instance, including null while unavailable. Required rather than
  /// optional: this bloc is built once per account in the app-shell
  /// `SavedSoundsScope` — which sits above `MaterialApp.router`, where
  /// re-keying on the repository re-inflates the whole app shell
  /// (#6477/#6480) — while `soundSyncAvailabilityProvider` resolves
  /// asynchronously and can change identity later. A caller that omits the
  /// stream leaves sync permanently off for the bloc's lifetime. Pass
  /// `const Stream.empty()` in tests that don't exercise sync.
  SavedSoundsBloc({
    required SavedSoundsService service,
    required SavedSoundMediaProbe mediaProbe,
    required Stream<SoundSyncRepository?> syncRepositoryStream,
    DateTime Function()? now,
    bool Function(String path)? localFileExists,
  }) : _service = service,
       _mediaProbe = mediaProbe,
       _now = now ?? DateTime.now,
       _localFileExists = localFileExists ?? _fileExists,
       super(const SavedSoundsState()) {
    on<SavedSoundsEvent>(_onEvent, transformer: sequential());
    _syncRepositorySubscription = syncRepositoryStream.listen(
      (repository) => addIfOpen(SavedSoundSyncRepositoryChanged(repository)),
      onError: (Object error, StackTrace stackTrace) {
        addError(error, stackTrace);
      },
    );
  }

  final SavedSoundsService _service;
  final SavedSoundMediaProbe _mediaProbe;

  /// Cross-device sync, or null until the vault key resolves.
  ///
  /// Mutable by design. `state_management.md` bans mutable bloc fields for
  /// *state*, but an injected dependency is configuration, and this one has
  /// to be swappable in place: the bloc is constructed once while
  /// `soundSyncAvailabilityProvider` resolves asynchronously and can later
  /// change identity on auth transitions. `PeopleListsBloc._repository`
  /// carries the same mutable-dependency shape for the same reason.
  SoundSyncRepository? _syncRepository;
  StreamSubscription<SoundSyncRepository?>? _syncRepositorySubscription;

  final DateTime Function() _now;

  /// Whether a device-local audio path still resolves to a file on disk.
  ///
  /// Injectable so the missing-file path can be exercised without touching
  /// the filesystem.
  final bool Function(String path) _localFileExists;

  @override
  Future<void> close() async {
    // super.close() first, unawaited: it synchronously flips isClosed the
    // moment this method is invoked, matching the pre-sync-wiring
    // behavior BlocProvider's element disposal relies on. Awaiting the
    // subscription cancel before it would push that flip a microtask
    // later, unlike the same-shape PeopleListsBloc.close() where nothing
    // depends on isClosed flipping within the same tick.
    final closing = super.close();
    await _syncRepositorySubscription?.cancel();
    await closing;
  }

  /// Mirrors a local mutation to the user's other devices.
  ///
  /// Sync is best-effort: the local write has already succeeded, and any
  /// failure here — expected (relay down, vault key unavailable) or not —
  /// must never surface as a failed save. The next reconcile pass picks up
  /// anything that did not publish.
  Future<void> _mirror(
    Future<void> Function() publish, {
    required String context,
  }) async {
    if (_syncRepository == null) return;
    try {
      await publish();
    } on SyncIndexException catch (e, stackTrace) {
      addError(e, stackTrace);
    } on VaultKeyUnavailableException catch (e, stackTrace) {
      addError(e, stackTrace);
    } on LocalStoreUnreadableException catch (e, stackTrace) {
      addError(e, stackTrace);
    } catch (e, stackTrace) {
      addError(Reportable(e, context: context), stackTrace);
    }
  }

  Future<SavedSoundSaveResult> saveSound(
    AudioEvent sound, {
    SavedSoundSourceContext? sourceContext,
  }) {
    final completer = Completer<SavedSoundSaveResult>();
    add(
      SavedSoundSaveRequested(
        sound: sound,
        sourceContext: sourceContext,
        completer: completer,
      ),
    );
    return completer.future;
  }

  /// Removes [soundId], completing with an error when it could not be
  /// persisted so the caller can report the failure.
  Future<void> removeSound(String soundId) {
    final completer = Completer<void>();
    add(SavedSoundRemoveRequested(soundId, completer: completer));
    return completer.future;
  }

  Future<void> _onEvent(
    SavedSoundsEvent event,
    Emitter<SavedSoundsState> emit,
  ) async {
    switch (event) {
      case SavedSoundsLoadRequested():
        final sounds = _service.loadSavedSounds();
        emit(
          state.copyWith(
            status: SavedSoundsStatus.loaded,
            sounds: sounds,
            missingFileSoundIds: _findMissingFiles(sounds),
          ),
        );
      case SavedSoundSaveRequested():
        await _save(event, emit);
      case SavedSoundDetailsChanged():
        await _edit(event, emit);
      case SavedSoundRemoveRequested():
        await _remove(event, emit);
      case SavedSoundsQueryChanged():
        emit(state.copyWith(query: event.query));
      case SavedSoundsHashtagSelected():
        emit(state.copyWith(selectedHashtag: event.hashtag));
      case SavedSoundProbeCompleted():
        await _applyProbe(event, emit);
      case SavedSoundSyncRepositoryChanged():
        _syncRepository = event.repository;
    }
  }

  /// Device-local sounds whose file is gone.
  ///
  /// A saved entry outlives the file it points at — the originating draft's
  /// cleanup could remove it before #8011 started guarding referenced files,
  /// and a user can always delete it themselves. Left undetected the entry
  /// stays in the library and plays silence (#8023).
  Set<String> _findMissingFiles(List<SavedSound> sounds) {
    final missing = <String>{};
    for (final sound in sounds) {
      final source = sound.audio.resolvedSource;
      if (source == null || source.kind != AudioSourceKind.file) continue;
      try {
        if (!_localFileExists(source.path)) missing.add(sound.audio.id);
      } on Object {
        // An unreadable path is as unplayable as an absent one, and the user
        // needs the same way out either way.
        missing.add(sound.audio.id);
      }
    }
    return missing;
  }

  Future<void> _save(
    SavedSoundSaveRequested event,
    Emitter<SavedSoundsState> emit,
  ) async {
    final record = SavedSound(
      audio: event.sound,
      savedAt: _now().toUtc(),
      personalHashtags: const [],
      catalogTags: event.sound.externalSource?.catalogTags ?? const [],
      waveformSamples: const [],
      sourceContext: event.sourceContext,
    );
    try {
      final result = await _service.saveSavedSound(record);
      // Report the local save before mirroring. _mirror is best-effort and
      // cannot throw, so awaiting it here only made the caller wait out a
      // relay round trip — up to perRelaySendTimeout per relay, fanned out
      // sequentially — before the sound appeared in the library.
      if (!event.completer.isCompleted) event.completer.complete(result);
      if (!emit.isDone) {
        final sounds = _service.loadSavedSounds();
        emit(
          state.copyWith(
            status: SavedSoundsStatus.loaded,
            sounds: sounds,
            // Rescanning here, not only on load: this list is the one that
            // gains entries, and a set left over from the last load would
            // describe a library that no longer exists.
            missingFileSoundIds: _findMissingFiles(sounds),
          ),
        );
      }
      if (result == SavedSoundSaveResult.saved) {
        unawaited(_probe(record));
      }
      await _mirror(
        () => _syncRepository!.publishLocalChange(record.id),
        context: SavedSoundsReportableSites.mirrorSave,
      );
    } catch (error, stackTrace) {
      if (!event.completer.isCompleted) {
        event.completer.completeError(error, stackTrace);
      }
    }
  }

  Future<void> _probe(SavedSound record) async {
    final result = await _mediaProbe.probe(record.audio);
    if (!isClosed) {
      add(SavedSoundProbeCompleted(soundId: record.id, result: result));
    }
  }

  Future<void> _edit(
    SavedSoundDetailsChanged event,
    Emitter<SavedSoundsState> emit,
  ) async {
    final index = state.sounds.indexWhere((sound) => sound.id == event.soundId);
    if (index == -1) return;
    final updated = state.sounds[index].copyWith(
      personalLabel: event.label,
      personalHashtags: event.hashtags,
    );
    final optimistic = [...state.sounds]..[index] = updated;
    emit(
      state.copyWith(
        sounds: optimistic,
        unsavedSoundIds: {...state.unsavedSoundIds}..remove(event.soundId),
      ),
    );
    try {
      await _service.replaceSavedSound(updated);
      await _mirror(
        () => _syncRepository!.publishLocalChange(updated.id),
        context: SavedSoundsReportableSites.mirrorEdit,
      );
    } catch (_) {
      if (!emit.isDone) {
        emit(
          state.copyWith(
            unsavedSoundIds: {...state.unsavedSoundIds, event.soundId},
          ),
        );
      }
    }
  }

  Future<void> _remove(
    SavedSoundRemoveRequested event,
    Emitter<SavedSoundsState> emit,
  ) async {
    final completer = event.completer;
    try {
      await _service.removeSound(event.soundId);
    } catch (error, stackTrace) {
      // The row stays on screen because the delete did not happen; the caller
      // completes with the error so the UI can say so instead of claiming
      // success.
      addError(error, stackTrace);
      if (completer != null && !completer.isCompleted) {
        completer.completeError(error, stackTrace);
      }
      return;
    }

    // Drop the row before mirroring, for the reason given in _save: the
    // local delete already succeeded and _mirror cannot fail the operation,
    // so waiting on it only left a deleted sound on screen for the length
    // of a relay round trip.
    if (completer != null && !completer.isCompleted) completer.complete();
    if (!emit.isDone) {
      emit(
        state.copyWith(
          sounds: state.sounds
              .where((sound) => sound.id != event.soundId)
              .toList(growable: false),
          unsavedSoundIds: {...state.unsavedSoundIds}..remove(event.soundId),
          missingFileSoundIds: {...state.missingFileSoundIds}
            ..remove(event.soundId),
        ),
      );
    }

    await _mirror(
      () => _syncRepository!.publishLocalDeletion(event.soundId),
      context: SavedSoundsReportableSites.mirrorRemove,
    );
  }

  Future<void> _applyProbe(
    SavedSoundProbeCompleted event,
    Emitter<SavedSoundsState> emit,
  ) async {
    final result = event.result;
    if (result == null) return;
    final index = state.sounds.indexWhere((sound) => sound.id == event.soundId);
    if (index == -1) return;
    final current = state.sounds[index];
    final duration = result.durationSeconds;
    final updated = current.copyWith(
      audio: duration == null
          ? current.audio
          : current.audio.copyWith(duration: duration),
      waveformSamples: result.waveformSamples,
    );
    try {
      await _service.replaceSavedSound(updated);
      await _mirror(
        () => _syncRepository!.publishLocalChange(updated.id),
        context: SavedSoundsReportableSites.mirrorProbe,
      );
      if (emit.isDone) return;
      emit(state.copyWith(sounds: [...state.sounds]..[index] = updated));
    } catch (_) {
      // Optional enrichment must never turn a successful save into an error.
    }
  }
}

bool _fileExists(String path) => File(path).existsSync();
