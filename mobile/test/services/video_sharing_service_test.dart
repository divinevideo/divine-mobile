// ABOUTME: Tests for VideoSharingService social features integration
// ABOUTME: Covers NIP-17 share path, NIP-04 fallback, recents,
// ABOUTME: shareVideoWithUser, and sharing utilities.

import 'dart:async';

import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/nip19/pubkey_for_logs.dart';
import 'package:openvine/services/auth_service.dart' hide UserProfile;
import 'package:openvine/services/video_sharing_service.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:unified_logger/unified_logger.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockAuthService extends Mock implements AuthService {}

class _MockProfileRepository extends Mock implements ProfileRepository {}

class _MockDmRepository extends Mock implements DmRepository {}

const _testPubkey =
    'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2';

const _recipientPubkey =
    'b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3';

const _testVideoId =
    'a695f6b60119d9521934a691347d9f78e8770b56da16bb255ee77ac112b4c1f6';

void main() {
  late VideoSharingService service;
  late _MockNostrClient mockNostrService;
  late _MockAuthService mockAuthService;
  late _MockProfileRepository mockProfileRepository;

  setUpAll(() {
    registerFallbackValue(Event(_testPubkey, 4, <List<String>>[], ''));
  });

  setUp(() {
    mockNostrService = _MockNostrClient();
    mockAuthService = _MockAuthService();
    mockProfileRepository = _MockProfileRepository();

    // Default: no DmRepository (NIP-04 fallback path)
    service = VideoSharingService(
      nostrService: mockNostrService,
      authService: mockAuthService,
      profileRepository: mockProfileRepository,
    );
  });

  group('$ShareableUser.fromProfile', () {
    UserProfile profileWith({
      String? nip05,
      String? name,
      String? displayName,
    }) {
      return UserProfile(
        pubkey: _recipientPubkey,
        rawData: const {},
        createdAt: DateTime.now(),
        eventId: 'event-handle',
        nip05: nip05,
        name: name,
        displayName: displayName,
      );
    }

    test('uses the full divine nip05 rather than the short form', () {
      final user = ShareableUser.fromProfile(
        _recipientPubkey,
        profileWith(nip05: 'bob@divine.video', name: 'bob'),
      );

      expect(user.handle, equals('@bob.divine.video'));
    });

    test('keeps an external nip05 verbatim, without a leading @', () {
      final user = ShareableUser.fromProfile(
        _recipientPubkey,
        profileWith(nip05: 'dana@nostrplebs.com', name: 'dana'),
      );

      expect(user.handle, equals('dana@nostrplebs.com'));
    });

    test('trims display nip05 before rendering it as a handle', () {
      final user = ShareableUser.fromProfile(
        _recipientPubkey,
        profileWith(nip05: '  dana@nostrplebs.com  ', name: 'dana'),
      );

      expect(user.handle, equals('dana@nostrplebs.com'));
    });

    test('falls back to name when nip05 is blank after trimming', () {
      final user = ShareableUser.fromProfile(
        _recipientPubkey,
        profileWith(nip05: '   ', name: 'dana'),
      );

      expect(user.handle, equals('@dana'));
    });

    test('falls back to name when nip05 is not handle-shaped', () {
      final user = ShareableUser.fromProfile(
        _recipientPubkey,
        profileWith(nip05: 'dana', name: 'fallback'),
      );

      expect(user.handle, equals('@fallback'));
    });

    test('falls back to name when nip05 is only an at sign', () {
      final user = ShareableUser.fromProfile(
        _recipientPubkey,
        profileWith(nip05: '@', name: 'fallback'),
      );

      expect(user.handle, equals('@fallback'));
    });

    test('falls back to name when nip05 contains whitespace', () {
      final user = ShareableUser.fromProfile(
        _recipientPubkey,
        profileWith(nip05: 'dana @nostrplebs.com', name: 'fallback'),
      );

      expect(user.handle, equals('@fallback'));
    });

    test('falls back to an @-prefixed name when there is no nip05', () {
      final user = ShareableUser.fromProfile(
        _recipientPubkey,
        profileWith(name: 'alice'),
      );

      expect(user.handle, equals('@alice'));
    });

    test('does not double the @ on an email-shaped name', () {
      final user = ShareableUser.fromProfile(
        _recipientPubkey,
        profileWith(name: 'dana@nostrplebs.com'),
      );

      expect(user.handle, equals('dana@nostrplebs.com'));
    });

    test('does not double the @ on an already-prefixed name', () {
      final user = ShareableUser.fromProfile(
        _recipientPubkey,
        profileWith(name: '@dana'),
      );

      expect(user.handle, equals('@dana'));
    });

    test(
      'leaves the handle null when the profile has no nip05 and no name',
      () {
        final user = ShareableUser.fromProfile(
          _recipientPubkey,
          profileWith(displayName: 'Display Only'),
        );

        expect(user.handle, isNull);
        expect(user.displayName, equals('Display Only'));
      },
    );

    test('leaves the handle null when there is no profile at all', () {
      final user = ShareableUser.fromProfile(_recipientPubkey, null);

      expect(user.handle, isNull);
      expect(user.displayName, isNull);
      expect(user.pubkey, equals(_recipientPubkey));
    });
  });

  group('recentlySharedWith', () {
    test('starts empty', () {
      expect(service.recentlySharedWith, isEmpty);
    });

    test('includes profile data after sharing', () async {
      // Arrange - set up successful share
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(() => mockAuthService.canPublishNostrWritesNow).thenReturn(true);
      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer(
        (_) async => Event(_testPubkey, 4, <List<String>>[], 'test'),
      );
      when(() => mockNostrService.publishEvent(any())).thenAnswer(
        (_) async => PublishSuccess(
          event: Event(_testPubkey, 4, <List<String>>[], 'test'),
        ),
      );
      when(
        () => mockProfileRepository.fetchFreshProfile(pubkey: _recipientPubkey),
      ).thenAnswer(
        (_) async => UserProfile(
          pubkey: _recipientPubkey,
          rawData: const {},
          createdAt: DateTime.now(),
          eventId: 'event1',
          displayName: 'Alice',
          picture: 'https://example.com/alice.jpg',
        ),
      );

      final now = DateTime.now();
      final testVideo = VideoEvent(
        id: _testVideoId,
        pubkey: _testPubkey,
        createdAt: now.millisecondsSinceEpoch ~/ 1000,
        timestamp: now,
        content: 'Test video',
      );

      // Act - share a video, which populates recently shared list
      await service.shareVideoWithUser(
        video: testVideo,
        recipientPubkey: _recipientPubkey,
      );
      // The recents update is now fire-and-forget (see #5391); drain the
      // event loop so the background insert completes before asserting.
      await Future<void>.delayed(Duration.zero);

      final result = service.recentlySharedWith;

      // Assert
      expect(result, hasLength(1));
      expect(result[0].pubkey, _recipientPubkey);
      expect(result[0].displayName, 'Alice');
      expect(result[0].picture, 'https://example.com/alice.jpg');
    });

    test('keeps only the ten most recent users', () async {
      // Arrange - share with multiple users
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(() => mockAuthService.canPublishNostrWritesNow).thenReturn(true);
      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer(
        (_) async => Event(_testPubkey, 4, <List<String>>[], 'test'),
      );
      when(() => mockNostrService.publishEvent(any())).thenAnswer(
        (_) async => PublishSuccess(
          event: Event(_testPubkey, 4, <List<String>>[], 'test'),
        ),
      );
      when(
        () => mockProfileRepository.fetchFreshProfile(
          pubkey: any(named: 'pubkey'),
        ),
      ).thenAnswer((_) async => null);

      final now = DateTime.now();
      final testVideo = VideoEvent(
        id: _testVideoId,
        pubkey: _testPubkey,
        createdAt: now.millisecondsSinceEpoch ~/ 1000,
        timestamp: now,
        content: 'Test video',
      );

      // Share with 11 users to exceed the recent list cap.
      for (var i = 0; i < 11; i++) {
        final hexI = i.toRadixString(16).padLeft(64, '0');
        await service.shareVideoWithUser(
          video: testVideo,
          recipientPubkey: hexI,
        );
      }

      // The recents update is now fire-and-forget (see #5391); drain the
      // event loop so all background inserts complete before asserting.
      await Future<void>.delayed(Duration.zero);

      final result = service.recentlySharedWith;

      expect(result.length, 10);
      expect(result.first.pubkey, 'a'.padLeft(64, '0'));
      expect(result.last.pubkey, '1'.padLeft(64, '0'));
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
      expect(result.error, contains('not authenticated'));
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
      expect(result.error, contains('Signing is not available'));
      // Never reached the signer: the gate short-circuits before any event is
      // created, rather than letting it fail 30s later on an RPC timeout.
      verifyNever(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      );
    });

    test('returns failure when event creation fails', () async {
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(() => mockAuthService.canPublishNostrWritesNow).thenReturn(true);
      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((_) async => null);

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
      expect(result.error, contains('Failed to create'));
    });

    test('returns success on successful publish', () async {
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(() => mockAuthService.canPublishNostrWritesNow).thenReturn(true);
      final signedEvent = Event(_testPubkey, 4, <List<String>>[], 'test');
      signedEvent.id = 'signed_event_id';

      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((_) async => signedEvent);
      when(
        () => mockNostrService.publishEvent(any()),
      ).thenAnswer((_) async => PublishSuccess(event: signedEvent));
      when(
        () => mockProfileRepository.fetchFreshProfile(
          pubkey: any(named: 'pubkey'),
        ),
      ).thenAnswer((_) async => null);

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

      expect(result.delivery, ShareDelivery.sent);
      expect(result.messageEventId, equals('signed_event_id'));
    });

    test('returns failure when publish fails', () async {
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(() => mockAuthService.canPublishNostrWritesNow).thenReturn(true);
      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer(
        (_) async => Event(_testPubkey, 4, <List<String>>[], 'test'),
      );
      when(
        () => mockNostrService.publishEvent(any()),
      ).thenAnswer((_) async => const PublishFailed());

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
      expect(result.error, contains('Failed to publish'));
    });
  });

  group('shareVideoWithUser (NIP-17 path)', () {
    late _MockDmRepository mockDmRepository;
    late VideoSharingService nip17Service;

    setUp(() {
      mockDmRepository = _MockDmRepository();
      when(() => mockDmRepository.userPubkey).thenReturn(_testPubkey);

      nip17Service = VideoSharingService(
        nostrService: mockNostrService,
        authService: mockAuthService,
        profileRepository: mockProfileRepository,
        dmRepository: mockDmRepository,
      );
    });

    test('uses NIP-17 when DmRepository is available', () async {
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(() => mockAuthService.canPublishNostrWritesNow).thenReturn(true);
      when(
        () => mockDmRepository.sendSharedVideo(
          recipientPubkey: any(named: 'recipientPubkey'),
          baseContent: any(named: 'baseContent'),
          videoKind: any(named: 'videoKind'),
          videoAuthorPubkey: any(named: 'videoAuthorPubkey'),
          videoDTag: any(named: 'videoDTag'),
          videoEventId: any(named: 'videoEventId'),
          relayHint: any(named: 'relayHint'),
          skipNip04Fallback: any(named: 'skipNip04Fallback'),
        ),
      ).thenAnswer(
        (_) async => NIP17SendResult.success(
          rumorEventId: 'nip17-rumor-id',
          messageEventId: 'nip17-msg-id',
          recipientPubkey: _recipientPubkey,
        ),
      );
      when(
        () => mockProfileRepository.fetchFreshProfile(
          pubkey: any(named: 'pubkey'),
        ),
      ).thenAnswer((_) async => null);

      final now = DateTime.now();
      final result = await nip17Service.shareVideoWithUser(
        video: VideoEvent(
          id: _testVideoId,
          pubkey: _testPubkey,
          createdAt: now.millisecondsSinceEpoch ~/ 1000,
          timestamp: now,
          content: 'Test',
        ),
        recipientPubkey: _recipientPubkey,
      );

      expect(result.delivery, ShareDelivery.sent);
      expect(result.messageEventId, equals('nip17-msg-id'));
      expect(result.conversationId, isNotNull);

      // Verify NIP-17 was used, NOT NIP-04, and that the plaintext kind-4
      // fallback is suppressed for shares (no sender↔recipient metadata leak).
      verify(
        () => mockDmRepository.sendSharedVideo(
          recipientPubkey: _recipientPubkey,
          baseContent: any(named: 'baseContent'),
          videoKind: any(named: 'videoKind'),
          videoAuthorPubkey: any(named: 'videoAuthorPubkey'),
          videoDTag: any(named: 'videoDTag'),
          videoEventId: any(named: 'videoEventId'),
          relayHint: any(named: 'relayHint'),
          skipNip04Fallback: true,
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
      'treats a retryable-pending NIP-17 share as optimistically sent',
      () async {
        when(() => mockAuthService.isAuthenticated).thenReturn(true);
        when(() => mockAuthService.canPublishNostrWritesNow).thenReturn(true);
        when(
          () => mockDmRepository.sendSharedVideo(
            recipientPubkey: any(named: 'recipientPubkey'),
            baseContent: any(named: 'baseContent'),
            videoKind: any(named: 'videoKind'),
            videoAuthorPubkey: any(named: 'videoAuthorPubkey'),
            videoDTag: any(named: 'videoDTag'),
            videoEventId: any(named: 'videoEventId'),
            relayHint: any(named: 'relayHint'),
            skipNip04Fallback: any(named: 'skipNip04Fallback'),
          ),
        ).thenAnswer(
          (_) async => const NIP17SendResult.failure(
            'Recipient DM inbox unreadable; published to the fallback pool',
            retryablePending: true,
            queuedRumorId: 'queued-rumor-id',
          ),
        );
        when(
          () => mockProfileRepository.fetchFreshProfile(
            pubkey: any(named: 'pubkey'),
          ),
        ).thenAnswer((_) async => null);

        final now = DateTime.now();
        final result = await nip17Service.shareVideoWithUser(
          video: VideoEvent(
            id: _testVideoId,
            pubkey: _testPubkey,
            createdAt: now.millisecondsSinceEpoch ~/ 1000,
            timestamp: now,
            content: 'Test',
          ),
          recipientPubkey: _recipientPubkey,
        );

        expect(result.delivery, ShareDelivery.sent);
        expect(result.messageEventId, 'queued-rumor-id');
        expect(result.conversationId, isNotNull);
      },
    );

    test(
      'shareVideoWithMultipleUsers: one recipient failing does not abort the '
      'rest, and each outcome is reported',
      () async {
        when(() => mockAuthService.isAuthenticated).thenReturn(true);
        when(() => mockAuthService.canPublishNostrWritesNow).thenReturn(true);
        when(
          () => mockProfileRepository.fetchFreshProfile(
            pubkey: any(named: 'pubkey'),
          ),
        ).thenAnswer((_) async => null);

        final goodA = 'a' * 64;
        final bad = 'b' * 64;
        final goodC = 'c' * 64;

        when(
          () => mockDmRepository.sendSharedVideo(
            recipientPubkey: any(named: 'recipientPubkey'),
            baseContent: any(named: 'baseContent'),
            videoKind: any(named: 'videoKind'),
            videoAuthorPubkey: any(named: 'videoAuthorPubkey'),
            videoDTag: any(named: 'videoDTag'),
            videoEventId: any(named: 'videoEventId'),
            relayHint: any(named: 'relayHint'),
            skipNip04Fallback: any(named: 'skipNip04Fallback'),
          ),
        ).thenAnswer((invocation) async {
          final pubkey = invocation.namedArguments[#recipientPubkey] as String;
          if (pubkey == bad) throw StateError('boom');
          return NIP17SendResult.success(
            rumorEventId: 'rumor-$pubkey',
            messageEventId: 'msg-$pubkey',
            recipientPubkey: pubkey,
          );
        });

        final now = DateTime.now();
        final results = await nip17Service.shareVideoWithMultipleUsers(
          video: VideoEvent(
            id: _testVideoId,
            pubkey: _testPubkey,
            createdAt: now.millisecondsSinceEpoch ~/ 1000,
            timestamp: now,
            content: 'Test',
          ),
          recipientPubkeys: [goodA, bad, goodC],
        );

        // The middle recipient threw, but the loop still attempted all three
        // and reports a per-recipient result for each.
        expect(results.keys, containsAll(<String>[goodA, bad, goodC]));
        expect(results[goodA]!.delivery, ShareDelivery.sent);
        // A send throws only before its queue row is written, so nothing
        // will retry this recipient.
        expect(results[bad]!.delivery, ShareDelivery.notSent);
        expect(results[goodC]!.delivery, ShareDelivery.sent);
        verify(
          () => mockDmRepository.sendSharedVideo(
            recipientPubkey: goodC,
            baseContent: any(named: 'baseContent'),
            videoKind: any(named: 'videoKind'),
            videoAuthorPubkey: any(named: 'videoAuthorPubkey'),
            videoDTag: any(named: 'videoDTag'),
            videoEventId: any(named: 'videoEventId'),
            relayHint: any(named: 'relayHint'),
            skipNip04Fallback: any(named: 'skipNip04Fallback'),
          ),
        ).called(1);
      },
    );

    test(
      'returns success without waiting on the recents profile fetch (#5391)',
      () async {
        when(() => mockAuthService.isAuthenticated).thenReturn(true);
        when(() => mockAuthService.canPublishNostrWritesNow).thenReturn(true);
        when(
          () => mockDmRepository.sendSharedVideo(
            recipientPubkey: any(named: 'recipientPubkey'),
            baseContent: any(named: 'baseContent'),
            videoKind: any(named: 'videoKind'),
            videoAuthorPubkey: any(named: 'videoAuthorPubkey'),
            videoDTag: any(named: 'videoDTag'),
            videoEventId: any(named: 'videoEventId'),
            relayHint: any(named: 'relayHint'),
            skipNip04Fallback: any(named: 'skipNip04Fallback'),
          ),
        ).thenAnswer(
          (_) async => NIP17SendResult.success(
            rumorEventId: 'nip17-rumor-id',
            messageEventId: 'nip17-msg-id',
            recipientPubkey: _recipientPubkey,
          ),
        );
        // The post-send recents refresh must be fire-and-forget: a hung
        // profile fetch must NOT delay the success result (the toast).
        final neverCompletes = Completer<UserProfile?>();
        when(
          () => mockProfileRepository.fetchFreshProfile(
            pubkey: any(named: 'pubkey'),
          ),
        ).thenAnswer((_) => neverCompletes.future);

        final now = DateTime.now();
        final result = await nip17Service
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

        expect(result.delivery, ShareDelivery.sent);
        expect(result.messageEventId, equals('nip17-msg-id'));
      },
    );

    test('returns failure when NIP-17 send fails', () async {
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(() => mockAuthService.canPublishNostrWritesNow).thenReturn(true);
      when(
        () => mockDmRepository.sendSharedVideo(
          recipientPubkey: any(named: 'recipientPubkey'),
          baseContent: any(named: 'baseContent'),
          videoKind: any(named: 'videoKind'),
          videoAuthorPubkey: any(named: 'videoAuthorPubkey'),
          videoDTag: any(named: 'videoDTag'),
          videoEventId: any(named: 'videoEventId'),
          relayHint: any(named: 'relayHint'),
          skipNip04Fallback: any(named: 'skipNip04Fallback'),
        ),
      ).thenAnswer(
        (_) async => const NIP17SendResult.failure('Relay rejected'),
      );

      final now = DateTime.now();
      final result = await nip17Service.shareVideoWithUser(
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
      expect(result.error, contains('Relay rejected'));
    });

    group('reports what will happen to a share that did not go out', () {
      Future<ShareResult> shareWith(NIP17SendResult sendResult) {
        when(() => mockAuthService.isAuthenticated).thenReturn(true);
        when(() => mockAuthService.canPublishNostrWritesNow).thenReturn(true);
        when(
          () => mockDmRepository.sendSharedVideo(
            recipientPubkey: any(named: 'recipientPubkey'),
            baseContent: any(named: 'baseContent'),
            videoKind: any(named: 'videoKind'),
            videoAuthorPubkey: any(named: 'videoAuthorPubkey'),
            videoDTag: any(named: 'videoDTag'),
            videoEventId: any(named: 'videoEventId'),
            relayHint: any(named: 'relayHint'),
            skipNip04Fallback: any(named: 'skipNip04Fallback'),
          ),
        ).thenAnswer((_) async => sendResult);

        final now = DateTime.now();
        return nip17Service.shareVideoWithUser(
          video: VideoEvent(
            id: _testVideoId,
            pubkey: _testPubkey,
            createdAt: now.millisecondsSinceEpoch ~/ 1000,
            timestamp: now,
            content: 'Test',
          ),
          recipientPubkey: _recipientPubkey,
        );
      }

      test(
        'a failed publish that left a queue row is retrying, not failed',
        () async {
          final result = await shareWith(
            const NIP17SendResult.failure(
              'Relay rejected',
              queuedRumorId: 'queued-rumor-id',
            ),
          );

          expect(result.delivery, ShareDelivery.retrying);
        },
      );

      test(
        'a send-policy refusal is not sent: it is never queued (#8672)',
        () async {
          final result = await shareWith(
            const NIP17SendResult.blocked(
              'blocked: recipient not permitted by send policy',
            ),
          );

          expect(result.delivery, ShareDelivery.notSent);
        },
      );

      test('an oversized message is not sent: it is never queued', () async {
        final result = await shareWith(
          const NIP17SendResult.tooLong('message is too large to send'),
        );

        expect(result.delivery, ShareDelivery.notSent);
      });

      group('logs', () {
        late LogCaptureService logCapture;

        setUp(() async {
          logCapture = LogCaptureService();
          await logCapture.clearAllLogs();
        });

        tearDown(() async {
          await logCapture.clearAllLogs();
        });

        List<String> shareLines() => [
          for (final entry in logCapture.getRecentLogs())
            if (entry.message.startsWith('Share to ')) entry.message,
        ];

        test('a refused recipient by npub and hex, as never retried', () async {
          await shareWith(
            const NIP17SendResult.blocked(
              'blocked: recipient not permitted by send policy',
            ),
          );

          final line =
              'Share to ${pubkeyForLogs(_recipientPubkey)} not sent and not '
              'queued: blocked: recipient not permitted by send policy';
          expect(shareLines(), [line]);
        });

        test('a queued recipient with the queue row the retry sends', () async {
          await shareWith(
            const NIP17SendResult.failure(
              'Relay rejected',
              queuedRumorId: 'queued-rumor-id',
            ),
          );

          final line =
              'Share to ${pubkeyForLogs(_recipientPubkey)} not published; '
              'queued for background retry as queued-rumor-id: Relay rejected';
          expect(shareLines(), [line]);
        });
      });
    });

    test('includes personal message in content', () async {
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(() => mockAuthService.canPublishNostrWritesNow).thenReturn(true);
      when(
        () => mockDmRepository.sendSharedVideo(
          recipientPubkey: any(named: 'recipientPubkey'),
          baseContent: any(named: 'baseContent'),
          videoKind: any(named: 'videoKind'),
          videoAuthorPubkey: any(named: 'videoAuthorPubkey'),
          videoDTag: any(named: 'videoDTag'),
          videoEventId: any(named: 'videoEventId'),
          relayHint: any(named: 'relayHint'),
          skipNip04Fallback: any(named: 'skipNip04Fallback'),
        ),
      ).thenAnswer(
        (_) async => NIP17SendResult.success(
          rumorEventId: 'nip17-rumor-id',
          messageEventId: 'nip17-msg-id',
          recipientPubkey: _recipientPubkey,
        ),
      );
      when(
        () => mockProfileRepository.fetchFreshProfile(
          pubkey: any(named: 'pubkey'),
        ),
      ).thenAnswer((_) async => null);

      final now = DateTime.now();
      await nip17Service.shareVideoWithUser(
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

      final captured = verify(
        () => mockDmRepository.sendSharedVideo(
          recipientPubkey: any(named: 'recipientPubkey'),
          baseContent: captureAny(named: 'baseContent'),
          videoKind: any(named: 'videoKind'),
          videoAuthorPubkey: any(named: 'videoAuthorPubkey'),
          videoDTag: any(named: 'videoDTag'),
          videoEventId: any(named: 'videoEventId'),
          relayHint: any(named: 'relayHint'),
          skipNip04Fallback: any(named: 'skipNip04Fallback'),
        ),
      ).captured;

      expect(captured.first as String, contains('Check this out!'));
    });

    test('share message contains quoted title and share URL', () async {
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(() => mockAuthService.canPublishNostrWritesNow).thenReturn(true);
      when(
        () => mockDmRepository.sendSharedVideo(
          recipientPubkey: any(named: 'recipientPubkey'),
          baseContent: any(named: 'baseContent'),
          videoKind: any(named: 'videoKind'),
          videoAuthorPubkey: any(named: 'videoAuthorPubkey'),
          videoDTag: any(named: 'videoDTag'),
          videoEventId: any(named: 'videoEventId'),
          relayHint: any(named: 'relayHint'),
          skipNip04Fallback: any(named: 'skipNip04Fallback'),
        ),
      ).thenAnswer(
        (_) async => NIP17SendResult.success(
          rumorEventId: 'nip17-rumor-id',
          messageEventId: 'nip17-msg-id',
          recipientPubkey: _recipientPubkey,
        ),
      );
      when(
        () => mockProfileRepository.fetchFreshProfile(
          pubkey: any(named: 'pubkey'),
        ),
      ).thenAnswer((_) async => null);

      final now = DateTime.now();
      await nip17Service.shareVideoWithUser(
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

      final captured = verify(
        () => mockDmRepository.sendSharedVideo(
          recipientPubkey: any(named: 'recipientPubkey'),
          baseContent: captureAny(named: 'baseContent'),
          videoKind: any(named: 'videoKind'),
          videoAuthorPubkey: any(named: 'videoAuthorPubkey'),
          videoDTag: any(named: 'videoDTag'),
          videoEventId: any(named: 'videoEventId'),
          relayHint: any(named: 'relayHint'),
          skipNip04Fallback: any(named: 'skipNip04Fallback'),
        ),
      ).captured;

      final message = captured.first as String;
      expect(message, contains('"Indigenous cultures"'));
      expect(message, contains('divine.video/video/'));
    });

    test('share message without title contains only share URL', () async {
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(() => mockAuthService.canPublishNostrWritesNow).thenReturn(true);
      when(
        () => mockDmRepository.sendSharedVideo(
          recipientPubkey: any(named: 'recipientPubkey'),
          baseContent: any(named: 'baseContent'),
          videoKind: any(named: 'videoKind'),
          videoAuthorPubkey: any(named: 'videoAuthorPubkey'),
          videoDTag: any(named: 'videoDTag'),
          videoEventId: any(named: 'videoEventId'),
          relayHint: any(named: 'relayHint'),
          skipNip04Fallback: any(named: 'skipNip04Fallback'),
        ),
      ).thenAnswer(
        (_) async => NIP17SendResult.success(
          rumorEventId: 'nip17-rumor-id',
          messageEventId: 'nip17-msg-id',
          recipientPubkey: _recipientPubkey,
        ),
      );
      when(
        () => mockProfileRepository.fetchFreshProfile(
          pubkey: any(named: 'pubkey'),
        ),
      ).thenAnswer((_) async => null);

      final now = DateTime.now();
      await nip17Service.shareVideoWithUser(
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

      final captured = verify(
        () => mockDmRepository.sendSharedVideo(
          recipientPubkey: any(named: 'recipientPubkey'),
          baseContent: captureAny(named: 'baseContent'),
          videoKind: any(named: 'videoKind'),
          videoAuthorPubkey: any(named: 'videoAuthorPubkey'),
          videoDTag: any(named: 'videoDTag'),
          videoEventId: any(named: 'videoEventId'),
          relayHint: any(named: 'relayHint'),
          skipNip04Fallback: any(named: 'skipNip04Fallback'),
        ),
      ).captured;

      final message = captured.first as String;
      expect(message, contains('divine.video/video/'));
      expect(message, isNot(contains('"')));
    });

    test('computes correct conversationId', () async {
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(() => mockAuthService.canPublishNostrWritesNow).thenReturn(true);
      when(
        () => mockDmRepository.sendSharedVideo(
          recipientPubkey: any(named: 'recipientPubkey'),
          baseContent: any(named: 'baseContent'),
          videoKind: any(named: 'videoKind'),
          videoAuthorPubkey: any(named: 'videoAuthorPubkey'),
          videoDTag: any(named: 'videoDTag'),
          videoEventId: any(named: 'videoEventId'),
          relayHint: any(named: 'relayHint'),
          skipNip04Fallback: any(named: 'skipNip04Fallback'),
        ),
      ).thenAnswer(
        (_) async => NIP17SendResult.success(
          rumorEventId: 'nip17-rumor-id',
          messageEventId: 'nip17-msg-id',
          recipientPubkey: _recipientPubkey,
        ),
      );
      when(
        () => mockProfileRepository.fetchFreshProfile(
          pubkey: any(named: 'pubkey'),
        ),
      ).thenAnswer((_) async => null);

      final now = DateTime.now();
      final result = await nip17Service.shareVideoWithUser(
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
      when(
        () => mockDmRepository.sendSharedVideo(
          recipientPubkey: any(named: 'recipientPubkey'),
          baseContent: any(named: 'baseContent'),
          videoKind: any(named: 'videoKind'),
          videoAuthorPubkey: any(named: 'videoAuthorPubkey'),
          videoDTag: any(named: 'videoDTag'),
          videoEventId: any(named: 'videoEventId'),
          relayHint: any(named: 'relayHint'),
          skipNip04Fallback: any(named: 'skipNip04Fallback'),
        ),
      ).thenAnswer(
        (_) async => NIP17SendResult.success(
          rumorEventId: 'nip17-rumor-id',
          messageEventId: 'nip17-msg-id',
          recipientPubkey: _recipientPubkey,
        ),
      );
      when(
        () => mockProfileRepository.fetchFreshProfile(
          pubkey: any(named: 'pubkey'),
        ),
      ).thenAnswer((_) async => null);

      final now = DateTime.now();
      await nip17Service.shareVideoWithUser(
        video: VideoEvent(
          id: _testVideoId,
          pubkey: _testPubkey,
          createdAt: now.millisecondsSinceEpoch ~/ 1000,
          timestamp: now,
          content: 'Test',
        ),
        recipientPubkey: _recipientPubkey,
      );

      expect(nip17Service.hasSharedWithRecently(_recipientPubkey), isTrue);
    });
  });

  group('sharing utilities', () {
    test('generateShareUrl uses stableId when video has a d tag', () {
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

      expect(url, equals('https://divine.video/video/my-vine-id'));
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

      // Always emits an https URL — never a nostr: URI. The route
      // handler accepts raw event IDs as well as d-tags / NIP-19 refs.
      expect(url, equals('https://divine.video/video/$eventId'));
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
        VideoSharingService.shareUrlForStableId('my-vine-id'),
        equals(service.generateShareUrl(video)),
      );
    });

    test('hasSharedWithRecently returns false for unknown user', () {
      expect(service.hasSharedWithRecently('unknown'), isFalse);
    });

    test('hasSharedWithRecently returns true after sharing', () async {
      // Arrange
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(() => mockAuthService.canPublishNostrWritesNow).thenReturn(true);
      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer(
        (_) async => Event(_testPubkey, 4, <List<String>>[], 'test'),
      );
      when(() => mockNostrService.publishEvent(any())).thenAnswer(
        (_) async => PublishSuccess(
          event: Event(_testPubkey, 4, <List<String>>[], 'test'),
        ),
      );
      when(
        () => mockProfileRepository.fetchFreshProfile(
          pubkey: any(named: 'pubkey'),
        ),
      ).thenAnswer((_) async => null);

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

      expect(service.hasSharedWithRecently(_recipientPubkey), isTrue);
    });

    test('clearSharingHistory removes all data', () async {
      // Arrange - populate some history
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(() => mockAuthService.canPublishNostrWritesNow).thenReturn(true);
      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer(
        (_) async => Event(_testPubkey, 4, <List<String>>[], 'test'),
      );
      when(() => mockNostrService.publishEvent(any())).thenAnswer(
        (_) async => PublishSuccess(
          event: Event(_testPubkey, 4, <List<String>>[], 'test'),
        ),
      );
      when(
        () => mockProfileRepository.fetchFreshProfile(
          pubkey: any(named: 'pubkey'),
        ),
      ).thenAnswer((_) async => null);

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

      // Act
      service.clearSharingHistory();

      // Assert
      expect(service.recentlySharedWith, isEmpty);
      expect(service.hasSharedWithRecently(_recipientPubkey), isFalse);
    });
  });
}
