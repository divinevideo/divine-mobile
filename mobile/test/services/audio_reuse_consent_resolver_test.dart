// ABOUTME: Tests fail-closed consent verification for legacy Kind 1063 audio.
// ABOUTME: Ensures only the source video, or a standalone sound's own signed
// ABOUTME: terms, can grant reuse.

import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/services/audio_reuse_consent_resolver.dart';
import 'package:videos_repository/videos_repository.dart';

class _MockVideosRepository extends Mock implements VideosRepository {}

class _MockNostrClient extends Mock implements NostrClient {}

class _MockFunnelcakeApiClient extends Mock implements FunnelcakeApiClient {}

class _FakeVideoEvent extends Fake implements VideoEvent {}

const _pubkey =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

const _sourceAddress = '34236:$_pubkey:source-video';
final String _sha256 = 'b' * 64;
final String _audioSha256 = 'c' * 64;

AudioEvent _sound({
  bool allowsReuse = false,
  bool hasExplicitReuseConsent = false,
  String? sourceVideoReference = _sourceAddress,
  String? sha256,
}) {
  return AudioEvent(
    id: 'audio-event',
    pubkey: _pubkey,
    createdAt: 100,
    sourceVideoReference: sourceVideoReference,
    sha256: sha256,
    allowsReuse: allowsReuse,
    hasExplicitReuseConsent: hasExplicitReuseConsent,
  );
}

VideoEvent _video({
  String id = 'video-event',
  String vineId = 'source-video',
  int createdAt = 101,
  String? reuseMarker = 'true',
  bool isVerifiedArchive = false,
}) {
  final rawTags = <String, String>{};
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
    isVerifiedArchive: isVerifiedArchive,
    archiveAudioReuseEnabled: isVerifiedArchive,
    sha256: _sha256,
  );
}

