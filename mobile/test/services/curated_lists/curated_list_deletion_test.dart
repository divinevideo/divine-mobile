// ABOUTME: Exercises extracted deletion through the public owned-list boundary.
// ABOUTME: Retrying default retirement preserves another list's memory-only ACK.

import 'dart:convert';

import 'package:curated_list_repository/curated_list_repository.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/services/curated_lists/curated_list_recovery_journal.dart';
import 'package:openvine/services/curated_lists/curated_list_recovery_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import '../../helpers/committed_list_account.dart';
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
    // Public identity derived from the well-known synthetic private test key1.
    const owner =
        '79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798';
    const oldPublicId =
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
    const siblingPublicId =
        'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
    const collaborator =
        'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
    late SharedPreferences prefs;
    late SharedPreferencesStorePlatform previous;
    late _Storage storage;
    late _Client client;
    late _Auth auth;
    late LocalNostrSigner signer;

    setUpAll(() => registerFallbackValue(<Filter>[]));

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
      signer = LocalNostrSigner('1'.padLeft(64, '0'));
      when(() => client.signer).thenReturn(signer);
      when(
        () => auth.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
          createdAt: any(named: 'createdAt'),
        ),
      ).thenAnswer((invocation) async {
        final event = Event(
          owner,
          invocation.namedArguments[#kind] as int,
          invocation.namedArguments[#tags] as List<List<String>>,
          invocation.namedArguments[#content] as String,
          createdAt: invocation.namedArguments[#createdAt] as int?,
        );
        await signer.signEvent(event);
        return event;
      });
      await prefs.setString('current_user_pubkey_hex', owner);
      await stubCommittedListAccount(auth: auth, preferences: prefs);
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
          // The current published revision is genuine and fully decoded;
          // a cached event ID or a mock authentication flag grants no rights.
          final baseline = Event(
            owner,
            30005,
            [
              ['d', CuratedListService.defaultListId],
              ['title', 'Default published list'],
              ['collaborative', 'true'],
              ['collaborator', collaborator],
            ],
            'Current published default',
            createdAt: now.millisecondsSinceEpoch ~/ 1000,
          );
          await signer.signEvent(baseline);
          expect(baseline.isValid && baseline.isSigned, isTrue);
          final original = CuratedListConverter.fromEvent(baseline)!;
          final sibling = original.copyWith(id: 'sibling', name: 'Sibling');
          await prefs.setString(
            CuratedListService.listsStorageKey,
            jsonEncode([original.toJson(), sibling.toJson()]),
          );
          bool? defaultAbsentAtRedaction;
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
              defaultAbsentAtRedaction = !stored
                  .cast<Map<String, dynamic>>()
                  .any((row) => row['id'] == original.id);
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
              eventId: baseline.id,
              acceptedAt: now,
              plaintextEventIds: [oldPublicId],
            ),
            isTrue,
          );
          when(() => client.subscribe(any(), closeOnEose: true))
              .thenAnswer((_) => Stream.value(baseline));
          final current = open();
          await current.fetchUserListsFromRelays(force: true);
          expect(current.getDefaultList()!.nostrEventId, baseline.id);
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

          current.dispose();
          SharedPreferences.resetStatic();
          prefs = await SharedPreferences.getInstance();
          when(() => auth.committedAccountActivationReceipt).thenReturn(null);
          await stubCommittedListAccount(auth: auth, preferences: prefs);
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
          // The shared flag cannot erase the owned coordinate tombstone.
          // Even the genuine older signed relay event cannot resurrect it.
          final restored = open();
          await restored.initialize();
          await restored.fetchUserListsFromRelays(force: true);
          expect(restored.isInitialized, isTrue);
          expect(restored.getDefaultList(), isNull);
          expect(restored.getListById(sibling.authorScopedId), isNotNull);
          expect(journal().record(owner, original.id)!.plaintextEventIds, [
            oldPublicId,
          ]);
          final beforeSync = verify(
            () => client.publishEventAwaitOk(captureAny()),
          ).captured.cast<Event>();
          bool isDefaultReplacement(Event event) =>
              event.kind == 30005 &&
              event.tags.any(
                (tag) =>
                    tag.length > 1 && tag[0] == 'd' && tag[1] == original.id,
              );
          expect(beforeSync.where(isDefaultReplacement), isEmpty);
          expect(defaultAbsentAtRedaction, isNull);
          // Explicit advisory erasure may drain owned journal evidence without
          // publishing an empty replacement or recreating a cache row.
          expect(await restored.retryListSync(original.authorScopedId), isTrue);
          final afterSync = verify(
            () => client.publishEventAwaitOk(captureAny()),
          ).captured.cast<Event>();
          expect(afterSync.where(isDefaultReplacement), isEmpty);
          expect(defaultAbsentAtRedaction, isTrue);
          expect(advisoryAtRedaction, contains(oldPublicId));
          expect(restored.getDefaultList(), isNull);
          expect(journal().record(owner, sibling.id)!.plaintextEventIds, [
            siblingPublicId,
          ]);
          restored.dispose();
          SharedPreferences.resetStatic();
          prefs = await SharedPreferences.getInstance();
          when(() => auth.committedAccountActivationReceipt).thenReturn(null);
          await stubCommittedListAccount(auth: auth, preferences: prefs);
          final durable = open();
          expect(durable.getDefaultList(), isNull);
          expect(durable.getListById(sibling.authorScopedId), isNotNull);
          expect(journal().record(owner, original.id)?.visibility, isNull);
        },
      );
    }
  });
}
