// ABOUTME: Verifies saved-sound file checks never block the loading event.
// ABOUTME: Keeps device-local filesystem work off the app-shell UI isolate.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/saved_sounds/saved_sound_media_probe.dart';
import 'package:openvine/blocs/saved_sounds/saved_sounds_bloc.dart';
import 'package:openvine/models/saved_sound.dart';
import 'package:openvine/services/saved_sounds_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NoopMediaProbe implements SavedSoundMediaProbe {
  @override
  Future<SavedSoundMediaResult?> probe(AudioEvent sound) async => null;
}

void main() {
  group(SavedSoundsLoadRequested, () {
    test('checks local files on a background isolate by default', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final service = SavedSoundsService(preferences);
      await service.saveSavedSound(
        SavedSound(
          audio: AudioEvent(
            id: 'gone',
            pubkey: 'creator',
            createdAt: 1,
            title: 'Imported sound',
            url: '/imports/never-written.m4a',
          ),
          savedAt: DateTime.utc(2026, 9, 9),
          personalHashtags: const [],
          catalogTags: const [],
          waveformSamples: const [],
        ),
      );
      final bloc = SavedSoundsBloc(
        service: service,
        mediaProbe: _NoopMediaProbe(),
        syncRepositoryStream: const Stream.empty(),
      );
      addTearDown(bloc.close);

      bloc.add(const SavedSoundsLoadRequested());
      await bloc.stream.firstWhere(
        (state) => state.status == SavedSoundsStatus.loaded,
      );

      expect(bloc.state.missingFileSoundIds, equals({'gone'}));
    });

    test(
      'waits asynchronously while checking whether local files exist',
      () async {
        SharedPreferences.setMockInitialValues({});
        final preferences = await SharedPreferences.getInstance();
        final service = SavedSoundsService(preferences);
        await service.saveSavedSound(
          SavedSound(
            audio: AudioEvent(
              id: 'gone',
              pubkey: 'creator',
              createdAt: 1,
              title: 'Imported sound',
              url: '/imports/gone.m4a',
            ),
            savedAt: DateTime.utc(2026, 9, 9),
            personalHashtags: const [],
            catalogTags: const [],
            waveformSamples: const [],
          ),
        );
        final exists = Completer<bool>();
        final bloc = SavedSoundsBloc(
          service: service,
          mediaProbe: _NoopMediaProbe(),
          syncRepositoryStream: const Stream.empty(),
          localFileExists: (_) => exists.future,
        );
        addTearDown(bloc.close);

        bloc.add(const SavedSoundsLoadRequested());
        await pumpEventQueue();

        expect(bloc.state.status, SavedSoundsStatus.initial);

        exists.complete(false);
        await bloc.stream.firstWhere(
          (state) => state.status == SavedSoundsStatus.loaded,
        );

        expect(bloc.state.missingFileSoundIds, equals({'gone'}));
      },
    );
  });
}
