// ABOUTME: Unit tests for SavedTitleStylesDao CRUD, ordering and
// ABOUTME: per-account isolation of the saved video-editor text-overlay styles.

import 'dart:io';

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late SavedTitleStylesDao dao;
  late String tempDbPath;

  const ownerA =
      'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2';
  const ownerB =
      'b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3';

  setUp(() async {
    final tempDir = Directory.systemTemp.createTempSync(
      'saved_title_styles_dao_',
    );
    tempDbPath = '${tempDir.path}/test.db';
    database = AppDatabase.test(NativeDatabase(File(tempDbPath)));
    dao = database.savedTitleStylesDao;
  });

  tearDown(() async {
    await database.close();
    final file = File(tempDbPath);
    if (file.existsSync()) file.deleteSync();
  });

  Future<void> insertStyle(
    String id, {
    String name = 'Intro',
    String style = '{"fontScale":1.0}',
    int orderIndex = 0,
    DateTime? createdAt,
    String? ownerPubkey,
  }) {
    return dao.upsertStyle(
      id: id,
      name: name,
      style: style,
      createdAt: createdAt ?? DateTime(2026, 3, 5),
      orderIndex: orderIndex,
      ownerPubkey: ownerPubkey,
    );
  }

  group(SavedTitleStylesDao, () {
    group('getStyles', () {
      test('returns styles ordered by orderIndex', () async {
        await insertStyle('style-b', name: 'B', orderIndex: 2);
        await insertStyle('style-a', name: 'A', orderIndex: 1);

        final styles = await dao.getStyles();

        expect(styles.map((s) => s.id), ['style-a', 'style-b']);
      });

      test('breaks an order tie by creation time', () async {
        await insertStyle('later', createdAt: DateTime(2026, 3, 6));
        await insertStyle('earlier', createdAt: DateTime(2026, 3, 5));

        final styles = await dao.getStyles();

        expect(styles.map((s) => s.id), ['earlier', 'later']);
      });

      test(
        'scopes to the owner and keeps legacy rows without an owner',
        () async {
          await insertStyle('style-a', ownerPubkey: ownerA);
          await insertStyle('style-b', ownerPubkey: ownerB);
          await insertStyle('style-legacy');

          final styles = await dao.getStyles(ownerPubkey: ownerA);

          expect(
            styles.map((s) => s.id),
            unorderedEquals(['style-a', 'style-legacy']),
          );
        },
      );

      test('returns the stored style payload untouched', () async {
        const payload = '{"fontFamily":"Inter","color":4294967295}';
        await insertStyle('style-a', style: payload);

        final styles = await dao.getStyles();

        expect(styles.single.style, payload);
      });
    });

    group('upsertStyle', () {
      test('updates an existing row instead of duplicating it', () async {
        await insertStyle('style-a', name: 'Old');
        await insertStyle('style-a', name: 'New', style: '{"fontScale":2.0}');

        final styles = await dao.getStyles();

        expect(styles, hasLength(1));
        expect(styles.single.name, 'New');
        expect(styles.single.style, '{"fontScale":2.0}');
      });
    });

    group('renameStyle', () {
      test('renames an existing style', () async {
        await insertStyle('style-a', name: 'Old');

        final renamed = await dao.renameStyle(id: 'style-a', name: 'New');

        expect(renamed, isTrue);
        final styles = await dao.getStyles();
        expect(styles.single.name, 'New');
      });

      test('reports false for an unknown style', () async {
        expect(await dao.renameStyle(id: 'missing', name: 'New'), isFalse);
      });
    });

    group('deleteStyle', () {
      test('removes the style and leaves the others', () async {
        await insertStyle('style-a');
        await insertStyle('style-b');

        final deleted = await dao.deleteStyle('style-a');

        expect(deleted, isTrue);
        final styles = await dao.getStyles();
        expect(styles.map((s) => s.id), ['style-b']);
      });

      test('reports false for an unknown style', () async {
        expect(await dao.deleteStyle('missing'), isFalse);
      });
    });

    group('reorderStyles', () {
      test('rewrites the order indexes to match the given ids', () async {
        await insertStyle('style-a');
        await insertStyle('style-b', orderIndex: 1);
        await insertStyle('style-c', orderIndex: 2);

        await dao.reorderStyles(['style-c', 'style-a', 'style-b']);

        final styles = await dao.getStyles();
        expect(styles.map((s) => s.id), ['style-c', 'style-a', 'style-b']);
        expect(styles.map((s) => s.orderIndex), [0, 1, 2]);
      });

      test('ignores ids that no longer exist', () async {
        await insertStyle('style-a', orderIndex: 5);

        await dao.reorderStyles(['missing', 'style-a']);

        final styles = await dao.getStyles();
        expect(styles.single.orderIndex, 1);
      });
    });

    group('highestOrderIndex', () {
      test('returns null when the account has no styles', () async {
        expect(await dao.highestOrderIndex(ownerPubkey: ownerA), isNull);
      });

      test('returns the highest index in use', () async {
        await insertStyle('style-a', orderIndex: 3, ownerPubkey: ownerA);
        await insertStyle('style-b', orderIndex: 7, ownerPubkey: ownerA);
        await insertStyle('style-c', orderIndex: 9, ownerPubkey: ownerB);

        expect(await dao.highestOrderIndex(ownerPubkey: ownerA), 7);
      });
    });

    group('deleteAllForUser', () {
      test(
        "removes only the owner's styles and keeps legacy rows",
        () async {
          await insertStyle('style-a', ownerPubkey: ownerA);
          await insertStyle('style-b', ownerPubkey: ownerB);
          await insertStyle('style-legacy');

          final deleted = await dao.deleteAllForUser(ownerA);

          expect(deleted, 1);
          final remaining = await dao.getStyles();
          expect(
            remaining.map((s) => s.id),
            unorderedEquals(['style-b', 'style-legacy']),
          );
        },
      );
    });

    group('claimLegacyRows', () {
      test('attributes ownerless styles to the new owner', () async {
        await insertStyle('style-legacy');
        await insertStyle('style-b', ownerPubkey: ownerB);

        final claimed = await dao.claimLegacyRows(ownerA);

        expect(claimed, 1);
        final styles = await dao.getStyles(ownerPubkey: ownerA);
        expect(styles.map((s) => s.id), ['style-legacy']);
        expect(styles.single.ownerPubkey, ownerA);
      });

      test('also claims rows stamped with the source marker', () async {
        await insertStyle('style-anon', ownerPubkey: 'anonymous');
        await insertStyle('style-legacy');

        final claimed = await dao.claimLegacyRows(
          ownerA,
          sourceOwnerPubkey: 'anonymous',
        );

        expect(claimed, 2);
        final styles = await dao.getStyles(ownerPubkey: ownerA);
        expect(
          styles.map((s) => s.id),
          unorderedEquals(['style-anon', 'style-legacy']),
        );
      });
    });
  });
}
