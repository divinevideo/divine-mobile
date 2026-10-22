// ABOUTME: Verifies retained relay sources, version fences and account cleanup.
// ABOUTME: Uses real signed encrypted events and a controllable preference backend.

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';
import 'package:openvine/services/auth/pending_account_cleanup.dart';
import 'package:openvine/services/curated_list_relay_gateway.dart';
import 'package:openvine/services/curated_lists/curated_list_recovery_journal.dart';
import 'package:openvine/services/curated_lists/curated_list_relay_evidence.dart';
import 'package:openvine/services/curated_lists/curated_list_session_coordinator.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

const _video =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _id = 'retained:list/🌱';

class _Storage extends InMemorySharedPreferencesStore {
  _Storage() : super.empty();
  bool refuseWrite = false;
  bool refuseRemove = false;
  Completer<void>? entered;
  Completer<void>? release;
  Completer<void>? removalEntered;
  Completer<void>? removalRelease;

  @override
  Future<bool> setValue(String type, String key, Object value) async {
    if (key.contains(CuratedListRelayEvidence.storagePrefix)) {
      if (entered?.isCompleted == false) entered!.complete();
      if (release != null) await release!.future;
      if (refuseWrite) return false;
    }
    return super.setValue(type, key, value);
  }

  @override
  Future<bool> remove(String key) async {
    if (key.contains(CuratedListRelayEvidence.storagePrefix)) {
      if (removalEntered?.isCompleted == false) removalEntered!.complete();
      if (removalRelease != null) await removalRelease!.future;
    }
    if (refuseRemove && key.contains(CuratedListRelayEvidence.storagePrefix)) {
      return false;
    }
    return super.remove(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('CuratedListRelayEvidence', () {
    late SharedPreferencesStorePlatform previousBackend;
    late _Storage backend;
    late SharedPreferences prefs;
    late LocalNostrSigner signer;
    late LocalNostrSigner otherSigner;
    late String owner;
    late String otherOwner;
    late CuratedListSessionLease lease;
    late CuratedListRelayEvidence evidence;

    CuratedList list({String id = _id, String? pubkey}) => CuratedList(
      id: id,
      name: 'Cached collection',
      pubkey: pubkey ?? owner,
      videoEventIds: const [_video],
      isPublic: false,
      createdAt: DateTime.utc(2000),
      updatedAt: DateTime.utc(2000),
    );

    CuratedListRelayEvidence createEvidence(String activeOwner) {
      final sessions = CuratedListSessionCoordinator.forPreferences(prefs);
      final capturedLease = sessions.acquire();
      lease = capturedLease;
      addTearDown(capturedLease.retire);
      return CuratedListRelayEvidence(
        preferences: prefs,
        currentOwner: () => activeOwner,
        isCurrentSession: () => capturedLease.isCurrent,
        runEvidence: sessions.writes.runExclusive,
        runCurrent: (operation) => sessions.runCurrent<bool>(
          capturedLease,
          operation,
          cancelled: false,
        ),
      );
    }

    Future<Event> event({
      String id = _id,
      int at = 1700000000,
      LocalNostrSigner? author,
      String? plaintext,
    }) async {
      final signing = author ?? signer;
      final pubkey = (await signing.getPublicKey())!;
      final ciphertext = await signing.nip44Encrypt(
        pubkey,
        plaintext ??
            jsonEncode([
              ['e', _video],
            ]),
      );
      final result = Event(
        pubkey,
        30005,
        [
          ['d', id],
          ['title', 'Private collection'],
        ],
        ciphertext!,
        createdAt: at,
      );
      await signing.signEvent(result);
      expect(result.isValid && result.isSigned, isTrue);
      return result;
    }

    setUp(() async {
      previousBackend = SharedPreferencesStorePlatform.instance;
      backend = _Storage();
      SharedPreferencesStorePlatform.instance = backend;
      SharedPreferences.resetStatic();
      prefs = await SharedPreferences.getInstance();
      signer = LocalNostrSigner('1'.padLeft(64, '0'));
      otherSigner = LocalNostrSigner('2'.padLeft(64, '0'));
      owner = (await signer.getPublicKey())!;
      otherOwner = (await otherSigner.getPublicKey())!;
      evidence = createEvidence(owner);
    });

    tearDown(() {
      SharedPreferences.resetStatic();
      SharedPreferencesStorePlatform.instance = previousBackend;
    });

    test(
      'holds synchronously while preserving the original encrypted source',
      () async {
        final incoming = await event();
        backend.entered = Completer<void>();
        backend.release = Completer<void>();
        final retaining = evidence.observe(incoming);
        expect(evidence.allows(list()), isFalse);
        expect(evidence.allows(list(id: 'unrelated')), isTrue);
        await backend.entered!.future;
        backend.release!.complete();
        expect(await retaining, isTrue);
        await prefs.reload();
        final raw = prefs.getString(
          CuratedListRelayEvidence.storageKey(owner, _id),
        )!;
        expect(
          (jsonDecode(raw) as Map<String, dynamic>)['event'],
          incoming.toJson(),
        );
        expect(raw, isNot(contains(_video)));
      },
    );

    test(
      'retained source and coordinate hold survive a cold preference reload',
      () async {
        final incoming = await event();
        expect(await evidence.observe(incoming), isTrue);
        lease.retire();
        SharedPreferences.resetStatic();
        prefs = await SharedPreferences.getInstance();
        evidence = createEvidence(owner);
        expect(evidence.allows(list()), isFalse);
        expect(evidence.retainedFor(list())!.toJson(), incoming.toJson());
        expect(evidence.allows(list(id: 'unrelated')), isTrue);
      },
    );

    test(
      'complete decoding alone cannot release evidence before cache save',
      () async {
        final incoming = await event();
        await evidence.observe(incoming);
        expect(
          evidence.decoded(incoming, const UnsealedItemTags.failed()),
          isFalse,
        );
        expect(
          evidence.decoded(
            incoming,
            const UnsealedItemTags.unsealed([
              ['e', _video],
            ]),
          ),
          isFalse,
        );
        expect(
          evidence.decoded(
            incoming,
            const UnsealedItemTags.unsealed(
              [
                ['e', _video],
              ],
              hasCompleteItemSnapshot: true,
            ),
          ),
          isTrue,
        );
        expect(evidence.allows(list()), isFalse);
        await evidence.reconciled([incoming]);
        expect(evidence.allows(list()), isTrue);
        expect(
          prefs.containsKey(CuratedListRelayEvidence.storageKey(owner, _id)),
          isFalse,
        );
      },
    );

    test(
      'older and empty readbacks cannot retire a newer opaque revision',
      () async {
        final older = await event();
        final newer = await event(at: 1700000001);
        await evidence.observe(newer);
        expect(await evidence.observe(older), isFalse);
        expect(
          evidence.decoded(
            older,
            const UnsealedItemTags.unsealed(
              [
                ['e', _video],
              ],
              hasCompleteItemSnapshot: true,
            ),
          ),
          isFalse,
        );
        await evidence.reconciled([older]);
        await evidence.reconciled([]);
        expect(evidence.allows(list()), isFalse);
        expect(evidence.retainedFor(list())!.id, newer.id);
      },
    );

    test(
      'refused evidence writes retain the hold and retry the original source',
      () async {
        final incoming = await event();
        backend.refuseWrite = true;
        expect(await evidence.observe(incoming), isFalse);
        expect(evidence.allows(list()), isFalse);
        expect(evidence.retainedFor(list())!.toJson(), incoming.toJson());
        expect(
          prefs.containsKey(CuratedListRelayEvidence.storageKey(owner, _id)),
          isFalse,
        );
        backend.refuseWrite = false;
        expect(await evidence.observe(incoming), isTrue);
        expect(evidence.allows(list()), isFalse);
      },
    );

    test(
      'retirement during a dispatched write cannot release its retained hold',
      () async {
        final incoming = await event();
        backend.entered = Completer<void>();
        backend.release = Completer<void>();
        final retaining = evidence.observe(incoming);
        await backend.entered!.future;
        lease.retire();
        backend.release!.complete();
        expect(await retaining, isTrue);
        evidence = createEvidence(owner);
        expect(evidence.allows(list()), isFalse);
        expect(evidence.retainedFor(list())!.toJson(), incoming.toJson());
      },
    );

    test(
      'refused verified removal leaves the raw revision and hold intact',
      () async {
        final incoming = await event();
        await evidence.observe(incoming);
        evidence.decoded(
          incoming,
          const UnsealedItemTags.unsealed(
            [
              ['e', _video],
            ],
            hasCompleteItemSnapshot: true,
          ),
        );
        backend.refuseRemove = true;
        await evidence.reconciled([incoming]);
        expect(evidence.allows(list()), isFalse);
        expect(
          prefs.containsKey(CuratedListRelayEvidence.storageKey(owner, _id)),
          isTrue,
        );
      },
    );

    test(
      'a newer header during old removal survives retirement and restart',
      () async {
        final older = await event();
        final newer = await event(at: 1700000001);
        await evidence.observe(older);
        evidence.decoded(
          older,
          const UnsealedItemTags.unsealed(
            [
              ['e', _video],
            ],
            hasCompleteItemSnapshot: true,
          ),
        );
        backend.removalEntered = Completer<void>();
        backend.removalRelease = Completer<void>();
        final resolving = evidence.reconciled([older]);
        await backend.removalEntered!.future;
        final retaining = evidence.observe(newer);
        expect(evidence.allows(list()), isFalse);
        lease.retire();
        backend.removalRelease!.complete();
        await resolving;
        expect(await retaining, isTrue);
        SharedPreferences.resetStatic();
        prefs = await SharedPreferences.getInstance();
        evidence = createEvidence(owner);
        expect(evidence.allows(list()), isFalse);
        expect(evidence.retainedFor(list())!.toJson(), newer.toJson());
      },
    );

    test(
      'cleanup generation rejects queued source writes after owner deletion',
      () async {
        final incoming = await event();
        final entered = Completer<void>();
        final release = Completer<void>();
        final sessions = CuratedListSessionCoordinator.forPreferences(prefs);
        final deleting = sessions.writes.runExclusive(() async {
          entered.complete();
          await release.future;
          await CuratedListRecoveryJournal.invalidateOwner(prefs, owner);
          expect(
            await CuratedListRelayEvidence.removeOwner(prefs, owner),
            isTrue,
          );
        });
        await entered.future;
        final retaining = evidence.observe(incoming);
        lease.retire();
        release.complete();
        await deleting;
        expect(await retaining, isFalse);
        expect(
          prefs.getKeys().where(
            (key) => key.startsWith(CuratedListRelayEvidence.storagePrefix),
          ),
          isEmpty,
        );
      },
    );

    test(
      'corrupt retained bytes remain untouched and hold only their coordinate',
      () async {
        final key = CuratedListRelayEvidence.storageKey(owner, _id);
        const raw = '{damaged retained evidence';
        await prefs.setString(key, raw);
        evidence = createEvidence(owner);
        expect(evidence.allows(list()), isFalse);
        expect(evidence.allows(list(id: 'unrelated')), isTrue);
        expect(await evidence.observe(await event()), isFalse);
        expect(prefs.getString(key), raw);
      },
    );

    test(
      'foreign and unauthenticated headers cannot create an owner hold',
      () async {
        await evidence.observe(await event(author: otherSigner));
        final forged = Event.fromJson({
          ...(await event()).toJson(),
          'sig': '0' * 128,
        });
        await evidence.observe(forged);
        expect(evidence.allows(list()), isTrue);
        expect(prefs.getKeys(), isEmpty);
      },
    );

    test(
      'another account retains full use of its own matching raw d-tag',
      () async {
        await evidence.observe(await event());
        final otherEvidence = createEvidence(otherOwner);
        expect(otherEvidence.allows(list(pubkey: otherOwner)), isTrue);
        expect(otherEvidence.retainedFor(list(pubkey: otherOwner)), isNull);
      },
    );

    test('a known-owner malformed coordinate holds that owner without affecting another', () async {
      await prefs.setString(
        '${CuratedListRelayEvidence.storagePrefix}$owner:??',
        '{damaged source',
      );
      evidence = createEvidence(owner);
      expect(evidence.allows(list(id: 'unrelated')), isFalse);
      final otherEvidence = createEvidence(otherOwner);
      expect(otherEvidence.allows(list(pubkey: otherOwner)), isTrue);
    });

    test(
      'unknown-owner damaged evidence keeps the shared conservative hold',
      () async {
        await prefs.setString(
          '${CuratedListRelayEvidence.storagePrefix}unknown',
          '{damaged source',
        );
        evidence = createEvidence(owner);
        expect(evidence.allows(list()), isFalse);
        final otherEvidence = createEvidence(otherOwner);
        expect(otherEvidence.allows(list(pubkey: otherOwner)), isFalse);
      },
    );

    test(
      'large private item sources are retained without truncation or plaintext',
      () async {
        final items = [
          for (var i = 0; i < 700; i++)
            ['e', i.toRadixString(16).padLeft(64, '0')],
        ];
        final incoming = await event(plaintext: jsonEncode(items));
        expect(await evidence.observe(incoming), isTrue);
        final raw = prefs.getString(
          CuratedListRelayEvidence.storageKey(owner, _id),
        )!;
        expect(raw.length, greaterThan(65000));
        expect(evidence.retainedFor(list())!.toJson(), incoming.toJson());
        expect(raw, isNot(contains(jsonEncode(items))));
      },
    );

    test(
      'ordinary sign-out and account switches preserve both owners evidence',
      () async {
        final first = await event();
        final second = await event(author: otherSigner);
        await evidence.observe(first);
        final otherEvidence = createEvidence(otherOwner);
        await otherEvidence.observe(second);
        final before = {
          for (final key in prefs.getKeys()) key: prefs.get(key),
        };
        final cleanup = UserDataCleanupService(prefs);
        await cleanup.clearUserSpecificData(userPubkey: owner);
        await cleanup.clearUserSpecificData(
          userPubkey: otherOwner,
          isIdentityChange: true,
        );
        for (final entry in before.entries) {
          expect(prefs.get(entry.key), entry.value);
        }
      },
    );

    for (final inactive in [false, true]) {
      test(
        'verified account deletion removes only its owner (inactive=$inactive)',
        () async {
          await evidence.observe(await event());
          final otherEvidence = createEvidence(otherOwner);
          await otherEvidence.observe(await event(author: otherSigner));
          final otherKey = CuratedListRelayEvidence.storageKey(otherOwner, _id);
          final retainedOther = prefs.get(otherKey);
          final cleanup = UserDataCleanupService(prefs);
          if (inactive) {
            await cleanup.deleteAccountData(
              owner,
              userNpub: NostrKeyUtils.encodePubKey(owner),
              preserveActiveSession: true,
            );
          } else {
            await cleanup.clearUserSpecificData(
              userPubkey: owner,
              deleteUserData: true,
            );
          }
          expect(
            prefs.containsKey(CuratedListRelayEvidence.storageKey(owner, _id)),
            isFalse,
          );
          expect(prefs.get(otherKey), retainedOther);
        },
      );
    }

    test(
      'unreadable known-owner deletion stays incomplete without erasing it',
      () async {
        final key = CuratedListRelayEvidence.storageKey(owner, _id);
        await prefs.setString(key, '{damaged source');
        final cleanup = UserDataCleanupService(prefs);
        await expectLater(
          cleanup.clearUserSpecificData(
            userPubkey: owner,
            deleteUserData: true,
          ),
          throwsA(isA<UserDataCleanupException>()),
        );
        expect(prefs.get(key), '{damaged source');
        expect(prefs.containsKey(PendingAccountCleanup.storageKey), isTrue);
      },
    );

    test('unknown-owner evidence prevents a false complete deletion', () async {
      const key = '${CuratedListRelayEvidence.storagePrefix}unknown-owner';
      await prefs.setString(key, '{damaged unknown source');
      expect(await CuratedListRelayEvidence.removeOwner(prefs, owner), isFalse);
      expect(prefs.get(key), '{damaged unknown source');
    });

    test(
      'another known owners damaged record does not prevent scoped deletion',
      () async {
        await evidence.observe(await event());
        final otherKey = CuratedListRelayEvidence.storageKey(otherOwner, _id);
        await prefs.setString(otherKey, '{damaged other owner source');
        expect(
          await CuratedListRelayEvidence.removeOwner(prefs, owner),
          isTrue,
        );
        expect(prefs.get(otherKey), '{damaged other owner source');
      },
    );

    test(
      'verified foreign bytes under an unknown key remain foreign at deletion',
      () async {
        const key = '${CuratedListRelayEvidence.storagePrefix}unknown-key';
        final foreign = await event(author: otherSigner);
        final raw = jsonEncode({'version': 1, 'event': foreign.toJson()});
        await prefs.setString(key, raw);
        expect(
          await CuratedListRelayEvidence.removeOwner(prefs, owner),
          isTrue,
        );
        expect(prefs.get(key), raw);
      },
    );

    group('misindexed authenticated sources', () {
      String encoded(Event value) =>
          jsonEncode({'version': 1, 'event': value.toJson()});

      UnsealedItemTags completeItems() => const UnsealedItemTags.unsealed(
        [
          ['e', _video],
        ],
        hasCompleteItemSnapshot: true,
      );

      test(
        'misindexed authenticated source holds its verified owner coordinate',
        () async {
          final incoming = await event(author: otherSigner);
          final wrongKey = CuratedListRelayEvidence.storageKey(owner, _id);
          final raw = encoded(incoming);
          await prefs.setString(wrongKey, raw);
          final otherEvidence = createEvidence(otherOwner);

          expect(otherEvidence.allows(list(pubkey: otherOwner)), isFalse);
          expect(
            otherEvidence.allows(list(id: 'unrelated', pubkey: otherOwner)),
            isTrue,
          );
          expect(evidence.allows(list()), isTrue);
          expect(
            otherEvidence.retainedFor(list(pubkey: otherOwner))!.toJson(),
            incoming.toJson(),
          );
          expect(prefs.get(wrongKey), raw);
          expect(prefs.getKeys(), {wrongKey});
        },
      );

      test(
        'verified payload under unknown namespace holds only its coordinate',
        () async {
          const wrongKey =
              '${CuratedListRelayEvidence.storagePrefix}unknown-key';
          final incoming = await event(author: otherSigner);
          final raw = encoded(incoming);
          await prefs.setString(wrongKey, raw);
          final otherEvidence = createEvidence(otherOwner);

          expect(otherEvidence.allows(list(pubkey: otherOwner)), isFalse);
          expect(
            otherEvidence.allows(list(id: 'unrelated', pubkey: otherOwner)),
            isTrue,
          );
          expect(evidence.allows(list()), isTrue);
          expect(prefs.get(wrongKey), raw);
        },
      );

      test(
        'cold reload retains original misindexed bytes without relocating',
        () async {
          final incoming = await event(author: otherSigner);
          final wrongKey = CuratedListRelayEvidence.storageKey(owner, 'alias');
          final raw = encoded(incoming);
          await prefs.setString(wrongKey, raw);
          lease.retire();
          SharedPreferences.resetStatic();
          prefs = await SharedPreferences.getInstance();
          final otherEvidence = createEvidence(otherOwner);

          expect(otherEvidence.allows(list(pubkey: otherOwner)), isFalse);
          expect(
            otherEvidence.retainedFor(list(pubkey: otherOwner))!.toJson(),
            incoming.toJson(),
          );
          expect(prefs.get(wrongKey), raw);
          expect(prefs.getKeys(), {wrongKey});
        },
      );

      test(
        'misindexed source waits for complete cache reconciliation',
        () async {
          final incoming = await event(author: otherSigner);
          final wrongKey = CuratedListRelayEvidence.storageKey(owner, 'alias');
          final raw = encoded(incoming);
          await prefs.setString(wrongKey, raw);
          final otherEvidence = createEvidence(otherOwner);

          expect(otherEvidence.decoded(incoming, completeItems()), isTrue);
          expect(otherEvidence.allows(list(pubkey: otherOwner)), isFalse);
          expect(prefs.get(wrongKey), raw);
          await otherEvidence.reconciled([incoming]);
          expect(prefs.containsKey(wrongKey), isFalse);
          expect(otherEvidence.allows(list(pubkey: otherOwner)), isTrue);
        },
      );

      test(
        'only newest verified revision can retire all older coordinate copies',
        () async {
          final older = await event(author: otherSigner);
          final newer = await event(author: otherSigner, at: 1700000001);
          final oldKey = CuratedListRelayEvidence.storageKey(
            owner,
            'old-alias',
          );
          final newKey = CuratedListRelayEvidence.storageKey(
            otherOwner,
            'new-alias',
          );
          await prefs.setString(oldKey, encoded(older));
          await prefs.setString(newKey, encoded(newer));
          final otherEvidence = createEvidence(otherOwner);

          expect(
            otherEvidence.retainedFor(list(pubkey: otherOwner))!.id,
            newer.id,
          );
          expect(await otherEvidence.observe(older), isFalse);
          expect(otherEvidence.decoded(older, completeItems()), isFalse);
          await otherEvidence.reconciled([older]);
          expect(prefs.get(oldKey), encoded(older));
          expect(prefs.get(newKey), encoded(newer));
          expect(otherEvidence.decoded(newer, completeItems()), isTrue);
          await otherEvidence.reconciled([newer]);
          expect(prefs.containsKey(oldKey), isFalse);
          expect(prefs.containsKey(newKey), isFalse);
          expect(otherEvidence.allows(list(pubkey: otherOwner)), isTrue);
        },
      );

      test(
        'changed raw payload refreshes verification and preserves newer source',
        () async {
          final older = await event(author: otherSigner);
          final newer = await event(author: otherSigner, at: 1700000001);
          final wrongKey = CuratedListRelayEvidence.storageKey(owner, 'alias');
          await prefs.setString(wrongKey, encoded(older));
          final otherEvidence = createEvidence(otherOwner);
          expect(otherEvidence.decoded(older, completeItems()), isTrue);
          await prefs.setString(wrongKey, encoded(newer));

          await otherEvidence.reconciled([older]);
          expect(prefs.get(wrongKey), encoded(newer));
          expect(otherEvidence.allows(list(pubkey: otherOwner)), isFalse);
          expect(
            otherEvidence.retainedFor(list(pubkey: otherOwner))!.id,
            newer.id,
          );
        },
      );

      test(
        'reconciliation preserves foreign and damaged physical sources',
        () async {
          final incoming = await event(author: otherSigner);
          final foreign = await event(id: 'alice-list');
          final ownKey = CuratedListRelayEvidence.storageKey(
            owner,
            'bob-alias',
          );
          final foreignKey = CuratedListRelayEvidence.storageKey(
            otherOwner,
            'alice-alias',
          );
          final damagedKey = CuratedListRelayEvidence.storageKey(
            owner,
            'damaged',
          );
          await prefs.setString(ownKey, encoded(incoming));
          await prefs.setString(foreignKey, encoded(foreign));
          await prefs.setString(damagedKey, '{damaged source');
          final otherEvidence = createEvidence(otherOwner);
          expect(otherEvidence.decoded(incoming, completeItems()), isTrue);

          await otherEvidence.reconciled([incoming]);
          expect(prefs.containsKey(ownKey), isFalse);
          expect(prefs.get(foreignKey), encoded(foreign));
          expect(prefs.get(damagedKey), '{damaged source');
          expect(otherEvidence.allows(list(pubkey: otherOwner)), isTrue);
        },
      );

      test(
        'refused duplicate erasure retains evidence until verified retry',
        () async {
          final incoming = await event(author: otherSigner);
          final first = CuratedListRelayEvidence.storageKey(owner, 'first');
          final second = CuratedListRelayEvidence.storageKey(
            otherOwner,
            'second',
          );
          final raw = encoded(incoming);
          await prefs.setString(first, raw);
          await prefs.setString(second, raw);
          final otherEvidence = createEvidence(otherOwner);
          expect(otherEvidence.decoded(incoming, completeItems()), isTrue);
          backend.refuseRemove = true;

          await otherEvidence.reconciled([incoming]);
          expect(otherEvidence.allows(list(pubkey: otherOwner)), isFalse);
          expect(prefs.get(first), raw);
          expect(prefs.get(second), raw);
          backend.refuseRemove = false;
          await otherEvidence.reconciled([incoming]);
          expect(prefs.containsKey(first), isFalse);
          expect(prefs.containsKey(second), isFalse);
          expect(otherEvidence.allows(list(pubkey: otherOwner)), isTrue);
        },
      );

      test(
        'owner deletion uses signed payload ownership across wrong namespaces',
        () async {
          final incoming = await event(author: otherSigner);
          final foreign = await event(id: 'alice-list');
          final ownKey = CuratedListRelayEvidence.storageKey(
            owner,
            'bob-alias',
          );
          final foreignKey = CuratedListRelayEvidence.storageKey(
            otherOwner,
            'alice-alias',
          );
          await prefs.setString(ownKey, encoded(incoming));
          await prefs.setString(foreignKey, encoded(foreign));

          expect(
            await CuratedListRelayEvidence.removeOwner(prefs, otherOwner),
            isTrue,
          );
          expect(prefs.containsKey(ownKey), isFalse);
          expect(prefs.get(foreignKey), encoded(foreign));
        },
      );
    });

    test(
      'refused source erasure keeps destructive cleanup incomplete',
      () async {
        await evidence.observe(await event());
        final key = CuratedListRelayEvidence.storageKey(owner, _id);
        final raw = prefs.get(key);
        backend.refuseRemove = true;
        await expectLater(
          UserDataCleanupService(prefs).clearUserSpecificData(
            userPubkey: owner,
            deleteUserData: true,
          ),
          throwsA(isA<UserDataCleanupException>()),
        );
        expect(prefs.get(key), raw);
        expect(prefs.containsKey(PendingAccountCleanup.storageKey), isTrue);
      },
    );
  });
}
