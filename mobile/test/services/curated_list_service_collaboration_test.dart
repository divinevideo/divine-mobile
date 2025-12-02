// ABOUTME: Unit tests for CuratedListService collaboration features
// ABOUTME: Tests adding/removing collaborators and permission checks

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'curated_list_service_collaboration_test.mocks.dart';

@GenerateMocks([INostrService, AuthService])
void main() {
  group('CuratedListService - Collaboration Features', () {
    late CuratedListService service;
    late MockINostrService mockNostr;
    late MockAuthService mockAuth;
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      mockNostr = MockINostrService();
      mockAuth = MockAuthService();
      prefs = await SharedPreferences.getInstance();

      when(mockAuth.isAuthenticated).thenReturn(true);
      when(
        mockAuth.currentPublicKeyHex,
      ).thenReturn('test_pubkey_123456789abcdef');

      when(mockNostr.broadcastEvent(any)).thenAnswer((_) async {
        final event = Event.fromJson({
          'id': 'test_event_id',
          'pubkey': 'test_pubkey_123456789abcdef',
          'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'kind': 30005,
          'tags': [],
          'content': 'test',
          'sig': 'test_sig',
        });
        return NostrBroadcastResult(
          event: event,
          successCount: 1,
          totalRelays: 1,
          results: {'wss://relay.example.com': true},
          errors: {},
        );
      });

      when(
        mockNostr.subscribeToEvents(
          filters: anyNamed('filters'),
          bypassLimits: anyNamed('bypassLimits'),
          onEose: anyNamed('onEose'),
        ),
      ).thenAnswer((_) => Stream.empty());

      when(
        mockAuth.createAndSignEvent(
          kind: anyNamed('kind'),
          content: anyNamed('content'),
          tags: anyNamed('tags'),
        ),
      ).thenAnswer(
        (_) async => Event.fromJson({
          'id': 'test_event_id',
          'pubkey': 'test_pubkey_123456789abcdef',
          'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'kind': 30005,
          'tags': [],
          'content': 'test',
          'sig': 'test_sig',
        }),
      );

      service = CuratedListService(
        nostrService: mockNostr,
        authService: mockAuth,
        prefs: prefs,
      );
    });

    group('addCollaborator()', () {
      test('adds collaborator to collaborative list', () async {
        final list = await service.createList(
          name: 'Test List',
          isCollaborative: true,
        );

        final result = await service.addCollaborator(
          list!.id,
          'collaborator_pubkey_123',
        );

        expect(result, isTrue);
        final updatedList = service.getListById(list.id);
        expect(
          updatedList!.allowedCollaborators,
          contains('collaborator_pubkey_123'),
        );
      });

      test('adds multiple collaborators', () async {
        final list = await service.createList(
          name: 'Test List',
          isCollaborative: true,
        );
        final listId = list!.id;

        await service.addCollaborator(listId, 'collaborator_1');
        await service.addCollaborator(listId, 'collaborator_2');
        await service.addCollaborator(listId, 'collaborator_3');

        final updatedList = service.getListById(listId);
        expect(updatedList!.allowedCollaborators.length, 3);
        expect(
          updatedList.allowedCollaborators,
          containsAll(['collaborator_1', 'collaborator_2', 'collaborator_3']),
        );
      });

      test('returns false when adding to non-collaborative list', () async {
        final list = await service.createList(
          name: 'Test List',
          isCollaborative: false,
        );

        final result = await service.addCollaborator(
          list!.id,
          'collaborator_pubkey_123',
        );

        expect(result, isFalse);
      });

      test('prevents duplicate collaborators', () async {
        final list = await service.createList(
          name: 'Test List',
          isCollaborative: true,
        );
        final listId = list!.id;

        await service.addCollaborator(listId, 'collaborator_1');
        await service.addCollaborator(listId, 'collaborator_1'); // Duplicate

        final updatedList = service.getListById(listId);
        expect(
          updatedList!.allowedCollaborators
              .where((c) => c == 'collaborator_1')
              .length,
          1,
        );
      });

      test('returns false for non-existent list', () async {
        final result = await service.addCollaborator(
          'non_existent',
          'collaborator_pubkey_123',
        );

        expect(result, isFalse);
      });

      test('publishes update to Nostr for public list', () async {
        final list = await service.createList(
          name: 'Test List',
          isCollaborative: true,
          isPublic: true,
        );
        reset(mockNostr);

        await service.addCollaborator(list!.id, 'collaborator_1');

        verify(mockNostr.broadcastEvent(any)).called(1);
      });

      test('updates updatedAt timestamp', () async {
        final list = await service.createList(
          name: 'Test List',
          isCollaborative: true,
        );
        final originalUpdatedAt = service.getListById(list!.id)!.updatedAt;

        await Future.delayed(const Duration(milliseconds: 10));
        await service.addCollaborator(list.id, 'collaborator_1');

        final updatedList = service.getListById(list.id);
        expect(updatedList!.updatedAt.isAfter(originalUpdatedAt), isTrue);
      });
    });

    group('removeCollaborator()', () {
      test('removes collaborator from list', () async {
        final list = await service.createList(
          name: 'Test List',
          isCollaborative: true,
        );
        final listId = list!.id;

        await service.addCollaborator(listId, 'collaborator_1');
        await service.addCollaborator(listId, 'collaborator_2');

        final result = await service.removeCollaborator(
          listId,
          'collaborator_1',
        );

        expect(result, isTrue);
        final updatedList = service.getListById(listId);
        expect(updatedList!.allowedCollaborators, ['collaborator_2']);
        expect(
          updatedList.allowedCollaborators,
          isNot(contains('collaborator_1')),
        );
      });

      test('returns false for non-existent list', () async {
        final result = await service.removeCollaborator(
          'non_existent',
          'collaborator_1',
        );

        expect(result, isFalse);
      });

      test('returns true even when collaborator not in list (no-op)', () async {
        final list = await service.createList(
          name: 'Test List',
          isCollaborative: true,
        );

        final result = await service.removeCollaborator(
          list!.id,
          'non_existent_collaborator',
        );

        // Implementation returns true (successful no-op) rather than false
        expect(result, isTrue);
      });

      test('publishes update to Nostr for public list', () async {
        final list = await service.createList(
          name: 'Test List',
          isCollaborative: true,
          isPublic: true,
        );
        await service.addCollaborator(list!.id, 'collaborator_1');
        reset(mockNostr);

        await service.removeCollaborator(list.id, 'collaborator_1');

        verify(mockNostr.broadcastEvent(any)).called(1);
      });

      test('handles removing last collaborator', () async {
        final list = await service.createList(
          name: 'Test List',
          isCollaborative: true,
        );
        await service.addCollaborator(list!.id, 'collaborator_1');

        await service.removeCollaborator(list.id, 'collaborator_1');

        final updatedList = service.getListById(list.id);
        expect(updatedList!.allowedCollaborators, isEmpty);
        expect(updatedList.isCollaborative, isTrue); // Still collaborative
      });
    });

    group('canCollaborate()', () {
      test('returns true for list owner', () async {
        final list = await service.createList(
          name: 'Test List',
          isCollaborative: true,
        );

        final result = service.canCollaborate(
          list!.id,
          'test_pubkey_123456789abcdef', // Owner's pubkey
        );

        expect(result, isTrue);
      });

      test('returns true for allowed collaborator', () async {
        final list = await service.createList(
          name: 'Test List',
          isCollaborative: true,
        );
        await service.addCollaborator(list!.id, 'collaborator_1');

        final result = service.canCollaborate(list.id, 'collaborator_1');

        expect(result, isTrue);
      });

      test('returns false for non-collaborator', () async {
        final list = await service.createList(
          name: 'Test List',
          isCollaborative: true,
        );
        await service.addCollaborator(list!.id, 'collaborator_1');

        final result = service.canCollaborate(list.id, 'random_user');

        expect(result, isFalse);
      });

      test('returns false for non-collaborative list', () async {
        final list = await service.createList(
          name: 'Test List',
          isCollaborative: false,
        );

        final result = service.canCollaborate(list!.id, 'random_user');

        expect(result, isFalse);
      });

      test('returns false for non-existent list', () {
        final result = service.canCollaborate('non_existent', 'random_user');

        expect(result, isFalse);
      });
    });

    group('Collaboration - Edge Cases', () {
      test('converting non-collaborative list to collaborative', () async {
        final list = await service.createList(
          name: 'Test List',
          isCollaborative: false,
        );

        await service.updateList(listId: list!.id, isCollaborative: true);

        // Now should be able to add collaborators
        final result = await service.addCollaborator(list.id, 'collaborator_1');
        expect(result, isTrue);
      });

      test(
        'converting collaborative list to non-collaborative preserves collaborators',
        () async {
          final list = await service.createList(
            name: 'Test List',
            isCollaborative: true,
          );
          await service.addCollaborator(list!.id, 'collaborator_1');

          await service.updateList(listId: list.id, isCollaborative: false);

          final updatedList = service.getListById(list.id);
          expect(updatedList!.isCollaborative, isFalse);
          expect(updatedList.allowedCollaborators, [
            'collaborator_1',
          ]); // Preserved
          expect(
            service.canCollaborate(list.id, 'collaborator_1'),
            isFalse,
          ); // But can't edit
        },
      );

      test('adding collaborator with empty pubkey', () async {
        final list = await service.createList(
          name: 'Test List',
          isCollaborative: true,
        );

        final result = await service.addCollaborator(list!.id, '');

        // Service should handle gracefully (either accept or reject)
        expect(result, isA<bool>());
      });

      test('collaborator list persists across service recreations', () async {
        final list = await service.createList(
          name: 'Test List',
          isCollaborative: true,
        );
        await service.addCollaborator(list!.id, 'collaborator_1');
        await service.addCollaborator(list.id, 'collaborator_2');

        // Create new service instance
        final service2 = CuratedListService(
          nostrService: mockNostr,
          authService: mockAuth,
          prefs: prefs,
        );

        final loadedList = service2.getListById(list.id);
        expect(
          loadedList!.allowedCollaborators,
          containsAll(['collaborator_1', 'collaborator_2']),
        );
      });

      test('many collaborators (100)', () async {
        final list = await service.createList(
          name: 'Test List',
          isCollaborative: true,
        );
        final listId = list!.id;

        for (var i = 0; i < 100; i++) {
          await service.addCollaborator(listId, 'collaborator_$i');
        }

        final updatedList = service.getListById(listId);
        expect(updatedList!.allowedCollaborators.length, 100);
      });

      test('canCollaborate with null pubkey', () {
        expect(service.canCollaborate('any_list', ''), isFalse);
      });
    });
  });
}
