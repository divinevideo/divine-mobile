// ABOUTME: Tests the box shown while a poll is moved: where it stands on the
// ABOUTME: canvas, the line saying why, and that it stays out of the way.

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/poll_sticker_placement.dart';
import 'package:openvine/widgets/video_editor/main_editor/poll_safe_area_guide.dart';

void main() {
  group(PollSafeAreaGuide, () {
    Future<void> pump(WidgetTester tester, {required bool isVisible}) =>
        tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Center(
              child: SizedBox(
                width: 300,
                height: 600,
                child: PollSafeAreaGuide(
                  isVisible: isVisible,
                  targetAspectRatio: 9 / 16,
                  fittedBoxScale: 1,
                ),
              ),
            ),
          ),
        );

    double opacity(WidgetTester tester) =>
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity;

    group('renders', () {
      testWidgets('outlines the safe area and says why while a poll moves', (
        tester,
      ) async {
        await pump(tester, isVisible: true);

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.text(l10n.videoEditorPollAreaHint), findsOneWidget);
        expect(opacity(tester), equals(1));
        final box = pollSafeRect(
          bodySize: const Size(300, 600),
          targetAspectRatio: 9 / 16,
        );
        final outline = tester.getRect(
          find.byWidgetPredicate(
            (w) =>
                w is DecoratedBox &&
                (w.decoration as BoxDecoration).border != null,
          ),
        );
        final shown = outline.shift(
          -tester.getTopLeft(find.byType(PollSafeAreaGuide)),
        );
        expect(shown.left, closeTo(box.left, 0.01));
        expect(shown.top, closeTo(box.top, 0.01));
        expect(shown.right, closeTo(box.right, 0.01));
        expect(shown.bottom, closeTo(box.bottom, 0.01));
      });

      testWidgets('is hidden while no poll moves', (tester) async {
        await pump(tester, isVisible: false);

        expect(opacity(tester), equals(0));
      });
    });

    group('interactions', () {
      testWidgets('lets touches through to the canvas', (tester) async {
        await pump(tester, isVisible: true);

        expect(
          find.descendant(
            of: find.byType(PollSafeAreaGuide),
            matching: find.byType(IgnorePointer),
          ),
          findsWidgets,
        );
        expect(
          tester
              .widget<IgnorePointer>(
                find
                    .descendant(
                      of: find.byType(PollSafeAreaGuide),
                      matching: find.byType(IgnorePointer),
                    )
                    .first,
              )
              .ignoring,
          isTrue,
        );
      });
    });
  });
}
