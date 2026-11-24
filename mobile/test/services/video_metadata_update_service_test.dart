// ABOUTME: Unit tests for VideoMetadataUpdateService.
// ABOUTME: Covers auth guard, video-URL guard, original-tag preservation,
// ABOUTME: edited-field replacement, replacement created_at, successful publish,
// ABOUTME: publish failure, invite failure, and rebuilding from the relays'
// ABOUTME: newest revision rather than the one the editor opened (#11250).

import 'dart:io';
import 'dart:ui' show Locale;

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:characters/characters.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hashtag_repository/hashtag_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/utils/nostr_timestamp.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/exceptions/video_exceptions.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/auth_state.dart';
import 'package:openvine/models/content_label.dart';
import 'package:openvine/models/video_editor/published_video_editor_seed.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/models/video_metadata_update_error.dart';
import 'package:openvine/services/collaborator_invite_service.dart';
import 'package:openvine/services/personal_event_cache_service.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/services/video_metadata_update_service.dart';
import 'package:openvine/services/video_publish/signed_event_relay_publisher.dart';
import 'package:openvine/utils/nostr_key_utils.dart';

import '../helpers/test_provider_overrides.dart';
import '../helpers/test_pubkeys.dart';

class _MockBlossomUploadService extends Mock implements BlossomUploadService {}

class _MockDmRepository extends Mock implements DmRepository {}

class _MockPersonalEventCacheService extends Mock
    implements PersonalEventCacheService {}

class _MockVideoEventService extends Mock implements VideoEventService {}

class _MockSignedEventRelayPublisher extends Mock
    implements SignedEventRelayPublisher {}

class _MockNostrClient extends Mock implements NostrClient {}

class _FakeEvent extends Fake implements Event {}

class _FakeVideoEvent extends Fake implements VideoEvent {}

const _ownerPubkey =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

VideoEvent _testVideo({
  List<List<String>> extraTags = const [],
  int? eventCreatedAt,
  String? title = 'Test Video Title',
  String content = 'Test video content',
}) {
  return VideoEvent.fromNostrEvent(
    Event.fromJson({
      'id': 'event-id',
      'pubkey': _ownerPubkey,
      'kind': NIP71VideoKinds.addressableShortVideo,
      'created_at': eventCreatedAt ?? 1757385263,
      'content': content,
      'tags': [
        if (!extraTags.any((tag) => tag.first == 'd')) ['d', 'video-d-tag'],
        if (title != null) ['title', title],
        ['imeta', 'url https://cdn.example.com/video.mp4', 'm video/mp4'],
        ...extraTags,
      ],
    }),
  );
}

