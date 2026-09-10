import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/video_editor/stop_motion/stop_motion_frames_per_image_sheet.dart';

void main() {
  Future<void> pump(WidgetTester tester, {required int initialValue}) {
    return tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: StopMotionFramesPerImageSheet(initialValue: initialValue),
        ),
      ),
    );
  }

  group(StopMotionFramesPerImageSheet, () {
    testWidgets('renders the title and the value it opens on', (tester) async {
      await pump(tester, initialValue: 5);
      final l10n = lookupAppLocalizations(const Locale('en'));

      expect(
        find.text(l10n.videoEditorStopMotionFramesPerImageLabel),
        findsOneWidget,
      );
      // The wheel opens centered on the initial value.
      expect(find.text(l10n.videoEditorStopMotionFramesCount(5)), findsWidgets);
    });

    testWidgets('uses the singular form for a hold of one frame', (
      tester,
    ) async {
      await pump(tester, initialValue: 1);
      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(l10n.videoEditorStopMotionFramesCount(1), '1 frame');
      expect(find.text('1 frame'), findsWidgets);
    });
  });
}
