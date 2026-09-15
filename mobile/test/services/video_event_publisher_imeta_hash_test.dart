// ABOUTME: Pins that the imeta `x` digest is reused from the content-addressed
// ABOUTME: upload instead of re-hashing the whole video file at publish time.

import 'dart:io';

import 'package:crypto/crypto.dart';
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

class _FakeEvent extends Fake implements Event {}

class _FakeFilter extends Fake implements Filter {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockUploadManager uploadManager;
  late _MockNostrClient nostrClient;
  late _MockAuthService authService;
  late _MockVideoEventService videoEventService;
  late VideoEventPublisher publisher;
  late List<List<String>> capturedTags;
  late Directory testDir;
  late File videoFile;

  const testPubkey =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const videoBytes = [1, 2, 3, 4, 5];

  /// The digest the upload would have streamed and stored as `videoId`.
  const uploadedDigest =
      '1111111111111111111111111111111111111111111111111111111111111111';

  setUpAll(() {
    registerFallbackValue(_FakeEvent());
    registerFallbackValue(_FakeFilter());
    registerFallbackValue(<Filter>[]);
    registerFallbackValue(UploadStatus.pending);
    registerFallbackValue(Duration.zero);
  });

  setUp(() async {
    testDir = await Directory.systemTemp.createTemp('imeta_hash_test_');
    videoFile = File('${testDir.path}/video.mp4')..writeAsBytesSync(videoBytes);

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

  tearDown(() async {
    try {
      await testDir.delete(recursive: true);
    } catch (_) {}
  });

  PendingUpload createUpload({required String? videoId, String? blurhash}) {
    return PendingUpload(
      id: 'upload-id',
      localVideoPath: videoFile.path,
      nostrPubkey: testPubkey,
      status: UploadStatus.readyToPublish,
      createdAt: DateTime.now(),
      videoId: videoId,
      cdnUrl: 'https://cdn.example.com/video.mp4',
      fallbackUrl: 'https://cdn.example.com/video.mp4',
      thumbnailPath: 'https://cdn.example.com/thumb.jpg',
      blurhash: blurhash,
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

  /// The value of the imeta component introduced by [prefix].
  String? capturedImeta(String prefix) {
    final imeta = capturedTags.firstWhere(
      (tag) => tag.isNotEmpty && tag.first == 'imeta',
      orElse: () => const <String>[],
    );
    for (final component in imeta) {
      if (component.startsWith('$prefix ')) {
        return component.substring(prefix.length + 1);
      }
    }
    return null;
  }

  /// The `x <digest>` component of the emitted imeta tag.
  String? capturedDigest() => capturedImeta('x');

  group('publishDirectUpload', () {
    test('reuses the digest the upload already computed', () async {
      stubSignAndPublish();

      final result = await publisher.publishDirectUpload(
        createUpload(videoId: uploadedDigest),
      );

      expect(result, isTrue);
      expect(capturedDigest(), equals(uploadedDigest));
      // Re-hashing the file would produce this instead — the whole point is that
      // the video is never read back at publish time.
      expect(
        capturedDigest(),
        isNot(equals(sha256.convert(videoBytes).toString())),
      );
    });

    test('emits the digest even when the local file is already gone', () async {
      stubSignAndPublish();

      // Funnelcake materializes events_local.sha256 from this sub-field and
      // joins moderation labels on it — a publish landing after local cleanup
      // must still carry x, even though size (which needs the file) cannot.
      await videoFile.delete();

      final result = await publisher.publishDirectUpload(
        createUpload(videoId: uploadedDigest),
      );

      expect(result, isTrue);
      expect(capturedDigest(), equals(uploadedDigest));
    });

    test('reuses the blurhash the thumbnail leg already derived', () async {
      stubSignAndPublish();

      final result = await publisher.publishDirectUpload(
        createUpload(videoId: uploadedDigest, blurhash: 'LEHV6nWB2yk8pyoJadR*'),
      );

      expect(result, isTrue);
      // Decoding the video again here would yield nothing for these bytes, so a
      // present value proves it came from the record.
      expect(capturedImeta('blurhash'), equals('LEHV6nWB2yk8pyoJadR*'));
    });
  });
}
