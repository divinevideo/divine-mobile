import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/services/content_blocklist_service.dart';
import 'package:openvine/services/nostr_service_interface.dart';

import 'content_blocklist_service_test.mocks.dart';

@GenerateMocks([INostrService])
void main() {
  group('ContentBlocklistService', () {
    late ContentBlocklistService service;

    setUp(() {
      service = ContentBlocklistService();
    });

    test('should initialize with blocked accounts', () {
      expect(service.totalBlockedCount, greaterThan(0));
    });

    test('should block specified npubs', () {
      // The service should have blocked the specified users (3 npubs)
      expect(service.totalBlockedCount, equals(3));

      // Verify the specific hex keys are blocked (correct values from bech32 decoding)
      const expectedHex1 =
          '7444faae22d4d4939c815819dca3c4822c209758bf86afc66365db5f79f67ddb';
      const expectedHex2 =
          '2df7fab5ab8eb77572b1a64221b68056cefbccd16fa370d33a5fbeade3debe5f';
      const expectedHex3 =
          '5943c88f3c60cd9edb125a668e2911ad419fc04e94549ed96a721901dd958372';

      expect(service.isBlocked(expectedHex1), isTrue);
      expect(service.isBlocked(expectedHex2), isTrue);
      expect(service.isBlocked(expectedHex3), isTrue);
    });

    test('should filter blocked content from feeds', () {
      const blockedPubkey =
          '7444faae22d4d4939c815819dca3c4822c209758bf86afc66365db5f79f67ddb';
      const allowedPubkey = 'allowed_user_pubkey';

      expect(service.shouldFilterFromFeeds(blockedPubkey), isTrue);
      expect(service.shouldFilterFromFeeds(allowedPubkey), isFalse);
    });

    test('should allow runtime blocking and unblocking', () {
      const testPubkey = 'test_pubkey_for_runtime_blocking';

      // Initially not blocked
      expect(service.isBlocked(testPubkey), isFalse);

      // Block user
      service.blockUser(testPubkey);
      expect(service.isBlocked(testPubkey), isTrue);

      // Unblock user
      service.unblockUser(testPubkey);
      expect(service.isBlocked(testPubkey), isFalse);
    });

    test('should filter content list correctly', () {
      final testItems = [
        {
          'pubkey':
              '7444faae22d4d4939c815819dca3c4822c209758bf86afc66365db5f79f67ddb',
          'content': 'blocked',
        },
        {'pubkey': 'allowed_user', 'content': 'allowed'},
        {
          'pubkey':
              '2df7fab5ab8eb77572b1a64221b68056cefbccd16fa370d33a5fbeade3debe5f',
          'content': 'blocked2',
        },
      ];

      final filtered = service.filterContent(
        testItems,
        (item) => item['pubkey'] as String,
      );

      expect(filtered.length, equals(1));
      expect(filtered.first['content'], equals('allowed'));
    });

    test('should provide blocking stats', () {
      final stats = service.blockingStats;

      expect(stats['total_blocks'], isA<int>());
      expect(stats['runtime_blocks'], isA<int>());
      expect(stats['internal_blocks'], isA<int>());
    });
  });

  group('ContentBlocklistService - Mutual Mute Sync', () {
    late ContentBlocklistService service;
    late MockINostrService mockNostrService;

    setUp(() {
      service = ContentBlocklistService();
      mockNostrService = MockINostrService();
    });

    test(
      'syncMuteListsInBackground subscribes to kind 10000 with our pubkey',
      () async {
        const ourPubkey = 'test_our_pubkey_hex';

        when(
          mockNostrService.subscribeToEvents(filters: anyNamed('filters')),
        ).thenAnswer((_) => Stream.empty());

        await service.syncMuteListsInBackground(mockNostrService, ourPubkey);

        // Verify subscribeToEvents was called
        final captured = verify(
          mockNostrService.subscribeToEvents(
            filters: captureAnyNamed('filters'),
          ),
        ).captured;

        expect(captured.length, equals(1));
        final filters = captured[0] as List;
        expect(filters.length, equals(1));

        final filter = filters[0];
        expect(filter.kinds, contains(10000));
        expect(filter.p, contains(ourPubkey));
      },
    );

    test('syncMuteListsInBackground only subscribes once', () async {
      const ourPubkey = 'test_our_pubkey_hex';

      when(
        mockNostrService.subscribeToEvents(filters: anyNamed('filters')),
      ).thenAnswer((_) => Stream.empty());

      await service.syncMuteListsInBackground(mockNostrService, ourPubkey);
      await service.syncMuteListsInBackground(mockNostrService, ourPubkey);
      await service.syncMuteListsInBackground(mockNostrService, ourPubkey);

      // Should only subscribe once
      verify(
        mockNostrService.subscribeToEvents(filters: anyNamed('filters')),
      ).called(1);
    });

    test(
      'handleMuteListEvent adds muter to blocklist when our pubkey is in tags',
      () async {
        const ourPubkey =
            '0000000000000000000000000000000000000000000000000000000000000001';
        const muterPubkey =
            '0000000000000000000000000000000000000000000000000000000000000002';

        // Create a kind 10000 event with our pubkey in the 'p' tags
        final event = Event(
          muterPubkey,
          10000,
          [
            ['p', ourPubkey],
            ['p', 'some_other_pubkey'],
          ],
          '',
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        );
        event.id = 'event-id';
        event.sig = 'signature';

        when(
          mockNostrService.subscribeToEvents(filters: anyNamed('filters')),
        ).thenAnswer((_) => Stream.fromIterable([event]));

        await service.syncMuteListsInBackground(mockNostrService, ourPubkey);

        // Give the stream time to emit
        await Future.delayed(const Duration(milliseconds: 100));

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
        final muteEvent = Event(
          muterPubkey,
          10000,
          [
            ['p', ourPubkey],
          ],
          '',
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        );
        muteEvent.id = 'event-id-1';
        muteEvent.sig = 'signature';

        // Second event: muter removes us from their list (replaceable event)
        final unmuteEvent = Event(
          muterPubkey,
          10000,
          [
            ['p', 'some_other_pubkey'], // Our pubkey is gone
          ],
          '',
          createdAt: (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 60,
        );
        unmuteEvent.id = 'event-id-2';
        unmuteEvent.sig = 'signature';

        // Create a stream controller to manually emit events
        final controller = StreamController<Event>();

        when(
          mockNostrService.subscribeToEvents(filters: anyNamed('filters')),
        ).thenAnswer((_) => controller.stream);

        await service.syncMuteListsInBackground(mockNostrService, ourPubkey);

        // First event - adds to blocklist
        controller.add(muteEvent);
        await Future.delayed(const Duration(milliseconds: 50));
        expect(service.shouldFilterFromFeeds(muterPubkey), isTrue);

        // Second event - removes from blocklist
        controller.add(unmuteEvent);
        await Future.delayed(const Duration(milliseconds: 50));
        expect(service.shouldFilterFromFeeds(muterPubkey), isFalse);

        controller.close();
      },
    );

    test('shouldFilterFromFeeds checks mutual mute blocklist', () async {
      const ourPubkey =
          '0000000000000000000000000000000000000000000000000000000000000001';
      const muterPubkey =
          '0000000000000000000000000000000000000000000000000000000000000002';
      const randomPubkey =
          '0000000000000000000000000000000000000000000000000000000000000003';

      final event = Event(
        muterPubkey,
        10000,
        [
          ['p', ourPubkey],
        ],
        '',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      event.id = 'event-id';
      event.sig = 'signature';

      when(
        mockNostrService.subscribeToEvents(filters: anyNamed('filters')),
      ).thenAnswer((_) => Stream.fromIterable([event]));

      await service.syncMuteListsInBackground(mockNostrService, ourPubkey);

      // Give the stream time to emit
      await Future.delayed(const Duration(milliseconds: 100));

      // Mutual muter should be filtered
      expect(service.shouldFilterFromFeeds(muterPubkey), isTrue);

      // Random user should not be filtered
      expect(service.shouldFilterFromFeeds(randomPubkey), isFalse);
    });
  });
}
