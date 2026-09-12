// ABOUTME: Tests the inspired-by p-tags emitted by VideoEventPublisher so the
// ABOUTME: referenced creator is notifiable, deduped against other p-tags.

import 'package:collection/collection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart'
    show ClipSourceCredit, clipSourceCreditTagMarker;
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:nostr_sdk/relay/publish_outcome.dart';
import 'package:openvine/constants/nip71_migration.dart';
import 'package:openvine/models/pending_upload.dart';
import 'package:openvine/models/video_reply_context.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/upload_manager.dart';
import 'package:openvine/services/video_event_publisher.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/utils/collaborator_tags.dart';
import 'package:openvine/utils/inspired_by_tags.dart';
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

int _countPTagsFor(List<List<String>> tags, String pubkey) {
  return tags
      .where((tag) => tag.length >= 2 && tag[0] == 'p' && tag[1] == pubkey)
      .length;
}

void main() {
  late _MockUploadManager uploadManager;
  late _MockNostrClient nostrClient;
  late _MockAuthService authService;
  late _MockVideoEventService videoEventService;
  late VideoEventPublisher publisher;
  late List<List<String>> capturedTags;
  late String capturedContent;

  const testPubkey =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const inspiredCreatorPubkey =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
  const inspiredPersonPubkey =
      'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
  const secondClipCreatorPubkey =
      'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
  const rootAuthorPubkey =
      'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';

  const inspiredByAddressableId = '34236:$inspiredCreatorPubkey:source-d-tag';

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
    capturedContent = '';

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
      capturedContent = invocation.namedArguments[#content] as String;
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

  group(VideoEventPublisher, () {
    group('publishDirectUpload', () {
      test(
        'emits an inspired-by p-tag alongside the a-tag for a video reference',
        () async {
          stubSignAndPublish();

          final result = await publisher.publishDirectUpload(
            createUpload(),
            inspiredByAddressableId: inspiredByAddressableId,
            inspiredByRelayUrl: 'wss://source.relay',
          );

          expect(result, isTrue);
          expect(
            _containsTag(capturedTags, const [
              'a',
              inspiredByAddressableId,
              'wss://source.relay',
              'mention',
            ]),
            isTrue,
            reason: 'the existing inspired-by a-tag is unchanged',
          );
          expect(
            _containsTag(
              capturedTags,
              buildInspiredByPTag(
                inspiredCreatorPubkey,
                relayHint: 'wss://source.relay',
              ),
            ),
            isTrue,
          );
        },
      );

      test(
        'emits clip-source a-tag even when the source is also inspired-by',
        () async {
          stubSignAndPublish();

          final result = await publisher.publishDirectUpload(
            createUpload(),
            inspiredByAddressableId: inspiredByAddressableId,
            inspiredByRelayUrl: 'wss://source.relay',
            clipSourceCredits: const [
              ClipSourceCredit(
                authorPubkey: inspiredCreatorPubkey,
                eventId: 'source-event-a',
                addressableId: inspiredByAddressableId,
                relayUrl: 'wss://source.relay',
              ),
            ],
          );

          expect(result, isTrue);
          expect(
            _containsTag(capturedTags, const [
              'a',
              inspiredByAddressableId,
              'wss://source.relay',
              'mention',
            ]),
            isTrue,
          );
          expect(
            _containsTag(capturedTags, const [
              'a',
              inspiredByAddressableId,
              'wss://source.relay',
              clipSourceCreditTagMarker,
            ]),
            isTrue,
            reason:
                'clip-source is factual provenance, so it must survive later '
                'metadata edits that clear manual inspired-by attribution',
          );
          expect(
            _countPTagsFor(capturedTags, inspiredCreatorPubkey),
            equals(1),
          );
        },
      );

      test(
        'emits an inspired-by p-tag for a person (npub) reference',
        () async {
          stubSignAndPublish();
          final npub = NostrKeyUtils.encodePubKey(inspiredPersonPubkey);

          final result = await publisher.publishDirectUpload(
            createUpload(),
            inspiredByNpubs: [npub],
          );

          expect(result, isTrue);
          expect(
            _containsTag(
              capturedTags,
              buildInspiredByPTag(inspiredPersonPubkey),
            ),
            isTrue,
          );
        },
      );

      test(
        'p-tags every credited creator but names only the first in content',
        () async {
          // The content line is what other clients render and what the reader
          // parses back, and its regex matches a single trailing reference —
          // so extra creators ride on p-tags instead. Emitting a second line
          // would break that parse for every client, including ours.
          stubSignAndPublish();
          final first = NostrKeyUtils.encodePubKey(inspiredPersonPubkey);
          final second = NostrKeyUtils.encodePubKey(secondClipCreatorPubkey);

          final result = await publisher.publishDirectUpload(
            createUpload(),
            inspiredByNpubs: [first, second],
          );

          expect(result, isTrue);
          expect(_countPTagsFor(capturedTags, inspiredPersonPubkey), equals(1));
          expect(
            _countPTagsFor(capturedTags, secondClipCreatorPubkey),
            equals(1),
          );
          expect(capturedContent, contains('Inspired by nostr:$first'));
          expect(capturedContent, isNot(contains(second)));
        },
      );

      test(
        'credits every picked creator alongside an inspiring video',
        () async {
          stubSignAndPublish();
          final first = NostrKeyUtils.encodePubKey(inspiredPersonPubkey);
          final second = NostrKeyUtils.encodePubKey(secondClipCreatorPubkey);

          final result = await publisher.publishDirectUpload(
            createUpload(),
            inspiredByAddressableId: inspiredByAddressableId,
            inspiredByNpubs: [first, second],
          );

          expect(result, isTrue);
          for (final pubkey in [
            inspiredCreatorPubkey,
            inspiredPersonPubkey,
            secondClipCreatorPubkey,
          ]) {
            expect(
              _countPTagsFor(capturedTags, pubkey),
              equals(1),
              reason: 'expected exactly one p-tag for $pubkey',
            );
          }
        },
      );

      test(
        'emits p-tags for both creators when video and person co-occur',
        () async {
          stubSignAndPublish();
          final npub = NostrKeyUtils.encodePubKey(inspiredPersonPubkey);

          final result = await publisher.publishDirectUpload(
            createUpload(),
            inspiredByAddressableId: inspiredByAddressableId,
            inspiredByNpubs: [npub],
          );

          expect(result, isTrue);
          expect(
            _countPTagsFor(capturedTags, inspiredCreatorPubkey),
            equals(1),
          );
          expect(_countPTagsFor(capturedTags, inspiredPersonPubkey), equals(1));
        },
      );

      test(
        'emits a-tags and p-tags for multiple clip source credits',
        () async {
          stubSignAndPublish();

          final result = await publisher.publishDirectUpload(
            createUpload(),
            clipSourceCredits: const [
              ClipSourceCredit(
                authorPubkey: inspiredCreatorPubkey,
                eventId: 'source-event-a',
                addressableId: inspiredByAddressableId,
                relayUrl: 'wss://source-a.relay',
              ),
              ClipSourceCredit(
                authorPubkey: secondClipCreatorPubkey,
                eventId: 'source-event-b',
                addressableId: '34236:$secondClipCreatorPubkey:source-b',
                relayUrl: 'wss://source-b.relay',
              ),
            ],
          );

          expect(result, isTrue);
          expect(
            _containsTag(capturedTags, const [
              'a',
              inspiredByAddressableId,
              'wss://source-a.relay',
              clipSourceCreditTagMarker,
            ]),
            isTrue,
          );
          expect(
            _containsTag(capturedTags, const [
              'a',
              '34236:$secondClipCreatorPubkey:source-b',
              'wss://source-b.relay',
              clipSourceCreditTagMarker,
            ]),
            isTrue,
          );
          expect(
            _containsTag(
              capturedTags,
              buildClipSourceCreditPTag(
                inspiredCreatorPubkey,
                relayHint: 'wss://source-a.relay',
              ),
            ),
            isTrue,
          );
          expect(
            _containsTag(
              capturedTags,
              buildClipSourceCreditPTag(
                secondClipCreatorPubkey,
                relayHint: 'wss://source-b.relay',
              ),
            ),
            isTrue,
          );
        },
      );

      test('emits a p-tag for author-only clip source credit', () async {
        stubSignAndPublish();

        final result = await publisher.publishDirectUpload(
          createUpload(),
          clipSourceCredits: const [
            ClipSourceCredit(
              authorPubkey: inspiredCreatorPubkey,
              eventId: 'source-event-a',
              relayUrl: 'wss://source.relay',
            ),
          ],
        );

        expect(result, isTrue);
        expect(
          capturedTags.any(
            (tag) =>
                tag.length >= 4 && tag[0] == 'a' && tag[3] == 'clip-source',
          ),
          isFalse,
        );
        expect(
          _containsTag(
            capturedTags,
            buildClipSourceCreditPTag(
              inspiredCreatorPubkey,
              relayHint: 'wss://source.relay',
            ),
          ),
          isTrue,
        );
      });

      test('self-suppresses clip source a-tags and p-tags', () async {
        stubSignAndPublish();

        final result = await publisher.publishDirectUpload(
          createUpload(),
          clipSourceCredits: const [
            ClipSourceCredit(
              authorPubkey: testPubkey,
              addressableId: '34236:$testPubkey:own-source',
              relayUrl: 'wss://source.relay',
            ),
          ],
        );

        expect(result, isTrue);
        expect(
          capturedTags.any(
            (tag) =>
                tag.length >= 2 &&
                tag[0] == 'a' &&
                tag[1] == '34236:$testPubkey:own-source',
          ),
          isFalse,
        );
        expect(_countPTagsFor(capturedTags, testPubkey), equals(0));
      });

      test(
        'emits a single p-tag when video and person reference the same creator',
        () async {
          stubSignAndPublish();
          final npub = NostrKeyUtils.encodePubKey(inspiredCreatorPubkey);

          final result = await publisher.publishDirectUpload(
            createUpload(),
            inspiredByAddressableId: inspiredByAddressableId,
            inspiredByNpubs: [npub],
          );

          expect(result, isTrue);
          expect(
            _countPTagsFor(capturedTags, inspiredCreatorPubkey),
            equals(1),
          );
        },
      );

      test(
        "skips the p-tag when inspired by the publisher's own video",
        () async {
          stubSignAndPublish();

          final result = await publisher.publishDirectUpload(
            createUpload(),
            inspiredByAddressableId: '34236:$testPubkey:own-d-tag',
          );

          expect(result, isTrue);
          expect(_countPTagsFor(capturedTags, testPubkey), equals(0));
        },
      );

      test(
        "skips the a-tag when inspired by the publisher's own video",
        () async {
          stubSignAndPublish();

          const ownAddressableId = '34236:$testPubkey:own-d-tag';
          final result = await publisher.publishDirectUpload(
            createUpload(),
            inspiredByAddressableId: ownAddressableId,
          );

          expect(result, isTrue);
          expect(
            capturedTags.any(
              (tag) =>
                  tag.length >= 2 &&
                  tag[0] == 'a' &&
                  tag[1] == ownAddressableId,
            ),
            isFalse,
          );
        },
      );

      test(
        'keeps the collaborator p-tag when the creator is also a collaborator',
        () async {
          stubSignAndPublish();

          final result = await publisher.publishDirectUpload(
            createUpload(),
            collaboratorPubkeys: const [inspiredCreatorPubkey],
            inspiredByAddressableId: inspiredByAddressableId,
          );

          expect(result, isTrue);
          expect(
            _containsTag(
              capturedTags,
              buildCollaboratorPTag(inspiredCreatorPubkey),
            ),
            isTrue,
          );
          expect(
            _countPTagsFor(capturedTags, inspiredCreatorPubkey),
            equals(1),
            reason: 'a collaborator is never double-tagged as inspired-by',
          );
        },
      );

      test(
        'keeps a single p-tag when the creator is also a caption mention',
        () async {
          stubSignAndPublish();

          final result = await publisher.publishDirectUpload(
            createUpload(),
            mentionedPubkeys: const [inspiredCreatorPubkey],
            inspiredByAddressableId: inspiredByAddressableId,
          );

          expect(result, isTrue);
          expect(
            _containsTag(capturedTags, const [
              'p',
              inspiredCreatorPubkey,
              'wss://relay.divine.video',
              'mention',
            ]),
            isTrue,
            reason: 'the caption-mention p-tag wins dedup',
          );
          expect(
            _countPTagsFor(capturedTags, inspiredCreatorPubkey),
            equals(1),
          );
        },
      );

      test('does not emit inspired-by p-tags on a video reply', () async {
        stubSignAndPublish();
        const replyContext = VideoReplyContext(
          rootEventId: 'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
          rootEventKind: 34236,
          rootAuthorPubkey: rootAuthorPubkey,
        );

        final result = await publisher.publishDirectUpload(
          createUpload(),
          replyContext: replyContext,
          inspiredByAddressableId: inspiredByAddressableId,
          inspiredByNpubs: [NostrKeyUtils.encodePubKey(inspiredPersonPubkey)],
        );

        expect(result, isTrue);
        expect(
          capturedTags.any(
            (tag) =>
                tag.length >= 4 &&
                tag[0] == 'p' &&
                tag[3] == inspiredByPTagMarker,
          ),
          isFalse,
          reason:
              'the model hides inspired-by attribution on replies and the '
              'edit flow cannot own the tag there, so replies never notify',
        );
        expect(
          _countPTagsFor(capturedTags, rootAuthorPubkey),
          equals(1),
          reason: 'reply threading p-tags are untouched',
        );
      });

      test(
        'emits no inspired-by p-tag without an inspired-by reference',
        () async {
          stubSignAndPublish();

          final result = await publisher.publishDirectUpload(createUpload());

          expect(result, isTrue);
          expect(
            capturedTags.any(
              (tag) =>
                  tag.length >= 4 &&
                  tag[0] == 'p' &&
                  tag[3] == inspiredByPTagMarker,
            ),
            isFalse,
          );
        },
      );

      test(
        'publishes without a p-tag when the addressable id is malformed',
        () async {
          stubSignAndPublish();

          final result = await publisher.publishDirectUpload(
            createUpload(),
            inspiredByAddressableId: '34236:',
          );

          expect(result, isTrue);
          expect(
            _containsTag(capturedTags, const [
              'a',
              '34236:',
              'wss://relay.divine.video',
              'mention',
            ]),
            isTrue,
            reason:
                'only malformed p-tags are suppressed; the a-tag is unchanged',
          );
          expect(
            capturedTags.any(
              (tag) =>
                  tag.length >= 4 &&
                  tag[0] == 'p' &&
                  tag[3] == inspiredByPTagMarker,
            ),
            isFalse,
          );
          expect(
            capturedTags.any((tag) => tag.length >= 2 && tag[1].isEmpty),
            isFalse,
            reason: 'no empty p value is ever published',
          );
        },
      );
    });
  });
}
