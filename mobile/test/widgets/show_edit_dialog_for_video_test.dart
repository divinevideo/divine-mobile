// ABOUTME: Tests for the showEditDialogForVideo navigation helper.
// ABOUTME: Drives it through EditActionButton, the owner's tap on a video.

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/video_metadata/video_metadata_edit_screen.dart';
import 'package:openvine/widgets/video_feed_item/actions/edit_action_button.dart';
import 'package:unified_logger/unified_logger.dart';

import '../helpers/go_router.dart';

void main() {
  group('showEditDialogForVideo', () {
    late MockGoRouter goRouter;
    late LogCaptureService logCapture;
    late VideoEvent video;

    setUp(() async {
      goRouter = MockGoRouter();
      when(() => goRouter.push<void>(any(), extra: any(named: 'extra')))
          .thenAnswer((_) async {});
      logCapture = LogCaptureService();
      await logCapture.clearAllLogs();
      video = VideoEvent(
        id: 'a' * 64,
        pubkey: 'b' * 64,
        createdAt: 1757385263,
        content: 'Test video',
        timestamp: DateTime.fromMillisecondsSinceEpoch(1757385263 * 1000),
      );
    });

    tearDown(() async {
      await logCapture.clearAllLogs();
    });

    Future<void> tapEdit(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MockGoRouterProvider(
            goRouter: goRouter,
            child: Scaffold(body: EditActionButton(video: video)),
          ),
        ),
      );
      await tester.tap(find.byType(EditActionButton));
      await tester.pump();
    }

    testWidgets('pushes the metadata editor carrying the tapped video', (
      tester,
    ) async {
      await tapEdit(tester);

      final pushed = verify(
        () => goRouter.push<void>(
          captureAny(),
          extra: captureAny(named: 'extra'),
        ),
      ).captured;
      expect(pushed, [VideoMetadataEditScreen.pathFor(video.id), video]);
    });

    testWidgets('logs a failed push instead of leaking it', (tester) async {
      when(() => goRouter.push<void>(any(), extra: any(named: 'extra')))
          .thenAnswer((_) => Future<void>.error(Exception('route failed')));

      await tapEdit(tester);

      expect(tester.takeException(), isNull);
      final errors = logCapture
          .getRecentLogs()
          .where((log) => log.level == LogLevel.error)
          .toList();
      expect(errors, hasLength(1));
      expect(errors.single.name, 'showEditDialogForVideo');
      expect(errors.single.category, LogCategory.ui);
      expect(
        errors.single.message,
        'Failed to open video metadata editor for video ${video.id}: '
        'Exception: route failed',
      );
    });
  });
}
