// ABOUTME: Tests for NIP-32 language tagging in VideoEventPublisher
// ABOUTME: Verifies that L and l tags are correctly added to published events

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

class _MockUploadManager extends Mock implements UploadManager {}

class _MockNostrClient extends Mock implements NostrClient {}

class _MockAuthService extends Mock implements AuthService {}

class _MockVideoEventService extends Mock implements VideoEventService {}

// Fake fallback values for mocktail any() matchers
class _FakeEvent extends Fake implements Event {}

class _FakeFilter extends Fake implements Filter {}

const _deepEquals = DeepCollectionEquality();

/// Checks whether [tags] contains a tag that deeply equals [expected].
bool _containsTag(List<List<String>> tags, List<String> expected) {
  return tags.any((t) => _deepEquals.equals(t, expected));
}

void main() {
  late _MockUploadManager mockUploadManager;
  late _MockNostrClient mockNostrClient;
  late _MockAuthService mockAuthService;
  late _MockVideoEventService mockVideoEventService;
  late VideoEventPublisher publisher;

  final testPubkey = 'a' * 64;

  setUpAll(() {
    registerFallbackValue(_FakeEvent());
    registerFallbackValue(_FakeFilter());
    registerFallbackValue(<Filter>[]);
    registerFallbackValue(UploadStatus.pending);
    registerFallbackValue(Duration.zero);
  });

  setUp(() {
    mockUploadManager = _MockUploadManager();
    mockNostrClient = _MockNostrClient();
    mockAuthService = _MockAuthService();
    mockVideoEventService = _MockVideoEventService();

    publisher = VideoEventPublisher(
      uploadManager: mockUploadManager,
      nostrService: mockNostrClient,
      authService: mockAuthService,
      videoEventService: mockVideoEventService,
    );

    // Stub NostrClient properties used by _publishEventToNostr
    when(() => mockNostrClient.isInitialized).thenReturn(true);
    when(() => mockNostrClient.configuredRelayCount).thenReturn(1);
    when(() => mockNostrClient.connectedRelayCount).thenReturn(1);
    when(
      () => mockNostrClient.configuredRelays,
    ).thenReturn(['wss://relay.divine.video']);
    when(
      () => mockNostrClient.connectedRelays,
    ).thenReturn(['wss://relay.divine.video']);
    // Return empty publicKey to skip profile stats cache invalidation
    when(() => mockNostrClient.publicKey).thenReturn('');

    // Stub auth service
    when(() => mockAuthService.isAuthenticated).thenReturn(true);
    when(() => mockAuthService.currentPublicKeyHex).thenReturn(testPubkey);

    // Stub upload manager
    when(
      () => mockUploadManager.updateUploadStatus(
        any(),
        any(),
        nostrEventId: any(named: 'nostrEventId'),
      ),
    ).thenAnswer((_) async {});
  });

  PendingUpload createTestUpload() {
    return PendingUpload(
      id: 'test-upload-id',
      localVideoPath: '',
      nostrPubkey: testPubkey,
      status: UploadStatus.readyToPublish,
      createdAt: DateTime.now(),
      videoId: 'test-video-id',
      cdnUrl: 'https://cdn.example.com/video.mp4',
      fallbackUrl: 'https://cdn.example.com/video.mp4',
    );
  }

  /// Helper that captures the tags passed to createAndSignEvent.
  List<List<String>>? capturedTags;

  void stubSignAndPublish() {
    late Event publishedEvent;

    when(
      () => mockAuthService.createAndSignEvent(
        kind: any(named: 'kind'),
        content: any(named: 'content'),
        tags: any(named: 'tags'),
      ),
    ).thenAnswer((invocation) async {
      capturedTags = invocation.namedArguments[#tags] as List<List<String>>?;
      final tags = capturedTags ?? [];
      return publishedEvent = Event(
        testPubkey,
        NIP71VideoKinds.getPreferredAddressableKind(),
        tags,
        'test content',
      );
    });

    when(
      () => mockNostrClient.publishEventAwaitOk(
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
      () => mockNostrClient.queryEvents(
        any(),
        subscriptionId: any(named: 'subscriptionId'),
        tempRelays: any(named: 'tempRelays'),
        relayTypes: any(named: 'relayTypes'),
        sendAfterAuth: any(named: 'sendAfterAuth'),
        useCache: any(named: 'useCache'),
      ),
    ).thenAnswer((_) async => <Event>[publishedEvent]);
  }

  group('NIP-32 language tagging', () {
    test('adds L and l tags when language is provided', () async {
      stubSignAndPublish();

      await publisher.publishDirectUpload(createTestUpload(), language: 'en');

      expect(capturedTags, isNotNull);
      expect(
        _containsTag(capturedTags!, ['L', 'ISO-639-1']),
        isTrue,
        reason: 'Expected L namespace tag for ISO-639-1',
      );
      expect(
        _containsTag(capturedTags!, ['l', 'en', 'ISO-639-1']),
        isTrue,
        reason: 'Expected l tag with language code "en"',
      );
    });

    test('adds correct language code for non-English languages', () async {
      stubSignAndPublish();

      await publisher.publishDirectUpload(createTestUpload(), language: 'pt');

      expect(capturedTags, isNotNull);
      expect(_containsTag(capturedTags!, ['L', 'ISO-639-1']), isTrue);
      expect(
        _containsTag(capturedTags!, ['l', 'pt', 'ISO-639-1']),
        isTrue,
        reason: 'Expected l tag with language code "pt"',
      );
    });

    test('does not add language tags when language is null', () async {
      stubSignAndPublish();

      await publisher.publishDirectUpload(createTestUpload());

      expect(capturedTags, isNotNull);
      expect(
        _containsTag(capturedTags!, ['L', 'ISO-639-1']),
        isFalse,
        reason: 'Should not have L tag when language is null',
      );
      // Verify no l tags with ISO-639-1 namespace exist
      final hasLTag = capturedTags!.any(
        (t) => t.length >= 3 && t[0] == 'l' && t[2] == 'ISO-639-1',
      );
      expect(
        hasLTag,
        isFalse,
        reason: 'Should not have l tag when language is null',
      );
    });

    test('does not add language tags when language is empty string', () async {
      stubSignAndPublish();

      await publisher.publishDirectUpload(createTestUpload(), language: '');

      expect(capturedTags, isNotNull);
      expect(
        _containsTag(capturedTags!, ['L', 'ISO-639-1']),
        isFalse,
        reason: 'Should not have L tag when language is empty',
      );
    });

    test('language tags are added via publishVideoEvent passthrough', () async {
      stubSignAndPublish();

      await publisher.publishVideoEvent(
        upload: createTestUpload(),
        language: 'es',
      );

      expect(capturedTags, isNotNull);
      expect(_containsTag(capturedTags!, ['L', 'ISO-639-1']), isTrue);
      expect(
        _containsTag(capturedTags!, ['l', 'es', 'ISO-639-1']),
        isTrue,
        reason: 'publishVideoEvent should pass language to publishDirectUpload',
      );
    });
  });

  group('NIP-32 content warning tagging', () {
    test('adds content-warning tags when labels are provided', () async {
      stubSignAndPublish();

      await publisher.publishDirectUpload(
        createTestUpload(),
        contentWarning: 'nudity,violence',
      );

      expect(capturedTags, isNotNull);
      expect(
        _containsTag(capturedTags!, ['content-warning', 'nudity']),
        isTrue,
      );
      expect(_containsTag(capturedTags!, ['L', 'content-warning']), isTrue);
      expect(
        _containsTag(capturedTags!, ['l', 'nudity', 'content-warning']),
        isTrue,
      );
      expect(
        _containsTag(capturedTags!, ['l', 'violence', 'content-warning']),
        isTrue,
      );
    });

    test('publishVideoEvent passes contentWarning through', () async {
      stubSignAndPublish();

      await publisher.publishVideoEvent(
        upload: createTestUpload(),
        contentWarning: 'drugs',
      );

      expect(capturedTags, isNotNull);
      expect(_containsTag(capturedTags!, ['content-warning', 'drugs']), isTrue);
      expect(
        _containsTag(capturedTags!, ['l', 'drugs', 'content-warning']),
        isTrue,
      );
    });

    test('does not add content-warning tags when labels are empty', () async {
      stubSignAndPublish();

      await publisher.publishDirectUpload(
        createTestUpload(),
        contentWarning: '',
      );

      expect(capturedTags, isNotNull);
      expect(
        capturedTags!.any(
          (tag) => tag.isNotEmpty && tag.first == 'content-warning',
        ),
        isFalse,
      );
      expect(
        capturedTags!.any(
          (tag) =>
              tag.length >= 3 && tag[0] == 'l' && tag[2] == 'content-warning',
        ),
        isFalse,
      );
    });
  });
}
