// ABOUTME: Tests for SavedTitleStyleRepository against an in-memory Drift
// ABOUTME: database: the save/load round-trip, ownership, and corrupt rows.

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_editor/saved_title_style.dart';
import 'package:openvine/models/video_editor/title_style.dart';
import 'package:openvine/repositories/saved_title_style_repository.dart';
import 'package:pro_image_editor/pro_image_editor.dart'
    show LayerBackgroundMode;
import 'package:pro_video_editor/pro_video_editor.dart' as pve;
import 'package:uuid/data.dart';
import 'package:uuid/uuid.dart';

void main() {
  const ownerA =
      'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2';
  const ownerB =
      'b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3';

  const style = TitleStyle(
    fontIndex: 7,
    color: Color(0xFFFFF140),
    background: Color(0xA6000000),
    colorMode: LayerBackgroundMode.backgroundAndColorWithOpacity,
    align: TextAlign.right,
    fontScale: 1.4,
    enter: [
      pve.LayerAnimation(
        type: pve.LayerAnimationType.slide,
        phase: pve.AnimationPhase.animateIn,
        duration: Duration(milliseconds: 350),
        curve: pve.AnimationCurve.easeOutCubic,
        slideDirection: pve.SlideDirection.top,
      ),
    ],
    leave: [
      pve.LayerAnimation(
        type: pve.LayerAnimationType.fade,
        phase: pve.AnimationPhase.animateOut,
        duration: Duration(milliseconds: 200),
      ),
    ],
    enterPoint: Offset(0.2, -0.45),
  );

  group(SavedTitleStyleRepository, () {
    late AppDatabase database;
    late DateTime now;
    var nextId = 0;

    setUp(() {
      database = AppDatabase.test(NativeDatabase.memory());
      // Local, not UTC: Drift reads a DateTimeColumn back as local time.
      now = DateTime(2026, 9, 15, 12);
      nextId = 0;
    });

    tearDown(() => database.close());

    SavedTitleStyleRepository repositoryFor(String? owner) =>
        SavedTitleStyleRepository(
          dao: database.savedTitleStylesDao,
          ownerPubkey: owner,
          uuid: _SequentialUuid(() => 'style-${++nextId}'),
          now: () => now,
        );

    group('save', () {
      test('round-trips a style through the database', () async {
        final repository = repositoryFor(ownerA);

        final saved = await repository.save(rawName: ' Intro ', style: style);
        final loaded = await repository.getStyles();

        expect(
          saved,
          equals(
            SavedTitleStyle(
              id: 'style-1',
              name: 'Intro',
              style: style,
              createdAt: now,
            ),
          ),
        );
        expect(loaded, equals([saved]));
      });

      test('appends after the highest existing order index', () async {
        final repository = repositoryFor(ownerA);
        await repository.save(rawName: 'First', style: style);
        await repository.save(rawName: 'Second', style: style);

        final loaded = await repository.getStyles();

        expect(loaded.map((s) => s.name), ['First', 'Second']);
        expect(loaded.map((s) => s.orderIndex), [0, 1]);
      });

      test('rejects a blank name without writing', () async {
        final repository = repositoryFor(ownerA);

        final saved = await repository.save(rawName: '   ', style: style);

        expect(saved, isNull);
        expect(await repository.getStyles(), isEmpty);
      });

      test('stamps the owner so other accounts do not see it', () async {
        await repositoryFor(ownerA).save(rawName: 'Mine', style: style);

        expect(await repositoryFor(ownerB).getStyles(), isEmpty);
        expect(await repositoryFor(ownerA).getStyles(), hasLength(1));
      });
    });

    group('getStyles', () {
      test('skips a row whose payload no longer decodes', () async {
        final repository = repositoryFor(ownerA);
        await repository.save(rawName: 'Good', style: style);
        await database.savedTitleStylesDao.upsertStyle(
          id: 'corrupt',
          name: 'Bad',
          style: 'not json at all',
          createdAt: now,
          orderIndex: 1,
          ownerPubkey: ownerA,
        );
        await database.savedTitleStylesDao.upsertStyle(
          id: 'missing-colors',
          name: 'Bad too',
          style: '{"fontScale": 2}',
          createdAt: now,
          orderIndex: 2,
          ownerPubkey: ownerA,
        );
        await database.savedTitleStylesDao.upsertStyle(
          id: 'unknown-animation',
          name: 'Bad three',
          style:
              '{"fontIndex":0,"color":1,"background":1,'
              '"enter":[{"type":"wobble","phase":"animateIn","durationUs":1}]}',
          createdAt: now,
          orderIndex: 3,
          ownerPubkey: ownerA,
        );

        final loaded = await repository.getStyles();

        expect(loaded.map((s) => s.name), ['Good']);
      });
    });

    group('rename', () {
      test('renames and reports success', () async {
        final repository = repositoryFor(ownerA);
        final saved = await repository.save(rawName: 'Intro', style: style);

        final renamed = await repository.rename(
          id: saved!.id,
          rawName: ' Outro ',
        );

        expect(renamed, isTrue);
        final loaded = await repository.getStyles();
        expect(loaded.single.name, 'Outro');
      });

      test('rejects a blank name and an unknown id', () async {
        final repository = repositoryFor(ownerA);
        final saved = await repository.save(rawName: 'Intro', style: style);

        expect(await repository.rename(id: saved!.id, rawName: ' '), isFalse);
        expect(await repository.rename(id: 'nope', rawName: 'X'), isFalse);
        final loaded = await repository.getStyles();
        expect(loaded.single.name, 'Intro');
      });
    });

    group('delete', () {
      test('removes the style and reports whether it existed', () async {
        final repository = repositoryFor(ownerA);
        final saved = await repository.save(rawName: 'Intro', style: style);

        expect(await repository.delete(saved!.id), isTrue);
        expect(await repository.delete(saved.id), isFalse);
        expect(await repository.getStyles(), isEmpty);
      });
    });

    group('reorder', () {
      test('persists the given order', () async {
        final repository = repositoryFor(ownerA);
        await repository.save(rawName: 'A', style: style);
        await repository.save(rawName: 'B', style: style);
        await repository.save(rawName: 'C', style: style);

        await repository.reorder(['style-3', 'style-1', 'style-2']);

        final loaded = await repository.getStyles();
        expect(loaded.map((s) => s.name), ['C', 'A', 'B']);
      });
    });
  });
}

/// A [Uuid] whose `v4` hands out ids from [next], so tests can name rows.
class _SequentialUuid extends Uuid {
  const _SequentialUuid(this.next);

  final String Function() next;

  @override
  String v4({
    @Deprecated('use config instead. Removal in 5.0.0')
    Map<String, dynamic>? options,
    V4Options? config,
  }) => next();
}
