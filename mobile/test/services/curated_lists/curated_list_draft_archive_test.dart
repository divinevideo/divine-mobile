// ABOUTME: Verifies the owner-private archive through platform storage calls.
// ABOUTME: Covers verified writes, revision consumption and exact-owner erasure.

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
    overrideSharedChannel(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async {
        final args = call.arguments as Map;
        final key = args['key'] as String;
        switch (call.method) {
          case 'read':
            return values[key];
          case 'write':
            if (!refuseWrites) values[key] = args['value'] as String;
            return null;
          case 'delete':
            if (!refuseDeletes) values.remove(key);
            return null;
        }
        throw StateError('Unexpected secure-storage operation');
      },
    );
    archive = SecureCuratedListDraftArchive(const FlutterSecureStorage());
  });

  group('owner-private draft archive', () {
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
      'normal reads and replacement preserve malformed owner envelopes',
      () async {
        final key = SecureCuratedListDraftArchive.storageKey(owner);
        for (final raw in [
          '{invalid',
          jsonEncode({
            'version': 1,
            'owner': other,
            'revision': 'synthetic-revision',
            'lists': [draft(owner).toJson()],
          }),
        ]) {
          values[key] = raw;
          await expectLater(
            archive.readOwner(owner),
            throwsA(isA<CuratedListDraftArchiveException>()),
          );
          await expectLater(
            archive.replaceOwner(owner, [draft(owner)]),
            throwsA(isA<CuratedListDraftArchiveException>()),
          );
          expect(values[key], raw);
        }
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
