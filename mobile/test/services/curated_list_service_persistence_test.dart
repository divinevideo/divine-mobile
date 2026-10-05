// ABOUTME: Unit tests for CuratedListService persistence operations
// ABOUTME: Tests SharedPreferences save/load functionality

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:nostr_sdk/relay/publish_outcome.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/services/curated_lists/curated_list_recovery_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/curated_list_publish_stubs.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockAuthService extends Mock implements AuthService {}

void main() {
  group('CuratedListService - Persistence', () {
    late _MockNostrClient mockNostr;
    late _MockAuthService mockAuth;
    late SharedPreferences prefs;

    setUpAll(() {
      registerFallbackValue(
        Event.fromJson({
          'id': 'fallback_event_id',
          'pubkey': 'aabbccdd00112233445566778899aabbccdd00112233445566778899aabbccdd',
          'created_at': 0,
          'kind': 1,
          'tags': <List<String>>[],
          'content': '',
          'sig': '',
        }),
      );
      registerFallbackValue(<Filter>[]);
    });

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      mockNostr = _MockNostrClient();
      stubListSigner(
        mockNostr,
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
      );
      mockAuth = _MockAuthService();
      prefs = await SharedPreferences.getInstance();

      when(() => mockAuth.isAuthenticated).thenReturn(true);
      when(
        () => mockAuth.currentPublicKeyHex,
      ).thenReturn(
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
      );

      when(() => mockNostr.publishEvent(any())).thenAnswer((invocation) async {
        return PublishSuccess(
          event: invocation.positionalArguments[0] as Event,
        );
      });
      when(() => mockNostr.publishEventAwaitOk(any())).thenAnswer((
        invocation,
      ) async {
        final event = invocation.positionalArguments[0] as Event;
        return PublishOutcome(
          eventId: event.id,
          acceptedBy: const ['wss://relay.test'],
          rejectedBy: const {},
          noResponseFrom: const [],
        );
      });

      when(
        () => mockNostr.subscribe(
          any(),
          closeOnEose: true,
          onEose: any(named: 'onEose'),
        ),
      ).thenAnswer((_) => const Stream.empty());

      when(
        () => mockAuth.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
          createdAt: any(named: 'createdAt'),
        ),
      ).thenAnswer(
        (invocation) async => Event(
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
          invocation.namedArguments[#kind] as int,
          invocation.namedArguments[#tags] as List<List<String>>,
          invocation.namedArguments[#content] as String,
          createdAt: invocation.namedArguments[#createdAt] as int?,
        ),
      );
    });

    test(
      'publication fixture reaches confirmed relay with the signed revision',
      () async {
        final publicationService = CuratedListService(
          nostrService: mockNostr,
          authService: mockAuth,
          prefs: prefs,
        );
        addTearDown(publicationService.dispose);
        final created = await publicationService.createList(name: 'Fixture');
        final event =
            verify(
                  () => mockNostr.publishEventAwaitOk(captureAny()),
                ).captured.single
                as Event;
        expect(created!.nostrEventId, event.id);
        expect(event.kind, 30005);
        expect(event.tags, contains(equals(['title', 'Fixture'])));
        expect(event.createdAt, greaterThan(0));
      },
    );

    group('Save to Preferences', () {
      test('saves list to SharedPreferences after creation', () async {
        final service = CuratedListService(
          nostrService: mockNostr,
          authService: mockAuth,
          prefs: prefs,
        );

        await service.createList(name: 'Test List');

        final savedData = prefs.getString(CuratedListService.listsStorageKey);
        expect(savedData, isNotNull);
        expect(savedData, contains('Test List'));
      });

      test('saves multiple lists to SharedPreferences', () async {
        final service = CuratedListService(
          nostrService: mockNostr,
          authService: mockAuth,
          prefs: prefs,
        );

        await service.createList(name: 'List 1');
        await service.createList(name: 'List 2');
        await service.createList(name: 'List 3');

        final savedData = prefs.getString(CuratedListService.listsStorageKey);
        expect(savedData, contains('List 1'));
        expect(savedData, contains('List 2'));
        expect(savedData, contains('List 3'));
      });

      test('updates SharedPreferences after list modification', () async {
        final service = CuratedListService(
          nostrService: mockNostr,
          authService: mockAuth,
          prefs: prefs,
        );

        final list = await service.createList(name: 'Original Name');
        await service.updateList(listId: list!.id, name: 'Updated Name');

        final savedData = prefs.getString(CuratedListService.listsStorageKey);
        expect(savedData, contains('Updated Name'));
        expect(savedData, isNot(contains('Original Name')));
      });

      test('updates SharedPreferences after video added', () async {
        final service = CuratedListService(
          nostrService: mockNostr,
          authService: mockAuth,
          prefs: prefs,
        );

        final list = await service.createList(name: 'Test List');
        await service.addVideoToList(list!.id, 'video_123');

        final savedData = prefs.getString(CuratedListService.listsStorageKey);
        expect(savedData, contains('video_123'));
      });

      test('updates SharedPreferences after list deletion', () async {
        final service = CuratedListService(
          nostrService: mockNostr,
          authService: mockAuth,
          prefs: prefs,
        );

        final list = await service.createList(name: 'To Delete');
        await service.deleteOwnedList(list!.id);

        final savedData = prefs.getString(CuratedListService.listsStorageKey);
        expect(savedData, isNot(contains('To Delete')));
      });

      test('saves subscribed list ids to SharedPreferences', () async {
        final service = CuratedListService(
          nostrService: mockNostr,
          authService: mockAuth,
          prefs: prefs,
        );

        final list = await service.createList(name: 'Test List');
        await service.subscribeToList(list!.id);

        final savedData = prefs.getString(
          CuratedListService.subscribedListsStorageKey,
        );
        expect(savedData, contains(list.id));
      });

      test('saves all list fields to SharedPreferences', () async {
        final service = CuratedListService(
          nostrService: mockNostr,
          authService: mockAuth,
          prefs: prefs,
        );

        await service.createList(
          name: 'Full List',
          description: 'Test description',
          imageUrl: 'https://example.com/image.jpg',
          tags: ['tag1', 'tag2'],
          playOrder: PlayOrder.shuffle,
        );

        final savedData = prefs.getString(CuratedListService.listsStorageKey);
        expect(savedData, contains('Full List'));
        expect(savedData, contains('Test description'));
        expect(savedData, contains('https://example.com/image.jpg'));
        expect(savedData, contains('tag1'));
        expect(savedData, contains('shuffle'));
      });

      test('preserves corrupted data and blocks replacement writes', () async {
        const corrupted = 'invalid json {{{';
        await prefs.setString(
          CuratedListService.listsStorageKey,
          corrupted,
        );
        final service = CuratedListService(
          nostrService: mockNostr,
          authService: mockAuth,
          prefs: prefs,
        );

        addTearDown(service.dispose);
        expect(service.recoveryNeedsRepair, isTrue);
        expect(service.isReadyForMutations, isFalse);
        expect(await service.createList(name: 'After Corruption'), isNull);
        expect(prefs.get(CuratedListService.listsStorageKey), corrupted);
        verifyNever(() => mockNostr.publishEventAwaitOk(any()));
        verifyNever(() => mockNostr.publishEvent(any()));
        await service.initialize();
        expect(service.isInitialized, isTrue);
        expect(service.initializationError, isNull);
        expect(service.isReadyForMutations, isFalse);
        await prefs.reload();

        final recreated = CuratedListService(
          nostrService: mockNostr,
          authService: mockAuth,
          prefs: prefs,
        );
        addTearDown(recreated.dispose);
        expect(recreated.lists, isEmpty);
        expect(recreated.recoveryNeedsRepair, isTrue);
        expect(await recreated.createList(name: 'After Restart'), isNull);
        expect(prefs.get(CuratedListService.listsStorageKey), '[]');
        final archive = jsonDecode(
          prefs.getString(
            CuratedListRecoveryStorage.sharedQuarantineKey,
          )!,
        ) as Map<String, dynamic>;
        expect(archive['rawBuckets'], [corrupted]);
      });

      test('preserves all raw rows until the bad row is repaired', () async {
        final original = CuratedListService(
          nostrService: mockNostr,
          authService: mockAuth,
          prefs: prefs,
        );
        addTearDown(original.dispose);
        final accepted = await original.createList(name: 'Kept');
        expect(accepted?.nostrEventId, isNotNull);
        final rows = jsonDecode(
          prefs.getString(CuratedListService.listsStorageKey)!,
        ) as List<dynamic>;
        final corrupted = jsonEncode([...rows, 'not a row']);
        await prefs.setString(
          CuratedListService.listsStorageKey,
          corrupted,
        );
        clearInteractions(mockNostr);
        final service = CuratedListService(
          nostrService: mockNostr,
          authService: mockAuth,
          prefs: prefs,
        );
        addTearDown(service.dispose);
        expect(service.lists, isEmpty);
        expect(service.recoveryNeedsRepair, isTrue);
        expect(service.isReadyForMutations, isFalse);
        expect(await service.createList(name: 'Added'), isNull);
        expect(prefs.get(CuratedListService.listsStorageKey), corrupted);
        verifyNever(() => mockNostr.publishEventAwaitOk(any()));
        verifyNever(() => mockNostr.publishEvent(any()));
        await prefs.reload();

        final recreated = CuratedListService(
          nostrService: mockNostr,
          authService: mockAuth,
          prefs: prefs,
        );
        addTearDown(recreated.dispose);
        expect(recreated.lists, isEmpty);
        expect(recreated.recoveryNeedsRepair, isTrue);
        expect(await recreated.createList(name: 'After Restart'), isNull);
        expect(prefs.get(CuratedListService.listsStorageKey), corrupted);

        // Supply the original known-good rows explicitly; the service must
        // not guess how to discard corrupt private recovery evidence itself.
        await prefs.setString(
          CuratedListService.listsStorageKey,
          jsonEncode(rows),
        );
        final repaired = CuratedListService(
          nostrService: mockNostr,
          authService: mockAuth,
          prefs: prefs,
        );
        addTearDown(repaired.dispose);
        expect(repaired.recoveryNeedsRepair, isFalse);
        expect(repaired.lists.map((list) => list.name), ['Kept']);
        expect(await repaired.createList(name: 'Added'), isNotNull);
        expect(
          repaired.lists.map((list) => list.name),
          unorderedEquals(['Kept', 'Added']),
        );
      });

      test(
        'keeps the lists after a row it cannot decode instead of deleting them',
        () async {
          final original = CuratedListService(
            nostrService: mockNostr,
            authService: mockAuth,
            prefs: prefs,
          );
          await original.createList(name: 'Kept');
          await original.createList(name: 'Later');
          addTearDown(original.dispose);
          final rows = jsonDecode(
            prefs.getString(CuratedListService.listsStorageKey)!,
          ) as List<dynamic>;
          // A map from another build or schema that the model cannot parse.
          final undecodable = {
            ...(rows.first as Map<String, dynamic>),
            'id': 'undecodable',
            'createdAt': 'not a date',
          };
          final raw = jsonEncode([rows.first, undecodable, ...rows.skip(1)]);
          await prefs.setString(CuratedListService.listsStorageKey, raw);
          final service = CuratedListService(
            nostrService: mockNostr,
            authService: mockAuth,
            prefs: prefs,
          );
          addTearDown(service.dispose);
          clearInteractions(mockNostr);

          expect(await service.createList(name: 'Added'), isNull);
          expect(prefs.getString(CuratedListService.listsStorageKey), raw);
          verifyNever(() => mockNostr.publishEventAwaitOk(any()));
          verifyNever(() => mockNostr.publishEvent(any()));
        },
      );
    });

    group('Load from Preferences', () {
      test('loads lists from SharedPreferences on construction', () async {
        // Pre-populate SharedPreferences
        final list = CuratedList(
          id: 'test_id',
          name: 'Saved List',
          videoEventIds: const ['video1', 'video2'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Properly encode as JSON
        await prefs.setString(
          CuratedListService.listsStorageKey,
          jsonEncode([list.toJson()]),
        );

        // Create service - should load from prefs
        final service = CuratedListService(
          nostrService: mockNostr,
          authService: mockAuth,
          prefs: prefs,
        );

        expect(service.lists.length, greaterThan(0));
        expect(service.lists.any((l) => l.name == 'Saved List'), isTrue);
      });

      test('loads empty list when SharedPreferences is empty', () {
        final service = CuratedListService(
          nostrService: mockNostr,
          authService: mockAuth,
          prefs: prefs,
        );

        expect(service.lists, isEmpty);
      });

      test('loads list with all fields from SharedPreferences', () async {
        final originalList = CuratedList(
          id: 'test_id',
          name: 'Full List',
          description: 'Description',
          imageUrl: 'https://example.com/image.jpg',
          videoEventIds: const ['video1'],
          createdAt: DateTime.parse('2024-01-01T12:00:00Z'),
          updatedAt: DateTime.parse('2024-01-02T12:00:00Z'),
          isPublic: false,
          tags: const ['tag1', 'tag2'],
          playOrder: PlayOrder.reverse,
        );

        await prefs.setString(
          CuratedListService.listsStorageKey,
          jsonEncode([originalList.toJson()]),
        );

        final service = CuratedListService(
          nostrService: mockNostr,
          authService: mockAuth,
          prefs: prefs,
        );

        final loadedList = service.getListById('test_id');
        expect(loadedList, isNotNull);
        expect(loadedList!.name, 'Full List');
        expect(loadedList.description, 'Description');
        expect(loadedList.imageUrl, 'https://example.com/image.jpg');
        expect(loadedList.videoEventIds, ['video1']);
        expect(loadedList.isPublic, isFalse);
        expect(loadedList.tags, ['tag1', 'tag2']);
        expect(loadedList.playOrder, PlayOrder.reverse);
      });

      test('handles corrupted SharedPreferences data gracefully', () async {
        // Set invalid JSON
        await prefs.setString(
          CuratedListService.listsStorageKey,
          'invalid json {{{',
        );

        // Should not throw, just log error and continue with
        // empty list
        final service = CuratedListService(
          nostrService: mockNostr,
          authService: mockAuth,
          prefs: prefs,
        );

        expect(service.lists, isEmpty);
      });

      test('preserves lists across service recreations', () async {
        // First service instance - create lists
        final service1 = CuratedListService(
          nostrService: mockNostr,
          authService: mockAuth,
          prefs: prefs,
        );
        await service1.createList(name: 'Persistent List');

        // Second service instance - should load existing lists
        final service2 = CuratedListService(
          nostrService: mockNostr,
          authService: mockAuth,
          prefs: prefs,
        );

        expect(service2.lists.length, greaterThanOrEqualTo(1));
        expect(service2.lists.any((l) => l.name == 'Persistent List'), isTrue);
      });
    });

    group('Persistence Edge Cases', () {
      test('handles very large list (1000 videos)', () async {
        final service = CuratedListService(
          nostrService: mockNostr,
          authService: mockAuth,
          prefs: prefs,
        );

        final list = await service.createList(name: 'Large List');
        for (var i = 0; i < 1000; i++) {
          await service.addVideoToList(list!.id, 'video_$i');
        }

        // Should still save/load successfully
        final service2 = CuratedListService(
          nostrService: mockNostr,
          authService: mockAuth,
          prefs: prefs,
        );

        final loadedList = service2.getListById(list!.id);
        expect(loadedList, isNotNull);
        expect(loadedList!.videoEventIds.length, 1000);
      });

      test('handles special characters in list names', () async {
        final service = CuratedListService(
          nostrService: mockNostr,
          authService: mockAuth,
          prefs: prefs,
        );

        await service.createList(
          name: 'List with "quotes" and \'apostrophes\'',
        );
        await service.createList(name: 'List with \n newlines \t tabs');
        await service.createList(name: 'Émojis 🎥📹🎬');

        final service2 = CuratedListService(
          nostrService: mockNostr,
          authService: mockAuth,
          prefs: prefs,
        );

        expect(service2.lists.length, greaterThanOrEqualTo(3));
      });

      test('handles concurrent save operations', () async {
        final service = CuratedListService(
          nostrService: mockNostr,
          authService: mockAuth,
          prefs: prefs,
        );

        // Create multiple lists concurrently
        await Future.wait([
          service.createList(name: 'Concurrent 1'),
          service.createList(name: 'Concurrent 2'),
          service.createList(name: 'Concurrent 3'),
        ]);

        // At least some lists should be saved
        final savedData = prefs.getString(CuratedListService.listsStorageKey);
        expect(savedData, isNotNull);
      });

      test('preserves timestamps across save/load', () async {
        final service1 = CuratedListService(
          nostrService: mockNostr,
          authService: mockAuth,
          prefs: prefs,
        );

        final list = await service1.createList(name: 'Test List');
        final originalCreatedAt = list!.createdAt;
        final originalUpdatedAt = list.updatedAt;

        // Load in new service instance
        final service2 = CuratedListService(
          nostrService: mockNostr,
          authService: mockAuth,
          prefs: prefs,
        );

        final loadedList = service2.getListById(list.id);
        expect(loadedList!.createdAt, originalCreatedAt);
        expect(loadedList.updatedAt, originalUpdatedAt);
      });

      test('handles empty video list', () async {
        final service = CuratedListService(
          nostrService: mockNostr,
          authService: mockAuth,
          prefs: prefs,
        );

        await service.createList(name: 'Empty List');

        final service2 = CuratedListService(
          nostrService: mockNostr,
          authService: mockAuth,
          prefs: prefs,
        );

        final list = service2.lists.firstWhere((l) => l.name == 'Empty List');
        expect(list.videoEventIds, isEmpty);
      });
    });
  });
}
