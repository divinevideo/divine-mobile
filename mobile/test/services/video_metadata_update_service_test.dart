// ABOUTME: Unit tests for VideoMetadataUpdateService.
// ABOUTME: Covers auth guard, video-URL guard, original-tag preservation,
// ABOUTME: edited-field replacement, replacement created_at, successful publish,
// ABOUTME: publish failure, and invite failure via inviteFailureCount.

import 'dart:io';
import 'dart:ui' show Locale;

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/auth_state.dart';
import 'package:openvine/models/content_label.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/models/video_metadata_update_error.dart';
import 'package:openvine/services/collaborator_invite_service.dart';
import 'package:openvine/services/personal_event_cache_service.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/services/video_metadata_update_service.dart';
import 'package:openvine/utils/nostr_key_utils.dart';

import '../helpers/test_provider_overrides.dart';

class _MockBlossomUploadService extends Mock implements BlossomUploadService {}

class _MockDmRepository extends Mock implements DmRepository {}

class _MockPersonalEventCacheService extends Mock
    implements PersonalEventCacheService {}

class _MockVideoEventService extends Mock implements VideoEventService {}

class _FakeEvent extends Fake implements Event {}

class _FakeVideoEvent extends Fake implements VideoEvent {}

const _ownerPubkey =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

VideoEvent _testVideo({
  List<List<String>> extraTags = const [],
  int? eventCreatedAt,
}) {
  return VideoEvent(
    id: 'event-id',
    pubkey: _ownerPubkey,
    createdAt: 1757385263,
    content: 'Test video content',
    timestamp: DateTime.fromMillisecondsSinceEpoch(1757385263 * 1000),
    videoUrl: 'https://cdn.example.com/video.mp4',
    title: 'Test Video Title',
    vineId: 'video-d-tag',
    eventCreatedAt: eventCreatedAt,
    nostrEventTags: [
      const ['imeta', 'url https://cdn.example.com/video.mp4', 'm video/mp4'],
      ...extraTags,
    ],
  );
}

