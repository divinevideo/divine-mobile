// ABOUTME: Tests the BLoC owning device-local saved sound library state.
// ABOUTME: Covers durable saves, optional enrichment, edits, search, and removal.

import 'dart:async';
import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:creator_sync/creator_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/saved_sounds/saved_sound_media_probe.dart';
import 'package:openvine/blocs/saved_sounds/saved_sounds_bloc.dart';
import 'package:openvine/models/saved_sound.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:openvine/services/saved_sounds_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockSoundSyncRepository extends Mock implements SoundSyncRepository {}

class _CapturingObserver extends BlocObserver {
  final errors = <Object>[];

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    errors.add(error);
    super.onError(bloc, error, stackTrace);
  }
}

class _ControlledProbe implements SavedSoundMediaProbe {
  final calls = <AudioEvent>[];
  Completer<SavedSoundMediaResult?>? completer;
  SavedSoundMediaResult? result;

  @override
  Future<SavedSoundMediaResult?> probe(AudioEvent sound) {
    calls.add(sound);
    final controlled = completer;
    return controlled?.future ?? Future.value(result);
  }
}

AudioEvent _sound({
  String id = 'sound-1',
  String title = 'Rain Guitar',
  List<String> tags = const ['field recording'],
}) => AudioEvent(
  id: id,
  pubkey: 'creator',
  createdAt: 1,
  title: title,
  url: 'https://example.com/$id.m4a',
  externalSource: AudioExternalSource(
    provider: 'freesound',
    providerSoundId: id,
    providerName: 'Freesound',
    license: AudioLicenseMetadata(
      type: 'cc0',
      name: 'CC0',
      url: 'https://creativecommons.org/publicdomain/zero/1.0/',
      allowsCommercialUse: true,
      allowsDerivatives: true,
      requiresAttribution: false,
    ),
    catalogTags: tags,
  ),
);

