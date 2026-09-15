// ABOUTME: Tests collaborator role p-tags emitted by VideoEventPublisher.
// ABOUTME: Ensures pending collabs are explicit role tags, not generic mentions.

import 'package:collection/collection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:nostr_sdk/relay/publish_outcome.dart';
import 'package:openvine/constants/nip71_migration.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/upload_manager.dart';
import 'package:openvine/services/video_event_publisher.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/utils/collaborator_tags.dart';
import 'package:openvine/utils/nostr_key_utils.dart';

class _MockUploadManager extends Mock implements UploadManager {}

class _MockNostrClient extends Mock implements NostrClient {}

class _MockAuthService extends Mock implements AuthService {}

class _MockVideoEventService extends Mock implements VideoEventService {}

class _FakeEvent extends Fake implements Event {}

class _FakeFilter extends Fake implements Filter {}

const _deepEquals = DeepCollectionEquality();

bool _containsTag(List<List<String>> tags, List<String> expected) {
  return tags.any((tag) => _deepEquals.equals(tag, expected));
}

void main() {
  late _MockUploadManager uploadManager;
  late _MockNostrClient nostrClient;
  late _MockAuthService authService;
  late _MockVideoEventService videoEventService;
  late VideoEventPublisher publisher;
  late List<List<String>> capturedTags;

  const testPubkey =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const collaboratorPubkey =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
  const mentionPubkey =
      'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
  const secondMentionPubkey =
      'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';

  setUpAll(() {
    registerFallbackValue(_FakeEvent());
    registerFallbackValue(_FakeFilter());
    registerFallbackValue(<Filter>[]);
    registerFallbackValue(UploadStatus.pending);
    registerFallbackValue(Duration.zero);
  });

  setUp(() {
    uploadManager = _MockUploadManager();
    nostrClient = _MockNostrClient();
    authService = _MockAuthService();
    videoEventService = _MockVideoEventService();
    capturedTags = [];

    publisher = VideoEventPublisher(
      uploadManager: uploadManager,
      nostrService: nostrClient,
      authService: authService,
      videoEventService: videoEventService,
    );

    when(() => nostrClient.isInitialized).thenReturn(true);
    when(() => nostrClient.configuredRelayCount).thenReturn(1);
    when(() => nostrClient.connectedRelayCount).thenReturn(1);
    when(
      () => nostrClient.configuredRelays,
    ).thenReturn(['wss://relay.divine.video']);
    when(
      () => nostrClient.connectedRelays,
    ).thenReturn(['wss://relay.divine.video']);
    when(() => nostrClient.publicKey).thenReturn('');

    when(() => authService.isAuthenticated).thenReturn(true);
    when(() => authService.currentPublicKeyHex).thenReturn(testPubkey);

    when(
      () => uploadManager.updateUploadStatus(
        any(),
        any(),
        nostrEventId: any(named: 'nostrEventId'),
      ),
    ).thenAnswer((_) async {});
  });

  PendingUpload createUpload() {
    return PendingUpload(
      id: 'upload-id',
      localVideoPath: '',
      nostrPubkey: testPubkey,
      status: UploadStatus.readyToPublish,
      createdAt: DateTime.now(),
      videoId: 'video-id',
      cdnUrl: 'https://cdn.example.com/video.mp4',
      fallbackUrl: 'https://cdn.example.com/video.mp4',
    );
  }

  void stubSignAndPublish() {
    late Event publishedEvent;

    when(
      () => authService.createAndSignEvent(
        kind: any(named: 'kind'),
        content: any(named: 'content'),
        tags: any(named: 'tags'),
      ),
    ).thenAnswer((invocation) async {
      capturedTags = invocation.namedArguments[#tags] as List<List<String>>;
      return publishedEvent = Event(
        testPubkey,
        NIP71VideoKinds.getPreferredAddressableKind(),
        capturedTags,
        'test content',
      );
    });

    when(
      () => nostrClient.publishEventAwaitOk(
        any(),
        timeout: any(named: 'timeout'),
      ),
    ).thenAnswer(
      (_) async => PublishOutcome(
        eventId: publishedEvent.id,
        acceptedBy: const ['wss://relay.divine.video'],
        rejectedBy: const {},
        noResponseFrom: const [],
      ),
    );
    when(
      () => nostrClient.queryEvents(
        any(),
        subscriptionId: any(named: 'subscriptionId'),
        tempRelays: any(named: 'tempRelays'),
        relayTypes: any(named: 'relayTypes'),
        sendAfterAuth: any(named: 'sendAfterAuth'),
        useCache: any(named: 'useCache'),
      ),
    ).thenAnswer((_) async => <Event>[publishedEvent]);
  }

  group('publishDirectUpload', () {
    test(
      'publishes collaborator p-tags with lowercase collaborator marker',
      () async {
        stubSignAndPublish();

        final result = await publisher.publishDirectUpload(
          createUpload(),
          collaboratorPubkeys: const [collaboratorPubkey],
        );

        expect(result, isTrue);
        expect(
          _containsTag(capturedTags, buildCollaboratorPTag(collaboratorPubkey)),
          isTrue,
        );
        // Verify no capitalized form is emitted
        expect(
          _containsTag(capturedTags, const [
            'p',
            collaboratorPubkey,
            'wss://relay.divine.video',
            'Collaborator',
          ]),
          isFalse,
        );
      },
    );

    test(
      'publishes generic mention p-tags while preserving collaborator role tags',
      () async {
        stubSignAndPublish();

        final result = await publisher.publishDirectUpload(
          createUpload(),
          collaboratorPubkeys: const [collaboratorPubkey],
          mentionedPubkeys: const [
            mentionPubkey,
            collaboratorPubkey,
            '',
            'not-a-valid-pubkey',
            mentionPubkey,
            secondMentionPubkey,
          ],
        );

        expect(result, isTrue);
        expect(
          _containsTag(capturedTags, buildCollaboratorPTag(collaboratorPubkey)),
          isTrue,
          reason: 'collaborator pubkeys keep the collaborator role marker',
        );
        expect(
          _containsTag(capturedTags, const [
            'p',
            mentionPubkey,
            'wss://relay.divine.video',
            'mention',
          ]),
          isTrue,
        );
        expect(
          _containsTag(capturedTags, const [
            'p',
            secondMentionPubkey,
            'wss://relay.divine.video',
            'mention',
          ]),
          isTrue,
        );
        expect(
          capturedTags
              .where(
                (tag) => _deepEquals.equals(tag, const [
                  'p',
                  mentionPubkey,
                  'wss://relay.divine.video',
                  'mention',
                ]),
              )
              .length,
          equals(1),
          reason: 'duplicate full hex mention pubkeys are emitted once',
        );
        expect(
          _containsTag(capturedTags, const [
            'p',
            collaboratorPubkey,
            'wss://relay.divine.video',
            'mention',
          ]),
          isFalse,
          reason: 'collaborator pubkeys are not duplicated as generic mentions',
        );
        expect(
          capturedTags.any((tag) => tag.length > 1 && tag[1].isEmpty),
          isFalse,
          reason: 'empty mention pubkeys are skipped',
        );
        expect(
          capturedTags.any(
            (tag) => tag.length > 1 && tag[1] == 'not-a-valid-pubkey',
          ),
          isFalse,
          reason: 'invalid mention pubkeys are skipped',
        );
      },
    );

    test('emits only canonical collaborator p-tags', () async {
      stubSignAndPublish();

      final result = await publisher.publishDirectUpload(
        createUpload(),
        collaboratorPubkeys: [
          collaboratorPubkey.toUpperCase(),
          NostrKeyUtils.encodePubKey(collaboratorPubkey),
          'not-a-pubkey',
        ],
      );

      expect(result, isTrue);
      final collaboratorTags = capturedTags
          .where((tag) => tag.length >= 4 && tag[3] == 'collaborator')
          .toList();
      expect(collaboratorTags, [buildCollaboratorPTag(collaboratorPubkey)]);
    });
  });
}
