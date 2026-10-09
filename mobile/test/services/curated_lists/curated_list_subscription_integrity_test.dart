// ABOUTME: Preserves unreadable Follow data and real rejected native overlays.
// ABOUTME: Exercises queued ownership claims and later verified repair writes.
import 'dart:convert';

import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/services/curated_lists/prefs_curated_list_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

const String owner =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const String author =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const String existing = '$author:existing';
const String refused = '$author:refused-follow';
const String added = '$author:added-follow';
const String repairedOther = '$author:independently-repaired-follow';
const String listsKey = CuratedListService.listsStorageKey;
const String followsKey = CuratedListService.subscribedListsStorageKey;

class RefusingBackend extends InMemorySharedPreferencesStore {
  RefusingBackend(super.data) : super.withData();
  bool refuses = false;
  bool throwsNative = false;
  int followAttempts = 0;
  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key == 'flutter.$followsKey') {
      followAttempts++;
      if (refuses) {
        if (throwsNative) throw PlatformException(code: 'controlled-refusal');
        return false;
      }
    }
    return super.setValue(valueType, key, value);
  }
}

CuratedList localDraft() => CuratedList(
  id: 'local-draft',
  name: 'Local draft',
  videoEventIds: const [],
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

PrefsCuratedListStore store(
  SharedPreferences prefs,
  CuratedListCacheWriteCoordinator coordinator,
  Set<String> baseline,
) =>
    PrefsCuratedListStore(
        prefs: prefs,
        writeCoordinator: coordinator,
        listsStorageKey: listsKey,
        subscriptionsStorageKey: followsKey,
        defaultListDeletedStorageKey:
            CuratedListService.defaultListDeletedStorageKey,
      )
      ..subscriptionsLoaded(baseline)
      ..listsLoaded([localDraft()]);

Future<(SharedPreferences, RefusingBackend)> setup(Object raw) async {
  final oldPlatform = SharedPreferencesStorePlatform.instance;
  final backend = RefusingBackend({
    'flutter.$followsKey': raw,
    'flutter.$listsKey': jsonEncode([localDraft().toJson()]),
  });
  SharedPreferences.resetStatic();
  SharedPreferencesStorePlatform.instance = backend;
  addTearDown(() {
    SharedPreferences.resetStatic();
    SharedPreferencesStorePlatform.instance = oldPlatform;
  });
  return (await SharedPreferences.getInstance(), backend);
}

Future<bool> corruptOptimistic(SharedPreferences prefs, Object raw) =>
    raw is bool
    ? prefs.setBool(followsKey, raw)
    : prefs.setString(followsKey, raw as String);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('Follow evidence and queued ownership claims', () {
    const malformed = <String, Object>{
      'malformed-json': '{"private-evidence":',
      'mixed-null': '["$existing",null]',
      'wrong-native-type': true,
    };
    for (final entry in malformed.entries) {
      for (final caller in ['early-claim', 'coordinated-claim']) {
        test(
          '$caller retains a genuine rejected follow overlay after ${entry.key}',
          () async {
            final (prefs, backend) = await setup(jsonEncode([existing]));
            final coordinator = CuratedListCacheWriteCoordinator();
            final adapter = store(prefs, coordinator, {existing});
            backend.refuses = true;
            final rejection = await adapter.saveSubscriptionsWithResult({
              existing,
              refused,
            });
            expect(rejection.status, CuratedCacheWriteStatus.storageRejected);
            expect((jsonDecode(prefs.getString(followsKey)!) as List).toSet(), {
              existing,
              refused,
            });
            final rejectedDurable = await backend.getAll();
            expect(
              (jsonDecode(
                rejectedDurable['flutter.$followsKey']! as String,
              ) as List).toSet(),
              {existing},
            );
            expect(await corruptOptimistic(prefs, entry.value), isFalse);
            final callsBeforeClaim = backend.followAttempts;
            bool denied;
            if (caller == 'early-claim') {
              denied = !adapter.canClaimLocalList(
                localDraft(),
                '$owner:local-draft',
              );
            } else {
              final claimed = localDraft().copyWith(pubkey: owner);
              final result = await adapter.saveListsWithResult(
                [claimed],
                ownershipClaims: {claimed.authorScopedId: localDraft()},
              );
              denied = result.status == CuratedCacheWriteStatus.conflict;
              expect(result.persisted, isNull);
              expect(
                result.acknowledgedBeforeWrite,
                [localDraft()],
                reason: 'Readable list acknowledgement is distinct from unreadable follow evidence.',
              );
            }
            expect(denied, isTrue);
            expect(backend.followAttempts, callsBeforeClaim);
            expect(prefs.get(followsKey), entry.value);
            expect(
              await prefs.setString(
                followsKey,
                jsonEncode([existing, refused]),
              ),
              isFalse,
            );
            backend.refuses = false;
            final next = await adapter.saveSubscriptionsWithResult({
              existing,
              added,
            });
            final finalDurable = await backend.getAll();
            final actual = (jsonDecode(
              finalDurable['flutter.$followsKey']! as String,
            ) as List).cast<String>().toSet();

            expect(next.succeeded, isTrue);
            expect(
              actual,
              {existing, added},
              reason: 'An invalid follow fallback must not retire genuine native-refusal bookkeeping and revive a rejected follow.',
            );
          },
        );
      }
      for (final emptyBaseline in [false, true]) {
        test(
          'invalid follow read ${entry.key} has no fresh acknowledged evidence (empty=$emptyBaseline)',
          () async {
            final (prefs, backend) = await setup(entry.value);
            final baseline = emptyBaseline ? <String>{} : {existing};
            final adapter = store(
              prefs,
              CuratedListCacheWriteCoordinator(),
              baseline,
            );
            final beforeAttempts = backend.followAttempts;
            final result = await adapter.saveSubscriptionsWithResult({
              ...baseline,
              added,
            });

            expect(result.status, CuratedCacheWriteStatus.storageRejected);
            expect(result.persisted, isNull);
            expect(
              result.acknowledgedBeforeWrite,
              isNull,
              reason: 'Unreadable storage proves only the prior baseline; it cannot claim a new acknowledged-before-write snapshot.',
            );
            expect(result.baseline, baseline);
            expect(result.reconcile({...baseline, added}), baseline);
            expect(backend.followAttempts, beforeAttempts);
            expect(prefs.get(followsKey), entry.value);
            expect(
              await prefs.setString(
                followsKey,
                jsonEncode([...baseline, repairedOther]),
              ),
              isTrue,
            );
            final retry = await adapter.saveSubscriptionsWithResult({
              ...baseline,
              added,
            });
            expect(retry.succeeded, isTrue);
            expect((jsonDecode(prefs.getString(followsKey)!) as List).toSet(), {
              ...baseline,
              repairedOther,
              added,
            });
          },
        );
      }
    }
    for (final throwsNative in [false, true]) {
      test(
        'readable native ${throwsNative ? 'exception' : 'false'} retains ordinary rejection bookkeeping',
        () async {
          final (prefs, backend) = await setup(jsonEncode([existing]));
          final adapter = store(prefs, CuratedListCacheWriteCoordinator(), {
            existing,
          });
          backend.refuses = true;
          backend.throwsNative = throwsNative;
          final rejected = await adapter.saveSubscriptionsWithResult({
            existing,
            refused,
          });
          expect(rejected.status, CuratedCacheWriteStatus.storageRejected);
          expect(rejected.acknowledgedBeforeWrite, {existing});
          backend.refuses = false;
          backend.throwsNative = false;
          expect(
            (await adapter.saveSubscriptionsWithResult({
              existing,
              added,
            })).succeeded,
            isTrue,
          );
          expect((jsonDecode(prefs.getString(followsKey)!) as List).toSet(), {
            existing,
            added,
          });
        },
      );
    }
    test(
      'readable ownership claim and genuine follows remain supported',
      () async {
        final (prefs, _) = await setup(jsonEncode([existing]));
        final adapter = store(prefs, CuratedListCacheWriteCoordinator(), {
          existing,
        });
        expect(
          adapter.canClaimLocalList(localDraft(), '$owner:local-draft'),
          isTrue,
        );
        final claimed = localDraft().copyWith(pubkey: owner);
        expect(
          (await adapter.saveListsWithResult(
            [claimed],
            ownershipClaims: {claimed.authorScopedId: localDraft()},
          )).succeeded,
          isTrue,
        );
        expect(
          (jsonDecode(prefs.getString(listsKey)!) as List).single['pubkey'],
          owner,
        );
        expect((jsonDecode(prefs.getString(followsKey)!) as List).toSet(), {
          existing,
        });
      },
    );
    test(
      'replacement loader rejects a genuine optimistic refused Follow overlay',
      () async {
        final (prefs, backend) = await setup(jsonEncode([existing]));
        final coordinator = CuratedListCacheWriteCoordinator();
        final original = store(prefs, coordinator, {existing});
        backend.refuses = true;
        expect(
          (await original.saveSubscriptionsWithResult({
            existing,
            refused,
          })).status,
          CuratedCacheWriteStatus.storageRejected,
        );
        expect((jsonDecode(prefs.getString(followsKey)!) as List).toSet(), {
          existing,
          refused,
        });
        final replacement = store(prefs, coordinator, const {});
        final loaded = replacement.loadSubscriptionSnapshot();
        expect(loaded.isReadable, isTrue);
        expect(loaded.ids, {existing});
        expect((jsonDecode(prefs.getString(followsKey)!) as List).toSet(), {
          existing,
          refused,
        });
        backend.refuses = false;
        expect(
          (await replacement.saveSubscriptionsWithResult({
            existing,
            added,
          })).succeeded,
          isTrue,
        );
        final durable = await backend.getAll();
        expect(
          (jsonDecode(durable['flutter.$followsKey']! as String) as List)
              .toSet(),
          {existing, added},
        );
      },
    );
  });
}
