import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' show NativeProofData, VideoEvent;
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:nostr_sdk/relay/publish_outcome.dart';
import 'package:openvine/models/pending_upload.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/upload_manager.dart';
import 'package:openvine/services/video_event_publisher.dart';

class MockAuthService extends Mock implements AuthService {}

class MockNostrService extends Mock implements NostrClient {}

class MockUploadManager extends Mock implements UploadManager {}

class _FakeFilter extends Fake implements Filter {}

void main() {
  setUpAll(() {
    registerFallbackValue(
      Event.fromJson({
        'id': 'test',
        'pubkey': 'test',
        'created_at': 0,
        'kind': 34236,
        'tags': [],
        'content': '',
        'sig': 'test',
      }),
    );
    registerFallbackValue(UploadStatus.pending);
    registerFallbackValue(_FakeFilter());
    registerFallbackValue(<Filter>[]);
    registerFallbackValue(Duration.zero);
  });

  group('VideoEventPublisher - CAWG identity tag integration', () {
    late MockNostrService mockNostrService;
    late MockAuthService mockAuthService;
    late MockUploadManager mockUploadManager;
    late VideoEventPublisher publisher;
    late Event? capturedEvent;

    setUp(() {
      mockNostrService = MockNostrService();
      mockAuthService = MockAuthService();
      mockUploadManager = MockUploadManager();
      capturedEvent = null;

      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(() => mockNostrService.isInitialized).thenReturn(true);
      when(() => mockNostrService.configuredRelayCount).thenReturn(1);
      when(() => mockNostrService.connectedRelayCount).thenReturn(1);
      when(
        () => mockNostrService.configuredRelays,
      ).thenReturn(const <String>['wss://relay.divine.video']);
      when(
        () => mockNostrService.connectedRelays,
      ).thenReturn(const <String>['wss://relay.divine.video']);
      when(() => mockNostrService.publicKey).thenReturn(
        '385c3a6ec0b9d57a4330dbd6284989be5bd00e41c535f9ca39b6ae7c521b81cd',
      );
      when(() => mockNostrService.initialize()).thenAnswer((_) async {});

      when(
        () => mockUploadManager.updateUploadStatus(
          any(),
          any(),
          nostrEventId: any(named: 'nostrEventId'),
        ),
      ).thenAnswer((_) async => {});

      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((invocation) async {
        final tags = invocation.namedArguments[#tags] as List<List<String>>;
        final content = invocation.namedArguments[#content] as String;
        capturedEvent = Event.fromJson({
          'id': 'event123',
          'pubkey': '385c3a6ec0b9d57a4330dbd6284989be5bd00e41c535f9ca39b6ae7c521b81cd',
          'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'kind': 34236,
          'tags': tags,
          'content': content,
          'sig': 'signature123',
        });
        return capturedEvent!;
      });

      when(
        () => mockNostrService.publishEventAwaitOk(
          any(),
          timeout: any(named: 'timeout'),
        ),
      ).thenAnswer((invocation) async {
        return PublishOutcome(
          eventId: (invocation.positionalArguments[0] as Event).id,
          acceptedBy: const ['wss://relay.divine.video'],
          rejectedBy: const {},
          noResponseFrom: const [],
        );
      });
      when(
        () => mockNostrService.queryEvents(
          any(),
          subscriptionId: any(named: 'subscriptionId'),
          tempRelays: any(named: 'tempRelays'),
          relayTypes: any(named: 'relayTypes'),
          sendAfterAuth: any(named: 'sendAfterAuth'),
          useCache: any(named: 'useCache'),
        ),
      ).thenAnswer(
        (_) async => capturedEvent == null ? <Event>[] : [capturedEvent!],
      );

      publisher = VideoEventPublisher(
        uploadManager: mockUploadManager,
        nostrService: mockNostrService,
        authService: mockAuthService,
      );
    });

    test(
      'publishes creator-binding-only identity tags when verifier output is missing',
      () async {
        final upload = _buildUpload(
          const NativeProofData(
            videoHash: 'abc123def456',
            creatorBindingAssertionLabel: 'video.divine.nostr.creator_binding',
            creatorBindingPayloadJson: '{"version":1}',
          ),
        );

        final published = await publisher.publishDirectUpload(upload);

        expect(published, isTrue);
        expect(capturedEvent, isNotNull);
        expect(capturedEvent!.pubkey, equals(upload.nostrPubkey));

        expect(
          capturedEvent!.tags,
          contains(equals(<String>['identity_binding', 'nostr_creator'])),
        );
        expect(
          capturedEvent!.tags.where(
            (tag) => tag.isNotEmpty && tag.first == 'identity_verifier',
          ),
          isEmpty,
        );
        expect(
          capturedEvent!.tags.where(
            (tag) => tag.isNotEmpty && tag.first == 'identity_portable',
          ),
          isEmpty,
        );
      },
    );

    test(
      'publishes CAWG overlay tags and exposes them through VideoEvent',
      () async {
        final upload = _buildUpload(
          NativeProofData(
            videoHash: 'abc123def456',
            creatorBindingAssertionLabel: 'video.divine.nostr.creator_binding',
            creatorBindingPayloadJson: '{"version":1}',
            cawgIdentityAssertionLabel: 'cawg.identity',
            verifiedIdentityBundleJson: jsonEncode(<String, dynamic>{
              'issuer': 'verifyer.divine.video',
              'status': 'verified',
            }),
          ),
        );

        final published = await publisher.publishDirectUpload(upload);

        expect(published, isTrue);
        expect(capturedEvent, isNotNull);
        expect(
          capturedEvent!.tags,
          contains(equals(<String>['identity_binding', 'nostr_creator'])),
        );
        expect(
          capturedEvent!.tags,
          contains(
            equals(<String>['identity_verifier', 'verifyer.divine.video']),
          ),
        );
        expect(
          capturedEvent!.tags,
          contains(equals(<String>['identity_portable', 'cawg'])),
        );

        final parsedVideo = VideoEvent.fromNostrEvent(capturedEvent!);
        expect(parsedVideo.hasCreatorIdentityBinding, isTrue);
        expect(parsedVideo.identityVerifier, equals('verifyer.divine.video'));
        expect(parsedVideo.hasPortableIdentity, isTrue);
      },
    );

    test(
      'does not block publish when verifier bundle JSON is malformed',
      () async {
        final upload = _buildUpload(
          const NativeProofData(
            videoHash: 'abc123def456',
            creatorBindingAssertionLabel: 'video.divine.nostr.creator_binding',
            creatorBindingPayloadJson: '{"version":1}',
            cawgIdentityAssertionLabel: 'cawg.identity',
            verifiedIdentityBundleJson: '{"issuer":',
          ),
        );

        final published = await publisher.publishDirectUpload(upload);

        expect(published, isTrue);
        expect(capturedEvent, isNotNull);
        expect(
          capturedEvent!.tags,
          contains(equals(<String>['identity_binding', 'nostr_creator'])),
        );
        expect(
          capturedEvent!.tags,
          contains(equals(<String>['identity_portable', 'cawg'])),
        );
        expect(
          capturedEvent!.tags.where(
            (tag) => tag.isNotEmpty && tag.first == 'identity_verifier',
          ),
          isEmpty,
        );
      },
    );
  });
}

PendingUpload _buildUpload(NativeProofData nativeProof) {
  return PendingUpload.create(
    localVideoPath: '/tmp/test.mp4',
    nostrPubkey:
        '385c3a6ec0b9d57a4330dbd6284989be5bd00e41c535f9ca39b6ae7c521b81cd',
    proofManifestJson: jsonEncode(nativeProof.toJson()),
  ).copyWith(
    status: UploadStatus.readyToPublish,
    videoId: 'video123',
    cdnUrl: 'https://cdn.example.com/video.mp4',
  );
}
