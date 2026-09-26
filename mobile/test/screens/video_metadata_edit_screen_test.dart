import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/observability/crash_reporter.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:openvine/providers/video_providers.dart';
import 'package:openvine/screens/video_metadata/video_metadata_edit_screen.dart';
import 'package:openvine/services/video_event_resolver.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:unified_logger/unified_logger.dart';

class _MockVideoEventResolver extends Mock implements VideoEventResolver {}

void main() {
  group(VideoMetadataEditScreen, () {
    testWidgets(
      'raw-tagless prefetch resolves a complete event before editing',
      (
        tester,
      ) async {
        final resolver = _MockVideoEventResolver();
        final pending = Completer<VideoEvent?>();
        when(
          () => resolver.resolveById(
            'event-id',
            allowOwnContentBypass: true,
            requireRawTags: true,
          ),
        ).thenAnswer((_) => pending.future);

        final incomplete = VideoEvent(
          id: 'event-id',
          pubkey: 'author-pubkey',
          createdAt: 1700000000,
          content: 'Description',
          timestamp: DateTime.fromMillisecondsSinceEpoch(
            1700000000 * 1000,
            isUtc: true,
          ),
          videoUrl: 'https://example.com/video.mp4',
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              videoEventResolverProvider.overrideWithValue(resolver),
            ],
            child: MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: VideoMetadataEditScreen(
                videoId: incomplete.id,
                prefetched: incomplete,
              ),
            ),
          ),
        );

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        verify(
          () => resolver.resolveById(
            'event-id',
            allowOwnContentBypass: true,
            requireRawTags: true,
          ),
        ).called(1);

        pending.complete();
        await tester.pump();
      },
    );

    testWidgets('shows the invalid-video route when the lookup throws', (
      tester,
    ) async {
      final resolver = _MockVideoEventResolver();
      when(
        () => resolver.resolveById(
          'event-id',
          allowOwnContentBypass: true,
          requireRawTags: true,
        ),
      ).thenThrow(StateError('resolver invariant'));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [videoEventResolverProvider.overrideWithValue(resolver)],
          child: const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: VideoMetadataEditScreen(videoId: 'event-id'),
          ),
        ),
      );
      await tester.pump();

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.routeInvalidVideoId), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('logs a failed lookup with the full video id', (tester) async {
      const videoId =
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
      final logCapture = LogCaptureService();
      await logCapture.clearAllLogs();
      addTearDown(logCapture.clearAllLogs);
      final resolver = _MockVideoEventResolver();
      when(
        () => resolver.resolveById(
          videoId,
          allowOwnContentBypass: true,
          requireRawTags: true,
        ),
      ).thenThrow(StateError('resolver invariant'));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [videoEventResolverProvider.overrideWithValue(resolver)],
          child: const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: VideoMetadataEditScreen(videoId: videoId),
          ),
        ),
      );
      await tester.pump();

      final errorLogs = logCapture.getRecentLogs(minLevel: LogLevel.error);
      expect(errorLogs.map((log) => log.message), contains(contains(videoId)));
    });

    group('crash reporting', () {
      late CrashReporter originalReporter;
      late _RecordingCrashReporter reporter;

      setUp(() {
        originalReporter = detachedFailureReporter;
        reporter = _RecordingCrashReporter();
        detachedFailureReporter = reporter;
      });

      tearDown(() {
        detachedFailureReporter = originalReporter;
      });

      testWidgets('reports a programming error thrown by the lookup', (
        tester,
      ) async {
        final resolver = _MockVideoEventResolver();
        when(
          () => resolver.resolveById(
            'event-id',
            allowOwnContentBypass: true,
            requireRawTags: true,
          ),
        ).thenThrow(StateError('resolver invariant'));

        await tester.pumpWidget(
          ProviderScope(
            overrides: [videoEventResolverProvider.overrideWithValue(resolver)],
            child: const MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: VideoMetadataEditScreen(videoId: 'event-id'),
            ),
          ),
        );
        await tester.pump();

        expect(reporter.recordedErrors, hasLength(1));
        expect(
          reporter.recordedErrors.single,
          isA<Reportable<Object>>().having(
            (r) => r.unwrap(),
            'unwrap',
            isA<StateError>(),
          ),
        );
      });
    });
  });
}

class _RecordingCrashReporter implements CrashReporter {
  final recordedErrors = <Object>[];

  @override
  Future<void> setCustomKey(String key, Object value) async {}

  @override
  void log(String message) {}

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    String? reason,
  }) async {
    recordedErrors.add(error);
  }
}
