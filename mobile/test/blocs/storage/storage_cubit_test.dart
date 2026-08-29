import 'dart:async';
import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' as model;
import 'package:openvine/blocs/storage/storage_cubit.dart';
import 'package:openvine/constants/storage_cache_constants.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/storage_footprint.dart';
import 'package:openvine/services/storage_management_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart' as editor;

class _MockService extends Mock implements StorageManagementService {}

DivineVideoClip _clip(String id) => DivineVideoClip(
  id: id,
  video: editor.EditorVideo.file(File('/tmp/$id.mp4')),
  duration: const Duration(seconds: 3),
  recordedAt: DateTime(2024),
  targetAspectRatio: model.AspectRatio.square,
  originalAspectRatio: 1,
);

void main() {
  setUpAll(() => registerFallbackValue(<DivineVideoClip>[]));

  group(StorageCubit, () {
    late _MockService service;

    setUp(() => service = _MockService());

    StorageCubit build() => StorageCubit(service: service);

    // A non-default budget, mirrored by the stubbed `videoCacheLimitBytes`:
    // `cacheUsage()` builds the video category's limit from that same prefs
    // read, so the two can never disagree in production.
    const configuredVideoLimit = 1536 * 1024 * 1024;

    const cacheUsage = CacheUsage(
      video: CacheUsageCategory(
        usedBytes: 1024,
        limitBytes: configuredVideoLimit,
      ),
      images: CacheUsageCategory(usedBytes: 512, limitBytes: 4 * 1024),
      transitionSeams: CacheUsageCategory(usedBytes: 256, limitBytes: 8 * 1024),
      tempRenders: CacheUsageCategory(usedBytes: 256),
    );

    group('loadCacheSize', () {
      // A non-default saved budget so the failure test proves the limit
      // survives a size-measurement failure rather than resetting to default.
      const savedLimit = 3 * 1024 * 1024 * 1024;

      blocTest<StorageCubit, StorageState>(
        'emits loading then ready with the size',
        setUp: () {
          when(service.videoCacheLimitBytes).thenReturn(configuredVideoLimit);
          when(service.cacheUsage).thenAnswer((_) async => cacheUsage);
        },
        build: build,
        act: (cubit) => cubit.loadCacheSize(),
        expect: () => const [
          StorageState(
            cacheStatus: StorageCacheStatus.loading,
            videoCacheLimitBytes: configuredVideoLimit,
          ),
          StorageState(
            cacheStatus: StorageCacheStatus.ready,
            cacheSizeBytes: 2048,
            cacheUsage: cacheUsage,
            videoCacheLimitBytes: configuredVideoLimit,
          ),
        ],
      );

      blocTest<StorageCubit, StorageState>(
        'keeps the saved limit and emits failure when sizing throws',
        setUp: () {
          when(service.videoCacheLimitBytes).thenReturn(savedLimit);
          when(service.cacheUsage).thenThrow(Exception('boom'));
        },
        build: build,
        act: (cubit) => cubit.loadCacheSize(),
        expect: () => const [
          StorageState(
            cacheStatus: StorageCacheStatus.loading,
            videoCacheLimitBytes: savedLimit,
          ),
          StorageState(
            cacheStatus: StorageCacheStatus.failure,
            videoCacheLimitBytes: savedLimit,
          ),
        ],
        errors: () => [isA<Exception>()],
      );
    });

    group('clearCaches', () {
      blocTest<StorageCubit, StorageState>(
        'emits clearing then ready with the refreshed size',
        setUp: () {
          when(service.clearCaches).thenAnswer((_) async {});
          when(service.cacheUsage).thenAnswer((_) async => CacheUsage.empty);
        },
        build: build,
        seed: () => const StorageState(cacheSizeBytes: 4096),
        act: (cubit) => cubit.clearCaches(),
        expect: () => const [
          StorageState(
            cacheStatus: StorageCacheStatus.clearing,
            cacheSizeBytes: 4096,
          ),
          StorageState(cacheStatus: StorageCacheStatus.cleared),
        ],
      );
    });

    group('scanLibrary', () {
      blocTest<StorageCubit, StorageState>(
        'emits scanning then scanned with the broken clips',
        setUp: () =>
            when(service.findBrokenClips).thenAnswer((_) async => [_clip('a')]),
        build: build,
        act: (cubit) => cubit.scanLibrary(),
        expect: () => [
          const StorageState(libraryStatus: StorageLibraryStatus.scanning),
          isA<StorageState>()
              .having(
                (s) => s.libraryStatus,
                'libraryStatus',
                StorageLibraryStatus.scanned,
              )
              .having((s) => s.brokenClips.map((c) => c.id), 'ids', ['a']),
        ],
      );
    });

    group('removeBrokenClips', () {
      blocTest<StorageCubit, StorageState>(
        'emits cleaning then cleaned and empties the list',
        setUp: () => when(
          () => service.removeBrokenClips(any()),
        ).thenAnswer((_) async {}),
        build: build,
        seed: () => StorageState(
          libraryStatus: StorageLibraryStatus.scanned,
          brokenClips: [_clip('a')],
        ),
        act: (cubit) => cubit.removeBrokenClips(),
        expect: () => [
          isA<StorageState>().having(
            (s) => s.libraryStatus,
            'status',
            StorageLibraryStatus.cleaning,
          ),
          const StorageState(libraryStatus: StorageLibraryStatus.cleaned),
        ],
      );

      blocTest<StorageCubit, StorageState>(
        'does nothing when there are no broken clips',
        build: build,
        act: (cubit) => cubit.removeBrokenClips(),
        expect: () => const <StorageState>[],
      );
    });

    group('cache limit', () {
      const oneGb = 1024 * 1024 * 1024;

      blocTest<StorageCubit, StorageState>(
        'previewVideoCacheLimit updates the limit without persisting',
        build: build,
        act: (cubit) => cubit.previewVideoCacheLimit(oneGb),
        expect: () => const [StorageState(videoCacheLimitBytes: oneGb)],
        verify: (_) => verifyNever(() => service.setVideoCacheLimit(any())),
      );

      blocTest<StorageCubit, StorageState>(
        'commitVideoCacheLimit persists the limit and refreshes the size',
        setUp: () {
          when(
            () => service.setVideoCacheLimit(any()),
          ).thenAnswer((_) async {});
          when(service.cacheUsage).thenAnswer(
            (_) async => const CacheUsage(
              video: CacheUsageCategory(usedBytes: 512, limitBytes: oneGb),
              images: CacheUsageCategory(usedBytes: 0),
              transitionSeams: CacheUsageCategory(
                usedBytes: 0,
                limitBytes: kSeamCacheLimitBytes,
              ),
              tempRenders: CacheUsageCategory(usedBytes: 0),
            ),
          );
          when(service.videoCacheLimitBytes).thenReturn(oneGb);
        },
        build: build,
        act: (cubit) => cubit.commitVideoCacheLimit(oneGb),
        expect: () => const [
          StorageState(
            cacheStatus: StorageCacheStatus.loading,
            videoCacheLimitBytes: oneGb,
          ),
          StorageState(
            cacheStatus: StorageCacheStatus.ready,
            videoCacheLimitBytes: oneGb,
            cacheSizeBytes: 512,
            cacheUsage: CacheUsage(
              video: CacheUsageCategory(usedBytes: 512, limitBytes: oneGb),
              images: CacheUsageCategory(usedBytes: 0),
              transitionSeams: CacheUsageCategory(
                usedBytes: 0,
                limitBytes: kSeamCacheLimitBytes,
              ),
              tempRenders: CacheUsageCategory(usedBytes: 0),
            ),
          ),
        ],
        verify: (_) =>
            verify(() => service.setVideoCacheLimit(oneGb)).called(1),
      );
    });

    group('recovery', () {
      const footprintBytes = 42 * 1024 * 1024;

      blocTest<StorageCubit, StorageState>(
        'fails closed when cache recovery was not injected',
        build: build,
        act: (cubit) => cubit.recoverFromCorruptedCache(),
        expect: () => const [
          StorageState(recoveryStatus: StorageRecoveryStatus.recovering),
          StorageState(recoveryStatus: StorageRecoveryStatus.failure),
        ],
        errors: () => [isA<StateError>()],
      );

      blocTest<StorageCubit, StorageState>(
        'loadRecoveryFootprint emits measuring then the measured footprint',
        build: () => StorageCubit(
          service: service,
          measureRecoveryFootprint: () async => footprintBytes,
        ),
        act: (cubit) => cubit.loadRecoveryFootprint(),
        expect: () => const [
          StorageState(recoveryStatus: StorageRecoveryStatus.measuring),
          StorageState(
            recoveryStatus: StorageRecoveryStatus.measured,
            recoveryFootprintBytes: footprintBytes,
          ),
        ],
      );

      blocTest<StorageCubit, StorageState>(
        'loadRecoveryFootprint falls back to idle when measuring throws, so '
        'the sheet hides the size instead of reporting a failed wipe',
        build: () => StorageCubit(
          service: service,
          measureRecoveryFootprint: () async => throw Exception('boom'),
        ),
        act: (cubit) => cubit.loadRecoveryFootprint(),
        expect: () => const [
          StorageState(recoveryStatus: StorageRecoveryStatus.measuring),
          StorageState(),
        ],
        errors: () => [isA<Exception>()],
      );

      blocTest<StorageCubit, StorageState>(
        'recoverFromCorruptedCache clears the stale footprint on success',
        build: () => StorageCubit(
          service: service,
          recoverAllCaches: () async => true,
          measureRecoveryFootprint: () async => footprintBytes,
        ),
        act: (cubit) async {
          await cubit.loadRecoveryFootprint();
          await cubit.recoverFromCorruptedCache();
        },
        skip: 2,
        expect: () => const [
          StorageState(
            recoveryStatus: StorageRecoveryStatus.recovering,
            recoveryFootprintBytes: footprintBytes,
          ),
          StorageState(recoveryStatus: StorageRecoveryStatus.recovered),
        ],
      );

      blocTest<StorageCubit, StorageState>(
        'recoverFromCorruptedCache emits failure when the wipe reports false',
        build: () =>
            StorageCubit(service: service, recoverAllCaches: () async => false),
        act: (cubit) => cubit.recoverFromCorruptedCache(),
        expect: () => const [
          StorageState(recoveryStatus: StorageRecoveryStatus.recovering),
          StorageState(recoveryStatus: StorageRecoveryStatus.failure),
        ],
      );

      blocTest<StorageCubit, StorageState>(
        'recoverFromCorruptedCache emits failure when the wipe throws',
        build: () => StorageCubit(
          service: service,
          recoverAllCaches: () async => throw Exception('boom'),
        ),
        act: (cubit) => cubit.recoverFromCorruptedCache(),
        expect: () => const [
          StorageState(recoveryStatus: StorageRecoveryStatus.recovering),
          StorageState(recoveryStatus: StorageRecoveryStatus.failure),
        ],
        errors: () => [isA<Exception>()],
      );

      // The screen fires the measure unawaited alongside the sheet, so a slow
      // walk can still be in flight when the user confirms. Landing on top of
      // the wipe would clear the "Repairing" line and re-enable the
      // destructive button mid-wipe.
      test(
        'a measurement landing mid-wipe does not overwrite recovering',
        () async {
          final measure = Completer<int>();
          final wipe = Completer<bool>();
          final cubit = StorageCubit(
            service: service,
            measureRecoveryFootprint: () => measure.future,
            recoverAllCaches: () => wipe.future,
          );
          addTearDown(cubit.close);

          unawaited(cubit.loadRecoveryFootprint());
          unawaited(cubit.recoverFromCorruptedCache());
          expect(cubit.state.recoveryStatus, StorageRecoveryStatus.recovering);

          measure.complete(footprintBytes);
          await pumpEventQueue();

          expect(cubit.state.recoveryStatus, StorageRecoveryStatus.recovering);
          expect(cubit.state.recoveryFootprintBytes, 0);

          wipe.complete(true);
          await pumpEventQueue();

          expect(cubit.state.recoveryStatus, StorageRecoveryStatus.recovered);
        },
      );

      test('a measurement landing after close does not emit', () async {
        final measure = Completer<int>();
        final cubit = StorageCubit(
          service: service,
          measureRecoveryFootprint: () => measure.future,
        );

        unawaited(cubit.loadRecoveryFootprint());
        await cubit.close();
        measure.complete(footprintBytes);

        await expectLater(pumpEventQueue(), completes);
      });

      test('a failed measurement landing after close does not emit', () async {
        final measure = Completer<int>();
        final cubit = StorageCubit(
          service: service,
          measureRecoveryFootprint: () => measure.future,
        );

        unawaited(cubit.loadRecoveryFootprint());
        await cubit.close();
        measure.completeError(Exception('boom'));

        await expectLater(pumpEventQueue(), completes);
      });

      test('a wipe landing after close does not emit', () async {
        final wipe = Completer<bool>();
        final cubit = StorageCubit(
          service: service,
          recoverAllCaches: () => wipe.future,
        );

        unawaited(cubit.recoverFromCorruptedCache());
        await cubit.close();
        wipe.complete(true);

        await expectLater(pumpEventQueue(), completes);
      });
    });

    group('measureFootprint', () {
      const footprint = StorageFootprint(
        roots: [
          StorageFootprintRoot(
            label: 'Documents',
            path: '/documents',
            totalBytes: 2048,
            largestChildren: [
              StorageFootprintEntry(
                name: 'divine_1.mp4',
                bytes: 2048,
                isDirectory: false,
              ),
            ],
            childCount: 1,
          ),
        ],
      );

      blocTest<StorageCubit, StorageState>(
        'emits the measured footprint',
        setUp: () => when(
          () => service.measureFootprint(),
        ).thenAnswer((_) async => footprint),
        build: build,
        act: (cubit) => cubit.measureFootprint(),
        expect: () => const [
          StorageState(footprintStatus: StorageFootprintStatus.measuring),
          StorageState(
            footprintStatus: StorageFootprintStatus.measured,
            footprint: footprint,
          ),
        ],
      );

      blocTest<StorageCubit, StorageState>(
        'emits failure when the walk throws',
        setUp: () =>
            when(() => service.measureFootprint()).thenThrow(Exception('boom')),
        build: build,
        act: (cubit) => cubit.measureFootprint(),
        expect: () => const [
          StorageState(footprintStatus: StorageFootprintStatus.measuring),
          StorageState(footprintStatus: StorageFootprintStatus.failure),
        ],
        errors: () => [isA<Exception>()],
      );

      test('a measurement landing after close does not emit', () async {
        final walk = Completer<StorageFootprint>();
        when(() => service.measureFootprint()).thenAnswer((_) => walk.future);
        final cubit = build();

        unawaited(cubit.measureFootprint());
        await cubit.close();
        walk.complete(footprint);

        await expectLater(pumpEventQueue(), completes);
      });
    });
  });
}