Future<void> _settle() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  late SavedSoundsService service;
  late _ControlledProbe probe;
  late SavedSoundsBloc bloc;

  SavedSoundsBloc buildBloc({
    SoundSyncRepository? syncRepository,
    bool Function(String path)? localFileExists,
  }) => SavedSoundsBloc(
    service: service,
    mediaProbe: probe,
    syncRepositoryStream: syncRepository == null
        ? const Stream.empty()
        : Stream.value(syncRepository),
    now: () => DateTime.utc(2026, 7, 31),
    localFileExists: localFileExists ?? (_) => true,
  );

  /// Builds a synced bloc and waits for [syncRepository] to be applied.
  ///
  /// `syncRepositoryStream`'s seed value reaches `_syncRepository` through
  /// an async stream subscription plus the bloc's own sequential event
  /// queue, not synchronously at construction — matching how the real
  /// `soundSyncRepositoryStreamProvider` seed arrives in production.
  Future<SavedSoundsBloc> buildSyncedBloc(
    SoundSyncRepository syncRepository,
  ) async {
    final syncedBloc = buildBloc(syncRepository: syncRepository);
    await _settle();
    return syncedBloc;
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    service = SavedSoundsService(await SharedPreferences.getInstance());
    probe = _ControlledProbe();
    bloc = buildBloc();
  });

  tearDown(() => bloc.close());

  test('loads persisted records', () async {
    await service.saveSavedSound(
      SavedSound.fromLegacy(_sound(id: 'existing')),
    );

    bloc.add(const SavedSoundsLoadRequested());
    await _settle();

    expect(bloc.state.sounds.single.id, 'existing');
  });

  test(
    'durably saves basic context and catalog tags before probe finishes',
    () async {
      probe.completer = Completer<SavedSoundMediaResult?>();
      const context = SavedSoundSourceContext(
        creatorName: 'Alice',
        description: 'A rainy loop',
      );

      final result = await bloc.saveSound(_sound(), sourceContext: context);

      expect(result, SavedSoundSaveResult.saved);
      expect(bloc.state.sounds.single.savedAt, DateTime.utc(2026, 7, 31));
      expect(bloc.state.sounds.single.sourceContext, context);
      expect(bloc.state.sounds.single.catalogTags, ['field recording']);
      expect(service.loadSavedSounds(), bloc.state.sounds);
      expect(probe.completer!.isCompleted, isFalse);
    },
  );

  test(
    'duplicate save reports alreadySaved and does not probe again',
    () async {
      await bloc.saveSound(_sound());
      await _settle();
      final result = await bloc.saveSound(_sound());

      expect(result, SavedSoundSaveResult.alreadySaved);
      expect(probe.calls, hasLength(1));
    },
  );

  test(
    'successful probe replaces duration and waveform on the same full ID',
    () async {
      probe.completer = Completer<SavedSoundMediaResult?>();
      await bloc.saveSound(_sound());

      probe.completer!.complete(
        const SavedSoundMediaResult(
          durationSeconds: 4.5,
          waveformSamples: [0.1, 0.8],
        ),
      );
      await _settle();

      expect(bloc.state.sounds.single.id, 'sound-1');
      expect(bloc.state.sounds.single.audio.duration, 4.5);
      expect(bloc.state.sounds.single.waveformSamples, [0.1, 0.8]);
    },
  );

  test(
    'failed optional probe leaves the saved record without an error',
    () async {
      probe.result = null;

      expect(await bloc.saveSound(_sound()), SavedSoundSaveResult.saved);
      await _settle();

      expect(bloc.state.sounds.single.id, 'sound-1');
      expect(bloc.state.unsavedSoundIds, isEmpty);
    },
  );

  test('autosaves normalized personal details', () async {
    await bloc.saveSound(_sound());
    bloc.add(
      const SavedSoundDetailsChanged(
        soundId: 'sound-1',
        label: '  Warm up  ',
        hashtags: ['#Practice', 'practice', ' Guitar '],
      ),
    );
    await _settle();

    final saved = service.loadSavedSounds().single;
    expect(saved.personalLabel, 'Warm up');
    expect(saved.personalHashtags, ['practice', 'guitar']);
  });

  test('query and selected hashtag filter private and source fields', () async {
    await service.saveSavedSound(
      SavedSound(
        audio: _sound(),
        personalLabel: 'Morning idea',
        personalHashtags: const ['practice'],
        catalogTags: const ['field recording'],
        waveformSamples: const [],
        sourceContext: const SavedSoundSourceContext(
          creatorName: 'Alice',
          description: 'Rain outside',
          transcript: 'soft guitar notes',
        ),
      ),
    );
    bloc.add(const SavedSoundsLoadRequested());
    await _settle();

    for (final query in [
      'morning',
      'rain guitar',
      'alice',
      'outside',
      'soft guitar',
      'practice',
      'field recording',
    ]) {
      bloc.add(SavedSoundsQueryChanged(query));
      await _settle();
      expect(bloc.state.visibleSounds, hasLength(1), reason: query);
    }
    bloc.add(const SavedSoundsHashtagSelected('missing'));
    await _settle();
    expect(bloc.state.visibleSounds, isEmpty);
    bloc.add(const SavedSoundsHashtagSelected('practice'));
    await _settle();
    expect(bloc.state.visibleSounds, hasLength(1));
  });

  test('removes a saved sound', () async {
    await bloc.saveSound(_sound());

    await bloc.removeSound('sound-1');
    await _settle();

    expect(bloc.state.sounds, isEmpty);
    expect(service.loadSavedSounds(), isEmpty);
  });

  test('keeps the row and reports the error when removal fails', () async {
    final failingBloc = SavedSoundsBloc(
      service: _FailingRemoveService(await SharedPreferences.getInstance()),
      mediaProbe: probe,
      syncRepositoryStream: const Stream.empty(),
      now: () => DateTime.utc(2026, 7, 31),
    );
    addTearDown(failingBloc.close);

    await failingBloc.saveSound(_sound());
    expect(failingBloc.state.sounds, hasLength(1));

    await expectLater(
      failingBloc.removeSound('sound-1'),
      throwsA(isA<StateError>()),
    );
    await _settle();

    expect(
      failingBloc.state.sounds,
      hasLength(1),
      reason: 'a delete that did not persist must not clear the row',
    );
  });

  group('missing local audio files', () {
    SavedSound localSound(String id, String path) => SavedSound(
      audio: AudioEvent(
        id: id,
        pubkey: 'creator',
        createdAt: 1,
        title: 'Imported $id',
        url: path,
      ),
      savedAt: DateTime.utc(2026, 7, 31),
      personalHashtags: const [],
      catalogTags: const [],
      waveformSamples: const [],
    );

    test('flags a saved sound whose file is gone from the device', () async {
      await service.saveSavedSound(localSound('gone', '/imports/gone.m4a'));
      await service.saveSavedSound(localSound('here', '/imports/here.m4a'));

      bloc = buildBloc(localFileExists: (path) => path.endsWith('here.m4a'));
      addTearDown(bloc.close);

      bloc.add(const SavedSoundsLoadRequested());
      await bloc.stream.firstWhere(
        (state) => state.status == SavedSoundsStatus.loaded,
      );

      expect(
        bloc.state.sounds.map((s) => s.audio.id),
        containsAll(<String>['gone', 'here']),
        reason:
            'A missing file must not drop the entry — the label, hashtags '
            'and source context the user wrote are still theirs (#8023).',
      );
      expect(bloc.state.missingFileSoundIds, equals({'gone'}));
      expect(
        bloc.state.isMissingFile(
          bloc.state.sounds.firstWhere((s) => s.audio.id == 'here'),
        ),
        isFalse,
      );
    });

    test('never flags a sound the library does not own the file for', () async {
      await service.saveSavedSound(
        SavedSound(
          audio: _sound(id: 'remote'),
          savedAt: DateTime.utc(2026, 7, 31),
          personalHashtags: const [],
          catalogTags: const [],
          waveformSamples: const [],
        ),
      );

      bloc = buildBloc(
        localFileExists: (_) =>
            fail('a network sound must not be probed on disk'),
      );
      addTearDown(bloc.close);

      bloc.add(const SavedSoundsLoadRequested());
      await bloc.stream.firstWhere(
        (state) => state.status == SavedSoundsStatus.loaded,
      );

      expect(bloc.state.sounds, hasLength(1));
      expect(bloc.state.missingFileSoundIds, isEmpty);
    });

    test('rescans when saving a sound reloads the library', () async {
      await service.saveSavedSound(localSound('gone', '/imports/gone.m4a'));

      // Present on load, deleted before the save reloads the library.
      var goneExists = true;
      bloc = buildBloc(
        localFileExists: (path) => goneExists || !path.endsWith('gone.m4a'),
      );
      addTearDown(bloc.close);

      bloc.add(const SavedSoundsLoadRequested());
      await bloc.stream.firstWhere(
        (state) => state.status == SavedSoundsStatus.loaded,
      );
      expect(bloc.state.missingFileSoundIds, isEmpty);

      goneExists = false;
      final completer = Completer<SavedSoundSaveResult>();
      bloc.add(
        SavedSoundSaveRequested(
          sound: _sound(id: 'new'),
          completer: completer,
        ),
      );
      await completer.future;
      await pumpEventQueue();

      expect(
        bloc.state.sounds.map((s) => s.audio.id),
        containsAll(<String>['gone', 'new']),
      );
      expect(
        bloc.state.missingFileSoundIds,
        equals({'gone'}),
        reason:
            'A set computed at load time describes a library that no longer '
            'exists once saving reloads it.',
      );
    });

    test('forgets a removed sound', () async {
      await service.saveSavedSound(localSound('gone', '/imports/gone.m4a'));

      bloc = buildBloc(localFileExists: (_) => false);
      addTearDown(bloc.close);

      bloc.add(const SavedSoundsLoadRequested());
      await bloc.stream.firstWhere(
        (state) => state.status == SavedSoundsStatus.loaded,
      );
      expect(bloc.state.missingFileSoundIds, equals({'gone'}));

      final completer = Completer<void>();
      bloc.add(
        SavedSoundRemoveRequested('gone', completer: completer),
      );
      await completer.future;
      await pumpEventQueue();

      expect(bloc.state.sounds, isEmpty);
      expect(bloc.state.missingFileSoundIds, isEmpty);
    });

    test('treats an unreadable path the same as an absent file', () async {
      await service.saveSavedSound(localSound('broken', '/imports/broken.m4a'));

      bloc = buildBloc(
        localFileExists: (_) => throw const FileSystemException('denied'),
      );
      addTearDown(bloc.close);

      bloc.add(const SavedSoundsLoadRequested());
      await bloc.stream.firstWhere(
        (state) => state.status == SavedSoundsStatus.loaded,
      );

      expect(bloc.state.missingFileSoundIds, equals({'broken'}));
    });
  });

  group('sync triggers', () {
    late _MockSoundSyncRepository syncRepository;

    setUp(() {
      syncRepository = _MockSoundSyncRepository();
      when(
        () => syncRepository.publishLocalChange(any()),
      ).thenAnswer((_) async {});
      when(
        () => syncRepository.publishLocalDeletion(any()),
      ).thenAnswer((_) async {});
    });

    test('publishes a change after a successful save', () async {
      final syncedBloc = await buildSyncedBloc(syncRepository);
      addTearDown(syncedBloc.close);

      await syncedBloc.saveSound(_sound(id: 'a' * 64));

      verify(() => syncRepository.publishLocalChange('a' * 64)).called(1);
    });

    test('publishes a tombstone after a successful removal', () async {
      final syncedBloc = await buildSyncedBloc(syncRepository);
      addTearDown(syncedBloc.close);
      await syncedBloc.saveSound(_sound(id: 'b' * 64));

      await syncedBloc.removeSound('b' * 64);

      verify(
        () => syncRepository.publishLocalDeletion('b' * 64),
      ).called(1);
    });

    test('a sync failure does not fail the local save', () async {
      when(
        () => syncRepository.publishLocalChange(any()),
      ).thenThrow(SyncIndexException('relay down'));
      final syncedBloc = await buildSyncedBloc(syncRepository);
      addTearDown(syncedBloc.close);

      await expectLater(
        syncedBloc.saveSound(_sound(id: 'c' * 64)),
        completes,
      );
      expect(service.loadSavedSounds(), hasLength(1));
    });

    test('saves normally when no sync repository is available', () async {
      final unsyncedBloc = buildBloc();
      addTearDown(unsyncedBloc.close);

      await unsyncedBloc.saveSound(_sound(id: 'd' * 64));

      expect(service.loadSavedSounds(), hasLength(1));
    });

    test(
      'publishes a change again after editing personal details',
      () async {
        final syncedBloc = await buildSyncedBloc(syncRepository);
        addTearDown(syncedBloc.close);
        await syncedBloc.saveSound(_sound(id: 'e' * 64));

        syncedBloc.add(
          SavedSoundDetailsChanged(
            soundId: 'e' * 64,
            label: 'Warm up',
            hashtags: const ['practice'],
          ),
        );
        await _settle();

        verify(
          () => syncRepository.publishLocalChange('e' * 64),
        ).called(2);
      },
    );

    test(
      'publishes a change again after waveform enrichment completes',
      () async {
        probe.result = const SavedSoundMediaResult(
          durationSeconds: 4.5,
          waveformSamples: [0.1, 0.8],
        );
        final syncedBloc = await buildSyncedBloc(syncRepository);
        addTearDown(syncedBloc.close);

        await syncedBloc.saveSound(_sound(id: 'f' * 64));
        await _settle();

        verify(
          () => syncRepository.publishLocalChange('f' * 64),
        ).called(2);
      },
    );

    test(
      'starts unsynced then picks up sync once the repository resolves '
      '(cold start)',
      () async {
        // Pins the #6480 re-pointing mechanism: soundSyncAvailabilityProvider
        // resolves asynchronously, well after this bloc is constructed at
        // app-shell scope, so a save issued before it resolves must not
        // publish, and a later save must — without recreating the bloc.
        final controller = StreamController<SoundSyncRepository?>();
        addTearDown(controller.close);
        final coldStartBloc = SavedSoundsBloc(
          service: service,
          mediaProbe: probe,
          syncRepositoryStream: controller.stream,
          now: () => DateTime.utc(2026, 7, 31),
        );
        addTearDown(coldStartBloc.close);

        await coldStartBloc.saveSound(_sound(id: 'g' * 64));
        verifyNever(() => syncRepository.publishLocalChange(any()));

        controller.add(syncRepository);
        await _settle();
        await coldStartBloc.saveSound(_sound(id: 'h' * 64));

        verify(() => syncRepository.publishLocalChange('h' * 64)).called(1);
      },
    );

    test(
      'an unexpected sync error does not fail the local save and is '
      'reported',
      () async {
        when(
          () => syncRepository.publishLocalChange(any()),
        ).thenThrow(StateError('signer refused'));
        final observer = _CapturingObserver();
        final priorObserver = Bloc.observer;
        Bloc.observer = observer;
        addTearDown(() => Bloc.observer = priorObserver);
        final syncedBloc = await buildSyncedBloc(syncRepository);
        addTearDown(syncedBloc.close);

        await expectLater(
          syncedBloc.saveSound(_sound(id: 'i' * 64)),
          completes,
        );

        expect(service.loadSavedSounds(), hasLength(1));
        expect(
          observer.errors,
          [isA<Reportable<Object>>()],
          reason:
              'an unexpected error (not the two typed sync exceptions) '
              'must still be wrapped and reported, not silently dropped',
        );
      },
    );

    test(
      'an unexpected sync error during removal does not hang removeSound()',
      () async {
        // Pins the specific worst case from the "mirror sits outside the
        // local-removal try" placement: before _mirror's catch-all, any
        // exception type it did not name escaped _remove entirely, so
        // event.completer was never completed and removeSound() awaited
        // forever. .timeout() turns a regression into a failure instead
        // of a hung test run.
        when(
          () => syncRepository.publishLocalDeletion(any()),
        ).thenThrow(StateError('signer refused'));
        final syncedBloc = await buildSyncedBloc(syncRepository);
        addTearDown(syncedBloc.close);
        await syncedBloc.saveSound(_sound(id: 'j' * 64));

        await expectLater(
          syncedBloc.removeSound('j' * 64).timeout(const Duration(seconds: 2)),
          completes,
        );
        expect(service.loadSavedSounds(), isEmpty);
      },
    );

    test(
      'a save completes without waiting on the relay publish',
      () async {
        // The publish is best-effort, so the sound must reach the library
        // while it is still in flight rather than after it settles.
        final publishing = Completer<void>();
        when(
          () => syncRepository.publishLocalChange(any()),
        ).thenAnswer((_) => publishing.future);
        final syncedBloc = await buildSyncedBloc(syncRepository);
        addTearDown(syncedBloc.close);

        await syncedBloc
            .saveSound(_sound(id: 'k' * 64))
            .timeout(const Duration(seconds: 2));

        expect(publishing.isCompleted, isFalse);
        expect(syncedBloc.state.sounds.single.id, 'k' * 64);
        publishing.complete();
      },
    );

    test(
      'a removal drops the row without waiting on the relay publish',
      () async {
        final publishing = Completer<void>();
        final syncedBloc = await buildSyncedBloc(syncRepository);
        addTearDown(syncedBloc.close);
        await syncedBloc.saveSound(_sound(id: 'l' * 64));
        when(
          () => syncRepository.publishLocalDeletion(any()),
        ).thenAnswer((_) => publishing.future);

        await syncedBloc
            .removeSound('l' * 64)
            .timeout(const Duration(seconds: 2));

        expect(publishing.isCompleted, isFalse);
        expect(syncedBloc.state.sounds, isEmpty);
        publishing.complete();
      },
    );
  });
}

/// Persists normally but fails every delete, standing in for a
/// `SharedPreferences` write that returns false.
class _FailingRemoveService extends SavedSoundsService {
  _FailingRemoveService(super._preferences);

  @override
  Future<void> removeSound(String soundId) async {
    throw StateError('Failed to persist saved sounds');
  }
}
