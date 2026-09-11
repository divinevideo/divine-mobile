import 'dart:io';

import 'package:divine_ui/divine_ui.dart';
import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' as model;
import 'package:openvine/blocs/storage/storage_cubit.dart';
import 'package:openvine/constants/storage_cache_constants.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/screens/settings/storage/storage_management_page.dart';
import 'package:openvine/services/storage_management_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart' as editor;

import '../../../helpers/scroll.dart';

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
  final l10n = lookupAppLocalizations(const Locale('en'));

  Widget wrap(StorageCubit cubit) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: BlocProvider.value(
      value: cubit,
      child: const StorageManagementView(),
    ),
  );

  late _MockService service;

  setUpAll(() => registerFallbackValue(<DivineVideoClip>[]));

  setUp(() {
    service = _MockService();
    when(service.videoCacheLimitBytes).thenReturn(kCacheLimitDefaultBytes);
    when(service.cacheUsage).thenAnswer(
      (_) async => const CacheUsage(
        video: CacheUsageCategory(
          usedBytes: 3 * 1024 * 1024,
          limitBytes: kCacheLimitDefaultBytes,
        ),
        player: CacheUsageCategory(
          usedBytes: 0,
          limitBytes: kDefaultCacheMaxSizeBytes,
        ),
        images: CacheUsageCategory(usedBytes: 0),
        transitionSeams: CacheUsageCategory(
          usedBytes: 0,
          limitBytes: kSeamCacheLimitBytes,
        ),
        tempRenders: CacheUsageCategory(usedBytes: 0),
      ),
    );
    when(service.documentsUsage).thenAnswer(
      (_) async => const DocumentsUsage(
        contentBytes: 5 * 1024 * 1024,
        orphanedFileCount: 2,
        orphanedBytes: 1024 * 1024,
      ),
    );
  });

  group('renders', () {
    testWidgets('shows the cache size and both action buttons', (tester) async {
      final cubit = StorageCubit(service: service)..loadCacheSize();
      addTearDown(cubit.close);

      await tester.pumpWidget(wrap(cubit));
      await tester.pumpAndSettle();

      expect(
        find.text(l10n.settingsStorageCacheInUse('3.0 MB')),
        findsOneWidget,
      );
      expect(find.text(l10n.settingsStorageClearButton), findsOneWidget);
      expect(find.text(l10n.settingsStorageScanButton), findsOneWidget);
    });

    testWidgets('shows the cache-limit slider and approximate video count', (
      tester,
    ) async {
      final cubit = StorageCubit(service: service)..loadCacheSize();
      addTearDown(cubit.close);

      await tester.pumpWidget(wrap(cubit));
      await tester.pumpAndSettle();

      expect(find.text(l10n.settingsStorageMaxVideoCacheLabel), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
      // Default 2 GB budget / ~4 MB per video ≈ 512 videos.
      expect(find.text(l10n.settingsStorageApproxVideos(512)), findsOneWidget);
    });
  });

  group('content', () {
    testWidgets("shows what the user's content holds and the leftover files", (
      tester,
    ) async {
      final cubit = StorageCubit(service: service);
      addTearDown(cubit.close);
      await cubit.loadCacheSize();
      await cubit.loadDocumentsUsage();

      await tester.pumpWidget(wrap(cubit));
      await tester.pumpAndSettle();

      // Two "in use" lines, one per section: the cache the user can clear,
      // and the content — 5 MB owned by clips plus the 1 MB of leftovers.
      expect(
        find.text(l10n.settingsStorageCacheInUse('3.0 MB')),
        findsOneWidget,
      );
      expect(
        find.text(l10n.settingsStorageCacheInUse('6.0 MB')),
        findsOneWidget,
      );
      expect(
        find.text(l10n.settingsStorageOrphanedFilesFound(2, '1.0 MB')),
        findsOneWidget,
      );
      final button = tester.widget<DivineButton>(
        find.widgetWithText(
          DivineButton,
          l10n.settingsStorageRemoveOrphanedButton,
        ),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('reports no leftover files and disables removal', (
      tester,
    ) async {
      when(service.documentsUsage).thenAnswer(
        (_) async => const DocumentsUsage(
          contentBytes: 5 * 1024 * 1024,
          orphanedFileCount: 0,
          orphanedBytes: 0,
        ),
      );
      final cubit = StorageCubit(service: service);
      addTearDown(cubit.close);
      await cubit.loadCacheSize();
      await cubit.loadDocumentsUsage();

      await tester.pumpWidget(wrap(cubit));
      await tester.pumpAndSettle();

      expect(find.text(l10n.settingsStorageNoOrphanedFiles), findsOneWidget);
      final button = tester.widget<DivineButton>(
        find.widgetWithText(
          DivineButton,
          l10n.settingsStorageRemoveOrphanedButton,
        ),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('removing leftover files is gated behind a confirmation', (
      tester,
    ) async {
      when(service.removeOrphanedFiles).thenAnswer((_) async => 1024 * 1024);
      final cubit = StorageCubit(service: service);
      addTearDown(cubit.close);
      await cubit.loadCacheSize();
      await cubit.loadDocumentsUsage();

      await tester.pumpWidget(wrap(cubit));
      await tester.pumpAndSettle();
      // The sweep re-measures afterwards; the second answer is the empty one.
      when(service.documentsUsage).thenAnswer(
        (_) async => const DocumentsUsage(
          contentBytes: 5 * 1024 * 1024,
          orphanedFileCount: 0,
          orphanedBytes: 0,
        ),
      );

      await tester.tap(find.text(l10n.settingsStorageRemoveOrphanedButton));
      await tester.pumpAndSettle();

      expect(
        find.text(l10n.settingsStorageRemoveOrphanedConfirmTitle),
        findsOneWidget,
      );
      expect(
        find.text(
          l10n.settingsStorageRemoveOrphanedConfirmMessage(2, '1.0 MB'),
        ),
        findsOneWidget,
      );
      verifyNever(service.removeOrphanedFiles);

      await tester.tap(find.text(l10n.commonDelete));
      await tester.pumpAndSettle();

      verify(service.removeOrphanedFiles).called(1);
      expect(find.text(l10n.settingsStorageNoOrphanedFiles), findsOneWidget);
      // The figure above drops by what was freed.
      expect(
        find.text(l10n.settingsStorageCacheInUse('5.0 MB')),
        findsOneWidget,
      );
    });

    testWidgets('a failed measurement says so and keeps the cache section', (
      tester,
    ) async {
      when(service.documentsUsage).thenThrow(Exception('db closed'));
      final cubit = StorageCubit(service: service);
      addTearDown(cubit.close);
      await cubit.loadCacheSize();
      await cubit.loadDocumentsUsage();

      await tester.pumpWidget(wrap(cubit));
      await tester.pumpAndSettle();

      expect(find.text(l10n.settingsStorageError), findsOneWidget);
      expect(
        find.text(l10n.settingsStorageCacheInUse('3.0 MB')),
        findsOneWidget,
      );
    });
  });

  group('interactions', () {
    testWidgets('a scan with no broken clips reports a healthy library', (
      tester,
    ) async {
      when(service.findBrokenClips).thenAnswer((_) async => []);
      final cubit = StorageCubit(service: service)..loadCacheSize();
      addTearDown(cubit.close);

      await tester.pumpWidget(wrap(cubit));
      await tester.pumpAndSettle();
      await scrollUntilTappable(
        tester,
        find.text(l10n.settingsStorageScanButton),
        200,
      );
      await tester.tap(find.text(l10n.settingsStorageScanButton));
      await tester.pumpAndSettle();

      expect(find.text(l10n.settingsStorageLibraryHealthy), findsOneWidget);
    });

    testWidgets('a scan with broken clips offers and performs removal', (
      tester,
    ) async {
      when(service.findBrokenClips).thenAnswer((_) async => [_clip('a')]);
      when(() => service.removeBrokenClips(any())).thenAnswer((_) async {});
      final cubit = StorageCubit(service: service)..loadCacheSize();
      addTearDown(cubit.close);

      await tester.pumpWidget(wrap(cubit));
      await tester.pumpAndSettle();
      await scrollUntilTappable(
        tester,
        find.text(l10n.settingsStorageScanButton),
        200,
      );
      await tester.tap(find.text(l10n.settingsStorageScanButton));
      await tester.pumpAndSettle();

      expect(
        find.text(l10n.settingsStorageBrokenClipsFound(1)),
        findsOneWidget,
      );

      await scrollUntilTappable(
        tester,
        find.text(l10n.settingsStorageRemoveBrokenButton),
        200,
      );
      await tester.tap(find.text(l10n.settingsStorageRemoveBrokenButton));
      await tester.pumpAndSettle();

      // A confirmation sheet gates the permanent removal.
      expect(
        find.text(l10n.settingsStorageRemoveBrokenConfirmTitle),
        findsOneWidget,
      );
      verifyNever(() => service.removeBrokenClips(any()));

      await tester.tap(find.text(l10n.commonDelete));
      await tester.pumpAndSettle();

      verify(() => service.removeBrokenClips(any())).called(1);
    });

    testWidgets('dragging the cache-size slider commits a new limit', (
      tester,
    ) async {
      when(() => service.setVideoCacheLimit(any())).thenAnswer((_) async {});
      final cubit = StorageCubit(service: service)..loadCacheSize();
      addTearDown(cubit.close);

      await tester.pumpWidget(wrap(cubit));
      await tester.pumpAndSettle();

      // Drag ends -> onChangeEnd -> commitVideoCacheLimit -> setVideoCacheLimit.
      await tester.drag(find.byType(Slider), const Offset(120, 0));
      await tester.pumpAndSettle();

      verify(() => service.setVideoCacheLimit(any())).called(1);
    });
  });

  /// Scrolls the repair button into view and opens its confirmation sheet.
  Future<void> openRepairSheet(WidgetTester tester) async {
    final repair = find.text(l10n.settingsStorageRepairButton);
    await scrollUntilTappable(tester, repair, 200);
    await tester.tap(repair);
    await tester.pumpAndSettle();
  }

  group('repair', () {
    testWidgets('the repair wipe is gated behind a confirmation', (
      tester,
    ) async {
      var recovered = false;
      final cubit = StorageCubit(
        service: service,
        recoverAllCaches: () async {
          recovered = true;
          return true;
        },
        measureRecoveryFootprint: () async => 42 * 1024 * 1024,
      )..loadCacheSize();
      addTearDown(cubit.close);

      await tester.pumpWidget(wrap(cubit));
      await tester.pumpAndSettle();
      await openRepairSheet(tester);

      expect(find.text(l10n.settingsStorageRepairConfirmTitle), findsOneWidget);
      expect(recovered, isFalse);

      await tester.tap(find.text(l10n.settingsStorageRepairConfirmAction));
      await tester.pumpAndSettle();

      expect(recovered, isTrue);
      expect(find.text(l10n.settingsStorageRepairSuccess), findsOneWidget);
    });

    testWidgets('the confirmation sheet reports what the repair frees', (
      tester,
    ) async {
      final cubit = StorageCubit(
        service: service,
        measureRecoveryFootprint: () async => 42 * 1024 * 1024,
      )..loadCacheSize();
      addTearDown(cubit.close);

      await tester.pumpWidget(wrap(cubit));
      await tester.pumpAndSettle();

      // The size belongs to the decision, not to the screen — nothing is
      // measured or shown until the sheet opens.
      expect(
        find.text(l10n.settingsStorageRepairFootprint('42 MB')),
        findsNothing,
      );

      await openRepairSheet(tester);

      expect(
        find.text(l10n.settingsStorageRepairFootprint('42 MB')),
        findsOneWidget,
      );
    });

    testWidgets('a failed measurement leaves the sheet usable without a size', (
      tester,
    ) async {
      var recovered = false;
      final cubit = StorageCubit(
        service: service,
        recoverAllCaches: () async {
          recovered = true;
          return true;
        },
        measureRecoveryFootprint: () async => throw Exception('boom'),
      );
      addTearDown(cubit.close);
      await cubit.loadCacheSize();
      // The content section has its own "Measuring…" line while it loads;
      // let it settle so the assertion below is about the sheet alone.
      await cubit.loadDocumentsUsage();

      await tester.pumpWidget(wrap(cubit));
      await tester.pumpAndSettle();
      await openRepairSheet(tester);

      expect(find.text(l10n.settingsStorageRepairConfirmTitle), findsOneWidget);
      expect(find.text(l10n.settingsStorageMeasuring), findsNothing);

      await tester.tap(find.text(l10n.settingsStorageRepairConfirmAction));
      await tester.pumpAndSettle();

      expect(recovered, isTrue);
    });

    // The statuses are sticky, so a listener that matched the cache branch
    // first would keep re-announcing "Cache cleared" for every later outcome.
    testWidgets('announces the repair outcome after the cache was cleared', (
      tester,
    ) async {
      final announcements = <String>[];
      tester.binding.defaultBinaryMessenger
          .setMockDecodedMessageHandler<Object?>(SystemChannels.accessibility, (
            message,
          ) async {
            if (message is Map) {
              final data = message['data'] as Map<Object?, Object?>?;
              final text = data?['message'];
              if (text is String) announcements.add(text);
            }
            return null;
          });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger
            .setMockDecodedMessageHandler<Object?>(
              SystemChannels.accessibility,
              null,
            ),
      );
      when(service.clearCaches).thenAnswer((_) async {});

      final cubit = StorageCubit(
        service: service,
        recoverAllCaches: () async => true,
        measureRecoveryFootprint: () async => 0,
      )..loadCacheSize();
      addTearDown(cubit.close);

      await tester.pumpWidget(wrap(cubit));
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.settingsStorageClearButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.settingsStorageClearConfirmAction));
      await tester.pumpAndSettle();

      expect(announcements, [l10n.settingsStorageCleared]);

      await openRepairSheet(tester);
      await tester.tap(find.text(l10n.settingsStorageRepairConfirmAction));
      await tester.pumpAndSettle();

      expect(announcements.last, l10n.settingsStorageRepairSuccess);
    });

    testWidgets('a failed repair says so on the screen', (tester) async {
      final cubit = StorageCubit(
        service: service,
        recoverAllCaches: () async => false,
        measureRecoveryFootprint: () async => 0,
      )..loadCacheSize();
      addTearDown(cubit.close);

      await tester.pumpWidget(wrap(cubit));
      await tester.pumpAndSettle();
      await openRepairSheet(tester);

      await tester.tap(find.text(l10n.settingsStorageRepairConfirmAction));
      await tester.pumpAndSettle();

      expect(find.text(l10n.settingsStorageRepairFailure), findsOneWidget);
    });
  });
}
