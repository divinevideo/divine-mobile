// ABOUTME: Guards Library and diagnostic projections against payload transfer.
// ABOUTME: Verifies ownership, sorting and malformed-row inventory behavior.

import 'dart:convert';

import 'package:db_client/db_client.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class _ReadRecorder extends QueryInterceptor {
  List<Map<String, Object?>> rows = [];

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    return rows = await executor.runSelect(statement, args);
  }
}

void main() {
  group('draft projections', () {
    late AppDatabase db;
    late _ReadRecorder recorder;
    const owner =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const foreign =
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

    setUp(() {
      recorder = _ReadRecorder();
      db = AppDatabase.test(NativeDatabase.memory().interceptWith(recorder));
    });
    tearDown(() => db.close());

    Future<void> seed(
      String id, {
      String? account,
      int day = 1,
      String? data,
    }) => db.draftsDao.saveDraftWithClips(
      id: id,
      title: 'Title $id',
      description: '',
      publishStatus: 'failed',
      createdAt: DateTime(2026),
      lastModified: DateTime(2026, 1, day),
      ownerPubkey: account,
      data:
          data ??
          jsonEncode({
            'finalRenderVersion': 2,
            'editorStateHistory': 'history-payload' * 10000,
          }),
      renderedFilePath: 'render.mp4',
      renderedThumbnailPath: 'render.jpg',
      customThumbnailPath: 'cover.jpg',
      clipDataList: [
        DraftClipData(
          id: 'clip-$id',
          orderIndex: 0,
          durationMs: 6000,
          recordedAt: DateTime(2026),
          data: 'clip-payload',
          filePath: 'clip.mp4',
        ),
      ],
    );

    test('summary result never transfers the editor payload', () async {
      await seed('owned', account: owner);
      final summary = (await db.draftsDao.getDraftSummaries(
        ownerPubkey: owner,
      )).single;
      expect(summary.title, 'Title owned');
      expect(summary.publishStatus, 'failed');
      expect(summary.finalRenderVersion, 2);
      expect(summary.customThumbnailPath, 'cover.jpg');
      expect(summary.renderedFilePath, 'render.mp4');
      expect(summary.renderedThumbnailPath, 'render.jpg');
      expect(recorder.rows.single.keys, isNot(contains('data')));
      expect(jsonEncode(recorder.rows), isNot(contains('history-payload')));
    });

    test('summary includes owned and legacy rows, newest first', () async {
      await seed('owned', account: owner);
      await seed('legacy', day: 2);
      await seed('foreign', account: foreign, day: 3);
      await seed('anonymous', account: '__anonymous_offline_draft__', day: 4);
      expect(
        (await db.draftsDao.getDraftSummaries(
          ownerPubkey: owner,
        )).map((r) => r.id),
        ['legacy', 'owned'],
      );
      expect(await db.draftsDao.getDraftSummaries(), hasLength(4));
    });

    test(
      'missing render version defaults to the full draft legacy version',
      () async {
        await seed('legacy-render', data: '{}');
        expect(
          (await db.draftsDao.getDraftSummaries()).single.finalRenderVersion,
          0,
        );
      },
    );

    test('malformed payload is hidden but remains in inventory', () async {
      await seed('bad', data: 'not json');
      expect(await db.draftsDao.getDraftSummaries(), isEmpty);
      expect(await db.draftsDao.getDraftInventory(), [
        (id: 'bad', ownerPubkey: null),
      ]);
      expect(recorder.rows.single.keys, isNot(contains('data')));
      final clips = await db.clipsDao.getClipInventory();
      expect(clips.single.draftId, 'bad');
      expect(clips.single.filePath, 'clip.mp4');
      expect(recorder.rows.single.keys, isNot(contains('data')));
    });
  });
}
