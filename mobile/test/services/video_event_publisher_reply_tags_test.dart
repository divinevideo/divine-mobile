// ABOUTME: Tests video reply tags emitted by VideoEventPublisher.
// ABOUTME: Ensures comment video replies publish as NIP-71 video events.

import 'package:collection/collection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart'
    show VideoEvent, videoReplyVisibilityFeedValue, videoReplyVisibilityTagName;
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:nostr_sdk/relay/publish_outcome.dart';
import 'package:openvine/constants/nip71_migration.dart';
import 'package:openvine/models/video_reply_context.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/upload_manager.dart';
import 'package:openvine/services/video_event_publisher.dart';
import 'package:openvine/services/video_event_service.dart';

class _MockUploadManager extends Mock implements UploadManager {}

class _MockNostrClient extends Mock implements NostrClient {}

class _MockAuthService extends Mock implements AuthService {}

class _MockVideoEventService extends Mock implements VideoEventService {}

class _FakeEvent extends Fake implements Event {}

class _FakeFilter extends Fake implements Filter {}

class _FakeVideoEvent extends Fake implements VideoEvent {}

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
  const rootEventId =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
  const rootAuthorPubkey =
      'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
  const parentCommentId =
      'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
  const parentAuthorPubkey =
      'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
  const rootAddressableId = '34236:$rootAuthorPubkey:root-video';

  setUpAll(() {
    registerFallbackValue(_FakeEvent());
    registerFallbackValue(_FakeFilter());
    registerFallbackValue(_FakeVideoEvent());
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
        'reply title',
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
    test('adds NIP-22 root tags for a top-level video reply', () async {
      stubSignAndPublish();

      final result = await publisher.publishDirectUpload(
        createUpload(),
        replyContext: const VideoReplyContext(
          rootEventId: rootEventId,
          rootEventKind: 34236,
          rootAuthorPubkey: rootAuthorPubkey,
          rootAddressableId: rootAddressableId,
        ),
      );

      expect(result, isTrue);
      expect(
        _containsTag(capturedTags, const [
          'E',
          rootEventId,
          '',
          rootAuthorPubkey,
        ]),
        isTrue,
      );
      expect(
        _containsTag(capturedTags, const ['A', rootAddressableId, '']),
        isTrue,
      );
      expect(_containsTag(capturedTags, const ['K', '34236']), isTrue);
      expect(_containsTag(capturedTags, const ['P', rootAuthorPubkey]), isTrue);
      expect(
        _containsTag(capturedTags, const [
          'e',
          rootEventId,
          '',
          rootAuthorPubkey,
        ]),
        isTrue,
      );
      expect(
        _containsTag(capturedTags, const ['a', rootAddressableId, '']),
        isTrue,
      );
      expect(_containsTag(capturedTags, const ['k', '34236']), isTrue);
      expect(_containsTag(capturedTags, const ['p', rootAuthorPubkey]), isTrue);
      verifyNever(() => videoEventService.addVideoEvent(any()));
    });

    test('adds NIP-22 parent tags for a nested video reply', () async {
      stubSignAndPublish();

      final result = await publisher.publishDirectUpload(
        createUpload(),
        replyContext: const VideoReplyContext(
          rootEventId: rootEventId,
          rootEventKind: 34236,
          rootAuthorPubkey: rootAuthorPubkey,
          rootAddressableId: rootAddressableId,
          parentCommentId: parentCommentId,
          parentAuthorPubkey: parentAuthorPubkey,
        ),
      );

      expect(result, isTrue);
      expect(
        _containsTag(capturedTags, const [
          'E',
          rootEventId,
          '',
          rootAuthorPubkey,
        ]),
        isTrue,
      );
      expect(
        _containsTag(capturedTags, const ['A', rootAddressableId, '']),
        isTrue,
      );
      expect(
        _containsTag(capturedTags, const [
          'e',
          parentCommentId,
          '',
          parentAuthorPubkey,
        ]),
        isTrue,
      );
      expect(_containsTag(capturedTags, const ['k', '1111']), isTrue);
      expect(
        _containsTag(capturedTags, const ['p', parentAuthorPubkey]),
        isTrue,
      );
    });

    test('can opt a video reply into normal feed visibility', () async {
      stubSignAndPublish();

      final result = await publisher.publishDirectUpload(
        createUpload(),
        replyContext: const VideoReplyContext(
          rootEventId: rootEventId,
          rootEventKind: 34236,
          rootAuthorPubkey: rootAuthorPubkey,
          rootAddressableId: rootAddressableId,
        ),
        addReplyToFeed: true,
      );

      expect(result, isTrue);
      expect(
        _containsTag(capturedTags, const [
          videoReplyVisibilityTagName,
          videoReplyVisibilityFeedValue,
        ]),
        isTrue,
      );
      verify(() => videoEventService.addVideoEvent(any())).called(1);
    });
  });
}
