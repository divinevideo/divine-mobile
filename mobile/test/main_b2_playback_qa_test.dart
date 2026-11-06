import 'dart:async';

import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/main_b2_playback_qa.dart';

class _Player extends Mock implements DivineVideoPlayerController {}

void main() {
  const hash =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const raw = 'https://media.divine.video/$hash';
  group('private playback QA fixture', () {
    setUpAll(() => registerFallbackValue(const VideoClip.network(raw)));
    test('rejects missing, authenticated or unrelated originals', () {
      for (final url in [
        '',
        '$raw?token=private',
        'https://example.test/$hash',
      ]) {
        expect(() => b2QaInitialVideo(url), throwsArgumentError);
      }
    });
    test('keeps synthetic identity and the supplied original in memory', () {
      final video = b2QaInitialVideo(raw);
      expect(video.videoUrl, raw);
      expect(video.id, hasLength(64));
      expect(video.pubkey, hasLength(64));
    });
    test(
      'close waits for initialization before disposing the native player',
      () async {
        final player = _Player();
        final initialized = Completer<void>();
        when(player.initialize).thenAnswer((_) => initialized.future);
        when(player.dispose).thenAnswer((_) async {});
        final cubit = B2PlaybackQaCubit(
          initialVideo: b2QaInitialVideo(raw),
          controller: player,
        );
        final loading = cubit.load();
        final closing = cubit.close();
        await Future<void>.value();
        try {
          verifyNever(player.dispose);
        } finally {
          initialized.complete();
          await loading;
          await closing;
        }
        verify(player.dispose).called(1);
        verifyNever(() => player.setSource(any()));
      },
    );

    test(
      'loads the selected rendition through the real source loader',
      () async {
        final player = _Player();
        final opened = <VideoClip>[];
        when(player.initialize).thenAnswer((_) async {});
        when(() => player.setSource(any())).thenAnswer((invocation) async {
          opened.add(invocation.positionalArguments.single as VideoClip);
        });
        when(() => player.setLooping(looping: true)).thenAnswer((_) async {});
        when(player.play).thenAnswer((_) async {});
        when(player.dispose).thenAnswer((_) async {});
        final cubit = B2PlaybackQaCubit(
          initialVideo: b2QaInitialVideo(raw),
          controller: player,
          rendition: '$raw/720p.mp4',
        );
        addTearDown(cubit.close);
        await cubit.load();
        expect(opened.map((clip) => clip.uri), ['$raw/720p.mp4']);
        expect(cubit.state.source, '$raw/720p.mp4');
      },
    );
  });
}
