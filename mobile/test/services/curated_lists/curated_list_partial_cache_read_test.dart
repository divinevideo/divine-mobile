// ABOUTME: Keeps intact cache rows visible without normalizing damaged evidence.
// ABOUTME: Real initialization and picker reads remain read-only until repair.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/committed_list_account.dart';

class _Auth extends Mock implements AuthService {}

class _Client extends Mock implements NostrClient {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('intact cache rows with preserved whole damaged evidence', () {
    final owner = 'a' * 64;
    final foreignOwner = 'b' * 64;
    final video = 'c' * 64;
    CuratedList row(String id, String? author) => CuratedList(
      id: id,
      name: id,
      pubkey: author,
      videoEventIds: [video],
      isPublic: false,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

    for (final damagedFirst in [false, true]) {
      test(
        'initialize retains intact own/foreign rows when damagedFirst=$damagedFirst',
        () async {
          final own = row('Own', owner);
          final foreign = row('Foreign', foreignOwner);
          final legacy = row('Legacy', null);
          final damaged = {
            ...row('Damaged', foreignOwner).toJson(),
            'updatedAt': 'unreadable private cache timestamp',
          };
          final raw = jsonEncode([
            if (damagedFirst) damaged,
            own.toJson(),
            foreign.toJson(),
            legacy.toJson(),
            if (!damagedFirst) damaged,
          ]);
          SharedPreferences.setMockInitialValues({
            CuratedListService.listsStorageKey: raw,
            CuratedListService.subscribedListsStorageKey: '[]',
          });
          final prefs = await SharedPreferences.getInstance();
          final auth = _Auth();
          when(() => auth.isAuthenticated).thenReturn(true);
          when(() => auth.currentPublicKeyHex).thenReturn(owner);
          await stubCommittedListAccount(auth: auth, preferences: prefs);
          final client = _Client();
          final before = {
            for (final key in prefs.getKeys()) key: prefs.get(key),
          };
          final service = CuratedListService(
            nostrService: client,
            authService: auth,
            prefs: prefs,
          );
          addTearDown(service.dispose);
          expect(service.lists, [own, foreign, legacy]);
          await service.prepareRecovery();
          expect(prefs.getString(CuratedListService.listsStorageKey), raw);
          expect({
            for (final key in prefs.getKeys()) key: prefs.get(key),
          }, before);
          expect(service.recoveryNeedsRepair, isTrue);
          await service.initialize();
          expect(service.isInitialized, isTrue);
          expect(service.initializationError, isNull);
          expect(service.isReadyForMutations, isFalse);
          expect(service.recoveryNeedsRepair, isTrue);
          expect(service.lists, [own, foreign, legacy]);
          expect(service.pickerListsForOwner(owner), [own]);
          expect(service.pickerListsForOwner(foreignOwner), isEmpty);
          expect(
            await service.addVideoToList(own.authorScopedId, 'd' * 64),
            isFalse,
          );
          expect(await service.createList(name: 'Blocked write'), isNull);
          expect(
            await service.subscribeToList(foreign.authorScopedId),
            isFalse,
          );
          expect(await service.deleteOwnedList(own.authorScopedId), isFalse);
          expect(prefs.getString(CuratedListService.listsStorageKey), raw);
          expect({
            for (final key in prefs.getKeys()) key: prefs.get(key),
          }, before);
          verifyZeroInteractions(client);
        },
      );
    }

    test('a contradictory owner row is excluded without hiding a proven own sibling', () async {
      final own = row('Own', owner);
      final doubtful = row('Doubtful', owner);
      final raw = jsonEncode([
        own.toJson(),
        {...doubtful.toJson(), 'authorPubkey': foreignOwner},
      ]);
      SharedPreferences.setMockInitialValues({
        CuratedListService.listsStorageKey: raw,
      });
      final prefs = await SharedPreferences.getInstance();
      final auth = _Auth();
      when(() => auth.isAuthenticated).thenReturn(true);
      when(() => auth.currentPublicKeyHex).thenReturn(owner);
      await stubCommittedListAccount(auth: auth, preferences: prefs);
      final client = _Client();
      final service = CuratedListService(
        nostrService: client,
        authService: auth,
        prefs: prefs,
      );
      addTearDown(service.dispose);
      await service.initialize();
      expect(service.isInitialized, isTrue);
      expect(service.isReadyForMutations, isFalse);
      expect(service.lists, [own]);
      expect(service.pickerListsForOwner(owner), [own]);
      expect(prefs.getString(CuratedListService.listsStorageKey), raw);
      verifyZeroInteractions(client);
    });
  });
}
