// ABOUTME: Tests for SubtitleRepository: the orchestration layer that
// ABOUTME: uploads VTT to Blossom, publishes a 39307, and republishes the
// ABOUTME: video with both refs.

import 'dart:typed_data';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/repositories/subtitle_repository.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/subtitle_fetcher.dart';
import 'package:openvine/services/subtitle_service.dart';
import 'package:openvine/services/video_event_publisher.dart';
import 'package:videos_repository/videos_repository.dart'
    show
        LatestVideoRevisionAbsent,
        LatestVideoRevisionFound,
        LatestVideoRevisionUnknown,
        VideosRepository;

class _MockBlossom extends Mock implements BlossomUploadService {}

class _MockPublisher extends Mock implements VideoEventPublisher {}

class _MockAuth extends Mock implements AuthService {}

class _MockNostrClient extends Mock implements NostrClient {}

class _MockHttpClient extends Mock implements http.Client {}

class _MockVideosRepository extends Mock implements VideosRepository {}

final _video = VideoEvent(
  id: 'vid1',
  pubkey: 'pk1',
  createdAt: 1,
  content: '',
  timestamp: DateTime.fromMillisecondsSinceEpoch(0),
  vineId: 'my-vine-id',
);

final VideoEvent _updatedVideo = _video.copyWith(
  id: 'vid2',
  textTrackRef: 'https://media.divine.video/hash',
  textTrackRefs: const [
    'https://media.divine.video/hash',
    '39307:pk1:subtitles:my-vine-id',
  ],
);

const _cues = [SubtitleCue(start: 0, end: 1000, text: 'hi')];

