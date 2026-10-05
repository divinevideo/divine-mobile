// ABOUTME: Covers unconfirmed privacy, accepted recovery and durable redaction retries.
// ABOUTME: Uses real SharedPreferences over a rejecting in-memory backing store.

import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/relay/publish_outcome.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/services/curated_lists/curated_list_recovery_journal.dart';
import 'package:openvine/services/curated_lists/curated_list_recovery_storage.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:unified_logger/unified_logger.dart';

import '../helpers/curated_list_publish_stubs.dart';

class _Client extends Mock implements NostrClient {}

class _Auth extends Mock implements AuthService {}

class _RejectingStore extends InMemorySharedPreferencesStore {
  _RejectingStore() : super.empty();
  bool Function(String key, Object value)? rejects;
  bool Function(String key, Object value)? throwsOn;
  String? rejectsRemoval;
  String? throwsRemoval;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (throwsOn?.call(key, value) ?? false) {
      throw StateError('Refused private recovery');
    }
    if (rejects?.call(key, value) ?? false) return false;
    return super.setValue(valueType, key, value);
  }

  @override
  Future<bool> remove(String key) async {
    if (throwsRemoval != null && key.endsWith(throwsRemoval!)) {
      throw StateError('Storage removal unavailable');
    }
    if (rejectsRemoval != null && key.endsWith(rejectsRemoval!)) return false;
    return super.remove(key);
  }
}

const _owner =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _oldEvent =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _video =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

