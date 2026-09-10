// ABOUTME: Tests for SaveOriginalProgressSheet widget
// ABOUTME: Validates UI states for downloading, success, failure, and permission denied

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
import 'package:openvine/widgets/save_original_progress_sheet.dart';
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
    registerFallbackValue(OriginalSaveStage.downloading);
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
                      showSaveOriginalSheet(
                        context: context,
                        ref: ref,
                        video: video,
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

  group('showSaveOriginalSheet', () {
    testWidgets('shows progress indicator while downloading', (tester) async {
      // Use a Completer that never completes (no timer involved)
      final neverComplete = Completer<WatermarkDownloadResult>();

      when(
        () => mockService.downloadOriginal(
          video: any(named: 'video'),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenAnswer((invocation) {
        // Simulate being stuck in downloading stage
        final onProgress =
            invocation.namedArguments[#onProgress]
                as void Function(OriginalSaveStage);
        onProgress(OriginalSaveStage.downloading);
        // Never return - stays in processing state (Completer avoids timer)
        return neverComplete.future;
      });

      await tester.pumpWidget(buildTestWidget(video: _createTestVideo()));

      // Open the sheet
      await tester.tap(find.text('Show Sheet'));
      await tester.pump();

      // Should show progress indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text(l10n.saveOriginalDownloadingVideo), findsOneWidget);
      // Prove the widget actually reads from l10n
      expect(find.text(l10nDe.saveOriginalDownloadingVideo), findsNothing);
    });

    testWidgets('shows success state with share button', (tester) async {
      when(
        () => mockService.downloadOriginal(
          video: any(named: 'video'),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenAnswer((invocation) async {
        final onProgress =
            invocation.namedArguments[#onProgress]
                as void Function(OriginalSaveStage);
        onProgress(OriginalSaveStage.downloading);
        onProgress(OriginalSaveStage.saving);
        return const WatermarkDownloadSuccess('/tmp/video.mp4');
      });

      await tester.pumpWidget(buildTestWidget(video: _createTestVideo()));

      await tester.tap(find.text('Show Sheet'));
      await tester.pumpAndSettle();

      // Should show success state
      expect(find.text(l10n.saveOriginalSavedToCameraRoll), findsOneWidget);
      expect(find.text(l10n.saveOriginalShare), findsOneWidget);
      expect(find.text(l10n.saveOriginalDone), findsOneWidget);
    });

    testWidgets('shows permission denied state', (tester) async {
      when(
        () => mockService.downloadOriginal(
          video: any(named: 'video'),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenAnswer((invocation) async {
        final onProgress =
            invocation.namedArguments[#onProgress]
                as void Function(OriginalSaveStage);
        onProgress(OriginalSaveStage.downloading);
        return const WatermarkDownloadPermissionDenied();
      });

      await tester.pumpWidget(buildTestWidget(video: _createTestVideo()));

      await tester.tap(find.text('Show Sheet'));
      await tester.pumpAndSettle();

      expect(find.text(l10n.saveOriginalPhotosAccessNeeded), findsOneWidget);
      expect(find.text(l10n.saveOriginalOpenSettings), findsOneWidget);
      expect(find.text(l10n.saveOriginalNotNow), findsOneWidget);
    });

    testWidgets('shows failure state with reason', (tester) async {
      when(
        () => mockService.downloadOriginal(
          video: any(named: 'video'),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenAnswer((_) async {
        return const WatermarkDownloadFailure('Network timeout');
      });

      await tester.pumpWidget(buildTestWidget(video: _createTestVideo()));

      await tester.tap(find.text('Show Sheet'));
      await tester.pumpAndSettle();

      expect(find.text(l10n.saveOriginalDownloadFailed), findsOneWidget);
      expect(find.text('Network timeout'), findsOneWidget);
      expect(find.text(l10n.saveOriginalDismiss), findsOneWidget);
    });

    testWidgets('dismiss button closes the sheet', (tester) async {
      when(
        () => mockService.downloadOriginal(
          video: any(named: 'video'),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenAnswer((_) async {
        return const WatermarkDownloadFailure('Error');
      });

      await tester.pumpWidget(buildTestWidget(video: _createTestVideo()));

      await tester.tap(find.text('Show Sheet'));
      await tester.pumpAndSettle();

      // Tap dismiss
      await tester.tap(find.text(l10n.saveOriginalDismiss));
      await tester.pumpAndSettle();

      // Sheet should be closed
      expect(find.text(l10n.saveOriginalDownloadFailed), findsNothing);
    });

    testWidgets(
      'Open Settings retries download after app resumes from settings',
      (tester) async {
        when(
          () => mockPermissions.openAppSettings(),
        ).thenAnswer((_) async => true);

        // First call: permission denied. Second call (retry): success.
        var callCount = 0;
        when(
          () => mockService.downloadOriginal(
            video: any(named: 'video'),
            onProgress: any(named: 'onProgress'),
          ),
        ).thenAnswer((invocation) async {
          callCount++;
          final onProgress =
              invocation.namedArguments[#onProgress]
                  as void Function(OriginalSaveStage);
          onProgress(OriginalSaveStage.downloading);
          if (callCount == 1) {
            return const WatermarkDownloadPermissionDenied();
          }
          onProgress(OriginalSaveStage.saving);
          return const WatermarkDownloadSuccess('/tmp/video.mp4');
        });

        await tester.pumpWidget(buildTestWidget(video: _createTestVideo()));
        await tester.tap(find.text('Show Sheet'));
        await tester.pumpAndSettle();

        // Permission denied UI is showing
        expect(
          find.text(l10n.saveOriginalPhotosAccessNeeded),
          findsOneWidget,
        );

        await tester.tap(find.text(l10n.saveOriginalOpenSettings));
        await tester.pump();

        // openAppSettings() returns when Settings opens, so the sheet should
        // wait for the app to resume before retrying.
        expect(callCount, equals(1));
        expect(
          find.text(l10n.saveOriginalPhotosAccessNeeded),
          findsOneWidget,
        );

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();

        // Should now show success (retry succeeded)
        expect(
          find.text(l10n.saveOriginalSavedToCameraRoll),
          findsOneWidget,
        );
        expect(find.text(l10n.saveOriginalPhotosAccessNeeded), findsNothing);
        expect(callCount, equals(2));
      },
    );

    testWidgets(
      'Open Settings shows loading indicator while resumed retry is in progress',
      (tester) async {
        when(
          () => mockPermissions.openAppSettings(),
        ).thenAnswer((_) async => true);

        final retryCompleter = Completer<WatermarkDownloadResult>();
        var callCount = 0;

        when(
          () => mockService.downloadOriginal(
            video: any(named: 'video'),
            onProgress: any(named: 'onProgress'),
          ),
        ).thenAnswer((invocation) async {
          callCount++;
          final onProgress =
              invocation.namedArguments[#onProgress]
                  as void Function(OriginalSaveStage);
          onProgress(OriginalSaveStage.downloading);
          if (callCount == 1) {
            return const WatermarkDownloadPermissionDenied();
          }
          return retryCompleter.future;
        });

        await tester.pumpWidget(buildTestWidget(video: _createTestVideo()));
        await tester.tap(find.text('Show Sheet'));
        await tester.pumpAndSettle();

        expect(
          find.text(l10n.saveOriginalPhotosAccessNeeded),
          findsOneWidget,
        );

        // Tap Open Settings
        await tester.tap(find.text(l10n.saveOriginalOpenSettings));
        await tester.pump();

        expect(callCount, equals(1));
        expect(
          find.text(l10n.saveOriginalPhotosAccessNeeded),
          findsOneWidget,
        );

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();

        // Sheet should be in loading/processing state during retry
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(callCount, equals(2));
      },
    );
  });
}