void main() {
  setUpAll(() {
    registerFallbackValue(_video);
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(Uri.parse('https://media.divine.video/fallback.vtt'));
    registerFallbackValue(<String>[]);
  });

  group(SubtitleRepository, () {
    late _MockBlossom blossom;
    late _MockPublisher publisher;
    late _MockAuth auth;
    late _MockHttpClient httpClient;
    late _MockVideosRepository videos;
    late SubtitleRepository repo;

    setUp(() {
      blossom = _MockBlossom();
      publisher = _MockPublisher();
      auth = _MockAuth();
      httpClient = _MockHttpClient();
      videos = _MockVideosRepository();
      repo = SubtitleRepository(
        blossomUploadService: blossom,
        videoEventPublisher: publisher,
        videosRepository: videos,
        authService: auth,
        nostrClient: _MockNostrClient(),
        httpClient: httpClient,
        pollDelay: (_) async {},
      );
      when(() => auth.currentPublicKeyHex).thenReturn('pk1');
      when(() => videos.fetchLatestVideoRevision(any())).thenAnswer(
        (_) async => LatestVideoRevisionFound(
          // Event needs a hex key; the read matches the address, not this.
          Event('a' * 64, 34236, [
            ['d', 'my-vine-id'],
          ], ''),
        ),
      );
    });

    test('loadCues falls back to legacy singular textTrackRef', () async {
      when(() => httpClient.get(any())).thenAnswer(
        (_) async => http.Response(
          'WEBVTT\n\n00:00:00.000 --> 00:00:01.000\ncorrected\n',
          200,
        ),
      );

      final result = await repo.loadCues(
        VideoEvent(
          id: 'vid1',
          pubkey: 'pk1',
          createdAt: 1,
          content: '',
          timestamp: DateTime.fromMillisecondsSinceEpoch(0),
          textTrackRef: 'https://media.divine.video/fallback.vtt',
        ),
      );

      expect(result.status, SubtitleFetchStatus.available);
      expect(result.cues, hasLength(1));
      expect(result.cues.single.text, equals('corrected'));
    });

    test(
      'loadCues prefers refs over stale embedded textTrackContent',
      () async {
        when(() => httpClient.get(any())).thenAnswer(
          (_) async => http.Response(
            'WEBVTT\n\n00:00:00.000 --> 00:00:01.000\nedited\n',
            200,
          ),
        );

        final result = await repo.loadCues(
          VideoEvent(
            id: 'vid1',
            pubkey: 'pk1',
            createdAt: 1,
            content: '',
            timestamp: DateTime.fromMillisecondsSinceEpoch(0),
            textTrackRef: 'https://media.divine.video/edited.vtt',
            textTrackContent:
                'WEBVTT\n\n00:00:00.000 --> 00:00:01.000\nstale\n',
          ),
        );

        expect(result.cues, hasLength(1));
        expect(result.cues.single.text, equals('edited'));
      },
    );

    test(
      'loadCues reports empty when Blossom serves a cue-less track',
      () async {
        // media.divine.video answers 200 with a header-only VTT once
        // transcription has finished on a video with no speech. That is a
        // finished track, not one that is still being generated.
        when(
          () => httpClient.get(any()),
        ).thenAnswer((_) async => http.Response('WEBVTT\n\n', 200));

        final result = await repo.loadCues(
          VideoEvent(
            id: 'vid1',
            pubkey: 'pk1',
            createdAt: 1,
            content: '',
            timestamp: DateTime.fromMillisecondsSinceEpoch(0),
            sha256: 'abc123',
          ),
        );

        expect(result.status, SubtitleFetchStatus.empty);
        expect(result.cues, isEmpty);
      },
    );

    test('uploads VTT, republishes the video with both refs, then publishes '
        '39307', () async {
      when(
        () => blossom.uploadSubtitleVtt(bytes: any(named: 'bytes')),
      ).thenAnswer(
        (_) async => const BlossomUploadResult(
          success: true,
          url: 'https://media.divine.video/hash',
          videoId: 'hash',
        ),
      );
      when(
        () => publisher.publishSubtitleEvent(
          video: any(named: 'video'),
          vttContent: any(named: 'vttContent'),
          blossomUrl: any(named: 'blossomUrl'),
          lang: any(named: 'lang'),
        ),
      ).thenAnswer((_) async => '39307:pk1:subtitles:my-vine-id');
      when(
        () => publisher.republishWithSubtitles(
          existingEvent: any(named: 'existingEvent'),
          textTrackRef: any(named: 'textTrackRef'),
          extraTextTrackRefs: any(named: 'extraTextTrackRefs'),
          textTrackLang: any(named: 'textTrackLang'),
        ),
      ).thenAnswer((_) async => _updatedVideo);

      final updated = await repo.publishEditedSubtitles(
        video: _video,
        cues: _cues,
      );

      expect(updated, _updatedVideo);

      // The video names the subtitle event before it is replaced, so a video
      // republish that fails leaves the captions every revision serves alone.
      verifyInOrder([
        () => publisher.republishWithSubtitles(
          existingEvent: _video,
          textTrackRef: 'https://media.divine.video/hash',
          extraTextTrackRefs: const ['39307:pk1:subtitles:my-vine-id'],
        ),
        () => publisher.publishSubtitleEvent(
          video: _updatedVideo,
          vttContent: any(named: 'vttContent'),
          blossomUrl: 'https://media.divine.video/hash',
        ),
      ]);
    });

    test('keeps the region in the selected caption language when the copy '
        'in hand has no raw tags', () async {
      // A copy restored from a cache keeps only the base language.
      when(() => videos.fetchLatestVideoRevision(any())).thenAnswer(
        (_) async => LatestVideoRevisionFound(
          Event('a' * 64, 34236, [
            ['d', 'my-vine-id'],
            [
              'text-track',
              'https://media.divine.video/portuguese.vtt',
              '',
              'captions',
              'pt-BR',
            ],
          ], ''),
        ),
      );
      when(
        () => blossom.uploadSubtitleVtt(bytes: any(named: 'bytes')),
      ).thenAnswer(
        (_) async => const BlossomUploadResult(
          success: true,
          url: 'https://media.divine.video/hash',
          videoId: 'hash',
        ),
      );
      when(
        () => publisher.publishSubtitleEvent(
          video: any(named: 'video'),
          vttContent: any(named: 'vttContent'),
          blossomUrl: any(named: 'blossomUrl'),
          lang: any(named: 'lang'),
        ),
      ).thenAnswer((_) async => '39307:pk1:subtitles:my-vine-id');
      when(
        () => publisher.republishWithSubtitles(
          existingEvent: any(named: 'existingEvent'),
          textTrackRef: any(named: 'textTrackRef'),
          extraTextTrackRefs: any(named: 'extraTextTrackRefs'),
          textTrackLang: any(named: 'textTrackLang'),
        ),
      ).thenAnswer((_) async => _updatedVideo);

      await repo.publishEditedSubtitles(
        video: _video.copyWith(
          textTrackRef: 'https://media.divine.video/portuguese.vtt',
          textTrackLang: 'pt',
        ),
        cues: _cues,
      );

      verify(
        () => publisher.publishSubtitleEvent(
          video: any(named: 'video'),
          vttContent: any(named: 'vttContent'),
          blossomUrl: any(named: 'blossomUrl'),
          lang: 'pt-BR',
        ),
      ).called(1);
      verify(
        () => publisher.republishWithSubtitles(
          existingEvent: any(named: 'existingEvent'),
          textTrackRef: any(named: 'textTrackRef'),
          extraTextTrackRefs: any(named: 'extraTextTrackRefs'),
          textTrackLang: 'pt-BR',
        ),
      ).called(1);
    });

    group('edited caption language', () {
      const portuguese = 'https://media.divine.video/portuguese.vtt';
      List<String> track(String ref, String type, String language) => [
        'text-track',
        ref,
        '',
        type,
        language,
      ];
      final openedFromCache = _video.copyWith(
        textTrackRef: portuguese,
        textTrackLang: 'pt',
      );

      /// Saves from [video] while the newest revision carries [tracks], and
      /// returns the language the republish was given.
      Future<String?> savedLanguage(
        VideoEvent video,
        List<List<String>> tracks,
      ) async {
        when(() => videos.fetchLatestVideoRevision(any())).thenAnswer(
          (_) async => LatestVideoRevisionFound(
            Event('a' * 64, 34236, [
              ['d', 'my-vine-id'],
              ...tracks,
            ], ''),
          ),
        );
        when(
          () => blossom.uploadSubtitleVtt(bytes: any(named: 'bytes')),
        ).thenAnswer(
          (_) async => const BlossomUploadResult(
            success: true,
            url: 'https://media.divine.video/hash',
            videoId: 'hash',
          ),
        );
        when(
          () => publisher.republishWithSubtitles(
            existingEvent: any(named: 'existingEvent'),
            textTrackRef: any(named: 'textTrackRef'),
            extraTextTrackRefs: any(named: 'extraTextTrackRefs'),
            textTrackLang: any(named: 'textTrackLang'),
          ),
        ).thenAnswer((_) async => _updatedVideo);
        when(
          () => publisher.publishSubtitleEvent(
            video: any(named: 'video'),
            vttContent: any(named: 'vttContent'),
            blossomUrl: any(named: 'blossomUrl'),
            lang: any(named: 'lang'),
          ),
        ).thenAnswer((_) async => '39307:pk1:subtitles:my-vine-id');

        await repo.publishEditedSubtitles(video: video, cues: _cues);

        return verify(
              () => publisher.republishWithSubtitles(
                existingEvent: any(named: 'existingEvent'),
                textTrackRef: any(named: 'textTrackRef'),
                extraTextTrackRefs: any(named: 'extraTextTrackRefs'),
                textTrackLang: captureAny(named: 'textTrackLang'),
              ),
            ).captured.single
            as String?;
      }

      // A save whose subtitle event failed, or an edit on another device,
      // replaced the track the copy in hand names.
      test('takes the only caption track in the base language once the '
          'selected one was replaced', () async {
        expect(
          await savedLanguage(openedFromCache, [
            track(
              'https://media.divine.video/chapters.vtt',
              'chapters',
              'pt-PT',
            ),
            track(
              'https://media.divine.video/replacement.vtt',
              'captions',
              'pt-BR',
            ),
          ]),
          'pt-BR',
        );
      });

      test(
        "takes the opened copy's own language when its raw tags name it",
        () async {
          expect(
            await savedLanguage(
              openedFromCache.copyWith(
                nostrEventTags: [track(portuguese, 'captions', 'pt-PT')],
              ),
              [
                track(
                  'https://media.divine.video/brazil.vtt',
                  'captions',
                  'pt-BR',
                ),
                track(
                  'https://media.divine.video/portugal.vtt',
                  'captions',
                  'pt-PT',
                ),
              ],
            ),
            'pt-PT',
          );
        },
      );

      test(
        'keeps the base language when several caption tracks share it',
        () async {
          expect(
            await savedLanguage(openedFromCache, [
              track(
                'https://media.divine.video/brazil.vtt',
                'captions',
                'pt-BR',
              ),
              track(
                'https://media.divine.video/portugal.vtt',
                'captions',
                'pt-PT',
              ),
            ]),
            'pt',
          );
        },
      );

      test('keeps the base language when the selected track is still there '
          'without one', () async {
        const untagged = 'https://media.divine.video/untagged.vtt';
        expect(
          await savedLanguage(
            _video.copyWith(textTrackRef: untagged, textTrackLang: 'en'),
            [
              track(untagged, 'captions', ''),
              track(
                'https://media.divine.video/british.vtt',
                'subtitles',
                'en-GB',
              ),
            ],
          ),
          'en',
        );
      });
    });

    test('throws SubtitleEditException when vineId is null', () async {
      final noId = VideoEvent(
        id: 'v',
        pubkey: 'pk1',
        createdAt: 1,
        content: '',
        timestamp: DateTime.fromMillisecondsSinceEpoch(0),
      );
      expect(
        () => repo.publishEditedSubtitles(video: noId, cues: _cues),
        throwsA(isA<SubtitleEditException>()),
      );
    });

    test('throws SubtitleEditException when Blossom upload fails', () async {
      when(
        () => blossom.uploadSubtitleVtt(bytes: any(named: 'bytes')),
      ).thenAnswer(
        (_) async => const BlossomUploadResult(
          success: false,
          errorMessage: 'network error',
        ),
      );
      expect(
        () => repo.publishEditedSubtitles(video: _video, cues: _cues),
        throwsA(isA<SubtitleEditException>()),
      );
    });

    test('throws SubtitleEditException when not authenticated', () async {
      when(() => auth.currentPublicKeyHex).thenReturn(null);
      expect(
        () => repo.publishEditedSubtitles(video: _video, cues: _cues),
        throwsA(isA<SubtitleEditException>()),
      );
    });

    group('after the Blossom upload', () {
      setUp(() {
        when(
          () => blossom.uploadSubtitleVtt(bytes: any(named: 'bytes')),
        ).thenAnswer(
          (_) async => const BlossomUploadResult(
            success: true,
            url: 'https://media.divine.video/hash',
            videoId: 'hash',
          ),
        );
      });

      test('publishes no subtitle event when the video republish '
          'fails', () async {
        when(
          () => publisher.republishWithSubtitles(
            existingEvent: any(named: 'existingEvent'),
            textTrackRef: any(named: 'textTrackRef'),
            extraTextTrackRefs: any(named: 'extraTextTrackRefs'),
            textTrackLang: any(named: 'textTrackLang'),
          ),
        ).thenAnswer((_) async => null);

        await expectLater(
          repo.publishEditedSubtitles(video: _video, cues: _cues),
          throwsA(isA<SubtitleEditException>()),
        );

        verifyNever(
          () => publisher.publishSubtitleEvent(
            video: any(named: 'video'),
            vttContent: any(named: 'vttContent'),
            blossomUrl: any(named: 'blossomUrl'),
            lang: any(named: 'lang'),
          ),
        );
      });

      group('fails the save when the subtitle event', () {
        // Playback prefers the captions served from the subtitle event, so a
        // republish whose subtitle event did not land still shows the old
        // text. Saving again rebuilds both from the newest revision.
        setUp(() {
          when(
            () => publisher.republishWithSubtitles(
              existingEvent: any(named: 'existingEvent'),
              textTrackRef: any(named: 'textTrackRef'),
              extraTextTrackRefs: any(named: 'extraTextTrackRefs'),
              textTrackLang: any(named: 'textTrackLang'),
            ),
          ).thenAnswer((_) async => _updatedVideo);
        });

        test('is not published after the video republish', () async {
          when(
            () => publisher.publishSubtitleEvent(
              video: any(named: 'video'),
              vttContent: any(named: 'vttContent'),
              blossomUrl: any(named: 'blossomUrl'),
              lang: any(named: 'lang'),
            ),
          ).thenAnswer((_) async => null);

          await expectLater(
            repo.publishEditedSubtitles(video: _video, cues: _cues),
            throwsA(isA<SubtitleEditException>()),
          );
        });

        test('publish throws after the video republish', () async {
          when(
            () => publisher.publishSubtitleEvent(
              video: any(named: 'video'),
              vttContent: any(named: 'vttContent'),
              blossomUrl: any(named: 'blossomUrl'),
              lang: any(named: 'lang'),
            ),
          ).thenThrow(StateError('signer unavailable'));

          await expectLater(
            repo.publishEditedSubtitles(video: _video, cues: _cues),
            throwsA(isA<StateError>()),
          );
        });
      });
    });

    group('refuses before uploading anything', () {
      for (final (reason, revision) in [
        ('no relay answered in full', const LatestVideoRevisionUnknown()),
        ('no relay holds a revision', const LatestVideoRevisionAbsent()),
      ]) {
        test('when $reason', () async {
          when(
            () => videos.fetchLatestVideoRevision(any()),
          ).thenAnswer((_) async => revision);

          await expectLater(
            repo.publishEditedSubtitles(video: _video, cues: _cues),
            throwsA(isA<SubtitleEditException>()),
          );

          verify(
            () => videos.fetchLatestVideoRevision('34236:pk1:my-vine-id'),
          ).called(1);
          verifyNever(
            () => blossom.uploadSubtitleVtt(bytes: any(named: 'bytes')),
          );
          verifyNever(
            () => publisher.publishSubtitleEvent(
              video: any(named: 'video'),
              vttContent: any(named: 'vttContent'),
              blossomUrl: any(named: 'blossomUrl'),
              lang: any(named: 'lang'),
            ),
          );
        });
      }

      test("when the video is not the signed-in account's", () async {
        when(() => auth.currentPublicKeyHex).thenReturn('someone-else');

        await expectLater(
          repo.publishEditedSubtitles(video: _video, cues: _cues),
          throwsA(isA<SubtitleEditException>()),
        );

        verifyNever(() => videos.fetchLatestVideoRevision(any()));
        verifyNever(
          () => blossom.uploadSubtitleVtt(bytes: any(named: 'bytes')),
        );
      });
    });
  });
}
