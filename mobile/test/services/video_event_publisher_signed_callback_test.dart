// ABOUTME: Pins that the onEventSigned progress step only fires once an event
// ABOUTME: actually exists, so a failed signing cannot advance the publish bar.

import 'dart:io';

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

  group(VideoEventPublisher, () {
    late _MockUploadManager uploadManager;
    late _MockNostrClient nostrClient;
    late _MockAuthService authService;
    late _MockVideoEventService videoEventService;
    late VideoEventPublisher publisher;
    late Directory testDir;
    late File videoFile;
    late int signedSteps;

    const testPubkey =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
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
      testDir = await Directory.systemTemp.createTemp('signed_callback_test_');
      videoFile = File('${testDir.path}/video.mp4')
        ..writeAsBytesSync([1, 2, 3]);

      uploadManager = _MockUploadManager();
      nostrClient = _MockNostrClient();
      authService = _MockAuthService();
      videoEventService = _MockVideoEventService();
      signedSteps = 0;

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

    PendingUpload createUpload() => PendingUpload(
      id: 'upload-id',
      localVideoPath: videoFile.path,
      nostrPubkey: testPubkey,
      status: UploadStatus.readyToPublish,
      createdAt: DateTime.now(),
      videoId: uploadedDigest,
      cdnUrl: 'https://cdn.example.com/video.mp4',
      fallbackUrl: 'https://cdn.example.com/video.mp4',
      thumbnailPath: 'https://cdn.example.com/thumb.jpg',
    );

    group('onEventSigned', () {
      test('does not report the signing step when signing fails', () async {
        when(
          () => authService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((_) async => null);

        final result = await publisher.publishDirectUpload(
          createUpload(),
          onEventSigned: () => signedSteps++,
        );

        expect(result, isFalse);
        expect(
          signedSteps,
          isZero,
          reason:
              'the bar advanced to the signing step for an event that '
              'was never signed',
        );
      });

      test('reports the signing step once the event is signed', () async {
        late Event signedEvent;
        when(
          () => authService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((invocation) async {
          return signedEvent = Event(
            testPubkey,
            NIP71VideoKinds.getPreferredAddressableKind(),
            invocation.namedArguments[#tags] as List<List<String>>,
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
            eventId: signedEvent.id,
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
        ).thenAnswer((_) async => <Event>[signedEvent]);

        final result = await publisher.publishDirectUpload(
          createUpload(),
          onEventSigned: () => signedSteps++,
        );

        expect(result, isTrue);
        expect(signedSteps, equals(1));
      });
    });
  });
}
