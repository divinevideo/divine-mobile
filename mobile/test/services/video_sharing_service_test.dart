// ABOUTME: Tests for VideoSharingService social features integration
// ABOUTME: Covers the NIP-17 share path, recents, shareVideoWithUser,
// ABOUTME: and sharing utilities.

import 'dart:async';

import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/nip19/nip19_tlv.dart';
import 'package:nostr_sdk/nip19/pubkey_for_logs.dart';
import 'package:openvine/services/auth_service.dart' hide UserProfile;
import 'package:openvine/services/share_recents_store.dart';
import 'package:openvine/services/short_link_client.dart';
import 'package:openvine/services/video_sharing_service.dart';
import 'package:unified_logger/unified_logger.dart';

import '../helpers/test_pubkeys.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockRecents extends Mock implements ShareRecentsStore {}

class _MockDmRepository extends Mock implements DmRepository {}

final String _testPubkey = testPubkeyFromSeed(1);

final String _recipientPubkey = testPubkeyFromSeed(2);

const _testVideoId =
    'a695f6b60119d9521934a691347d9f78e8770b56da16bb255ee77ac112b4c1f6';

void main() {
  late VideoSharingService service;
  late _MockAuthService mockAuthService;
  late _MockRecents recents;
  late _MockDmRepository mockDmRepository;

  setUp(() {
    mockAuthService = _MockAuthService();
    recents = _MockRecents();
    when(() => recents.snapshot(any())).thenReturn([]);
    when(() => recents.recordQueued(any(), any())).thenAnswer((_) async {});
    mockDmRepository = _MockDmRepository();
    when(() => mockAuthService.currentPublicKeyHex).thenReturn(_testPubkey);
    when(() => mockDmRepository.userPubkey).thenReturn(_testPubkey);

    service = VideoSharingService(
      authService: mockAuthService,
      recentsStore: recents,
      dmRepository: mockDmRepository,
    );
  });

  /// Any share batch, for `when` and `verifyNever`.
  Future<Map<String, ShareEnqueueOutcome>> anySharedVideoSend() =>
      mockDmRepository.enqueueSharedVideoBatch(
        recipientPubkeys: any(named: 'recipientPubkeys'),
        baseContent: any(named: 'baseContent'),
        videoKind: any(named: 'videoKind'),
        videoAuthorPubkey: any(named: 'videoAuthorPubkey'),
        videoDTag: any(named: 'videoDTag'),
        videoEventId: any(named: 'videoEventId'),
        relayHint: any(named: 'relayHint'),
      );

  void stubSharesSucceed() {
    when(anySharedVideoSend).thenAnswer((call) async {
      final recipients = call.namedArguments[#recipientPubkeys] as List<String>;
      return {
        for (final recipient in recipients)
          recipient: ShareEnqueueOutcome.queued(
            'rumor-id',
            DmRepository.computeConversationId(
              [_testPubkey, recipient]..sort(),
            ),
          ),
      };
    });
  }

  /// The message body of the first share handed to the DM repository.
  String sharedMessage() {
    final captured = verify(
      () => mockDmRepository.enqueueSharedVideoBatch(
        recipientPubkeys: any(named: 'recipientPubkeys'),
        baseContent: captureAny(named: 'baseContent'),
        videoKind: any(named: 'videoKind'),
        videoAuthorPubkey: any(named: 'videoAuthorPubkey'),
        videoDTag: any(named: 'videoDTag'),
        videoEventId: any(named: 'videoEventId'),
        relayHint: any(named: 'relayHint'),
      ),
    ).captured;
    return captured.first as String;
  }

  group('recentlySharedWith', () {
    test('switching accounts immediately changes the recents snapshot', () {
      when(() => recents.snapshot(_testPubkey)).thenReturn([
        ShareableUser(pubkey: _recipientPubkey, displayName: 'Alice'),
      ]);
      expect(service.recentlySharedWith.single.displayName, 'Alice');
      when(
        () => mockAuthService.currentPublicKeyHex,
      ).thenReturn(testPubkeyFromSeed(3));
      expect(service.recentlySharedWith, isEmpty);
    });
  });

  group('shareVideoWithUser', () {
    test('returns failure when user is not authenticated', () async {
      when(() => mockAuthService.isAuthenticated).thenReturn(false);

      final now = DateTime.now();
      final result = await service.shareVideoWithUser(
        video: VideoEvent(
          id: _testVideoId,
          pubkey: _testPubkey,
          createdAt: now.millisecondsSinceEpoch ~/ 1000,
          timestamp: now,
          content: 'Test',
        ),
        recipientPubkey: _recipientPubkey,
      );

      expect(result.delivery, ShareDelivery.notSent);
      expect(result.refusal, ShareRefusal.notAuthenticated);
    });

    test('returns failure when the signer is not ready yet (#6423)', () async {
      // The service used to inherit this check by accident: it was built from
      // the relay-gated profile repository, so a not-yet-ready session made
      // the whole service null and Share a silent dead tap. Now the sheet
      // opens on the read-only handle and the send path owns the requirement.
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(() => mockAuthService.canPublishNostrWritesNow).thenReturn(false);

      final now = DateTime.now();
      final result = await service.shareVideoWithUser(
        video: VideoEvent(
          id: _testVideoId,
          pubkey: _testPubkey,
          createdAt: now.millisecondsSinceEpoch ~/ 1000,
          timestamp: now,
          content: 'Test',
        ),
        recipientPubkey: _recipientPubkey,
      );

      expect(result.delivery, ShareDelivery.notSent);
      expect(result.refusal, ShareRefusal.signerUnavailable);
      // Never reached the signer: the gate short-circuits before any event is
      // created, rather than letting it fail 30s later on an RPC timeout.
      verifyNever(anySharedVideoSend);
    });

    test(
      'an account switch before enqueue refuses the batch locally',
      () async {
        when(() => mockAuthService.isAuthenticated).thenReturn(true);
        when(() => mockAuthService.canPublishNostrWritesNow).thenReturn(true);
        when(
          () => mockAuthService.currentPublicKeyHex,
        ).thenReturn(testPubkeyFromSeed(3));
        final result = await service.shareVideoWithUser(
          video: VideoEvent(
            id: _testVideoId,
            pubkey: _testPubkey,
            createdAt: 1,
            timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
            content: '',
          ),
          recipientPubkey: _recipientPubkey,
        );
        expect(result.delivery, ShareDelivery.notSent);
        expect(result.refusal, ShareRefusal.accountChanged);
        expect(result.rumorId, isNull);
        verifyNever(anySharedVideoSend);
      },
    );

    test('sends the video as a NIP-17 message, with no kind-4 copy', () async {
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(() => mockAuthService.canPublishNostrWritesNow).thenReturn(true);
      stubSharesSucceed();

      // Someone else's video, so its author cannot pass for the sender.
      final videoAuthor = testPubkeyFromSeed(4);
      final now = DateTime.now();
      final result = await service.shareVideoWithUser(
        video: VideoEvent(
          id: _testVideoId,
          pubkey: videoAuthor,
          createdAt: now.millisecondsSinceEpoch ~/ 1000,
          timestamp: now,
          content: 'Test',
          vineId: 'shared-video',
          rawTags: const {'d': 'shared-video'},
        ),
        recipientPubkey: _recipientPubkey,
      );

      expect(result.delivery, ShareDelivery.queued);
      expect(result.refusal, isNull);
      expect(result.rumorId, equals('rumor-id'));
      expect(result.conversationId, isNotNull);

      // The repository gets this video's own reference, which is what the
      // recipient's share card resolves. The plaintext kind-4 copy is turned
      // off for shares (no sender↔recipient metadata leak), and the service
      // signs nothing itself.
      verify(
        () => mockDmRepository.enqueueSharedVideoBatch(
          recipientPubkeys: [_recipientPubkey],
          baseContent: any(named: 'baseContent'),
          videoKind: NIP71VideoKinds.addressableShortVideo,
          videoAuthorPubkey: videoAuthor,
          videoDTag: 'shared-video',
          videoEventId: _testVideoId,
          relayHint: any(named: 'relayHint'),
        ),
      ).called(1);
      verifyNever(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      );
    });

    test(
      'returns a durable result without waiting on the recents profile fetch (#5391)',
      () async {
        when(() => mockAuthService.isAuthenticated).thenReturn(true);
        when(() => mockAuthService.canPublishNostrWritesNow).thenReturn(true);
        stubSharesSucceed();
        // The post-send recents refresh must be fire-and-forget: a hung
        // profile fetch must NOT delay the success result (the toast).
        final neverCompletes = Completer<void>();
        when(() => recents.recordQueued(any(), any()))
            .thenAnswer((_) => neverCompletes.future);

        final now = DateTime.now();
        final result = await service
            .shareVideoWithUser(
              video: VideoEvent(
                id: _testVideoId,
                pubkey: _testPubkey,
                createdAt: now.millisecondsSinceEpoch ~/ 1000,
                timestamp: now,
                content: 'Test',
              ),
              recipientPubkey: _recipientPubkey,
            )
            .timeout(const Duration(seconds: 2));

        expect(result.delivery, ShareDelivery.queued);
        expect(result.rumorId, equals('rumor-id'));
      },
    );

    for (final (outcome, refusal) in [
      (const ShareEnqueueOutcome.blocked(), ShareRefusal.blocked),
      (const ShareEnqueueOutcome.tooLong(), ShareRefusal.tooLong),
      (
        const ShareEnqueueOutcome.refused('invalid recipient'),
        ShareRefusal.recipientRefused,
      ),
      (null, ShareRefusal.unavailable),
    ]) {
      test('a ${outcome?.runtimeType ?? 'missing'} result is refused as '
          '${refusal.name} with no queued rumor', () async {
        when(() => mockAuthService.isAuthenticated).thenReturn(true);
        when(() => mockAuthService.canPublishNostrWritesNow).thenReturn(true);
        when(anySharedVideoSend).thenAnswer(
          (_) async => {_recipientPubkey: ?outcome},
        );
        final result = await service.shareVideoWithUser(
          video: VideoEvent(
            id: _testVideoId,
            pubkey: _testPubkey,
            createdAt: 1,
            timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
            content: 'Test',
          ),
          recipientPubkey: _recipientPubkey,
        );
        expect(result.delivery, ShareDelivery.notSent);
        expect(result.refusal, refusal);
        expect(result.rumorId, isNull);
        expect(result.conversationId, isNull);
        verifyNever(() => recents.recordQueued(any(), any()));
      });
    }

    test('includes personal message in content', () async {
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(() => mockAuthService.canPublishNostrWritesNow).thenReturn(true);
      stubSharesSucceed();

      final now = DateTime.now();
      await service.shareVideoWithUser(
        video: VideoEvent(
          id: _testVideoId,
          pubkey: _testPubkey,
          createdAt: now.millisecondsSinceEpoch ~/ 1000,
          timestamp: now,
          content: 'Test',
        ),
        recipientPubkey: _recipientPubkey,
        personalMessage: 'Check this out!',
      );

      expect(sharedMessage(), contains('Check this out!'));
    });

    test('share message contains quoted title and share URL', () async {
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(() => mockAuthService.canPublishNostrWritesNow).thenReturn(true);
      stubSharesSucceed();

      final now = DateTime.now();
      await service.shareVideoWithUser(
        video: VideoEvent(
          id: _testVideoId,
          pubkey: _testPubkey,
          createdAt: now.millisecondsSinceEpoch ~/ 1000,
          timestamp: now,
          content: 'Test',
          title: 'Indigenous cultures',
          vineId: 'indigenous-cultures',
          rawTags: const {'d': 'indigenous-cultures'},
        ),
        recipientPubkey: _recipientPubkey,
      );

      final message = sharedMessage();
      expect(message, contains('"Indigenous cultures"'));
      expect(message, contains('divine.video/video/'));
    });

    test('share message without title contains only share URL', () async {
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(() => mockAuthService.canPublishNostrWritesNow).thenReturn(true);
      stubSharesSucceed();

      final now = DateTime.now();
      await service.shareVideoWithUser(
        video: VideoEvent(
          id: _testVideoId,
          pubkey: _testPubkey,
          createdAt: now.millisecondsSinceEpoch ~/ 1000,
          timestamp: now,
          content: 'Test',
          vineId: 'shareable-video',
          rawTags: const {'d': 'shareable-video'},
        ),
        recipientPubkey: _recipientPubkey,
      );

      final message = sharedMessage();
      expect(message, contains('divine.video/video/'));
      expect(message, isNot(contains('"')));
    });

    test('computes correct conversationId', () async {
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(() => mockAuthService.canPublishNostrWritesNow).thenReturn(true);
      stubSharesSucceed();

      final now = DateTime.now();
      final result = await service.shareVideoWithUser(
        video: VideoEvent(
          id: _testVideoId,
          pubkey: _testPubkey,
          createdAt: now.millisecondsSinceEpoch ~/ 1000,
          timestamp: now,
          content: 'Test',
        ),
        recipientPubkey: _recipientPubkey,
      );

      // Verify conversation ID matches DmRepository computation
      final participants = [_testPubkey, _recipientPubkey]..sort();
      final expectedId = DmRepository.computeConversationId(participants);
      expect(result.conversationId, equals(expectedId));
    });

    test('updates sharing history on NIP-17 success', () async {
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(() => mockAuthService.canPublishNostrWritesNow).thenReturn(true);
      stubSharesSucceed();

      final now = DateTime.now();
      await service.shareVideoWithUser(
        video: VideoEvent(
          id: _testVideoId,
          pubkey: _testPubkey,
          createdAt: now.millisecondsSinceEpoch ~/ 1000,
          timestamp: now,
          content: 'Test',
        ),
        recipientPubkey: _recipientPubkey,
      );

      expect(
        verify(() => recents.recordQueued(_testPubkey, captureAny()))
            .captured
            .single,
        [_recipientPubkey],
      );
    });
  });

  group('shareVideoWithMultipleUsers', () {
    test(
      'one batch preserves recipient order, and each outcome is '
      'reported',
      () async {
        when(() => mockAuthService.isAuthenticated).thenReturn(true);
        when(() => mockAuthService.canPublishNostrWritesNow).thenReturn(true);

        final goodA = testPubkeyFromSeed(5);
        final bad = testPubkeyFromSeed(6);
        final goodC = testPubkeyFromSeed(7);

        when(anySharedVideoSend).thenAnswer(
          (_) async => {
            goodA: const ShareEnqueueOutcome.queued('rumor-a', 'thread-a'),
            bad: const ShareEnqueueOutcome.blocked(),
            goodC: const ShareEnqueueOutcome.queued('rumor-c', 'thread-c'),
          },
        );
        final now = DateTime.now();
        final results = await service.shareVideoWithMultipleUsers(
          video: VideoEvent(
            id: _testVideoId,
            pubkey: _testPubkey,
            createdAt: now.millisecondsSinceEpoch ~/ 1000,
            timestamp: now,
            content: 'Test',
          ),
          recipientPubkeys: [goodA, bad, goodC],
        );

        expect(results.keys, [goodA, bad, goodC]);
        expect(results[goodA]!.delivery, ShareDelivery.queued);
        expect(results[bad]!.delivery, ShareDelivery.notSent);
        expect(results[goodC]!.delivery, ShareDelivery.queued);
        final captured = verify(
          () => mockDmRepository.enqueueSharedVideoBatch(
            recipientPubkeys: captureAny(named: 'recipientPubkeys'),
            baseContent: any(named: 'baseContent'),
            videoKind: any(named: 'videoKind'),
            videoAuthorPubkey: any(named: 'videoAuthorPubkey'),
            videoDTag: any(named: 'videoDTag'),
            videoEventId: any(named: 'videoEventId'),
            relayHint: any(named: 'relayHint'),
          ),
        ).captured;
        expect(captured, [
          [goodA, bad, goodC],
        ]);
        expect(
          verify(
            () => recents.recordQueued(_testPubkey, captureAny()),
          ).captured.single,
          [goodA, goodC],
        );
      },
    );

    group('logging', () {
      final queued = testPubkeyFromSeed(8);
      final blocked = testPubkeyFromSeed(9);
      final invalid = testPubkeyFromSeed(10);
      final logs = LogCaptureService();
      final video = VideoEvent(
        id: _testVideoId,
        pubkey: _testPubkey,
        createdAt: 1,
        timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
        content: 'Test',
      );

      setUp(() async {
        await logs.clearAllLogs();
        when(() => mockAuthService.isAuthenticated).thenReturn(true);
        when(() => mockAuthService.canPublishNostrWritesNow).thenReturn(true);
      });

      Iterable<String> messages(LogLevel level) => logs
          .getRecentLogs()
          .where((entry) => entry.level == level)
          .map((entry) => entry.message);

      String notQueued(String recipient, String reason) =>
          'Video share not queued for ${pubkeyForLogs(recipient)}: $reason';

      test('logs each refused recipient by full npub and hex with its '
          'reason, then the batch totals', () async {
        when(anySharedVideoSend).thenAnswer(
          (_) async => {
            queued: const ShareEnqueueOutcome.queued('rumor', 'thread'),
            blocked: const ShareEnqueueOutcome.blocked(),
            invalid: const ShareEnqueueOutcome.refused('invalid recipient'),
          },
        );

        await service.shareVideoWithMultipleUsers(
          video: video,
          recipientPubkeys: [queued, blocked, invalid],
        );

        expect(messages(LogLevel.warning), [
          notQueued(blocked, 'blocked'),
          notQueued(invalid, 'recipientRefused (invalid recipient)'),
        ]);
        expect(
          messages(LogLevel.info),
          contains('Video share batch: 1 queued, 2 refused'),
        );
      });

      test('logs every recipient a local gate refuses', () async {
        when(() => mockAuthService.isAuthenticated).thenReturn(false);

        await service.shareVideoWithMultipleUsers(
          video: video,
          recipientPubkeys: [queued, blocked],
        );

        expect(messages(LogLevel.warning), [
          notQueued(queued, 'notAuthenticated'),
          notQueued(blocked, 'notAuthenticated'),
        ]);
        verifyNever(anySharedVideoSend);
      });

      test('a failed recents write is logged with its error', () async {
        final written = Completer<void>();
        when(() => recents.recordQueued(any(), any())).thenAnswer((_) {
          written.complete();
          return Future.error(const ShareRecentsStorageException('persist'));
        });
        when(anySharedVideoSend).thenAnswer(
          (_) async => {
            queued: const ShareEnqueueOutcome.queued('rumor', 'thread'),
          },
        );

        await service.shareVideoWithMultipleUsers(
          video: video,
          recipientPubkeys: [queued],
        );
        await written.future;
        await pumpEventQueue();

        final warning = logs.getRecentLogs().singleWhere(
          (entry) => entry.message == 'Could not update local share recents',
        );
        expect(warning.error, contains('could not persist share recents'));
        expect(warning.stackTrace, isNotNull);
      });
    });
  });

  group('sharing utilities', () {
    for (final dTag in <String?>[null, 'actual-coordinate', '🙂' * 64]) {
      test(
        'URL and DM citation share the same real identity for '
        '${dTag == null
            ? 'no d tag'
            : dTag.length > 32
            ? 'an over-long d tag'
            : 'd=$dTag'}',
        () async {
          final video = VideoEvent(
            id: _testVideoId,
            pubkey: _testPubkey,
            createdAt: 1,
            timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
            content: '',
            eventKind: 34236,
            addressableDTag: dTag,
            vineId: 'legacy-vine-id',
            rawTags: const {'vine_id': 'legacy-vine-id'},
          );
          when(() => mockAuthService.isAuthenticated).thenReturn(true);
          when(() => mockAuthService.canPublishNostrWritesNow).thenReturn(true);
          stubSharesSucceed();
          await service.shareVideoWithUser(
            video: video,
            recipientPubkey: _recipientPubkey,
          );
          final captured = verify(
            () => mockDmRepository.enqueueSharedVideoBatch(
              recipientPubkeys: [_recipientPubkey],
              baseContent: captureAny(named: 'baseContent'),
              videoKind: 34236,
              videoAuthorPubkey: _testPubkey,
              videoDTag: captureAny(named: 'videoDTag'),
              videoEventId: _testVideoId,
              relayHint: any(named: 'relayHint'),
            ),
          ).captured;
          final url = divineVideoUrlRegex
              .firstMatch(captured[0] as String)!
              .group(0)!;
          final reference = Uri.parse(url).pathSegments.last;
          if (dTag == 'actual-coordinate') {
            expect(captured[1], dTag);
            expect(NIP19Tlv.decodeNaddr(reference)!.id, dTag);
          } else {
            expect(captured[1], isNull);
            expect(NIP19Tlv.decodeNevent(reference)!.id, _testVideoId);
          }
        },
      );
    }

    test(
      'a video with no kind or d tag cites its exact event as kind 22',
      () async {
        final video = VideoEvent(
          id: _testVideoId,
          pubkey: _testPubkey,
          createdAt: 1,
          timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
          content: '',
        );
        when(() => mockAuthService.isAuthenticated).thenReturn(true);
        when(() => mockAuthService.canPublishNostrWritesNow).thenReturn(true);
        stubSharesSucceed();

        await service.shareVideoWithUser(
          video: video,
          recipientPubkey: _recipientPubkey,
        );

        verify(
          () => mockDmRepository.enqueueSharedVideoBatch(
            recipientPubkeys: [_recipientPubkey],
            baseContent: any(named: 'baseContent'),
            videoKind: 22,
            videoAuthorPubkey: _testPubkey,
            videoEventId: _testVideoId,
            relayHint: any(named: 'relayHint'),
          ),
        ).called(1);
      },
    );

    test('a legacy vine_id without a real d tag shares the exact event', () {
      final video = VideoEvent(
        id: _testVideoId,
        pubkey: _testPubkey,
        createdAt: 1,
        timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
        content: '',
        eventKind: 34236,
        vineId: 'old-vine-id',
        rawTags: const {'vine_id': 'old-vine-id'},
      );
      final url = service.generateShareUrl(video);
      expect(
        NIP19Tlv.decodeNevent(Uri.parse(url).pathSegments.last)!.id,
        _testVideoId,
      );
    });

    test('a regular event with a d tag still shares its exact event ID', () {
      final video = VideoEvent(
        id: _testVideoId,
        pubkey: _testPubkey,
        createdAt: 1,
        timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
        content: '',
        eventKind: 22,
        vineId: 'incidental',
        rawTags: const {'d': 'incidental'},
      );
      final url = service.generateShareUrl(video);
      expect(
        NIP19Tlv.decodeNevent(Uri.parse(url).pathSegments.last)!.id,
        _testVideoId,
      );
    });

    test('an addressable event keeps its actual kind and d tag', () {
      final video = VideoEvent(
        id: _testVideoId,
        pubkey: _testPubkey,
        createdAt: 1,
        timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
        content: '',
        eventKind: 34235,
        addressableDTag: 'clip:one',
      );
      final url = service.generateShareUrl(video);
      final address = NIP19Tlv.decodeNaddr(Uri.parse(url).pathSegments.last)!;
      expect(address.kind, 34235);
      expect(address.author, _testPubkey);
      expect(address.id, 'clip:one');
    });

    test(
      'external shortening preserves the canonical URL in DM messages',
      () async {
        final canonical = divineVideoShareUrl(
          'synthetic-video',
          authorPubkey: _testPubkey,
          kind: 34236,
        );
        const shortened = 'https://divine.video/l/Abc12345';
        final httpClient = MockClient(
          (_) async => http.Response(
            '{"code":"Abc12345","short_url":"$shortened","url":"$canonical"}',
            201,
          ),
        );
        final shortener = ShortLinkClient(
          client: httpClient,
        );
        service = VideoSharingService(
          authService: mockAuthService,
          recentsStore: recents,
          dmRepository: mockDmRepository,
          shortLinkClient: shortener,
        );
        final video = VideoEvent(
          id: _testVideoId,
          pubkey: _testPubkey,
          createdAt: 1,
          timestamp: DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true),
          content: 'Synthetic',
          vineId: 'synthetic-video',
          rawTags: const {'d': 'synthetic-video'},
        );
        expect(
          await service.shortenExternalUrl(service.generateShareUrl(video)),
          shortened,
        );
        expect(service.generateShareData(video).shareUrl, canonical);
        stubSharesSucceed();
        when(() => mockAuthService.isAuthenticated).thenReturn(true);
        when(() => mockAuthService.canPublishNostrWritesNow).thenReturn(true);
        await service.shareVideoWithUser(
          video: video,
          recipientPubkey: _recipientPubkey,
        );
        expect(sharedMessage(), contains(canonical));
        shortener.close();
        httpClient.close();
      },
    );

    test('external shares keep the full URL without a shortener', () async {
      final canonical = divineVideoShareUrl(
        'synthetic-video',
        authorPubkey: _testPubkey,
        kind: 34236,
      );

      expect(await service.shortenExternalUrl(canonical), canonical);
    });

    test('generateShareUrl includes the complete NIP-19 address', () {
      final now = DateTime.now();
      final video = VideoEvent(
        id: _testVideoId,
        pubkey: _testPubkey,
        createdAt: now.millisecondsSinceEpoch ~/ 1000,
        timestamp: now,
        content: 'Test',
        vineId: 'my-vine-id',
        rawTags: const {'d': 'my-vine-id'},
      );

      final url = service.generateShareUrl(video);

      // The d tag alone can name another account's video (#10929).
      expect(
        url,
        equals(
          divineVideoShareUrl(
            'my-vine-id',
            authorPubkey: _testPubkey,
            kind: 34236,
          ),
        ),
      );
    });

    test('generateShareUrl falls back to event id when d tag is missing', () {
      final now = DateTime.now();
      const eventId =
          'a695f6b60119d9521934a691347d9f78e8770b56da16bb255ee77ac112b4c1f6';
      final video = VideoEvent(
        id: eventId,
        pubkey: _testPubkey,
        createdAt: now.millisecondsSinceEpoch ~/ 1000,
        timestamp: now,
        content: 'Test',
        vineId: eventId,
      );

      final url = service.generateShareUrl(video);

      // Always an https URL, never a nostr: URI; a missing d tag shares the
      // exact event as an nevent.
      expect(
        url,
        equals(divineVideoShareUrl(eventId, kind: 22)),
      );
    });

    test('shareUrlForStableId agrees with generateShareUrl', () {
      // The post-publish confirmation has only the d-tag, never a
      // hydrated VideoEvent. If these two ever drift, a freshly
      // published video would be shared under a different URL than
      // the same video shared from the feed.
      final now = DateTime.now();
      final video = VideoEvent(
        id: _testVideoId,
        pubkey: _testPubkey,
        createdAt: now.millisecondsSinceEpoch ~/ 1000,
        timestamp: now,
        content: 'Test',
        vineId: 'my-vine-id',
        rawTags: const {'d': 'my-vine-id'},
      );

      expect(
        VideoSharingService.shareUrlForStableId(
          'my-vine-id',
          authorPubkey: _testPubkey,
          kind: 34236,
        ),
        equals(service.generateShareUrl(video)),
      );
    });
  });
}
