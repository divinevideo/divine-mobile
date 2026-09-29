// ABOUTME: Tests for StopMotionAudioPreview - stop-motion preview audio engine
// ABOUTME: Verifies window scheduling, scrub re-seek, pause, and disposal

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/services/video_editor/stop_motion_audio_preview.dart';
import 'package:sound_service/sound_service.dart';

class _MockAudioClipPlayer extends Mock implements AudioClipPlayer {}

void main() {
  setUpAll(() {
    registerFallbackValue(const AudioSourceConfig.file('/fallback.mp3'));
    registerFallbackValue(Duration.zero);
  });

  group(StopMotionAudioPreview, () {
    late List<_MockAudioClipPlayer> players;
    late StopMotionAudioPreview preview;

    _MockAudioClipPlayer newPlayer() {
      final player = _MockAudioClipPlayer();
      when(() => player.setClip(any())).thenAnswer((_) async {});
      when(() => player.setVolume(any())).thenAnswer((_) async {});
      when(() => player.seek(any())).thenAnswer((_) async {});
      when(player.play).thenAnswer((_) async {});
      when(player.pause).thenAnswer((_) async {});
      when(player.dispose).thenAnswer((_) async {});
      players.add(player);
      return player;
    }

    StopMotionAudioPreviewTrack track({
      String id = 'sound-1',
      Duration windowStart = Duration.zero,
      Duration windowEnd = const Duration(seconds: 2),
      double volume = 1,
      Duration fadeIn = Duration.zero,
      Duration fadeOut = Duration.zero,
    }) {
      return StopMotionAudioPreviewTrack(
        id: id,
        source: const AudioSourceConfig.file('/music.mp3'),
        windowStart: windowStart,
        windowEnd: windowEnd,
        volume: volume,
        fadeIn: fadeIn,
        fadeOut: fadeOut,
      );
    }

    setUp(() {
      players = [];
      preview = StopMotionAudioPreview(playerFactory: newPlayer);
    });

    tearDown(() async {
      await preview.dispose();
    });

    test('setTracks loads the clip and applies the track volume', () async {
      await preview.setTracks([track(volume: 0.4)]);

      expect(players, hasLength(1));
      verify(
        () =>
            players.single.setClip(const AudioSourceConfig.file('/music.mp3')),
      ).called(1);
      verify(() => players.single.setVolume(0.4)).called(1);
    });

    group('fade', () {
      test('ramps the volume through the fade in and out as the playhead '
          'moves', () async {
        await preview.setTracks([
          track(
            windowStart: const Duration(seconds: 1),
            windowEnd: const Duration(seconds: 5),
            volume: 0.8,
            fadeIn: const Duration(seconds: 1),
            fadeOut: const Duration(seconds: 2),
          ),
        ]);
        final player = players.single;
        clearInteractions(player);

        await preview.syncTo(const Duration(seconds: 1), isPlaying: true);
        await preview.syncTo(
          const Duration(milliseconds: 1500),
          isPlaying: true,
        );
        await preview.syncTo(
          const Duration(milliseconds: 2500),
          isPlaying: true,
        );
        await preview.syncTo(const Duration(seconds: 4), isPlaying: true);

        expect(
          verify(() => player.setVolume(captureAny())).captured,
          [0.0, 0.4, 0.8, 0.4],
        );
      });

      test('starts a sound inside its fade in at the faded level', () async {
        await preview.setTracks([
          track(
            windowEnd: const Duration(seconds: 4),
            fadeIn: const Duration(seconds: 2),
          ),
        ]);
        final player = players.single;
        clearInteractions(player);

        await preview.syncTo(const Duration(seconds: 1), isPlaying: true);

        verifyInOrder([() => player.setVolume(0.5), player.play]);
      });

      test('a sound without a fade keeps its volume', () async {
        await preview.setTracks([track(volume: 0.6)]);
        final player = players.single;
        clearInteractions(player);

        await preview.syncTo(
          const Duration(milliseconds: 500),
          isPlaying: true,
        );
        await preview.syncTo(const Duration(seconds: 1), isPlaying: true);

        verifyNever(() => player.setVolume(any()));
      });
    });

    test('starts a sound when the playhead enters its window', () async {
      await preview.setTracks([
        track(
          windowStart: const Duration(seconds: 1),
          windowEnd: const Duration(seconds: 3),
        ),
      ]);

      await preview.syncTo(const Duration(milliseconds: 500), isPlaying: true);
      verifyNever(players.single.play);

      await preview.syncTo(const Duration(milliseconds: 1500), isPlaying: true);
      verify(
        () => players.single.seek(const Duration(milliseconds: 500)),
      ).called(1);
      verify(players.single.play).called(1);
    });

    test('steady playback inside the window does not re-seek', () async {
      await preview.setTracks([track()]);

      await preview.syncTo(const Duration(milliseconds: 100), isPlaying: true);
      await preview.syncTo(const Duration(milliseconds: 117), isPlaying: true);
      await preview.syncTo(const Duration(milliseconds: 134), isPlaying: true);

      verify(() => players.single.seek(any())).called(1);
      verify(players.single.play).called(1);
    });

    test('pauses a sound when the playhead leaves its window', () async {
      await preview.setTracks([
        track(windowEnd: const Duration(seconds: 1)),
      ]);

      await preview.syncTo(const Duration(milliseconds: 500), isPlaying: true);
      await preview.syncTo(const Duration(milliseconds: 900), isPlaying: true);
      // 1.2s is past the 1s window end but within the jump threshold.
      await preview.syncTo(const Duration(milliseconds: 1200), isPlaying: true);

      verify(players.single.pause).called(1);
    });

    test('a backwards jump (loop wrap / scrub) re-seeks the sound', () async {
      await preview.setTracks([track()]);

      await preview.syncTo(const Duration(milliseconds: 1500), isPlaying: true);
      await preview.syncTo(const Duration(milliseconds: 100), isPlaying: true);

      verifyInOrder([
        () => players.single.seek(const Duration(milliseconds: 1500)),
        () => players.single.seek(const Duration(milliseconds: 100)),
      ]);
      verify(players.single.play).called(2);
    });

    test('a forward jump past the threshold re-seeks the sound', () async {
      await preview.setTracks([track(windowEnd: const Duration(seconds: 5))]);

      await preview.syncTo(const Duration(milliseconds: 100), isPlaying: true);
      await preview.syncTo(const Duration(seconds: 3), isPlaying: true);

      verify(() => players.single.seek(const Duration(seconds: 3))).called(1);
    });

    test('a short forward scrub re-seeks the sound', () async {
      await preview.setTracks([track(windowEnd: const Duration(seconds: 5))]);

      await preview.syncTo(const Duration(milliseconds: 100), isPlaying: true);
      // A 300ms forward scrub is under the jump threshold, so it is
      // indistinguishable from a run of normal ticks — only the explicit seek
      // flag separates them. Without it the sound plays on from 100ms.
      await preview.syncTo(
        const Duration(milliseconds: 400),
        isPlaying: true,
        isSeek: true,
      );

      verify(
        () => players.single.seek(const Duration(milliseconds: 400)),
      ).called(1);
    });

    test('syncTo with isPlaying false pauses an active sound', () async {
      await preview.setTracks([track()]);

      await preview.syncTo(const Duration(milliseconds: 500), isPlaying: true);
      await preview.syncTo(const Duration(milliseconds: 600), isPlaying: false);

      verify(players.single.pause).called(1);
    });

    test('pauseAll pauses only active sounds', () async {
      await preview.setTracks([
        track(id: 'a'),
        track(
          id: 'b',
          windowStart: const Duration(seconds: 5),
          windowEnd: const Duration(seconds: 6),
        ),
      ]);

      await preview.syncTo(const Duration(seconds: 1), isPlaying: true);
      await preview.pauseAll();

      verify(players[0].pause).called(1);
      verifyNever(players[1].pause);
    });

    test('setTracks disposes the previous generation of players', () async {
      await preview.setTracks([track(id: 'a')]);
      await preview.setTracks([track(id: 'b')]);

      expect(players, hasLength(2));
      verify(players[0].dispose).called(1);
      verifyNever(players[1].dispose);
    });

    test('a track whose clip fails to load is skipped and disposed', () async {
      final failing = _MockAudioClipPlayer();
      when(() => failing.setClip(any())).thenThrow(Exception('bad file'));
      when(failing.dispose).thenAnswer((_) async {});

      preview = StopMotionAudioPreview(playerFactory: () => failing);
      await preview.setTracks([track()]);

      verify(failing.dispose).called(1);
      // No crash on sync with the failed track skipped.
      await preview.syncTo(Duration.zero, isPlaying: true);
      verifyNever(failing.play);
    });

    test('dispose releases every player and ignores later syncs', () async {
      await preview.setTracks([track()]);
      await preview.dispose();

      verify(players.single.dispose).called(1);

      await preview.syncTo(const Duration(milliseconds: 500), isPlaying: true);
      verifyNever(players.single.play);
    });

    // Regression: syncTo used to iterate the live _tracks map across its
    // seek/pause awaits, so a setTracks() that cleared the map mid-iteration
    // (a sound edit during playback) threw ConcurrentModificationError. The
    // operations are now serialized, so setTracks waits for the in-flight sync.
    test(
      'setTracks during an in-flight syncTo does not throw '
      'ConcurrentModificationError',
      () async {
        final seekGate = Completer<void>();
        final gated = _MockAudioClipPlayer();
        when(() => gated.setClip(any())).thenAnswer((_) async {});
        when(() => gated.setVolume(any())).thenAnswer((_) async {});
        when(() => gated.seek(any())).thenAnswer((_) => seekGate.future);
        when(gated.play).thenAnswer((_) async {});
        when(gated.pause).thenAnswer((_) async {});
        when(gated.dispose).thenAnswer((_) async {});

        var served = false;
        preview = StopMotionAudioPreview(
          playerFactory: () {
            if (!served) {
              served = true;
              return gated;
            }
            return newPlayer();
          },
        );
        await preview.setTracks([track()]);

        // Suspends inside the gated seek.
        final syncing = preview.syncTo(
          const Duration(milliseconds: 100),
          isPlaying: true,
        );
        // Replaces the tracks while the sync is suspended — must not throw.
        final replacing = preview.setTracks([track(id: 'b')]);

        seekGate.complete();
        await syncing;
        await replacing;

        // The replacement generation disposed the gated player; no CME.
        verify(gated.dispose).called(1);
      },
    );

    // Regression: overlapping unawaited syncTo calls used to race on the shared
    // active/_lastPosition state. A call issued while another is in flight is
    // now dropped (the next frame re-syncs).
    test('drops a syncTo issued while another is in flight', () async {
      final seekGate = Completer<void>();
      final gated = _MockAudioClipPlayer();
      when(() => gated.setClip(any())).thenAnswer((_) async {});
      when(() => gated.setVolume(any())).thenAnswer((_) async {});
      when(() => gated.seek(any())).thenAnswer((_) => seekGate.future);
      when(gated.play).thenAnswer((_) async {});
      when(gated.pause).thenAnswer((_) async {});
      when(gated.dispose).thenAnswer((_) async {});

      preview = StopMotionAudioPreview(playerFactory: () => gated);
      await preview.setTracks([track()]);

      final first = preview.syncTo(
        const Duration(milliseconds: 100),
        isPlaying: true,
      );
      // Dropped: the first sync is still suspended in seek.
      await preview.syncTo(const Duration(milliseconds: 117), isPlaying: true);

      seekGate.complete();
      await first;

      verify(() => gated.seek(const Duration(milliseconds: 100))).called(1);
      verifyNever(() => gated.seek(const Duration(milliseconds: 117)));
    });

    // Regression: a scrub dropped because a sync was already in flight used to
    // lose its re-seek intent. The in-flight sync had already advanced
    // _lastPosition, so the next normal tick read as a sub-threshold forward
    // hop (steady playback) and never re-seeked — the sound played on from the
    // pre-scrub offset until the next window/loop boundary. The dropped scrub
    // is now remembered and forces the next admitted sync to re-seek.
    test('a scrub dropped mid-sync forces the next tick to re-seek', () async {
      final seekGate = Completer<void>();
      final gated = _MockAudioClipPlayer();
      when(() => gated.setClip(any())).thenAnswer((_) async {});
      when(() => gated.setVolume(any())).thenAnswer((_) async {});
      when(() => gated.seek(any())).thenAnswer((_) => seekGate.future);
      when(gated.play).thenAnswer((_) async {});
      when(gated.pause).thenAnswer((_) async {});
      when(gated.dispose).thenAnswer((_) async {});

      preview = StopMotionAudioPreview(playerFactory: () => gated);
      await preview.setTracks([track(windowEnd: const Duration(seconds: 5))]);

      // A sync suspends inside the gated seek, holding _syncInFlight and having
      // already advanced _lastPosition to 100ms.
      final first = preview.syncTo(
        const Duration(milliseconds: 100),
        isPlaying: true,
      );
      // Let that sync run up to (and suspend in) the seek await, so it is past
      // the point where it reads the pending-seek flag.
      await Future<void>.delayed(Duration.zero);

      // A scrub lands while the sync is in flight: dropped, but remembered.
      await preview.syncTo(
        const Duration(milliseconds: 400),
        isPlaying: true,
        isSeek: true,
      );

      seekGate.complete();
      await first;

      // A 317ms forward hop from _lastPosition is under the 500ms threshold, so
      // without the remembered scrub this tick would not re-seek.
      await preview.syncTo(const Duration(milliseconds: 417), isPlaying: true);

      verify(() => gated.seek(const Duration(milliseconds: 417))).called(1);
    });
  });
}
