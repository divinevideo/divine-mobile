import 'dart:async';
import 'dart:convert';

import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:content_policy/content_policy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockNostrClient extends Mock implements NostrClient {
  _MockNostrClient() {
    // The own-mute-list read goes through `queryEventsDetailed` so it can tell
    // a relay's "I hold nothing" apart from an answer nobody gave (#6750).
    // Every test that stubs `queryEvents` is describing the former, so mirror
    // it here as a settled answer. Tests about the inconclusive read override
    // this stub with `timedOut` or `noRelays`.
    when(
      () => queryEventsDetailed(
        any(),
        requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
      ),
    ).thenAnswer((invocation) async {
      final filters = invocation.positionalArguments[0] as List<Filter>;
      return (
        events: await queryEvents(filters),
        timedOut: false,
        noRelays: false,
      );
    });
  }
}

class _MockBlockListSigner extends Mock implements BlockListSigner {}

class _MockSharedPreferences extends Mock implements SharedPreferences {}

class _FakeEvent extends Fake implements Event {}

void main() {
  setUpAll(() {
    registerFallbackValue(<Filter>[]);
    registerFallbackValue(_FakeEvent());
  });

  group('ContentBlocklistRepository', () {
    late ContentBlocklistRepository service;

    setUp(() {
      service = ContentBlocklistRepository();
    });

    test('should initialize with no hardcoded blocked accounts', () {
      // Moderation should happen at relay level, not hardcoded in app
      expect(service.totalBlockedCount, equals(0));
    });

    test('should block users at runtime', () async {
      const testPubkey1 = 'pubkey_to_block_1';
      const testPubkey2 = 'pubkey_to_block_2';

      // Initially no blocks
      expect(service.totalBlockedCount, equals(0));
      expect(service.isBlocked(testPubkey1), isFalse);
      expect(service.isBlocked(testPubkey2), isFalse);

      // Block users at runtime
      await service.blockUser(testPubkey1);
      await service.blockUser(testPubkey2);

      expect(service.totalBlockedCount, equals(2));
      expect(service.isBlocked(testPubkey1), isTrue);
      expect(service.isBlocked(testPubkey2), isTrue);
    });

    test(
      'blockUsers blocks a batch and emits one change per new pubkey',
      () async {
        const pubkey1 = 'pubkey_to_block_1';
        const pubkey2 = 'pubkey_to_block_2';
        final emitted = <BlocklistChange>[];
        final sub = service.changes.listen(emitted.add);

        await service.blockUsers([pubkey1, pubkey2, pubkey1]);
        await Future<void>.delayed(Duration.zero);

        expect(service.isBlocked(pubkey1), isTrue);
        expect(service.isBlocked(pubkey2), isTrue);
        expect(
          emitted,
          [
            const BlocklistChange(pubkey: pubkey1, op: BlocklistOp.blocked),
            const BlocklistChange(pubkey: pubkey2, op: BlocklistOp.blocked),
          ],
        );

        await sub.cancel();
      },
    );

    test('blockUsers skips self and already-blocked pubkeys', () async {
      const ourPubkey = 'our_pubkey';
      const otherPubkey = 'other_pubkey';

      await service.blockUser(otherPubkey, ourPubkey: ourPubkey);
      await service.blockUsers(
        [ourPubkey, otherPubkey],
        ourPubkey: ourPubkey,
      );

      expect(service.isBlocked(ourPubkey), isFalse);
      expect(service.runtimeBlockedUsers, {otherPubkey});
    });

    test('should filter blocked content from feeds', () async {
      const blockedPubkey = 'blocked_user_pubkey';
      const allowedPubkey = 'allowed_user_pubkey';

      // Block a user first
      await service.blockUser(blockedPubkey);

      expect(service.shouldFilterFromFeeds(blockedPubkey), isTrue);
      expect(service.shouldFilterFromFeeds(allowedPubkey), isFalse);
    });

    test('should allow runtime blocking and unblocking', () async {
      const testPubkey = 'test_pubkey_for_runtime_blocking';

      // Initially not blocked
      expect(service.isBlocked(testPubkey), isFalse);

      // Block user
      await service.blockUser(testPubkey);
      expect(service.isBlocked(testPubkey), isTrue);

      // Unblock user
      await service.unblockUser(testPubkey);
      expect(service.isBlocked(testPubkey), isFalse);
    });

    test('should filter content list correctly', () async {
      const blockedPubkey1 = 'blocked_pubkey_1';
      const blockedPubkey2 = 'blocked_pubkey_2';

      // Block users first
      await service.blockUser(blockedPubkey1);
      await service.blockUser(blockedPubkey2);

      final testItems = [
        {'pubkey': blockedPubkey1, 'content': 'blocked'},
        {'pubkey': 'allowed_user', 'content': 'allowed'},
        {'pubkey': blockedPubkey2, 'content': 'blocked2'},
      ];

      final filtered = service.filterContent(
        testItems,
        (item) => item['pubkey']!,
      );

      expect(filtered.length, equals(1));
      expect(filtered.first['content'], equals('allowed'));
    });

    test('filterBlockedConversations filters blocked participants', () async {
      const userPubkey = 'current_user';
      const blockedPubkey = 'blocked_user';
      const allowedPubkey = 'allowed_user';

      await service.blockUser(blockedPubkey);

      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final conversations = [
        DmConversation(
          id: 'conv1',
          participantPubkeys: const [userPubkey, blockedPubkey],
          isGroup: false,
          createdAt: now,
        ),
        DmConversation(
          id: 'conv2',
          participantPubkeys: const [userPubkey, allowedPubkey],
          isGroup: false,
          createdAt: now,
        ),
      ];

      final filtered = service.filterBlockedConversations(
        conversations,
        userPubkey: userPubkey,
      );

      expect(filtered, hasLength(1));
      expect(filtered.first.id, equals('conv2'));
    });

    test('filterBlockedConversations returns all when no blocks', () {
      const userPubkey = 'current_user';

      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final conversations = [
        DmConversation(
          id: 'conv1',
          participantPubkeys: const [userPubkey, 'other1'],
          isGroup: false,
          createdAt: now,
        ),
        DmConversation(
          id: 'conv2',
          participantPubkeys: const [userPubkey, 'other2'],
          isGroup: false,
          createdAt: now,
        ),
      ];

      final filtered = service.filterBlockedConversations(
        conversations,
        userPubkey: userPubkey,
      );

      expect(filtered, hasLength(2));
    });

    test('filterBlockedConversations excludes self-conversations', () {
      const userPubkey = 'current_user';

      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final conversations = [
        DmConversation(
          id: 'self_conv',
          participantPubkeys: const [userPubkey, userPubkey],
          isGroup: false,
          createdAt: now,
        ),
        DmConversation(
          id: 'normal_conv',
          participantPubkeys: const [userPubkey, 'other_user'],
          isGroup: false,
          createdAt: now,
        ),
      ];

      final filtered = service.filterBlockedConversations(
        conversations,
        userPubkey: userPubkey,
      );

      expect(filtered, hasLength(1));
      expect(filtered.first.id, equals('normal_conv'));
    });

    test('should provide blocking stats', () {
      final stats = service.blockingStats;

      expect(stats['total_blocks'], isA<int>());
      expect(stats['runtime_blocks'], isA<int>());
      expect(stats['internal_blocks'], isA<int>());
    });

    test('invokes onChanged callback for local block changes', () async {
      var changeCount = 0;
      service = ContentBlocklistRepository(onChanged: () => changeCount++);

      await service.blockUser('blocked_pubkey');
      await service.unblockUser('blocked_pubkey');

      expect(changeCount, equals(2));
    });

    group('changes stream', () {
      test('blockUser emits BlocklistOp.blocked', () async {
        const target = 'pubkey-target';
        final emitted = <BlocklistChange>[];
        final sub = service.changes.listen(emitted.add);
        addTearDown(sub.cancel);

        await service.blockUser(target);
        await Future<void>.delayed(Duration.zero);

        expect(
          emitted,
          equals([
            const BlocklistChange(
              pubkey: target,
              op: BlocklistOp.blocked,
            ),
          ]),
        );
      });

      test('unblockUser emits BlocklistOp.unblocked', () async {
        const target = 'pubkey-target';
        await service.blockUser(target);

        final emitted = <BlocklistChange>[];
        final sub = service.changes.listen(emitted.add);
        addTearDown(sub.cancel);

        await service.unblockUser(target);
        await Future<void>.delayed(Duration.zero);

        expect(
          emitted,
          equals([
            const BlocklistChange(
              pubkey: target,
              op: BlocklistOp.unblocked,
            ),
          ]),
        );
      });

      test('block + unblock round-trip emits both ops in order', () async {
        const target = 'pubkey-target';
        final emitted = <BlocklistChange>[];
        final sub = service.changes.listen(emitted.add);
        addTearDown(sub.cancel);

        await service.blockUser(target);
        await service.unblockUser(target);
        await Future<void>.delayed(Duration.zero);

        expect(
          emitted.map((c) => c.op),
          equals([
            BlocklistOp.blocked,
            BlocklistOp.unblocked,
          ]),
        );
        expect(emitted.every((c) => c.pubkey == target), isTrue);
      });

      test(
        're-blocking the same pubkey is a no-op (no duplicate emit)',
        () async {
          const target = 'pubkey-target';
          await service.blockUser(target);

          final emitted = <BlocklistChange>[];
          final sub = service.changes.listen(emitted.add);
          addTearDown(sub.cancel);

          await service.blockUser(target);
          await Future<void>.delayed(Duration.zero);

          expect(emitted, isEmpty);
        },
      );

      test('isAddition is correct for every op', () {
        const additions = [
          BlocklistOp.blocked,
          BlocklistOp.muted,
          BlocklistOp.mutedByUs,
          BlocklistOp.blockedUs,
        ];
        const removals = [
          BlocklistOp.unblocked,
          BlocklistOp.unmuted,
          BlocklistOp.unmutedByUs,
          BlocklistOp.unblockedUs,
        ];

        for (final op in additions) {
          expect(
            BlocklistChange(pubkey: 'p', op: op).isAddition,
            isTrue,
            reason: 'op $op should be an addition',
          );
        }
        for (final op in removals) {
          expect(
            BlocklistChange(pubkey: 'p', op: op).isAddition,
            isFalse,
            reason: 'op $op should NOT be an addition',
          );
        }
      });
    });

    group('self-block prevention', () {
      test(
        'blockUser() ignores when pubkey matches ourPubkey parameter',
        () async {
          const ourPubkey = 'test_our_pubkey';

          await service.blockUser(ourPubkey, ourPubkey: ourPubkey);

          expect(service.isBlocked(ourPubkey), isFalse);
          expect(service.totalBlockedCount, equals(0));
        },
      );

      test('blockUser() allows blocking other users', () async {
        const ourPubkey = 'our_pubkey';
        const otherPubkey = 'other_pubkey';

        await service.blockUser(otherPubkey, ourPubkey: ourPubkey);

        expect(service.isBlocked(otherPubkey), isTrue);
        expect(service.totalBlockedCount, equals(1));
      });

      test('blockUser() allows blocking when ourPubkey is null', () async {
        const otherPubkey = 'other_pubkey';

        // No ourPubkey provided - should allow blocking
        await service.blockUser(otherPubkey);

        expect(service.isBlocked(otherPubkey), isTrue);
        expect(service.totalBlockedCount, equals(1));
      });
    });
  });

  group('ContentBlocklistRepository - Mutual Mute Sync', () {
    late ContentBlocklistRepository service;
    late _MockNostrClient mockNostrService;

    setUp(() {
      service = ContentBlocklistRepository();
      mockNostrService = _MockNostrClient();
    });

    test(
      'syncMuteListsInBackground subscribes to mutual and own kind 10000',
      () async {
        const ourPubkey = 'test_our_pubkey_hex';

        List<dynamic>? capturedFilters;
        when(() => mockNostrService.subscribe(any())).thenAnswer((invocation) {
          capturedFilters = invocation.positionalArguments[0] as List;
          return const Stream.empty();
        });

        await service.syncMuteListsInBackground(mockNostrService, ourPubkey);

        // Verify subscribeToEvents was called
        verify(() => mockNostrService.subscribe(any())).called(1);

        expect(capturedFilters, isNotNull);
        expect(capturedFilters!.length, equals(2));

        final mutualFilter = capturedFilters![0] as Filter;
        expect(mutualFilter.kinds, contains(10000));
        expect(mutualFilter.p, contains(ourPubkey));

        final ownFilter = capturedFilters![1] as Filter;
        expect(ownFilter.kinds, contains(10000));
        expect(ownFilter.authors, contains(ourPubkey));
      },
    );

    test('syncMuteListsInBackground only subscribes once', () async {
      const ourPubkey = 'test_our_pubkey_hex';

      when(
        () => mockNostrService.subscribe(any()),
      ).thenAnswer((_) => const Stream.empty());

      await service.syncMuteListsInBackground(mockNostrService, ourPubkey);
      await service.syncMuteListsInBackground(mockNostrService, ourPubkey);
      await service.syncMuteListsInBackground(mockNostrService, ourPubkey);

      // Should only subscribe once
      verify(() => mockNostrService.subscribe(any())).called(1);
    });

    test(
      'handleMuteListEvent adds muter to blocklist when our pubkey is in tags',
      () async {
        const ourPubkey =
            '0000000000000000000000000000000000000000000000000000000000000001';
        const muterPubkey =
            '0000000000000000000000000000000000000000000000000000000000000002';

        // Create a kind 10000 event with our pubkey in the 'p' tags
        final event =
            Event(
                muterPubkey,
                10000,
                [
                  ['p', ourPubkey],
                  ['p', 'some_other_pubkey'],
                ],
                '',
                createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
              )
              ..id = 'event-id'
              ..sig = 'signature';

        when(
          () => mockNostrService.subscribe(any()),
        ).thenAnswer((_) => Stream.fromIterable([event]));

        await service.syncMuteListsInBackground(mockNostrService, ourPubkey);

        // Give the stream time to emit
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Verify muter is now blocked
        expect(service.shouldFilterFromFeeds(muterPubkey), isTrue);
      },
    );

    test(
      'handleMuteListEvent removes muter when our pubkey not in tags (unmuted)',
      () async {
        const ourPubkey =
            '0000000000000000000000000000000000000000000000000000000000000001';
        const muterPubkey =
            '0000000000000000000000000000000000000000000000000000000000000002';

        // First event: muter adds us to their list
        final muteEvent =
            Event(
                muterPubkey,
                10000,
                [
                  ['p', ourPubkey],
                ],
                '',
                createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
              )
              ..id = 'event-id-1'
              ..sig = 'signature';

        // Second event: muter removes us from their list (replaceable event)
        final unmuteEvent =
            Event(
                muterPubkey,
                10000,
                [
                  ['p', 'some_other_pubkey'], // Our pubkey is gone
                ],
                '',
                createdAt: (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 60,
              )
              ..id = 'event-id-2'
              ..sig = 'signature';

        // Create a stream controller to manually emit events
        final controller = StreamController<Event>();

        when(
          () => mockNostrService.subscribe(any()),
        ).thenAnswer((_) => controller.stream);

        await service.syncMuteListsInBackground(mockNostrService, ourPubkey);

        // First event - adds to blocklist
        controller.add(muteEvent);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(service.shouldFilterFromFeeds(muterPubkey), isTrue);

        // Second event - removes from blocklist
        controller.add(unmuteEvent);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(service.shouldFilterFromFeeds(muterPubkey), isFalse);

        await controller.close();
      },
    );

    test(
      'ignores stale older mute event after newer unmute event',
      () async {
        const ourPubkey =
            '0000000000000000000000000000000000000000000000000000000000000001';
        const muterPubkey =
            '0000000000000000000000000000000000000000000000000000000000000002';

        final newerUnmuteEvent =
            Event(
                muterPubkey,
                10000,
                [
                  ['p', 'some_other_pubkey'],
                ],
                '',
                createdAt: (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 60,
              )
              ..id = 'newer-unmute-event-id'
              ..sig = 'signature';

        final olderMuteEvent =
            Event(
                muterPubkey,
                10000,
                [
                  ['p', ourPubkey],
                ],
                '',
                createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
              )
              ..id = 'older-mute-event-id'
              ..sig = 'signature';

        final controller = StreamController<Event>();

        when(
          () => mockNostrService.subscribe(any()),
        ).thenAnswer((_) => controller.stream);

        await service.syncMuteListsInBackground(mockNostrService, ourPubkey);

        controller.add(newerUnmuteEvent);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(service.hasMutedUs(muterPubkey), isFalse);

        controller.add(olderMuteEvent);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(service.hasMutedUs(muterPubkey), isFalse);
        expect(service.shouldFilterFromFeeds(muterPubkey), isFalse);

        await controller.close();
      },
    );

    test('shouldFilterFromFeeds checks mutual mute blocklist', () async {
      const ourPubkey =
          '0000000000000000000000000000000000000000000000000000000000000001';
      const muterPubkey =
          '0000000000000000000000000000000000000000000000000000000000000002';
      const randomPubkey =
          '0000000000000000000000000000000000000000000000000000000000000003';

      final event =
          Event(
              muterPubkey,
              10000,
              [
                ['p', ourPubkey],
              ],
              '',
              createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            )
            ..id = 'event-id'
            ..sig = 'signature';

      when(
        () => mockNostrService.subscribe(any()),
      ).thenAnswer((_) => Stream.fromIterable([event]));

      await service.syncMuteListsInBackground(mockNostrService, ourPubkey);

      // Give the stream time to emit
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Mutual muter should be filtered
      expect(service.shouldFilterFromFeeds(muterPubkey), isTrue);

      // Random user should not be filtered
      expect(service.shouldFilterFromFeeds(randomPubkey), isFalse);
    });

    test(
      'hasMutedUs only checks mutual mute blocklist, not runtime blocks',
      () async {
        const ourPubkey =
            '0000000000000000000000000000000000000000000000000000000000000001';
        const muterPubkey =
            '0000000000000000000000000000000000000000000000000000000000000002';
        const blockedByUsPubkey =
            '0000000000000000000000000000000000000000000000000000000000000003';

        final event =
            Event(
                muterPubkey,
                10000,
                [
                  ['p', ourPubkey],
                ],
                '',
                createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
              )
              ..id = 'event-id'
              ..sig = 'signature';

        when(
          () => mockNostrService.subscribe(any()),
        ).thenAnswer((_) => Stream.fromIterable([event]));

        await service.syncMuteListsInBackground(mockNostrService, ourPubkey);

        // Give the stream time to emit
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Block a user ourselves
        await service.blockUser(blockedByUsPubkey);

        // hasMutedUs should return true for mutual muter
        expect(service.hasMutedUs(muterPubkey), isTrue);

        // hasMutedUs should return false for user WE blocked
        // (this is the key distinction - we can still view their profile)
        expect(service.hasMutedUs(blockedByUsPubkey), isFalse);

        // But shouldFilterFromFeeds includes both
        expect(service.shouldFilterFromFeeds(muterPubkey), isTrue);
        expect(service.shouldFilterFromFeeds(blockedByUsPubkey), isTrue);
      },
    );
  });

  group('ContentBlocklistRepository - Own Mute List Sync', () {
    const ourPubkey =
        '0000000000000000000000000000000000000000000000000000000000000001';
    const mutedPubkey =
        '0000000000000000000000000000000000000000000000000000000000000002';
    const otherMutedPubkey =
        '0000000000000000000000000000000000000000000000000000000000000003';

    late ContentBlocklistRepository service;
    late _MockNostrClient mockNostrService;
    late StreamController<Event> controller;

    Event ownMuteListEvent({
      required List<String> mutedPubkeys,
      required int createdAt,
      String id = 'own-mute-event-id',
    }) =>
        Event(
            ourPubkey,
            10000,
            [
              for (final pubkey in mutedPubkeys) ['p', pubkey],
            ],
            '',
            createdAt: createdAt,
          )
          ..id = id
          ..sig = 'signature';

    setUp(() {
      service = ContentBlocklistRepository();
      mockNostrService = _MockNostrClient();
      controller = StreamController<Event>();
      when(
        () => mockNostrService.subscribe(any()),
      ).thenAnswer((_) => controller.stream);
    });

    tearDown(() async {
      await controller.close();
    });

    test('own kind 10000 event populates muted authors', () async {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      await service.syncMuteListsInBackground(mockNostrService, ourPubkey);
      controller.add(
        ownMuteListEvent(
          mutedPubkeys: [mutedPubkey, otherMutedPubkey],
          createdAt: now,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(service.isMutedByUs(mutedPubkey), isTrue);
      expect(service.isMutedByUs(otherMutedPubkey), isTrue);
      expect(service.shouldFilterFromFeeds(mutedPubkey), isTrue);
      expect(
        service.currentState.mutedPubkeys,
        containsAll(<String>{mutedPubkey, otherMutedPubkey}),
      );
      // Mutes are not blocks — the block-specific queries stay false.
      expect(service.isBlocked(mutedPubkey), isFalse);
      expect(service.hasMutedUs(mutedPubkey), isFalse);
    });

    test('own kind 10000 echo does not double-count our own blocks as '
        'mutes', () async {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      await service.syncMuteListsInBackground(mockNostrService, ourPubkey);
      // We blocked mutedPubkey in-app (no signer wired, so publishing is a
      // no-op here), then our own kind 10000 echoes back containing both
      // that block and a mute authored from another client.
      await service.blockUser(mutedPubkey, ourPubkey: ourPubkey);
      controller.add(
        ownMuteListEvent(
          mutedPubkeys: [mutedPubkey, otherMutedPubkey],
          createdAt: now,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Our own block stays tracked as a block, not duplicated into the
      // mute set — otherwise unblocking could never drop it from the
      // republished kind 10000 list.
      expect(service.isBlocked(mutedPubkey), isTrue);
      expect(service.isMutedByUs(mutedPubkey), isFalse);
      // The external mute is still recorded.
      expect(service.isMutedByUs(otherMutedPubkey), isTrue);
      // Both are filtered from feeds regardless.
      expect(service.shouldFilterFromFeeds(mutedPubkey), isTrue);
      expect(service.shouldFilterFromFeeds(otherMutedPubkey), isTrue);
    });

    test('newer own event replaces the muted set (unmute)', () async {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      await service.syncMuteListsInBackground(mockNostrService, ourPubkey);
      controller.add(
        ownMuteListEvent(
          mutedPubkeys: [mutedPubkey, otherMutedPubkey],
          createdAt: now,
          id: 'own-mute-event-id-1',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      controller.add(
        ownMuteListEvent(
          mutedPubkeys: [otherMutedPubkey],
          createdAt: now + 60,
          id: 'own-mute-event-id-2',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(service.isMutedByUs(mutedPubkey), isFalse);
      expect(service.shouldFilterFromFeeds(mutedPubkey), isFalse);
      expect(service.isMutedByUs(otherMutedPubkey), isTrue);
    });

    test('ignores stale older own mute event', () async {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      await service.syncMuteListsInBackground(mockNostrService, ourPubkey);
      controller.add(
        ownMuteListEvent(
          mutedPubkeys: [],
          createdAt: now + 60,
          id: 'own-mute-event-id-newer',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      controller.add(
        ownMuteListEvent(
          mutedPubkeys: [mutedPubkey],
          createdAt: now,
          id: 'own-mute-event-id-older',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(service.isMutedByUs(mutedPubkey), isFalse);
      expect(service.shouldFilterFromFeeds(mutedPubkey), isFalse);
    });

    test('excludes our own pubkey from a self-referential mute list', () async {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      await service.syncMuteListsInBackground(mockNostrService, ourPubkey);
      controller.add(
        ownMuteListEvent(
          mutedPubkeys: [ourPubkey, mutedPubkey],
          createdAt: now,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // A malformed self-referential list must never filter our own
      // content (#2192).
      expect(service.isMutedByUs(ourPubkey), isFalse);
      expect(service.shouldFilterFromFeeds(ourPubkey), isFalse);
      expect(service.isMutedByUs(mutedPubkey), isTrue);
    });

    test('own mute event does not touch the mutual-mute set', () async {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      await service.syncMuteListsInBackground(mockNostrService, ourPubkey);
      // Our own list naming our own pubkey-of-interest must route to the
      // own-mute handler, not register as "they muted us".
      controller.add(
        ownMuteListEvent(mutedPubkeys: [mutedPubkey], createdAt: now),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(service.hasMutedUs(ourPubkey), isFalse);
      expect(service.hasMutedUs(mutedPubkey), isFalse);
      expect(service.isMutedByUs(mutedPubkey), isTrue);
    });

    test('emits mutedByUs and unmutedByUs on the changes stream', () async {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final changes = <BlocklistChange>[];
      final subscription = service.changes.listen(changes.add);

      await service.syncMuteListsInBackground(mockNostrService, ourPubkey);
      controller.add(
        ownMuteListEvent(
          mutedPubkeys: [mutedPubkey],
          createdAt: now,
          id: 'own-mute-event-id-1',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      controller.add(
        ownMuteListEvent(
          mutedPubkeys: [],
          createdAt: now + 60,
          id: 'own-mute-event-id-2',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(
        changes,
        containsAllInOrder([
          const BlocklistChange(
            pubkey: mutedPubkey,
            op: BlocklistOp.mutedByUs,
          ),
          const BlocklistChange(
            pubkey: mutedPubkey,
            op: BlocklistOp.unmutedByUs,
          ),
        ]),
      );
      expect(
        changes.firstWhere((c) => c.op == BlocklistOp.mutedByUs).isAddition,
        isTrue,
      );
      expect(
        changes.firstWhere((c) => c.op == BlocklistOp.unmutedByUs).isAddition,
        isFalse,
      );

      await subscription.cancel();
    });

    test('continues when persisting muted authors throws', () async {
      final mockPrefs = _MockSharedPreferences();
      when(() => mockPrefs.getString(any())).thenReturn(null);
      when(
        () => mockPrefs.setString(any(), any()),
      ).thenThrow(Exception('disk full'));

      final failingService = ContentBlocklistRepository(prefs: mockPrefs);
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      await failingService.syncMuteListsInBackground(
        mockNostrService,
        ourPubkey,
      );
      controller.add(
        ownMuteListEvent(mutedPubkeys: [mutedPubkey], createdAt: now),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // The in-memory set still updates even though the write failed.
      expect(failingService.isMutedByUs(mutedPubkey), isTrue);

      failingService.dispose();
    });

    test('persists muted authors and rehydrates at construction', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final persistedService = ContentBlocklistRepository(prefs: prefs);
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      await persistedService.syncMuteListsInBackground(
        mockNostrService,
        ourPubkey,
      );
      controller.add(
        ownMuteListEvent(mutedPubkeys: [mutedPubkey], createdAt: now),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(persistedService.isMutedByUs(mutedPubkey), isTrue);

      // A fresh instance over the same prefs hydrates the muted set
      // before any relay event arrives.
      final rehydrated = ContentBlocklistRepository(prefs: prefs);
      expect(rehydrated.isMutedByUs(mutedPubkey), isTrue);
      expect(rehydrated.shouldFilterFromFeeds(mutedPubkey), isTrue);
      expect(rehydrated.currentState.mutedPubkeys, contains(mutedPubkey));

      persistedService.dispose();
      rehydrated.dispose();
    });
  });

  group('ContentBlocklistRepository - identity change (#4969)', () {
    const accountA =
        '00000000000000000000000000000000000000000000000000000000000000aa';
    const accountB =
        '00000000000000000000000000000000000000000000000000000000000000bb';
    const blockerX =
        '0000000000000000000000000000000000000000000000000000000000000011';
    const someoneElse =
        '0000000000000000000000000000000000000000000000000000000000000022';

    late _MockNostrClient mockNostrService;
    late StreamController<Event> controller;

    Event blockListEvent({
      required String author,
      required List<String> blockedPubkeys,
      required int createdAt,
      String id = 'block-event-id',
    }) =>
        Event(
            author,
            30000,
            [
              ['d', 'block'],
              for (final pubkey in blockedPubkeys) ['p', pubkey],
            ],
            '',
            createdAt: createdAt,
          )
          ..id = id
          ..sig = 'signature';

    setUp(() {
      mockNostrService = _MockNostrClient();
      controller = StreamController<Event>.broadcast();
      when(
        () => mockNostrService.subscribe(any()),
      ).thenAnswer((_) => controller.stream);
    });

    tearDown(() async {
      await controller.close();
    });

    test(
      'switching accounts clears relay-synced blocked-by and mute state',
      () async {
        final service = ContentBlocklistRepository();
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

        await service.syncBlockListsInBackground(
          mockNostrService,
          _MockBlockListSigner(),
          accountA,
        );
        controller.add(
          blockListEvent(
            author: blockerX,
            blockedPubkeys: [accountA],
            createdAt: now,
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(service.hasBlockedUs(blockerX), isTrue);

        // Switch to account B: X never blocked B, so the gate must clear.
        await service.syncBlockListsInBackground(
          mockNostrService,
          _MockBlockListSigner(),
          accountB,
        );
        expect(service.hasBlockedUs(blockerX), isFalse);
        expect(service.shouldFilterFromFeeds(blockerX), isFalse);
        expect(service.hasMutedUs(blockerX), isFalse);
        expect(service.currentState.pubkeysBlockingUs, isEmpty);
        expect(service.currentState.mutedPubkeys, isEmpty);

        service.dispose();
      },
    );

    test('switching accounts re-subscribes with the new pubkey', () async {
      final captured = <List<dynamic>>[];
      when(() => mockNostrService.subscribe(any())).thenAnswer((invocation) {
        captured.add(invocation.positionalArguments[0] as List);
        return controller.stream;
      });

      final service = ContentBlocklistRepository();
      await service.syncMuteListsInBackground(mockNostrService, accountA);
      await service.syncMuteListsInBackground(mockNostrService, accountB);

      expect(captured, hasLength(2));
      final secondMutual = captured[1][0] as Filter;
      expect(secondMutual.p, contains(accountB));
      final secondOwn = captured[1][1] as Filter;
      expect(secondOwn.authors, contains(accountB));

      service.dispose();
    });

    test('per-account blocks do not leak across a switch and survive '
        'switching back', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final service = ContentBlocklistRepository(prefs: prefs);

      await service.syncMuteListsInBackground(mockNostrService, accountA);
      await service.blockUser(blockerX);
      expect(service.isBlocked(blockerX), isTrue);

      await service.syncMuteListsInBackground(mockNostrService, accountB);
      expect(
        service.isBlocked(blockerX),
        isFalse,
        reason: "account A's blocks must not apply to account B",
      );
      await service.blockUser(someoneElse);

      await service.syncMuteListsInBackground(mockNostrService, accountA);
      expect(service.isBlocked(blockerX), isTrue);
      expect(service.isBlocked(someoneElse), isFalse);

      service.dispose();
    });

    test(
      'switching accounts reloads the incoming account pending unblocks',
      () async {
        SharedPreferences.setMockInitialValues({
          'blocklist_active_pubkey': accountA,
          'pending_unblocks.$accountB': jsonEncode({someoneElse: 2000}),
        });
        final prefs = await SharedPreferences.getInstance();
        final service = ContentBlocklistRepository(prefs: prefs);

        await service.syncMuteListsInBackground(mockNostrService, accountA);
        await service.syncMuteListsInBackground(mockNostrService, accountB);
        controller.add(
          Event(
              accountB,
              10000,
              const [
                ['p', someoneElse],
              ],
              '',
              createdAt: 1000,
            )
            ..id = 'stale-account-b-mute-list'
            ..sig = 'signature',
        );
        await Future<void>.delayed(Duration.zero);

        expect(service.isMutedByUs(someoneElse), isFalse);

        service.dispose();
      },
    );

    test(
      'first identity prefers an existing scoped pending-unblock map',
      () async {
        SharedPreferences.setMockInitialValues({
          'pending_unblocks': jsonEncode({blockerX: 2000}),
          'pending_unblocks.$accountA': jsonEncode({someoneElse: 2000}),
        });
        final prefs = await SharedPreferences.getInstance();
        final service = ContentBlocklistRepository(prefs: prefs);

        await service.syncMuteListsInBackground(mockNostrService, accountA);
        await pumpEventQueue();

        expect(prefs.getString('pending_unblocks'), isNull);
        controller.add(
          Event(
              accountA,
              10000,
              const [
                ['p', blockerX],
              ],
              '',
              createdAt: 1000,
            )
            ..id = 'mute-list-after-partial-migration'
            ..sig = 'signature',
        );
        await Future<void>.delayed(Duration.zero);
        expect(service.isMutedByUs(blockerX), isTrue);

        service.dispose();
      },
    );

    test(
      'first identity makes an existing scoped pending unblock retryable',
      () async {
        SharedPreferences.setMockInitialValues({
          'pending_unblocks': jsonEncode(<String, int>{}),
          'pending_unblocks.$accountA': jsonEncode({someoneElse: 2000}),
          'block_list_migrated_to_mute_list.$accountA': true,
          'block_list_retired.$accountA': true,
        });
        final prefs = await SharedPreferences.getInstance();
        final signer = _MockBlockListSigner();
        when(() => signer.isAuthenticated).thenReturn(true);
        when(
          () => mockNostrService.queryEventsDetailed(
            any(),
            requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
          ),
        ).thenAnswer(
          (_) async => (
            events: <Event>[],
            timedOut: false,
            noRelays: false,
          ),
        );
        when(
          () => signer.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer(
          (invocation) async =>
              Event(
                  accountA,
                  invocation.namedArguments[#kind] as int,
                  invocation.namedArguments[#tags] as List<List<String>>,
                  invocation.namedArguments[#content] as String,
                  createdAt: 3000,
                )
                ..id = 'retried-scoped-pending-unblock'
                ..sig = 'signature',
        );
        when(() => mockNostrService.publishEvent(any())).thenAnswer(
          (invocation) async => PublishSuccess(
            event: invocation.positionalArguments.first as Event,
          ),
        );
        final service = ContentBlocklistRepository(prefs: prefs);

        await service.syncBlockListsInBackground(
          mockNostrService,
          signer,
          accountA,
        );
        await pumpEventQueue();

        expect(await service.retryPendingMuteListPublish(), isTrue);

        service.dispose();
      },
    );

    test('recorded identity recovers a legacy pending-unblock map', () async {
      SharedPreferences.setMockInitialValues({
        'blocklist_active_pubkey': accountA,
        'pending_unblocks': jsonEncode({blockerX: 2000}),
      });
      final prefs = await SharedPreferences.getInstance();
      final service = ContentBlocklistRepository(prefs: prefs);
      final signer = _MockBlockListSigner();
      when(() => signer.isAuthenticated).thenReturn(true);
      when(
        () => mockNostrService.queryEvents(any()),
      ).thenAnswer((_) async => []);
      when(
        () => signer.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer(
        (invocation) async =>
            Event(
                accountA,
                invocation.namedArguments[#kind] as int,
                invocation.namedArguments[#tags] as List<List<String>>,
                invocation.namedArguments[#content] as String,
                createdAt: 3000,
              )
              ..id = 'recovered-pending-unblock'
              ..sig = 'signature',
      );
      when(() => mockNostrService.publishEvent(any())).thenAnswer(
        (invocation) async => PublishSuccess(
          event: invocation.positionalArguments.first as Event,
        ),
      );

      await service.syncBlockListsInBackground(
        mockNostrService,
        signer,
        accountA,
      );
      await pumpEventQueue();

      expect(prefs.getString('pending_unblocks'), isNull);
      expect(
        jsonDecode(prefs.getString('pending_unblocks.$accountA')!),
        containsPair(blockerX, 2000),
      );
      expect(await service.retryPendingMuteListPublish(), isTrue);

      service.dispose();
    });

    test('recorded identity drops stale pending-unblock legacy data', () async {
      SharedPreferences.setMockInitialValues({
        'blocklist_active_pubkey': accountA,
        'pending_unblocks': jsonEncode({blockerX: 1000}),
        'pending_unblocks.$accountA': jsonEncode({someoneElse: 2000}),
      });
      final prefs = await SharedPreferences.getInstance();
      final service = ContentBlocklistRepository(prefs: prefs);

      await service.syncMuteListsInBackground(mockNostrService, accountA);
      await pumpEventQueue();

      expect(prefs.getString('pending_unblocks'), isNull);
      expect(
        jsonDecode(prefs.getString('pending_unblocks.$accountA')!),
        equals({someoneElse: 2000}),
      );

      service.dispose();
    });

    test(
      'recorded identity recovers when scoped pending unblocks are corrupt',
      () async {
        SharedPreferences.setMockInitialValues({
          'blocklist_active_pubkey': accountA,
          'pending_unblocks': jsonEncode({blockerX: 2000}),
          'pending_unblocks.$accountA': 'not-json',
        });
        final prefs = await SharedPreferences.getInstance();
        final service = ContentBlocklistRepository(prefs: prefs);

        await service.syncMuteListsInBackground(mockNostrService, accountA);
        await pumpEventQueue();

        expect(prefs.getString('pending_unblocks'), isNull);
        expect(
          jsonDecode(prefs.getString('pending_unblocks.$accountA')!),
          equals({blockerX: 2000}),
        );

        service.dispose();
      },
    );

    test('first identity adopts legacy un-namespaced persisted data', () async {
      SharedPreferences.setMockInitialValues({
        'blocked_users_list': jsonEncode([blockerX]),
      });
      final prefs = await SharedPreferences.getInstance();
      final service = ContentBlocklistRepository(prefs: prefs);

      // Legacy data hydrates before any identity is known.
      expect(service.isBlocked(blockerX), isTrue);

      await service.syncMuteListsInBackground(mockNostrService, accountA);
      expect(service.isBlocked(blockerX), isTrue);

      // A fresh instance over the same prefs loads the migrated,
      // account-scoped data.
      final rehydrated = ContentBlocklistRepository(prefs: prefs);
      expect(rehydrated.isBlocked(blockerX), isTrue);
      expect(prefs.getString('blocked_users_list'), isNull);

      service.dispose();
      rehydrated.dispose();
    });

    test('continues when legacy key migration throws', () async {
      final mockPrefs = _MockSharedPreferences();
      when(() => mockPrefs.getString(any())).thenReturn(null);
      when(
        () => mockPrefs.getString('blocked_users_list'),
      ).thenReturn(jsonEncode([blockerX]));
      when(
        () => mockPrefs.setString(any(), any()),
      ).thenThrow(Exception('disk full'));

      final service = ContentBlocklistRepository(prefs: mockPrefs);
      expect(service.isBlocked(blockerX), isTrue);

      // Adoption triggers migration; the failed move must not throw and
      // the in-memory state must survive.
      await service.syncMuteListsInBackground(mockNostrService, accountA);
      expect(service.isBlocked(blockerX), isTrue);

      service.dispose();
    });

    test('survives corrupt pending-unblock storage', () async {
      final mockPrefs = _MockSharedPreferences();
      when(() => mockPrefs.getString(any())).thenReturn(null);
      when(
        () => mockPrefs.getString('pending_unblocks'),
      ).thenReturn('{not json');

      // Construction hydrates; a corrupt blob must not take the repository
      // down with it.
      final service = ContentBlocklistRepository(prefs: mockPrefs);
      expect(service.totalBlockedCount, equals(0));

      await service.syncMuteListsInBackground(mockNostrService, accountA);
      await pumpEventQueue();

      service.dispose();
    });

    test('continues when persisting a pending unblock throws', () async {
      final mockPrefs = _MockSharedPreferences();
      when(() => mockPrefs.getString(any())).thenReturn(null);
      when(
        () => mockPrefs.getString('blocked_users_list'),
      ).thenReturn(jsonEncode([blockerX]));
      when(
        () => mockPrefs.setString(any(), any()),
      ).thenThrow(Exception('disk full'));

      final service = ContentBlocklistRepository(prefs: mockPrefs);
      expect(service.isBlocked(blockerX), isTrue);

      // The unblock records an intent, whose persist fails. The in-memory
      // unblock must still take effect.
      await service.unblockUser(blockerX);
      expect(service.isBlocked(blockerX), isFalse);

      service.dispose();
    });

    test('keeps the legacy key when the scoped copy reports failure', () async {
      final mockPrefs = _MockSharedPreferences();
      when(() => mockPrefs.getString(any())).thenReturn(null);
      when(
        () => mockPrefs.getString('blocked_users_list'),
      ).thenReturn(jsonEncode([blockerX]));
      when(
        () => mockPrefs.setString(any(), any()),
      ).thenAnswer((_) async => false);
      when(() => mockPrefs.remove(any())).thenAnswer((_) async => true);

      final service = ContentBlocklistRepository(prefs: mockPrefs);
      await service.syncMuteListsInBackground(mockNostrService, accountA);
      await Future<void>.delayed(Duration.zero);

      // The scoped copy never landed, so the legacy data must survive
      // for the next attempt.
      verifyNever(() => mockPrefs.remove('blocked_users_list'));
      expect(service.isBlocked(blockerX), isTrue);

      service.dispose();
    });

    test(
      'keeps legacy pending unblocks when the scoped copy reports failure',
      () async {
        final mockPrefs = _MockSharedPreferences();
        when(() => mockPrefs.getString(any())).thenReturn(null);
        when(
          () => mockPrefs.getString('blocklist_active_pubkey'),
        ).thenReturn(accountA);
        when(
          () => mockPrefs.getString('pending_unblocks'),
        ).thenReturn(jsonEncode({blockerX: 2000}));
        when(
          () => mockPrefs.setString(any(), any()),
        ).thenAnswer((_) async => true);
        when(
          () => mockPrefs.setString('pending_unblocks.$accountA', any()),
        ).thenAnswer((_) async => false);
        when(() => mockPrefs.remove(any())).thenAnswer((_) async => true);

        final service = ContentBlocklistRepository(prefs: mockPrefs);
        await service.syncMuteListsInBackground(mockNostrService, accountA);
        await pumpEventQueue();

        verifyNever(() => mockPrefs.remove('pending_unblocks'));

        service.dispose();
      },
    );

    test('survives an asynchronous setString failure during '
        'migration', () async {
      final mockPrefs = _MockSharedPreferences();
      when(() => mockPrefs.getString(any())).thenReturn(null);
      when(
        () => mockPrefs.getString('blocked_users_list'),
      ).thenReturn(jsonEncode([blockerX]));
      when(
        () => mockPrefs.setString(any(), any()),
      ).thenAnswer((_) => Future.error(Exception('platform write failed')));
      when(() => mockPrefs.remove(any())).thenAnswer((_) async => true);

      final service = ContentBlocklistRepository(prefs: mockPrefs);
      await service.syncMuteListsInBackground(mockNostrService, accountA);
      // Flush the unawaited migration; a rejection it failed to catch
      // would surface as an unhandled error and fail this test.
      await Future<void>.delayed(Duration.zero);

      verifyNever(() => mockPrefs.remove('blocked_users_list'));
      expect(service.isBlocked(blockerX), isTrue);

      service.dispose();
    });

    test('retries a failed legacy migration on the next launch and '
        'recovers the data in-session', () async {
      // An earlier launch recorded the active account but its legacy
      // move failed: the data still sits at the un-namespaced keys.
      SharedPreferences.setMockInitialValues({
        'blocklist_active_pubkey': accountA,
        'blocked_users_list': jsonEncode([blockerX]),
        'severed_followers_list': jsonEncode([someoneElse]),
      });
      final prefs = await SharedPreferences.getInstance();
      var changeCount = 0;
      final service = ContentBlocklistRepository(
        prefs: prefs,
        onChanged: () => changeCount++,
      );

      // Hydration reads the (empty) scoped keys, so the data starts
      // invisible.
      expect(service.isBlocked(blockerX), isFalse);
      expect(service.isFollowSevered(someoneElse), isFalse);
      final changesBefore = changeCount;

      await service.syncMuteListsInBackground(mockNostrService, accountA);
      await Future<void>.delayed(Duration.zero);

      expect(prefs.getString('blocked_users_list'), isNull);
      expect(
        prefs.getString('blocked_users_list.$accountA'),
        equals(jsonEncode([blockerX])),
      );
      expect(prefs.getString('severed_followers_list'), isNull);
      expect(
        prefs.getString('severed_followers_list.$accountA'),
        equals(jsonEncode([someoneElse])),
      );
      expect(service.isBlocked(blockerX), isTrue);
      expect(service.isFollowSevered(someoneElse), isTrue);
      expect(
        changeCount,
        greaterThan(changesBefore),
        reason: 'watchers must re-filter with the recovered data',
      );

      service.dispose();
    });

    test('merges legacy data with a scoped value written by a save '
        'that raced the migration', () async {
      // The recorded account's scoped key was absent at construction,
      // so a value appearing there mid-session comes from this
      // session's own saves — those entries and the legacy entries
      // must both survive.
      SharedPreferences.setMockInitialValues({
        'blocklist_active_pubkey': accountA,
        'blocked_users_list': jsonEncode([blockerX]),
      });
      final prefs = await SharedPreferences.getInstance();
      final service = ContentBlocklistRepository(prefs: prefs);

      // A user action lands before the session identity resolves.
      await service.blockUser(someoneElse);
      expect(prefs.getString('blocked_users_list.$accountA'), isNotNull);

      await service.syncMuteListsInBackground(mockNostrService, accountA);
      await Future<void>.delayed(Duration.zero);

      expect(prefs.getString('blocked_users_list'), isNull);
      final scoped =
          (jsonDecode(prefs.getString('blocked_users_list.$accountA')!)
                  as List<dynamic>)
              .cast<String>();
      expect(scoped, containsAll([blockerX, someoneElse]));
      expect(service.isBlocked(blockerX), isTrue);
      expect(service.isBlocked(someoneElse), isTrue);

      service.dispose();
    });

    test('keeps the newest pending-unblock timestamp when a save races '
        'migration', () async {
      SharedPreferences.setMockInitialValues({
        'blocklist_active_pubkey': accountA,
        'blocked_users_list.$accountA': jsonEncode([blockerX]),
        'pending_unblocks': jsonEncode({blockerX: 1}),
      });
      final prefs = await SharedPreferences.getInstance();
      final service = ContentBlocklistRepository(prefs: prefs);

      await service.unblockUser(blockerX);
      final savedBeforeMigration =
          (jsonDecode(prefs.getString('pending_unblocks.$accountA')!)
                  as Map<String, dynamic>)[blockerX]
              as int;
      await service.syncMuteListsInBackground(mockNostrService, accountA);
      await pumpEventQueue();

      final migrated =
          (jsonDecode(prefs.getString('pending_unblocks.$accountA')!)
                  as Map<String, dynamic>)[blockerX]
              as int;
      expect(migrated, savedBeforeMigration);

      service.dispose();
    });

    test('prefers a pre-adoption scoped value over the legacy snapshot '
        'when no account was recorded', () async {
      // A previous launch copied the legacy data but failed to remove
      // it and to record the account: the scoped value may hold newer
      // writes, so it wins and the stale legacy key is dropped.
      SharedPreferences.setMockInitialValues({
        'blocked_users_list': jsonEncode([blockerX]),
        'blocked_users_list.$accountA': jsonEncode([blockerX, someoneElse]),
      });
      final prefs = await SharedPreferences.getInstance();
      final service = ContentBlocklistRepository(prefs: prefs);

      await service.syncMuteListsInBackground(mockNostrService, accountA);
      await Future<void>.delayed(Duration.zero);

      expect(prefs.getString('blocked_users_list'), isNull);
      expect(
        prefs.getString('blocked_users_list.$accountA'),
        equals(jsonEncode([blockerX, someoneElse])),
      );

      service.dispose();
    });

    test('skips a corrupt legacy value without dropping it', () async {
      SharedPreferences.setMockInitialValues({
        'blocked_users_list': 'not-json',
      });
      final prefs = await SharedPreferences.getInstance();
      final service = ContentBlocklistRepository(prefs: prefs);

      await service.syncMuteListsInBackground(mockNostrService, accountA);
      await Future<void>.delayed(Duration.zero);

      expect(prefs.getString('blocked_users_list'), equals('not-json'));
      expect(prefs.getString('blocked_users_list.$accountA'), isNull);

      service.dispose();
    });

    test('tolerates a failed stale legacy cleanup', () async {
      final mockPrefs = _MockSharedPreferences();
      when(() => mockPrefs.getString(any())).thenReturn(null);
      when(
        () => mockPrefs.getString('blocklist_active_pubkey'),
      ).thenReturn(accountA);
      when(
        () => mockPrefs.getString('blocked_users_list'),
      ).thenReturn(jsonEncode([blockerX]));
      when(
        () => mockPrefs.getString('blocked_users_list.$accountA'),
      ).thenReturn(jsonEncode([someoneElse]));
      when(
        () => mockPrefs.setString(any(), any()),
      ).thenAnswer((_) async => true);
      when(() => mockPrefs.remove(any())).thenThrow(Exception('disk error'));

      final service = ContentBlocklistRepository(prefs: mockPrefs);
      await service.syncMuteListsInBackground(mockNostrService, accountA);
      await Future<void>.delayed(Duration.zero);

      // The cleanup failure is swallowed and the hydrated state stays
      // usable; the stale key is retried on the next launch.
      verify(() => mockPrefs.remove('blocked_users_list')).called(1);
      expect(service.isBlocked(someoneElse), isTrue);

      service.dispose();
    });

    test('stops migrating remaining keys when the account switches '
        'mid-flight', () async {
      final mockPrefs = _MockSharedPreferences();
      final firstWrite = Completer<bool>();
      when(() => mockPrefs.getString(any())).thenReturn(null);
      when(
        () => mockPrefs.getString('blocklist_active_pubkey'),
      ).thenReturn(accountA);
      when(
        () => mockPrefs.getString('blocked_users_list'),
      ).thenReturn(jsonEncode([blockerX]));
      when(
        () => mockPrefs.getString('severed_followers_list'),
      ).thenReturn(jsonEncode([someoneElse]));
      when(
        () => mockPrefs.setString(any(), any()),
      ).thenAnswer((_) async => true);
      when(
        () => mockPrefs.setString('blocked_users_list.$accountA', any()),
      ).thenAnswer((_) => firstWrite.future);
      when(() => mockPrefs.remove(any())).thenAnswer((_) async => true);

      final service = ContentBlocklistRepository(prefs: mockPrefs);
      await service.syncMuteListsInBackground(mockNostrService, accountA);
      // The first key's platform write is in flight when the session
      // switches identity.
      await service.syncMuteListsInBackground(mockNostrService, accountB);
      firstWrite.complete(true);
      await Future<void>.delayed(Duration.zero);

      // The in-flight write already serialized account A's set, so its
      // move completes — but the remaining legacy key must not be
      // serialized under the new identity.
      verify(() => mockPrefs.remove('blocked_users_list')).called(1);
      verifyNever(
        () => mockPrefs.setString('severed_followers_list.$accountA', any()),
      );
      verifyNever(() => mockPrefs.remove('severed_followers_list'));

      service.dispose();
    });

    test('does not clobber newer scoped data when retrying the legacy '
        'move', () async {
      // An earlier copy landed but its remove failed, and the scoped
      // set has been written since: the legacy snapshot is stale.
      SharedPreferences.setMockInitialValues({
        'blocklist_active_pubkey': accountA,
        'blocked_users_list': jsonEncode([blockerX]),
        'blocked_users_list.$accountA': jsonEncode([someoneElse]),
      });
      final prefs = await SharedPreferences.getInstance();
      final service = ContentBlocklistRepository(prefs: prefs);

      await service.syncMuteListsInBackground(mockNostrService, accountA);
      await Future<void>.delayed(Duration.zero);

      expect(prefs.getString('blocked_users_list'), isNull);
      expect(
        prefs.getString('blocked_users_list.$accountA'),
        equals(jsonEncode([someoneElse])),
      );
      expect(service.isBlocked(someoneElse), isTrue);
      expect(service.isBlocked(blockerX), isFalse);

      service.dispose();
    });

    test('leaves legacy data untouched when a different account than '
        'its owner signs in', () async {
      SharedPreferences.setMockInitialValues({
        'blocklist_active_pubkey': accountA,
        'blocked_users_list': jsonEncode([blockerX]),
      });
      final prefs = await SharedPreferences.getInstance();
      final service = ContentBlocklistRepository(prefs: prefs);

      await service.syncMuteListsInBackground(mockNostrService, accountB);
      await Future<void>.delayed(Duration.zero);

      expect(
        prefs.getString('blocked_users_list'),
        equals(jsonEncode([blockerX])),
      );
      expect(prefs.getString('blocked_users_list.$accountB'), isNull);
      expect(service.isBlocked(blockerX), isFalse);

      service.dispose();
    });

    test('adopting a different identity than the stored account resets '
        'hydrated state', () async {
      SharedPreferences.setMockInitialValues({
        'blocklist_active_pubkey': accountA,
        'blocked_users_list.$accountA': jsonEncode([blockerX]),
      });
      final prefs = await SharedPreferences.getInstance();
      final service = ContentBlocklistRepository(prefs: prefs);

      // Construction hydrates account A's persisted blocks.
      expect(service.isBlocked(blockerX), isTrue);

      // The session resolves to account B: A's blocks must not apply.
      await service.syncMuteListsInBackground(mockNostrService, accountB);
      expect(service.isBlocked(blockerX), isFalse);

      service.dispose();
    });

    test('notifies listeners when a switch resets state', () async {
      var changeCount = 0;
      final service = ContentBlocklistRepository(
        onChanged: () => changeCount++,
      );

      await service.syncMuteListsInBackground(mockNostrService, accountA);
      final before = changeCount;

      await service.syncMuteListsInBackground(mockNostrService, accountB);
      expect(
        changeCount,
        greaterThan(before),
        reason: 'watchers must re-filter after an account switch',
      );

      service.dispose();
    });
  });

  group('ContentBlocklistRepository - Block List Sync', () {
    late ContentBlocklistRepository service;
    late _MockNostrClient mockNostrService;
    late _MockBlockListSigner mockSigner;

    setUp(() {
      mockNostrService = _MockNostrClient();
      mockSigner = _MockBlockListSigner();
    });

    test(
      'syncBlockListsInBackground subscribes only to others block lists',
      () async {
        const ourPubkey = 'test_our_pubkey_hex';
        service = ContentBlocklistRepository();

        List<dynamic>? capturedFilters;
        when(
          () => mockNostrService.subscribe(
            any(),
          ),
        ).thenAnswer((invocation) {
          capturedFilters = invocation.positionalArguments[0] as List;
          return const Stream.empty();
        });

        await service.syncBlockListsInBackground(
          mockNostrService,
          mockSigner,
          ourPubkey,
        );

        verify(
          () => mockNostrService.subscribe(
            any(),
          ),
        ).called(1);

        expect(capturedFilters, isNotNull);
        // Only others' block lists containing our pubkey. Our own legacy
        // list stopped being a source of truth for our blocks (#5462).
        expect(capturedFilters!.length, equals(1));

        final othersFilter = capturedFilters![0] as Filter;
        expect(othersFilter.kinds, contains(30000));
        expect(othersFilter.p, contains(ourPubkey));
        expect(othersFilter.authors, isNull);
      },
    );

    test(
      'handleBlockListEvent adds blocker when our pubkey is in block list',
      () async {
        const ourPubkey =
            '0000000000000000000000000000000000000000000000000000000000000001';
        const blockerPubkey =
            '0000000000000000000000000000000000000000000000000000000000000002';

        var changeCount = 0;
        service = ContentBlocklistRepository(onChanged: () => changeCount++);

        final event =
            Event(
                blockerPubkey,
                30000,
                [
                  ['d', 'block'],
                  ['p', ourPubkey],
                ],
                'Block list',
                createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
              )
              ..id = 'block-event-id'
              ..sig = 'signature';

        when(
          () => mockNostrService.subscribe(
            any(),
          ),
        ).thenAnswer((_) => Stream.fromIterable([event]));

        await service.syncBlockListsInBackground(
          mockNostrService,
          mockSigner,
          ourPubkey,
        );

        await Future<void>.delayed(const Duration(milliseconds: 100));

        expect(service.hasBlockedUs(blockerPubkey), isTrue);
        expect(service.shouldFilterFromFeeds(blockerPubkey), isTrue);
        expect(changeCount, equals(1));
      },
    );

    test(
      'handleBlockListEvent removes blocker when updated event no longer '
      'contains our pubkey',
      () async {
        const ourPubkey =
            '0000000000000000000000000000000000000000000000000000000000000001';
        const blockerPubkey =
            '0000000000000000000000000000000000000000000000000000000000000002';

        var changeCount = 0;
        service = ContentBlocklistRepository(onChanged: () => changeCount++);

        final blockEvent =
            Event(
                blockerPubkey,
                30000,
                [
                  ['d', 'block'],
                  ['p', ourPubkey],
                ],
                'Block list',
                createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
              )
              ..id = 'block-event-id'
              ..sig = 'signature';

        final unblockEvent =
            Event(
                blockerPubkey,
                30000,
                [
                  ['d', 'block'],
                  ['p', 'some_other_pubkey'],
                ],
                'Block list',
                createdAt: (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 60,
              )
              ..id = 'unblock-event-id'
              ..sig = 'signature';

        final controller = StreamController<Event>();

        when(
          () => mockNostrService.subscribe(
            any(),
          ),
        ).thenAnswer((_) => controller.stream);

        await service.syncBlockListsInBackground(
          mockNostrService,
          mockSigner,
          ourPubkey,
        );

        controller.add(blockEvent);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(service.hasBlockedUs(blockerPubkey), isTrue);

        controller.add(unblockEvent);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(service.hasBlockedUs(blockerPubkey), isFalse);
        expect(changeCount, equals(2));

        await controller.close();
      },
    );

    test(
      'ignores stale older block event after newer unblock event',
      () async {
        const ourPubkey =
            '0000000000000000000000000000000000000000000000000000000000000001';
        const blockerPubkey =
            '0000000000000000000000000000000000000000000000000000000000000002';

        service = ContentBlocklistRepository();

        final newerUnblockEvent =
            Event(
                blockerPubkey,
                30000,
                [
                  ['d', 'block'],
                  ['p', 'some_other_pubkey'],
                ],
                'Block list',
                createdAt: (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 60,
              )
              ..id = 'newer-unblock-event-id'
              ..sig = 'signature';

        final olderBlockEvent =
            Event(
                blockerPubkey,
                30000,
                [
                  ['d', 'block'],
                  ['p', ourPubkey],
                ],
                'Block list',
                createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
              )
              ..id = 'older-block-event-id'
              ..sig = 'signature';

        final controller = StreamController<Event>();

        when(
          () => mockNostrService.subscribe(
            any(),
          ),
        ).thenAnswer((_) => controller.stream);

        await service.syncBlockListsInBackground(
          mockNostrService,
          mockSigner,
          ourPubkey,
        );

        controller.add(newerUnblockEvent);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(service.hasBlockedUs(blockerPubkey), isFalse);

        controller.add(olderBlockEvent);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(service.hasBlockedUs(blockerPubkey), isFalse);
        expect(service.shouldFilterFromFeeds(blockerPubkey), isFalse);

        await controller.close();
      },
    );
  });

  group('ContentBlocklistRepository - legacy own block list is inert', () {
    late ContentBlocklistRepository service;
    late _MockNostrClient mockNostrService;
    late _MockBlockListSigner mockSigner;
    late StreamController<Event> controller;

    const ourPubkey =
        '0000000000000000000000000000000000000000000000000000000000000001';
    const blockedPubkey1 =
        '0000000000000000000000000000000000000000000000000000000000000002';
    const blockedPubkey2 =
        '0000000000000000000000000000000000000000000000000000000000000003';

    Event makeOwnBlockListEvent(List<String> blockedPubkeys) {
      return Event(
          ourPubkey,
          30000,
          [
            const ['d', 'block'],
            const ['title', 'Block List'],
            for (final pk in blockedPubkeys) ['p', pk],
          ],
          'Block list',
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        )
        ..id = 'own-block-event-${blockedPubkeys.length}'
        ..sig = 'signature';
    }

    setUp(() {
      mockNostrService = _MockNostrClient();
      mockSigner = _MockBlockListSigner();
      controller = StreamController<Event>();

      when(() => mockSigner.isAuthenticated).thenReturn(false);
      when(
        () => mockNostrService.subscribe(
          any(),
        ),
      ).thenAnswer((_) => controller.stream);
    });

    tearDown(() async {
      await controller.close();
    });

    test(
      'own relay event does not restore blocks',
      () async {
        var changeCount = 0;
        service = ContentBlocklistRepository(onChanged: () => changeCount++);

        await service.syncBlockListsInBackground(
          mockNostrService,
          mockSigner,
          ourPubkey,
        );

        controller.add(makeOwnBlockListEvent([blockedPubkey1, blockedPubkey2]));
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(service.isBlocked(blockedPubkey1), isFalse);
        expect(service.isBlocked(blockedPubkey2), isFalse);
        expect(service.totalBlockedCount, equals(0));
        expect(changeCount, equals(0));
      },
    );

    test(
      'a superseded own list cannot resurrect a lifted block (#7027)',
      () async {
        service = ContentBlocklistRepository();

        await service.blockUser(blockedPubkey1, ourPubkey: ourPubkey);
        await service.syncBlockListsInBackground(
          mockNostrService,
          mockSigner,
          ourPubkey,
        );
        await service.unblockUser(blockedPubkey1);
        expect(service.isBlocked(blockedPubkey1), isFalse);

        // The relay re-serves the superseded copy that still carries the
        // block. Merging it back in is what made unblock fail to stick.
        controller.add(makeOwnBlockListEvent([blockedPubkey1]));
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(service.isBlocked(blockedPubkey1), isFalse);
        expect(service.totalBlockedCount, equals(0));
      },
    );

    test(
      'still detects others blocking us',
      () async {
        var changeCount = 0;
        service = ContentBlocklistRepository(onChanged: () => changeCount++);

        await service.syncBlockListsInBackground(
          mockNostrService,
          mockSigner,
          ourPubkey,
        );

        // Another user blocks us
        final othersEvent =
            Event(
                blockedPubkey2,
                30000,
                [
                  const ['d', 'block'],
                  ['p', ourPubkey],
                ],
                'Block list',
                createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
              )
              ..id = 'others-block-event'
              ..sig = 'signature';

        controller.add(othersEvent);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(service.hasBlockedUs(blockedPubkey2), isTrue);
        expect(changeCount, equals(1));
      },
    );
  });

  group('ContentBlocklistRepository - persistence', () {
    const blockedUsersKey = 'blocked_users_list';
    const severedFollowersKey = 'severed_followers_list';

    test('loads existing blocked users from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        blockedUsersKey: jsonEncode(['pubkey1', 'pubkey2']),
      });
      final prefs = await SharedPreferences.getInstance();

      final service = ContentBlocklistRepository(prefs: prefs);

      expect(service.isBlocked('pubkey1'), isTrue);
      expect(service.isBlocked('pubkey2'), isTrue);
      expect(service.totalBlockedCount, equals(2));
    });

    test('ignores corrupt blocked users JSON without throwing', () async {
      SharedPreferences.setMockInitialValues({
        blockedUsersKey: 'not valid json',
      });
      final prefs = await SharedPreferences.getInstance();

      final service = ContentBlocklistRepository(prefs: prefs);

      expect(service.totalBlockedCount, equals(0));
    });

    test('ignores corrupt muted authors JSON without throwing', () async {
      SharedPreferences.setMockInitialValues({
        'muted_users_list': 'not valid json',
      });
      final prefs = await SharedPreferences.getInstance();

      final service = ContentBlocklistRepository(prefs: prefs);

      expect(service.currentState.mutedPubkeys, isEmpty);
    });

    test('loads existing severed followers from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        severedFollowersKey: jsonEncode(['severed1']),
      });
      final prefs = await SharedPreferences.getInstance();

      final service = ContentBlocklistRepository(prefs: prefs);

      expect(service.isFollowSevered('severed1'), isTrue);
    });

    test('ignores corrupt severed followers JSON without throwing', () async {
      SharedPreferences.setMockInitialValues({
        severedFollowersKey: 'not valid json',
      });
      final prefs = await SharedPreferences.getInstance();

      final service = ContentBlocklistRepository(prefs: prefs);

      expect(service.isFollowSevered('anything'), isFalse);
    });

    test('persists blocked user and severed follower on blockUser', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final service = ContentBlocklistRepository(prefs: prefs);

      await service.blockUser('pubkey1');

      final blockedJson = prefs.getString(blockedUsersKey);
      expect(blockedJson, isNotNull);
      expect(
        (jsonDecode(blockedJson!) as List).cast<String>(),
        contains('pubkey1'),
      );

      final severedJson = prefs.getString(severedFollowersKey);
      expect(severedJson, isNotNull);
      expect(
        (jsonDecode(severedJson!) as List).cast<String>(),
        contains('pubkey1'),
      );
    });

    test('continues when SharedPreferences.setString throws', () async {
      final mockPrefs = _MockSharedPreferences();
      when(() => mockPrefs.getString(any())).thenReturn(null);
      when(
        () => mockPrefs.setString(any(), any()),
      ).thenThrow(Exception('disk full'));

      final service = ContentBlocklistRepository(prefs: mockPrefs);

      // Should not rethrow even though setString fails for both
      // blocked_users_list and severed_followers_list writes.
      await service.blockUser('pubkey1');

      expect(service.isBlocked('pubkey1'), isTrue);
    });
  });

  group('ContentBlocklistRepository - severed followers', () {
    test('isFollowSevered returns true after blocking', () async {
      final service = ContentBlocklistRepository();
      await service.blockUser('pubkey1');

      expect(service.isFollowSevered('pubkey1'), isTrue);
    });

    test('isFollowSevered returns false for unknown pubkey', () {
      final service = ContentBlocklistRepository();

      expect(service.isFollowSevered('unknown'), isFalse);
    });

    test('removeSeveredFollower clears entry and persists', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final service = ContentBlocklistRepository(prefs: prefs);

      await service.blockUser('pubkey1');
      expect(service.isFollowSevered('pubkey1'), isTrue);

      service.removeSeveredFollower('pubkey1');

      expect(service.isFollowSevered('pubkey1'), isFalse);
    });

    test('removeSeveredFollower is a no-op for unknown pubkey', () {
      final service = ContentBlocklistRepository()
        ..removeSeveredFollower('never_severed');

      expect(service.isFollowSevered('never_severed'), isFalse);
    });
  });

  group('ContentBlocklistRepository - getters and utility', () {
    test('blockedPubkeys exposes the combined runtime set', () async {
      final service = ContentBlocklistRepository();
      await service.blockUser('pubkey1');

      expect(service.blockedPubkeys, contains('pubkey1'));
    });

    test('isInternallyBlocked returns false (internal list is empty)', () {
      final service = ContentBlocklistRepository();

      expect(service.isInternallyBlocked('any_pubkey'), isFalse);
    });

    test('runtimeBlockedUsers is unmodifiable', () async {
      final service = ContentBlocklistRepository();
      await service.blockUser('pubkey1');

      expect(service.runtimeBlockedUsers, contains('pubkey1'));
      expect(
        () => service.runtimeBlockedUsers.add('pubkey2'),
        throwsUnsupportedError,
      );
    });

    test('clearRuntimeBlocks empties runtime blocks', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final service = ContentBlocklistRepository(prefs: prefs);

      await service.blockUser('pubkey1');
      expect(service.totalBlockedCount, equals(1));

      service.clearRuntimeBlocks();

      expect(service.totalBlockedCount, equals(0));
    });

    test('clearRuntimeBlocks is a no-op when already empty', () {
      final service = ContentBlocklistRepository()..clearRuntimeBlocks();

      expect(service.totalBlockedCount, equals(0));
    });
  });

  group('feedHiddenPubkeys', () {
    const ourPubkey =
        '0000000000000000000000000000000000000000000000000000000000000001';
    const runtimeBlocked =
        '0000000000000000000000000000000000000000000000000000000000000002';
    const mutedByUs =
        '0000000000000000000000000000000000000000000000000000000000000003';
    const mutualMuter =
        '0000000000000000000000000000000000000000000000000000000000000004';
    const blockedByOther =
        '0000000000000000000000000000000000000000000000000000000000000005';
    const stranger =
        '0000000000000000000000000000000000000000000000000000000000000006';

    test('is empty when no hide bucket is populated', () {
      expect(ContentBlocklistRepository().feedHiddenPubkeys, isEmpty);
    });

    test(
      'unions every hide bucket and stays equivalent to shouldFilterFromFeeds',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final prefs = await SharedPreferences.getInstance();
        final service = ContentBlocklistRepository(prefs: prefs);

        final muteController = StreamController<Event>();
        final blockController = StreamController<Event>();
        final mockMuteClient = _MockNostrClient();
        final mockBlockClient = _MockNostrClient();
        final mockSigner = _MockBlockListSigner();
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

        // Runtime-block bucket.
        await service.blockUser(runtimeBlocked, ourPubkey: ourPubkey);

        // Own-mute + mutual-mute buckets, both via the kind 10000 stream.
        when(
          () => mockMuteClient.subscribe(any()),
        ).thenAnswer((_) => muteController.stream);
        await service.syncMuteListsInBackground(mockMuteClient, ourPubkey);
        muteController
          ..add(
            Event(
                ourPubkey,
                10000,
                [
                  ['p', mutedByUs],
                ],
                '',
                createdAt: now,
              )
              ..id = 'own-mute'
              ..sig = 'sig',
          )
          ..add(
            Event(
                mutualMuter,
                10000,
                [
                  ['p', ourPubkey],
                ],
                '',
                createdAt: now,
              )
              ..id = 'mutual-mute'
              ..sig = 'sig',
          );

        // Blocked-by bucket via the kind 30000 d=block stream.
        when(
          () => mockBlockClient.subscribe(any()),
        ).thenAnswer((_) => blockController.stream);
        when(() => mockBlockClient.queryEvents(any())).thenAnswer(
          (_) async => <Event>[],
        );
        when(() => mockSigner.isAuthenticated).thenReturn(false);
        await service.syncBlockListsInBackground(
          mockBlockClient,
          mockSigner,
          ourPubkey,
        );
        blockController.add(
          Event(
              blockedByOther,
              30000,
              [
                ['d', 'block'],
                ['p', ourPubkey],
              ],
              'Block list',
              createdAt: now,
            )
            ..id = 'blocked-by'
            ..sig = 'sig',
        );

        await Future<void>.delayed(const Duration(milliseconds: 100));

        final hidden = service.feedHiddenPubkeys;
        expect(
          hidden,
          containsAll(<String>{
            runtimeBlocked,
            mutedByUs,
            mutualMuter,
            blockedByOther,
          }),
        );
        expect(hidden, isNot(contains(stranger)));

        // The set and the predicate must agree for every pubkey, so a future
        // sixth bucket added to one cannot silently diverge from the other.
        for (final pubkey in <String>{
          runtimeBlocked,
          mutedByUs,
          mutualMuter,
          blockedByOther,
          stranger,
        }) {
          expect(
            hidden.contains(pubkey),
            equals(service.shouldFilterFromFeeds(pubkey)),
            reason:
                'feedHiddenPubkeys and shouldFilterFromFeeds '
                'disagree for $pubkey',
          );
        }

        await muteController.close();
        await blockController.close();
      },
    );
  });

  group('shouldFilterFromDms', () {
    const ourPubkey =
        '0000000000000000000000000000000000000000000000000000000000000001';
    const runtimeBlocked =
        '0000000000000000000000000000000000000000000000000000000000000002';
    const mutedByUs =
        '0000000000000000000000000000000000000000000000000000000000000003';
    const mutualMuter =
        '0000000000000000000000000000000000000000000000000000000000000004';
    const blockedByOther =
        '0000000000000000000000000000000000000000000000000000000000000005';
    const stranger =
        '0000000000000000000000000000000000000000000000000000000000000006';

    DmConversation conversationWith(String otherPubkey) => DmConversation(
      id: 'conv-$otherPubkey',
      participantPubkeys: [ourPubkey, otherPubkey],
      isGroup: false,
      createdAt: 1,
    );

    test('is empty when no hide bucket is populated', () {
      expect(ContentBlocklistRepository().dmHiddenPubkeys, isEmpty);
    });

    test('keeps a DM thread when the counterparty mutes or blocks us, and '
        'still hides the ones we hid ourselves', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final service = ContentBlocklistRepository(prefs: prefs);

      final muteController = StreamController<Event>();
      final blockController = StreamController<Event>();
      final mockMuteClient = _MockNostrClient();
      final mockBlockClient = _MockNostrClient();
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      await service.blockUser(runtimeBlocked, ourPubkey: ourPubkey);

      when(
        () => mockMuteClient.subscribe(any()),
      ).thenAnswer((_) => muteController.stream);
      await service.syncMuteListsInBackground(mockMuteClient, ourPubkey);
      muteController
        ..add(
          Event(
              ourPubkey,
              10000,
              [
                ['p', mutedByUs],
              ],
              '',
              createdAt: now,
            )
            ..id = 'own-mute'
            ..sig = 'sig',
        )
        ..add(
          Event(
              mutualMuter,
              10000,
              [
                ['p', ourPubkey],
              ],
              '',
              createdAt: now,
            )
            ..id = 'mutual-mute'
            ..sig = 'sig',
        );

      final mockSigner = _MockBlockListSigner();
      when(() => mockSigner.isAuthenticated).thenReturn(false);
      when(
        () => mockBlockClient.subscribe(any()),
      ).thenAnswer((_) => blockController.stream);
      await service.syncBlockListsInBackground(
        mockBlockClient,
        mockSigner,
        ourPubkey,
      );
      blockController.add(
        Event(
            blockedByOther,
            30000,
            [
              ['d', 'block'],
              ['p', ourPubkey],
            ],
            'Block list',
            createdAt: now,
          )
          ..id = 'blocked-by'
          ..sig = 'sig',
      );

      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Precondition: all four buckets really are populated, so the
      // assertions below cannot pass vacuously.
      expect(
        service.feedHiddenPubkeys,
        containsAll(<String>{
          runtimeBlocked,
          mutedByUs,
          mutualMuter,
          blockedByOther,
        }),
      );

      // The regression (#7345): a third party's list must not reach a DM
      // surface, whether asked as a predicate, a set, or a conversation
      // filter.
      for (final pubkey in <String>{mutualMuter, blockedByOther}) {
        expect(service.shouldFilterFromDms(pubkey), isFalse);
        expect(service.dmHiddenPubkeys, isNot(contains(pubkey)));
      }
      expect(
        service.filterBlockedConversations([
          conversationWith(mutualMuter),
          conversationWith(blockedByOther),
        ], userPubkey: ourPubkey),
        hasLength(2),
      );

      // The viewer's own decisions still hide, so this is not a blanket
      // removal of DM filtering.
      for (final pubkey in <String>{runtimeBlocked, mutedByUs}) {
        expect(service.shouldFilterFromDms(pubkey), isTrue);
        expect(service.dmHiddenPubkeys, contains(pubkey));
      }
      expect(
        service.filterBlockedConversations([
          conversationWith(runtimeBlocked),
          conversationWith(mutedByUs),
        ], userPubkey: ourPubkey),
        isEmpty,
      );

      expect(service.shouldFilterFromDms(stranger), isFalse);

      // The set and the predicate must agree for every pubkey, so a future
      // bucket added to one cannot silently diverge from the other.
      for (final pubkey in <String>{
        runtimeBlocked,
        mutedByUs,
        mutualMuter,
        blockedByOther,
        stranger,
      }) {
        expect(
          service.dmHiddenPubkeys.contains(pubkey),
          equals(service.shouldFilterFromDms(pubkey)),
          reason:
              'dmHiddenPubkeys and shouldFilterFromDms '
              'disagree for $pubkey',
        );
      }

      // DM hiding is a strict subset of feed hiding: a bucket added to the
      // viewer list reaches both, and one added to the feed list reaches
      // only feeds.
      expect(service.feedHiddenPubkeys, containsAll(service.dmHiddenPubkeys));

      await muteController.close();
      await blockController.close();
    });
  });

  group('blockedPubkeysForAccount', () {
    const ourPubkey =
        '0000000000000000000000000000000000000000000000000000000000000001';
    const otherAccount =
        '00000000000000000000000000000000000000000000000000000000000000aa';
    const runtimeBlocked =
        '0000000000000000000000000000000000000000000000000000000000000002';
    const mutedByUs =
        '0000000000000000000000000000000000000000000000000000000000000003';
    const mutualMuter =
        '0000000000000000000000000000000000000000000000000000000000000004';
    const blockedByOther =
        '0000000000000000000000000000000000000000000000000000000000000005';

    test('is empty before any identity is adopted', () async {
      final service = ContentBlocklistRepository();
      await service.blockUser(runtimeBlocked);

      expect(service.blockedPubkeys, contains(runtimeBlocked));
      expect(service.blockedPubkeysForAccount(ourPubkey), isEmpty);
    });

    test(
      'a refused relay subscription does not become an uncaught error',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final prefs = await SharedPreferences.getInstance();
        final service = ContentBlocklistRepository(prefs: prefs);
        final mockClient = _MockNostrClient();
        when(() => mockClient.subscribe(any())).thenAnswer(
          (_) => Stream<Event>.error(
            const RelaySubscriptionRefusedException(
              'error: too many subscriptions',
            ),
          ),
        );

        // Both syncs listen without awaiting. Without an onError handler the
        // stream error reaches the zone and is reported as a crash.
        await service.syncMuteListsInBackground(mockClient, ourPubkey);
        final mockSigner = _MockBlockListSigner();
        when(() => mockSigner.isAuthenticated).thenReturn(false);
        await service.syncBlockListsInBackground(
          mockClient,
          mockSigner,
          ourPubkey,
        );
        await pumpEventQueue();

        expect(service.blockedPubkeysForAccount(ourPubkey), isEmpty);
      },
    );

    test('is empty for the empty pubkey', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final service = ContentBlocklistRepository(prefs: prefs);
      final mockClient = _MockNostrClient();
      when(
        () => mockClient.subscribe(any()),
      ).thenAnswer((_) => const Stream<Event>.empty());
      await service.syncMuteListsInBackground(mockClient, ourPubkey);
      await service.blockUser(runtimeBlocked, ourPubkey: ourPubkey);

      expect(service.blockedPubkeysForAccount(''), isEmpty);
    });

    test(
      'answers for the adopted account and withholds from every other one',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final prefs = await SharedPreferences.getInstance();
        final service = ContentBlocklistRepository(prefs: prefs);
        final mockClient = _MockNostrClient();
        when(
          () => mockClient.subscribe(any()),
        ).thenAnswer((_) => const Stream<Event>.empty());
        await service.syncMuteListsInBackground(mockClient, ourPubkey);
        await service.blockUser(runtimeBlocked, ourPubkey: ourPubkey);

        expect(
          service.blockedPubkeysForAccount(ourPubkey),
          contains(runtimeBlocked),
        );
        // A keepAlive repository can still hold account A's blocks while a
        // session signs as B. Answering here would filter B's published
        // follow list against A's blocks (#6903).
        expect(service.blockedPubkeysForAccount(otherAccount), isEmpty);
      },
    );

    test(
      'excludes every hide bucket that is not an explicit block by us',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final prefs = await SharedPreferences.getInstance();
        final service = ContentBlocklistRepository(prefs: prefs);

        final muteController = StreamController<Event>();
        final blockController = StreamController<Event>();
        final mockMuteClient = _MockNostrClient();
        final mockBlockClient = _MockNostrClient();
        final mockSigner = _MockBlockListSigner();
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

        await service.blockUser(runtimeBlocked, ourPubkey: ourPubkey);

        when(
          () => mockMuteClient.subscribe(any()),
        ).thenAnswer((_) => muteController.stream);
        await service.syncMuteListsInBackground(mockMuteClient, ourPubkey);
        muteController
          ..add(
            Event(
                ourPubkey,
                10000,
                [
                  ['p', mutedByUs],
                ],
                '',
                createdAt: now,
              )
              ..id = 'own-mute'
              ..sig = 'sig',
          )
          ..add(
            Event(
                mutualMuter,
                10000,
                [
                  ['p', ourPubkey],
                ],
                '',
                createdAt: now,
              )
              ..id = 'mutual-mute'
              ..sig = 'sig',
          );

        when(
          () => mockBlockClient.subscribe(any()),
        ).thenAnswer((_) => blockController.stream);
        when(
          () => mockBlockClient.queryEvents(any()),
        ).thenAnswer((_) async => <Event>[]);
        when(() => mockSigner.isAuthenticated).thenReturn(false);
        await service.syncBlockListsInBackground(
          mockBlockClient,
          mockSigner,
          ourPubkey,
        );
        blockController.add(
          Event(
              blockedByOther,
              30000,
              [
                ['d', 'block'],
                ['p', ourPubkey],
              ],
              'Block list',
              createdAt: now,
            )
            ..id = 'blocked-by'
            ..sig = 'sig',
        );

        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Every bucket below is hidden from feeds, and every one of them
        // would be attacker- or third-party-controlled input to a Nostr
        // event if it reached a write path. `blockedByOther` is the sharp
        // one: including it would let anyone rewrite our published follow
        // list just by blocking us.
        expect(service.feedHiddenPubkeys, contains(blockedByOther));
        expect(
          service.blockedPubkeysForAccount(ourPubkey),
          equals(<String>{runtimeBlocked}),
        );

        await muteController.close();
        await blockController.close();
      },
    );
  });

  group('ContentBlocklistRepository - Nostr publishing', () {
    late _MockNostrClient mockClient;
    late _MockBlockListSigner mockSigner;
    const ourPubkey =
        '0000000000000000000000000000000000000000000000000000000000000001';

    setUp(() {
      mockClient = _MockNostrClient();
      mockSigner = _MockBlockListSigner();
      when(
        () => mockClient.subscribe(any()),
      ).thenAnswer((_) => const Stream.empty());
      when(() => mockClient.queryEvents(any())).thenAnswer((_) async => []);
    });

    Event buildEvent({
      int kind = 30000,
      List<List<String>> tags = const <List<String>>[],
      String content = 'Block list',
      int? createdAt,
    }) {
      return Event(
          ourPubkey,
          kind,
          tags,
          content,
          createdAt: createdAt ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
        )
        ..id = 'test-event-id'
        ..sig = 'signature';
    }

    Event signedEventFromInvocation(Invocation invocation) {
      return buildEvent(
        kind: invocation.namedArguments[#kind] as int,
        content: invocation.namedArguments[#content] as String,
        tags: invocation.namedArguments[#tags] as List<List<String>>,
      );
    }

    test('does not publish when signer is not authenticated', () async {
      when(() => mockSigner.isAuthenticated).thenReturn(false);

      final service = ContentBlocklistRepository();
      await service.syncBlockListsInBackground(
        mockClient,
        mockSigner,
        ourPubkey,
      );

      await service.blockUser('pubkey1');

      verifyNever(
        () => mockSigner.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      );
    });

    test('blocking publishes the kind 10000 mute list with a p tag', () async {
      when(() => mockSigner.isAuthenticated).thenReturn(true);
      when(
        () => mockSigner.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer(
        (invocation) async => signedEventFromInvocation(invocation),
      );
      when(
        () => mockClient.publishEvent(any()),
      ).thenAnswer(
        (invocation) async => PublishSuccess(
          event: invocation.positionalArguments.first as Event,
        ),
      );

      final service = ContentBlocklistRepository();
      await service.syncBlockListsInBackground(
        mockClient,
        mockSigner,
        ourPubkey,
      );

      await service.blockUser('pubkey1');

      // The interop fix (#4037): the blocked user lands on the standard
      // NIP-51 kind 10000 mute list, with no parameterized-list tags.
      final muteTags =
          verify(
                () => mockSigner.createAndSignEvent(
                  kind: 10000,
                  content: '',
                  tags: captureAny(named: 'tags'),
                ),
              ).captured.last
              as List<List<String>>;
      expect(muteTags, contains(equals(['p', 'pubkey1'])));
      expect(muteTags, isNot(contains(equals(['d', 'block']))));

      // The legacy kind 30000 block list is no longer authored (#5462).
      verifyNever(
        () => mockSigner.createAndSignEvent(
          kind: 30000,
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      );

      verify(() => mockClient.publishEvent(any())).called(1);
    });

    test('blockUsers publishes each Nostr list once for a batch', () async {
      when(() => mockSigner.isAuthenticated).thenReturn(true);
      when(
        () => mockSigner.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer(
        (invocation) async => signedEventFromInvocation(invocation),
      );
      when(
        () => mockClient.publishEvent(any()),
      ).thenAnswer(
        (invocation) async => PublishSuccess(
          event: invocation.positionalArguments.first as Event,
        ),
      );

      final service = ContentBlocklistRepository();
      await service.syncBlockListsInBackground(
        mockClient,
        mockSigner,
        ourPubkey,
      );

      await service.blockUsers([
        '00000000000000000000000000000000000000000000000000000000000000aa',
        ourPubkey,
        '00000000000000000000000000000000000000000000000000000000000000bb',
        '00000000000000000000000000000000000000000000000000000000000000aa',
      ]);

      final muteTags =
          verify(
                () => mockSigner.createAndSignEvent(
                  kind: 10000,
                  content: '',
                  tags: captureAny(named: 'tags'),
                ),
              ).captured.single
              as List<List<String>>;
      expect(
        muteTags,
        containsAll([
          equals([
            'p',
            '00000000000000000000000000000000000000000000000000000000000000aa',
          ]),
          equals([
            'p',
            '00000000000000000000000000000000000000000000000000000000000000bb',
          ]),
        ]),
      );
      expect(muteTags, isNot(contains(equals(['p', ourPubkey]))));

      verifyNever(
        () => mockSigner.createAndSignEvent(
          kind: 30000,
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      );

      verify(() => mockClient.publishEvent(any())).called(1);
    });

    test('unblocking republishes the kind 10000 mute list without the '
        'user', () async {
      when(() => mockSigner.isAuthenticated).thenReturn(true);
      when(
        () => mockSigner.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer(
        (invocation) async => signedEventFromInvocation(invocation),
      );
      when(
        () => mockClient.publishEvent(any()),
      ).thenAnswer(
        (invocation) async => PublishSuccess(
          event: invocation.positionalArguments.first as Event,
        ),
      );

      final service = ContentBlocklistRepository();
      await service.syncBlockListsInBackground(
        mockClient,
        mockSigner,
        ourPubkey,
      );

      await service.blockUser('pubkey1');
      await service.unblockUser('pubkey1');

      final lastMuteTags =
          verify(
                () => mockSigner.createAndSignEvent(
                  kind: 10000,
                  content: '',
                  tags: captureAny(named: 'tags'),
                ),
              ).captured.last
              as List<List<String>>;
      expect(lastMuteTags, isEmpty);
    });

    test('blocking preserves existing NIP-51 public tags and encrypted '
        'content', () async {
      const existingMute =
          '00000000000000000000000000000000000000000000000000000000000000cc';
      const blockedPubkey =
          '00000000000000000000000000000000000000000000000000000000000000dd';
      final existingEvent = buildEvent(
        kind: 10000,
        content: 'encrypted-private-tags',
        tags: const [
          ['p', existingMute, 'wss://relay.example'],
          ['t', 'spoilers'],
          ['word', 'spoiler'],
          ['e', 'event-thread-id'],
        ],
        createdAt: 1000,
      );
      when(() => mockSigner.isAuthenticated).thenReturn(true);
      when(
        () => mockClient.queryEvents(any()),
      ).thenAnswer((_) async => [existingEvent]);
      when(
        () => mockSigner.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer(
        (invocation) async => signedEventFromInvocation(invocation),
      );
      when(
        () => mockClient.publishEvent(any()),
      ).thenAnswer(
        (invocation) async => PublishSuccess(
          event: invocation.positionalArguments.first as Event,
        ),
      );

      final service = ContentBlocklistRepository();
      await service.syncBlockListsInBackground(
        mockClient,
        mockSigner,
        ourPubkey,
      );

      await service.blockUser(blockedPubkey);

      final capturedMuteCall = verify(
        () => mockSigner.createAndSignEvent(
          kind: 10000,
          content: captureAny(named: 'content'),
          tags: captureAny(named: 'tags'),
        ),
      ).captured;
      final content = capturedMuteCall[0] as String;
      final tags = capturedMuteCall[1] as List<List<String>>;

      expect(content, 'encrypted-private-tags');
      expect(
        tags,
        contains(equals(['p', existingMute, 'wss://relay.example'])),
      );
      expect(tags, contains(equals(['p', blockedPubkey])));
      expect(tags, contains(equals(['t', 'spoilers'])));
      expect(tags, contains(equals(['word', 'spoiler'])));
      expect(tags, contains(equals(['e', 'event-thread-id'])));
    });

    test(
      'blocking someone already muted elsewhere keeps their relay hint',
      () async {
        // `_applyOwnMuteListEvent` keeps our own blocks out of `_mutedPubkeys`,
        // so the source-preservation loop skips this pubkey and the re-emit
        // path is what decides whether the hint survives.
        const alreadyMuted =
            '00000000000000000000000000000000000000000000000000000000000000ee';
        final existingEvent = buildEvent(
          kind: 10000,
          content: 'encrypted-private-tags',
          tags: const [
            ['p', alreadyMuted, 'wss://relay.example'],
          ],
          createdAt: 1000,
        );
        when(() => mockSigner.isAuthenticated).thenReturn(true);
        when(
          () => mockClient.queryEvents(any()),
        ).thenAnswer((_) async => [existingEvent]);
        when(
          () => mockSigner.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer(
          (invocation) async => signedEventFromInvocation(invocation),
        );
        when(() => mockClient.publishEvent(any())).thenAnswer(
          (invocation) async => PublishSuccess(
            event: invocation.positionalArguments.first as Event,
          ),
        );

        final service = ContentBlocklistRepository();
        await service.syncBlockListsInBackground(
          mockClient,
          mockSigner,
          ourPubkey,
        );

        await service.blockUser(alreadyMuted);

        final tags =
            verify(
                  () => mockSigner.createAndSignEvent(
                    kind: 10000,
                    content: any(named: 'content'),
                    tags: captureAny(named: 'tags'),
                  ),
                ).captured.last
                as List<List<String>>;
        expect(
          tags,
          contains(equals(['p', alreadyMuted, 'wss://relay.example'])),
        );
        expect(tags, isNot(contains(equals(['p', alreadyMuted]))));
      },
    );

    test('blocking appends hydrated external p mutes before the latest source '
        'event is available', () async {
      const existingMute =
          '00000000000000000000000000000000000000000000000000000000000000cc';
      const blockedPubkey =
          '00000000000000000000000000000000000000000000000000000000000000dd';
      SharedPreferences.setMockInitialValues(<String, Object>{
        'muted_users_list': jsonEncode([existingMute]),
      });
      final prefs = await SharedPreferences.getInstance();
      when(() => mockSigner.isAuthenticated).thenReturn(true);
      when(
        () => mockSigner.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer(
        (invocation) async => signedEventFromInvocation(invocation),
      );
      when(
        () => mockClient.publishEvent(any()),
      ).thenAnswer(
        (invocation) async => PublishSuccess(
          event: invocation.positionalArguments.first as Event,
        ),
      );

      final service = ContentBlocklistRepository(prefs: prefs);
      await service.syncBlockListsInBackground(
        mockClient,
        mockSigner,
        ourPubkey,
      );

      await service.blockUser(blockedPubkey);

      final tags =
          verify(
                () => mockSigner.createAndSignEvent(
                  kind: 10000,
                  content: any(named: 'content'),
                  tags: captureAny(named: 'tags'),
                ),
              ).captured.last
              as List<List<String>>;
      expect(tags, contains(equals(['p', existingMute])));
      expect(tags, contains(equals(['p', blockedPubkey])));
    });

    test(
      'unblocking preserves non-p mute-list tags and encrypted content',
      () async {
        const blockedPubkey =
            '00000000000000000000000000000000000000000000000000000000000000dd';
        final existingEvent = buildEvent(
          kind: 10000,
          content: 'encrypted-private-tags',
          tags: const [
            ['t', 'spoilers'],
            ['word', 'spoiler'],
            ['e', 'event-thread-id'],
          ],
          createdAt: 1000,
        );
        when(() => mockSigner.isAuthenticated).thenReturn(true);
        when(
          () => mockClient.queryEvents(any()),
        ).thenAnswer((_) async => [existingEvent]);
        when(
          () => mockSigner.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer(
          (invocation) async => signedEventFromInvocation(invocation),
        );
        when(
          () => mockClient.publishEvent(any()),
        ).thenAnswer(
          (invocation) async => PublishSuccess(
            event: invocation.positionalArguments.first as Event,
          ),
        );

        final service = ContentBlocklistRepository();
        await service.syncBlockListsInBackground(
          mockClient,
          mockSigner,
          ourPubkey,
        );

        await service.blockUser(blockedPubkey);
        await service.unblockUser(blockedPubkey);

        final capturedMuteCalls = verify(
          () => mockSigner.createAndSignEvent(
            kind: 10000,
            content: captureAny(named: 'content'),
            tags: captureAny(named: 'tags'),
          ),
        ).captured;
        final lastContent =
            capturedMuteCalls[capturedMuteCalls.length - 2] as String;
        final lastTags =
            capturedMuteCalls[capturedMuteCalls.length - 1]
                as List<List<String>>;

        expect(lastContent, 'encrypted-private-tags');
        expect(lastTags, isNot(contains(equals(['p', blockedPubkey]))));
        expect(lastTags, contains(equals(['t', 'spoilers'])));
        expect(lastTags, contains(equals(['word', 'spoiler'])));
        expect(lastTags, contains(equals(['e', 'event-thread-id'])));
      },
    );

    test('tolerates publishEvent returning null', () async {
      when(() => mockSigner.isAuthenticated).thenReturn(true);
      when(
        () => mockSigner.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((_) async => buildEvent());
      when(
        () => mockClient.publishEvent(any()),
      ).thenAnswer((_) async => const PublishFailed());

      final service = ContentBlocklistRepository();
      await service.syncBlockListsInBackground(
        mockClient,
        mockSigner,
        ourPubkey,
      );

      // Should not throw even though publish returns null.
      await service.blockUser('pubkey1');

      expect(service.isBlocked('pubkey1'), isTrue);
    });

    test('swallows exceptions raised while signing the event', () async {
      when(() => mockSigner.isAuthenticated).thenReturn(true);
      when(
        () => mockSigner.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenThrow(Exception('signing failure'));

      final service = ContentBlocklistRepository();
      await service.syncBlockListsInBackground(
        mockClient,
        mockSigner,
        ourPubkey,
      );

      // Should not rethrow; blockUser still succeeds locally.
      await service.blockUser('pubkey1');

      expect(service.isBlocked('pubkey1'), isTrue);
    });

    group('inconclusive own-mute-list read (#6750)', () {
      const blockedPubkey =
          '00000000000000000000000000000000000000000000000000000000000000dd';

      void stubMuteRead({
        List<Event> events = const <Event>[],
        bool timedOut = false,
        bool noRelays = false,
      }) {
        when(
          () => mockClient.queryEventsDetailed(
            any(),
            requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
          ),
        ).thenAnswer(
          (_) async => (
            events: events,
            timedOut: timedOut,
            noRelays: noRelays,
          ),
        );
      }

      void stubSigningAndPublishing() {
        when(() => mockSigner.isAuthenticated).thenReturn(true);
        when(
          () => mockSigner.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer(
          (invocation) async => signedEventFromInvocation(invocation),
        );
        when(() => mockClient.publishEvent(any())).thenAnswer(
          (invocation) async => PublishSuccess(
            event: invocation.positionalArguments.first as Event,
          ),
        );
      }

      Future<ContentBlocklistRepository> startedService([
        SharedPreferences? prefs,
      ]) async {
        final service = ContentBlocklistRepository(prefs: prefs);
        await service.syncBlockListsInBackground(
          mockClient,
          mockSigner,
          ourPubkey,
        );
        return service;
      }

      test('blocking does not publish when the read timed out', () async {
        stubSigningAndPublishing();
        stubMuteRead(timedOut: true);

        final service = await startedService();
        await service.blockUser(blockedPubkey);

        verifyNever(
          () => mockSigner.createAndSignEvent(
            kind: 10000,
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        );
      });

      test(
        'blocking does not publish when no relay took the query',
        () async {
          stubSigningAndPublishing();
          stubMuteRead(noRelays: true);

          final service = await startedService();
          await service.blockUser(blockedPubkey);

          verifyNever(
            () => mockSigner.createAndSignEvent(
              kind: 10000,
              content: any(named: 'content'),
              tags: any(named: 'tags'),
            ),
          );
        },
      );

      test('the block still applies and persists when the publish is '
          'withheld', () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final prefs = await SharedPreferences.getInstance();
        stubSigningAndPublishing();
        stubMuteRead(timedOut: true);

        final service = await startedService(prefs);
        await service.blockUser(blockedPubkey);

        expect(service.isBlocked(blockedPubkey), isTrue);
        // Survives a restart: the local block is the part that must not be
        // gated on relay health.
        expect(
          ContentBlocklistRepository(prefs: prefs).isBlocked(blockedPubkey),
          isTrue,
        );
      });

      test(
        'unblocking does not publish when the read is inconclusive',
        () async {
          stubSigningAndPublishing();
          stubMuteRead();

          final service = await startedService();
          await service.blockUser(blockedPubkey);
          clearInteractions(mockSigner);

          stubMuteRead(timedOut: true);
          await service.unblockUser(blockedPubkey);

          expect(service.isBlocked(blockedPubkey), isFalse);
          verifyNever(
            () => mockSigner.createAndSignEvent(
              kind: 10000,
              content: any(named: 'content'),
              tags: any(named: 'tags'),
            ),
          );
        },
      );

      test('a settled empty read still publishes, so a first block reaches '
          'the relay', () async {
        stubSigningAndPublishing();
        stubMuteRead();

        final service = await startedService();
        await service.blockUser(blockedPubkey);

        final tags =
            verify(
                  () => mockSigner.createAndSignEvent(
                    kind: 10000,
                    content: any(named: 'content'),
                    tags: captureAny(named: 'tags'),
                  ),
                ).captured.last
                as List<List<String>>;
        expect(tags, contains(equals(['p', blockedPubkey])));

        // The read that precedes a replace must demand every relay settle;
        // without it a partial answer reads as empty and clobbers the list
        // (#6750). Pin the argument so flipping it back to false fails here.
        verify(
          () => mockClient.queryEventsDetailed(
            any(),
            requireAllRelaysSettled: true,
          ),
        ).called(greaterThanOrEqualTo(1));
      });

      test('a withheld publish leaves the source event untouched, so the '
          'retry preserves it', () async {
        const existingMute =
            '00000000000000000000000000000000000000000000000000000000000000cc';
        final existingEvent = buildEvent(
          kind: 10000,
          content: 'encrypted-private-tags',
          tags: const [
            ['p', existingMute],
            ['t', 'spoilers'],
            ['word', 'spoiler'],
          ],
          createdAt: 1000,
        );
        stubSigningAndPublishing();
        stubMuteRead(timedOut: true);

        final service = await startedService();
        await service.blockUser(blockedPubkey);
        verifyNever(
          () => mockSigner.createAndSignEvent(
            kind: 10000,
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        );

        stubMuteRead(events: [existingEvent]);
        expect(await service.retryPendingMuteListPublish(), isTrue);

        final captured = verify(
          () => mockSigner.createAndSignEvent(
            kind: 10000,
            content: captureAny(named: 'content'),
            tags: captureAny(named: 'tags'),
          ),
        ).captured;
        expect(captured[0] as String, 'encrypted-private-tags');
        final tags = captured[1] as List<List<String>>;
        expect(tags, contains(equals(['t', 'spoilers'])));
        expect(tags, contains(equals(['word', 'spoiler'])));
        expect(tags, contains(equals(['p', existingMute])));
        expect(tags, contains(equals(['p', blockedPubkey])));
      });

      test(
        'retryPendingMuteListPublish is a no-op when nothing is pending',
        () async {
          stubSigningAndPublishing();
          stubMuteRead();

          final service = await startedService();
          await service.blockUser(blockedPubkey);
          clearInteractions(mockSigner);

          expect(await service.retryPendingMuteListPublish(), isFalse);
          verifyNever(
            () => mockSigner.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
            ),
          );
        },
      );

      test('a retry that is still inconclusive stays pending', () async {
        stubSigningAndPublishing();
        stubMuteRead(timedOut: true);

        final service = await startedService();
        await service.blockUser(blockedPubkey);

        expect(await service.retryPendingMuteListPublish(), isFalse);

        stubMuteRead();
        expect(await service.retryPendingMuteListPublish(), isTrue);
      });

      test('a restart republishes a block the relay never received', () async {
        // The app-kill case: the block survived in SharedPreferences, the
        // pending flag did not, and the relay's list predates it.
        SharedPreferences.setMockInitialValues(<String, Object>{
          'blocked_users_list': jsonEncode([blockedPubkey]),
        });
        final prefs = await SharedPreferences.getInstance();
        stubSigningAndPublishing();
        stubMuteRead();
        final ownList = StreamController<Event>();
        addTearDown(ownList.close);
        when(
          () => mockClient.subscribe(any()),
        ).thenAnswer((_) => ownList.stream);

        final service = ContentBlocklistRepository(prefs: prefs);
        await service.syncMuteListsInBackground(mockClient, ourPubkey);
        await service.syncBlockListsInBackground(
          mockClient,
          mockSigner,
          ourPubkey,
        );
        clearInteractions(mockSigner);

        // The relay serves a list that predates the block.
        ownList.add(
          buildEvent(
            kind: 10000,
            content: 'encrypted-private-tags',
            tags: const [
              ['t', 'spoilers'],
            ],
            createdAt: 5000,
          ),
        );
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        final captured = verify(
          () => mockSigner.createAndSignEvent(
            kind: 10000,
            content: captureAny(named: 'content'),
            tags: captureAny(named: 'tags'),
          ),
        ).captured;
        expect(captured[0] as String, 'encrypted-private-tags');
        final tags = captured[1] as List<List<String>>;
        expect(tags, contains(equals(['p', blockedPubkey])));
        expect(tags, contains(equals(['t', 'spoilers'])));
      });

      test(
        'a list that already carries our blocks republishes nothing',
        () async {
          SharedPreferences.setMockInitialValues(<String, Object>{
            'blocked_users_list': jsonEncode([blockedPubkey]),
          });
          final prefs = await SharedPreferences.getInstance();
          stubSigningAndPublishing();
          stubMuteRead();
          final ownList = StreamController<Event>();
          addTearDown(ownList.close);
          when(
            () => mockClient.subscribe(any()),
          ).thenAnswer((_) => ownList.stream);

          final service = ContentBlocklistRepository(prefs: prefs);
          await service.syncMuteListsInBackground(mockClient, ourPubkey);
          await service.syncBlockListsInBackground(
            mockClient,
            mockSigner,
            ourPubkey,
          );
          clearInteractions(mockSigner);

          ownList.add(
            buildEvent(
              kind: 10000,
              tags: const [
                ['p', blockedPubkey],
              ],
              createdAt: 5000,
            ),
          );
          await Future<void>.delayed(Duration.zero);
          await Future<void>.delayed(Duration.zero);

          verifyNever(
            () => mockSigner.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
            ),
          );
        },
      );
    });

    group('an unblock whose publish never landed (#8263)', () {
      const target =
          '00000000000000000000000000000000000000000000000000000000000000dd';

      void stubHealthy() {
        when(() => mockSigner.isAuthenticated).thenReturn(true);
        when(
          () => mockSigner.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer(
          (invocation) async => signedEventFromInvocation(invocation),
        );
        when(() => mockClient.publishEvent(any())).thenAnswer(
          (invocation) async => PublishSuccess(
            event: invocation.positionalArguments.first as Event,
          ),
        );
      }

      void stubReadSettled() {
        when(
          () => mockClient.queryEventsDetailed(
            any(),
            requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
          ),
        ).thenAnswer(
          (_) async => (
            events: <Event>[],
            timedOut: false,
            noRelays: false,
          ),
        );
      }

      void stubReadInconclusive() {
        when(
          () => mockClient.queryEventsDetailed(
            any(),
            requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
          ),
        ).thenAnswer(
          (_) async => (events: <Event>[], timedOut: true, noRelays: false),
        );
      }

      /// Blocks [target], then unblocks it with the read inconclusive, so the
      /// unblock is recorded but never published. Returns fresh prefs holding
      /// that state, as a relaunch would find them.
      Future<SharedPreferences> prefsAfterAWithheldUnblock() async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final prefs = await SharedPreferences.getInstance();
        stubHealthy();
        final before = ContentBlocklistRepository(prefs: prefs);
        await before.syncBlockListsInBackground(
          mockClient,
          mockSigner,
          ourPubkey,
        );
        await before.blockUser(target);
        stubReadInconclusive();
        await before.unblockUser(target);
        before.dispose();
        return prefs;
      }

      test(
        'is not re-adopted as a mute from a list that predates it',
        () async {
          final prefs = await prefsAfterAWithheldUnblock();
          final ownList = StreamController<Event>.broadcast();
          addTearDown(ownList.close);
          when(
            () => mockClient.subscribe(any()),
          ).thenAnswer((_) => ownList.stream);

          final restarted = ContentBlocklistRepository(prefs: prefs);
          await restarted.syncMuteListsInBackground(mockClient, ourPubkey);
          ownList.add(
            buildEvent(
              kind: 10000,
              tags: const [
                ['p', target],
              ],
              createdAt: 1000,
            ),
          );
          await Future<void>.delayed(Duration.zero);

          expect(restarted.isMutedByUs(target), isFalse);
          expect(restarted.shouldFilterFromFeeds(target), isFalse);
        },
      );

      test('IS honoured when the list is newer than the unblock, because that '
          'is another client muting them again', () async {
        final prefs = await prefsAfterAWithheldUnblock();
        final ownList = StreamController<Event>.broadcast();
        addTearDown(ownList.close);
        when(
          () => mockClient.subscribe(any()),
        ).thenAnswer((_) => ownList.stream);

        final restarted = ContentBlocklistRepository(prefs: prefs);
        await restarted.syncMuteListsInBackground(mockClient, ourPubkey);
        ownList.add(
          buildEvent(
            kind: 10000,
            tags: const [
              ['p', target],
            ],
            // Comfortably after the unblock we just recorded.
            createdAt: 99999999999,
          ),
        );
        await Future<void>.delayed(Duration.zero);

        expect(restarted.isMutedByUs(target), isTrue);
      });

      test('is not re-adopted from a stale list in the same second', () async {
        final prefs = await prefsAfterAWithheldUnblock();
        final pending =
            jsonDecode(
                  prefs.getString('pending_unblocks.$ourPubkey')!,
                )
                as Map<String, dynamic>;
        final unblockedAt = pending[target]! as int;
        final ownList = StreamController<Event>.broadcast();
        addTearDown(ownList.close);
        when(
          () => mockClient.subscribe(any()),
        ).thenAnswer((_) => ownList.stream);

        final restarted = ContentBlocklistRepository(prefs: prefs);
        await restarted.syncMuteListsInBackground(mockClient, ourPubkey);
        ownList.add(
          buildEvent(
            kind: 10000,
            tags: const [
              ['p', target],
            ],
            createdAt: unblockedAt,
          ),
        );
        await Future<void>.delayed(Duration.zero);

        expect(restarted.isMutedByUs(target), isFalse);
      });

      test('retries an unblock after the relay rejects its publish', () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final prefs = await SharedPreferences.getInstance();
        stubHealthy();
        stubReadSettled();
        final service = ContentBlocklistRepository(prefs: prefs);
        await service.syncBlockListsInBackground(
          mockClient,
          mockSigner,
          ourPubkey,
        );
        await service.blockUser(target);
        when(
          () => mockClient.publishEvent(any()),
        ).thenThrow(Exception('relay rejected publish'));

        await service.unblockUser(target);

        stubHealthy();
        expect(await service.retryPendingMuteListPublish(), isTrue);
        expect(await service.retryPendingMuteListPublish(), isFalse);
      });

      test(
        'a restart makes a persisted unblock immediately retryable',
        () async {
          final prefs = await prefsAfterAWithheldUnblock();
          await prefs.setBool(
            'block_list_migrated_to_mute_list.$ourPubkey',
            true,
          );
          await prefs.setBool('block_list_retired.$ourPubkey', true);
          stubHealthy();
          stubReadSettled();

          final restarted = ContentBlocklistRepository(prefs: prefs);
          await restarted.syncBlockListsInBackground(
            mockClient,
            mockSigner,
            ourPubkey,
          );

          expect(await restarted.retryPendingMuteListPublish(), isTrue);
          expect(await restarted.retryPendingMuteListPublish(), isFalse);
        },
      );

      test('first identity scopes an unblock written before sync', () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final prefs = await SharedPreferences.getInstance();
        final service = ContentBlocklistRepository(prefs: prefs);
        await service.blockUser(target);
        await service.unblockUser(target);
        expect(prefs.getString('pending_unblocks'), isNotNull);
        when(() => mockSigner.isAuthenticated).thenReturn(true);

        await service.syncBlockListsInBackground(
          mockClient,
          mockSigner,
          ourPubkey,
        );
        await pumpEventQueue();

        expect(prefs.getString('pending_unblocks'), isNull);
        final pending =
            jsonDecode(
                  prefs.getString('pending_unblocks.$ourPubkey')!,
                )
                as Map<String, dynamic>;
        expect(pending, contains(target));
      });

      test('republishes so the relay drops the stale tag', () async {
        final prefs = await prefsAfterAWithheldUnblock();
        final ownList = StreamController<Event>.broadcast();
        addTearDown(ownList.close);
        when(
          () => mockClient.subscribe(any()),
        ).thenAnswer((_) => ownList.stream);
        stubHealthy();
        stubReadSettled();

        final restarted = ContentBlocklistRepository(prefs: prefs);
        await restarted.syncBlockListsInBackground(
          mockClient,
          mockSigner,
          ourPubkey,
        );
        await restarted.syncMuteListsInBackground(mockClient, ourPubkey);
        clearInteractions(mockSigner);
        ownList.add(
          buildEvent(
            kind: 10000,
            tags: const [
              ['p', target],
            ],
            createdAt: 1000,
          ),
        );
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        final tags =
            verify(
                  () => mockSigner.createAndSignEvent(
                    kind: 10000,
                    content: any(named: 'content'),
                    tags: captureAny(named: 'tags'),
                  ),
                ).captured.last
                as List<List<String>>;
        expect(tags, isNot(contains(equals(['p', target]))));
      });

      test(
        'reconciles a stale unblock and a missing block with one publish',
        () async {
          const stillBlocked =
              '00000000000000000000000000000000'
              '000000000000000000000000000000ee';
          final prefs = await prefsAfterAWithheldUnblock();
          await prefs.setString(
            'blocked_users_list.$ourPubkey',
            jsonEncode([stillBlocked]),
          );
          await prefs.setBool(
            'block_list_migrated_to_mute_list.$ourPubkey',
            true,
          );
          await prefs.setBool('block_list_retired.$ourPubkey', true);
          final ownList = StreamController<Event>.broadcast();
          addTearDown(ownList.close);
          when(
            () => mockClient.subscribe(any()),
          ).thenAnswer((_) => ownList.stream);
          stubHealthy();
          stubReadSettled();

          final restarted = ContentBlocklistRepository(prefs: prefs);
          await restarted.syncBlockListsInBackground(
            mockClient,
            mockSigner,
            ourPubkey,
          );
          await restarted.syncMuteListsInBackground(mockClient, ourPubkey);
          await pumpEventQueue();
          clearInteractions(mockSigner);

          ownList.add(
            buildEvent(
              kind: 10000,
              tags: const [
                ['p', target],
              ],
              createdAt: 1000,
            ),
          );
          await pumpEventQueue();

          verify(
            () => mockSigner.createAndSignEvent(
              kind: 10000,
              content: any(named: 'content'),
              tags: any(named: 'tags'),
            ),
          ).called(1);
        },
      );

      test('blocking again retires the intent, so a later restart has no '
          'outstanding work', () async {
        final prefs = await prefsAfterAWithheldUnblock();
        final pending =
            jsonDecode(
                  prefs.getString('pending_unblocks.$ourPubkey')!,
                )
                as Map<String, dynamic>;
        final unblockedAt = pending[target]! as int;
        stubHealthy();
        stubReadSettled();
        when(
          () => mockSigner.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer(
          (invocation) async => buildEvent(
            kind: invocation.namedArguments[#kind] as int,
            content: invocation.namedArguments[#content] as String,
            tags: invocation.namedArguments[#tags] as List<List<String>>,
            createdAt: unblockedAt,
          ),
        );

        // Re-block and publish in the same second as the unblock. The explicit
        // re-block must retire the intent because the timestamp cannot.
        final second = ContentBlocklistRepository(prefs: prefs);
        await second.syncBlockListsInBackground(
          mockClient,
          mockSigner,
          ourPubkey,
        );
        await second.blockUser(target);
        final persistedAfterReblock =
            jsonDecode(
                  prefs.getString('pending_unblocks.$ourPubkey')!,
                )
                as Map<String, dynamic>;
        expect(persistedAfterReblock, isNot(contains(target)));
        // The retire persists fire-and-forget, matching `_saveMutedUsers` in
        // the same method, so let it land before the restart reads prefs.
        await Future<void>.delayed(Duration.zero);
        second.dispose();

        // Restart, so nothing is carried in memory.
        final ownList = StreamController<Event>.broadcast();
        addTearDown(ownList.close);
        when(
          () => mockClient.subscribe(any()),
        ).thenAnswer((_) => ownList.stream);
        final restarted = ContentBlocklistRepository(prefs: prefs);
        await restarted.syncBlockListsInBackground(
          mockClient,
          mockSigner,
          ourPubkey,
        );
        await restarted.syncMuteListsInBackground(mockClient, ourPubkey);
        // The startup legacy migration publishes on its own; let it finish so
        // it is not mistaken for the reconcile republish below.
        await pumpEventQueue();
        clearInteractions(mockSigner);

        ownList.add(
          buildEvent(
            kind: 10000,
            tags: const [
              ['p', target],
            ],
            createdAt: 1000,
          ),
        );
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(restarted.isBlocked(target), isTrue);
        // Nothing outstanding: the block is already on the relay's list.
        verifyNever(
          () => mockSigner.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        );
      });

      test('a successful unblock publish leaves nothing pending', () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final prefs = await SharedPreferences.getInstance();
        stubHealthy();
        final service = ContentBlocklistRepository(prefs: prefs);
        await service.syncBlockListsInBackground(
          mockClient,
          mockSigner,
          ourPubkey,
        );
        await service.blockUser(target);
        await service.unblockUser(target);
        service.dispose();

        // A later list that still carries the tag is now an ordinary foreign
        // mute, because our unblock was confirmed.
        final ownList = StreamController<Event>.broadcast();
        addTearDown(ownList.close);
        when(
          () => mockClient.subscribe(any()),
        ).thenAnswer((_) => ownList.stream);
        final restarted = ContentBlocklistRepository(prefs: prefs);
        await restarted.syncMuteListsInBackground(mockClient, ourPubkey);
        ownList.add(
          buildEvent(
            kind: 10000,
            tags: const [
              ['p', target],
            ],
            createdAt: 1000,
          ),
        );
        await Future<void>.delayed(Duration.zero);

        expect(restarted.isMutedByUs(target), isTrue);
      });

      group('explicit unblock intent (#6438)', () {
        Future<ContentBlocklistRepository> serviceWithOwnMute({
          required SharedPreferences prefs,
          required Event ownMute,
        }) async {
          await prefs.setBool(
            'block_list_migrated_to_mute_list.$ourPubkey',
            true,
          );
          await prefs.setBool('block_list_retired.$ourPubkey', true);
          final ownList = StreamController<Event>.broadcast();
          addTearDown(ownList.close);
          when(() => mockClient.subscribe(any())).thenAnswer(
            (_) => ownList.stream,
          );
          stubHealthy();
          stubReadSettled();

          final service = ContentBlocklistRepository(prefs: prefs);
          await service.syncBlockListsInBackground(
            mockClient,
            mockSigner,
            ourPubkey,
          );
          await service.syncMuteListsInBackground(mockClient, ourPubkey);
          ownList.add(ownMute);
          await pumpEventQueue();
          clearInteractions(mockSigner);
          return service;
        }

        test(
          'removes and publishes a mute that is not a runtime block',
          () async {
            SharedPreferences.setMockInitialValues(<String, Object>{});
            final prefs = await SharedPreferences.getInstance();
            final service = await serviceWithOwnMute(
              prefs: prefs,
              ownMute: buildEvent(
                kind: 10000,
                tags: const [
                  ['p', target],
                ],
                createdAt: 1000,
              ),
            );
            final changes = <BlocklistChange>[];
            final subscription = service.changes.listen(changes.add);
            addTearDown(subscription.cancel);

            await service.unblockUser(target);

            expect(service.isMutedByUs(target), isFalse);
            expect(service.shouldFilterFromFeeds(target), isFalse);
            expect(
              changes,
              contains(
                const BlocklistChange(
                  pubkey: target,
                  op: BlocklistOp.unmutedByUs,
                ),
              ),
            );
            final tags =
                verify(
                      () => mockSigner.createAndSignEvent(
                        kind: 10000,
                        content: any(named: 'content'),
                        tags: captureAny(named: 'tags'),
                      ),
                    ).captured.last
                    as List<List<String>>;
            expect(tags, isNot(contains(equals(['p', target]))));
          },
        );

        test(
          'protects the unblock from a clock-skewed publish refresh',
          () async {
            SharedPreferences.setMockInitialValues(<String, Object>{});
            final prefs = await SharedPreferences.getInstance();
            final service = await serviceWithOwnMute(
              prefs: prefs,
              ownMute: buildEvent(
                kind: 10000,
                tags: const [
                  ['p', target],
                ],
                createdAt: 1000,
              ),
            );
            final clockSkewedList = buildEvent(
              kind: 10000,
              tags: const [
                ['p', target],
              ],
              createdAt: 99999999999,
            )..id = 'clock-skewed-event';
            when(
              () => mockClient.queryEventsDetailed(
                any(),
                requireAllRelaysSettled: any(
                  named: 'requireAllRelaysSettled',
                ),
              ),
            ).thenAnswer(
              (_) async => (
                events: [clockSkewedList],
                timedOut: false,
                noRelays: false,
              ),
            );
            when(
              () => mockClient.publishEvent(any()),
            ).thenAnswer((_) async => const PublishFailed());

            await service.unblockUser(target);

            expect(service.isMutedByUs(target), isFalse);
            final pending =
                jsonDecode(prefs.getString('pending_unblocks.$ourPubkey')!)
                    as Map<String, dynamic>;
            expect(pending[target], clockSkewedList.createdAt);
            final tags =
                verify(
                      () => mockSigner.createAndSignEvent(
                        kind: 10000,
                        content: any(named: 'content'),
                        tags: captureAny(named: 'tags'),
                      ),
                    ).captured.last
                    as List<List<String>>;
            expect(tags, isNot(contains(equals(['p', target]))));
          },
        );

        test(
          'is a true no-op when no local or published state carries it',
          () async {
            SharedPreferences.setMockInitialValues(<String, Object>{});
            final prefs = await SharedPreferences.getInstance();
            stubHealthy();
            stubReadSettled();
            final service = ContentBlocklistRepository(prefs: prefs);
            await service.syncBlockListsInBackground(
              mockClient,
              mockSigner,
              ourPubkey,
            );
            clearInteractions(mockSigner);

            await service.unblockUser(target);

            verifyNever(
              () => mockSigner.createAndSignEvent(
                kind: any(named: 'kind'),
                content: any(named: 'content'),
                tags: any(named: 'tags'),
              ),
            );
            expect(
              jsonDecode(
                prefs.getString('pending_unblocks.$ourPubkey') ?? '{}',
              ),
              isNot(contains(target)),
            );
          },
        );

        test(
          're-blocking retires contradictory pending intent and republishes',
          () async {
            SharedPreferences.setMockInitialValues(<String, Object>{
              'blocklist_active_pubkey': ourPubkey,
              'blocked_users_list.$ourPubkey': jsonEncode([target]),
              'pending_unblocks.$ourPubkey': jsonEncode({target: 1000}),
              'block_list_migrated_to_mute_list.$ourPubkey': true,
              'block_list_retired.$ourPubkey': true,
            });
            final prefs = await SharedPreferences.getInstance();
            stubHealthy();
            stubReadSettled();
            final service = ContentBlocklistRepository(prefs: prefs);
            await service.syncBlockListsInBackground(
              mockClient,
              mockSigner,
              ourPubkey,
            );
            clearInteractions(mockSigner);

            await service.blockUser(target);

            final pending =
                jsonDecode(prefs.getString('pending_unblocks.$ourPubkey')!)
                    as Map<String, dynamic>;
            expect(pending, isNot(contains(target)));
            final tags =
                verify(
                      () => mockSigner.createAndSignEvent(
                        kind: 10000,
                        content: any(named: 'content'),
                        tags: captureAny(named: 'tags'),
                      ),
                    ).captured.last
                    as List<List<String>>;
            expect(tags, contains(equals(['p', target])));
          },
        );

        test('re-blocking is a no-op when no publish is pending', () async {
          SharedPreferences.setMockInitialValues(<String, Object>{
            'blocklist_active_pubkey': ourPubkey,
            'blocked_users_list.$ourPubkey': jsonEncode([target]),
            'block_list_migrated_to_mute_list.$ourPubkey': true,
            'block_list_retired.$ourPubkey': true,
          });
          final prefs = await SharedPreferences.getInstance();
          stubHealthy();
          stubReadSettled();
          final service = ContentBlocklistRepository(prefs: prefs);
          await service.syncBlockListsInBackground(
            mockClient,
            mockSigner,
            ourPubkey,
          );
          clearInteractions(mockSigner);

          await service.blockUser(target);

          verifyNever(
            () => mockSigner.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
            ),
          );
        });
      });
    });
  });

  group('ContentBlocklistRepository - legacy block list migration', () {
    const ourPubkey =
        '0000000000000000000000000000000000000000000000000000000000000001';
    const blockA =
        '00000000000000000000000000000000000000000000000000000000000000aa';
    const blockB =
        '00000000000000000000000000000000000000000000000000000000000000bb';
    const muteC =
        '00000000000000000000000000000000000000000000000000000000000000cc';
    const flagKey = 'block_list_migrated_to_mute_list.$ourPubkey';
    const retiredKey = 'block_list_retired.$ourPubkey';

    late _MockNostrClient mockClient;
    late _MockBlockListSigner mockSigner;
    late SharedPreferences prefs;

    Event ownBlockEvent(List<String> blocked) =>
        Event(
            ourPubkey,
            30000,
            [
              const ['d', 'block'],
              for (final pk in blocked) ['p', pk],
            ],
            'Block list',
            createdAt: 1000,
          )
          ..id = 'own-block-event'
          ..sig = 'signature';

    Event ownMuteEvent(
      List<String> muted, {
      int createdAt = 2000,
      List<List<String>> extraTags = const <List<String>>[],
      String content = '',
    }) =>
        Event(
            ourPubkey,
            10000,
            [
              for (final pk in muted) ['p', pk],
              ...extraTags,
            ],
            content,
            createdAt: createdAt,
          )
          ..id = 'own-mute-event-$createdAt'
          ..sig = 'signature';

    Event signedMuteList({
      List<List<String>> tags = const <List<String>>[],
      String content = '',
    }) => Event(ourPubkey, 10000, tags, content, createdAt: 3000)
      ..id = 'signed-mute-list'
      ..sig = 'signature';

    Event signedMuteListFromInvocation(Invocation invocation) {
      return signedMuteList(
        content: invocation.namedArguments[#content] as String,
        tags: invocation.namedArguments[#tags] as List<List<String>>,
      );
    }

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      prefs = await SharedPreferences.getInstance();
      mockClient = _MockNostrClient();
      mockSigner = _MockBlockListSigner();
      when(
        () => mockClient.subscribe(any()),
      ).thenAnswer((_) => const Stream.empty());
      when(() => mockSigner.isAuthenticated).thenReturn(true);
      when(
        () => mockSigner.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer(
        (invocation) async =>
            Event(
                ourPubkey,
                invocation.namedArguments[#kind] as int,
                invocation.namedArguments[#tags] as List<List<String>>,
                invocation.namedArguments[#content] as String,
                createdAt: 3000,
              )
              ..id = 'signed-event'
              ..sig = 'signature',
      );
      when(() => mockClient.publishEvent(any())).thenAnswer(
        (invocation) async => PublishSuccess(
          event: invocation.positionalArguments.first as Event,
        ),
      );
    });

    test(
      'appends legacy kind 30000 blocks to the existing kind 10000 mute '
      'list and publishes once',
      () async {
        when(() => mockClient.queryEvents(any())).thenAnswer((
          invocation,
        ) async {
          final filters = invocation.positionalArguments[0] as List<Filter>;
          final kinds = filters.first.kinds ?? const <int>[];
          if (kinds.contains(30000)) {
            return [
              ownBlockEvent([blockA, blockB]),
            ];
          }
          if (kinds.contains(10000)) {
            return [
              ownMuteEvent([muteC]),
            ];
          }
          return <Event>[];
        });

        List<List<String>>? publishedMuteTags;
        when(
          () => mockSigner.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((invocation) async {
          final kind = invocation.namedArguments[#kind] as int;
          if (kind == 10000) {
            publishedMuteTags =
                invocation.namedArguments[#tags] as List<List<String>>?;
            return signedMuteListFromInvocation(invocation);
          }
          return signedMuteList();
        });
        when(
          () => mockClient.publishEvent(any()),
        ).thenAnswer(
          (invocation) async => PublishSuccess(
            event: invocation.positionalArguments.first as Event,
          ),
        );

        final service = ContentBlocklistRepository(prefs: prefs);
        await service.syncBlockListsInBackground(
          mockClient,
          mockSigner,
          ourPubkey,
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // The republished kind 10000 list carries the legacy blocks AND the
        // mute that already lived on the existing kind 10000 list.
        expect(publishedMuteTags, isNotNull);
        final publishedPubkeys = publishedMuteTags!
            .where((tag) => tag.length >= 2 && tag[0] == 'p')
            .map((tag) => tag[1])
            .toSet();
        expect(publishedPubkeys, containsAll(<String>{blockA, blockB, muteC}));

        expect(service.isBlocked(blockA), isTrue);
        expect(service.isBlocked(blockB), isTrue);
        expect(service.isMutedByUs(muteC), isTrue);
        expect(prefs.getBool(flagKey), isTrue);

        service.dispose();
      },
    );

    test(
      'leaves the flag unset without publishing when there is no legacy list',
      () async {
        when(
          () => mockClient.queryEvents(any()),
        ).thenAnswer((_) async => <Event>[]);

        final service = ContentBlocklistRepository(prefs: prefs);
        await service.syncBlockListsInBackground(
          mockClient,
          mockSigner,
          ourPubkey,
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));

        verifyNever(
          () => mockSigner.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        );
        expect(prefs.getBool(flagKey), isNull);

        service.dispose();
      },
    );

    test('does not run again once both flags are set', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        flagKey: true,
        retiredKey: true,
      });
      prefs = await SharedPreferences.getInstance();

      final service = ContentBlocklistRepository(prefs: prefs);
      await service.syncBlockListsInBackground(
        mockClient,
        mockSigner,
        ourPubkey,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      verifyNever(() => mockClient.queryEvents(any()));

      service.dispose();
    });

    test(
      'retires the legacy list for an account that already migrated',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          flagKey: true,
          'blocklist_active_pubkey': ourPubkey,
          'blocked_users_list.$ourPubkey': jsonEncode([blockA]),
        });
        prefs = await SharedPreferences.getInstance();

        when(() => mockClient.queryEvents(any())).thenAnswer((
          invocation,
        ) async {
          final filters = invocation.positionalArguments[0] as List<Filter>;
          final kinds = filters.first.kinds ?? const <int>[];
          if (kinds.contains(30000)) {
            return [
              ownBlockEvent([blockA]),
            ];
          }
          return <Event>[];
        });

        final service = ContentBlocklistRepository(prefs: prefs);
        await service.syncBlockListsInBackground(
          mockClient,
          mockSigner,
          ourPubkey,
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // The already-carried-over entry needs no republish of the mute list.
        verifyNever(
          () => mockSigner.createAndSignEvent(
            kind: 10000,
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        );

        final retirementTags =
            verify(
                  () => mockSigner.createAndSignEvent(
                    kind: 30000,
                    content: '',
                    tags: captureAny(named: 'tags'),
                  ),
                ).captured.single
                as List<List<String>>;
        expect(
          retirementTags,
          equals([
            ['d', 'block'],
          ]),
        );
        expect(prefs.getBool(retiredKey), isTrue);

        service.dispose();
      },
    );

    test(
      'records retirement without republishing an already-empty legacy list',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{flagKey: true});
        prefs = await SharedPreferences.getInstance();

        // Another device already emptied it; the replacement still exists.
        when(() => mockClient.queryEvents(any())).thenAnswer((
          invocation,
        ) async {
          final filters = invocation.positionalArguments[0] as List<Filter>;
          final kinds = filters.first.kinds ?? const <int>[];
          if (kinds.contains(30000)) {
            return [ownBlockEvent(const [])];
          }
          return <Event>[];
        });

        final service = ContentBlocklistRepository(prefs: prefs);
        await service.syncBlockListsInBackground(
          mockClient,
          mockSigner,
          ourPubkey,
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));

        verifyNever(
          () => mockSigner.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        );
        expect(prefs.getBool(retiredKey), isTrue);

        service.dispose();
      },
    );

    test(
      'does not empty the legacy list when the migration publish failed',
      () async {
        // The migration adds the legacy blocks to the in-memory set before
        // its publish guard and never rolls back, so runtime membership is
        // not evidence they reached a relay. Erasing on that signal would
        // leave the blocks on neither list.
        when(() => mockClient.queryEvents(any())).thenAnswer((
          invocation,
        ) async {
          final filters = invocation.positionalArguments[0] as List<Filter>;
          final kinds = filters.first.kinds ?? const <int>[];
          if (kinds.contains(30000)) {
            return [
              ownBlockEvent([blockA]),
            ];
          }
          return <Event>[];
        });
        when(
          () => mockClient.publishEvent(any()),
        ).thenAnswer((_) async => const PublishFailed());

        final service = ContentBlocklistRepository(prefs: prefs);
        await service.syncBlockListsInBackground(
          mockClient,
          mockSigner,
          ourPubkey,
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));

        verifyNever(
          () => mockSigner.createAndSignEvent(
            kind: 30000,
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        );
        expect(prefs.getBool(flagKey), isNull);
        expect(prefs.getBool(retiredKey), isNull);

        service.dispose();
      },
    );

    test(
      'persists pending-unblock retirement during an in-memory merge',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          'blocklist_active_pubkey': ourPubkey,
          'blocked_users_list.$ourPubkey': jsonEncode([blockB]),
          'pending_unblocks.$ourPubkey': jsonEncode({blockA: 1500}),
        });
        prefs = await SharedPreferences.getInstance();
        when(() => mockClient.queryEvents(any())).thenAnswer((
          invocation,
        ) async {
          final filters = invocation.positionalArguments[0] as List<Filter>;
          final kinds = filters.first.kinds ?? const <int>[];
          if (kinds.contains(30000)) {
            return [
              ownBlockEvent([blockB]),
            ];
          }
          if (kinds.contains(10000)) {
            return [ownMuteEvent(const [])];
          }
          return <Event>[];
        });
        when(
          () => mockClient.publishEvent(any()),
        ).thenAnswer((_) async => const PublishFailed());

        final service = ContentBlocklistRepository(prefs: prefs);
        await service.syncBlockListsInBackground(
          mockClient,
          mockSigner,
          ourPubkey,
        );
        await pumpEventQueue();

        final pending =
            jsonDecode(
                  prefs.getString('pending_unblocks.$ourPubkey')!,
                )
                as Map<String, dynamic>;
        expect(pending, isNot(contains(blockA)));

        service.dispose();
      },
    );

    test(
      'leaves the retired flag unset when the empty replacement is rejected',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          flagKey: true,
          'blocklist_active_pubkey': ourPubkey,
          'blocked_users_list.$ourPubkey': jsonEncode([blockA]),
        });
        prefs = await SharedPreferences.getInstance();

        when(() => mockClient.queryEvents(any())).thenAnswer((
          invocation,
        ) async {
          final filters = invocation.positionalArguments[0] as List<Filter>;
          final kinds = filters.first.kinds ?? const <int>[];
          if (kinds.contains(30000)) {
            return [
              ownBlockEvent([blockA]),
            ];
          }
          return <Event>[];
        });
        when(
          () => mockClient.publishEvent(any()),
        ).thenAnswer((_) async => const PublishFailed());

        final service = ContentBlocklistRepository(prefs: prefs);
        await service.syncBlockListsInBackground(
          mockClient,
          mockSigner,
          ourPubkey,
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));

        verify(
          () => mockSigner.createAndSignEvent(
            kind: 30000,
            content: '',
            tags: any(named: 'tags'),
          ),
        ).called(1);
        expect(prefs.getBool(retiredKey), isNull);

        service.dispose();
      },
    );

    test(
      'does not re-block a legacy entry the user unblocked after migrating',
      () async {
        // Migration confirmed on an earlier launch, its empty-30000 publish
        // did not land, and the user has since unblocked blockA. The legacy
        // list still names A; treating that as a straggler would resurrect
        // a deliberately lifted block (#7027).
        SharedPreferences.setMockInitialValues(<String, Object>{
          flagKey: true,
          'blocklist_active_pubkey': ourPubkey,
          'blocked_users_list.$ourPubkey': jsonEncode([blockB]),
        });
        prefs = await SharedPreferences.getInstance();

        when(() => mockClient.queryEvents(any())).thenAnswer((
          invocation,
        ) async {
          final filters = invocation.positionalArguments[0] as List<Filter>;
          final kinds = filters.first.kinds ?? const <int>[];
          if (kinds.contains(30000)) {
            return [
              ownBlockEvent([blockA, blockB]),
            ];
          }
          return <Event>[];
        });

        final service = ContentBlocklistRepository(prefs: prefs);
        await service.syncBlockListsInBackground(
          mockClient,
          mockSigner,
          ourPubkey,
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(service.isBlocked(blockA), isFalse);
        expect(service.isBlocked(blockB), isTrue);
        verifyNever(
          () => mockSigner.createAndSignEvent(
            kind: 10000,
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        );
        expect(prefs.getBool(retiredKey), isTrue);

        service.dispose();
      },
    );

    test('abandons retirement when the account switches mid-flight', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        flagKey: true,
        'blocklist_active_pubkey': ourPubkey,
        'blocked_users_list.$ourPubkey': jsonEncode([blockA]),
      });
      prefs = await SharedPreferences.getInstance();

      const otherPubkey =
          '0000000000000000000000000000000000000000000000000000000000000009';
      final service = ContentBlocklistRepository(prefs: prefs);

      when(() => mockClient.queryEvents(any())).thenAnswer((
        invocation,
      ) async {
        final filters = invocation.positionalArguments[0] as List<Filter>;
        final kinds = filters.first.kinds ?? const <int>[];
        if (kinds.contains(30000)) {
          // The switch lands while the legacy read is in flight.
          await service.syncMuteListsInBackground(mockClient, otherPubkey);
          return [
            ownBlockEvent([blockA]),
          ];
        }
        return <Event>[];
      });

      await service.syncBlockListsInBackground(
        mockClient,
        mockSigner,
        ourPubkey,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Nothing is published on the incoming account's behalf.
      verifyNever(
        () => mockSigner.createAndSignEvent(
          kind: 30000,
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      );
      expect(prefs.getBool(retiredKey), isNull);

      service.dispose();
    });

    test('keeps the flag unset when the republish is rejected', () async {
      when(() => mockClient.queryEvents(any())).thenAnswer((invocation) async {
        final filters = invocation.positionalArguments[0] as List<Filter>;
        final kinds = filters.first.kinds ?? const <int>[];
        if (kinds.contains(30000)) {
          return [
            ownBlockEvent([blockA]),
          ];
        }
        return <Event>[];
      });
      when(
        () => mockSigner.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((_) async => signedMuteList());
      when(
        () => mockClient.publishEvent(any()),
      ).thenAnswer((_) async => const PublishFailed());

      final service = ContentBlocklistRepository(prefs: prefs);
      await service.syncBlockListsInBackground(
        mockClient,
        mockSigner,
        ourPubkey,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Migration retries next launch, but the block is real and already
      // applied locally.
      expect(prefs.getBool(flagKey), isNull);
      expect(service.isBlocked(blockA), isTrue);

      service.dispose();
    });

    test('defers the migration when the mute-list read is inconclusive '
        '(#6750)', () async {
      when(() => mockClient.queryEvents(any())).thenAnswer((invocation) async {
        final filters = invocation.positionalArguments[0] as List<Filter>;
        final kinds = filters.first.kinds ?? const <int>[];
        if (kinds.contains(30000)) {
          return [
            ownBlockEvent([blockA]),
          ];
        }
        return <Event>[];
      });
      // The legacy kind-30000 read succeeds; only the kind-10000 read is
      // unanswered. Merging into a mute list we could not see would republish
      // over it.
      when(
        () => mockClient.queryEventsDetailed(
          any(),
          requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
        ),
      ).thenAnswer(
        (_) async => (events: <Event>[], timedOut: true, noRelays: false),
      );

      final service = ContentBlocklistRepository(prefs: prefs);
      await service.syncBlockListsInBackground(
        mockClient,
        mockSigner,
        ourPubkey,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      verifyNever(
        () => mockSigner.createAndSignEvent(
          kind: 10000,
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      );
      // Unset, so the next launch retries.
      expect(prefs.getBool(flagKey), isNull);

      // The migration's kind 10000 read must also demand all relays settle,
      // for the same reason the publish path does (#6750).
      verify(
        () => mockClient.queryEventsDetailed(
          any(),
          requireAllRelaysSettled: true,
        ),
      ).called(greaterThanOrEqualTo(1));

      service.dispose();
    });

    test(
      'merges the newest kind 10000 event when several exist',
      () async {
        const muteD =
            '00000000000000000000000000000000000000000000000000000000000000dd';
        when(() => mockClient.queryEvents(any())).thenAnswer((
          invocation,
        ) async {
          final filters = invocation.positionalArguments[0] as List<Filter>;
          final kinds = filters.first.kinds ?? const <int>[];
          if (kinds.contains(30000)) {
            return [
              ownBlockEvent([blockA]),
            ];
          }
          if (kinds.contains(10000)) {
            // Older event first, newer second: the newest one wins so only
            // its mutes survive into the republished list.
            return [
              ownMuteEvent([muteC], createdAt: 1500),
              ownMuteEvent([muteD], createdAt: 5000),
            ];
          }
          return <Event>[];
        });

        List<List<String>>? publishedMuteTags;
        when(
          () => mockSigner.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((invocation) async {
          final kind = invocation.namedArguments[#kind] as int;
          if (kind == 10000) {
            publishedMuteTags =
                invocation.namedArguments[#tags] as List<List<String>>?;
            return signedMuteListFromInvocation(invocation);
          }
          return signedMuteList();
        });
        when(
          () => mockClient.publishEvent(any()),
        ).thenAnswer(
          (invocation) async => PublishSuccess(
            event: invocation.positionalArguments.first as Event,
          ),
        );

        final service = ContentBlocklistRepository(prefs: prefs);
        await service.syncBlockListsInBackground(
          mockClient,
          mockSigner,
          ourPubkey,
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));

        final publishedPubkeys = publishedMuteTags!
            .where((tag) => tag.length >= 2 && tag[0] == 'p')
            .map((tag) => tag[1])
            .toSet();
        expect(publishedPubkeys, containsAll(<String>{blockA, muteD}));
        expect(publishedPubkeys, isNot(contains(muteC)));
        expect(service.isMutedByUs(muteD), isTrue);
        expect(service.isMutedByUs(muteC), isFalse);

        service.dispose();
      },
    );

    test(
      'migration preserves existing non-p mute tags and encrypted content',
      () async {
        when(() => mockClient.queryEvents(any())).thenAnswer((
          invocation,
        ) async {
          final filters = invocation.positionalArguments[0] as List<Filter>;
          final kinds = filters.first.kinds ?? const <int>[];
          if (kinds.contains(30000)) {
            return [
              ownBlockEvent([blockA]),
            ];
          }
          if (kinds.contains(10000)) {
            return [
              ownMuteEvent(
                [muteC],
                content: 'encrypted-private-tags',
                extraTags: const [
                  ['t', 'spoilers'],
                  ['word', 'spoiler'],
                  ['e', 'event-thread-id'],
                ],
              ),
            ];
          }
          return <Event>[];
        });

        List<List<String>>? publishedMuteTags;
        String? publishedContent;
        when(
          () => mockSigner.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((invocation) async {
          final kind = invocation.namedArguments[#kind] as int;
          if (kind == 10000) {
            publishedContent = invocation.namedArguments[#content] as String;
            publishedMuteTags =
                invocation.namedArguments[#tags] as List<List<String>>?;
            return signedMuteListFromInvocation(invocation);
          }
          return signedMuteList();
        });
        when(
          () => mockClient.publishEvent(any()),
        ).thenAnswer(
          (invocation) async => PublishSuccess(
            event: invocation.positionalArguments.first as Event,
          ),
        );

        final service = ContentBlocklistRepository(prefs: prefs);
        await service.syncBlockListsInBackground(
          mockClient,
          mockSigner,
          ourPubkey,
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(publishedContent, 'encrypted-private-tags');
        expect(publishedMuteTags, isNotNull);
        expect(publishedMuteTags, contains(equals(['p', blockA])));
        expect(publishedMuteTags, contains(equals(['p', muteC])));
        expect(publishedMuteTags, contains(equals(['t', 'spoilers'])));
        expect(publishedMuteTags, contains(equals(['word', 'spoiler'])));
        expect(publishedMuteTags, contains(equals(['e', 'event-thread-id'])));

        service.dispose();
      },
    );

    test(
      'swallows errors and leaves the flag unset on query failure',
      () async {
        when(
          () => mockClient.queryEvents(any()),
        ).thenThrow(Exception('relay unavailable'));

        final service = ContentBlocklistRepository(prefs: prefs);
        await service.syncBlockListsInBackground(
          mockClient,
          mockSigner,
          ourPubkey,
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // The failure is caught; migration retries on the next launch.
        expect(prefs.getBool(flagKey), isNull);
        verifyNever(
          () => mockSigner.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        );

        service.dispose();
      },
    );
  });

  group('ContentBlocklistRepository - sync edge cases', () {
    late _MockNostrClient mockClient1;
    late _MockNostrClient mockClient2;
    late _MockBlockListSigner mockSigner;
    const ourPubkey = 'our_pubkey';

    setUp(() {
      mockClient1 = _MockNostrClient();
      mockClient2 = _MockNostrClient();
      mockSigner = _MockBlockListSigner();
      when(
        () => mockClient1.subscribe(any()),
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => mockClient2.subscribe(any()),
      ).thenAnswer((_) => const Stream.empty());
    });

    test(
      'syncMuteListsInBackground re-subscribes when client changes',
      () async {
        final service = ContentBlocklistRepository();

        await service.syncMuteListsInBackground(mockClient1, ourPubkey);
        await service.syncMuteListsInBackground(mockClient2, ourPubkey);

        verify(() => mockClient1.subscribe(any())).called(1);
        verify(() => mockClient2.subscribe(any())).called(1);
      },
    );

    test('syncMuteListsInBackground swallows subscribe errors', () async {
      when(
        () => mockClient1.subscribe(any()),
      ).thenThrow(Exception('connection failed'));

      final service = ContentBlocklistRepository();

      await service.syncMuteListsInBackground(mockClient1, ourPubkey);

      // Sync did not mark itself as started, so a second client is allowed.
      await service.syncMuteListsInBackground(mockClient2, ourPubkey);
      verify(() => mockClient2.subscribe(any())).called(1);
    });

    test('syncBlockListsInBackground skips when already started', () async {
      final service = ContentBlocklistRepository();

      await service.syncBlockListsInBackground(
        mockClient1,
        mockSigner,
        ourPubkey,
      );
      await service.syncBlockListsInBackground(
        mockClient1,
        mockSigner,
        ourPubkey,
      );

      verify(() => mockClient1.subscribe(any())).called(1);
    });

    test(
      'syncBlockListsInBackground re-subscribes when client changes',
      () async {
        final service = ContentBlocklistRepository();

        await service.syncBlockListsInBackground(
          mockClient1,
          mockSigner,
          ourPubkey,
        );
        await service.syncBlockListsInBackground(
          mockClient2,
          mockSigner,
          ourPubkey,
        );

        verify(() => mockClient1.subscribe(any())).called(1);
        verify(() => mockClient2.subscribe(any())).called(1);
      },
    );

    test('syncBlockListsInBackground swallows subscribe errors', () async {
      when(
        () => mockClient1.subscribe(any()),
      ).thenThrow(Exception('connection failed'));

      final service = ContentBlocklistRepository();

      await service.syncBlockListsInBackground(
        mockClient1,
        mockSigner,
        ourPubkey,
      );

      // Sync is not marked as started, so a second client is allowed.
      await service.syncBlockListsInBackground(
        mockClient2,
        mockSigner,
        ourPubkey,
      );
      verify(() => mockClient2.subscribe(any())).called(1);
    });
  });

  group('ContentBlocklistRepository - event handler guards', () {
    test('_handleMuteListEvent ignores non-10000 events', () async {
      final mockClient = _MockNostrClient();
      final controller = StreamController<Event>();
      when(
        () => mockClient.subscribe(any()),
      ).thenAnswer((_) => controller.stream);

      final service = ContentBlocklistRepository();
      await service.syncMuteListsInBackground(mockClient, 'our_pubkey');

      const muterPubkey =
          '0000000000000000000000000000000000000000000000000000000000000002';
      final wrongKind =
          Event(
              muterPubkey,
              1,
              const [],
              '',
              createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            )
            ..id = 'wrong-kind-event'
            ..sig = 'signature';

      controller.add(wrongKind);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(service.hasMutedUs(muterPubkey), isFalse);

      await controller.close();
    });
  });

  group('ContentBlocklistRepository - dispose', () {
    test('dispose resets sync flags so a fresh sync can start', () async {
      final mockClient = _MockNostrClient();
      final mockSigner = _MockBlockListSigner();
      when(
        () => mockClient.subscribe(any()),
      ).thenAnswer((_) => const Stream.empty());

      final service = ContentBlocklistRepository();
      await service.syncMuteListsInBackground(mockClient, 'our_pubkey');
      await service.syncBlockListsInBackground(
        mockClient,
        mockSigner,
        'our_pubkey',
      );

      service.dispose();

      // After dispose the flags are cleared, so another sync pair
      // subscribes again on the same client.
      await service.syncMuteListsInBackground(mockClient, 'our_pubkey');
      await service.syncBlockListsInBackground(
        mockClient,
        mockSigner,
        'our_pubkey',
      );

      verify(() => mockClient.subscribe(any())).called(4);
    });
  });

  group('ContentPolicyState exposure', () {
    test('currentState reflects blocked set after blockUser', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = ContentBlocklistRepository(prefs: prefs);

      const me = 'my-hex-pubkey';
      const blockedByUs = 'blocked-hex';
      await repo.blockUser(blockedByUs, ourPubkey: me);

      final state = repo.currentState;
      expect(state.blockedPubkeys, contains(blockedByUs));
      expect(state.mutedPubkeys, isEmpty);
      expect(state.pubkeysBlockingUs, isEmpty);
      expect(state.pubkeysMutingUs, isEmpty);
    });

    test('stateStream emits a new snapshot when blocks change', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = ContentBlocklistRepository(prefs: prefs);

      const blocked = 'some-hex';
      final snapshots = <ContentPolicyState>[];
      final sub = repo.stateStream.listen(snapshots.add);

      await repo.blockUser(blocked, ourPubkey: 'me');
      await Future<void>.delayed(Duration.zero);

      expect(snapshots, hasLength(greaterThanOrEqualTo(1)));
      expect(snapshots.last.blockedPubkeys, contains(blocked));

      await sub.cancel();
    });

    test('currentState reflects persisted blocks at construction', () async {
      SharedPreferences.setMockInitialValues({
        'blocked_users_list': '["persisted-hex"]',
      });
      final prefs = await SharedPreferences.getInstance();
      final repo = ContentBlocklistRepository(prefs: prefs);

      expect(repo.currentState.blockedPubkeys, contains('persisted-hex'));
    });
  });

  group('ContentBlocklistRepository - a lifted block reaches the blockee', () {
    // Real pubkeys from the reported incident, untruncated.
    const ourPubkey =
        '613cb00feb0ecd7648a62740771cf60efaead56a0d19b2ac3d7b4f3c589e6fa3';
    const blockerPubkey =
        '9be8bd90d818407bcf574d11b1c57f104fd53f40fa767abc4a631ee2694b43a3';

    late _FilterAwareRelay relay;
    late _MockNostrClient mockNostrService;
    late _MockBlockListSigner mockSigner;
    late ContentBlocklistRepository service;

    setUp(() {
      relay = _FilterAwareRelay();
      mockNostrService = _MockNostrClient();
      mockSigner = _MockBlockListSigner();

      when(
        () => mockNostrService.subscribe(
          any(),
          subscriptionId: any(named: 'subscriptionId'),
        ),
      ).thenAnswer(
        (invocation) => relay.subscribe(
          invocation.positionalArguments.first as List<Filter>,
        ),
      );
      when(() => mockNostrService.unsubscribe(any())).thenAnswer((_) async {});

      service = ContentBlocklistRepository();
    });

    tearDown(() async {
      await relay.close();
    });

    Event listEvent(
      int kind,
      List<List<String>> tags, {
      required int createdAt,
      required String id,
      String author = blockerPubkey,
    }) => Event(author, kind, tags, '', createdAt: createdAt)
      ..id = id
      ..sig = 'signature';

    test(
      'a refused by-author watch does not become an uncaught error',
      () async {
        // The by-author watch is a long-lived REQ. A relay that runs out of
        // subscription slots ends it with CLOSED, which reaches the stream as
        // an error; without an onError handler it escapes to the zone.
        when(
          () => mockNostrService.subscribe(
            any(),
            subscriptionId: any(
              named: 'subscriptionId',
              that: contains('author-watch'),
            ),
          ),
        ).thenAnswer(
          (_) => Stream<Event>.error(
            const RelaySubscriptionRefusedException(
              'error: too many subscriptions',
            ),
          ),
        );

        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        relay.publish(
          listEvent(
            30000,
            [
              ['d', 'block'],
              ['p', ourPubkey],
            ],
            createdAt: now,
            id: 'block-event',
          ),
        );

        await service.syncBlockListsInBackground(
          mockNostrService,
          mockSigner,
          ourPubkey,
        );
        await pumpEventQueue();

        expect(service.hasBlockedUs(blockerPubkey), isTrue);
      },
    );

    test(
      'hasBlockedUs clears when the blocker republishes a kind-30000 list '
      'that no longer tags us',
      () async {
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

        relay.publish(
          listEvent(
            30000,
            [
              ['d', 'block'],
              ['p', ourPubkey],
            ],
            createdAt: now,
            id: 'block-event',
          ),
        );

        await service.syncBlockListsInBackground(
          mockNostrService,
          mockSigner,
          ourPubkey,
        );
        await pumpEventQueue();
        expect(service.hasBlockedUs(blockerPubkey), isTrue);

        // The unblock replaces the list with one that has no 'p' tag at all,
        // so it can never match the `#p = us` discovery filter. Only a
        // by-author watch can deliver it.
        relay.publish(
          listEvent(
            30000,
            [
              ['d', 'block'],
              ['title', 'Block List'],
            ],
            createdAt: now + 60,
            id: 'unblock-event',
          ),
        );
        await pumpEventQueue();

        expect(service.hasBlockedUs(blockerPubkey), isFalse);
        expect(service.shouldFilterFromFeeds(blockerPubkey), isFalse);
      },
    );

    test(
      "the blocker's DM conversation stays visible throughout, because a "
      "third party cannot hide the viewer's own thread (#7345)",
      () async {
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final conversations = [
          DmConversation(
            id: 'conv-with-blocker',
            participantPubkeys: const [ourPubkey, blockerPubkey],
            isGroup: false,
            createdAt: now,
          ),
        ];

        relay.publish(
          listEvent(
            30000,
            [
              ['d', 'block'],
              ['p', ourPubkey],
            ],
            createdAt: now,
            id: 'block-event',
          ),
        );
        await service.syncBlockListsInBackground(
          mockNostrService,
          mockSigner,
          ourPubkey,
        );
        await pumpEventQueue();

        // Precondition: the block really did land, so the assertion below
        // cannot pass just because the bucket stayed empty.
        expect(service.hasBlockedUs(blockerPubkey), isTrue);
        expect(
          service.shouldFilterFromFeeds(blockerPubkey),
          isTrue,
          reason: 'feeds still honour a third-party block',
        );

        expect(
          service.filterBlockedConversations(
            conversations,
            userPubkey: ourPubkey,
          ),
          hasLength(1),
          reason:
              "being blocked must not remove the viewer's own copy of a "
              'thread they already received',
        );

        relay.publish(
          listEvent(
            30000,
            [
              ['d', 'block'],
            ],
            createdAt: now + 60,
            id: 'unblock-event',
          ),
        );
        await pumpEventQueue();

        expect(service.hasBlockedUs(blockerPubkey), isFalse);
        expect(
          service.filterBlockedConversations(
            conversations,
            userPubkey: ourPubkey,
          ),
          hasLength(1),
          reason: 'and the lift does not change the DM surface either',
        );
      },
    );

    test(
      'hasMutedUs clears when the muter republishes a kind-10000 list that '
      'no longer tags us',
      () async {
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

        relay.publish(
          listEvent(
            10000,
            [
              ['p', ourPubkey],
            ],
            createdAt: now,
            id: 'mute-event',
          ),
        );

        await service.syncMuteListsInBackground(mockNostrService, ourPubkey);
        await pumpEventQueue();
        expect(service.hasMutedUs(blockerPubkey), isTrue);

        relay.publish(
          listEvent(10000, [], createdAt: now + 60, id: 'unmute-event'),
        );
        await pumpEventQueue();

        expect(service.hasMutedUs(blockerPubkey), isFalse);
        expect(service.shouldFilterFromFeeds(blockerPubkey), isFalse);
      },
    );

    test(
      'a stale older list event does not resurrect a lifted block',
      () async {
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

        relay.publish(
          listEvent(
            30000,
            [
              ['d', 'block'],
              ['p', ourPubkey],
            ],
            createdAt: now,
            id: 'block-event',
          ),
        );
        await service.syncBlockListsInBackground(
          mockNostrService,
          mockSigner,
          ourPubkey,
        );
        await pumpEventQueue();

        relay.publish(
          listEvent(
            30000,
            [
              ['d', 'block'],
            ],
            createdAt: now + 60,
            id: 'unblock-event',
          ),
        );
        await pumpEventQueue();
        expect(service.hasBlockedUs(blockerPubkey), isFalse);

        // A second relay replaying the superseded block must not win.
        relay.publish(
          listEvent(
            30000,
            [
              ['d', 'block'],
              ['p', ourPubkey],
            ],
            createdAt: now - 30,
            id: 'stale-block-event',
          ),
        );
        await pumpEventQueue();

        expect(service.hasBlockedUs(blockerPubkey), isFalse);
      },
    );

    test(
      'recovers on a cold start when the relay serves a superseded block '
      'list to the #p filter',
      () async {
        // Reproduces relay.divine.video as measured: both versions of
        // (author, kind 30000, d=block) stay stored, so the #p discovery
        // filter keeps returning the last version that still tagged us
        // while the author filter returns the current, empty one.
        final staleRelay = _FilterAwareRelay(retainSuperseded: true);
        addTearDown(staleRelay.close);

        final staleClient = _MockNostrClient();
        when(
          () => staleClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
          ),
        ).thenAnswer(
          (invocation) => staleRelay.subscribe(
            invocation.positionalArguments.first as List<Filter>,
          ),
        );
        when(() => staleClient.unsubscribe(any())).thenAnswer((_) async {});

        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        staleRelay
          ..publish(
            listEvent(
              30000,
              [
                ['d', 'block'],
                ['p', ourPubkey],
              ],
              createdAt: now,
              id: 'block-event',
            ),
          )
          // The unblock supersedes it, but the old row is retained.
          ..publish(
            listEvent(
              30000,
              [
                ['d', 'block'],
                ['title', 'Block List'],
              ],
              createdAt: now + 600,
              id: 'unblock-event',
            ),
          );

        // Cold start: nothing in memory, everything re-derived from relay.
        final coldService = ContentBlocklistRepository();
        await coldService.syncBlockListsInBackground(
          staleClient,
          mockSigner,
          ourPubkey,
        );
        await pumpEventQueue();

        expect(
          coldService.hasBlockedUs(blockerPubkey),
          isFalse,
          reason:
              'the by-author watch must correct the stale #p delivery, or '
              'the blockee stays blocked forever across restarts',
        );
        expect(coldService.shouldFilterFromFeeds(blockerPubkey), isFalse);
      },
    );

    test('the by-author watch follows a recreated NostrClient', () async {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      relay.publish(
        listEvent(
          30000,
          [
            ['d', 'block'],
            ['p', ourPubkey],
          ],
          createdAt: now,
          id: 'block-event',
        ),
      );
      // Start both syncs the way blocklistSyncBridge does. Mute sync runs
      // first and neither body awaits, so a per-path client check is the
      // only thing that can still see the swap on the block side.
      await Future.wait([
        service.syncMuteListsInBackground(mockNostrService, ourPubkey),
        service.syncBlockListsInBackground(
          mockNostrService,
          mockSigner,
          ourPubkey,
        ),
      ]);
      await pumpEventQueue();
      expect(service.hasBlockedUs(blockerPubkey), isTrue);

      // The app recreates the NostrClient on auth flips and reconnects, so
      // the existing watch is left holding a disposed client.
      final newRelay = _FilterAwareRelay();
      addTearDown(newRelay.close);
      final newClient = _MockNostrClient();
      when(
        () => newClient.subscribe(
          any(),
          subscriptionId: any(named: 'subscriptionId'),
        ),
      ).thenAnswer(
        (invocation) => newRelay.subscribe(
          invocation.positionalArguments.first as List<Filter>,
        ),
      );
      when(() => newClient.unsubscribe(any())).thenAnswer((_) async {});

      await Future.wait([
        service.syncMuteListsInBackground(newClient, ourPubkey),
        service.syncBlockListsInBackground(newClient, mockSigner, ourPubkey),
      ]);
      await pumpEventQueue();

      // The watch on the old client is released rather than leaked.
      verify(() => mockNostrService.unsubscribe(any())).called(1);

      // Only the new relay carries the unblock, so it can arrive solely
      // through a watch that followed the client swap.
      newRelay.publish(
        listEvent(
          30000,
          [
            ['d', 'block'],
          ],
          createdAt: now + 60,
          id: 'unblock-event',
        ),
      );
      await pumpEventQueue();

      expect(service.hasBlockedUs(blockerPubkey), isFalse);
    });

    test('a burst of discovered blockers opens a single watch', () async {
      const otherBlockerPubkey =
          '7f2a4c6e8b0d1f3a5c7e9b1d3f5a7c9e1b3d5f7a9c1e3b5d7f9a1c3e5b7d9f1a';
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      // Both arrive in the same replay, as they do on a cold start.
      for (final (author, id) in [
        (blockerPubkey, 'block-event'),
        (otherBlockerPubkey, 'other-block-event'),
      ]) {
        relay.publish(
          listEvent(
            30000,
            [
              ['d', 'block'],
              ['p', ourPubkey],
            ],
            createdAt: now,
            id: id,
            author: author,
          ),
        );
      }

      await service.syncBlockListsInBackground(
        mockNostrService,
        mockSigner,
        ourPubkey,
      );
      await pumpEventQueue();

      expect(service.hasBlockedUs(blockerPubkey), isTrue);
      expect(service.hasBlockedUs(otherBlockerPubkey), isTrue);

      // The discovery subscription filters on #p; the by-author watch is the
      // one that filters on authors.
      final watchRequests =
          verify(
                () => mockNostrService.subscribe(
                  captureAny(),
                  subscriptionId: any(named: 'subscriptionId'),
                ),
              ).captured
              .cast<List<Filter>>()
              .where(
                (filters) => filters.every((filter) => filter.authors != null),
              )
              .toList();

      expect(
        watchRequests,
        hasLength(1),
        reason: 'both blockers must land in one REQ, not one each',
      );
      expect(
        watchRequests.single.single.authors,
        containsAll([blockerPubkey, otherBlockerPubkey]),
      );
    });
  });
}

/// A relay stub that honours filters: a subscription only ever receives
/// events it actually matches.
///
/// This is the whole point of the group above. A stub that pipes every
/// event into every listener cannot see the defect being guarded — the
/// production filter is `#p = <us>`, and a lifted block publishes a list
/// with no `p` tag, so the update stops matching. With [retainSuperseded]
/// the stub goes further and reproduces what the deployed relay actually
/// does: it keeps re-serving the last version that *did* carry the tag.
class _FilterAwareRelay {
  /// [retainSuperseded] reproduces the behaviour observed on
  /// relay.divine.video: superseded versions of a replaceable/addressable
  /// event stay stored, and "latest wins" is resolved *after* the filter
  /// predicate. A tag query therefore returns the newest version that still
  /// carries the tag — which, for a lifted block, is the stale one. NIP-01
  /// says a relay should not do this, but the deployed relay does, so the
  /// fix has to survive it.
  _FilterAwareRelay({this.retainSuperseded = false});

  final bool retainSuperseded;

  final List<({List<Filter> filters, StreamController<Event> controller})>
  _subscriptions = [];
  final List<Event> _stored = [];

  Stream<Event> subscribe(List<Filter> filters) {
    final controller = StreamController<Event>.broadcast();
    _subscriptions.add((filters: filters, controller: controller));
    // Relays replay stored matches on REQ. Deliver them asynchronously:
    // the caller attaches its listener after this returns, and a broadcast
    // controller discards anything added while it has no subscribers.
    final replay = _newestPerCoordinate(
      _stored.where((e) => _matchesAny(filters, e)),
    );
    scheduleMicrotask(() {
      for (final event in replay) {
        if (!controller.isClosed) controller.add(event);
      }
    });
    return controller.stream;
  }

  /// Stores [event] and fans it out to every matching subscription.
  ///
  /// Unless [retainSuperseded] is set, prior versions of the same
  /// (author, kind) are dropped. Every test here uses a single `d` value
  /// per kind, so that stands in for NIP-01's per-(author, kind, d)
  /// replacement rule without needing the finer key.
  void publish(Event event) {
    if (!retainSuperseded) {
      _stored.removeWhere(
        (e) => e.pubkey == event.pubkey && e.kind == event.kind,
      );
    }
    _stored.add(event);
    for (final subscription in _subscriptions) {
      if (_matchesAny(subscription.filters, event) &&
          !subscription.controller.isClosed) {
        subscription.controller.add(event);
      }
    }
  }

  Future<void> close() async {
    for (final subscription in _subscriptions) {
      await subscription.controller.close();
    }
    _subscriptions.clear();
  }

  /// Collapses [events] to the newest version per (author, kind, d-tag).
  ///
  /// Applied *after* the filter predicate, which is precisely how the
  /// deployed relay resolves replaceable events — and why a `#p` query can
  /// surface a superseded list.
  static List<Event> _newestPerCoordinate(Iterable<Event> events) {
    final newest = <String, Event>{};
    for (final event in events) {
      var dTag = '';
      for (final tag in event.tags) {
        if (tag.length >= 2 && tag[0] == 'd') {
          dTag = tag[1];
          break;
        }
      }
      final coordinate = '${event.pubkey}:${event.kind}:$dTag';
      final current = newest[coordinate];
      if (current == null || event.createdAt > current.createdAt) {
        newest[coordinate] = event;
      }
    }
    return newest.values.toList();
  }

  static bool _matchesAny(List<Filter> filters, Event event) =>
      filters.any((filter) => filter.checkEvent(event));
}
