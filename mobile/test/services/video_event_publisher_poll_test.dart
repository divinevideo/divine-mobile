// ABOUTME: Tests that a video's poll, quiz or slider goes out ahead of the
// ABOUTME: video, whose poll sticker then points to it, and only once.

import 'dart:io';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' show VideoStickerKind, VideoStickerRegion;
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/relay/publish_outcome.dart';
import 'package:openvine/constants/nip71_migration.dart';
import 'package:openvine/services/audio_extraction_service.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/personal_event_cache_service.dart';
import 'package:openvine/services/upload_manager.dart';
import 'package:openvine/services/video_event_publisher.dart';
import 'package:poll_repository/poll_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockUploadManager extends Mock implements UploadManager {}

class _MockNostrClient extends Mock implements NostrClient {}

class _MockAuthService extends Mock implements AuthService {}

class _MockBlossomUploadService extends Mock implements BlossomUploadService {}

class _MockAudioExtractionService extends Mock
    implements AudioExtractionService {}

class _MockPersonalEventCacheService extends Mock
    implements PersonalEventCacheService {}

class _FakeEvent extends Fake implements Event {}

void main() {
  group('VideoEventPublisher poll stickers', () {
    final ownerPubkey = 'b' * 64;
    const stableId = 'poll-video';
    const relay = 'wss://relay.divine.video';

    final poll = Poll.choice(
      question: 'Which one?',
      answers: const ['Red', 'Blue'],
    );
    const pollRegion = VideoStickerRegion(
      kind: VideoStickerKind.poll,
      target: '',
      centerX: 0.5,
      centerY: 0.5,
      width: 0.6,
      height: 0.3,
      style: 'light',
      label: 'Which one?\nRed\nBlue',
    );
    const linkRegion = VideoStickerRegion(
      kind: VideoStickerKind.link,
      target: 'https://divine.video/',
      centerX: 0.5,
      centerY: 0.2,
      width: 0.3,
      height: 0.05,
    );

    late _MockUploadManager uploadManager;
    late _MockNostrClient nostrClient;
    late _MockAuthService authService;
    late _MockPersonalEventCacheService personalEventCache;
    late VideoEventPublisher publisher;
    late List<Event> broadcast;
    late bool relaysTakePolls;
    late bool signsVideos;
    late int clock;

    setUpAll(() {
      registerFallbackValue(_FakeEvent());
      registerFallbackValue(UploadStatus.pending);
      registerFallbackValue(File(''));
      registerFallbackValue(Duration.zero);
    });

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      Nip89ClientTag.resetForTest();

      uploadManager = _MockUploadManager();
      nostrClient = _MockNostrClient();
      authService = _MockAuthService();
      personalEventCache = _MockPersonalEventCacheService();
      broadcast = <Event>[];
      relaysTakePolls = true;
      signsVideos = true;
      clock = 1700000100;

      publisher = VideoEventPublisher(
        uploadManager: uploadManager,
        nostrService: nostrClient,
        authService: authService,
        personalEventCache: personalEventCache,
        blossomUploadService: _MockBlossomUploadService(),
        audioExtractionService: _MockAudioExtractionService(),
      );

      when(() => authService.isAuthenticated).thenReturn(true);
      when(() => authService.currentPublicKeyHex).thenReturn(ownerPubkey);
      when(() => nostrClient.isInitialized).thenReturn(true);
      when(() => nostrClient.configuredRelayCount).thenReturn(1);
      when(() => nostrClient.connectedRelayCount).thenReturn(1);
      when(() => nostrClient.configuredRelays).thenReturn(const [relay]);
      when(() => nostrClient.connectedRelays).thenReturn(const [relay]);
      when(() => nostrClient.publicKey).thenReturn(ownerPubkey);
      when(
        () => uploadManager.updateUploadStatus(
          any(),
          any(),
          nostrEventId: any(named: 'nostrEventId'),
        ),
      ).thenAnswer((_) async {});
      when(() => personalEventCache.cacheUserEvent(any())).thenReturn(null);
      when(
        () => nostrClient.publishEventAwaitOk(
          any(),
          timeout: any(named: 'timeout'),
        ),
      ).thenAnswer((invocation) async {
        final event = invocation.positionalArguments.first as Event;
        final accepted = event.kind != Poll.eventKind || relaysTakePolls;
        if (accepted) broadcast.add(event);
        return PublishOutcome(
          eventId: event.id,
          acceptedBy: accepted ? const [relay] : const [],
          rejectedBy: accepted ? const {} : const {relay: 'blocked: kind'},
          noResponseFrom: const [],
        );
      });
      when(
        () => authService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
          createdAt: any(named: 'createdAt'),
        ),
      ).thenAnswer((invocation) async {
        final kind = invocation.namedArguments[#kind] as int;
        if (kind != Poll.eventKind && !signsVideos) return null;
        return Event(
          ownerPubkey,
          kind,
          invocation.namedArguments[#tags] as List<List<String>>,
          invocation.namedArguments[#content] as String,
          // Like a real signer: stamped now unless told otherwise.
          createdAt: invocation.namedArguments[#createdAt] as int? ?? clock++,
        )..sig = 'signature';
      });
    });

    tearDown(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      Nip89ClientTag.resetForTest();
    });

    PendingUpload upload({String? nostrEventId}) => PendingUpload(
      id: 'poll-upload',
      localVideoPath: '',
      nostrPubkey: ownerPubkey,
      status: UploadStatus.readyToPublish,
      createdAt: DateTime.utc(2026, 10, 30, 12),
      videoId: stableId,
      title: 'Outfits',
      cdnUrl: 'https://cdn.example.com/video.mp4',
      fallbackUrl: 'https://cdn.example.com/video.mp4',
      nostrEventId: nostrEventId,
    );

    List<VideoStickerRegion> stickersOf(Event video) =>
        VideoStickerRegion.fromTags(video.tags);

    test('publishes the poll ahead of the video and points the poll '
        'sticker at it', () async {
      expect(
        await publisher.publishDirectUpload(
          upload(),
          stickerRegions: const [linkRegion, pollRegion],
          poll: poll,
        ),
        isTrue,
      );

      final [pollEvent, video] = broadcast;
      expect(pollEvent.kind, equals(Poll.eventKind));
      expect(pollEvent.content, equals('Which one?'));
      expect(pollEvent.tags, containsAll(poll.toTags(relayUrl: relay)));
      expect(
        stickersOf(video),
        equals([linkRegion, pollRegion.withTarget(pollEvent.id)]),
      );
    });

    test('sends a retried video signed before without another poll', () async {
      final cached = Event(
        ownerPubkey,
        NIP71VideoKinds.addressableShortVideo,
        [
          ['d', stableId],
          if (await Nip89ClientTag.isEnabled()) Nip89ClientTag.tag,
          pollRegion.withTarget('c' * 64).toTag(),
        ],
        'Outfits',
        createdAt: 1700000000,
      )..sig = 'cached-signature';
      when(() => personalEventCache.getEventById(cached.id)).thenReturn(cached);

      expect(
        await publisher.publishDirectUpload(
          upload(nostrEventId: cached.id),
          stickerRegions: const [pollRegion],
          poll: poll,
        ),
        isTrue,
      );

      expect(broadcast.single.id, equals(cached.id));
    });

    test('signs the same poll again when a retry has to sign its video '
        'again', () async {
      signsVideos = false;
      expect(
        await publisher.publishDirectUpload(
          upload(),
          stickerRegions: const [pollRegion],
          poll: poll,
        ),
        isFalse,
      );
      final firstPoll = broadcast.single;

      signsVideos = true;
      expect(
        await publisher.publishDirectUpload(
          upload(),
          stickerRegions: const [pollRegion],
          poll: poll,
        ),
        isTrue,
      );

      final [retriedPoll, video] = broadcast.sublist(1);
      expect(retriedPoll.id, equals(firstPoll.id));
      expect(stickersOf(video).single.target, equals(firstPoll.id));
    });

    test('keeps the video back when no relay takes its poll', () async {
      relaysTakePolls = false;

      expect(
        await publisher.publishDirectUpload(
          upload(),
          stickerRegions: const [pollRegion],
          poll: poll,
        ),
        isFalse,
      );

      expect(broadcast, isEmpty);
    });

    test('leaves out a poll sticker with no poll to publish', () async {
      expect(
        await publisher.publishDirectUpload(
          upload(),
          stickerRegions: const [linkRegion, pollRegion],
        ),
        isTrue,
      );

      expect(stickersOf(broadcast.single), equals([linkRegion]));
    });
  });
}
