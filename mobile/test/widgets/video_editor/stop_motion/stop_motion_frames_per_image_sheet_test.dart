import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_editor/stop_motion/stop_motion_frames_per_image_sheet.dart';

void main() {
  Future<void> pump(WidgetTester tester, {required int initialValue}) {
    return tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
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

    testWidgets('gives every row of the wheel room for its whole label at the '
        'largest text size', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = 3.12;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        MaterialApp(
          theme: VineTheme.theme,
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: DivineButton(
                  label: 'open',
                  onPressed: () => VineBottomSheet.show<int>(
                    context: context,
                    expanded: false,
                    scrollable: false,
                    isScrollControlled: true,
                    body: const StopMotionFramesPerImageSheet(
                      initialValue: 5,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final l10n = lookupAppLocalizations(const Locale('en'));

      expect(tester.takeException(), isNull);
      final selected = tester.renderObject<RenderParagraph>(
        find.text(l10n.videoEditorStopMotionFramesCount(5)),
      );
      expect(
        selected.size.height,
        greaterThanOrEqualTo(selected.textSize.height),
      );
    });
  });
}
