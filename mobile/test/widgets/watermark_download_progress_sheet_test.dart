// ABOUTME: Tests for WatermarkDownloadProgressSheet widget
// ABOUTME: Validates UI states: loading, success, permission-denied (+ retry), failure

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/watermark_download_provider.dart';
import 'package:openvine/services/watermark_download_service.dart';
import 'package:openvine/widgets/watermark_download_progress_sheet.dart';
import 'package:permissions_service/permissions_service.dart';

class _MockWatermarkDownloadService extends Mock
    implements WatermarkDownloadService {}

class _MockPermissionsService extends Mock implements PermissionsService {}

VideoEvent _createTestVideo() => VideoEvent(
  id: 'test-video-id-0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
  pubkey:
      'pubkey-0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
  createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
  content: 'Test video',
  timestamp: DateTime.now(),
  videoUrl: 'https://example.com/video.mp4',
);

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  final l10nDe = lookupAppLocalizations(const Locale('de'));

  late _MockWatermarkDownloadService mockService;
  late _MockPermissionsService mockPermissions;

  setUpAll(() {
    registerFallbackValue(_createTestVideo());
    registerFallbackValue(WatermarkDownloadStage.downloading);
  });

  setUp(() {
    mockService = _MockWatermarkDownloadService();
    mockPermissions = _MockPermissionsService();
  });

  Widget buildTestWidget({required VideoEvent video}) {
    return ProviderScope(
      overrides: [
        watermarkDownloadServiceProvider.overrideWithValue(mockService),
        permissionsServiceProvider.overrideWithValue(mockPermissions),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData.dark(),
        home: Builder(
          builder: (context) {
            return Consumer(
              builder: (context, ref, _) {
                return Scaffold(
                  body: ElevatedButton(
                    onPressed: () {
                      showWatermarkDownloadSheet(
                        context: context,
                        ref: ref,
                        video: video,
                        watermarkText: 'TestUser',
                      );
                    },
                    child: const Text('Show Sheet'),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> pumpSheet(
    WidgetTester tester, {
    required VideoEvent video,
  }) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(buildTestWidget(video: video));
  }

  group('showWatermarkDownloadSheet', () {
    testWidgets('shows progress indicator while downloading', (tester) async {
      final neverComplete = Completer<WatermarkDownloadResult>();

      when(
        () => mockService.downloadWithWatermark(
          video: any(named: 'video'),
          watermarkText: any(named: 'watermarkText'),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenAnswer((invocation) {
        final onProgress =
            invocation.namedArguments[#onProgress]
                as void Function(WatermarkDownloadStage);
        onProgress(WatermarkDownloadStage.downloading);
        return neverComplete.future;
      });

      await pumpSheet(tester, video: _createTestVideo());
      await tester.tap(find.text('Show Sheet'));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        find.text(l10n.watermarkDownloadStageDownloading),
        findsOneWidget,
      );
      // Prove the widget actually reads from l10n
      expect(
        find.text(l10nDe.watermarkDownloadStageDownloading),
        findsNothing,
      );
    });

    testWidgets('shows watermarking stage label', (tester) async {
      final neverComplete = Completer<WatermarkDownloadResult>();

      when(
        () => mockService.downloadWithWatermark(
          video: any(named: 'video'),
          watermarkText: any(named: 'watermarkText'),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenAnswer((invocation) {
        final onProgress =
            invocation.namedArguments[#onProgress]
                as void Function(WatermarkDownloadStage);
        onProgress(WatermarkDownloadStage.watermarking);
        return neverComplete.future;
      });

      await pumpSheet(tester, video: _createTestVideo());
      await tester.tap(find.text('Show Sheet'));
      await tester.pump();

      expect(
        find.text(l10n.watermarkDownloadStageWatermarking),
        findsOneWidget,
      );
    });

    testWidgets('shows success state after completed download', (tester) async {
      when(
        () => mockService.downloadWithWatermark(
          video: any(named: 'video'),
          watermarkText: any(named: 'watermarkText'),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenAnswer((_) async => const WatermarkDownloadSuccess('/tmp/v.mp4'));

      await pumpSheet(tester, video: _createTestVideo());
      await tester.tap(find.text('Show Sheet'));
      await tester.pumpAndSettle();

      expect(
        find.text(l10n.watermarkDownloadSavedToCameraRoll),
        findsOneWidget,
      );
      expect(find.text(l10n.watermarkDownloadShare), findsOneWidget);
      expect(find.text(l10n.watermarkDownloadDone), findsOneWidget);
    });

    testWidgets('shows permission denied state', (tester) async {
      when(
        () => mockService.downloadWithWatermark(
          video: any(named: 'video'),
          watermarkText: any(named: 'watermarkText'),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenAnswer((_) async => const WatermarkDownloadPermissionDenied());

      await pumpSheet(tester, video: _createTestVideo());
      await tester.tap(find.text('Show Sheet'));
      await tester.pumpAndSettle();

      expect(
        find.text(l10n.watermarkDownloadPhotosAccessNeeded),
        findsOneWidget,
      );
      expect(find.text(l10n.watermarkDownloadOpenSettings), findsOneWidget);
      expect(find.text(l10n.watermarkDownloadNotNow), findsOneWidget);
    });

    testWidgets('shows failure state with reason', (tester) async {
      when(
        () => mockService.downloadWithWatermark(
          video: any(named: 'video'),
          watermarkText: any(named: 'watermarkText'),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenAnswer(
        (_) async => const WatermarkDownloadFailure('Network error'),
      );

      await pumpSheet(tester, video: _createTestVideo());
      await tester.tap(find.text('Show Sheet'));
      await tester.pumpAndSettle();

      expect(find.text(l10n.watermarkDownloadFailed), findsOneWidget);
      expect(find.text('Network error'), findsOneWidget);
      expect(find.text(l10n.watermarkDownloadDismiss), findsOneWidget);
    });

    testWidgets(
      'Open Settings retries download after app resumes from settings',
      (tester) async {
        when(
          () => mockPermissions.openAppSettings(),
        ).thenAnswer((_) async => true);

        var callCount = 0;
        when(
          () => mockService.downloadWithWatermark(
            video: any(named: 'video'),
            watermarkText: any(named: 'watermarkText'),
            onProgress: any(named: 'onProgress'),
          ),
        ).thenAnswer((invocation) async {
          callCount++;
          final onProgress =
              invocation.namedArguments[#onProgress]
                  as void Function(WatermarkDownloadStage);
          onProgress(WatermarkDownloadStage.downloading);
          if (callCount == 1) {
            return const WatermarkDownloadPermissionDenied();
          }
          onProgress(WatermarkDownloadStage.saving);
          return const WatermarkDownloadSuccess('/tmp/v.mp4');
        });

        await pumpSheet(tester, video: _createTestVideo());
        await tester.tap(find.text('Show Sheet'));
        await tester.pumpAndSettle();

        expect(
          find.text(l10n.watermarkDownloadPhotosAccessNeeded),
          findsOneWidget,
        );

        await tester.tap(find.text(l10n.watermarkDownloadOpenSettings));
        await tester.pump();

        // openAppSettings() returns when Settings opens, so the sheet should
        // wait for the app to resume before retrying.
        expect(callCount, equals(1));
        expect(
          find.text(l10n.watermarkDownloadPhotosAccessNeeded),
          findsOneWidget,
        );

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();

        expect(
          find.text(l10n.watermarkDownloadSavedToCameraRoll),
          findsOneWidget,
        );
        expect(
          find.text(l10n.watermarkDownloadPhotosAccessNeeded),
          findsNothing,
        );
        expect(callCount, equals(2));
      },
    );

    testWidgets(
      'Open Settings shows loading state while resumed retry is in progress',
      (tester) async {
        when(
          () => mockPermissions.openAppSettings(),
        ).thenAnswer((_) async => true);

        final retryCompleter = Completer<WatermarkDownloadResult>();
        var callCount = 0;

        when(
          () => mockService.downloadWithWatermark(
            video: any(named: 'video'),
            watermarkText: any(named: 'watermarkText'),
            onProgress: any(named: 'onProgress'),
          ),
        ).thenAnswer((invocation) async {
          callCount++;
          final onProgress =
              invocation.namedArguments[#onProgress]
                  as void Function(WatermarkDownloadStage);
          onProgress(WatermarkDownloadStage.downloading);
          if (callCount == 1) {
            return const WatermarkDownloadPermissionDenied();
          }
          return retryCompleter.future;
        });

        await pumpSheet(tester, video: _createTestVideo());
        await tester.tap(find.text('Show Sheet'));
        await tester.pumpAndSettle();

        expect(
          find.text(l10n.watermarkDownloadPhotosAccessNeeded),
          findsOneWidget,
        );

        await tester.tap(find.text(l10n.watermarkDownloadOpenSettings));
        await tester.pump();

        expect(callCount, equals(1));
        expect(
          find.text(l10n.watermarkDownloadPhotosAccessNeeded),
          findsOneWidget,
        );

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(callCount, equals(2));
      },
    );

    testWidgets('Dismiss button closes the sheet', (tester) async {
      when(
        () => mockService.downloadWithWatermark(
          video: any(named: 'video'),
          watermarkText: any(named: 'watermarkText'),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenAnswer(
        (_) async => const WatermarkDownloadFailure('Network error'),
      );

      await pumpSheet(tester, video: _createTestVideo());
      await tester.tap(find.text('Show Sheet'));
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.watermarkDownloadDismiss));
      await tester.pumpAndSettle();

      expect(find.text(l10n.watermarkDownloadFailed), findsNothing);
    });
  });
}
