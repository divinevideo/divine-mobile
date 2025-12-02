// ABOUTME: TDD tests for UserListService managing NIP-51 kind 30000 people lists
// ABOUTME: Ensures proper creation, storage, and retrieval of user lists

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/user_list_service.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('UserListService TDD', () {
    late SharedPreferences mockPrefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      mockPrefs = await SharedPreferences.getInstance();
    });

    test('RED: UserListService should exist', () {
      expect(
        () => UserListService(prefs: mockPrefs),
        returnsNormally,
        reason: 'UserListService class should be defined',
      );
    });

    test('RED: Should have Divine Team as default list', () async {
      final service = UserListService(prefs: mockPrefs);
      await service.initialize();

      final lists = service.lists;
      expect(
        lists.isNotEmpty,
        true,
        reason: 'Should have at least Divine Team list',
      );

      final divineTeam = lists.firstWhere(
        (list) => list.id == 'divine_team',
        orElse: () => throw Exception('Divine Team list not found'),
      );

      expect(
        divineTeam.name,
        'Divine Team',
        reason: 'Divine Team list should have correct name',
      );
      expect(
        divineTeam.pubkeys,
        AppConstants.divineTeamPubkeys,
        reason: 'Divine Team should contain divine team pubkeys',
      );
    });

    test('RED: Divine Team list should be public and non-editable', () async {
      final service = UserListService(prefs: mockPrefs);
      await service.initialize();

      final divineTeam = service.getListById('divine_team');
      expect(divineTeam, isNotNull);
      expect(
        divineTeam!.isPublic,
        true,
        reason: 'Divine Team should be public',
      );
      // Note: We'll add isEditable field to prevent users from editing Divine Team
    });

    test('Should create new user list', () async {
      final service = UserListService(prefs: mockPrefs);
      await service.initialize();

      final newList = await service.createList(
        name: 'My Friends',
        description: 'Friends I follow',
        pubkeys: ['pubkey1', 'pubkey2'],
      );

      expect(newList, isNotNull);
      expect(newList!.name, 'My Friends');
      expect(newList.pubkeys.length, 2);
    });

    test('Should add pubkey to user list', () async {
      final service = UserListService(prefs: mockPrefs);
      await service.initialize();

      final list = await service.createList(
        name: 'Test List',
        pubkeys: ['pubkey1'],
      );

      await service.addPubkeyToList(list!.id, 'pubkey2');

      final updated = service.getListById(list.id);
      expect(updated!.pubkeys.length, 2);
      expect(updated.pubkeys.contains('pubkey2'), true);
    });

    test('Should remove pubkey from user list', () async {
      final service = UserListService(prefs: mockPrefs);
      await service.initialize();

      final list = await service.createList(
        name: 'Test List',
        pubkeys: ['pubkey1', 'pubkey2'],
      );

      await service.removePubkeyFromList(list!.id, 'pubkey1');

      final updated = service.getListById(list.id);
      expect(updated!.pubkeys.length, 1);
      expect(updated.pubkeys.contains('pubkey1'), false);
    });

    test('Should persist lists to SharedPreferences', () async {
      final service = UserListService(prefs: mockPrefs);
      await service.initialize();

      await service.createList(name: 'Persistent List', pubkeys: ['pubkey1']);

      // Create new service instance to test persistence
      final service2 = UserListService(prefs: mockPrefs);
      await service2.initialize();

      final lists = service2.lists;
      final persistedList = lists.firstWhere(
        (list) => list.name == 'Persistent List',
        orElse: () => throw Exception('List not persisted'),
      );

      expect(persistedList.pubkeys, ['pubkey1']);
    });
  });
}
