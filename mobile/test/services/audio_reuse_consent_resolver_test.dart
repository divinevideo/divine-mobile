// ABOUTME: Tests fail-closed consent verification for legacy Kind 1063 audio.
// ABOUTME: Ensures only the sound's own source video can grant reuse.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/services/audio_reuse_consent_resolver.dart';
import 'package:videos_repository/videos_repository.dart';

class _MockVideosRepository extends Mock implements VideosRepository {}

const _pubkey =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

const _sourceAddress = '34236:$_pubkey:source-video';

AudioEvent _sound({
  bool allowsReuse = false,
  bool hasExplicitReuseConsent = false,
  String? sourceVideoReference = _sourceAddress,
}) {
  return AudioEvent(
    id: 'audio-event',
    pubkey: _pubkey,
    createdAt: 100,
    sourceVideoReference: sourceVideoReference,
    allowsReuse: allowsReuse,
    hasExplicitReuseConsent: hasExplicitReuseConsent,
  );
}

VideoEvent _video({
  String id = 'video-event',
  String vineId = 'source-video',
  int createdAt = 101,
  String? reuseMarker = 'true',
  bool isClassicVine = false,
}) {
  final rawTags = <String, String>{
    if (isClassicVine) 'platform': 'vine',
  };
  if (reuseMarker case final value?) {
    rawTags['allow_audio_reuse'] = value;
  }
  return VideoEvent(
    id: id,
    pubkey: _pubkey,
    createdAt: createdAt,
    content: '',
    timestamp: DateTime.fromMillisecondsSinceEpoch(
      createdAt * 1000,
      isUtc: true,
    ),
    vineId: vineId,
    addressableDTag: vineId,
    rawTags: rawTags,
  );
}

void main() {
  late _MockVideosRepository videosRepository;
  late AudioReuseConsentResolver resolver;

  setUp(() {
    videosRepository = _MockVideosRepository();
    resolver = AudioReuseConsentResolver(videosRepository: videosRepository);
  });

  void stubSource(List<VideoEvent> videos) {
    when(
      () => videosRepository.getVideosByAddressableIds([_sourceAddress]),
    ).thenAnswer((_) async => videos);
  }

  group('verify', () {
    test('accepts explicit true without a legacy lookup', () async {
      expect(await resolver.verify(_sound(allowsReuse: true)), isTrue);
      verifyNever(() => videosRepository.getVideosByAddressableIds(any()));
    });

    test('honors explicit false without a legacy lookup', () async {
      expect(
        await resolver.verify(_sound(hasExplicitReuseConsent: true)),
        isFalse,
      );
      verifyNever(() => videosRepository.getVideosByAddressableIds(any()));
    });

    test('grants reuse from the source video the sound points at', () async {
      // Regression (#6769): the old reverse lookup asked which videos carry an
      // `['e', <audioEventId>, …, 'audio']` tag back to the sound. Legacy videos
      // predate that tag, so it returned nothing for exactly the sounds this
      // resolver exists to rescue and every one of them failed closed.
      stubSource([_video()]);

      expect(await resolver.verify(_sound()), isTrue);
    });

    test('honours a revocation on the current revision', () async {
      stubSource([_video(createdAt: 120, reuseMarker: 'false')]);

      expect(await resolver.verify(_sound()), isFalse);
    });

    test('grants reuse for an unmarked classic Vine source', () async {
      stubSource([_video(reuseMarker: null, isClassicVine: true)]);

      expect(await resolver.verify(_sound()), isTrue);
    });

    test('fails closed for an unmarked ordinary source', () async {
      stubSource([_video(reuseMarker: null)]);

      expect(await resolver.verify(_sound()), isFalse);
    });

    test('honors an explicit decline on a classic Vine source', () async {
      stubSource([_video(reuseMarker: 'false', isClassicVine: true)]);

      expect(await resolver.verify(_sound()), isFalse);
    });

    test('ignores a video at a different address', () async {
      stubSource([_video(vineId: 'other-video')]);

      expect(await resolver.verify(_sound()), isFalse);
    });

    test('fails closed when the source video predates the sound', () async {
      stubSource([_video(createdAt: 99)]);

      expect(await resolver.verify(_sound()), isFalse);
    });

    test('fails closed without a source address', () async {
      expect(
        await resolver.verify(_sound(sourceVideoReference: null)),
        isFalse,
      );
      verifyNever(() => videosRepository.getVideosByAddressableIds(any()));
    });

    test('fails closed when the source video is unreachable', () async {
      stubSource(const []);

      expect(await resolver.verify(_sound()), isFalse);
    });

    test('fails closed when the lookup throws', () async {
      when(
        () => videosRepository.getVideosByAddressableIds([_sourceAddress]),
      ).thenThrow(StateError('relay unavailable'));

      expect(await resolver.verify(_sound()), isFalse);
    });
  });
}
