// ABOUTME: Widget tests for TimelineEditingToolsBar.
// ABOUTME: Covers the Edit button's label at large text sizes.

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_timeline_editing_tools_bar.dart';

import '../../../../helpers/text_lines.dart';

void main() {
  group(TimelineEditingToolsBar, () {
    group('renders', () {
      // The button floats over the timeline's tracks, so a label wrapping
      // onto a second line covers one of them.
      testWidgets('keeps the German label on one line at the largest text '
          'size on a small phone', (tester) async {
        tester.view.physicalSize = const Size(375, 667);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('de'),
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(3.12)),
              child: child!,
            ),
            home: const Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: TimelineEditingToolsBar(),
              ),
            ),
          ),
        );

        final de = lookupAppLocalizations(const Locale('de'));
        expect(lineCountOf(tester, find.text(de.videoActionEdit)), 1);
      });
    });
  });
}
