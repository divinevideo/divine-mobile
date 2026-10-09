// ABOUTME: Widget tests for the reply parent link shown on a reply video.
// ABOUTME: Covers opening the parent route and logging a rejected push.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/observability/crash_reporter.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:openvine/providers/video_reply_parent_provider.dart';
import 'package:openvine/screens/video_detail_screen.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/widgets/video_reply_parent_link.dart';
import 'package:unified_logger/unified_logger.dart';

import '../helpers/go_router.dart';

void main() {
  const parentId =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  final fallbackLabel = lookupAppLocalizations(const Locale('en'))
      .commentsReplyParentFallbackLabel;
  final reply = VideoEvent(
    id: 'reply-video',
    pubkey: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
    createdAt: 1,
    content: 'Reply',
    timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
    videoUrl: 'https://example.com/reply.mp4',
    nostrEventTags: const [
      ['E', parentId],
      ['K', '34236'],
    ],
  );

  group(VideoReplyParentLink, () {
    group('navigation', () {
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

      testWidgets('tapping the reply parent opens its video route', (
        tester,
      ) async {
        final router = GoRouter(
          initialLocation: '/',
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => Scaffold(
                body: VideoReplyParentLink(
                  video: reply,
                  variant: VideoReplyParentLinkVariant.metadata,
                ),
              ),
            ),
            GoRoute(
              path: VideoDetailScreen.path,
              builder: (_, state) =>
                  Scaffold(body: Text('Opened ${state.pathParameters['id']}')),
            ),
          ],
        );
        addTearDown(router.dispose);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              videoReplyParentProvider.overrideWith(
                (ref, routeId) async => null,
              ),
            ],
            child: MaterialApp.router(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text(fallbackLabel));
        await tester.pumpAndSettle();

        expect(find.text('Opened $parentId'), findsOneWidget);
      });

      testWidgets('logs a rejected parent route push instead of leaking it', (
        tester,
      ) async {
        final logCapture = LogCaptureService();
        await logCapture.clearAllLogs();
        addTearDown(logCapture.clearAllLogs);
        final router = MockGoRouter();
        when(
          () => router.push<void>(any()),
        ).thenAnswer((_) => Future<void>.error(StateError('route failed')));

        await tester.pumpWidget(
          MockGoRouterProvider(
            goRouter: router,
            child: ProviderScope(
              overrides: [
                videoReplyParentProvider.overrideWith(
                  (ref, routeId) async => null,
                ),
              ],
              child: MaterialApp(
                localizationsDelegates: appLocalizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(
                  body: VideoReplyParentLink(
                    video: reply,
                    variant: VideoReplyParentLinkVariant.metadata,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text(fallbackLabel));
        await tester.pump();

        verify(() => router.push<void>(VideoDetailScreen.pathForId(parentId)))
            .called(1);
        expect(tester.takeException(), isNull);
        final failures = logCapture
            .getRecentLogs()
            .where((entry) => entry.name == 'VideoReplyParentLink')
            .toList();
        expect(failures, hasLength(1));
        expect(failures.single.level, equals(LogLevel.error));
        expect(failures.single.category, equals(LogCategory.video));
        expect(
          failures.single.message,
          equals('Failed to open reply parent video: Bad state: route failed'),
        );
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
  void log(String message) {}

  @override
  Future<void> setCustomKey(String key, Object value) async {}

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stackTrace, {
    String? reason,
  }) async {
    recordedErrors.add(error);
  }
}
