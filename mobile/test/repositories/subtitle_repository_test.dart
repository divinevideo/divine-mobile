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
import 'package:openvine/repositories/subtitle_repository.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/subtitle_fetcher.dart';
import 'package:openvine/services/subtitle_service.dart';
import 'package:openvine/services/video_event_publisher.dart';

class _MockBlossom extends Mock implements BlossomUploadService {}

class _MockPublisher extends Mock implements VideoEventPublisher {}

class _MockAuth extends Mock implements AuthService {}

class _MockNostrClient extends Mock implements NostrClient {}

class _MockHttpClient extends Mock implements http.Client {}

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
    late SubtitleRepository repo;

    setUp(() {
      blossom = _MockBlossom();
      publisher = _MockPublisher();
      auth = _MockAuth();
      httpClient = _MockHttpClient();
      repo = SubtitleRepository(
        blossomUploadService: blossom,
        videoEventPublisher: publisher,
        authService: auth,
        nostrClient: _MockNostrClient(),
        httpClient: httpClient,
        pollDelay: (_) async {},
      );
      when(() => auth.currentPublicKeyHex).thenReturn('pk1');
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

    test('uploads VTT, publishes 39307, republishes with both refs', () async {
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

      verify(
        () => publisher.republishWithSubtitles(
          existingEvent: _video,
          textTrackRef: 'https://media.divine.video/hash',
          extraTextTrackRefs: const ['39307:pk1:subtitles:my-vine-id'],
        ),
      ).called(1);
    });

    test('keeps the language the edited subtitles are tagged with', () async {
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
        video: _video.copyWith(textTrackLang: 'ja'),
        cues: _cues,
      );

      verify(
        () => publisher.publishSubtitleEvent(
          video: any(named: 'video'),
          vttContent: any(named: 'vttContent'),
          blossomUrl: any(named: 'blossomUrl'),
          lang: 'ja',
        ),
      ).called(1);
      verify(
        () => publisher.republishWithSubtitles(
          existingEvent: any(named: 'existingEvent'),
          textTrackRef: any(named: 'textTrackRef'),
          extraTextTrackRefs: any(named: 'extraTextTrackRefs'),
          textTrackLang: 'ja',
        ),
      ).called(1);
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

    test(
      'throws SubtitleEditException when subtitle event publish fails',
      () async {
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
        ).thenAnswer((_) async => null);

        expect(
          () => repo.publishEditedSubtitles(video: _video, cues: _cues),
          throwsA(isA<SubtitleEditException>()),
        );
      },
    );
  });
}
