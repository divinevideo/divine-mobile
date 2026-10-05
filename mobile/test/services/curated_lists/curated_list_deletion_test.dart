// ABOUTME: Exercises extracted deletion through the public owned-list boundary.
// ABOUTME: Retrying default retirement preserves another list's memory-only ACK.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/services/curated_lists/curated_list_recovery_journal.dart';
import 'package:openvine/services/curated_lists/curated_list_recovery_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import '../../helpers/curated_list_publish_stubs.dart';

class _Client extends Mock implements NostrClient {}

class _Auth extends Mock implements AuthService {}

class _Storage extends InMemorySharedPreferencesStore {
  _Storage() : super.empty();
  bool rejectJournal = false;
  bool rejectRetirement = false;
  bool throwing = false;

  @override
  Future<bool> setValue(String type, String key, Object value) async {
    final blocked =
        key.contains(CuratedListRecoveryJournal.storagePrefix) &&
        (rejectJournal ||
            (rejectRetirement &&
                value is String &&
                value.contains('"permissionsRetired":true')));
    if (blocked) {
      if (throwing) throw StateError('Retirement storage unavailable');
      return false;
    }
    return super.setValue(type, key, value);
  }
}

void main() {
  group('CuratedListDeletion', () {
    const owner =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const oldPublicId =
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
    const acceptedId =
        'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
    const siblingPublicId =
        'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
    const collaborator =
        'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
    late SharedPreferences prefs;
    late SharedPreferencesStorePlatform previous;
    late _Storage storage;
    late _Client client;
    late _Auth auth;

    setUp(() async {
      previous = SharedPreferencesStorePlatform.instance;
      storage = _Storage();
      SharedPreferencesStorePlatform.instance = storage;
      SharedPreferences.resetStatic();
      prefs = await SharedPreferences.getInstance();
      client = _Client();
      auth = _Auth();
      when(() => auth.isAuthenticated).thenReturn(true);
      when(() => auth.currentPublicKeyHex).thenReturn(owner);
      stubListPublishing(client: client, auth: auth, pubkey: owner);
      when(
        () => client.subscribe(
          any(),
          closeOnEose: true,
          onEose: any(named: 'onEose'),
        ),
      ).thenAnswer((_) => const Stream.empty());
    });

    tearDown(() {
      SharedPreferences.resetStatic();
      SharedPreferencesStorePlatform.instance = previous;
    });

    CuratedListService open() {
      final service = CuratedListService(
        nostrService: client,
        authService: auth,
        prefs: prefs,
      );
      addTearDown(service.dispose);
      return service;
    }

    CuratedListRecoveryJournal journal() => CuratedListRecoveryJournal(
      prefs: prefs,
      runCurrent: (operation) => operation(),
    );

    for (final throwing in [false, true]) {
      test(
        'default deletion ${throwing ? 'throw' : 'refusal'} retries without losing a sibling ACK',
        () async {
          final now = DateTime.utc(2026, 10, 5);
          final original = CuratedList(
            id: CuratedListService.defaultListId,
            name: 'Default private list',
            pubkey: owner,
            videoEventIds: const [],
            createdAt: now,
            updatedAt: now,
            nostrEventId: oldPublicId,
            isPublic: false,
          );
          final sibling = original.copyWith(id: 'sibling', name: 'Sibling');
          await prefs.setString(
            CuratedListService.listsStorageKey,
            jsonEncode([original.toJson(), sibling.toJson()]),
          );
          CuratedList? atRedaction;
          List<String>? advisoryAtRedaction;
          when(() => client.publishEventAwaitOk(any())).thenAnswer((
            invocation,
          ) async {
            final event = invocation.positionalArguments.single as Event;
            if (event.kind == 5 &&
                event.tags.any(
                  (tag) =>
                      tag.length > 1 && tag[0] == 'e' && tag[1] == oldPublicId,
                )) {
              await prefs.reload();
              final stored = jsonDecode(
                prefs.getString(CuratedListService.listsStorageKey)!,
              ) as List;
              atRedaction = CuratedList.fromJson(
                stored.cast<Map<String, dynamic>>().singleWhere(
                  (row) => row['id'] == original.id,
                ),
              );
              advisoryAtRedaction = CuratedListRecoveryStorage.read(
                prefs,
                CuratedListRecoveryJournal.storageKey(owner),
              ).records[original.id]?.plaintextEventIds;
            }
            return acceptedOutcome(event);
          });
          expect(
            await journal().accepted(
              owner: owner,
              listId: original.id,
              visibility: const CuratedListVisibility(
                isPublic: true,
                isCollaborative: true,
                allowedCollaborators: [collaborator],
                relayAccepted: true,
              ),
              eventId: acceptedId,
              acceptedAt: now,
              plaintextEventIds: [oldPublicId],
            ),
            isTrue,
          );
          final current = open();
          storage.rejectRetirement = true;
          storage.throwing = throwing;
          expect(await current.deleteOwnedList(original.id), isFalse);
          await prefs.reload();
          final remaining = jsonDecode(
            prefs.getString(CuratedListService.listsStorageKey)!,
          ) as List;
          expect(remaining.map((row) => (row as Map)['id']), ['sibling']);
          expect(
            journal().record(owner, original.id)!.visibility!.isPublic,
            isTrue,
          );
          expect(current.getDefaultList(), isNull);

          storage.throwing = false;
          storage.rejectRetirement = false;
          storage.rejectJournal = true;
          expect(
            await journal().accepted(
              owner: owner,
              listId: sibling.id,
              visibility: const CuratedListVisibility(
                isPublic: false,
                isCollaborative: false,
                allowedCollaborators: [],
                relayAccepted: true,
              ),
              eventId: siblingPublicId,
              acceptedAt: now,
              plaintextEventIds: [siblingPublicId],
            ),
            isFalse,
          );
          expect(journal().record(owner, sibling.id)!.plaintextEventIds, [
            siblingPublicId,
          ]);
          storage.rejectJournal = false;
          expect(
            await current.deleteOwnedList(original.authorScopedId),
            isTrue,
          );

          SharedPreferences.resetStatic();
          prefs = await SharedPreferences.getInstance();
          final retired = journal().record(owner, original.id)!;
          expect(retired.visibility, isNull);
          expect(retired.permissionsRetired, isTrue);
          expect(retired.plaintextEventIds, [oldPublicId]);
          expect(journal().record(owner, sibling.id)!.plaintextEventIds, [
            siblingPublicId,
          ]);
          await prefs.setBool(
            CuratedListService.defaultListDeletedStorageKey,
            false,
          );
          final restored = open();
          await restored.initialize();
          final recreated = restored.getDefaultList()!;
          expect(recreated.isPublic, isFalse);
          expect(recreated.isCollaborative, isFalse);
          expect(recreated.allowedCollaborators, isEmpty);
          expect(recreated.hasPendingPermissionRecovery, isFalse);
          final sent = verify(
            () => client.publishEventAwaitOk(captureAny()),
          ).captured.cast<Event>();
          final replacements = sent
              .where(
                (event) =>
                    event.kind == 30005 &&
                    event.tags.any(
                      (tag) =>
                          tag.length > 1 &&
                          tag[0] == 'd' &&
                          tag[1] == original.id,
                    ),
              )
              .toList();
          expect(replacements, isNotEmpty);
          expect(recreated.nostrEventId, replacements.last.id);
          expect(unsealForTest(replacements.last.content), isNotNull);
          expect(atRedaction, isNotNull);
          final boundary = atRedaction!;
          expect(boundary.nostrEventId, replacements.last.id);
          expect(boundary.isPublic, isFalse);
          expect(boundary.isCollaborative, isFalse);
          expect(boundary.allowedCollaborators, isEmpty);
          expect(advisoryAtRedaction, contains(oldPublicId));
          final redactionIndex = sent.indexWhere(
            (event) =>
                event.kind == 5 &&
                event.tags.any(
                  (tag) =>
                      tag.length > 1 && tag[0] == 'e' && tag[1] == oldPublicId,
                ),
          );
          expect(redactionIndex, greaterThan(sent.indexOf(replacements.first)));
          expect(restored.getListById(sibling.authorScopedId), isNotNull);
          SharedPreferences.resetStatic();
          prefs = await SharedPreferences.getInstance();
          final durable = open().getDefaultList()!;
          expect(durable.nostrEventId, replacements.last.id);
          expect(durable.isPublic, isFalse);
          expect(durable.isCollaborative, isFalse);
          expect(durable.allowedCollaborators, isEmpty);
          expect(durable.hasPendingPermissionRecovery, isFalse);
        },
      );
    }
  });
}
