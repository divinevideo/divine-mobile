// ABOUTME: Covers durable raw quarantine and typed failures at storage boundary.
// ABOUTME: Healthy sibling records survive partially malformed owner evidence.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/services/curated_lists/curated_list_recovery_record.dart';
import 'package:openvine/services/curated_lists/curated_list_recovery_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class _Storage extends InMemorySharedPreferencesStore {
  _Storage() : super.empty();
  bool reject = false;
  bool throwing = false;

  @override
  Future<bool> setValue(String type, String key, Object value) async {
    if (throwing) throw StateError('sensitive storage payload');
    if (reject) return false;
    return super.setValue(type, key, value);
  }
}

void main() {
  group('CuratedListRecoveryStorage', () {
    const owner =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const key = 'curated_list_recovery_v1:$owner';
    const eventId =
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
    const healthy = CuratedListRecoveryRecord(
      plaintextEventIds: [eventId],
      visibility: CuratedListVisibility(
        isPublic: false,
        isCollaborative: false,
        allowedCollaborators: [],
        relayAccepted: true,
      ),
      requiresPrivateCommit: true,
    );
    late SharedPreferences prefs;
    late _Storage storage;
    late SharedPreferencesStorePlatform previous;

    setUp(() async {
      previous = SharedPreferencesStorePlatform.instance;
      storage = _Storage();
      SharedPreferencesStorePlatform.instance = storage;
      SharedPreferences.resetStatic();
      prefs = await SharedPreferences.getInstance();
    });

    tearDown(() {
      SharedPreferences.resetStatic();
      SharedPreferencesStorePlatform.instance = previous;
    });

    Future<void> restart() async {
      SharedPreferences.resetStatic();
      prefs = await SharedPreferences.getInstance();
    }

    test(
      'quarantine preserves raw malformed siblings and healthy evidence',
      () async {
        final raw = jsonEncode({
          'healthy': healthy.toJson(),
          'bad-date': {'acceptedAt': 'private malformed date'},
          'unknown-row': 'private unknown bytes',
        });
        await prefs.setString(key, raw);
        final read = CuratedListRecoveryStorage.read(prefs, key);
        expect(read.status, CuratedListRecoveryReadStatus.corrupt);
        expect(read.raw, raw);
        expect(read.records.keys, ['healthy']);
        expect(read.records['healthy']!.toJson(), healthy.toJson());
        expect(
          await CuratedListRecoveryStorage.preserve(prefs, key, owner, {
            ...read.records,
            'pending-ack': healthy,
          }),
          isTrue,
        );
        await restart();
        expect(prefs.getString(key), raw);
        final envelope = jsonDecode(
          prefs.getString(CuratedListRecoveryStorage.quarantineKey(owner))!,
        ) as Map<String, dynamic>;
        expect(envelope['rawBuckets'], [raw]);
        final preserved = CuratedListRecoveryStorage.preservedRecords(
          prefs,
          owner,
        );
        expect(preserved.keys, unorderedEquals(['healthy', 'pending-ack']));
        expect(preserved['healthy']!.toJson(), healthy.toJson());
        expect(preserved['pending-ack']!.toJson(), healthy.toJson());
        expect(
          CuratedListRecoveryStorage.needsRepair(prefs, key, owner),
          isTrue,
        );
      },
    );

    test(
      'existing unreadable quarantine is preserved with a payload-free error',
      () async {
        const raw = '{private malformed quarantine';
        final quarantine = CuratedListRecoveryStorage.quarantineKey(owner);
        await prefs.setString(quarantine, raw);
        await expectLater(
          CuratedListRecoveryStorage.preserve(prefs, key, owner, {
            'healthy': healthy,
          }),
          throwsA(
            isA<CuratedListRecoveryException>().having(
              (e) => e.toString(),
              'safe message',
              'Curated-list recovery needs repair',
            ),
          ),
        );
        await restart();
        expect(prefs.getString(quarantine), raw);
        expect(prefs.containsKey(key), isFalse);
      },
    );

    for (final throwing in [false, true]) {
      test(
        'quarantine ${throwing ? 'throw' : 'refusal'} leaves durable evidence unchanged',
        () async {
          const raw = '{private malformed owner evidence';
          await prefs.setString(key, raw);
          storage.throwing = throwing;
          storage.reject = !throwing;
          final saving = CuratedListRecoveryStorage.preserve(
            prefs,
            key,
            owner,
            {
              'healthy': healthy,
            },
          );
          if (throwing) {
            await expectLater(
              saving,
              throwsA(isA<CuratedListRecoveryException>()),
            );
          } else {
            expect(await saving, isFalse);
          }
          expect(
            prefs.containsKey(CuratedListRecoveryStorage.quarantineKey(owner)),
            isFalse,
          );
          await restart();
          expect(prefs.getString(key), raw);
          expect(
            prefs.containsKey(CuratedListRecoveryStorage.quarantineKey(owner)),
            isFalse,
          );
        },
      );
    }
  });
}
