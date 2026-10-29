// ABOUTME: #8176 regression tests: Try Again must re-sign a cached video event
// ABOUTME: whenever the client-attribution setting changed since it was signed.

import 'dart:io';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/relay/publish_outcome.dart';
import 'package:openvine/constants/nip71_migration.dart';
import 'package:openvine/services/audio_extraction_service.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/personal_event_cache_service.dart';
import 'package:openvine/services/upload_manager.dart';
import 'package:openvine/services/video_event_publisher.dart';
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
  group(
    'VideoEventPublisher Try Again after an attribution change (#8176)',
    () {
      final ownerPubkey = 'b' * 64;
      const uploadId = 'retry-upload';
      const stableId = 'retry-video';
      const relay = 'wss://relay.divine.video';

      late _MockUploadManager uploadManager;
      late _MockNostrClient nostrClient;
      late _MockAuthService authService;
      late _MockPersonalEventCacheService personalEventCache;
      late VideoEventPublisher publisher;
      late List<Event> broadcast;
      late int signatures;

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
        signatures = 0;

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
          broadcast.add(event);
          return PublishOutcome(
            eventId: event.id,
            acceptedBy: const [relay],
            rejectedBy: const {},
            noResponseFrom: const [],
          );
        });
        // Mirrors SignerFactory.createAndSignEvent: Divine's tag is appended
        // before signing exactly when the preference asks for it.
        when(
          () => authService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
            createdAt: any(named: 'createdAt'),
          ),
        ).thenAnswer((invocation) async {
          signatures++;
          final kind = invocation.namedArguments[#kind] as int;
          final tags = [
            for (final tag
                in invocation.namedArguments[#tags] as List<List<String>>)
              List<String>.of(tag),
          ];
          if (!Nip89ClientTag.shouldSkipKind(kind) &&
              !Nip89ClientTag.hasClientTag(tags) &&
              await Nip89ClientTag.isEnabled()) {
            tags.add(Nip89ClientTag.tag);
          }
          return Event(
            ownerPubkey,
            kind,
            tags,
            invocation.namedArguments[#content] as String,
            createdAt: 1700000100,
          )..sig = 'fresh-signature';
        });
      });

      // Two tests here turn the tag off; the persisted preference outlives the
      // cache reset, so clear both for whichever suite runs next.
      tearDown(() {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        Nip89ClientTag.resetForTest();
      });

      /// The event a first, failed attempt left in the personal cache.
      Event cachedSignedEvent({required bool attributed}) {
        final tags = <List<String>>[
          ['d', stableId],
          ['title', 'Plants'],
          if (attributed) Nip89ClientTag.tag,
        ];
        return Event(
          ownerPubkey,
          NIP71VideoKinds.addressableShortVideo,
          tags,
          'Plants',
          createdAt: 1700000000,
        )..sig = 'cached-signature';
      }

      PendingUpload retriedUpload(Event cached) => PendingUpload(
        id: uploadId,
        localVideoPath: '',
        nostrPubkey: ownerPubkey,
        status: UploadStatus.readyToPublish,
        createdAt: DateTime.now(),
        videoId: stableId,
        title: 'Plants',
        cdnUrl: 'https://cdn.example.com/video.mp4',
        fallbackUrl: 'https://cdn.example.com/video.mp4',
        nostrEventId: cached.id,
      );

      test(
        'attribution switched on since the first attempt: signs afresh and '
        'the retried video carries the client tag',
        () async {
          await Nip89ClientTag.setEnabled(enabled: true);
          final cached = cachedSignedEvent(attributed: false);
          when(
            () => personalEventCache.getEventById(cached.id),
          ).thenReturn(cached);

          expect(
            await publisher.publishDirectUpload(retriedUpload(cached)),
            isTrue,
          );

          expect(
            signatures,
            1,
            reason: 'a cached event signed without the tag must not be reused',
          );
          final sent = broadcast.single;
          expect(sent.id, isNot(cached.id));
          expect(Nip89ClientTag.hasClientTag(sent.tags), isTrue);
        },
      );

      test(
        'attribution switched off since the first attempt: signs afresh and '
        'the retried video carries no client tag',
        () async {
          await Nip89ClientTag.setEnabled(enabled: false);
          final cached = cachedSignedEvent(attributed: true);
          when(
            () => personalEventCache.getEventById(cached.id),
          ).thenReturn(cached);

          expect(
            await publisher.publishDirectUpload(retriedUpload(cached)),
            isTrue,
          );

          expect(
            signatures,
            1,
            reason: 'a cached event signed with the tag must not be reused',
          );
          final sent = broadcast.single;
          expect(sent.id, isNot(cached.id));
          expect(Nip89ClientTag.hasClientTag(sent.tags), isFalse);
        },
      );

      test(
        'attribution still on: the cached tagged event is reused without a '
        'second signature',
        () async {
          await Nip89ClientTag.setEnabled(enabled: true);
          final cached = cachedSignedEvent(attributed: true);
          when(
            () => personalEventCache.getEventById(cached.id),
          ).thenReturn(cached);

          expect(
            await publisher.publishDirectUpload(retriedUpload(cached)),
            isTrue,
          );

          expect(signatures, 0);
          expect(broadcast.single.id, cached.id);
          expect(broadcast.single.sig, 'cached-signature');
        },
      );

      test(
        'attribution still off: the cached untagged event is reused without a '
        'second signature',
        () async {
          await Nip89ClientTag.setEnabled(enabled: false);
          final cached = cachedSignedEvent(attributed: false);
          when(
            () => personalEventCache.getEventById(cached.id),
          ).thenReturn(cached);

          expect(
            await publisher.publishDirectUpload(retriedUpload(cached)),
            isTrue,
          );

          expect(signatures, 0);
          expect(broadcast.single.id, cached.id);
          expect(Nip89ClientTag.hasClientTag(broadcast.single.tags), isFalse);
        },
      );
    },
  );
}