void main() {
  setUpAll(() => registerFallbackValue(_FakeVideoEvent()));

  late _MockVideosRepository videosRepository;
  late AudioReuseConsentResolver resolver;

  setUp(() {
    videosRepository = _MockVideosRepository();
    resolver = AudioReuseConsentResolver(videosRepository: videosRepository);
    when(
      () => videosRepository.refreshAudioReusePolicy(any()),
    ).thenAnswer((_) async => const AudioReusePolicy(allowAudioReuse: true));
  });

  void stubSource(List<VideoEvent> videos) {
    when(
      () => videosRepository.getVideosByAddressableIds([_sourceAddress]),
    ).thenAnswer((_) async => videos);
  }

  void stubPolicy({required bool allowAudioReuse}) {
    when(() => videosRepository.refreshAudioReusePolicy(any())).thenAnswer(
      (_) async => AudioReusePolicy(allowAudioReuse: allowAudioReuse),
    );
  }

  group('verify', () {
    test(
      'accepts explicit true after current-source and suppression checks',
      () async {
        stubSource([_video()]);
        expect(
          await resolver.verify(
            _sound(allowsReuse: true, sha256: _audioSha256),
          ),
          isTrue,
        );
        verify(
          () => videosRepository.getVideosByAddressableIds([_sourceAddress]),
        ).called(1);
        verify(() => videosRepository.refreshAudioReusePolicy(any())).called(1);
      },
    );

    test('suppression overrides explicit true', () async {
      stubSource([_video()]);
      when(
        () => videosRepository.refreshAudioReusePolicy(any()),
      ).thenAnswer((_) async => const AudioReusePolicy(allowAudioReuse: false));

      expect(
        await resolver.verify(_sound(allowsReuse: true, sha256: _audioSha256)),
        isFalse,
      );
    });

    test('honors the current server denial for an ordinary source', () async {
      stubSource([_video(reuseMarker: null)]);
      stubPolicy(allowAudioReuse: false);
      expect(await resolver.verify(_sound(allowsReuse: true)), isFalse);
      verify(() => videosRepository.refreshAudioReusePolicy(any())).called(1);
    });

    test('grants reuse from the source video the sound points at', () async {
      // Regression (#6769): the old reverse lookup asked which videos carry an
      // `['e', <audioEventId>, …, 'audio']` tag back to the sound. Legacy videos
      // predate that tag, so it returned nothing for exactly the sounds this
      // resolver exists to rescue and every one of them failed closed.
      stubSource([_video()]);

      expect(await resolver.verify(_sound()), isTrue);
    });

    test(
      'honours a current server revocation after a source revision',
      () async {
        stubSource([_video(createdAt: 120, reuseMarker: null)]);
        stubPolicy(allowAudioReuse: false);

        expect(await resolver.verify(_sound()), isFalse);
      },
    );

    test('allows a legacy source when the current policy allows it', () async {
      stubSource([_video(reuseMarker: null)]);

      expect(await resolver.verify(_sound()), isTrue);
    });

    test(
      'uses authoritative policy when a relay classic lacks archive flags',
      () async {
        stubSource([_video(reuseMarker: null)]);

        expect(await resolver.verify(_sound()), isTrue);
        verify(() => videosRepository.refreshAudioReusePolicy(any())).called(1);
      },
    );

    test(
      'allows a relay-parsed classic through the real repository pipeline',
      () async {
        final nostrClient = _MockNostrClient();
        final funnelcakeClient = _MockFunnelcakeApiClient();
        final relayEvent = Event.fromJson({
          'id': 'd' * 64,
          'pubkey': _pubkey,
          'created_at': 101,
          'kind': EventKind.videoVertical,
          'tags': [
            ['d', 'source-video'],
            ['url', 'https://cdn.example.com/video.mp4'],
          ],
          'content': '',
          'sig': '',
        });
        when(
          () => nostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [relayEvent]);
        when(() => funnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => funnelcakeClient.getBulkVideoStats(any()),
        ).thenAnswer((_) async => const BulkVideoStatsResponse(stats: {}));
        when(
          () => funnelcakeClient.refreshAudioReusePolicy(
            kind: EventKind.videoVertical,
            pubkey: _pubkey,
            dTag: 'source-video',
          ),
        ).thenAnswer(
          (_) async => const AudioReusePolicy(allowAudioReuse: true),
        );
        final realRepository = VideosRepository(
          nostrClient: nostrClient,
          funnelcakeApiClient: funnelcakeClient,
        );
        final realResolver = AudioReuseConsentResolver(
          videosRepository: realRepository,
        );

        expect(await realResolver.verify(_sound()), isTrue);
        verify(
          () => funnelcakeClient.refreshAudioReusePolicy(
            kind: EventKind.videoVertical,
            pubkey: _pubkey,
            dTag: 'source-video',
          ),
        ).called(1);
      },
    );

    test(
      'fails closed when the current policy denies an ordinary source',
      () async {
        stubSource([_video(reuseMarker: null)]);
        stubPolicy(allowAudioReuse: false);

        expect(await resolver.verify(_sound()), isFalse);
      },
    );

    test('ignores a video at a different address', () async {
      stubSource([_video(vineId: 'other-video')]);

      expect(await resolver.verify(_sound()), isFalse);
    });

    test('fails closed when the source video predates the sound', () async {
      stubSource([_video(createdAt: 99)]);

      expect(await resolver.verify(_sound()), isFalse);
    });

    group('without a source address', () {
      test('fails closed for a sound with no reuse terms', () async {
        expect(
          await resolver.verify(_sound(sourceVideoReference: null)),
          isFalse,
        );
        verifyNever(() => videosRepository.getVideosByAddressableIds(any()));
      });

      test('grants a standalone sound its explicit signed grant', () async {
        expect(
          await resolver.verify(
            _sound(
              allowsReuse: true,
              hasExplicitReuseConsent: true,
              sourceVideoReference: null,
            ),
          ),
          isTrue,
        );
        verifyNever(() => videosRepository.getVideosByAddressableIds(any()));
        verifyNever(() => videosRepository.refreshAudioReusePolicy(any()));
      });

      test('grants a published standalone Kind 1063 round trip', () async {
        final published = AudioEvent(
          id: '',
          pubkey: _pubkey,
          createdAt: 100,
          url: 'https://blossom.example/$_audioSha256.m4a',
          sha256: _audioSha256,
          title: 'Beat',
          creatorName: 'Creator',
        );
        final parsed = AudioEvent.fromNostrEvent(
          Event(_pubkey, audioEventKind, published.toTags(), 'Beat'),
        );

        expect(parsed.sourceVideoReference, isNull);
        expect(await resolver.verify(parsed), isTrue);
      });

      test("honors a standalone sound's explicit denial", () async {
        expect(
          await resolver.verify(
            _sound(hasExplicitReuseConsent: true, sourceVideoReference: null),
          ),
          isFalse,
        );
      });

      test('fails closed for a grant without a consent marker', () async {
        expect(
          await resolver.verify(
            _sound(allowsReuse: true, sourceVideoReference: null),
          ),
          isFalse,
        );
      });

      test('fails closed when the grant needs current verification', () async {
        final sound = _sound(
          allowsReuse: true,
          hasExplicitReuseConsent: true,
          sourceVideoReference: null,
        ).copyWith(requiresCurrentReuseVerification: true);

        expect(await resolver.verify(sound), isFalse);
      });
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

    test('fails closed when the policy lookup throws', () async {
      when(
        () => videosRepository.refreshAudioReusePolicy(any()),
      ).thenThrow(StateError('policy unavailable'));
      stubSource([_video()]);

      expect(await resolver.verify(_sound()), isFalse);
    });
  });
}
