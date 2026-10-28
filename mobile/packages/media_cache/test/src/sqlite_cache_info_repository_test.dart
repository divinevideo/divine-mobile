import 'dart:async';
import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_cache/src/sqlite_cache_info_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite/sqflite.dart';

class _MockRepository extends Mock implements CacheInfoRepository {}

class _DatabaseFailure extends DatabaseException {
  _DatabaseFailure(this.code) : super('synthetic cache open failure');

  final int? code;

  @override
  int? getResultCode() => code;

  @override
  Object? get result => null;
}

void main() {
  group('SqliteCacheInfoRepository', () {
    late Directory directory;
    late _MockRepository delegate;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('sqlite_cache_index_');
      delegate = _MockRepository();
      when(delegate.open).thenAnswer((_) async => true);
      when(delegate.close).thenAnswer((_) async => true);
    });

    tearDown(() async => directory.delete(recursive: true));

    SqliteCacheInfoRepository repository({
      CacheInfoRepository Function(String)? create,
      Future<void> Function(String)? delete,
    }) => SqliteCacheInfoRepository(
      databaseName: 'images',
      directoryProvider: () async => directory,
      repositoryFactory: create ?? (_) => delegate,
      deleteDatabase: delete ?? (_) async {},
    );

    group('open', () {
      for (final code in [11, 26, 11 | (1 << 8)]) {
        test('retries corruption code $code with a fresh provider', () async {
          final failed = _MockRepository();
          when(failed.open).thenThrow(_DatabaseFailure(code));
          var created = 0;
          final deleted = <String>[];
          final index = repository(
            create: (_) => created++ == 0 ? failed : delegate,
            delete: (path) async => deleted.add(path),
          );
          expect(await index.open(), isTrue);
          expect(created, 2);
          expect(deleted, ['${directory.path}/images.db']);
          verify(failed.open).called(1);
          verify(delegate.open).called(1);
          expect(await index.close(), isTrue);
          verify(delegate.close).called(1);
          verifyNever(failed.close);
        });
      }

      for (final code in [5, 6, 10, 14, null]) {
        test('does not delete for non-corrupt code $code', () async {
          final error = _DatabaseFailure(code);
          when(delegate.open).thenThrow(error);
          final deleted = <String>[];
          final index = repository(delete: (path) async => deleted.add(path));
          await expectLater(index.open(), throwsA(same(error)));
          expect(deleted, isEmpty);
          expect(await index.close(), isTrue);
          verifyNever(delegate.close);
        });
      }

      test('does not delete for an unclassified exception', () async {
        when(delegate.open).thenThrow(StateError('unavailable'));
        final deleted = <String>[];
        final index = repository(delete: (path) async => deleted.add(path));
        await expectLater(index.open(), throwsStateError);
        expect(deleted, isEmpty);
      });

      test('propagates failed recovery without an unbounded retry', () async {
        when(delegate.open).thenThrow(_DatabaseFailure(26));
        var created = 0;
        var deleted = 0;
        final index = repository(
          create: (_) {
            created++;
            return delegate;
          },
          delete: (_) async => deleted++,
        );
        await expectLater(index.open(), throwsA(isA<DatabaseException>()));
        expect(created, 2);
        expect(deleted, 1);
        verify(delegate.open).called(2);
      });

      test('does not retry after index deletion fails', () async {
        when(delegate.open).thenThrow(_DatabaseFailure(11));
        final index = repository(
          delete: (_) async => throw const FileSystemException('unavailable'),
        );
        await expectLater(index.open(), throwsA(isA<FileSystemException>()));
        verify(delegate.open).called(1);
      });

      test('coalesces concurrent opens', () async {
        final opening = Completer<bool>();
        when(delegate.open).thenAnswer((_) => opening.future);
        final index = repository();
        final first = index.open();
        final second = index.open();
        expect(identical(first, second), isTrue);
        opening.complete(true);
        expect(await first, isTrue);
        verify(delegate.open).called(1);
      });
    });

    group('close', () {
      test('is harmless before open', () async {
        expect(await repository().close(), isTrue);
        verifyNever(delegate.close);
      });

      test('permits a new open after a successful close', () async {
        final index = repository();
        await index.open();
        await index.close();
        await index.open();
        verify(delegate.open).called(2);
        await index.close();
      });

      test('retains the connection if its delegate is still open', () async {
        when(delegate.close).thenAnswer((_) async => false);
        final index = repository();
        await index.open();
        expect(await index.close(), isFalse);
        await index.open();
        verify(delegate.open).called(1);
      });
    });

    group('file operations', () {
      test('checks and deletes only the named index', () async {
        final deleted = <String>[];
        final index = repository(delete: (path) async => deleted.add(path));
        expect(await index.exists(), isFalse);
        await File('${directory.path}/images.db').writeAsString('index');
        expect(await index.exists(), isTrue);
        await index.deleteDataFile();
        expect(deleted, ['${directory.path}/images.db']);
      });
    });

    group('cache operations', () {
      test(
        'delegates rows and preserves touch and eviction arguments',
        () async {
          final row = CacheObject(
            'https://example.com/image.jpg',
            key: 'image',
            relativePath: 'image.jpg',
            validTill: DateTime.utc(2030),
          );
          final rows = [row];
          when(() => delegate.get('image')).thenAnswer((_) async => row);
          when(
            () => delegate.insert(row, setTouchedToNow: false),
          ).thenAnswer((_) async => row);
          when(
            () => delegate.update(row, setTouchedToNow: false),
          ).thenAnswer((_) async => 1);
          when(() => delegate.updateOrInsert(row)).thenAnswer((_) async => row);
          when(() => delegate.delete(1)).thenAnswer((_) async => 1);
          when(() => delegate.deleteAll([1, 2])).thenAnswer((_) async => 2);
          when(delegate.getAllObjects).thenAnswer((_) async => rows);
          when(
            () => delegate.getObjectsOverCapacity(10),
          ).thenAnswer((_) async => rows);
          when(
            () => delegate.getOldObjects(const Duration(days: 2)),
          ).thenAnswer((_) async => rows);
          final index = repository();
          await index.open();
          expect(await index.get('image'), same(row));
          expect(await index.insert(row, setTouchedToNow: false), same(row));
          expect(await index.update(row, setTouchedToNow: false), 1);
          expect(await index.updateOrInsert(row), same(row));
          expect(await index.delete(1), 1);
          expect(await index.deleteAll([1, 2]), 2);
          expect(await index.getAllObjects(), same(rows));
          expect(await index.getObjectsOverCapacity(10), same(rows));
          expect(
            await index.getOldObjects(const Duration(days: 2)),
            same(rows),
          );
          await index.close();
        },
      );
    });
  });
}
