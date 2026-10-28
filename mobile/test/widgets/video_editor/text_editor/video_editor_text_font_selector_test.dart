// ABOUTME: Tests the inline font selector of the text editor: it shows the
// ABOUTME: picked font and hands a new pick to both the bloc and the editor.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_editor/text_editor/video_editor_text_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_editor/text_editor/video_editor_text_font_selector.dart';

class _MockVideoEditorTextBloc
    extends MockBloc<VideoEditorTextEvent, VideoEditorTextState>
    implements VideoEditorTextBloc {}

void main() {
  late bool allowRuntimeFetching;

  setUpAll(() {
    allowRuntimeFetching = GoogleFonts.config.allowRuntimeFetching;
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  tearDownAll(
    () => GoogleFonts.config.allowRuntimeFetching = allowRuntimeFetching,
  );

  int catalogueIndexOf(String familyName) => VideoEditorConstants
      .textFontCatalogue
      .indexWhere((entry) => entry.familyName == familyName);

  /// Runs [body], which may build or apply fonts in their own face.
  ///
  /// google_fonts cannot fetch the faces that are not bundled in a test, so
  /// those expected load failures are dropped; anything else fails the test.
  Future<void> ignoringFontLoads(
    WidgetTester tester,
    Future<void> Function() body,
  ) async {
    final unexpected = <Object>[];
    await runZonedGuarded(
      () async {
        try {
          await body();
        } on Object catch (error) {
          unexpected.add(error);
        }
      },
      (error, stackTrace) {
        if (!'$error'.contains('allowRuntimeFetching is false')) {
          unexpected.add(error);
        }
      },
    );
    await tester.runAsync(pumpEventQueue);
    expect(unexpected, isEmpty);
  }

  group(VideoEditorTextFontSelector, () {
    late _MockVideoEditorTextBloc bloc;

    setUp(() {
      bloc = _MockVideoEditorTextBloc();
    });

    Future<void> pumpSelector(
      WidgetTester tester, {
      int selectedFontIndex = 0,
      ValueChanged<TextStyle>? onFontSelected,
    }) async {
      when(
        () => bloc.state,
      ).thenReturn(VideoEditorTextState(selectedFontIndex: selectedFontIndex));
      tester.view
        ..physicalSize = const Size(1080, 2400)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await ignoringFontLoads(
        tester,
        () => tester.pumpWidget(
          MaterialApp(
            theme: VineTheme.theme,
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: BlocProvider<VideoEditorTextBloc>.value(
                value: bloc,
                child: VideoEditorTextFontSelector(
                  onFontSelected: onFontSelected,
                ),
              ),
            ),
          ),
        ),
      );
    }

    group('renders', () {
      testWidgets('marks the font the text editor has picked', (tester) async {
        await pumpSelector(
          tester,
          selectedFontIndex: catalogueIndexOf('Roboto'),
        );

        final robotoRow = find.ancestor(
          of: find.text('Roboto'),
          matching: find.byType(Row),
        );
        expect(
          find.descendant(of: robotoRow, matching: find.byType(DivineIcon)),
          findsOneWidget,
        );
        expect(find.byType(DivineIcon), findsOneWidget);
      });
    });

    group('interactions', () {
      testWidgets(
        'a pick selects the font in the bloc and hands its style to the editor',
        (tester) async {
          // The editor opens on the first font, so the pick has to differ
          // from the font the bloc already holds.
          final robotoIndex = catalogueIndexOf('Roboto');
          TextStyle? applied;
          await pumpSelector(
            tester,
            onFontSelected: (style) => applied = style,
          );

          late TextStyle expected;
          await ignoringFontLoads(tester, () async {
            expected = VideoEditorConstants.textFonts[robotoIndex]();
            await tester.tap(find.text('Roboto'));
          });

          verify(
            () => bloc.add(VideoEditorTextFontSelected(robotoIndex)),
          ).called(1);
          expect(applied?.fontFamily, expected.fontFamily);
        },
      );
    });
  });
}
