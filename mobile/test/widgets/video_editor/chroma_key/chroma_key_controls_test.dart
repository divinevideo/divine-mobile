// ABOUTME: Pins the chroma-key controls to the active palette so the panel
// ABOUTME: stays readable once light mode reaches the video editor.

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/video_editor/chroma_key/chroma_key_editor_cubit.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/video_editor/clip_chroma_key.dart';
import 'package:openvine/widgets/video_editor/chroma_key/chroma_key_controls.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show ChromaKey;

class _MockChromaKeyEditorCubit extends MockCubit<ChromaKeyEditorState>
    implements ChromaKeyEditorCubit {}

void main() {
  group(ChromaKeyControls, () {
    late ChromaKeyEditorCubit cubit;

    setUp(() {
      cubit = _MockChromaKeyEditorCubit();
      whenListen(
        cubit,
        const Stream<ChromaKeyEditorState>.empty(),
        initialState: const ChromaKeyEditorState(
          chromaKey: ClipChromaKey(key: ChromaKey.greenScreen()),
        ),
      );
    });

    Future<void> pump(
      WidgetTester tester,
      ThemeData theme, {
      TextScaler textScaler = TextScaler.noScaling,
      Locale? locale,
    }) async {
      // A phone, not the 800x600 default. The panel is a narrow column of
      // rows, so a surface 2.2x a phone's width cannot show one overflowing
      // and the text-scale test below would pass on anything.
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          // copyWith, not a fresh MediaQueryData: the default constructor
          // zeroes size, padding and devicePixelRatio, so every test in this
          // file would measure a 0x0 unpadded screen. Sitting on `builder`
          // rather than `home` also carries the scale into pushed routes.
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: textScaler),
            child: child!,
          ),
          home: BlocProvider<ChromaKeyEditorCubit>.value(
            value: cubit,
            child: Scaffold(
              backgroundColor: theme
                  .extension<VineThemeColors>()!
                  .surfaceContainerHigh,
              body: ChromaKeyControls(onPickBackground: (_) {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    /// Every colour the panel resolves for its own text.
    Set<Color?> textColors(WidgetTester tester) => tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.style?.color)
        .toSet();

    testWidgets('states the surface requirement without being asked', (
      tester,
    ) async {
      await pump(tester, VineTheme.theme);

      final en = lookupAppLocalizations(const Locale('en'));
      expect(
        find.text(en.videoEditorChromaKeySurfaceHint),
        findsOneWidget,
        reason:
            'The prerequisite used to surface only as a failed detect, after '
            'the clip was already shot (#8547).',
      );
      expect(
        en.videoEditorChromaKeySurfaceHint.toLowerCase(),
        contains('wall'),
        reason:
            'Naming a wall is the point: most people own no green screen and '
            'do not know an ordinary wall keys. Epic #8543 ratified that '
            'framing.',
      );
      expect(
        find.text(
          lookupAppLocalizations(
            const Locale('de'),
          ).videoEditorChromaKeySurfaceHint,
        ),
        findsNothing,
        reason: 'Proves the widget resolves the string through l10n.',
      );
    });

    testWidgets('holds at the largest system text scale', (tester) async {
      await pump(
        tester,
        VineTheme.theme,
        textScaler: const TextScaler.linear(2),
      );

      expect(tester.takeException(), isNull);
      expect(
        find.text(
          lookupAppLocalizations(
            const Locale('en'),
          ).videoEditorChromaKeySurfaceHint,
        ),
        findsOneWidget,
      );
    });

    testWidgets('takes its text from the light palette, not fixed dark', (
      tester,
    ) async {
      await pump(tester, VineTheme.lightTheme);

      final colors = textColors(tester);
      expect(colors, contains(VineTheme.lightColors.onSurface));

      // The fixed dark constants are what made this panel unreadable on a
      // light canvas — `onSurface` is 95% white, which is 1.1:1 on it.
      expect(colors, isNot(contains(VineTheme.onSurface)));
      expect(colors, isNot(contains(VineTheme.onSurfaceVariant)));
      expect(colors, isNot(contains(VineTheme.onSurfaceMuted)));
    });

    testWidgets('keeps every label on its dark constant', (tester) async {
      await pump(tester, VineTheme.theme);

      // The dark palette aliases the same constants, so the labels and the
      // slider readouts resolve exactly what they resolved before.
      final colors = textColors(tester);
      expect(colors, contains(VineTheme.darkColors.onSurface));
      expect(colors, contains(VineTheme.darkColors.onSurfaceVariant));
    });

    testWidgets('lifts the transparent hint off the muted register on dark', (
      tester,
    ) async {
      await pump(tester, VineTheme.theme);

      // The one value this migration moves on dark. `onSurfaceMuted` is 50%
      // white — 5.30:1 on the canvas this screen used to paint — and the hint
      // now takes the same `onSurfaceVariant` as the panel's other secondary
      // text, 11.19:1 on the canvas it paints today.
      final hint = tester.widget<Text>(
        find.text(
          lookupAppLocalizations(
            const Locale('en'),
          ).videoEditorChromaKeyTransparentHint,
        ),
      );
      expect(hint.style?.color, VineTheme.darkColors.onSurfaceVariant);
      expect(hint.style?.color, isNot(VineTheme.onSurfaceMuted));
    });

    testWidgets('never uses onSurfaceMuted on the light canvas', (
      tester,
    ) async {
      await pump(tester, VineTheme.lightTheme);

      // `onSurfaceMuted` is only 3.05:1 against `surfaceContainerHigh`, under
      // the 4.5:1 this 12px hint needs.
      expect(
        textColors(tester),
        isNot(contains(VineTheme.lightColors.onSurfaceMuted)),
      );
    });
  });
}
