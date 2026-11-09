import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_cache/media_cache.dart';
import 'package:mocktail/mocktail.dart';

import 'helpers/mocks.dart';
import 'helpers/test_helpers.dart';

void main() {
  setUpTestEnvironment();

  group('SafeCacheInfoRepository', () {
    late MockCacheInfoRepository mockRepository;
    late Directory testDirectory;

    setUpAll(() async {
      await setUpTestDirectories();
    });

    tearDownAll(() async {
      await tearDownTestDirectories();
    });

    setUp(() {
      mockRepository = MockCacheInfoRepository();
      testDirectory = Directory(testSupportPath);
    });

    test('can be instantiated with default dependencies', () {
      final repo = SafeCacheInfoRepository(databaseName: 'test_db');
      expect(repo, isNotNull);
    });

    test('can be instantiated with injected dependencies', () {
      final repo = SafeCacheInfoRepository(
        databaseName: 'test_db',
        repository: mockRepository,
        directoryProvider: () async => testDirectory,
      );

      expect(repo, isNotNull);
      expect(repo.repository, same(mockRepository));
    });

    group('open', () {
      test('delegates to wrapped repository on success', () async {
        when(() => mockRepository.open()).thenAnswer((_) async => true);

        final repo = SafeCacheInfoRepository(
          databaseName: 'test_db',
          repository: mockRepository,
          directoryProvider: () async => testDirectory,
        );

        final result = await repo.open();

        expect(result, true);
        verify(() => mockRepository.open()).called(1);
      });

      test('deletes cache file and retries on FormatException', () async {
        var openCallCount = 0;
        when(() => mockRepository.open()).thenAnswer((_) async {
          openCallCount++;
          if (openCallCount == 1) {
            throw const FormatException('corrupted JSON');
          }
          return true;
        });

        // Create a corrupted cache file
        final cacheFile = File('$testSupportPath/test_db.json');
        await cacheFile.writeAsString('{ corrupted }');
        expect(cacheFile.existsSync(), true);

        final repo = SafeCacheInfoRepository(
          databaseName: 'test_db',
          repository: mockRepository,
          directoryProvider: () async => testDirectory,
        );

        final result = await repo.open();

        expect(result, true);
        expect(openCallCount, 2); // Called twice: fail then retry
        expect(cacheFile.existsSync(), false); // File was deleted
      });

      test(
        'deletes cache file and retries on Unexpected end of input',
        () async {
          var openCallCount = 0;
          when(() => mockRepository.open()).thenAnswer((_) async {
            openCallCount++;
            if (openCallCount == 1) {
              throw Exception('Unexpected end of input');
            }
            return true;
          });

          // Create a cache file
          final cacheFile = File('$testSupportPath/test_db2.json');
          await cacheFile.writeAsString('');
          expect(cacheFile.existsSync(), true);

          final repo = SafeCacheInfoRepository(
            databaseName: 'test_db2',
            repository: mockRepository,
            directoryProvider: () async => testDirectory,
          );

          final result = await repo.open();

          expect(result, true);
          expect(openCallCount, 2);
          expect(cacheFile.existsSync(), false);
        },
      );

      test('deletes cache file and retries on type Null exception', () async {
        var openCallCount = 0;
        when(() => mockRepository.open()).thenAnswer((_) async {
          openCallCount++;
          if (openCallCount == 1) {
            throw Exception("type 'Null' is not a subtype of type 'Map'");
          }
          return true;
        });

        // Create a cache file
        final cacheFile = File('$testSupportPath/test_db3.json');
        await cacheFile.writeAsString('null');
        expect(cacheFile.existsSync(), true);

        final repo = SafeCacheInfoRepository(
          databaseName: 'test_db3',
          repository: mockRepository,
          directoryProvider: () async => testDirectory,
        );

        final result = await repo.open();

        expect(result, true);
        expect(openCallCount, 2);
        expect(cacheFile.existsSync(), false);
      });

      test('deletes a corrupt index before the repository opens it', () async {
        // The real-world shape: upstream swallows the parse failure and
        // reports it, so the wrapper has to resolve the corruption before
        // delegating rather than react to it afterwards.
        var openCallCount = 0;
        when(() => mockRepository.open()).thenAnswer((_) async {
          openCallCount++;
          return true;
        });

        final cacheFile = File('$testSupportPath/test_corrupt_index.json');
        await cacheFile.writeAsString('{"truncated":');

        final repo = SafeCacheInfoRepository(
          databaseName: 'test_corrupt_index',
          repository: mockRepository,
          directoryProvider: () async => testDirectory,
        );

        expect(await repo.open(), isTrue);
        expect(cacheFile.existsSync(), isFalse);
        // Once, not twice: the repository never sees the corrupt file, so
        // there is nothing to recover from and no retry to make.
        expect(openCallCount, equals(1));
      });

      test('deletes an index whose entries cannot be mapped', () async {
        // Well-formed JSON that CacheObject.fromMap still rejects. Upstream
        // treats this exactly like a syntax error, so this must too.
        when(() => mockRepository.open()).thenAnswer((_) async => true);

        final cacheFile = File('$testSupportPath/test_bad_entries.json');
        await cacheFile.writeAsString(
          jsonEncode([
            {'url': 'https://example.com/a.jpg'},
          ]),
        );

        final repo = SafeCacheInfoRepository(
          databaseName: 'test_bad_entries',
          repository: mockRepository,
          directoryProvider: () async => testDirectory,
        );

        await repo.open();

        expect(cacheFile.existsSync(), isFalse);
      });

      test('keeps a readable index', () async {
        when(() => mockRepository.open()).thenAnswer((_) async => true);

        final cacheFile = File('$testSupportPath/test_valid_index.json');
        await cacheFile.writeAsString(
          jsonEncode([
            CacheObject(
              'https://example.com/a.jpg',
              relativePath: 'a.jpg',
              validTill: DateTime.now().add(const Duration(days: 1)),
              id: 1,
            ).toMap(),
          ]),
        );

        final repo = SafeCacheInfoRepository(
          databaseName: 'test_valid_index',
          repository: mockRepository,
          directoryProvider: () async => testDirectory,
        );

        await repo.open();

        expect(cacheFile.existsSync(), isTrue);
      });

      test(
        'leaves FlutterError.onError untouched across concurrent opens',
        () async {
          // The regression this guards: open() used to swap the process-global
          // FlutterError.onError and restore it by assignment. CacheStore's
          // constructor fires repo.open() eagerly and unawaited, and the app
          // builds two managers, so those windows overlap.
          //
          // Restore-by-assignment is only correct when the opens finish LIFO.
          // The completers below force the other order — the repository that
          // installed first also finishes first — which dropped the second
          // handler and then permanently reinstalled the first, stale one. A
          // production stack showed three of these chained together.
          final firstOpen = Completer<bool>();
          final secondOpen = Completer<bool>();
          final secondRepository = MockCacheInfoRepository();
          when(() => mockRepository.open()).thenAnswer((_) => firstOpen.future);
          when(secondRepository.open).thenAnswer((_) => secondOpen.future);

          final previousHandler = FlutterError.onError;
          void sentinel(FlutterErrorDetails details) {}
          FlutterError.onError = sentinel;
          addTearDown(() => FlutterError.onError = previousHandler);

          final first = SafeCacheInfoRepository(
            databaseName: 'test_concurrent_a',
            repository: mockRepository,
            directoryProvider: () async => testDirectory,
          );
          final second = SafeCacheInfoRepository(
            databaseName: 'test_concurrent_b',
            repository: secondRepository,
            directoryProvider: () async => testDirectory,
          );

          final firstFuture = first.open();
          final secondFuture = second.open();

          firstOpen.complete(true);
          await firstFuture;
          secondOpen.complete(true);
          await secondFuture;

          expect(FlutterError.onError, same(sentinel));
        },
      );

      test('a corrupt index for one database leaves another intact', () async {
        // The old interception keyed only on library: 'flutter cache manager',
        // which carries no file identity, so an overlapping open could
        // attribute one cache's corruption to the other and delete a
        // healthy index.
        when(() => mockRepository.open()).thenAnswer((_) async => true);

        final corrupt = File('$testSupportPath/test_isolation_corrupt.json');
        await corrupt.writeAsString('not json at all');
        final healthy = File('$testSupportPath/test_isolation_healthy.json');
        await healthy.writeAsString(
          jsonEncode([
            CacheObject(
              'https://example.com/b.jpg',
              relativePath: 'b.jpg',
              validTill: DateTime.now().add(const Duration(days: 1)),
              id: 1,
            ).toMap(),
          ]),
        );

        final corruptRepo = SafeCacheInfoRepository(
          databaseName: 'test_isolation_corrupt',
          repository: mockRepository,
          directoryProvider: () async => testDirectory,
        );
        final healthyRepo = SafeCacheInfoRepository(
          databaseName: 'test_isolation_healthy',
          repository: MockCacheInfoRepository(),
          directoryProvider: () async => testDirectory,
        );
        when(() => healthyRepo.repository.open()).thenAnswer((_) async => true);

        await Future.wait([corruptRepo.open(), healthyRepo.open()]);

        expect(corrupt.existsSync(), isFalse);
        expect(healthy.existsSync(), isTrue);
      });

      test(
        'propagates a retry failure instead of deleting and reopening again',
        () async {
          var openCallCount = 0;
          when(() => mockRepository.open()).thenAnswer((_) async {
            openCallCount++;
            throw const FormatException('still unreadable');
          });

          final repo = SafeCacheInfoRepository(
            databaseName: 'test_retry_failure',
            repository: mockRepository,
            directoryProvider: () async => testDirectory,
          );

          await expectLater(repo.open(), throwsA(isA<FormatException>()));

          // One delete-and-retry, then the failure is the caller's. It must
          // not re-enter the recovery path a second time.
          expect(openCallCount, equals(2));
        },
      );

      test('rethrows non-recoverable exceptions', () async {
        when(() => mockRepository.open()).thenThrow(
          Exception('Some other error'),
        );

        final repo = SafeCacheInfoRepository(
          databaseName: 'test_db',
          repository: mockRepository,
          directoryProvider: () async => testDirectory,
        );

        expect(
          repo.open,
          throwsA(isA<Exception>()),
        );
      });

      test('handles missing cache file gracefully during deletion', () async {
        var openCallCount = 0;
        when(() => mockRepository.open()).thenAnswer((_) async {
          openCallCount++;
          if (openCallCount == 1) {
            throw const FormatException('corrupted');
          }
          return true;
        });

        // Don't create a cache file - it doesn't exist
        final cacheFile = File('$testSupportPath/nonexistent.json');
        expect(cacheFile.existsSync(), false);

        final repo = SafeCacheInfoRepository(
          databaseName: 'nonexistent',
          repository: mockRepository,
          directoryProvider: () async => testDirectory,
        );

        // Should not throw even when file doesn't exist
        final result = await repo.open();
        expect(result, true);
      });
    });

    group('deleteCacheFile', () {
      test('deletes existing cache file', () async {
        final cacheFile = File('$testSupportPath/delete_test.json');
        await cacheFile.writeAsString('test content');
        expect(cacheFile.existsSync(), true);

        final repo = SafeCacheInfoRepository(
          databaseName: 'delete_test',
          repository: mockRepository,
          directoryProvider: () async => testDirectory,
        );

        await repo.deleteCacheFile();

        expect(cacheFile.existsSync(), false);
      });

      test('does nothing when cache file does not exist', () async {
        final cacheFile = File('$testSupportPath/no_file.json');
        expect(cacheFile.existsSync(), false);

        final repo = SafeCacheInfoRepository(
          databaseName: 'no_file',
          repository: mockRepository,
          directoryProvider: () async => testDirectory,
        );

        // Should not throw
        await repo.deleteCacheFile();
        expect(cacheFile.existsSync(), false);
      });

      test('treats an index another delete removed first as deleted', () async {
        // The cache store and the manifest load both open the repository at
        // startup, so both validate a corrupt index and both delete it. The
        // losing delete finds the file present, then gone.
        final indexPath = '$testSupportPath/raced_index.json';
        final indexFile = MockFile();
        when(() => indexFile.path).thenReturn(indexPath);
        when(indexFile.existsSync).thenReturn(true);
        when(indexFile.delete).thenThrow(
          PathNotFoundException(
            indexPath,
            const OSError('No such file or directory', 2),
            'Cannot delete file',
          ),
        );

        final repo = SafeCacheInfoRepository(
          databaseName: 'raced_index',
          repository: mockRepository,
          directoryProvider: () async => testDirectory,
        );

        await expectLater(
          IOOverrides.runZoned(
            repo.deleteCacheFile,
            createFile: (_) => indexFile,
          ),
          completes,
        );
      });

      test('rethrows a delete that fails for another reason', () async {
        final indexPath = '$testSupportPath/locked_index.json';
        final indexFile = MockFile();
        when(() => indexFile.path).thenReturn(indexPath);
        when(indexFile.existsSync).thenReturn(true);
        when(indexFile.delete).thenThrow(
          FileSystemException(
            'Cannot delete file',
            indexPath,
            const OSError('Operation not permitted', 1),
          ),
        );

        final repo = SafeCacheInfoRepository(
          databaseName: 'locked_index',
          repository: mockRepository,
          directoryProvider: () async => testDirectory,
        );

        await expectLater(
          IOOverrides.runZoned(
            repo.deleteCacheFile,
            createFile: (_) => indexFile,
          ),
          throwsA(isA<FileSystemException>()),
        );
      });
    });

    group('delegation', () {
      test('close delegates to wrapped repository', () async {
        when(() => mockRepository.close()).thenAnswer((_) async => true);

        final repo = SafeCacheInfoRepository(
          databaseName: 'test_db',
          repository: mockRepository,
        );

        final result = await repo.close();

        expect(result, true);
        verify(() => mockRepository.close()).called(1);
      });

      test('exists delegates to wrapped repository', () async {
        when(() => mockRepository.exists()).thenAnswer((_) async => true);

        final repo = SafeCacheInfoRepository(
          databaseName: 'test_db',
          repository: mockRepository,
        );

        final result = await repo.exists();

        expect(result, true);
        verify(() => mockRepository.exists()).called(1);
      });

      test('get delegates to wrapped repository', () async {
        when(() => mockRepository.get('key')).thenAnswer((_) async => null);

        final repo = SafeCacheInfoRepository(
          databaseName: 'test_db',
          repository: mockRepository,
        );

        final result = await repo.get('key');

        expect(result, isNull);
        verify(() => mockRepository.get('key')).called(1);
      });

      test('getAllObjects delegates to wrapped repository', () async {
        when(() => mockRepository.getAllObjects()).thenAnswer((_) async => []);

        final repo = SafeCacheInfoRepository(
          databaseName: 'test_db',
          repository: mockRepository,
        );

        final result = await repo.getAllObjects();

        expect(result, isEmpty);
        verify(() => mockRepository.getAllObjects()).called(1);
      });

      test('delete delegates to wrapped repository', () async {
        when(() => mockRepository.delete(1)).thenAnswer((_) async => 1);

        final repo = SafeCacheInfoRepository(
          databaseName: 'test_db',
          repository: mockRepository,
        );

        final result = await repo.delete(1);

        expect(result, 1);
        verify(() => mockRepository.delete(1)).called(1);
      });

      test('deleteAll delegates to wrapped repository', () async {
        when(() => mockRepository.deleteAll([1, 2])).thenAnswer((_) async => 2);

        final repo = SafeCacheInfoRepository(
          databaseName: 'test_db',
          repository: mockRepository,
        );

        final result = await repo.deleteAll([1, 2]);

        expect(result, 2);
        verify(() => mockRepository.deleteAll([1, 2])).called(1);
      });

      test('deleteDataFile delegates to wrapped repository', () async {
        when(() => mockRepository.deleteDataFile()).thenAnswer((_) async {});

        final repo = SafeCacheInfoRepository(
          databaseName: 'test_db',
          repository: mockRepository,
        );

        await repo.deleteDataFile();

        verify(() => mockRepository.deleteDataFile()).called(1);
      });

      test('getObjectsOverCapacity delegates to wrapped repository', () async {
        when(
          () => mockRepository.getObjectsOverCapacity(100),
        ).thenAnswer((_) async => []);

        final repo = SafeCacheInfoRepository(
          databaseName: 'test_db',
          repository: mockRepository,
        );

        final result = await repo.getObjectsOverCapacity(100);

        expect(result, isEmpty);
        verify(() => mockRepository.getObjectsOverCapacity(100)).called(1);
      });

      test('getOldObjects delegates to wrapped repository', () async {
        const maxAge = Duration(days: 7);
        when(
          () => mockRepository.getOldObjects(maxAge),
        ).thenAnswer((_) async => []);

        final repo = SafeCacheInfoRepository(
          databaseName: 'test_db',
          repository: mockRepository,
        );

        final result = await repo.getOldObjects(maxAge);

        expect(result, isEmpty);
        verify(() => mockRepository.getOldObjects(maxAge)).called(1);
      });

      test('insert delegates to wrapped repository', () async {
        final cacheObject = CacheObject(
          'test_url',
          relativePath: 'test.mp4',
          validTill: DateTime.now().add(const Duration(days: 7)),
        );
        when(
          () => mockRepository.insert(cacheObject),
        ).thenAnswer((_) async => cacheObject);

        final repo = SafeCacheInfoRepository(
          databaseName: 'test_db',
          repository: mockRepository,
        );

        final result = await repo.insert(cacheObject);

        expect(result, cacheObject);
        verify(
          () => mockRepository.insert(cacheObject),
        ).called(1);
      });

      test('update delegates to wrapped repository', () async {
        final cacheObject = CacheObject(
          'test_url',
          relativePath: 'test.mp4',
          validTill: DateTime.now().add(const Duration(days: 7)),
        );
        when(
          () => mockRepository.update(cacheObject),
        ).thenAnswer((_) async => 1);

        final repo = SafeCacheInfoRepository(
          databaseName: 'test_db',
          repository: mockRepository,
        );

        final result = await repo.update(cacheObject);

        expect(result, 1);
        verify(
          () => mockRepository.update(cacheObject),
        ).called(1);
      });

      test('updateOrInsert delegates to wrapped repository', () async {
        final cacheObject = CacheObject(
          'test_url',
          relativePath: 'test.mp4',
          validTill: DateTime.now().add(const Duration(days: 7)),
        );
        when(
          () => mockRepository.updateOrInsert(cacheObject),
        ).thenAnswer((_) async => cacheObject);

        final repo = SafeCacheInfoRepository(
          databaseName: 'test_db',
          repository: mockRepository,
        );

        final result = await repo.updateOrInsert(cacheObject);

        expect(result, cacheObject);
        verify(() => mockRepository.updateOrInsert(cacheObject)).called(1);
      });
    });
  });
}