void main() {
  late MockAuthService mockAuthService;
  late MockNostrClient mockNostrService;
  late _MockBlossomUploadService mockBlossomUploadService;
  late _MockDmRepository mockDmRepository;
  late _MockPersonalEventCacheService mockPersonalEventCacheService;
  late _MockVideoEventService mockVideoEventService;
  late VideoMetadataUpdateService service;
  late List<List<String>> capturedTags;
  late int capturedCreatedAt;

  setUpAll(() {
    registerFallbackValue(_FakeEvent());
    registerFallbackValue(_FakeVideoEvent());
    registerFallbackValue(File('/tmp/fallback-thumbnail.jpg'));
  });

  setUp(() {
    mockAuthService = createMockAuthService(
      authState: AuthState.authenticated,
      currentPublicKeyHex: _ownerPubkey,
    );
    mockNostrService = createMockNostrService();
    mockBlossomUploadService = _MockBlossomUploadService();
    mockDmRepository = _MockDmRepository();
    mockPersonalEventCacheService = _MockPersonalEventCacheService();
    mockVideoEventService = _MockVideoEventService();
    capturedTags = [];
    capturedCreatedAt = 0;

    late Event signedEvent;
    when(
      () => mockAuthService.createAndSignEvent(
        kind: any(named: 'kind'),
        content: any(named: 'content'),
        tags: any(named: 'tags'),
        createdAt: any(named: 'createdAt'),
      ),
    ).thenAnswer((invocation) async {
      capturedTags = List<List<String>>.from(
        invocation.namedArguments[#tags] as List<List<String>>,
      );
      capturedCreatedAt = invocation.namedArguments[#createdAt] as int? ?? 0;
      return signedEvent = Event(
        _ownerPubkey,
        NIP71VideoKinds.addressableShortVideo,
        capturedTags,
        invocation.namedArguments[#content] as String,
        createdAt: capturedCreatedAt,
      );
    });

    when(
      () => mockNostrService.publishEvent(any()),
    ).thenAnswer((_) async => PublishSuccess(event: signedEvent));

    when(
      () => mockPersonalEventCacheService.cacheUserEvent(any()),
    ).thenReturn(null);
    when(() => mockVideoEventService.updateVideoEvent(any())).thenReturn(null);

    service = VideoMetadataUpdateService(
      authService: mockAuthService,
      blossomService: mockBlossomUploadService,
      nostrService: mockNostrService,
      personalEventCache: mockPersonalEventCacheService,
      videoEventService: mockVideoEventService,
      collaboratorInviteService: CollaboratorInviteService(
        dmRepository: mockDmRepository,
        l10n: lookupAppLocalizations(const Locale('en')),
      ),
    );
  });

  group(VideoMetadataUpdateService, () {
    test('writes an explicit false audio-reuse marker', () async {
      final result = await service.updateVideo(
        originalVideo: _testVideo(),
        editorState: VideoEditorProviderState(),
        initialCollaboratorPubkeys: const {},
      );

      expect(result, isA<VideoUpdateSuccess>());
      expect(
        capturedTags,
        contains(equals(['allow_audio_reuse', 'false'])),
      );
    });

    group('auth guard', () {
      test('returns VideoUpdateFailure when not authenticated', () async {
        when(() => mockAuthService.isAuthenticated).thenReturn(false);
        when(
          () => mockAuthService.authState,
        ).thenReturn(AuthState.unauthenticated);

        final result = await service.updateVideo(
          originalVideo: _testVideo(),
          editorState: VideoEditorProviderState(),
          initialCollaboratorPubkeys: const {},
        );

        expect(
          result,
          isA<VideoUpdateFailure>().having(
            (f) => f.reason,
            'reason',
            VideoMetadataUpdateError.notAuthenticated,
          ),
        );
        verifyNever(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
            createdAt: any(named: 'createdAt'),
          ),
        );
      });
    });

    group('video URL guard', () {
      test(
        'returns VideoUpdateFailure when video has no HTTP URL in imeta tags',
        () async {
          final videoWithNoHttpUrl = VideoEvent(
            id: 'event-id',
            pubkey: _ownerPubkey,
            createdAt: 1757385263,
            content: 'Test',
            timestamp: DateTime.fromMillisecondsSinceEpoch(1757385263 * 1000),
            videoUrl: '',
            title: 'Test',
            vineId: 'video-d-tag',
            nostrEventTags: const [
              ['d', 'video-d-tag'],
            ],
          );

          final result = await service.updateVideo(
            originalVideo: videoWithNoHttpUrl,
            editorState: VideoEditorProviderState(),
            initialCollaboratorPubkeys: const {},
          );

          expect(
            result,
            isA<VideoUpdateFailure>().having(
              (f) => f.reason,
              'reason',
              VideoMetadataUpdateError.noPlayableVideoUrl,
            ),
          );
        },
      );
    });

    group('replacement created_at', () {
      test(
        'uses raw Nostr created_at instead of stable published_at',
        () async {
          const stablePublishedAt = 1757385263;
          const rawEventCreatedAt = 4102444800;
          final result = await service.updateVideo(
            originalVideo: _testVideo(eventCreatedAt: rawEventCreatedAt),
            editorState: VideoEditorProviderState(),
            initialCollaboratorPubkeys: const {},
          );

          expect(result, isA<VideoUpdateSuccess>());
          expect(capturedCreatedAt, equals(rawEventCreatedAt + 1));
          expect(capturedCreatedAt, isNot(equals(stablePublishedAt + 1)));
        },
      );

      test('keeps successive replacements strictly monotonic', () async {
        const rawEventCreatedAt = 4102444800;
        final firstResult = await service.updateVideo(
          originalVideo: _testVideo(eventCreatedAt: rawEventCreatedAt),
          editorState: VideoEditorProviderState(),
          initialCollaboratorPubkeys: const {},
        );

        final firstVideo = (firstResult as VideoUpdateSuccess).updatedEvent;
        final firstReplacementCreatedAt = firstVideo.nostrCreatedAt;
        final secondResult = await service.updateVideo(
          originalVideo: firstVideo,
          editorState: VideoEditorProviderState(),
          initialCollaboratorPubkeys: const {},
        );

        expect(secondResult, isA<VideoUpdateSuccess>());
        expect(firstReplacementCreatedAt, rawEventCreatedAt + 1);
        expect(capturedCreatedAt, firstReplacementCreatedAt + 1);
      });
    });

    group('engagement tag preservation', () {
      test(
        'preserves all five engagement count tags with exact values',
        () async {
          final video = _testVideo(
            extraTags: const [
              ['loops', '850000'],
              ['likes', '12000'],
              ['reposts', '3400'],
              ['views', '1000000'],
              ['comments', '4200'],
            ],
          );

          final result = await service.updateVideo(
            originalVideo: video,
            editorState: VideoEditorProviderState(),
            initialCollaboratorPubkeys: const {},
          );

          expect(result, isA<VideoUpdateSuccess>());
          expect(capturedTags, contains(equals(['loops', '850000'])));
          expect(capturedTags, contains(equals(['likes', '12000'])));
          expect(capturedTags, contains(equals(['reposts', '3400'])));
          expect(capturedTags, contains(equals(['views', '1000000'])));
          expect(capturedTags, contains(equals(['comments', '4200'])));
        },
      );

      test('does not include engagement tags when original has none', () async {
        final result = await service.updateVideo(
          originalVideo: _testVideo(),
          editorState: VideoEditorProviderState(),
          initialCollaboratorPubkeys: const {},
        );

        expect(result, isA<VideoUpdateSuccess>());
        final engagementTagNames = {
          'loops',
          'likes',
          'reposts',
          'views',
          'comments',
        };
        final engagementTags = capturedTags.where(
          (t) => t.isNotEmpty && engagementTagNames.contains(t.first),
        );
        expect(engagementTags, isEmpty);
      });
    });

    group('original tag preservation', () {
      const audioEventId =
          'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

      test(
        'preserves audio-attribution, provenance, expiration, and hint tags',
        () async {
          final video = _testVideo(
            extraTags: const [
              ['e', audioEventId, 'wss://relay.divine.video', 'audio'],
              ['expiration', '1799999999'],
              ['client', 'divine'],
              ['r', 'wss://relay.divine.video'],
              ['proofmode', 'proof-payload'],
              ['c2pa_manifest_id', 'manifest-123'],
            ],
          );

          final result = await service.updateVideo(
            originalVideo: video,
            editorState: VideoEditorProviderState(),
            initialCollaboratorPubkeys: const {},
          );

          expect(result, isA<VideoUpdateSuccess>());
          expect(
            capturedTags,
            contains(
              equals(['e', audioEventId, 'wss://relay.divine.video', 'audio']),
            ),
          );
          expect(capturedTags, contains(equals(['expiration', '1799999999'])));
          expect(capturedTags, contains(equals(['client', 'divine'])));
          expect(
            capturedTags,
            contains(equals(['r', 'wss://relay.divine.video'])),
          );
          expect(
            capturedTags,
            contains(equals(['proofmode', 'proof-payload'])),
          );
          expect(
            capturedTags,
            contains(equals(['c2pa_manifest_id', 'manifest-123'])),
          );
        },
      );

      test('preserves reply-threading tags and mention p-tags', () async {
        const rootEventId =
            'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
        const rootAuthorPubkey =
            'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
        const rootAddressableId = '34236:$rootAuthorPubkey:root-vid';
        final video = VideoEvent.fromNostrEvent(
          Event(
            _ownerPubkey,
            NIP71VideoKinds.addressableShortVideo,
            const [
              ['d', 'video-d-tag'],
              ['imeta', 'url https://cdn.example.com/video.mp4', 'm video/mp4'],
              ['A', rootAddressableId, ''],
              ['P', rootAuthorPubkey],
              ['k', '34236'],
              ['p', rootAuthorPubkey],
              ['a', rootAddressableId, ''],
              ['p', rootAuthorPubkey, 'wss://relay.divine.video', 'mention'],
              ['E', rootEventId, '', rootAuthorPubkey],
              ['K', '34236'],
              ['e', rootEventId, '', rootAuthorPubkey],
            ],
            'Reply video',
            createdAt: 1757385263,
          ),
        );

        expect(video.isVideoReply, isTrue);
        expect(video.inspiredByVideo, isNotNull);

        final result = await service.updateVideo(
          originalVideo: video,
          editorState: VideoEditorProviderState(
            inspiredByVideo: video.inspiredByVideo,
          ),
          initialCollaboratorPubkeys: const {},
        );

        expect(result, isA<VideoUpdateSuccess>());
        expect(
          capturedTags,
          contains(equals(['E', rootEventId, '', rootAuthorPubkey])),
        );
        expect(capturedTags, contains(equals(['K', '34236'])));
        expect(
          capturedTags,
          contains(equals(['e', rootEventId, '', rootAuthorPubkey])),
        );
        final addressableTags = capturedTags
            .where((tag) => tag.isNotEmpty && tag.first == 'a')
            .toList();
        expect(addressableTags, [
          ['a', rootAddressableId, ''],
        ]);
        expect(capturedTags, contains(equals(['A', rootAddressableId, ''])));
        expect(capturedTags, contains(equals(['P', rootAuthorPubkey])));
        expect(capturedTags, contains(equals(['p', rootAuthorPubkey])));
        expect(
          capturedTags,
          contains(
            equals([
              'p',
              rootAuthorPubkey,
              'wss://relay.divine.video',
              'mention',
            ]),
          ),
        );
      });

      test('preserves a genuine inspired-by a-tag on a reply instead of '
          'dropping it', () async {
        const rootEventId =
            'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
        const rootAuthorPubkey =
            'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
        const rootAddressableId = '34236:$rootAuthorPubkey:root-vid';
        const inspiringAuthorPubkey =
            '2222222222222222222222222222222222222222222222222222222222222222';
        const inspiringAddressableId =
            '34236:$inspiringAuthorPubkey:inspiring-vid';
        final video = VideoEvent.fromNostrEvent(
          Event(
            _ownerPubkey,
            NIP71VideoKinds.addressableShortVideo,
            const [
              ['d', 'video-d-tag'],
              ['imeta', 'url https://cdn.example.com/video.mp4', 'm video/mp4'],
              ['A', rootAddressableId, ''],
              ['K', '34236'],
              ['E', rootEventId, '', rootAuthorPubkey],
              ['a', rootAddressableId, ''],
              // A genuine inspired-by reference that co-exists with the
              // reply threading tags.
              [
                'a',
                inspiringAddressableId,
                'wss://relay.divine.video',
                'mention',
              ],
            ],
            'Reply video that is also inspired by another',
            createdAt: 1757385263,
          ),
        );

        expect(video.isVideoReply, isTrue);

        final result = await service.updateVideo(
          originalVideo: video,
          editorState: VideoEditorProviderState(
            inspiredByVideo: video.inspiredByVideo,
          ),
          initialCollaboratorPubkeys: const {},
        );

        expect(result, isA<VideoUpdateSuccess>());
        // The genuine inspired-by tag survives verbatim.
        expect(
          capturedTags,
          contains(
            equals([
              'a',
              inspiringAddressableId,
              'wss://relay.divine.video',
              'mention',
            ]),
          ),
        );
        // The reply-parent a-tag survives.
        expect(capturedTags, contains(equals(['a', rootAddressableId, ''])));
        // No parent reference is turned into 'inspired-by' attribution.
        expect(
          capturedTags.where(
            (tag) =>
                tag.length >= 4 && tag.first == 'a' && tag[3] == 'inspired-by',
          ),
          isEmpty,
        );
      });

      test('removes collaborator tags with mixed-case markers', () async {
        const removedCollaborator =
            'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';
        final video = _testVideo(
          extraTags: const [
            [
              'p',
              removedCollaborator,
              'wss://relay.divine.video',
              'Collaborator',
            ],
          ],
        );

        final result = await service.updateVideo(
          originalVideo: video,
          editorState: VideoEditorProviderState(),
          initialCollaboratorPubkeys: const {removedCollaborator},
        );

        expect(result, isA<VideoUpdateSuccess>());
        expect(
          capturedTags,
          isNot(
            contains(
              equals([
                'p',
                removedCollaborator,
                'wss://relay.divine.video',
                'Collaborator',
              ]),
            ),
          ),
        );
        expect(
          capturedTags.where(
            (tag) =>
                tag.length >= 2 &&
                tag.first == 'p' &&
                tag[1] == removedCollaborator,
          ),
          isEmpty,
        );
      });

      test(
        'does not duplicate the d tag when the original carries one',
        () async {
          final video = _testVideo(
            extraTags: const [
              ['d', 'video-d-tag'],
            ],
          );

          final result = await service.updateVideo(
            originalVideo: video,
            editorState: VideoEditorProviderState(),
            initialCollaboratorPubkeys: const {},
          );

          expect(result, isA<VideoUpdateSuccess>());
          final dTags = capturedTags.where(
            (t) => t.isNotEmpty && t.first == 'd',
          );
          expect(dTags, hasLength(1));
          expect(capturedTags, contains(equals(['d', 'video-d-tag'])));
        },
      );

      test('recovers preserved tags from the personal cache when '
          'nostrEventTags is empty', () async {
        final cachedEvent = Event(
          _ownerPubkey,
          NIP71VideoKinds.addressableShortVideo,
          const [
            ['d', 'video-d-tag'],
            ['imeta', 'url https://cdn.example.com/video.mp4', 'm video/mp4'],
            ['e', audioEventId, 'wss://relay.divine.video', 'audio'],
            ['expiration', '1799999999'],
          ],
          'Test video content',
        );
        // A VideoEvent rehydrated from a JSON cache has empty
        // nostrEventTags; the raw event still lives in the personal cache.
        final video = VideoEvent(
          id: 'event-id',
          pubkey: _ownerPubkey,
          createdAt: 1757385263,
          content: 'Test video content',
          timestamp: DateTime.fromMillisecondsSinceEpoch(1757385263 * 1000),
          videoUrl: 'https://cdn.example.com/video.mp4',
          title: 'Test Video Title',
          vineId: 'video-d-tag',
        );
        when(
          () => mockPersonalEventCacheService.getEventById('event-id'),
        ).thenReturn(cachedEvent);

        final result = await service.updateVideo(
          originalVideo: video,
          editorState: VideoEditorProviderState(),
          initialCollaboratorPubkeys: const {},
        );

        expect(result, isA<VideoUpdateSuccess>());
        expect(
          capturedTags,
          contains(
            equals(['e', audioEventId, 'wss://relay.divine.video', 'audio']),
          ),
        );
        expect(capturedTags, contains(equals(['expiration', '1799999999'])));
      });

      test(
        'refuses to publish when original raw tags are unavailable',
        () async {
          final video = VideoEvent(
            id: 'uncached-event-id',
            pubkey: _ownerPubkey,
            createdAt: 1757385263,
            content: 'Test video content',
            timestamp: DateTime.fromMillisecondsSinceEpoch(1757385263 * 1000),
            videoUrl: 'https://cdn.example.com/video.mp4',
            title: 'Test Video Title',
            vineId: 'video-d-tag',
          );
          when(
            () =>
                mockPersonalEventCacheService.getEventById('uncached-event-id'),
          ).thenReturn(null);

          final result = await service.updateVideo(
            originalVideo: video,
            editorState: VideoEditorProviderState(),
            initialCollaboratorPubkeys: const {},
            newThumbnailFile: File('/tmp/unused-thumbnail.jpg'),
          );

          expect(result, isA<VideoUpdateOriginalUnavailable>());
          verifyNever(
            () => mockBlossomUploadService.uploadImage(
              imageFile: any(named: 'imageFile'),
              nostrPubkey: any(named: 'nostrPubkey'),
            ),
          );
          verifyNever(
            () => mockAuthService.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
              createdAt: any(named: 'createdAt'),
            ),
          );
          verifyNever(() => mockNostrService.publishEvent(any()));
        },
      );

      test(
        'REST-sourced edit preserves hashtags and provenance tags',
        () async {
          final video = VideoStats.fromJson(const {
            'event': {
              'id': 'rest-event-id',
              'pubkey': _ownerPubkey,
              'created_at': 1757385263,
              'kind': 34236,
              'content': 'Test video content',
              'tags': [
                ['d', 'video-d-tag'],
                [
                  'imeta',
                  'url https://cdn.example.com/video.mp4',
                  'm video/mp4',
                  'size 480000',
                ],
                ['t', 'first'],
                ['t', 'second'],
                ['alt', 'Accessible description'],
                ['duration', '6'],
                ['proofmode', 'proof-manifest'],
                ['c2pa_manifest_id', 'urn:c2pa:test'],
                ['verification', 'verified_mobile'],
                ['device_attestation', 'attestation'],
                ['text-track', '39307:author:subtitles:video-d-tag'],
              ],
            },
            'stats': {
              'reactions': 0,
              'comments': 0,
              'reposts': 0,
              'engagement_score': 0,
            },
          }).toVideoEvent();

          final result = await service.updateVideo(
            originalVideo: video,
            editorState: VideoEditorProviderState(
              title: video.title ?? '',
              description: video.content,
              tags: video.hashtags.toSet(),
            ),
            initialCollaboratorPubkeys: const {},
          );

          expect(result, isA<VideoUpdateSuccess>());
          for (final tag in const [
            ['t', 'first'],
            ['t', 'second'],
            ['alt', 'Accessible description'],
            ['duration', '6'],
            ['proofmode', 'proof-manifest'],
            ['c2pa_manifest_id', 'urn:c2pa:test'],
            ['verification', 'verified_mobile'],
            ['device_attestation', 'attestation'],
            ['text-track', '39307:author:subtitles:video-d-tag'],
          ]) {
            expect(capturedTags, contains(equals(tag)));
          }
          expect(
            capturedTags.singleWhere((tag) => tag.first == 'imeta'),
            contains('size 480000'),
          );
        },
      );
    });

    group('edited field replacement', () {
      test(
        'replaces title, summary, and hashtags without duplicates',
        () async {
          final video = _testVideo(
            extraTags: const [
              ['title', 'Old Title'],
              ['summary', 'Old description'],
              ['t', 'oldtag'],
            ],
          );
          final editorState = VideoEditorProviderState(
            title: 'New Title',
            description: 'New description',
            tags: const {'newtag'},
          );

          final result = await service.updateVideo(
            originalVideo: video,
            editorState: editorState,
            initialCollaboratorPubkeys: const {},
          );

          expect(result, isA<VideoUpdateSuccess>());
          expect(capturedTags, contains(equals(['title', 'New Title'])));
          expect(capturedTags, isNot(contains(equals(['title', 'Old Title']))));
          expect(
            capturedTags,
            contains(equals(['summary', 'New description'])),
          );
          expect(
            capturedTags,
            isNot(contains(equals(['summary', 'Old description']))),
          );
          expect(capturedTags, contains(equals(['t', 'newtag'])));
          expect(capturedTags, isNot(contains(equals(['t', 'oldtag']))));
        },
      );

      test('allows the user to clear hashtags from a complete event', () async {
        final video = _testVideo(
          extraTags: const [
            ['t', 'oldtag'],
            ['proofmode', 'proof-manifest'],
          ],
        );

        final result = await service.updateVideo(
          originalVideo: video,
          editorState: VideoEditorProviderState(),
          initialCollaboratorPubkeys: const {},
        );

        expect(result, isA<VideoUpdateSuccess>());
        expect(capturedTags.where((tag) => tag.first == 't'), isEmpty);
        expect(
          capturedTags,
          contains(equals(['proofmode', 'proof-manifest'])),
        );
      });

      test(
        'removes the content-warning group when warnings are cleared',
        () async {
          final video = _testVideo(
            extraTags: const [
              ['content-warning', 'nudity'],
              ['L', 'content-warning'],
              ['l', 'nudity', 'content-warning'],
              ['L', 'ISO-639-1'],
              ['l', 'en', 'ISO-639-1'],
            ],
          );

          final result = await service.updateVideo(
            originalVideo: video,
            editorState: VideoEditorProviderState(),
            initialCollaboratorPubkeys: const {},
          );

          expect(result, isA<VideoUpdateSuccess>());
          final warningTags = capturedTags.where(
            (t) => t.isNotEmpty && t.first == 'content-warning',
          );
          expect(warningTags, isEmpty);
          expect(
            capturedTags,
            isNot(contains(equals(['L', 'content-warning']))),
          );
          expect(
            capturedTags,
            isNot(contains(equals(['l', 'nudity', 'content-warning']))),
          );
          expect(capturedTags, contains(equals(['L', 'ISO-639-1'])));
          expect(capturedTags, contains(equals(['l', 'en', 'ISO-639-1'])));
        },
      );

      test('rewrites the full NIP-36 group when warnings change', () async {
        final video = _testVideo(
          extraTags: const [
            ['content-warning', 'nudity'],
            ['L', 'content-warning'],
            ['l', 'nudity', 'content-warning'],
          ],
        );
        final editorState = VideoEditorProviderState(
          contentWarnings: const {ContentLabel.violence},
        );

        final result = await service.updateVideo(
          originalVideo: video,
          editorState: editorState,
          initialCollaboratorPubkeys: const {},
        );

        expect(result, isA<VideoUpdateSuccess>());
        expect(capturedTags, contains(equals(['content-warning', 'violence'])));
        expect(capturedTags, contains(equals(['L', 'content-warning'])));
        expect(
          capturedTags,
          contains(equals(['l', 'violence', 'content-warning'])),
        );
        expect(
          capturedTags,
          isNot(contains(equals(['content-warning', 'nudity']))),
        );
        expect(
          capturedTags,
          isNot(contains(equals(['l', 'nudity', 'content-warning']))),
        );
      });

      test('replaces collaborator p-tags but keeps mention p-tags', () async {
        const removedCollaborator =
            'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';
        const mentionedPubkey =
            '1111111111111111111111111111111111111111111111111111111111111111';
        final video = _testVideo(
          extraTags: const [
            [
              'p',
              removedCollaborator,
              'wss://relay.divine.video',
              'collaborator',
            ],
            ['p', mentionedPubkey, 'wss://relay.divine.video', 'mention'],
          ],
        );

        final result = await service.updateVideo(
          originalVideo: video,
          editorState: VideoEditorProviderState(),
          initialCollaboratorPubkeys: const {removedCollaborator},
        );

        expect(result, isA<VideoUpdateSuccess>());
        expect(
          capturedTags,
          isNot(
            contains(
              equals([
                'p',
                removedCollaborator,
                'wss://relay.divine.video',
                'collaborator',
              ]),
            ),
          ),
        );
        expect(
          capturedTags,
          contains(
            equals([
              'p',
              mentionedPubkey,
              'wss://relay.divine.video',
              'mention',
            ]),
          ),
        );
      });

      test(
        'canonicalizes collaborator tags and invite recipients',
        () async {
          const collaborator =
              'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
          when(
            () => mockDmRepository.sendMessage(
              recipientPubkey: any(named: 'recipientPubkey'),
              content: any(named: 'content'),
              additionalTags: any(named: 'additionalTags'),
              skipNip04Fallback: any(named: 'skipNip04Fallback'),
            ),
          ).thenAnswer(
            (_) async => NIP17SendResult.success(
              rumorEventId: 'rumor-id',
              messageEventId: 'invite-id',
              recipientPubkey: collaborator,
            ),
          );

          final result = await service.updateVideo(
            originalVideo: _testVideo(),
            editorState: VideoEditorProviderState(
              collaboratorPubkeys: {
                collaborator.toUpperCase(),
                NostrKeyUtils.encodePubKey(collaborator),
                NostrKeyUtils.encodePubKey(_ownerPubkey),
                'not-a-pubkey',
              },
            ),
            initialCollaboratorPubkeys: const {},
          );

          expect(result, isA<VideoUpdateSuccess>());
          final collaboratorTags = capturedTags
              .where((tag) => tag.length >= 4 && tag[3] == 'collaborator')
              .toList();
          expect(
            collaboratorTags,
            [
              [
                'p',
                collaborator,
                'wss://relay.divine.video',
                'collaborator',
              ],
            ],
          );
          verify(
            () => mockDmRepository.sendMessage(
              recipientPubkey: collaborator,
              content: any(named: 'content'),
              additionalTags: any(named: 'additionalTags'),
              skipNip04Fallback: true,
            ),
          ).called(1);
        },
      );

      test('compares existing collaborators in canonical form', () async {
        const collaborator =
            'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

        final result = await service.updateVideo(
          originalVideo: _testVideo(),
          editorState: VideoEditorProviderState(
            collaboratorPubkeys: {collaborator.toUpperCase()},
          ),
          initialCollaboratorPubkeys: {
            NostrKeyUtils.encodePubKey(collaborator),
          },
        );

        expect(result, isA<VideoUpdateSuccess>());
        verifyNever(
          () => mockDmRepository.sendMessage(
            recipientPubkey: any(named: 'recipientPubkey'),
            content: any(named: 'content'),
            additionalTags: any(named: 'additionalTags'),
            skipNip04Fallback: any(named: 'skipNip04Fallback'),
          ),
        );
      });

      test('replaces the inspired-by a-tag without duplicating it', () async {
        final video = _testVideo(
          extraTags: const [
            [
              'a',
              '34236:$_ownerPubkey:old-vid',
              'wss://relay.divine.video',
              'mention',
            ],
          ],
        );
        final editorState = VideoEditorProviderState(
          inspiredByVideo: const InspiredByInfo(
            addressableId: '34236:$_ownerPubkey:new-vid',
            relayUrl: 'wss://relay.divine.video',
          ),
        );

        final result = await service.updateVideo(
          originalVideo: video,
          editorState: editorState,
          initialCollaboratorPubkeys: const {},
        );

        expect(result, isA<VideoUpdateSuccess>());
        expect(
          capturedTags,
          contains(
            equals([
              'a',
              '34236:$_ownerPubkey:new-vid',
              'wss://relay.divine.video',
              'inspired-by',
            ]),
          ),
        );
        expect(
          capturedTags,
          isNot(
            contains(
              equals([
                'a',
                '34236:$_ownerPubkey:old-vid',
                'wss://relay.divine.video',
                'mention',
              ]),
            ),
          ),
        );
      });

      test(
        'preserves clip-source tags when manual inspired-by is cleared',
        () async {
          const sourceCreator =
              'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
          const sourceAddressableId = '34236:$sourceCreator:source-vid';
          final video = _testVideo(
            extraTags: const [
              ['a', sourceAddressableId, 'wss://source.relay', 'mention'],
              [
                'a',
                sourceAddressableId,
                'wss://source.relay',
                clipSourceCreditTagMarker,
              ],
              ['p', sourceCreator, 'wss://source.relay', 'inspired-by'],
            ],
          );

          final result = await service.updateVideo(
            originalVideo: video,
            editorState: VideoEditorProviderState(),
            initialCollaboratorPubkeys: const {},
          );

          expect(result, isA<VideoUpdateSuccess>());
          expect(
            capturedTags,
            isNot(
              contains(
                equals([
                  'a',
                  sourceAddressableId,
                  'wss://source.relay',
                  'mention',
                ]),
              ),
            ),
          );
          expect(
            capturedTags,
            contains(
              equals([
                'a',
                sourceAddressableId,
                'wss://source.relay',
                clipSourceCreditTagMarker,
              ]),
            ),
          );
          expect(
            capturedTags,
            isNot(
              contains(
                equals([
                  'p',
                  sourceCreator,
                  'wss://source.relay',
                  'inspired-by',
                ]),
              ),
            ),
          );
          expect(
            capturedTags,
            contains(
              equals([
                'p',
                sourceCreator,
                'wss://source.relay',
                clipSourceCreditTagMarker,
              ]),
            ),
          );
        },
      );

      test(
        'preserves multiple clip-source credits when editing metadata',
        () async {
          const sourceCreatorA =
              'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
          const sourceCreatorB =
              'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
          const sourceAddressableIdA = '34236:$sourceCreatorA:source-a';
          const sourceAddressableIdB = '34236:$sourceCreatorB:source-b';
          final video = _testVideo(
            extraTags: const [
              [
                'a',
                sourceAddressableIdA,
                'wss://source-a.relay',
                clipSourceCreditTagMarker,
              ],
              [
                'a',
                sourceAddressableIdB,
                'wss://source-b.relay',
                clipSourceCreditTagMarker,
              ],
            ],
          );

          final result = await service.updateVideo(
            originalVideo: video,
            editorState: VideoEditorProviderState(title: 'Updated title'),
            initialCollaboratorPubkeys: const {},
          );

          expect(result, isA<VideoUpdateSuccess>());
          expect(
            capturedTags,
            contains(
              equals([
                'a',
                sourceAddressableIdA,
                'wss://source-a.relay',
                clipSourceCreditTagMarker,
              ]),
            ),
          );
          expect(
            capturedTags,
            contains(
              equals([
                'a',
                sourceAddressableIdB,
                'wss://source-b.relay',
                clipSourceCreditTagMarker,
              ]),
            ),
          );
          expect(
            capturedTags,
            contains(
              equals([
                'p',
                sourceCreatorA,
                'wss://source-a.relay',
                clipSourceCreditTagMarker,
              ]),
            ),
          );
          expect(
            capturedTags,
            contains(
              equals([
                'p',
                sourceCreatorB,
                'wss://source-b.relay',
                clipSourceCreditTagMarker,
              ]),
            ),
          );
        },
      );

      test(
        'drops a mention p-tag when its pubkey is promoted to collaborator',
        () async {
          const promoted =
              '1111111111111111111111111111111111111111111111111111111111111111';
          final video = _testVideo(
            extraTags: [
              [
                'p',
                NostrKeyUtils.encodePubKey(promoted),
                'wss://relay.divine.video',
                'mention',
              ],
            ],
          );

          final result = await service.updateVideo(
            originalVideo: video,
            editorState: VideoEditorProviderState(
              collaboratorPubkeys: {promoted.toUpperCase()},
            ),
            // Already known as a collaborator so no invite DM is attempted.
            initialCollaboratorPubkeys: const {promoted},
          );

          expect(result, isA<VideoUpdateSuccess>());
          // The stale tag carries the npub, so a filter keyed on the hex
          // cannot see it and a preserved 'mention' tag would go unnoticed.
          // Match either representation so the count catches a double-listing.
          final promotedNpub = NostrKeyUtils.encodePubKey(promoted);
          final pTagsForPromoted = capturedTags
              .where(
                (tag) =>
                    tag.length >= 2 &&
                    tag.first == 'p' &&
                    (tag[1] == promoted || tag[1] == promotedNpub),
              )
              .toList();
          expect(pTagsForPromoted, hasLength(1));
          expect(
            pTagsForPromoted.single,
            equals(['p', promoted, 'wss://relay.divine.video', 'collaborator']),
          );
        },
      );

      test(
        'strips an uppercase-marker inspired-by a-tag without duplicating it',
        () async {
          final video = _testVideo(
            extraTags: const [
              [
                'a',
                '34236:$_ownerPubkey:old-vid',
                'wss://relay.divine.video',
                'MENTION',
              ],
            ],
          );
          final editorState = VideoEditorProviderState(
            inspiredByVideo: const InspiredByInfo(
              addressableId: '34236:$_ownerPubkey:new-vid',
              relayUrl: 'wss://relay.divine.video',
            ),
          );

          final result = await service.updateVideo(
            originalVideo: video,
            editorState: editorState,
            initialCollaboratorPubkeys: const {},
          );

          expect(result, isA<VideoUpdateSuccess>());
          final aTags = capturedTags
              .where((tag) => tag.isNotEmpty && tag.first == 'a')
              .toList();
          expect(aTags, [
            [
              'a',
              '34236:$_ownerPubkey:new-vid',
              'wss://relay.divine.video',
              'inspired-by',
            ],
          ]);
        },
      );

      test(
        'does not accrete the inspired-by a-tag when re-editing an edited video',
        () async {
          // The original already carries the edit-written 'inspired-by' marker
          // (i.e. it was produced by a previous metadata edit).
          final video = _testVideo(
            extraTags: const [
              [
                'a',
                '34236:$_ownerPubkey:vid',
                'wss://relay.divine.video',
                'inspired-by',
              ],
            ],
          );
          final editorState = VideoEditorProviderState(
            inspiredByVideo: const InspiredByInfo(
              addressableId: '34236:$_ownerPubkey:vid',
              relayUrl: 'wss://relay.divine.video',
            ),
          );

          final result = await service.updateVideo(
            originalVideo: video,
            editorState: editorState,
            initialCollaboratorPubkeys: const {},
          );

          expect(result, isA<VideoUpdateSuccess>());
          final aTags = capturedTags
              .where((tag) => tag.isNotEmpty && tag.first == 'a')
              .toList();
          expect(aTags, [
            [
              'a',
              '34236:$_ownerPubkey:vid',
              'wss://relay.divine.video',
              'inspired-by',
            ],
          ]);
        },
      );
    });

    group('successful publish', () {
      test('returns VideoUpdateSuccess on happy path', () async {
        final result = await service.updateVideo(
          originalVideo: _testVideo(),
          editorState: VideoEditorProviderState(),
          initialCollaboratorPubkeys: const {},
        );

        expect(result, isA<VideoUpdateSuccess>());
      });

      test('calls publishEvent and cacheUserEvent on success', () async {
        await service.updateVideo(
          originalVideo: _testVideo(),
          editorState: VideoEditorProviderState(),
          initialCollaboratorPubkeys: const {},
        );

        verify(() => mockNostrService.publishEvent(any())).called(1);
        verify(
          () => mockPersonalEventCacheService.cacheUserEvent(any()),
        ).called(1);
      });

      test('calls updateVideoEvent on success', () async {
        await service.updateVideo(
          originalVideo: _testVideo(),
          editorState: VideoEditorProviderState(),
          initialCollaboratorPubkeys: const {},
        );

        verify(() => mockVideoEventService.updateVideoEvent(any())).called(1);
      });
    });

    group('publish failure', () {
      test(
        'returns VideoUpdateFailure when publishEvent does not succeed',
        () async {
          when(
            () => mockNostrService.publishEvent(any()),
          ).thenAnswer((_) async => const PublishNoRelays());

          final result = await service.updateVideo(
            originalVideo: _testVideo(),
            editorState: VideoEditorProviderState(),
            initialCollaboratorPubkeys: const {},
          );

          expect(
            result,
            isA<VideoUpdateFailure>().having(
              (f) => f.reason,
              'reason',
              VideoMetadataUpdateError.publishRejected,
            ),
          );
          verifyNever(
            () => mockPersonalEventCacheService.cacheUserEvent(any()),
          );
          verifyNever(() => mockVideoEventService.updateVideoEvent(any()));
        },
      );

      test(
        'returns VideoUpdateFailure when createAndSignEvent throws',
        () async {
          when(
            () => mockAuthService.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
              createdAt: any(named: 'createdAt'),
            ),
          ).thenThrow(Exception('signing failed'));

          final result = await service.updateVideo(
            originalVideo: _testVideo(),
            editorState: VideoEditorProviderState(),
            initialCollaboratorPubkeys: const {},
          );

          // `couldNotSign` is the *null-return* arm: in production
          // `SignerFactory.createAndSignEvent` catches and returns null. A
          // throw from the auth service itself is an infrastructure failure
          // that propagates to the outer handler, so it maps to `generic`.
          expect(
            result,
            isA<VideoUpdateFailure>().having(
              (f) => f.reason,
              'reason',
              VideoMetadataUpdateError.generic,
            ),
          );
          verifyNever(() => mockNostrService.publishEvent(any()));
        },
      );

      test(
        'returns couldNotSign when createAndSignEvent returns null',
        () async {
          // The production path: SignerFactory catches internally and returns
          // null rather than throwing, so this is the arm a real signer
          // refusal takes.
          when(
            () => mockAuthService.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
              createdAt: any(named: 'createdAt'),
            ),
          ).thenAnswer((_) async => null);

          final result = await service.updateVideo(
            originalVideo: _testVideo(),
            editorState: VideoEditorProviderState(),
            initialCollaboratorPubkeys: const {},
          );

          expect(
            result,
            isA<VideoUpdateFailure>().having(
              (f) => f.reason,
              'reason',
              VideoMetadataUpdateError.couldNotSign,
            ),
          );
          verifyNever(() => mockNostrService.publishEvent(any()));
        },
      );
    });

    group('invite failure', () {
      const newCollaborator =
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

      test('returns VideoUpdateSuccess with inviteFailureCount > 0 when DM '
          'send fails for a newly added collaborator', () async {
        when(
          () => mockDmRepository.sendMessage(
            recipientPubkey: any(named: 'recipientPubkey'),
            content: any(named: 'content'),
            additionalTags: any(named: 'additionalTags'),
            skipNip04Fallback: any(named: 'skipNip04Fallback'),
          ),
        ).thenAnswer(
          (_) async => const NIP17SendResult.failure('relay unreachable'),
        );

        final editorState = VideoEditorProviderState(
          collaboratorPubkeys: const {newCollaborator},
        );

        final result = await service.updateVideo(
          originalVideo: _testVideo(),
          editorState: editorState,
          initialCollaboratorPubkeys: const {},
        );

        expect(result, isA<VideoUpdateSuccess>());
        expect((result as VideoUpdateSuccess).inviteFailureCount, equals(1));
        verify(
          () => mockDmRepository.sendMessage(
            recipientPubkey: newCollaborator,
            content: any(named: 'content'),
            additionalTags: any(named: 'additionalTags'),
            skipNip04Fallback: any(named: 'skipNip04Fallback'),
          ),
        ).called(1);
      });

      test(
        'returns inviteFailureCount = 0 when the invite remains queued',
        () async {
          when(
            () => mockDmRepository.sendMessage(
              recipientPubkey: any(named: 'recipientPubkey'),
              content: any(named: 'content'),
              additionalTags: any(named: 'additionalTags'),
              skipNip04Fallback: any(named: 'skipNip04Fallback'),
            ),
          ).thenAnswer(
            (_) async => const NIP17SendResult.failure(
              'Delivery confirmation pending',
              retryablePending: true,
            ),
          );

          final result = await service.updateVideo(
            originalVideo: _testVideo(),
            editorState: VideoEditorProviderState(
              collaboratorPubkeys: const {newCollaborator},
            ),
            initialCollaboratorPubkeys: const {},
          );

          expect(result, isA<VideoUpdateSuccess>());
          expect((result as VideoUpdateSuccess).inviteFailureCount, equals(0));
        },
      );

      test(
        'returns inviteFailureCount = 0 when no new collaborators were added',
        () async {
          final result = await service.updateVideo(
            originalVideo: _testVideo(),
            editorState: VideoEditorProviderState(),
            initialCollaboratorPubkeys: const {},
          );

          expect(result, isA<VideoUpdateSuccess>());
          expect((result as VideoUpdateSuccess).inviteFailureCount, equals(0));
          verifyNever(
            () => mockDmRepository.sendMessage(
              recipientPubkey: any(named: 'recipientPubkey'),
              content: any(named: 'content'),
              additionalTags: any(named: 'additionalTags'),
              skipNip04Fallback: any(named: 'skipNip04Fallback'),
            ),
          );
        },
      );
    });

    group('inspired-by p-tag lifecycle', () {
      const inspiredCreator =
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
      const otherCreator =
          '2222222222222222222222222222222222222222222222222222222222222222';
      const inspiredAddressableId = '34236:$inspiredCreator:source-vid';
      const inspiredPTag = [
        'p',
        inspiredCreator,
        'wss://relay.divine.video',
        'inspired-by',
      ];

      List<List<String>> inspiredByPTags() => capturedTags
          .where(
            (tag) =>
                tag.length >= 4 && tag.first == 'p' && tag[3] == 'inspired-by',
          )
          .toList();

      test('keeps the p-tag exactly once when re-editing', () async {
        final video = _testVideo(
          extraTags: const [
            [
              'a',
              inspiredAddressableId,
              'wss://relay.divine.video',
              'inspired-by',
            ],
            inspiredPTag,
          ],
        );

        final result = await service.updateVideo(
          originalVideo: video,
          editorState: VideoEditorProviderState(
            inspiredByVideo: const InspiredByInfo(
              addressableId: inspiredAddressableId,
              relayUrl: 'wss://relay.divine.video',
            ),
          ),
          initialCollaboratorPubkeys: const {},
        );

        expect(result, isA<VideoUpdateSuccess>());
        expect(inspiredByPTags(), [equals(inspiredPTag)]);
      });

      test('mints the p-tag when editing a pre-fix video', () async {
        final video = _testVideo(
          extraTags: const [
            ['a', inspiredAddressableId, 'wss://relay.divine.video', 'mention'],
          ],
        );

        final result = await service.updateVideo(
          originalVideo: video,
          editorState: VideoEditorProviderState(
            inspiredByVideo: const InspiredByInfo(
              addressableId: inspiredAddressableId,
              relayUrl: 'wss://relay.divine.video',
            ),
          ),
          initialCollaboratorPubkeys: const {},
        );

        expect(result, isA<VideoUpdateSuccess>());
        expect(inspiredByPTags(), [equals(inspiredPTag)]);
      });

      test('strips the p-tag when attribution is cleared', () async {
        final video = _testVideo(
          extraTags: const [
            [
              'a',
              inspiredAddressableId,
              'wss://relay.divine.video',
              'inspired-by',
            ],
            inspiredPTag,
          ],
        );

        final result = await service.updateVideo(
          originalVideo: video,
          editorState: VideoEditorProviderState(),
          initialCollaboratorPubkeys: const {},
        );

        expect(result, isA<VideoUpdateSuccess>());
        expect(inspiredByPTags(), isEmpty);
      });

      test('re-targets the p-tag when the inspiring creator changes', () async {
        final video = _testVideo(
          extraTags: const [
            [
              'a',
              inspiredAddressableId,
              'wss://relay.divine.video',
              'inspired-by',
            ],
            inspiredPTag,
          ],
        );

        final result = await service.updateVideo(
          originalVideo: video,
          editorState: VideoEditorProviderState(
            inspiredByVideo: const InspiredByInfo(
              addressableId: '34236:$otherCreator:other-vid',
              relayUrl: 'wss://relay.divine.video',
            ),
          ),
          initialCollaboratorPubkeys: const {},
        );

        expect(result, isA<VideoUpdateSuccess>());
        expect(inspiredByPTags(), [
          equals([
            'p',
            otherCreator,
            'wss://relay.divine.video',
            'inspired-by',
          ]),
        ]);
      });

      test('emits a p-tag for a person (npub) attribution', () async {
        final npub = NostrKeyUtils.encodePubKey(inspiredCreator);

        final result = await service.updateVideo(
          originalVideo: _testVideo(),
          editorState: VideoEditorProviderState(inspiredByNpub: npub),
          initialCollaboratorPubkeys: const {},
        );

        expect(result, isA<VideoUpdateSuccess>());
        expect(inspiredByPTags(), [equals(inspiredPTag)]);
      });

      test('keeps a single collaborator p-tag when the creator is promoted '
          'to collaborator', () async {
        final video = _testVideo(
          extraTags: const [
            [
              'a',
              inspiredAddressableId,
              'wss://relay.divine.video',
              'inspired-by',
            ],
            inspiredPTag,
          ],
        );

        final result = await service.updateVideo(
          originalVideo: video,
          editorState: VideoEditorProviderState(
            collaboratorPubkeys: {inspiredCreator},
            inspiredByVideo: const InspiredByInfo(
              addressableId: inspiredAddressableId,
              relayUrl: 'wss://relay.divine.video',
            ),
          ),
          initialCollaboratorPubkeys: const {inspiredCreator},
        );

        expect(result, isA<VideoUpdateSuccess>());
        final pTagsForCreator = capturedTags
            .where(
              (tag) =>
                  tag.length >= 2 &&
                  tag.first == 'p' &&
                  tag[1] == inspiredCreator,
            )
            .toList();
        expect(pTagsForCreator, hasLength(1));
        expect(
          pTagsForCreator.single,
          equals([
            'p',
            inspiredCreator,
            'wss://relay.divine.video',
            'collaborator',
          ]),
        );
      });

      test('re-mints the inspired-by p-tag when the creator is demoted from '
          'collaborator', () async {
        // The original event was produced by a promotion edit: it carries
        // the collaborator p-tag and no inspired-by p-tag.
        final promotedVideo = _testVideo(
          extraTags: const [
            [
              'a',
              inspiredAddressableId,
              'wss://relay.divine.video',
              'inspired-by',
            ],
            ['p', inspiredCreator, 'wss://relay.divine.video', 'collaborator'],
          ],
        );

        final result = await service.updateVideo(
          originalVideo: promotedVideo,
          editorState: VideoEditorProviderState(
            inspiredByVideo: const InspiredByInfo(
              addressableId: inspiredAddressableId,
              relayUrl: 'wss://relay.divine.video',
            ),
          ),
          initialCollaboratorPubkeys: const {inspiredCreator},
        );

        expect(result, isA<VideoUpdateSuccess>());
        expect(inspiredByPTags(), [equals(inspiredPTag)]);
        expect(
          capturedTags,
          isNot(
            contains(
              equals([
                'p',
                inspiredCreator,
                'wss://relay.divine.video',
                'collaborator',
              ]),
            ),
          ),
        );
      });

      test('never strips caption-mention p-tags', () async {
        const mentioned =
            '3333333333333333333333333333333333333333333333333333333333333333';
        final video = _testVideo(
          extraTags: const [
            ['p', mentioned, 'wss://relay.divine.video', 'mention'],
          ],
        );

        final result = await service.updateVideo(
          originalVideo: video,
          editorState: VideoEditorProviderState(
            inspiredByVideo: const InspiredByInfo(
              addressableId: inspiredAddressableId,
              relayUrl: 'wss://relay.divine.video',
            ),
          ),
          initialCollaboratorPubkeys: const {},
        );

        expect(result, isA<VideoUpdateSuccess>());
        expect(
          capturedTags,
          contains(
            equals(['p', mentioned, 'wss://relay.divine.video', 'mention']),
          ),
        );
        expect(inspiredByPTags(), [equals(inspiredPTag)]);
      });

      test(
        'does not double-tag a creator who is already a caption mention',
        () async {
          final video = _testVideo(
            extraTags: const [
              ['p', inspiredCreator, 'wss://relay.divine.video', 'mention'],
            ],
          );

          final result = await service.updateVideo(
            originalVideo: video,
            editorState: VideoEditorProviderState(
              inspiredByVideo: const InspiredByInfo(
                addressableId: inspiredAddressableId,
                relayUrl: 'wss://relay.divine.video',
              ),
            ),
            initialCollaboratorPubkeys: const {},
          );

          expect(result, isA<VideoUpdateSuccess>());
          final pTagsForCreator = capturedTags
              .where(
                (tag) =>
                    tag.length >= 2 &&
                    tag.first == 'p' &&
                    tag[1] == inspiredCreator,
              )
              .toList();
          expect(pTagsForCreator, hasLength(1));
          expect(
            pTagsForCreator.single,
            equals([
              'p',
              inspiredCreator,
              'wss://relay.divine.video',
              'mention',
            ]),
          );
        },
      );

      test('preserves an inspired-by p-tag verbatim on a video reply', () async {
        const rootEventId =
            'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
        const rootAuthorPubkey =
            'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
        const rootAddressableId = '34236:$rootAuthorPubkey:root-vid';
        final video = VideoEvent.fromNostrEvent(
          Event(
            _ownerPubkey,
            NIP71VideoKinds.addressableShortVideo,
            const [
              ['d', 'video-d-tag'],
              ['imeta', 'url https://cdn.example.com/video.mp4', 'm video/mp4'],
              ['A', rootAddressableId, ''],
              ['P', rootAuthorPubkey],
              ['E', rootEventId, '', rootAuthorPubkey],
              ['K', '34236'],
              ['e', rootEventId, '', rootAuthorPubkey],
              ['p', rootAuthorPubkey],
              inspiredPTag,
            ],
            'Reply video',
            createdAt: 1757385263,
          ),
        );
        expect(video.isVideoReply, isTrue);

        final result = await service.updateVideo(
          originalVideo: video,
          editorState: VideoEditorProviderState(
            inspiredByVideo: video.inspiredByVideo,
          ),
          initialCollaboratorPubkeys: const {},
        );

        expect(result, isA<VideoUpdateSuccess>());
        expect(inspiredByPTags(), [equals(inspiredPTag)]);
      });

      test('does not self-p-tag when inspired by an own video', () async {
        final result = await service.updateVideo(
          originalVideo: _testVideo(),
          editorState: VideoEditorProviderState(
            inspiredByVideo: const InspiredByInfo(
              addressableId: '34236:$_ownerPubkey:own-vid',
              relayUrl: 'wss://relay.divine.video',
            ),
          ),
          initialCollaboratorPubkeys: const {},
        );

        expect(result, isA<VideoUpdateSuccess>());
        expect(inspiredByPTags(), isEmpty);
      });
    });
  });
}
