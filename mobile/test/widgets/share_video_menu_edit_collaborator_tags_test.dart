// ABOUTME: Regression coverage for collaborator p-tags in the edit-video flow.
// ABOUTME: Verifies the shared collaborator tag builder contract and that
// ABOUTME: VideoMetadataUpdateService emits that tag when republishing.

import 'dart:ui' show Locale;

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/auth_state.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/services/collaborator_invite_service.dart';
import 'package:openvine/services/personal_event_cache_service.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/services/video_metadata_update_service.dart';
import 'package:openvine/utils/collaborator_tags.dart';

import '../helpers/test_provider_overrides.dart';

class _MockBlossomUploadService extends Mock implements BlossomUploadService {}

class _MockDmRepository extends Mock implements DmRepository {}

class _MockPersonalEventCacheService extends Mock
    implements PersonalEventCacheService {}

class _MockVideoEventService extends Mock implements VideoEventService {}

class _FakeEvent extends Fake implements Event {}

class _FakeVideoEvent extends Fake implements VideoEvent {}

VideoEvent _testVideo({
  required String ownerPubkey,
  required String collaboratorPubkey,
}) {
  return VideoEvent(
    id: 'event-id',
    pubkey: ownerPubkey,
    createdAt: 1757385263,
    content: 'Test video content',
    timestamp: DateTime.fromMillisecondsSinceEpoch(1757385263 * 1000),
    videoUrl: 'https://cdn.example.com/video.mp4',
    title: 'Test Video Title',
    vineId: 'video-d-tag',
    collaboratorPubkeys: [collaboratorPubkey],
    nostrEventTags: const [
      ['imeta', 'url https://cdn.example.com/video.mp4', 'm video/mp4'],
    ],
  );
}

void main() {
  const ownerPubkey =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const collaboratorPubkey =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

  late MockAuthService mockAuthService;
  late MockNostrClient mockNostrService;
  late _MockBlossomUploadService mockBlossomUploadService;
  late _MockDmRepository mockDmRepository;
  late _MockPersonalEventCacheService mockPersonalEventCacheService;
  late _MockVideoEventService mockVideoEventService;
  late VideoMetadataUpdateService service;
  late List<List<String>> capturedTags;

  setUpAll(() {
    registerFallbackValue(_FakeEvent());
    registerFallbackValue(_FakeVideoEvent());
  });

  setUp(() {
    mockAuthService = createMockAuthService(
      authState: AuthState.authenticated,
      currentPublicKeyHex: ownerPubkey,
    );
    mockNostrService = createMockNostrService();
    mockBlossomUploadService = _MockBlossomUploadService();
    mockDmRepository = _MockDmRepository();
    mockPersonalEventCacheService = _MockPersonalEventCacheService();
    mockVideoEventService = _MockVideoEventService();
    capturedTags = [];

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
      return signedEvent = Event(
        ownerPubkey,
        NIP71VideoKinds.addressableShortVideo,
        capturedTags,
        invocation.namedArguments[#content] as String,
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

  group('buildCollaboratorPTag', () {
    test(
      'buildCollaboratorPTag emits the exact lowercase collaborator tag',
      () {
        expect(
          buildCollaboratorPTag(collaboratorPubkey),
          equals(const [
            'p',
            collaboratorPubkey,
            collaboratorInviteRelayHint,
            'collaborator',
          ]),
        );
      },
    );
  });

  group('updateVideo', () {
    test(
      'edit-video flow republishes collaborator p-tags with lowercase marker',
      () async {
        final editorState = VideoEditorProviderState(
          collaboratorPubkeys: {collaboratorPubkey},
        );

        final result = await service.updateVideo(
          originalVideo: _testVideo(
            ownerPubkey: ownerPubkey,
            collaboratorPubkey: collaboratorPubkey,
          ),
          editorState: editorState,
          initialCollaboratorPubkeys: {collaboratorPubkey},
        );

        expect(result, isA<VideoUpdateSuccess>());
        expect(
          capturedTags.where((tag) => tag.isNotEmpty && tag.first == 'p'),
          hasLength(1),
        );
        expect(
          capturedTags,
          contains(equals(buildCollaboratorPTag(collaboratorPubkey))),
        );
        expect(
          capturedTags,
          isNot(
            contains(
              equals(const [
                'p',
                collaboratorPubkey,
                collaboratorInviteRelayHint,
                'Collaborator',
              ]),
            ),
          ),
        );
      },
    );
  });
}
