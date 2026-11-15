// ABOUTME: Verifies the owner-private archive through platform storage calls.
// ABOUTME: Covers verified writes, revision consumption and exact-owner erasure.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/services/curated_lists/curated_list_draft_archive.dart';

import '../../helpers/shared_channel_override.dart';

void main() {
  final owner = 'a' * 64;
  final other = 'b' * 64;
  late Map<String, String> values;
  late SecureCuratedListDraftArchive archive;
  late bool refuseWrites;
  late bool refuseDeletes;
  late bool rejectReads;
  late bool rejectWrites;
  late bool corruptWrites;
  late bool rejectBackupReadback;
  late bool rejectReadAll;
  late Set<String> unreadableKeys;
  late Set<String> refusedDeleteKeys;
  late List<({String method, String? key})> storageCalls;
  String? pausedReadKey;
  Completer<void>? readStarted;
  Completer<void>? releaseRead;
  var readPaused = false;

  CuratedList draft(String pubkey, {String name = 'Private draft'}) =>
      CuratedList(
        id: 'retained',
        pubkey: pubkey,
        name: name,
        videoEventIds: ['1' * 64],
        isPublic: false,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );

  setUp(() {
    values = {};
    refuseWrites = false;
    refuseDeletes = false;
    rejectReads = false;
    rejectWrites = false;
    corruptWrites = false;
    rejectBackupReadback = false;
    rejectReadAll = false;
    unreadableKeys = {};
    refusedDeleteKeys = {};
    storageCalls = [];
    pausedReadKey = null;
    readStarted = null;
    releaseRead = null;
    readPaused = false;
    overrideSharedChannel(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async {
        final args = call.arguments as Map;
        final key = args['key'] as String?;
        storageCalls.add((method: call.method, key: key));
        switch (call.method) {
          case 'read':
            if (rejectReads ||
                (unreadableKeys.contains(key) && values.containsKey(key)) ||
                (rejectBackupReadback &&
                    key!.startsWith('curated_list_draft_quarantine_v1:') &&
                    values.containsKey(key))) {
              throw PlatformException(code: 'read_failed');
            }
            final before = values[key];
            if (key == pausedReadKey && !readPaused) {
              readPaused = true;
              readStarted!.complete();
              await releaseRead!.future;
            }
            return before;
          case 'readAll':
            if (rejectReads || rejectReadAll) {
              throw PlatformException(code: 'read_failed');
            }
            return Map<String, String>.of(values);
          case 'containsKey':
            if (rejectReads) throw PlatformException(code: 'read_failed');
            return values.containsKey(key);
          case 'write':
            if (rejectWrites) throw PlatformException(code: 'write_failed');
            if (!refuseWrites) {
              values[key!] = corruptWrites
                  ? 'readback-mismatch'
                  : args['value'] as String;
            }
            return null;
          case 'delete':
            if (!refuseDeletes && !refusedDeleteKeys.contains(key)) {
              values.remove(key);
            }
            return null;
        }
        throw StateError('Unexpected secure-storage operation');
      },
    );
    archive = SecureCuratedListDraftArchive(const FlutterSecureStorage());
  });

  group('owner-private draft archive', () {
    String quarantineKey(String pubkey, int slot) =>
        'curated_list_draft_quarantine_v1:$pubkey:$slot';

    test(
      'owner removal never decrypts or enumerates unrelated storage',
      () async {
        await archive.replaceOwner(owner, [draft(owner)]);
        await archive.replaceOwner(other, [draft(other)]);
        values[quarantineKey(owner, 4)] = '{unreadable-owner-evidence';
        values['unrelated-key'] = '{unreadable-unrelated-evidence';
        final retained = Map<String, String>.of(values)
          ..remove(SecureCuratedListDraftArchive.storageKey(owner))
          ..remove(quarantineKey(owner, 4));
        rejectReadAll = true;
        unreadableKeys = {'unrelated-key', quarantineKey(owner, 4)};
        storageCalls.clear();

        await archive.removeOwner(owner);

        expect(values, retained);
        expect(storageCalls.where((call) => call.method == 'readAll'), isEmpty);
        expect(
          storageCalls.where((call) => call.key == 'unrelated-key'),
          isEmpty,
        );
        expect(
          storageCalls.where((call) => call.method == 'containsKey'),
          isNotEmpty,
        );
      },
    );

    test(
      'sparse quarantine slots survive partial removal and are all retried',
      () async {
        final liveKey = SecureCuratedListDraftArchive.storageKey(owner);
        values.addAll({
          liveKey: '{live-owner-evidence',
          quarantineKey(owner, 0): '{first-evidence',
          quarantineKey(owner, 4): '{middle-evidence',
          quarantineKey(owner, 255): '{last-evidence',
          quarantineKey(other, 4): '{other-evidence',
        });
        refusedDeleteKeys.add(quarantineKey(owner, 4));
        rejectReadAll = true;

        await expectLater(
          archive.removeOwner(owner),
          throwsA(isA<CuratedListDraftArchiveException>()),
        );
        expect(values[quarantineKey(owner, 4)], '{middle-evidence');
        expect(values[quarantineKey(other, 4)], '{other-evidence');
        refusedDeleteKeys.clear();
        await archive.removeOwner(owner);

        expect(values, {quarantineKey(other, 4): '{other-evidence'});
      },
    );

    test(
      'a full quarantine retains every backup and the unchanged live source',
      () async {
        final liveKey = SecureCuratedListDraftArchive.storageKey(owner);
        values[liveKey] = '{new-unreadable-source';
        for (var slot = 0; slot < 256; slot++) {
          values[quarantineKey(owner, slot)] = '{prior-evidence-$slot';
        }
        final before = Map<String, String>.of(values);
        storageCalls.clear();

        await expectLater(
          archive.readOwner(owner),
          throwsA(isA<CuratedListDraftArchiveException>()),
        );

        expect(values, before);
        expect(
          storageCalls.where(
            (call) => call.method == 'write' || call.method == 'delete',
          ),
          isEmpty,
        );
        // Explicit destruction can still remove a full quarantine.
        await archive.removeOwner(owner);
        expect(values, isEmpty);
      },
    );

    test('reuses a verified source beyond a quarantine hole without duplicating it', () async {
      final liveKey = SecureCuratedListDraftArchive.storageKey(owner);
      const raw = '{preserved-source';
      values[liveKey] = raw;
      values[quarantineKey(owner, 255)] = raw;

      expect(await archive.readOwner(owner), isNull);

      expect(values, {quarantineKey(owner, 255): raw});
    });

    test(
      'round trips private rows and rejects foreign or duplicate coordinates',
      () async {
        final expected = draft(owner);
        await archive.replaceOwner(owner, [expected]);
        final snapshot = (await archive.readOwner(owner))!;
        expect(snapshot.owner, owner);
        expect(snapshot.lists, [expected]);
        expect(snapshot.revision, isNotEmpty);
        for (final rows in [
          [draft(other)],
          [expected, expected],
        ]) {
          await expectLater(
            archive.replaceOwner(owner, rows),
            throwsA(isA<CuratedListDraftArchiveException>()),
          );
          expect((await archive.readOwner(owner))!.revision, snapshot.revision);
        }
      },
    );

    test('stale consumption leaves the newer owner draft intact', () async {
      await archive.replaceOwner(owner, [draft(owner)]);
      final before = (await archive.readOwner(owner))!;
      await archive.replaceOwner(owner, [draft(owner, name: 'Newer draft')]);
      expect(await archive.consumeOwner(owner, before.revision), isFalse);
      final newer = (await archive.readOwner(owner))!;
      expect(newer.lists.single.name, 'Newer draft');
      expect(await archive.consumeOwner(owner, newer.revision), isTrue);
      expect(await archive.readOwner(owner), isNull);
    });

    test(
      'quarantines each unreadable revision before replacing live drafts',
      () async {
        final key = SecureCuratedListDraftArchive.storageKey(owner);
        final unreadable = [
          '{invalid',
          jsonEncode({
            'version': 2,
            'owner': owner,
            'revision': 'new-format',
            'lists': [],
          }),
          jsonEncode({
            'version': 1,
            'owner': other,
            'revision': 'foreign',
            'lists': [draft(other).toJson()],
          }),
        ];
        for (final raw in unreadable) {
          values[key] = raw;
          expect(await archive.readOwner(owner), isNull);
          expect(values[key], isNull);
          expect(values.values, contains(raw));
        }
        expect(values.values, containsAll(unreadable));
        expect(values.length, unreadable.length);
        await archive.replaceOwner(owner, [draft(owner)]);
        final snapshot = (await archive.readOwner(owner))!;
        expect(await archive.consumeOwner(owner, snapshot.revision), isTrue);
        expect(values.values, containsAll(unreadable));
        await archive.replaceOwner(owner, []);
        expect(values.values, containsAll(unreadable));
      },
    );

    for (final failure in [
      'rejected write',
      'ignored write',
      'mismatched readback',
      'failed deletion',
    ]) {
      test('quarantine $failure keeps the live source and retries', () async {
        final key = SecureCuratedListDraftArchive.storageKey(owner);
        const raw = '{unreadable';
        values[key] = raw;
        rejectWrites = failure == 'rejected write';
        refuseWrites = failure == 'ignored write';
        corruptWrites = failure == 'mismatched readback';
        refuseDeletes = failure == 'failed deletion';
        await expectLater(
          archive.readOwner(owner),
          throwsA(isA<CuratedListDraftArchiveException>()),
        );
        expect(values[key], raw);
        rejectWrites = refuseWrites = corruptWrites = refuseDeletes = false;
        expect(await archive.readOwner(owner), isNull);
        expect(values.values.where((value) => value == raw), hasLength(1));
        if (failure == 'mismatched readback') {
          expect(values.values, contains('readback-mismatch'));
        }
      });
    }

    test(
      'storage read failures never masquerade as malformed archives',
      () async {
        final key = SecureCuratedListDraftArchive.storageKey(owner);
        values[key] = '{unreadable';
        rejectReads = true;
        await expectLater(
          archive.readOwner(owner),
          throwsA(isA<CuratedListDraftArchiveException>()),
        );
        expect(values, {key: '{unreadable'});
        rejectReads = false;
        expect(await archive.readOwner(owner), isNull);
        expect(values.values, ['{unreadable']);
      },
    );

    test('a backup readback outage leaves both copies and retries without duplication', () async {
      final key = SecureCuratedListDraftArchive.storageKey(owner);
      const raw = '{unreadable';
      values[key] = raw;
      rejectBackupReadback = true;
      await expectLater(
        archive.readOwner(owner),
        throwsA(isA<CuratedListDraftArchiveException>()),
      );
      expect(values[key], raw);
      expect(values.values.where((value) => value == raw), hasLength(2));
      rejectBackupReadback = false;
      expect(await archive.readOwner(owner), isNull);
      expect(values.values, [raw]);
    });

    test(
      'a stale unreadable read cannot recreate explicitly destroyed evidence',
      () async {
        final key = SecureCuratedListDraftArchive.storageKey(owner);
        values[key] = '{removed-evidence';
        pausedReadKey = key;
        readStarted = Completer<void>();
        releaseRead = Completer<void>();
        final reading = archive.readOwner(owner);
        await readStarted!.future;
        final second = SecureCuratedListDraftArchive(
          const FlutterSecureStorage(),
        );
        await second.removeOwner(owner);
        releaseRead!.complete();
        expect(await reading, isNull);
        expect(values, isEmpty);
      },
    );

    test('explicit destruction erases only exact-owner live and quarantined revisions', () async {
      final key = SecureCuratedListDraftArchive.storageKey(owner);
      final otherKey = SecureCuratedListDraftArchive.storageKey(other);
      values[key] = '{owner-revision';
      values[otherKey] = '{other-revision';
      await archive.readOwner(owner);
      await archive.readOwner(other);
      await archive.replaceOwner(owner, [draft(owner)]);
      await archive.replaceOwner(other, [draft(other)]);
      final beforeOther = {
        for (final entry in values.entries)
          if (entry.value == '{other-revision' || entry.key == otherKey)
            entry.key: entry.value,
      };
      await archive.removeOwner(owner);
      expect(values, beforeOther);
    });

    test(
      'failed explicit quarantine deletion retains other owners and retries',
      () async {
        final key = SecureCuratedListDraftArchive.storageKey(owner);
        final otherKey = SecureCuratedListDraftArchive.storageKey(other);
        values[key] = '{owner-evidence';
        values[otherKey] = '{other-evidence';
        await archive.readOwner(owner);
        await archive.readOwner(other);
        refuseDeletes = true;
        await expectLater(
          archive.removeOwner(owner),
          throwsA(isA<CuratedListDraftArchiveException>()),
        );
        expect(
          values.values,
          containsAll(['{owner-evidence', '{other-evidence']),
        );
        refuseDeletes = false;
        await archive.removeOwner(owner);
        expect(values.values, ['{other-evidence']);
      },
    );

    test(
      'a paused stale read cannot quarantine or delete a newer live draft',
      () async {
        final key = SecureCuratedListDraftArchive.storageKey(owner);
        values[key] = '{old-unreadable';
        pausedReadKey = key;
        readStarted = Completer<void>();
        releaseRead = Completer<void>();
        final reading = archive.readOwner(owner);
        await readStarted!.future;
        final second = SecureCuratedListDraftArchive(
          const FlutterSecureStorage(),
        );
        await second.replaceOwner(owner, [draft(owner, name: 'Newer draft')]);
        releaseRead!.complete();
        expect((await reading)!.lists.single.name, 'Newer draft');
        expect(
          (await archive.readOwner(owner))!.lists.single.name,
          'Newer draft',
        );
        expect(values.values, contains('{old-unreadable'));
      },
    );

    test(
      'consume and replacement are serialized across archive instances',
      () async {
        await archive.replaceOwner(owner, [draft(owner)]);
        final snapshot = (await archive.readOwner(owner))!;
        pausedReadKey = SecureCuratedListDraftArchive.storageKey(owner);
        readStarted = Completer<void>();
        releaseRead = Completer<void>();
        final consuming = archive.consumeOwner(owner, snapshot.revision);
        await readStarted!.future;
        final second = SecureCuratedListDraftArchive(
          const FlutterSecureStorage(),
        );
        final replacing = second.replaceOwner(owner, [
          draft(owner, name: 'Newer draft'),
        ]);
        releaseRead!.complete();
        expect(await consuming, isTrue);
        await replacing;
        expect(
          (await archive.readOwner(owner))!.lists.single.name,
          'Newer draft',
        );
      },
    );

    test('failed write readback preserves the prior durable draft', () async {
      await archive.replaceOwner(owner, [draft(owner)]);
      final before = (await archive.readOwner(owner))!;
      refuseWrites = true;
      await expectLater(
        archive.replaceOwner(owner, [draft(owner, name: 'Unstored draft')]),
        throwsA(isA<CuratedListDraftArchiveException>()),
      );
      expect((await archive.readOwner(owner))!.revision, before.revision);
    });

    test('failed deletion is reported and can retry without affecting another owner', () async {
      await archive.replaceOwner(owner, [draft(owner)]);
      await archive.replaceOwner(other, [draft(other)]);
      final retained = (await archive.readOwner(other))!;
      refuseDeletes = true;
      await expectLater(
        archive.removeOwner(owner),
        throwsA(isA<CuratedListDraftArchiveException>()),
      );
      expect(await archive.readOwner(owner), isNotNull);
      refuseDeletes = false;
      rejectReads = false;
      rejectWrites = false;
      corruptWrites = false;
      rejectBackupReadback = false;
      pausedReadKey = null;
      readStarted = null;
      releaseRead = null;
      readPaused = false;
      await archive.removeOwner(owner);
      expect(await archive.readOwner(owner), isNull);
      expect((await archive.readOwner(other))!.revision, retained.revision);
    });

    test(
      'explicit destruction erases an unreadable exact-owner payload',
      () async {
        final key = SecureCuratedListDraftArchive.storageKey(owner);
        values[key] = '{unreadable-private-payload';
        await archive.replaceOwner(other, [draft(other)]);
        await archive.removeOwner(owner);
        expect(values[key], isNull);
        expect(await archive.readOwner(other), isNotNull);
      },
    );

    test('invalid owner keys cannot access or erase storage', () async {
      await archive.replaceOwner(owner, [draft(owner)]);
      await expectLater(
        archive.removeOwner('invalid-owner'),
        throwsA(isA<CuratedListDraftArchiveException>()),
      );
      expect(await archive.readOwner(owner), isNotNull);
    });
  });
}