void main() {
  group('CuratedListService privacy recovery', () {
    late _RejectingStore backing;
    late SharedPreferences prefs;
    late _Client client;
    late _Auth auth;
    late SharedPreferencesStorePlatform previousPlatform;
    final sent = <Event>[];

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      previousPlatform = SharedPreferencesStorePlatform.instance;
      SharedPreferences.resetStatic();
      backing = _RejectingStore();
      SharedPreferencesStorePlatform.instance = backing;
      prefs = await SharedPreferences.getInstance();
      client = _Client();
      auth = _Auth();
      when(() => auth.isAuthenticated).thenReturn(true);
      when(() => auth.currentPublicKeyHex).thenReturn(_owner);
      stubListPublishing(client: client, auth: auth, pubkey: _owner);
      sent.clear();
      when(() => client.publishEventAwaitOk(any())).thenAnswer((i) async {
        final event = i.positionalArguments.single as Event;
        sent.add(event);
        return acceptedOutcome(event);
      });
      when(() => client.publishEvent(any())).thenAnswer((i) async {
        final event = i.positionalArguments.single as Event;
        sent.add(event);
        return PublishSuccess(event: event);
      });
      addTearDown(() {
        SharedPreferences.resetStatic();
        SharedPreferencesStorePlatform.instance = previousPlatform;
      });
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

    Future<void> restart() async {
      // A genuine new preference cache must reload the durable platform value,
      // rather than keep the optimistic value from a rejected setString.
      SharedPreferences.resetStatic();
      prefs = await SharedPreferences.getInstance();
    }

    Future<CuratedList> seed({bool isPublic = true}) async {
      final now = clock.now().subtract(const Duration(seconds: 4));
      final list = CuratedList(
        id: 'privacy',
        name: 'Before',
        pubkey: _owner,
        videoEventIds: const [_video],
        createdAt: now,
        updatedAt: now,
        nostrEventId: _oldEvent,
        isPublic: isPublic,
      );
      await prefs.setString(
        CuratedListService.listsStorageKey,
        jsonEncode([list.toJson()]),
      );
      return list;
    }

    test('immediate logout migrates stored owner evidence before the list cache is wiped', () async {
      final list = await seed(isPublic: false);
      final pending = list.copyWith(
        pendingPlaintextEventIds: [_oldEvent],
        pendingVisibility: const CuratedListVisibility(
          isPublic: true,
          isCollaborative: false,
          allowedCollaborators: [],
          relayAccepted: true,
        ),
        pendingRepublish: true,
      );
      await prefs.setString('current_user_pubkey_hex', _owner);
      await prefs.setString(
        CuratedListService.listsStorageKey,
        jsonEncode([pending.toJson()]),
      );
      final departing = open();
      await UserDataCleanupService(prefs)
          .clearUserSpecificData(userPubkey: _owner);
      expect(departing.isCurrentSession, isFalse);
      expect(prefs.containsKey(CuratedListService.listsStorageKey), isFalse);
      final journal = CuratedListRecoveryJournal(
        prefs: prefs,
        runCurrent: (op) => op(),
      );
      expect(journal.record(_owner, list.id)!.plaintextEventIds, [_oldEvent]);
      expect(journal.record(_owner, list.id)!.visibility!.isPublic, isTrue);
      expect(sent, isEmpty);
    });

    test('ordinary swap preserves both full owners without authorizing the incoming signer', () async {
      final list = await seed(isPublic: false);
      const incoming =
          'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
      final pending = list.copyWith(pendingPlaintextEventIds: [_oldEvent]);
      final foreign = pending.copyWith(
        pubkey: incoming,
        pendingPlaintextEventIds: [_video],
      );
      await prefs.setString('current_user_pubkey_hex', _owner);
      await prefs.setString(
        CuratedListService.listsStorageKey,
        jsonEncode([pending.toJson(), foreign.toJson()]),
      );
      final departing = open();
      await UserDataCleanupService(prefs)
          .clearUserSpecificData(isIdentityChange: true, userPubkey: incoming);
      when(() => auth.currentPublicKeyHex).thenReturn(incoming);
      stubListPublishing(client: client, auth: auth, pubkey: incoming);
      final next = open();
      expect(departing.isCurrentSession, isFalse);
      expect(await next.retryListSync(pending.authorScopedId), isFalse);
      expect(sent, isEmpty);
      final journal = CuratedListRecoveryJournal(
        prefs: prefs,
        runCurrent: (op) => op(),
      );
      expect(journal.record(_owner, list.id)!.plaintextEventIds, [_oldEvent]);
      expect(journal.record(incoming, list.id)!.plaintextEventIds, [_video]);
    });

    test('rejected migration stops ordinary logout before pending cache evidence is wiped', () async {
      final list = (await seed()).copyWith(
        pendingPlaintextEventIds: [_oldEvent],
      );
      await prefs.setString('current_user_pubkey_hex', _owner);
      await prefs.setString(
        CuratedListService.listsStorageKey,
        jsonEncode([list.toJson()]),
      );
      backing.rejects = (key, value) =>
          key.contains(CuratedListRecoveryJournal.storagePrefix);
      final departing = open();
      await expectLater(
        UserDataCleanupService(prefs).clearUserSpecificData(userPubkey: _owner),
        throwsStateError,
      );
      expect(departing.isCurrentSession, isFalse);
      await restart();
      expect(
        prefs.getString(CuratedListService.listsStorageKey),
        contains(_oldEvent),
      );
      expect(sent, isEmpty);
    });

    for (final preserveActive in [false, true]) {
      test(
        'destructive removal clears only the departing journal with activeSession=$preserveActive',
        () async {
          const other =
              'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
          final pending = (await seed()).copyWith(
            pendingPlaintextEventIds: [_oldEvent],
          );
          final journal = CuratedListRecoveryJournal(
            prefs: prefs,
            runCurrent: (op) => op(),
          );
          expect(await journal.captureRows([pending], _owner), isTrue);
          expect(
            await journal.captureRows([pending.copyWith(pubkey: other)], other),
            isTrue,
          );
          await prefs.setString('current_user_pubkey_hex', _owner);
          await prefs.setString(
            CuratedListService.listsStorageKey,
            jsonEncode([pending.toJson()]),
          );
          await UserDataCleanupService(prefs).deleteAccountData(
            _owner,
            userNpub: 'npub-owner',
            preserveActiveSession: preserveActive,
          );
          expect(journal.records(_owner), isEmpty);
          expect(journal.record(other, pending.id)!.plaintextEventIds, [
            _oldEvent,
          ]);
          expect(sent, isEmpty);
        },
      );
    }

    for (final initialPublic in [false, true]) {
      for (final outcome in ['empty', 'timeout', 'rejected', 'throws']) {
        for (final entry in ['rename', 'add', 'retry', 'backfill']) {
          test('unconfirmed visibility=$initialPublic/$outcome then $entry '
              'retains accepted privacy', () async {
            final list = await seed(isPublic: initialPublic);
            var current = open();
            when(() => client.publishEventAwaitOk(any())).thenAnswer((i) async {
              final event = i.positionalArguments.single as Event;
              if (outcome == 'throws') throw StateError('socket disconnected');
              return PublishOutcome(
                eventId: event.id,
                acceptedBy: const [],
                rejectedBy: outcome == 'rejected'
                    ? const {'wss://relay.test': 'blocked'}
                    : const {},
                noResponseFrom: outcome == 'timeout'
                    ? const ['wss://relay.test']
                    : const [],
              );
            });
            var unknown = 0;
            expect(
              await current.updateList(
                listId: list.id,
                isPublic: !initialPublic,
                onPublicationUnconfirmed: () => unknown++,
              ),
              isFalse,
            );
            expect(unknown, outcome == 'rejected' ? 0 : 1);
            expect(current.getListById(list.id)!.isPublic, initialPublic);
            expect(current.getListById(list.id)!.pendingVisibility, isNull);
            await restart();
            current = open();
            expect(current.getListById(list.id)!.pendingVisibility, isNull);
            sent.clear();
            when(() => client.publishEventAwaitOk(any())).thenAnswer((i) async {
              final event = i.positionalArguments.single as Event;
              sent.add(event);
              return acceptedOutcome(event);
            });
            switch (entry) {
              case 'rename':
                expect(
                  await current.updateList(listId: list.id, name: 'Renamed'),
                  isTrue,
                );
              case 'add':
                expect(await current.addVideoToList(list.id, 'd' * 64), isTrue);
              case 'retry':
                expect(await current.retryListSync(list.id), isTrue);
              case 'backfill':
                when(
                  () => client.subscribe(
                    any(),
                    closeOnEose: true,
                    onEose: any(named: 'onEose'),
                  ),
                ).thenAnswer((_) => const Stream<Event>.empty());
                await current.fetchUserListsFromRelays(force: true);
            }
            final event = sent.singleWhere((e) => e.kind == 30005);
            expect(
              event.tags.where((t) => t.first == 'e'),
              initialPublic ? isNotEmpty : isEmpty,
            );
            expect(current.getListById(list.id)!.isPublic, initialPublic);
            await restart();
            expect(open().getListById(list.id)!.isPublic, initialPublic);
          });
        }
      }
    }

    for (final entry in ['update', 'retry', 'add', 'backfill']) {
      test(
        'accepted private final-local-failure blocks $entry until explicit recovery and redacts '
        'the prior plaintext event',
        () async {
          final list = await seed();
          var rejectedFinal = false;
          backing.rejects = (key, value) {
            if (!key.endsWith(CuratedListService.listsStorageKey)) return false;
            final row =
                (jsonDecode(value as String) as List).single
                    as Map<String, dynamic>;
            final stored = CuratedList.fromJson(row);
            if (!rejectedFinal &&
                stored.nostrEventId != _oldEvent &&
                stored.nostrEventId != null &&
                !stored.pendingRepublish) {
              rejectedFinal = true;
              return true;
            }
            return false;
          };
          final original = open();
          expect(
            await original.updateList(listId: list.id, isPublic: false),
            isFalse,
          );
          expect(rejectedFinal, isTrue);
          expect(
            original.getListById(list.id)!.pendingVisibility!.relayAccepted,
            isTrue,
          );
          backing.rejects = null;
          await restart();
          final current = open();
          final beforeRecovery = sent.length;
          switch (entry) {
            case 'update':
              expect(
                await current.updateList(listId: list.id, name: 'Blocked'),
                isFalse,
              );
            case 'add':
              expect(await current.addVideoToList(list.id, 'd' * 64), isFalse);
            case 'backfill':
              when(
                () => client.subscribe(
                  any(),
                  closeOnEose: true,
                  onEose: any(named: 'onEose'),
                ),
              ).thenAnswer((_) => const Stream<Event>.empty());
              await current.fetchUserListsFromRelays(force: true);
            case 'retry':
              break;
          }
          expect(
            sent.length,
            beforeRecovery,
            reason: 'Unrelated edits and startup must not apply a pending permission target',
          );
          expect(await current.retryListSync(list.id), isTrue);
          switch (entry) {
            case 'update':
              expect(
                await current.updateList(listId: list.id, name: 'Recovered'),
                isTrue,
              );
            case 'retry':
              break;
            case 'add':
              expect(await current.addVideoToList(list.id, 'd' * 64), isTrue);
            case 'backfill':
              when(
                () => client.subscribe(
                  any(),
                  closeOnEose: true,
                  onEose: any(named: 'onEose'),
                ),
              ).thenAnswer((_) => const Stream<Event>.empty());
              await current.fetchUserListsFromRelays(force: true);
          }
          final redaction = sent.singleWhere((e) => e.kind == 5);
          expect(redaction.tags, contains(equals(['e', _oldEvent])));
          expect(redaction.tags.where((t) => t.first == 'a'), isEmpty);
          final privateEvent = sent
              .take(sent.indexOf(redaction))
              .where((e) => e.kind == 30005)
              .last;
          expect(privateEvent.tags.where((t) => t.first == 'e'), isEmpty);
          expect(redaction.createdAt, greaterThan(privateEvent.createdAt));
          expect(
            current.getListById(list.id)!.pendingPlaintextEventIds,
            isEmpty,
          );
          await restart();
          expect(open().getListById(list.id)!.isPublic, isFalse);
        },
      );
    }

    for (final failure in ['refused', 'throws']) {
      for (final allRecoveryWrites in [false, true]) {
        for (final transition in ['private', 'public', 'collaborators']) {
          test(
            'ACKed $transition with $failure recovery storage '
            '(all=$allRecoveryWrites) blocks edits until explicit Sync',
            () async {
              final list = await seed(isPublic: transition != 'public');
              var acknowledged = false;
              bool rejectsRecovery(String key, Object value) =>
                  acknowledged &&
                  (key.contains(CuratedListRecoveryJournal.storagePrefix) ||
                      (allRecoveryWrites &&
                          key.endsWith(CuratedListService.listsStorageKey)));
              if (failure == 'refused') {
                backing.rejects = rejectsRecovery;
              } else {
                backing.throwsOn = rejectsRecovery;
              }
              when(() => client.publishEventAwaitOk(any()))
                  .thenAnswer((i) async {
                    final event = i.positionalArguments.single as Event;
                    sent.add(event);
                    acknowledged = true;
                    return acceptedOutcome(event);
                  });
              when(() => client.subscribe(any(), closeOnEose: true))
                  .thenAnswer((_) => const Stream<Event>.empty());
              final current = open();
              expect(
                await current.updateList(
                  listId: list.id,
                  isPublic: transition == 'collaborators'
                      ? null
                      : transition == 'public',
                  isCollaborative: transition == 'collaborators' ? true : null,
                  allowedCollaborators: transition == 'collaborators'
                      ? [_video]
                      : null,
                ),
                isFalse,
              );
              final pending = current.getListById(list.id)!;
              expect(pending.hasPendingPermissionRecovery, isTrue);
              expect(
                pending.publicationTarget.isPublic,
                transition != 'private',
              );
              expect(pending.isPublic, list.isPublic);
              expect(sent, hasLength(1));
              expect(
                await current.updateList(listId: list.id, name: 'Blocked'),
                isFalse,
              );
              expect(await current.addVideoToList(list.id, 'd' * 64), isFalse);
              expect(
                await current.updateList(
                  listId: list.id,
                  isPublic: list.isPublic,
                ),
                isFalse,
              );
              await current.fetchUserListsFromRelays(force: true);
              expect(sent, hasLength(1));
              backing.rejects = null;
              backing.throwsOn = null;
              expect(await current.retryListSync(list.id), isTrue);
              expect(
                current.getListById(list.id)!.hasPendingPermissionRecovery,
                isFalse,
              );
              expect(
                current.getListById(list.id)!.isPublic,
                transition != 'private',
              );
              expect(
                await current.updateList(listId: list.id, name: 'Recovered'),
                isTrue,
              );
              await restart();
              expect(open().getListById(list.id)!.name, 'Recovered');
              expect(
                open().getListById(list.id)!.isPublic,
                transition != 'private',
              );
            },
          );
        }
      }
    }

    test(
      'unsaved permission ACK prevents logout from wiping the last row',
      () async {
        final list = await seed();
        await prefs.setString('current_user_pubkey_hex', _owner);
        var acknowledged = false;
        backing.rejects = (key, value) =>
            acknowledged &&
            key.contains(CuratedListRecoveryJournal.storagePrefix);
        when(() => client.publishEventAwaitOk(any())).thenAnswer((i) async {
          final event = i.positionalArguments.single as Event;
          sent.add(event);
          acknowledged = true;
          return acceptedOutcome(event);
        });
        final current = open();
        expect(
          await current.updateList(listId: list.id, isPublic: false),
          isFalse,
        );
        expect(
          current.getListById(list.id)!.hasPendingPermissionRecovery,
          isTrue,
        );
        await expectLater(
          UserDataCleanupService(prefs)
              .clearUserSpecificData(userPubkey: _owner),
          throwsStateError,
        );
        expect(current.isCurrentSession, isFalse);
        expect(prefs.containsKey(CuratedListService.listsStorageKey), isTrue);
        expect(sent, hasLength(1));
        backing.rejects = null;
        await UserDataCleanupService(prefs)
            .clearUserSpecificData(userPubkey: _owner);
        expect(prefs.containsKey(CuratedListService.listsStorageKey), isFalse);
        final recovery = CuratedListRecoveryJournal(
          prefs: prefs,
          runCurrent: (op) => op(),
        );
        expect(recovery.record(_owner, list.id)!.visibility!.isPublic, isFalse);
        expect(recovery.record(_owner, list.id)!.plaintextEventIds, [
          _oldEvent,
        ]);
      },
    );

    test(
      'pre-send write rejection restores the captured row without a send',
      () async {
        final list = await seed();
        backing.rejects = (key, value) {
          if (!key.endsWith(CuratedListService.listsStorageKey)) return false;
          final row =
              (jsonDecode(value as String) as List).single
                  as Map<String, dynamic>;
          return CuratedList.fromJson(row).pendingRepublish;
        };
        final current = open();
        var unknown = 0;
        expect(
          await current.updateList(
            listId: list.id,
            isPublic: false,
            onPublicationUnconfirmed: () => unknown++,
          ),
          isFalse,
        );
        expect(sent, isEmpty);
        expect(unknown, 0);
        expect(current.getListById(list.id)!.pendingRepublish, isFalse);
        expect(current.getListById(list.id)!.pendingVisibility, isNull);
        await restart();
        expect(open().getListById(list.id)!.pendingVisibility, isNull);
      },
    );

    test(
      'accepted journal rejection reports failure without false durability',
      () async {
        final list = await seed();
        backing.rejects = (key, value) {
          if (!key.endsWith(CuratedListService.listsStorageKey)) return false;
          final row =
              (jsonDecode(value as String) as List).single
                  as Map<String, dynamic>;
          return CuratedList.fromJson(row).pendingVisibility?.relayAccepted ==
              true;
        };
        final current = open();
        var unknown = 0;
        expect(
          await current.updateList(
            listId: list.id,
            isPublic: false,
            onPublicationUnconfirmed: () => unknown++,
          ),
          isFalse,
        );
        expect(sent.single.kind, 30005);
        expect(sent.single.tags.where((t) => t.first == 'e'), isEmpty);
        expect(
          unknown,
          0,
          reason: 'The relay did acknowledge this replacement',
        );
        expect(
          current.getListById(list.id)!.pendingVisibility?.relayAccepted,
          isTrue,
        );
        expect(await current.addVideoToList(list.id, 'd' * 64), isFalse);
        await restart();
        expect(
          open().getListById(list.id)!.pendingVisibility?.relayAccepted,
          isTrue,
        );
      },
    );

    for (final failure in ['timeout', 'signing', 'clock', 'final-write']) {
      test(
        'redaction $failure retains the prior ID across restart and retry',
        () => withClock(Clock.fixed(DateTime.now()), () async {
          final list = await seed();
          var privateAt = 0;
          when(() => client.publishEventAwaitOk(any())).thenAnswer((i) async {
            final event = i.positionalArguments.single as Event;
            sent.add(event);
            if (event.kind == 30005) privateAt = event.createdAt;
            if (event.kind == 5 && failure == 'timeout') {
              return PublishOutcome(
                eventId: event.id,
                acceptedBy: const [],
                rejectedBy: const {},
                noResponseFrom: const ['wss://relay.test'],
              );
            }
            return acceptedOutcome(event);
          });
          if (failure == 'signing') {
            when(
              () => auth.createAndSignEvent(
                kind: 5,
                content: any(named: 'content'),
                tags: any(named: 'tags'),
                createdAt: any(named: 'createdAt'),
              ),
            ).thenAnswer((_) async => null);
          }
          if (failure == 'final-write') {
            backing.rejects = (key, value) {
              if (!key.endsWith(CuratedListService.listsStorageKey)) {
                return false;
              }
              final row =
                  (jsonDecode(value as String) as List).single
                      as Map<String, dynamic>;
              final stored = CuratedList.fromJson(row);
              return !stored.isPublic &&
                  !stored.pendingRepublish &&
                  stored.pendingPlaintextEventIds.isEmpty;
            };
          }
          final current = failure == 'clock'
              ? CuratedListService(
                  nostrService: client,
                  authService: auth,
                  prefs: prefs,
                  maxPublishClockDrift: Duration.zero,
                )
              : open();
          if (failure == 'clock') addTearDown(current.dispose);
          expect(
            await current.updateList(listId: list.id, isPublic: false),
            isTrue,
          );
          expect(current.getListById(list.id)!.isPublic, isFalse);
          expect(current.getListById(list.id)!.pendingPlaintextEventIds, [
            _oldEvent,
          ]);
          backing.rejects = null;
          stubListPublishing(client: client, auth: auth, pubkey: _owner);
          sent.clear();
          when(() => client.publishEventAwaitOk(any())).thenAnswer((i) async {
            final event = i.positionalArguments.single as Event;
            sent.add(event);
            return acceptedOutcome(event);
          });
          await restart();
          final rebuilt = open();
          expect(await rebuilt.retryListSync(list.id), isTrue);
          final deletion = sent.single;
          expect(
            deletion.kind,
            5,
            reason: 'A redaction-only retry must not republish the list',
          );
          expect(deletion.createdAt, greaterThan(privateAt));
          expect(deletion.tags, contains(equals(['e', _oldEvent])));
          expect(
            rebuilt.getListById(list.id)!.pendingPlaintextEventIds,
            isEmpty,
          );
          await restart();
          expect(
            open().getListById(list.id)!.pendingPlaintextEventIds,
            isEmpty,
          );
        }),
      );
    }

    test(
      'service future drift rejection keeps a pending edit until clock catchup',
      () async {
        var now = DateTime.utc(2026, 10, 5);
        final source = CuratedList(
          id: 'clock',
          name: 'Before',
          pubkey: _owner,
          nostrEventId: _oldEvent,
          videoEventIds: const [_video],
          createdAt: now,
          updatedAt: now.add(const Duration(seconds: 2)),
        );
        await prefs.setString(
          CuratedListService.listsStorageKey,
          jsonEncode([source.toJson()]),
        );
        final current = CuratedListService(
          nostrService: client,
          authService: auth,
          prefs: prefs,
          maxPublishClockDrift: const Duration(seconds: 2),
        );
        addTearDown(current.dispose);
        await withClock(Clock(() => now), () async {
          var unknown = 0;
          expect(
            await current.updateList(
              listId: source.id,
              name: 'Later',
              onPublicationUnconfirmed: () => unknown++,
            ),
            isFalse,
          );
          expect(unknown, 0);
          expect(sent, isEmpty);
          expect(current.getListById(source.id)!.pendingRepublish, isTrue);
          now = now.add(const Duration(seconds: 1));
          expect(await current.retryListSync(source.id), isTrue);
          expect(
            sent.single.createdAt,
            source.updatedAt.millisecondsSinceEpoch ~/ 1000 + 1,
          );
        });
      },
    );

    test(
      'future relay rejection blocks a second service send until clock moves',
      () async {
        var now = DateTime.utc(2026, 10, 5);
        final source = CuratedList(
          id: 'future',
          name: 'Before',
          pubkey: _owner,
          nostrEventId: _oldEvent,
          videoEventIds: const [_video],
          createdAt: now,
          updatedAt: now,
        );
        await prefs.setString(
          CuratedListService.listsStorageKey,
          jsonEncode([source.toJson()]),
        );
        final current = open();
        when(() => client.publishEventAwaitOk(any())).thenAnswer((i) async {
          final event = i.positionalArguments.single as Event;
          sent.add(event);
          return PublishOutcome(
            eventId: event.id,
            acceptedBy: const [],
            rejectedBy: const {
              'wss://relay.test': 'invalid: created_at in future',
            },
            noResponseFrom: const [],
          );
        });
        await withClock(Clock(() => now), () async {
          var unknown = 0;
          expect(
            await current.updateList(
              listId: source.id,
              name: 'Later',
              onPublicationUnconfirmed: () => unknown++,
            ),
            isFalse,
          );
          expect(unknown, 0);
          expect(sent, hasLength(1));
          expect(await current.retryListSync(source.id), isFalse);
          expect(sent, hasLength(1));
          now = now.add(const Duration(seconds: 2));
          when(() => client.publishEventAwaitOk(any())).thenAnswer((i) async {
            final event = i.positionalArguments.single as Event;
            sent.add(event);
            return acceptedOutcome(event);
          });
          expect(await current.retryListSync(source.id), isTrue);
          expect(sent.last.createdAt, greaterThan(sent.first.createdAt));
        });
      },
    );
    for (final accepted in [false, true]) {
      test(
        'permissions-only save gates collaborators on acceptance=$accepted',
        () async {
          final alice = 'd' * 64;
          final bob = 'e' * 64;
          final original = (await seed()).copyWith(
            isCollaborative: true,
            allowedCollaborators: [alice],
          );
          await prefs.setString(
            CuratedListService.listsStorageKey,
            jsonEncode([original.toJson()]),
          );
          final current = open();
          final started = Completer<Event>();
          final decision = Completer<PublishOutcome>();
          when(() => client.publishEventAwaitOk(any())).thenAnswer((i) {
            final event = i.positionalArguments.single as Event;
            started.complete(event);
            return decision.future;
          });
          var unknown = 0;
          final saving = current.updateList(
            listId: original.id,
            allowedCollaborators: [bob],
            onPublicationUnconfirmed: () => unknown++,
          );
          final event = await started.future;
          expect(current.getListById(original.id)!.allowedCollaborators, [
            alice,
          ]);
          expect(event.tags, contains(equals(['collaborator', bob])));
          decision.complete(
            accepted
                ? acceptedOutcome(event)
                : PublishOutcome(
                    eventId: event.id,
                    acceptedBy: const [],
                    rejectedBy: const {},
                    noResponseFrom: const ['wss://relay.test'],
                  ),
          );
          expect(await saving, accepted);
          expect(unknown, accepted ? 0 : 1);
          expect(
            current.getListById(original.id)!.allowedCollaborators,
            accepted ? [bob] : [alice],
          );
          await restart();
          expect(
            open().getListById(original.id)!.allowedCollaborators,
            accepted ? [bob] : [alice],
          );
        },
      );
    }

    test(
      'direct collaborator mutation preserves accepted permissions on timeout',
      () async {
        final alice = 'd' * 64;
        final bob = 'e' * 64;
        final original = (await seed()).copyWith(
          isCollaborative: true,
          allowedCollaborators: [alice],
        );
        await prefs.setString(
          CuratedListService.listsStorageKey,
          jsonEncode([original.toJson()]),
        );
        final current = open();
        when(() => client.publishEventAwaitOk(any())).thenAnswer((i) async {
          final event = i.positionalArguments.single as Event;
          return PublishOutcome(
            eventId: event.id,
            acceptedBy: const [],
            rejectedBy: const {},
            noResponseFrom: const ['wss://relay.test'],
          );
        });
        expect(await current.addCollaborator(original.id, bob), isFalse);
        expect(current.getListById(original.id)!.allowedCollaborators, [alice]);
        await restart();
        expect(open().getListById(original.id)!.allowedCollaborators, [alice]);
      },
    );

    for (final action in ['dispose', 'clear-cache']) {
      test(
        'accepted ACK after $action cannot resurrect the old account row',
        () async {
          final list = await seed();
          final current = CuratedListService(
            nostrService: client,
            authService: auth,
            prefs: prefs,
          );
          var disposed = false;
          addTearDown(() {
            if (!disposed) current.dispose();
          });
          final started = Completer<Event>();
          final decision = Completer<PublishOutcome>();
          when(() => client.publishEventAwaitOk(any())).thenAnswer((i) {
            final event = i.positionalArguments.single as Event;
            started.complete(event);
            return decision.future;
          });
          final saving = current.updateList(listId: list.id, isPublic: false);
          final event = await started.future;
          if (action == 'dispose') {
            current.dispose();
            disposed = true;
          }
          await prefs.remove(CuratedListService.listsStorageKey);
          when(() => auth.currentPublicKeyHex).thenReturn('f' * 64);
          decision.complete(acceptedOutcome(event));
          expect(await saving, isFalse);
          expect(prefs.getString(CuratedListService.listsStorageKey), isNull);
          verify(() => client.publishEventAwaitOk(any())).called(1);
          verifyNever(() => client.publishEvent(any()));
          await restart();
          expect(open().lists, isEmpty);
        },
      );
    }

    test(
      'newer relay merge retains the durable event-specific redaction outbox',
      () async {
        final original = (await seed(
          isPublic: false,
        )).copyWith(pendingPlaintextEventIds: [_oldEvent]);
        await prefs.setString(
          CuratedListService.listsStorageKey,
          jsonEncode([original.toJson()]),
        );
        final current = open();
        final newer = Event(
          _owner,
          30005,
          [
            ['d', original.id],
            ['title', 'Newer'],
            ['e', _video],
          ],
          'Updated on another device',
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        );
        when(
          () => client.subscribe(
            any(),
            closeOnEose: true,
            onEose: any(named: 'onEose'),
          ),
        ).thenAnswer((_) => Stream.value(newer));
        when(() => client.publishEventAwaitOk(any())).thenAnswer((i) async {
          final event = i.positionalArguments.single as Event;
          sent.add(event);
          return PublishOutcome(
            eventId: event.id,
            acceptedBy: const [],
            rejectedBy: const {},
            noResponseFrom: const ['wss://relay.test'],
          );
        });
        await current.fetchUserListsFromRelays(force: true);
        expect(current.getListById(original.id)!.name, 'Newer');
        expect(current.getListById(original.id)!.pendingPlaintextEventIds, [
          _oldEvent,
        ]);
        expect(sent.single.kind, 5);
        await restart();
        expect(open().getListById(original.id)!.pendingPlaintextEventIds, [
          _oldEvent,
        ]);
      },
    );
    for (final entry in ['rename', 'added video']) {
      test(
        'a later $entry keeps the queued plaintext ID until the deletion '
        'is accepted',
        () async {
          final list = await seed();
          var deletionAnswered = false;
          when(() => client.publishEventAwaitOk(any())).thenAnswer((i) async {
            final event = i.positionalArguments.single as Event;
            sent.add(event);
            if (event.kind == 5 && !deletionAnswered) {
              return PublishOutcome(
                eventId: event.id,
                acceptedBy: const [],
                rejectedBy: const {},
                noResponseFrom: const ['wss://relay.test'],
              );
            }
            return acceptedOutcome(event);
          });
          final current = open();
          expect(
            await current.updateList(listId: list.id, isPublic: false),
            isTrue,
          );
          expect(current.getListById(list.id)!.pendingPlaintextEventIds, [
            _oldEvent,
          ]);

          final later = entry == 'rename'
              ? await current.updateList(listId: list.id, name: 'Renamed')
              : await current.addVideoToList(list.id, 'd' * 64);
          expect(later, isTrue);
          expect(current.getListById(list.id)!.pendingPlaintextEventIds, [
            _oldEvent,
          ], reason: 'the deletion was never answered');

          deletionAnswered = true;
          sent.clear();
          expect(
            await current.updateList(listId: list.id, name: 'Settled'),
            isTrue,
          );
          expect(
            sent.where(
              (e) =>
                  e.kind == 5 &&
                  e.tags.any((t) => t[0] == 'e' && t[1] == _oldEvent),
            ),
            hasLength(1),
          );
          expect(
            current.getListById(list.id)!.pendingPlaintextEventIds,
            isEmpty,
          );
          await restart();
          expect(
            open().getListById(list.id)!.pendingPlaintextEventIds,
            isEmpty,
          );
        },
      );
    }

    test(
      'a relay replacement that made the list private queues the old '
      'plaintext ID and requests its deletion',
      () async {
        final original = await seed();
        final current = open();
        final sealed = Event(
          _owner,
          30005,
          [
            ['d', original.id],
            ['title', 'Sealed on another device'],
          ],
          sealForTest(
            jsonEncode([
              ['e', _video],
            ]),
          ),
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        );
        when(
          () => client.subscribe(
            any(),
            closeOnEose: true,
            onEose: any(named: 'onEose'),
          ),
        ).thenAnswer((_) => Stream.value(sealed));
        await current.fetchUserListsFromRelays(force: true);
        expect(current.getListById(original.id)!.isPublic, isFalse);
        final deletion = sent.single;
        expect(deletion.kind, 5);
        expect(deletion.tags, contains(equals(['e', _oldEvent])));
        expect(
          current.getListById(original.id)!.pendingPlaintextEventIds,
          isEmpty,
        );
        await restart();
        expect(
          open().getListById(original.id)!.pendingPlaintextEventIds,
          isEmpty,
        );
      },
    );

    test(
      'ACKed public transition rejects every unrelated edit until Sync now',
      () async {
        final list = await seed(isPublic: false);
        var rejectedFinal = false;
        backing.rejects = (key, value) {
          if (!key.endsWith(CuratedListService.listsStorageKey)) return false;
          final saved = CuratedList.fromJson(
            (jsonDecode(value as String) as List).single
                as Map<String, dynamic>,
          );
          if (!rejectedFinal &&
              saved.isPublic &&
              !saved.pendingRepublish &&
              saved.pendingVisibility == null) {
            rejectedFinal = true;
            return true;
          }
          return false;
        };
        final initial = open();
        expect(
          await initial.updateList(listId: list.id, isPublic: true),
          isFalse,
        );
        expect(rejectedFinal, isTrue);
        expect(initial.getListById(list.id)!.isPublic, isFalse);
        expect(
          initial.getListById(list.id)!.hasPendingPermissionRecovery,
          isTrue,
        );
        backing.rejects = null;
        await restart();
        final current = open();
        final before = sent.length;
        expect(await current.addVideoToList(list.id, 'd' * 64), isFalse);
        expect(await current.removeVideoFromList(list.id, _video), isFalse);
        expect(
          await current.updateList(listId: list.id, name: 'Must wait'),
          isFalse,
        );
        expect(
          await current.updateList(listId: list.id, isPublic: false),
          isFalse,
        );
        expect(await current.addCollaborator(list.id, 'e' * 64), isFalse);
        when(
          () => client.subscribe(
            any(),
            closeOnEose: true,
            onEose: any(named: 'onEose'),
          ),
        ).thenAnswer((_) => const Stream<Event>.empty());
        await current.fetchUserListsFromRelays(force: true);
        expect(sent.length, before);
        expect(current.getListById(list.id)!.videoEventIds, [_video]);
        expect(await current.retryListSync(list.id), isTrue);
        expect(current.getListById(list.id)!.isPublic, isTrue);
        expect(
          current.getListById(list.id)!.hasPendingPermissionRecovery,
          isFalse,
        );
        expect(await current.addVideoToList(list.id, 'd' * 64), isTrue);
        expect(sent.last.tags, contains(equals(['e', 'd' * 64])));
      },
    );

    test(
      'failed durable relay merge never backfills and a later read can retry',
      () async {
        final local = (await seed(isPublic: false))
            .copyWith(clearNostrEventId: true);
        await prefs.setString(
          CuratedListService.listsStorageKey,
          jsonEncode([local.toJson()]),
        );
        final event = Event(
          _owner,
          30005,
          [
            ['d', local.id],
            ['title', 'Relay copy'],
            ['e', 'd' * 64],
          ],
          '',
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        );
        when(
          () => client.subscribe(
            any(),
            closeOnEose: true,
            onEose: any(named: 'onEose'),
          ),
        ).thenAnswer((_) => Stream.value(event));
        final current = open();
        backing.rejects = (key, _) =>
            key.endsWith(CuratedListService.listsStorageKey);
        await current.fetchUserListsFromRelays();
        expect(sent, isEmpty);
        backing.rejects = null;
        await current.fetchUserListsFromRelays();
        final publication = sent.singleWhere((e) => e.kind == 30005);
        expect(publication.tags.where((tag) => tag.first == 'e'), isEmpty);
        final deletion = sent.singleWhere((e) => e.kind == 5);
        expect(deletion.tags, contains(equals(['e', event.id])));
        verify(
          () => client.subscribe(
            any(),
            closeOnEose: true,
            onEose: any(named: 'onEose'),
          ),
        ).called(2);
      },
    );

    for (final failure in ['rejected', 'no answer']) {
      test(
        'unpublished private/public union keeps every plaintext ID across $failure and restart',
        () async {
          final local = (await seed(isPublic: false)).copyWith(
            clearNostrEventId: true,
            pendingPlaintextEventIds: [_oldEvent],
          );
          await prefs.setString(
            CuratedListService.listsStorageKey,
            jsonEncode([local.toJson()]),
          );
          final relay = Event(
            _owner,
            30005,
            [
              ['d', local.id],
              ['title', 'Public copy'],
              ['e', 'd' * 64],
            ],
            '',
            createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          );
          when(
            () => client.subscribe(
              any(),
              closeOnEose: true,
              onEose: any(named: 'onEose'),
            ),
          ).thenAnswer((_) => Stream.value(relay));
          when(() => client.publishEventAwaitOk(any())).thenAnswer((i) async {
            final event = i.positionalArguments.single as Event;
            sent.add(event);
            if (event.kind == 30005) return acceptedOutcome(event);
            return PublishOutcome(
              eventId: event.id,
              acceptedBy: const [],
              rejectedBy: failure == 'rejected'
                  ? const {'wss://relay.test': 'blocked'}
                  : const {},
              noResponseFrom: failure == 'no answer'
                  ? const ['wss://relay.test']
                  : const [],
            );
          });
          final current = open();
          await current.fetchUserListsFromRelays(force: true);
          final publication = sent.singleWhere((event) => event.kind == 30005);
          expect(publication.tags.where((tag) => tag.first == 'e'), isEmpty);
          expect(current.getListById(local.id)!.isPublic, isFalse);
          expect(
            current.getListById(local.id)!.videoEventIds,
            containsAll([_video, 'd' * 64]),
          );
          expect(
            current.getListById(local.id)!.pendingPlaintextEventIds,
            containsAll([_oldEvent, relay.id]),
          );
          await restart();
          final resumed = open();
          expect(
            resumed.getListById(local.id)!.pendingPlaintextEventIds,
            containsAll([_oldEvent, relay.id]),
          );
          sent.clear();
          when(() => client.publishEventAwaitOk(any())).thenAnswer((i) async {
            final event = i.positionalArguments.single as Event;
            sent.add(event);
            return acceptedOutcome(event);
          });
          expect(await resumed.retryListSync(local.authorScopedId), isTrue);
          expect(sent.where((event) => event.kind == 30005), isEmpty);
          expect(
            sent
                .where((event) => event.kind == 5)
                .map(
                  (event) =>
                      event.tags.singleWhere((tag) => tag.first == 'e')[1],
                ),
            unorderedEquals([_oldEvent, relay.id]),
          );
          expect(
            resumed.getListById(local.id)!.pendingPlaintextEventIds,
            isEmpty,
          );
        },
      );
    }

    test(
      'unpublished public/public union never queues a plaintext deletion',
      () async {
        final local = (await seed()).copyWith(clearNostrEventId: true);
        await prefs.setString(
          CuratedListService.listsStorageKey,
          jsonEncode([local.toJson()]),
        );
        final relay = Event(
          _owner,
          30005,
          [
            ['d', local.id],
            ['title', 'Public copy'],
            ['e', 'd' * 64],
          ],
          '',
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        );
        when(
          () => client.subscribe(
            any(),
            closeOnEose: true,
            onEose: any(named: 'onEose'),
          ),
        ).thenAnswer((_) => Stream.value(relay));
        final current = open();
        await current.fetchUserListsFromRelays(force: true);
        final publication = sent.singleWhere((event) => event.kind == 30005);
        expect(publication.tags.where((tag) => tag.first == 'e'), hasLength(2));
        expect(sent.where((event) => event.kind == 5), isEmpty);
        expect(current.getListById(local.id)!.isPublic, isTrue);
        expect(
          current.getListById(local.id)!.pendingPlaintextEventIds,
          isEmpty,
        );
      },
    );

    for (final incomplete in ['timeout', 'error']) {
      test(
        'real finite-read contract requests EOSE; $incomplete never backfills',
        () async {
          final local = (await seed()).copyWith(pendingRepublish: true);
          await prefs.setString(
            CuratedListService.listsStorageKey,
            jsonEncode([local.toJson()]),
          );
          final controller = StreamController<Event>.broadcast();
          addTearDown(controller.close);
          when(
            () => client.subscribe(
              any(),
              closeOnEose: true,
              onEose: any(named: 'onEose'),
            ),
          ).thenAnswer(
            (_) => incomplete == 'timeout'
                ? controller.stream
                : Stream<Event>.error(StateError('relay unavailable')),
          );
          final current = CuratedListService(
            nostrService: client,
            authService: auth,
            prefs: prefs,
            relaySyncTimeout: const Duration(milliseconds: 5),
          );
          addTearDown(current.dispose);
          await current.fetchUserListsFromRelays(force: true);
          expect(sent, isEmpty);
          expect(current.getListById(local.id)!.pendingRepublish, isTrue);
          verify(
            () => client.subscribe(
              any(),
              closeOnEose: true,
              onEose: any(named: 'onEose'),
            ),
          ).called(1);
        },
      );
    }

    test('a public relay row after logout cannot certify a pending private union or delete its copy', () async {
      final local = (await seed(isPublic: false)).copyWith(
        clearNostrEventId: true,
        pendingPlaintextEventIds: [_oldEvent],
      );
      await prefs.setString(
        CuratedListService.listsStorageKey,
        jsonEncode([local.toJson()]),
      );
      await prefs.setString('current_user_pubkey_hex', _owner);
      await UserDataCleanupService(prefs)
          .clearUserSpecificData(userPubkey: _owner);
      final relay = Event(
        _owner,
        30005,
        [
          ['d', local.id],
          ['title', 'Public relay copy'],
          ['e', _video],
        ],
        '',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      when(
        () => client.subscribe(
          any(),
          closeOnEose: true,
          onEose: any(named: 'onEose'),
        ),
      ).thenAnswer((_) => Stream.value(relay));
      final current = open();
      await current.fetchUserListsFromRelays(force: true);
      expect(sent, isEmpty);
      expect(await current.retryListSync(local.authorScopedId), isFalse);
      expect(sent, isEmpty);
      final journal = CuratedListRecoveryJournal(
        prefs: prefs,
        runCurrent: (op) => op(),
      );
      expect(journal.record(_owner, local.id)!.requiresPrivateCommit, isTrue);
      expect(current.getListById(local.id)!.isPublic, isTrue);
      expect(
        await current.updateList(listId: local.id, isPublic: false),
        isTrue,
      );
      final sealed = sent.singleWhere((event) => event.kind == 30005);
      expect(sealed.tags.where((tag) => tag.first == 'e'), isEmpty);
      expect(
        sent
            .where((event) => event.kind == 5)
            .map(
              (event) => event.tags.singleWhere((tag) => tag.first == 'e')[1],
            ),
        unorderedEquals([_oldEvent, relay.id]),
      );
      expect(journal.records(_owner), isEmpty);
    });

    test('owner-scoped deletion retry works after list-cache wipe without recreating a row', () async {
      final local = (await seed(isPublic: false))
          .copyWith(pendingPlaintextEventIds: [_oldEvent]);
      await prefs.setString(
        CuratedListService.listsStorageKey,
        jsonEncode([local.toJson()]),
      );
      await CuratedListRecoveryJournal.migrateEmbeddedRecords(
        prefs,
        legacyOwner: _owner,
      );
      await prefs.remove(CuratedListService.listsStorageKey);
      await restart();
      final current = open();
      expect(await current.retryListSync(local.authorScopedId), isTrue);
      expect(sent.single.kind, 5);
      expect(sent.single.tags, contains(equals(['e', _oldEvent])));
      expect(current.lists, isEmpty);
      expect(prefs.getString(CuratedListService.listsStorageKey), isNull);
      expect(
        prefs.getString(CuratedListRecoveryJournal.storageKey(_owner)),
        isNull,
      );
    });

    test(
      'late ACK cannot overwrite a newer in-service relay replacement',
      () async {
        final list = await seed();
        final current = open();
        final started = Completer<Event>();
        final decision = Completer<PublishOutcome>();
        when(() => client.publishEventAwaitOk(any())).thenAnswer((i) {
          final event = i.positionalArguments.single as Event;
          if (event.kind == 5) return Future.value(acceptedOutcome(event));
          started.complete(event);
          return decision.future;
        });
        var unknown = 0;
        final saving = current.updateList(
          listId: list.id,
          name: 'Older local',
          isPublic: false,
          onPublicationUnconfirmed: () => unknown++,
        );
        final sentEvent = await started.future;
        final collaborator = 'd' * 64;
        final newer = Event(
          _owner,
          30005,
          [
            ['d', list.id],
            ['title', 'Newer relay'],
            ['e', _video],
            ['collaborative', 'true'],
            ['collaborator', collaborator],
          ],
          'Newer description',
          createdAt: sentEvent.createdAt + 10,
        );
        when(
          () => client.subscribe(
            any(),
            closeOnEose: true,
            onEose: any(named: 'onEose'),
          ),
        ).thenAnswer((_) => Stream.value(newer));
        await current.fetchUserListsFromRelays(force: true);
        final winning = current.getListById(list.id)!;
        expect(winning.name, 'Newer relay');
        expect(winning.isPublic, isTrue);
        expect(winning.allowedCollaborators, [collaborator]);
        decision.complete(acceptedOutcome(sentEvent));
        expect(await saving, isFalse);
        expect(unknown, 0, reason: 'The older event was actually acknowledged');
        expect(current.getListById(list.id), winning);
        await restart();
        final resumed = open().getListById(list.id)!;
        expect(
          resumed,
          winning.copyWith(pendingPlaintextEventIds: [_oldEvent]),
        );
        final journal = CuratedListRecoveryJournal(
          prefs: prefs,
          runCurrent: (op) => op(),
        );
        expect(journal.record(_owner, list.id)!.visibility, isNull);
        expect(journal.record(_owner, list.id)!.plaintextEventIds, [_oldEvent]);
        expect(journal.record(_owner, list.id)!.requiresPrivateCommit, isTrue);
        expect(sent.where((event) => event.kind == 5), isEmpty);
      },
    );
    test(
      'scoped privacy edit and unscoped item addition share one queue',
      () async {
        final list = await seed();
        final current = open();
        final started = Completer<Event>();
        final decision = Completer<PublishOutcome>();
        when(() => client.publishEventAwaitOk(any())).thenAnswer((i) {
          final event = i.positionalArguments.single as Event;
          if (event.kind == 5) return Future.value(acceptedOutcome(event));
          started.complete(event);
          return decision.future;
        });
        final saving = current.updateList(
          listId: list.authorScopedId,
          isPublic: false,
        );
        final privateEvent = await started.future;
        final adding = current.addVideoToList(list.id, 'd' * 64);
        await pumpEventQueue();
        expect(current.getListById(list.id)!.videoEventIds, [_video]);
        verify(() => client.publishEventAwaitOk(any())).called(1);
        verifyNever(() => client.publishEvent(any()));
        decision.complete(acceptedOutcome(privateEvent));
        expect(await saving, isTrue);
        expect(await adding, isTrue);
        final itemEvent = sent.singleWhere((event) => event.kind == 30005);
        expect(itemEvent.tags.where((tag) => tag.first == 'e'), isEmpty);
        expect(unsealForTest(itemEvent.content), contains('d' * 64));
        expect(current.getListById(list.id)!.isPublic, isFalse);
      },
    );

    test('a privacy ACK after ordinary logout durably belongs only to its captured owner', () async {
      final list = await seed();
      await prefs.setString('current_user_pubkey_hex', _owner);
      final departing = open();
      final started = Completer<Event>();
      final decision = Completer<PublishOutcome>();
      when(() => client.publishEventAwaitOk(any())).thenAnswer((i) {
        final event = i.positionalArguments.single as Event;
        started.complete(event);
        return decision.future;
      });
      final saving = departing.updateList(listId: list.id, isPublic: false);
      final attempted = await started.future;
      await UserDataCleanupService(prefs)
          .clearUserSpecificData(userPubkey: _owner);
      const incoming =
          'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
      when(() => auth.currentPublicKeyHex).thenReturn(incoming);
      stubListPublishing(client: client, auth: auth, pubkey: incoming);
      final active = open();
      decision.complete(acceptedOutcome(attempted));
      expect(await saving, isFalse);
      expect(departing.isCurrentSession, isFalse);
      expect(active.isCurrentSession, isTrue);
      expect(active.lists, isEmpty);
      await restart();
      final journal = CuratedListRecoveryJournal(
        prefs: prefs,
        runCurrent: (op) => op(),
      );
      expect(journal.record(_owner, list.id)!.visibility!.isPublic, isFalse);
      expect(journal.record(_owner, list.id)!.plaintextEventIds, [_oldEvent]);
      expect(journal.records(incoming), isEmpty);
      expect(prefs.containsKey(CuratedListService.listsStorageKey), isFalse);
      expect(sent.where((event) => event.kind == 5), isEmpty);
    });

    test('inactive-account deletion rejects its held ACK even after the same pubkey is re-added', () async {
      final list = await seed();
      await prefs.setString('current_user_pubkey_hex', _owner);
      final departing = open();
      final started = Completer<Event>();
      final decision = Completer<PublishOutcome>();
      when(() => client.publishEventAwaitOk(any())).thenAnswer((i) {
        final event = i.positionalArguments.single as Event;
        started.complete(event);
        return decision.future;
      });
      final saving = departing.updateList(listId: list.id, isPublic: false);
      final attempted = await started.future;
      final cleanup = UserDataCleanupService(prefs);
      await cleanup.clearUserSpecificData(userPubkey: _owner);
      const incoming =
          'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
      when(() => auth.currentPublicKeyHex).thenReturn(incoming);
      stubListPublishing(client: client, auth: auth, pubkey: incoming);
      await prefs.setString('current_user_pubkey_hex', incoming);
      final active = open();
      final journal = CuratedListRecoveryJournal(
        prefs: prefs,
        runCurrent: (op) => op(),
      );
      expect(
        await journal.captureRows([
          list.copyWith(pubkey: incoming, pendingPlaintextEventIds: [_video]),
        ], incoming),
        isTrue,
      );
      await cleanup.deleteAccountData(
        _owner,
        userNpub: 'npub-departed',
        preserveActiveSession: true,
      );
      expect(active.isCurrentSession, isTrue);
      expect(journal.record(incoming, list.id)!.plaintextEventIds, [_video]);
      await cleanup.clearUserSpecificData(
        isIdentityChange: true,
        userPubkey: _owner,
      );
      when(() => auth.currentPublicKeyHex).thenReturn(_owner);
      stubListPublishing(client: client, auth: auth, pubkey: _owner);
      final readded = open();
      decision.complete(acceptedOutcome(attempted));
      expect(await saving, isFalse);
      expect(readded.isCurrentSession, isTrue);
      await restart();
      expect(prefs.getInt(CuratedListRecoveryStorage.generationKey(_owner)), 1);
      expect(
        prefs.containsKey(CuratedListRecoveryJournal.storageKey(_owner)),
        isFalse,
      );
      expect(
        CuratedListRecoveryJournal(
          prefs: prefs,
          runCurrent: (op) => op(),
        ).record(incoming, list.id)!.plaintextEventIds,
        [_video],
      );
      expect(sent.where((event) => event.kind == 5), isEmpty);
    });

    for (final throwing in [false, true]) {
      test(
        'account deletion stops before removing evidence when its durable generation ${throwing ? 'throws' : 'is refused'}',
        () async {
          final list = (await seed()).copyWith(
            pendingPlaintextEventIds: [_oldEvent],
          );
          final journal = CuratedListRecoveryJournal(
            prefs: prefs,
            runCurrent: (op) => op(),
          );
          expect(await journal.captureRows([list], _owner), isTrue);
          final key = CuratedListRecoveryStorage.generationKey(_owner);
          if (throwing) {
            backing.throwsOn = (candidate, _) => candidate.endsWith(key);
          } else {
            backing.rejects = (candidate, _) => candidate.endsWith(key);
          }
          await expectLater(
            UserDataCleanupService(prefs).deleteAccountData(
              _owner,
              userNpub: 'npub-owner',
              preserveActiveSession: true,
            ),
            throwsA(isA<CuratedListRecoveryException>()),
          );
          await restart();
          expect(prefs.containsKey(key), isFalse);
          expect(
            prefs.getString(CuratedListService.listsStorageKey),
            isNotNull,
          );
          expect(
            prefs.getString(CuratedListRecoveryJournal.storageKey(_owner)),
            contains(_oldEvent),
          );
        },
      );
    }

    test('a corrupt journal allows durable quarantine logout but prevents edits and deletion retries', () async {
      final list = await seed();
      final key = CuratedListRecoveryJournal.storageKey(_owner);
      const raw = '{private recovery malformed';
      await prefs.setString(key, raw);
      final current = open();
      expect(current.recoveryNeedsRepair, isTrue);
      await expectLater(
        current.prepareRecovery(),
        throwsA(isA<CuratedListRecoveryException>()),
      );
      expect(
        await current.updateList(listId: list.id, isPublic: false),
        isFalse,
      );
      expect(await current.retryListSync(list.authorScopedId), isFalse);
      expect(await current.deleteOwnedList(list.id), isFalse);
      expect(sent, isEmpty);
      await UserDataCleanupService(prefs)
          .clearUserSpecificData(userPubkey: _owner);
      await restart();
      expect(prefs.getString(key), raw);
      expect(
        prefs.getString(CuratedListRecoveryStorage.quarantineKey(_owner)),
        contains(raw),
      );
      expect(prefs.containsKey(CuratedListService.listsStorageKey), isFalse);
      expect(open().recoveryNeedsRepair, isTrue);
    });

    for (final throwing in [false, true]) {
      test(
        'default recreation cannot reuse accepted permissions after retirement ${throwing ? 'throws' : 'is refused'}',
        () async {
          final original = (await seed(isPublic: false))
              .copyWith(id: CuratedListService.defaultListId);
          await prefs.setString(
            CuratedListService.listsStorageKey,
            jsonEncode([original.toJson()]),
          );
          final journal = CuratedListRecoveryJournal(
            prefs: prefs,
            runCurrent: (op) => op(),
          );
          expect(
            await journal.accepted(
              owner: _owner,
              listId: original.id,
              visibility: CuratedListVisibility(
                isPublic: true,
                isCollaborative: true,
                allowedCollaborators: ['e' * 64],
                relayAccepted: true,
              ),
              eventId: _video,
              acceptedAt: clock.now(),
              plaintextEventIds: [_oldEvent],
            ),
            isTrue,
          );
          final current = open();
          final key = CuratedListRecoveryJournal.storageKey(_owner);
          bool retirement(String candidate, Object value) =>
              candidate.endsWith(key) &&
              value is String &&
              value.contains('"permissionsRetired":true');
          if (throwing) {
            backing.throwsOn = retirement;
          } else {
            backing.rejects = retirement;
          }
          expect(await current.deleteOwnedList(original.id), isFalse);
          await restart();
          expect(
            jsonDecode(prefs.getString(CuratedListService.listsStorageKey)!)
                as List,
            isEmpty,
          );
          final resumed = open();
          expect(
            await resumed.deleteOwnedList(original.authorScopedId),
            isFalse,
          );
          expect(resumed.getDefaultList(), isNull);
          backing.throwsOn = null;
          backing.rejects = null;
          expect(
            await resumed.deleteOwnedList(original.authorScopedId),
            isTrue,
          );
          await restart();
          final retired = CuratedListRecoveryJournal(
            prefs: prefs,
            runCurrent: (op) => op(),
          ).record(_owner, original.id)!;
          expect(retired.visibility, isNull);
          expect(retired.plaintextEventIds, [_oldEvent]);
          expect(retired.permissionsRetired, isTrue);
          // Existing explicit restore resets this preference before initialize.
          await prefs.setBool(
            CuratedListService.defaultListDeletedStorageKey,
            false,
          );
          when(
            () => client.subscribe(
              any(),
              closeOnEose: true,
              onEose: any(named: 'onEose'),
            ),
          ).thenAnswer((_) => const Stream.empty());
          sent.clear();
          final restored = open();
          await restored.initialize();
          final created = restored.getDefaultList()!;
          expect(created.isPublic, isFalse);
          expect(created.isCollaborative, isFalse);
          expect(created.allowedCollaborators, isEmpty);
          expect(created.hasPendingPermissionRecovery, isFalse);
          expect(await restored.retryListSync(created.authorScopedId), isTrue);
          await restart();
          final durable = open().getDefaultList()!;
          expect(durable.isPublic, isFalse);
          expect(durable.isCollaborative, isFalse);
          expect(durable.allowedCollaborators, isEmpty);
          expect(durable.hasPendingPermissionRecovery, isFalse);
          expect(
            sent
                .where((event) => event.kind == 5)
                .any(
                  (event) => event.tags.any(
                    (tag) =>
                        tag.length > 1 && tag[0] == 'e' && tag[1] == _oldEvent,
                  ),
                ),
            isTrue,
          );
          final replacements = sent
              .where((event) => event.kind == 30005)
              .toList();
          expect(replacements, isNotEmpty);
          expect(durable.nostrEventId, replacements.last.id);
          expect(
            replacements.every(
              (event) => event.tags.every((tag) => tag[0] != 'e'),
            ),
            isTrue,
          );
          expect(
            replacements.every((event) => unsealForTest(event.content) != null),
            isTrue,
          );
          final redactionIndex = sent.indexWhere(
            (event) =>
                event.kind == 5 &&
                event.tags.any(
                  (tag) =>
                      tag.length > 1 && tag[0] == 'e' && tag[1] == _oldEvent,
                ),
          );
          expect(redactionIndex, greaterThan(sent.indexOf(replacements.first)));
        },
      );
    }

    for (final throwing in [false, true]) {
      test(
        'inactive-account recovery deletion is retryable after removal ${throwing ? 'throws' : 'is refused'}',
        () async {
          final list = (await seed()).copyWith(
            pendingPlaintextEventIds: [_oldEvent],
          );
          final journal = CuratedListRecoveryJournal(
            prefs: prefs,
            runCurrent: (op) => op(),
          );
          const incoming =
              'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
          expect(await journal.captureRows([list], _owner), isTrue);
          expect(
            await journal.captureRows([
              list.copyWith(
                pubkey: incoming,
                pendingPlaintextEventIds: [_video],
              ),
            ], incoming),
            isTrue,
          );
          final quarantine = CuratedListRecoveryStorage.quarantineKey(_owner);
          final rawQuarantine = jsonEncode({
            'rawBuckets': ['{malformed accepted evidence'],
            'records': <String, Object>{},
          });
          await prefs.setString(quarantine, rawQuarantine);
          await prefs.remove(CuratedListService.listsStorageKey);
          when(() => auth.currentPublicKeyHex).thenReturn(incoming);
          stubListPublishing(client: client, auth: auth, pubkey: incoming);
          final active = open();
          final key = CuratedListRecoveryJournal.storageKey(_owner);
          if (throwing) {
            backing.throwsRemoval = key;
          } else {
            backing.rejectsRemoval = key;
          }
          await expectLater(
            UserDataCleanupService(prefs).deleteAccountData(
              _owner,
              userNpub: 'npub-owner',
              preserveActiveSession: true,
            ),
            throwsA(isA<CuratedListRecoveryException>()),
          );
          expect(active.isCurrentSession, isTrue);
          await restart();
          expect(prefs.getString(key), contains(_oldEvent));
          expect(prefs.getString(quarantine), rawQuarantine);
          expect(
            prefs.getString(CuratedListRecoveryJournal.storageKey(incoming)),
            contains(_video),
          );
          backing.throwsRemoval = null;
          backing.rejectsRemoval = null;
          await UserDataCleanupService(prefs).deleteAccountData(
            _owner,
            userNpub: 'npub-owner',
            preserveActiveSession: true,
          );
          await restart();
          expect(prefs.containsKey(key), isFalse);
          expect(prefs.containsKey(quarantine), isFalse);
          expect(
            prefs.getInt(CuratedListRecoveryStorage.generationKey(_owner)),
            2,
          );
          expect(
            prefs.getString(CuratedListRecoveryJournal.storageKey(incoming)),
            contains(_video),
          );
        },
      );
    }

    Object malformedLegacy(String form, CuratedList healthyRow) =>
        switch (form) {
          'non-string' => ['PRIVATE_UNKNOWN_LEGACY_VALUE'],
          'invalid JSON' => '{PRIVATE_UNKNOWN_LEGACY_VALUE',
          'non-list' => '{"PRIVATE_UNKNOWN_LEGACY_VALUE":true}',
          'non-map row' => '["PRIVATE_UNKNOWN_LEGACY_VALUE"]',
          _ => jsonEncode([
            healthyRow.toJson(),
            {
              ...healthyRow.toJson(),
              'id': 'broken',
              'name': 'PRIVATE_UNKNOWN_LEGACY_VALUE',
              'createdAt': 'PRIVATE_UNKNOWN_LEGACY_VALUE',
            },
          ]),
        };

    Future<void> storeMalformedLegacy(Object raw) async {
      if (raw is String) {
        await prefs.setString(CuratedListService.listsStorageKey, raw);
      } else {
        await prefs.setStringList(
          CuratedListService.listsStorageKey,
          raw as List<String>,
        );
      }
    }

    for (final form in [
      'non-string',
      'invalid JSON',
      'non-list',
      'non-map row',
      'partially corrupt row',
    ]) {
      for (final destructive in [false, true]) {
        test(
          '${destructive ? 'destructive A cleanup' : 'ordinary logout'} preserves unknown-owner $form legacy evidence and healthy B recovery',
          () async {
            const other =
                'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
            final list = (await seed()).copyWith(pubkey: other);
            final journal = CuratedListRecoveryJournal(
              prefs: prefs,
              runCurrent: (op) => op(),
            );
            expect(
              await journal.accepted(
                owner: other,
                listId: list.id,
                visibility: const CuratedListVisibility(
                  isPublic: false,
                  isCollaborative: false,
                  allowedCollaborators: [],
                  relayAccepted: true,
                ),
                eventId: _video,
                acceptedAt: clock.now(),
                plaintextEventIds: [_oldEvent],
              ),
              isTrue,
            );
            final raw = malformedLegacy(form, list);
            await storeMalformedLegacy(raw);
            final cleanup = UserDataCleanupService(prefs);
            await expectLater(
              destructive
                  ? cleanup.deleteAccountData(
                      _owner,
                      userNpub: 'npub-A',
                      preserveActiveSession: false,
                    )
                  : cleanup.clearUserSpecificData(userPubkey: _owner),
              throwsA(
                isA<CuratedListRecoveryException>().having(
                  (error) => error.toString(),
                  'safe reason',
                  isNot(contains('PRIVATE_UNKNOWN_LEGACY_VALUE')),
                ),
              ),
            );
            await restart();
            expect(prefs.get(CuratedListService.listsStorageKey), raw);
            final recovered = CuratedListRecoveryJournal(
              prefs: prefs,
              runCurrent: (op) => op(),
            );
            expect(
              recovered.record(other, list.id)!.visibility!.isPublic,
              isFalse,
            );
            expect(recovered.record(other, list.id)!.plaintextEventIds, [
              _oldEvent,
            ]);
            expect(
              prefs.containsKey(CuratedListRecoveryJournal.storageKey(_owner)),
              isFalse,
            );
            expect(sent, isEmpty);
          },
        );
      }

      test(
        'startup and direct creates cannot replace unknown-owner $form legacy evidence',
        () async {
          final raw = malformedLegacy(form, await seed());
          await storeMalformedLegacy(raw);
          final logs = LogCaptureService();
          await logs.clearAllLogs();
          final current = open();
          expect(current.recoveryNeedsRepair, isTrue);
          await expectLater(
            current.prepareRecovery(),
            throwsA(isA<CuratedListRecoveryException>()),
          );
          await current.initialize().catchError((Object _) {});
          expect(current.isInitialized, isFalse);
          expect(current.getDefaultList(), isNull);
          expect(await current.createList(name: 'New list'), isNull);
          expect(sent, isEmpty);
          final captured = (await logs.getAllLogsAsText()).join('\n');
          expect(
            captured,
            contains('Failed to initialize curated list service'),
          );
          expect(captured, isNot(contains('PRIVATE_UNKNOWN_LEGACY_VALUE')));
          await restart();
          expect(prefs.get(CuratedListService.listsStorageKey), raw);
          expect(open().recoveryNeedsRepair, isTrue);
        },
      );
    }
  });
}