void main() {
  late MockAuthService mockAuthService;
  late _MockSignedEventRelayPublisher mockRelayPublisher;
  late _MockBlossomUploadService mockBlossomUploadService;
  late _MockDmRepository mockDmRepository;
  late _MockPersonalEventCacheService mockPersonalEventCacheService;
  late _MockVideoEventService mockVideoEventService;
  late _MockNostrClient mockNostrClient;
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
    mockRelayPublisher = _MockSignedEventRelayPublisher();
    mockBlossomUploadService = _MockBlossomUploadService();
    mockDmRepository = _MockDmRepository();
    mockPersonalEventCacheService = _MockPersonalEventCacheService();
    mockVideoEventService = _MockVideoEventService();
    mockNostrClient = _MockNostrClient();
    capturedTags = [];
    capturedCreatedAt = 0;

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
      return Event(
        _ownerPubkey,
        invocation.namedArguments[#kind] as int,
        capturedTags,
        invocation.namedArguments[#content] as String,
        createdAt: capturedCreatedAt,
      );
    });

    when(
      () => mockRelayPublisher.publishViaWebSocket(any()),
    ).thenAnswer((_) async => EventPublishOutcome.published);

    when(
      () => mockPersonalEventCacheService.cacheUserEvent(any()),
    ).thenReturn(null);
    when(() => mockVideoEventService.updateVideoEvent(any())).thenReturn(null);

    service = VideoMetadataUpdateService(
      authService: mockAuthService,
      blossomService: mockBlossomUploadService,
      relayPublisher: mockRelayPublisher,
      personalEventCache: mockPersonalEventCacheService,
      videoEventService: mockVideoEventService,
      nostrClient: mockNostrClient,
      collaboratorInviteService: CollaboratorInviteService(
        dmRepository: mockDmRepository,
        l10n: lookupAppLocalizations(const Locale('en')),
      ),
    );
  });

  /// The raw event behind [video], as the relays would answer for it.
  Event relayRevisionOf(VideoEvent video) => Event.fromJson({
    'id': video.id,
    'pubkey': video.pubkey,
    'created_at': video.nostrCreatedAt,
    'kind': video.eventKind ?? NIP71VideoKinds.addressableShortVideo,
    'tags': [
      if (!video.nostrEventTags.any((t) => t.isNotEmpty && t.first == 'd'))
        ['d', video.stableId],
      ...video.nostrEventTags,
    ],
    'content': video.content,
    'sig': '',
  });

  /// Edits [originalVideo] while the relays' newest revision is that same
  /// event, the common case: nobody changed the video since it was opened.
  Future<VideoUpdateResult> updateFromRelay({
    required VideoEvent originalVideo,
    required VideoEditorProviderState editorState,
    required Set<String> initialCollaboratorPubkeys,
    File? newThumbnailFile,
  }) {
    when(
      () => mockNostrClient.readCurrentVersion(
        kind: any(named: 'kind'),
        pubkey: any(named: 'pubkey'),
        dTag: any(named: 'dTag'),
      ),
    ).thenAnswer(
      (_) async => CurrentVersionFound(relayRevisionOf(originalVideo)),
    );
    return service.updateVideo(
      originalVideo: originalVideo,
      editorState: editorState,
      initialCollaboratorPubkeys: initialCollaboratorPubkeys,
      newThumbnailFile: newThumbnailFile,
    );
  }

  group(VideoMetadataUpdateService, () {
    test('writes an explicit false audio-reuse marker', () async {
      final result = await updateFromRelay(
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

    test('replaces the video-reuse marker with the edited choice', () async {
      final result = await updateFromRelay(
        originalVideo: _testVideo(
          extraTags: const [
            ['allow_video_reuse', 'false'],
          ],
        ),
        editorState: VideoEditorProviderState(),
        initialCollaboratorPubkeys: const {},
      );

      expect(result, isA<VideoUpdateSuccess>());
      expect(
        capturedTags.where((tag) => tag.first == 'allow_video_reuse'),
        equals([
          ['allow_video_reuse', 'true'],
        ]),
      );
    });

    group('auth guard', () {
      test(
        'does not send a replacement signed under a different account',
        () async {
          when(
            () => mockAuthService.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
              createdAt: any(named: 'createdAt'),
            ),
          ).thenAnswer(
            (_) async =>
                Event(syntheticOtherTestPubkey, 34236, [], 'Different author'),
          );

          final result = await updateFromRelay(
            originalVideo: _testVideo(),
            editorState: VideoEditorProviderState(),
            initialCollaboratorPubkeys: const {},
          );

          expect(result, isA<VideoUpdateFailure>());
          verifyNever(() => mockRelayPublisher.publishViaWebSocket(any()));
        },
      );
      test('returns VideoUpdateFailure when not authenticated', () async {
        when(() => mockAuthService.isAuthenticated).thenReturn(false);
        when(
          () => mockAuthService.authState,
        ).thenReturn(AuthState.unauthenticated);

        final result = await updateFromRelay(
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
            addressableDTag: 'video-d-tag',
            nostrEventTags: const [
              ['d', 'video-d-tag'],
            ],
          );

          final result = await updateFromRelay(
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
          final result = await updateFromRelay(
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
        final firstResult = await updateFromRelay(
          originalVideo: _testVideo(eventCreatedAt: rawEventCreatedAt),
          editorState: VideoEditorProviderState(),
          initialCollaboratorPubkeys: const {},
        );

        final firstVideo = (firstResult as VideoUpdateSuccess).updatedEvent;
        final firstReplacementCreatedAt = firstVideo.nostrCreatedAt;
        final secondResult = await updateFromRelay(
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

          final result = await updateFromRelay(
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
        final result = await updateFromRelay(
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
              ['r', 'wss://relay.divine.video'],
              ['proofmode', 'proof-payload'],
              ['c2pa_manifest_id', 'manifest-123'],
            ],
          );

          final result = await updateFromRelay(
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

      test(
        'drops the original client tag so the signing path attributes the '
        'edit per the current preference (#8176)',
        () async {
          final video = _testVideo(
            extraTags: const [
              ['client', 'divine'],
            ],
          );

          final result = await updateFromRelay(
            originalVideo: video,
            editorState: VideoEditorProviderState(),
            initialCollaboratorPubkeys: const {},
          );

          expect(result, isA<VideoUpdateSuccess>());
          expect(
            capturedTags.where(
              (tag) => tag.isNotEmpty && tag.first == 'client',
            ),
            isEmpty,
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

        final result = await updateFromRelay(
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

        final result = await updateFromRelay(
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
            '7777777777777777777777777777777777777777777777777777777777777777';
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

        final result = await updateFromRelay(
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

          final result = await updateFromRelay(
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

      test('rebuilds from the raw tags the relays hold when the opened copy '
          'has none', () async {
        // A VideoEvent rehydrated from a JSON cache has empty
        // nostrEventTags; the relays still hold the raw event.
        final video = VideoEvent(
          id: 'event-id',
          pubkey: _ownerPubkey,
          createdAt: 1757385263,
          content: 'Test video content',
          timestamp: DateTime.fromMillisecondsSinceEpoch(1757385263 * 1000),
          videoUrl: 'https://cdn.example.com/video.mp4',
          title: 'Test Video Title',
          vineId: 'video-d-tag',
          addressableDTag: 'video-d-tag',
        );
        when(
          () => mockNostrClient.readCurrentVersion(
            kind: any(named: 'kind'),
            pubkey: any(named: 'pubkey'),
            dTag: any(named: 'dTag'),
          ),
        ).thenAnswer(
          (_) async => CurrentVersionFound(
            Event.fromJson({
              'id': 'event-id',
              'pubkey': _ownerPubkey,
              'created_at': 1757385263,
              'kind': NIP71VideoKinds.addressableShortVideo,
              'tags': [
                ['d', 'video-d-tag'],
                [
                  'imeta',
                  'url https://cdn.example.com/video.mp4',
                  'url https://mirror.example.com/video.mp4',
                  'm video/mp4',
                ],
                ['e', audioEventId, 'wss://relay.divine.video', 'audio'],
                ['expiration', '1799999999'],
              ],
              'content': 'Test video content',
              'sig': '',
            }),
          ),
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
        final imeta = capturedTags.singleWhere((t) => t.first == 'imeta');
        expect(
          imeta,
          containsAll([
            'url https://cdn.example.com/video.mp4',
            'url https://mirror.example.com/video.mp4',
          ]),
        );
      });

      for (final (name, revision) in [
        (
          'refused or did not answer',
          const CurrentVersionFailed(noRelay: false),
        ),
        ('hold none', const CurrentVersionAbsent()),
      ]) {
        test('refuses to publish when the relays $name', () async {
          when(
            () => mockNostrClient.readCurrentVersion(
              kind: any(named: 'kind'),
              pubkey: any(named: 'pubkey'),
              dTag: any(named: 'dTag'),
            ),
          ).thenAnswer((_) async => revision);

          final result = await service.updateVideo(
            originalVideo: _testVideo(),
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
          verifyNever(() => mockRelayPublisher.publishViaWebSocket(any()));
        });
      }

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

          final result = await updateFromRelay(
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

    group('newest revision on the relays', () {
      const audioEventId =
          'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
      const collaborator = syntheticOtherTestPubkey;
      const subtitleTrack = [
        'text-track',
        'https://cdn.example.com/subs-en.vtt',
        'wss://relay.divine.video',
        'captions',
        'en',
      ];
      const audioTag = ['e', audioEventId, 'wss://relay.divine.video', 'audio'];

      /// A revision another device published after the editor opened
      /// [_testVideo]: same address, later, with [extraTags] on top.
      Event newerRevision({
        List<List<String>> extraTags = const [],
        String title = 'Test Video Title',
        String content = 'Test video content',
        int createdAt = 1757385263 + 500,
        int kind = NIP71VideoKinds.addressableShortVideo,
      }) => Event.fromJson({
        'id': 'newer-event-id',
        'pubkey': _ownerPubkey,
        'created_at': createdAt,
        'kind': kind,
        'tags': [
          ['d', 'video-d-tag'],
          ['imeta', 'url https://cdn.example.com/video.mp4', 'm video/mp4'],
          ['title', title],
          ...extraTags,
        ],
        'content': content,
        'sig': '',
      });

      void relaysHold(Event event) {
        when(
          () => mockNostrClient.readCurrentVersion(
            kind: any(named: 'kind'),
            pubkey: any(named: 'pubkey'),
            dTag: any(named: 'dTag'),
          ),
        ).thenAnswer((_) async => CurrentVersionFound(event));
      }

      test('reads the address of the video being edited', () async {
        relaysHold(newerRevision());

        await service.updateVideo(
          originalVideo: _testVideo(),
          editorState: editorStateFromPublishedVideo(_testVideo()),
          initialCollaboratorPubkeys: const {},
        );

        verify(
          () => mockNostrClient.readCurrentVersion(
            kind: 34236,
            pubkey: _ownerPubkey,
            dTag: 'video-d-tag',
          ),
        ).called(1);
      });

      test(
        'preserves signed tags omitted from a REST row at the same ID',
        () async {
          final relay = newerRevision(
            extraTags: const [
              ['t', 'fromrelay'],
              ['allow_audio_reuse', 'true'],
              ['allow_video_reuse', 'false'],
            ],
          );
          relaysHold(relay);
          final opened = VideoStats.fromJson({
            'id': relay.id,
            'pubkey': relay.pubkey,
            'kind': relay.kind,
            'created_at': relay.createdAt,
            'd_tag': 'video-d-tag',
            'title': 'Test Video Title',
            'video_url': 'https://cdn.example.com/video.mp4',
            'tags': const [
              ['d', 'video-d-tag'],
              ['title', 'Test Video Title'],
            ],
          }).toVideoEvent();
          final seed = editorStateFromPublishedVideo(opened);
          expect(seed.allowAudioReuse, isFalse);
          expect(seed.allowVideoReuse, isTrue);
          expect(seed.tags, isEmpty);

          final result = await service.updateVideo(
            originalVideo: opened,
            editorState: seed.copyWith(title: 'Edited title'),
            initialCollaboratorPubkeys: const {},
          );

          expect(result, isA<VideoUpdateSuccess>());
          expect(capturedTags, contains(equals(['title', 'Edited title'])));
          expect(capturedTags, contains(equals(['t', 'fromrelay'])));
          expect(capturedTags, contains(equals(['allow_audio_reuse', 'true'])));
          expect(
            capturedTags,
            contains(equals(['allow_video_reuse', 'false'])),
          );
        },
      );

      test('applies local hashtag changes to the signed set', () async {
        final opened = _testVideo(
          extraTags: const [
            ['t', 'kept'],
            ['t', 'removed'],
          ],
        );
        relaysHold(
          newerRevision(
            extraTags: const [
              ['t', 'kept'],
              ['t', 'removed'],
              ['t', 'remoteaddition'],
            ],
          ),
        );

        final result = await service.updateVideo(
          originalVideo: opened,
          editorState: editorStateFromPublishedVideo(opened).copyWith(
            tags: const {'kept', 'localaddition'},
          ),
          initialCollaboratorPubkeys: const {},
        );

        expect(result, isA<VideoUpdateSuccess>());
        expect(
          capturedTags.where((tag) => tag.first == 't').map((tag) => tag[1]),
          unorderedEquals(['kept', 'remoteaddition', 'localaddition']),
        );
      });

      test(
        'keeps signed hashtags beyond the limit in a title-only edit',
        () async {
          final signedHashtags = [
            for (var i = 0; i <= HashtagExtractor.maxHashtagsPerVideo; i++)
              'signedtag$i',
          ];
          final opened = _testVideo(
            extraTags: [
              for (final hashtag in signedHashtags) ['t', hashtag],
            ],
          );

          final result = await updateFromRelay(
            originalVideo: opened,
            editorState: editorStateFromPublishedVideo(
              opened,
            ).copyWith(title: 'Retitled'),
            initialCollaboratorPubkeys: const {},
          );

          expect(result, isA<VideoUpdateSuccess>());
          expect(
            capturedTags.where((tag) => tag.first == 't').map((tag) => tag[1]),
            signedHashtags,
          );
        },
      );

      test(
        'refuses a concurrent collaborator addition above the limit and '
        'shows the newest revision',
        () async {
          final opened = _testVideo();
          final remoteCollaborators = List.generate(
            5,
            (i) => testPubkeyFromSeed(i + 1),
          );
          relaysHold(
            newerRevision(
              extraTags: [
                for (final pubkey in remoteCollaborators)
                  ['p', pubkey, '', 'collaborator'],
              ],
            ),
          );

          final result = await service.updateVideo(
            originalVideo: opened,
            editorState: editorStateFromPublishedVideo(opened)
                .copyWith(collaboratorPubkeys: {testPubkeyFromSeed(6)}),
            initialCollaboratorPubkeys: const {},
          );

          expect(
            result,
            isA<VideoUpdateFailure>().having(
              (failure) => failure.reason,
              'reason',
              VideoMetadataUpdateError.concurrentEditsOverLimit,
            ),
          );
          verifyNever(() => mockRelayPublisher.publishViaWebSocket(any()));
          verify(
            () => mockVideoEventService.updateVideoEvent(
              any(
                that: isA<VideoEvent>().having(
                  (v) => v.id,
                  'id',
                  'newer-event-id',
                ),
              ),
            ),
          ).called(1);
          verify(
            () => mockPersonalEventCacheService.cacheUserEvent(
              any(
                that: isA<Event>().having((e) => e.id, 'id', 'newer-event-id'),
              ),
            ),
          ).called(1);
        },
      );

      test('refuses two ten-tag edits whose union exceeds the limit and shows '
          'the newest revision', () async {
        final shared = [for (var i = 0; i < 9; i++) 'shared$i'];
        final opened = _testVideo(
          extraTags: [
            for (final tag in shared) ['t', tag],
          ],
        );
        relaysHold(
          newerRevision(
            extraTags: [
              for (final tag in [...shared, 'remotetenth']) ['t', tag],
            ],
          ),
        );
        final localTags = {...shared, 'localtenth'};
        expect(localTags, hasLength(HashtagExtractor.maxHashtagsPerVideo));

        final result = await service.updateVideo(
          originalVideo: opened,
          editorState: editorStateFromPublishedVideo(
            opened,
          ).copyWith(tags: localTags),
          initialCollaboratorPubkeys: const {},
        );

        expect(
          result,
          isA<VideoUpdateFailure>().having(
            (failure) => failure.reason,
            'reason',
            VideoMetadataUpdateError.concurrentEditsOverLimit,
          ),
        );
        verifyNever(() => mockRelayPublisher.publishViaWebSocket(any()));
        verify(
          () => mockVideoEventService.updateVideoEvent(
            any(
              that: isA<VideoEvent>().having(
                (v) => v.id,
                'id',
                'newer-event-id',
              ),
            ),
          ),
        ).called(1);
        verify(
          () => mockPersonalEventCacheService.cacheUserEvent(
            any(that: isA<Event>().having((e) => e.id, 'id', 'newer-event-id')),
          ),
        ).called(1);
      });

      test(
        'leaves the cached copies alone when the account changes before an '
        'over-limit edit is refused',
        () async {
          final shared = [for (var i = 0; i < 9; i++) 'shared$i'];
          final opened = _testVideo(
            extraTags: [
              for (final tag in shared) ['t', tag],
            ],
          );
          relaysHold(
            newerRevision(
              extraTags: [
                for (final tag in [...shared, 'remotetenth']) ['t', tag],
              ],
            ),
          );
          when(
            () => mockBlossomUploadService.uploadImage(
              imageFile: any(named: 'imageFile'),
              nostrPubkey: _ownerPubkey,
            ),
          ).thenAnswer((_) async {
            when(() => mockAuthService.currentPublicKeyHex)
                .thenReturn(syntheticOtherTestPubkey);
            return const BlossomUploadResult(success: false);
          });

          final result = await service.updateVideo(
            originalVideo: opened,
            editorState: editorStateFromPublishedVideo(
              opened,
            ).copyWith(tags: {...shared, 'localtenth'}),
            initialCollaboratorPubkeys: const {},
            newThumbnailFile: File('new-thumbnail.jpg'),
          );

          expect(
            result,
            isA<VideoUpdateFailure>().having(
              (failure) => failure.reason,
              'reason',
              VideoMetadataUpdateError.concurrentEditsOverLimit,
            ),
          );
          verifyNever(
            () => mockPersonalEventCacheService.cacheUserEvent(any()),
          );
          verifyNever(() => mockVideoEventService.updateVideoEvent(any()));
        },
      );

      test(
        'publishes a merge that lands exactly on the hashtag limit',
        () async {
          final shared = [for (var i = 0; i < 8; i++) 'shared$i'];
          final opened = _testVideo(
            extraTags: [
              for (final tag in shared) ['t', tag],
            ],
          );
          relaysHold(
            newerRevision(
              extraTags: [
                for (final tag in [...shared, 'remoteninth']) ['t', tag],
              ],
            ),
          );

          final result = await service.updateVideo(
            originalVideo: opened,
            editorState: editorStateFromPublishedVideo(
              opened,
            ).copyWith(tags: {...shared, 'localninth'}),
            initialCollaboratorPubkeys: const {},
          );

          expect(result, isA<VideoUpdateSuccess>());
          expect(
            capturedTags.where((tag) => tag.first == 't').map((tag) => tag[1]),
            unorderedEquals([...shared, 'remoteninth', 'localninth']),
          );
        },
      );

      test('keeps a hashtag removal made only on the other device', () async {
        final opened = _testVideo(
          extraTags: const [
            ['t', 'kept'],
            ['t', 'removedelsewhere'],
          ],
        );
        relaysHold(
          newerRevision(
            extraTags: const [
              ['t', 'kept'],
            ],
          ),
        );

        final result = await service.updateVideo(
          originalVideo: opened,
          editorState: editorStateFromPublishedVideo(
            opened,
          ).copyWith(title: 'Edited title'),
          initialCollaboratorPubkeys: const {},
        );

        expect(result, isA<VideoUpdateSuccess>());
        expect(
          capturedTags.where((tag) => tag.first == 't').map((tag) => tag[1]),
          ['kept'],
        );
      });

      test('still edits a video over the collaborator limit when this edit '
          'adds no one', () async {
        final collaborators = List.generate(
          6,
          (i) => testPubkeyFromSeed(i + 1),
        );
        relaysHold(
          newerRevision(
            extraTags: [
              for (final pubkey in collaborators)
                ['p', pubkey, '', 'collaborator'],
            ],
          ),
        );
        final opened = _testVideo();

        final result = await service.updateVideo(
          originalVideo: opened,
          editorState: editorStateFromPublishedVideo(
            opened,
          ).copyWith(title: 'Edited title'),
          initialCollaboratorPubkeys: const {},
        );

        expect(result, isA<VideoUpdateSuccess>());
        expect(
          capturedTags
              .where((tag) => tag.first == 'p' && tag.last == 'collaborator')
              .map((tag) => tag[1]),
          unorderedEquals(collaborators),
        );
      });

      test('keeps a newer title when saving details after subtitles', () async {
        final opened = _testVideo();
        final subtitleRevision = newerRevision(
          title: 'Title from another device',
          extraTags: const [subtitleTrack],
        );
        final afterSubtitles = VideoEvent.fromNostrEvent(subtitleRevision);
        relaysHold(subtitleRevision);

        final result = await service.updateVideo(
          originalVideo: afterSubtitles,
          editorBaseline: opened,
          editorState: editorStateFromPublishedVideo(opened)
              .copyWith(description: 'Unsaved caption edit'),
          initialCollaboratorPubkeys: const {},
        );

        expect(result, isA<VideoUpdateSuccess>());
        expect(
          capturedTags,
          contains(equals(['title', 'Title from another device'])),
        );
        expect(
          capturedTags,
          contains(equals(['summary', 'Unsaved caption edit'])),
        );
        expect(capturedTags, contains(equals(subtitleTrack)));
      });

      test('preserves separate imeta variants and their metadata', () async {
        const hls = [
          'imeta',
          'url',
          'https://cdn.example.com/video.m3u8',
          'm',
          'application/vnd.apple.mpegurl',
          'dim',
          '1080x1920',
        ];
        relaysHold(newerRevision(extraTags: const [hls]));
        final opened = _testVideo();

        final result = await service.updateVideo(
          originalVideo: opened,
          editorState: editorStateFromPublishedVideo(opened)
              .copyWith(title: 'Edited title'),
          initialCollaboratorPubkeys: const {},
        );

        expect(result, isA<VideoUpdateSuccess>());
        expect(capturedTags.where((tag) => tag.first == 'imeta'), [
          ['imeta', 'url https://cdn.example.com/video.mp4', 'm video/mp4'],
          hls,
        ]);
      });

      test('updates thumbnails without flattening media variants', () async {
        const thumbnailUrl = 'https://cdn.example.com/new-thumbnail.jpg';
        const hls = [
          'imeta',
          'url',
          'https://cdn.example.com/video.m3u8',
          'thumb',
          'https://cdn.example.com/old-thumbnail.jpg',
          'm',
          'application/vnd.apple.mpegurl',
        ];
        const oldCover = 'https://cdn.example.com/legacy-thumbnail.jpg';
        relaysHold(
          newerRevision(
            extraTags: const [
              hls,
              ['thumbnail', oldCover],
              ['thumb', oldCover],
              ['image', oldCover],
              ['r', oldCover, 'thumbnail'],
            ],
          ),
        );
        when(
          () => mockBlossomUploadService.uploadImage(
            imageFile: any(named: 'imageFile'),
            nostrPubkey: _ownerPubkey,
          ),
        ).thenAnswer(
          (_) async =>
              const BlossomUploadResult(success: true, url: thumbnailUrl),
        );
        final opened = _testVideo();

        final result = await service.updateVideo(
          originalVideo: opened,
          editorState: editorStateFromPublishedVideo(opened),
          initialCollaboratorPubkeys: const {},
          newThumbnailFile: File('new-thumbnail.jpg'),
        );

        expect(
          result,
          isA<VideoUpdateSuccess>().having(
            (success) => success.updatedEvent.thumbnailUrl,
            'updated thumbnail',
            thumbnailUrl,
          ),
        );
        final indexedVideo = VideoStats.fromJson({
          'tags': capturedTags,
        }).toVideoEvent();
        expect(indexedVideo.thumbnailUrl, thumbnailUrl);
        expect(
          capturedTags,
          containsAll([
            ['thumb', thumbnailUrl],
            ['image', thumbnailUrl],
            ['r', thumbnailUrl, 'thumbnail'],
          ]),
        );
        expect(capturedTags.where((tag) => tag.first == 'imeta'), [
          [
            'imeta',
            'url https://cdn.example.com/video.mp4',
            'm video/mp4',
            'image $thumbnailUrl',
          ],
          [
            'imeta',
            'url https://cdn.example.com/video.m3u8',
            'm application/vnd.apple.mpegurl',
            'image $thumbnailUrl',
          ],
        ]);
      });

      test(
        'keeps a subtitle revision published during a cover upload',
        () async {
          final opened = _testVideo();
          relaysHold(relayRevisionOf(opened));
          when(
            () => mockBlossomUploadService.uploadImage(
              imageFile: any(named: 'imageFile'),
              nostrPubkey: _ownerPubkey,
            ),
          ).thenAnswer((_) async {
            relaysHold(newerRevision(extraTags: const [subtitleTrack]));
            return const BlossomUploadResult(
              success: true,
              url: 'https://cdn.example.com/new-thumbnail.jpg',
            );
          });

          final result = await service.updateVideo(
            originalVideo: opened,
            editorState: editorStateFromPublishedVideo(opened),
            initialCollaboratorPubkeys: const {},
            newThumbnailFile: File('new-thumbnail.jpg'),
          );

          expect(result, isA<VideoUpdateSuccess>());
          expect(capturedTags, contains(equals(subtitleTrack)));
          expect(
            capturedTags.singleWhere((tag) => tag.first == 'imeta'),
            contains('image https://cdn.example.com/new-thumbnail.jpg'),
          );
        },
      );

      test('keeps the subtitles and sound another device added', () async {
        relaysHold(
          newerRevision(
            extraTags: const [
              subtitleTrack,
              audioTag,
              ['allow_audio_reuse', 'true'],
            ],
          ),
        );
        final opened = _testVideo();

        final result = await service.updateVideo(
          originalVideo: opened,
          editorState: editorStateFromPublishedVideo(
            opened,
          ).copyWith(title: 'Edited title'),
          initialCollaboratorPubkeys: const {},
        );

        expect(result, isA<VideoUpdateSuccess>());
        expect(capturedTags, contains(equals(subtitleTrack)));
        expect(capturedTags, contains(equals(audioTag)));
        expect(capturedTags, contains(equals(['allow_audio_reuse', 'true'])));
        expect(capturedTags, contains(equals(['title', 'Edited title'])));
      });

      test(
        'keeps the newest signed summary when editing only the title',
        () async {
          const summary = ['summary', 'Separate summary from another client'];
          relaysHold(
            newerRevision(
              content: 'Caption from the other device',
              extraTags: const [summary],
            ),
          );
          final opened = _testVideo();

          final result = await service.updateVideo(
            originalVideo: opened,
            editorState: editorStateFromPublishedVideo(
              opened,
            ).copyWith(title: 'Edited title'),
            initialCollaboratorPubkeys: const {},
          );

          expect(result, isA<VideoUpdateSuccess>());
          expect(capturedTags, contains(equals(['title', 'Edited title'])));
          expect(capturedTags.where((tag) => tag.first == 'summary'), [
            summary,
          ]);
        },
      );

      test('applies only the fields changed in this edit', () async {
        relaysHold(newerRevision(title: 'Title from the other device'));
        final opened = _testVideo();

        final result = await service.updateVideo(
          originalVideo: opened,
          editorState: editorStateFromPublishedVideo(
            opened,
          ).copyWith(description: 'Caption from this edit'),
          initialCollaboratorPubkeys: const {},
        );

        expect(result, isA<VideoUpdateSuccess>());
        expect(
          capturedTags,
          contains(equals(['title', 'Title from the other device'])),
        );
        expect(
          capturedTags,
          contains(equals(['summary', 'Caption from this edit'])),
        );
      });

      // The editor stores the title and caption trimmed, and the caption cut
      // to its limit, once any metadata field changes. Text that differs from
      // the opened copy only by that was not edited, so a newer value from
      // another device must win.
      test('keeps a newer title and caption when this edit only trimmed '
          'them', () async {
        relaysHold(
          newerRevision(
            title: 'Title from the other device',
            content: 'Caption from the other device',
          ),
        );
        final opened = _testVideo(
          title: '  Opened title ',
          content: ' Opened caption\n',
        );

        final result = await service.updateVideo(
          originalVideo: opened,
          editorState: editorStateFromPublishedVideo(opened).copyWith(
            title: 'Opened title',
            description: 'Opened caption',
            tags: const {'fromthisedit'},
          ),
          initialCollaboratorPubkeys: const {},
        );

        expect(result, isA<VideoUpdateSuccess>());
        expect(
          capturedTags,
          contains(equals(['title', 'Title from the other device'])),
        );
        expect(
          capturedTags,
          contains(equals(['summary', 'Caption from the other device'])),
        );
        expect(capturedTags, contains(equals(['t', 'fromthisedit'])));
      });

      test('keeps a newer caption when this edit only cut the opened one to '
          'the limit', () async {
        relaysHold(newerRevision(content: 'Caption from the other device'));
        // One character but several code units each, so a cut by code unit
        // would not match the editor's.
        final longCaption =
            '👍🏽' * (VideoEditorConstants.descriptionLimit + 1);
        final opened = _testVideo(content: longCaption);

        final result = await service.updateVideo(
          originalVideo: opened,
          editorState: editorStateFromPublishedVideo(opened).copyWith(
            description: longCaption.characters
                .take(VideoEditorConstants.descriptionLimit)
                .toString(),
            tags: const {'fromthisedit'},
          ),
          initialCollaboratorPubkeys: const {},
        );

        expect(result, isA<VideoUpdateSuccess>());
        expect(
          capturedTags,
          contains(equals(['summary', 'Caption from the other device'])),
        );
      });

      test(
        'publishes the cut caption when no other device changed it',
        () async {
          final longCaption = 'x' * (VideoEditorConstants.descriptionLimit + 1);
          relaysHold(newerRevision(content: longCaption));
          final opened = _testVideo(content: longCaption);
          final cut = longCaption.substring(
            0,
            VideoEditorConstants.descriptionLimit,
          );

          final result = await service.updateVideo(
            originalVideo: opened,
            editorState: editorStateFromPublishedVideo(
              opened,
            ).copyWith(description: cut),
            initialCollaboratorPubkeys: const {},
          );

          expect(result, isA<VideoUpdateSuccess>());
          expect(capturedTags, contains(equals(['summary', cut])));
        },
      );

      test('stamps the replacement after the newer revision', () async {
        final newer = NostrTimestamp.now(driftTolerance: 0) + 1000;
        relaysHold(newerRevision(createdAt: newer));
        final opened = _testVideo();

        await service.updateVideo(
          originalVideo: opened,
          editorState: editorStateFromPublishedVideo(opened),
          initialCollaboratorPubkeys: const {},
        );

        expect(capturedCreatedAt, equals(newer + 1));
      });

      test('publishes and invites under the video kind', () async {
        relaysHold(
          newerRevision(kind: NIP71VideoKinds.addressableNormalVideo),
        );
        final opened = _testVideo().copyWith(
          eventKind: NIP71VideoKinds.addressableNormalVideo,
        );

        when(
          () => mockDmRepository.sendMessage(
            recipientPubkey: collaborator,
            content: any(named: 'content'),
            additionalTags: any(named: 'additionalTags'),
            skipNip04Fallback: true,
          ),
        ).thenAnswer(
          (_) async => NIP17SendResult.success(
            rumorEventId: 'rumor-id',
            messageEventId: 'gift-wrap-id',
            recipientPubkey: collaborator,
          ),
        );

        final result = await service.updateVideo(
          originalVideo: opened,
          editorState: editorStateFromPublishedVideo(
            opened,
          ).copyWith(collaboratorPubkeys: const {collaborator}),
          initialCollaboratorPubkeys: const {},
        );

        expect(
          result,
          isA<VideoUpdateSuccess>().having(
            (success) => success.updatedEvent.eventKind,
            'updated video kind',
            NIP71VideoKinds.addressableNormalVideo,
          ),
        );
        verify(
          () => mockVideoEventService.updateVideoEvent(
            any(
              that: isA<VideoEvent>().having(
                (video) => video.eventKind,
                'event kind',
                34235,
              ),
            ),
          ),
        ).called(1);
        verify(
          () => mockNostrClient.readCurrentVersion(
            kind: 34235,
            pubkey: _ownerPubkey,
            dTag: 'video-d-tag',
          ),
        ).called(1);
        verify(
          () => mockAuthService.createAndSignEvent(
            kind: NIP71VideoKinds.addressableNormalVideo,
            content: any(named: 'content'),
            tags: any(named: 'tags'),
            createdAt: any(named: 'createdAt'),
          ),
        ).called(1);
        final invite = verify(
          () => mockDmRepository.sendMessage(
            recipientPubkey: collaborator,
            content: any(named: 'content'),
            additionalTags: captureAny(named: 'additionalTags'),
            skipNip04Fallback: true,
          ),
        );
        final inviteTags = invite.captured.single as List<List<String>>;
        expect(
          parseCollaboratorInviteRumorTags(inviteTags)?.videoAddress,
          '34235:$_ownerPubkey:video-d-tag',
        );
      });

      test('does not re-invite a collaborator the newer revision already '
          'credits', () async {
        relaysHold(
          newerRevision(
            extraTags: const [
              ['p', collaborator, 'wss://relay.divine.video', 'collaborator'],
            ],
          ),
        );
        final opened = _testVideo();

        final result = await service.updateVideo(
          originalVideo: opened,
          editorState: editorStateFromPublishedVideo(opened),
          initialCollaboratorPubkeys: const {},
        );

        expect(result, isA<VideoUpdateSuccess>());
        expect(
          capturedTags,
          contains(
            equals([
              'p',
              collaborator,
              'wss://relay.divine.video',
              'collaborator',
            ]),
          ),
        );
        verifyNever(
          () => mockDmRepository.sendMessage(
            recipientPubkey: any(named: 'recipientPubkey'),
            content: any(named: 'content'),
            additionalTags: any(named: 'additionalTags'),
            skipNip04Fallback: any(named: 'skipNip04Fallback'),
          ),
        );
      });
    });

    group('edited field replacement', () {
      test('keeps every sound credit line under the edited caption', () async {
        // The editor never shows the lines, and an edit cannot change the
        // sounds, so the published credits must survive the edit.
        const credit =
            '♪ Monkeys Spinning Monkeys – Kevin MacLeod (incompetech.com), '
            'CC BY 4.0 https://creativecommons.org/licenses/by/4.0/ (edited)\n'
            '♪ Elevator Music – YellowTree via Freesound, '
            'CC BY 4.0 https://creativecommons.org/licenses/by/4.0/ (edited)';
        String? capturedContent;
        List<List<String>>? capturedTags;
        when(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
            createdAt: any(named: 'createdAt'),
          ),
        ).thenAnswer((invocation) async {
          capturedContent = invocation.namedArguments[#content] as String;
          capturedTags = invocation.namedArguments[#tags] as List<List<String>>;
          return Event(
            _ownerPubkey,
            NIP71VideoKinds.addressableShortVideo,
            capturedTags!,
            capturedContent!,
          );
        });

        final result = await updateFromRelay(
          originalVideo: _testVideo(content: 'Old caption\n\n$credit'),
          editorState: VideoEditorProviderState(description: 'New caption'),
          initialCollaboratorPubkeys: const {},
        );

        expect(result, isA<VideoUpdateSuccess>());
        expect(capturedContent, equals('New caption\n\n$credit'));
        // Clients such as the Bluesky bridge show the summary instead.
        expect(
          capturedTags!.where((tag) => tag.first == 'summary').single[1],
          equals('New caption\n\n$credit'),
        );
      });

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

          final result = await updateFromRelay(
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

      test(
        'keeps an empty title tag on an untitled video so the relay '
        'accepts the replacement',
        () async {
          final video = _testVideo(
            title: null,
            extraTags: const [
              ['title', ''],
              ['summary', 'Old description'],
            ],
          );

          final result = await updateFromRelay(
            originalVideo: video,
            editorState: VideoEditorProviderState(
              title: '   ',
              description: 'New description',
            ),
            initialCollaboratorPubkeys: const {},
          );

          expect(result, isA<VideoUpdateSuccess>());
          expect(
            capturedTags.where((tag) => tag.first == 'title'),
            equals([
              ['title', ''],
            ]),
          );
        },
      );

      test('drops an over-long hashtag when the video is edited', () async {
        final pastedList = 'VineHashtagsMasterList' * 10;
        final video = _testVideo(
          extraTags: [
            ['t', pastedList],
          ],
        );

        final result = await updateFromRelay(
          originalVideo: video,
          editorState: VideoEditorProviderState(
            tags: {pastedList, 'FunnyDivines'},
          ),
          initialCollaboratorPubkeys: const {},
        );

        expect(result, isA<VideoUpdateSuccess>());
        expect(
          capturedTags.where((tag) => tag.first == 't'),
          equals([
            ['t', 'funnydivines'],
          ]),
        );
      });

      test('allows the user to clear hashtags from a complete event', () async {
        final video = _testVideo(
          extraTags: const [
            ['t', 'oldtag'],
            ['proofmode', 'proof-manifest'],
          ],
        );

        final result = await updateFromRelay(
          originalVideo: video,
          editorState: VideoEditorProviderState(),
          initialCollaboratorPubkeys: const {},
        );

        expect(result, isA<VideoUpdateSuccess>());
        expect(capturedTags.where((tag) => tag.first == 't'), isEmpty);
        expect(capturedTags, contains(equals(['proofmode', 'proof-manifest'])));
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

          final result = await updateFromRelay(
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

        final result = await updateFromRelay(
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

      test('keeps a warning label the editor has no option for', () async {
        final video = _testVideo(
          extraTags: const [
            ['content-warning', 'needles'],
            ['L', 'content-warning'],
            ['l', 'needles', 'content-warning'],
          ],
        );

        final result = await updateFromRelay(
          originalVideo: video,
          editorState: VideoEditorProviderState(title: 'Retitled'),
          initialCollaboratorPubkeys: const {},
        );

        expect(result, isA<VideoUpdateSuccess>());
        expect(capturedTags, contains(equals(['content-warning', 'needles'])));
        expect(capturedTags, contains(equals(['L', 'content-warning'])));
        expect(
          capturedTags,
          contains(equals(['l', 'needles', 'content-warning'])),
        );
      });

      test(
        'keeps an unknown warning label when the user removes a known one',
        () async {
          final video = _testVideo(
            extraTags: const [
              ['content-warning', 'nudity'],
              ['L', 'content-warning'],
              ['l', 'nudity', 'content-warning'],
              ['l', 'needles', 'content-warning'],
            ],
          );

          final result = await updateFromRelay(
            originalVideo: video,
            editorState: VideoEditorProviderState(),
            initialCollaboratorPubkeys: const {},
          );

          expect(result, isA<VideoUpdateSuccess>());
          expect(
            capturedTags.where(
              (t) => t.isNotEmpty && t.first == 'content-warning',
            ),
            equals([
              ['content-warning', 'needles'],
            ]),
          );
          expect(capturedTags, contains(equals(['L', 'content-warning'])));
          expect(
            capturedTags.where(
              (t) => t.length >= 3 && t[0] == 'l' && t[2] == 'content-warning',
            ),
            equals([
              ['l', 'needles', 'content-warning'],
            ]),
          );
        },
      );

      test('keeps a content warning that names no reason', () async {
        final video = _testVideo(
          extraTags: const [
            ['content-warning'],
          ],
        );

        final result = await updateFromRelay(
          originalVideo: video,
          editorState: VideoEditorProviderState(title: 'Retitled'),
          initialCollaboratorPubkeys: const {},
        );

        expect(result, isA<VideoUpdateSuccess>());
        expect(
          capturedTags.where(
            (t) => t.isNotEmpty && t.first == 'content-warning',
          ),
          equals([
            ['content-warning'],
          ]),
        );
        expect(
          capturedTags,
          isNot(contains(equals(['L', 'content-warning']))),
        );
      });

      test('keeps a reasonless warning alongside a named one', () async {
        final opened = _testVideo(
          extraTags: const [
            ['content-warning'],
            ['L', 'content-warning'],
            ['l', 'nudity', 'content-warning'],
          ],
        );

        final result = await updateFromRelay(
          originalVideo: opened,
          editorState: editorStateFromPublishedVideo(
            opened,
          ).copyWith(title: 'Retitled'),
          initialCollaboratorPubkeys: const {},
        );

        expect(result, isA<VideoUpdateSuccess>());
        expect(capturedTags, contains(equals(['content-warning'])));
        expect(
          capturedTags,
          contains(equals(['l', 'nudity', 'content-warning'])),
        );
      });

      test(
        'keeps a blank warning reason as a warning with no reason',
        () async {
          final video = _testVideo(
            extraTags: const [
              ['content-warning', ' '],
            ],
          );

          final result = await updateFromRelay(
            originalVideo: video,
            editorState: VideoEditorProviderState(title: 'Retitled'),
            initialCollaboratorPubkeys: const {},
          );

          expect(result, isA<VideoUpdateSuccess>());
          expect(
            capturedTags.where(
              (t) => t.isNotEmpty && t.first == 'content-warning',
            ),
            equals([
              ['content-warning'],
            ]),
          );
          expect(
            capturedTags.where((t) => t.isNotEmpty && t.first == 'l'),
            isEmpty,
          );
        },
      );

      test('replaces collaborator p-tags but keeps mention p-tags', () async {
        const removedCollaborator =
            '7777777777777777777777777777777777777777777777777777777777777777';
        const mentionedPubkey =
            '4444444444444444444444444444444444444444444444444444444444444444';
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

        final result = await updateFromRelay(
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

      test('canonicalizes collaborator tags and invite recipients', () async {
        const collaborator = syntheticTestPubkey;
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

        final result = await updateFromRelay(
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
        expect(collaboratorTags, [
          ['p', collaborator, 'wss://relay.divine.video', 'collaborator'],
        ]);
        verify(
          () => mockDmRepository.sendMessage(
            recipientPubkey: collaborator,
            content: any(named: 'content'),
            additionalTags: any(named: 'additionalTags'),
            skipNip04Fallback: true,
          ),
        ).called(1);
      });

      test('compares existing collaborators in canonical form', () async {
        const collaborator = syntheticTestPubkey;

        final result = await updateFromRelay(
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

      test(
        'keeps the mention marker when the inspired-by video stays the same',
        () async {
          // An Add yours answer names its chain's first video this way, and
          // counts as joined only while the marker is mention.
          final video = _testVideo(
            extraTags: const [
              [
                'a',
                '34236:$_ownerPubkey:first-vid',
                'wss://relay.divine.video',
                'mention',
              ],
            ],
          );
          final editorState = VideoEditorProviderState(
            inspiredByVideo: const InspiredByInfo(
              addressableId: '34236:$_ownerPubkey:first-vid',
              relayUrl: 'wss://relay.divine.video',
            ),
          );

          final result = await updateFromRelay(
            originalVideo: video,
            editorState: editorState,
            initialCollaboratorPubkeys: const {},
          );

          expect(result, isA<VideoUpdateSuccess>());
          final inspiredBy = capturedTags
              .where(
                (tag) =>
                    tag.first == 'a' &&
                    tag[1] == '34236:$_ownerPubkey:first-vid',
              )
              .toList();
          expect(
            inspiredBy,
            equals([
              [
                'a',
                '34236:$_ownerPubkey:first-vid',
                'wss://relay.divine.video',
                'mention',
              ],
            ]),
          );
        },
      );

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

        final result = await updateFromRelay(
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
          const sourceCreator = syntheticTestPubkey;
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

          final result = await updateFromRelay(
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
          const sourceCreatorA = syntheticTestPubkey;
          const sourceCreatorB = syntheticOtherTestPubkey;
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

          final result = await updateFromRelay(
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
              '4444444444444444444444444444444444444444444444444444444444444444';
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

          final result = await updateFromRelay(
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

          final result = await updateFromRelay(
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

          final result = await updateFromRelay(
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
      test(
        'reports invites skipped when the account changes after acceptance',
        () async {
          when(() => mockRelayPublisher.publishViaWebSocket(any()))
              .thenAnswer((_) async {
                when(() => mockAuthService.currentPublicKeyHex)
                    .thenReturn(syntheticTestPubkey);
                return EventPublishOutcome.published;
              });

          final result = await updateFromRelay(
            originalVideo: _testVideo(),
            editorState: VideoEditorProviderState(
              collaboratorPubkeys: const {syntheticOtherTestPubkey},
            ),
            initialCollaboratorPubkeys: const {},
          );

          expect(
            result,
            isA<VideoUpdateSuccess>().having(
              (value) => value.inviteFailureCount,
              'skipped invites',
              1,
            ),
          );
          verifyNever(
            () => mockPersonalEventCacheService.cacheUserEvent(any()),
          );
          verifyNever(() => mockVideoEventService.updateVideoEvent(any()));
        },
      );

      test('returns VideoUpdateSuccess on happy path', () async {
        final result = await updateFromRelay(
          originalVideo: _testVideo(),
          editorState: VideoEditorProviderState(),
          initialCollaboratorPubkeys: const {},
        );

        expect(result, isA<VideoUpdateSuccess>());
      });

      test(
        'publishes through the relay publisher and caches on success',
        () async {
          await updateFromRelay(
            originalVideo: _testVideo(),
            editorState: VideoEditorProviderState(),
            initialCollaboratorPubkeys: const {},
          );

          verify(() => mockRelayPublisher.publishViaWebSocket(any())).called(1);
          verify(
            () => mockPersonalEventCacheService.cacheUserEvent(any()),
          ).called(1);
        },
      );

      test('calls updateVideoEvent on success', () async {
        await updateFromRelay(
          originalVideo: _testVideo(),
          editorState: VideoEditorProviderState(),
          initialCollaboratorPubkeys: const {},
        );

        verify(() => mockVideoEventService.updateVideoEvent(any())).called(1);
      });
    });

    group('publish failure', () {
      test(
        'returns publishRejected and caches nothing when no relay accepts '
        'the edit',
        () async {
          when(
            () => mockRelayPublisher.publishViaWebSocket(any()),
          ).thenAnswer((_) async => EventPublishOutcome.transientFailure);

          final result = await updateFromRelay(
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
        'returns a failure and caches nothing when the relay reports the '
        'account restricted',
        () async {
          when(
            () => mockRelayPublisher.publishViaWebSocket(any()),
          ).thenThrow(
            const AccountRestrictedPublishException(
              reason: 'blocked: account suspended',
              source: AccountRestrictionSource.webSocket,
            ),
          );

          final result = await updateFromRelay(
            originalVideo: _testVideo(),
            editorState: VideoEditorProviderState(),
            initialCollaboratorPubkeys: const {},
          );

          expect(
            result,
            isA<VideoUpdateFailure>().having(
              (f) => f.reason,
              'reason',
              VideoMetadataUpdateError.generic,
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

          final result = await updateFromRelay(
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
          verifyNever(() => mockRelayPublisher.publishViaWebSocket(any()));
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

          final result = await updateFromRelay(
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
          verifyNever(() => mockRelayPublisher.publishViaWebSocket(any()));
        },
      );
    });

    group('invite failure', () {
      const newCollaborator = syntheticTestPubkey;

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

        final result = await updateFromRelay(
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

          final result = await updateFromRelay(
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
          final result = await updateFromRelay(
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
      const inspiredCreator = syntheticTestPubkey;
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

        final result = await updateFromRelay(
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

        final result = await updateFromRelay(
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

        final result = await updateFromRelay(
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

        final result = await updateFromRelay(
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

        final result = await updateFromRelay(
          originalVideo: _testVideo(),
          editorState: VideoEditorProviderState(inspiredByNpubs: [npub]),
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

        final result = await updateFromRelay(
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

        final result = await updateFromRelay(
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

        final result = await updateFromRelay(
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

          final result = await updateFromRelay(
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

        final result = await updateFromRelay(
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
        final result = await updateFromRelay(
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
