// ABOUTME: Pins what the chroma-key controls show up front, what folds under
// ABOUTME: Fine-tune, and that the panel reads the active palette.

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/semantics.dart' show SemanticsAction;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_editor/chroma_key/chroma_key_editor_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
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
      ChromaKeySurface surface = ChromaKeySurface.track,
      // Off for a panel mid-measurement: Auto-detect spins for as long as
      // the measurement runs, so that frame never settles.
      bool settle = true,
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
          localizationsDelegates: appLocalizationsDelegates,
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
              body: ChromaKeyControls(
                onPickBackground: (_) {},
                surface: surface,
              ),
            ),
          ),
        ),
      );
      if (settle) {
        await tester.pumpAndSettle();
      } else {
        await tester.pump();
      }
    }

    /// Every colour the panel resolves for its own text.
    Set<Color?> textColors(WidgetTester tester) => tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.style?.color)
        .toSet();

    /// Restarts the cubit on [state] before the panel is pumped.
    void startOn(ChromaKeyEditorState state) => whenListen(
      cubit,
      const Stream<ChromaKeyEditorState>.empty(),
      initialState: state,
    );

    Future<void> openFineTune(WidgetTester tester, {bool settle = true}) async {
      final en = lookupAppLocalizations(const Locale('en'));
      final fineTune = find.text(en.videoEditorChromaKeyFineTune);
      // At large text sizes the row sits below the fold of a phone.
      await tester.ensureVisible(fineTune);
      await tester.pump();
      await tester.tap(fineTune);
      if (settle) {
        await tester.pumpAndSettle();
      } else {
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      }
    }

    testWidgets('keeps the wall tip back until a measurement fails', (
      tester,
    ) async {
      await pump(tester, VineTheme.theme);

      final en = lookupAppLocalizations(const Locale('en'));
      expect(find.text(en.videoEditorChromaKeySurfaceHint), findsNothing);
      expect(find.text(en.videoEditorChromaKeyDetectFailed), findsNothing);
    });

    testWidgets('says what the wall needs once no screen was found', (
      tester,
    ) async {
      startOn(
        const ChromaKeyEditorState(
          chromaKey: ClipChromaKey(key: ChromaKey.greenScreen()),
          detectionStatus: ChromaKeyDetectionStatus.failure,
        ),
      );
      await pump(tester, VineTheme.theme);

      final en = lookupAppLocalizations(const Locale('en'));
      expect(find.text(en.videoEditorChromaKeyDetectFailed), findsOneWidget);
      expect(
        find.text(en.videoEditorChromaKeySurfaceHint),
        findsOneWidget,
        reason:
            'What a background swap needs explains the failure the user just '
            'saw (#8547).',
      );
      expect(
        en.videoEditorChromaKeySurfaceHint.toLowerCase(),
        contains('white'),
        reason:
            'A white wall is the background most people own, and the mask '
            'keys one since pro_video_editor 2.19.0 (#8544).',
      );
    });

    testWidgets('reports a timeout without blaming the wall', (tester) async {
      startOn(
        const ChromaKeyEditorState(
          chromaKey: ClipChromaKey(key: ChromaKey.greenScreen()),
          detectionStatus: ChromaKeyDetectionStatus.timedOut,
        ),
      );
      await pump(tester, VineTheme.theme);

      final en = lookupAppLocalizations(const Locale('en'));
      expect(find.text(en.videoEditorChromaKeyDetectTimedOut), findsOneWidget);
      // The decode stalled; the wall was never looked at.
      expect(find.text(en.videoEditorChromaKeySurfaceHint), findsNothing);
    });

    testWidgets('offers every backdrop and names the empty one Black', (
      tester,
    ) async {
      await pump(tester, VineTheme.theme);

      final en = lookupAppLocalizations(const Locale('en'));
      expect(find.text(en.videoEditorChromaKeyBackgroundVideo), findsOneWidget);
      // A single H.264 track has nothing under it, so an empty backdrop is
      // black — and the chip says so instead of a warning under it.
      expect(find.text(en.videoEditorChromaKeyBackgroundBlack), findsOneWidget);
      expect(find.text(en.videoEditorChromaKeyBackgroundNone), findsNothing);
      expect(
        find.text(en.videoEditorChromaKeyCanvasTransparentHint),
        findsNothing,
      );
    });

    testWidgets('drops the clip backdrop and reassures on the canvas', (
      tester,
    ) async {
      await pump(tester, VineTheme.theme, surface: ChromaKeySurface.canvas);

      final en = lookupAppLocalizations(const Locale('en'));
      // A live key has no second track to play a library clip on.
      expect(find.text(en.videoEditorChromaKeyBackgroundVideo), findsNothing);
      // The layer is composited over the track, so an empty backdrop really
      // is see-through rather than black.
      expect(find.text(en.videoEditorChromaKeyBackgroundNone), findsOneWidget);
      expect(find.text(en.videoEditorChromaKeyBackgroundBlack), findsNothing);
      expect(find.text(en.videoEditorChromaKeyBackgroundColor), findsOneWidget);
      expect(find.text(en.videoEditorChromaKeyBackgroundImage), findsOneWidget);
      expect(
        find.text(en.videoEditorChromaKeyCanvasTransparentHint),
        findsOneWidget,
      );
    });

    testWidgets('resolves its copy through l10n rather than a literal', (
      tester,
    ) async {
      await pump(tester, VineTheme.theme, locale: const Locale('de'));

      // Asserting only that the German string is absent from an English
      // render is satisfied by a hardcoded English literal too. Rendering
      // German is the half that a literal cannot fake.
      final de = lookupAppLocalizations(const Locale('de'));
      final en = lookupAppLocalizations(const Locale('en'));
      expect(find.text(de.videoEditorChromaKeyFineTune), findsOneWidget);
      expect(find.text(en.videoEditorChromaKeyFineTune), findsNothing);
    });

    testWidgets('asks what replaces the color before how strongly', (
      tester,
    ) async {
      await pump(tester, VineTheme.theme);

      final en = lookupAppLocalizations(const Locale('en'));
      double top(String text) => tester.getTopLeft(find.text(text)).dy;
      // The backdrop is what most people open the mask for, so it leads;
      // the key's own tuning comes last. find.text alone passes in any order.
      expect(
        top(en.videoEditorChromaKeyBackgroundLabel),
        lessThan(top(en.videoEditorChromaKeyAmountLabel)),
      );
      expect(
        top(en.videoEditorChromaKeyAmountLabel),
        lessThan(top(en.videoEditorChromaKeyFineTune)),
      );
    });

    testWidgets('keeps the key settings folded until Fine-tune opens', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pump(tester, VineTheme.theme);

      final en = lookupAppLocalizations(const Locale('en'));
      final folded = [
        en.videoEditorChromaKeyAutoDetect,
        en.videoEditorChromaKeyPresetGreen,
        en.videoEditorChromaKeyScreenColorLabel,
        en.videoEditorChromaKeyEdgeLabel,
        en.videoEditorChromaKeySpillLabel,
      ];
      for (final label in folded) {
        expect(find.text(label), findsNothing, reason: label);
      }
      expect(
        tester.getSemantics(find.text(en.videoEditorChromaKeyFineTune)),
        isSemantics(isButton: true, hasExpandedState: true, isExpanded: false),
      );

      await openFineTune(tester);

      for (final label in folded) {
        expect(find.text(label), findsWidgets, reason: label);
      }
      expect(
        tester.getSemantics(find.text(en.videoEditorChromaKeyFineTune)),
        isSemantics(isButton: true, hasExpandedState: true, isExpanded: true),
      );
      // Edge and tint are not self-explanatory, so their hints are drawn.
      expect(find.text(en.videoEditorChromaKeyEdgeHint), findsOneWidget);
      expect(find.text(en.videoEditorChromaKeySpillHint), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('leaves everything but Auto-detect live while measuring', (
      tester,
    ) async {
      startOn(
        const ChromaKeyEditorState(
          chromaKey: ClipChromaKey(key: ChromaKey.greenScreen()),
          detectionStatus: ChromaKeyDetectionStatus.detecting,
        ),
      );
      await pump(tester, VineTheme.theme, settle: false);
      await openFineTune(tester, settle: false);

      final en = lookupAppLocalizations(const Locale('en'));
      final autoDetect = tester.widget<DivineButton>(
        find.widgetWithText(DivineButton, en.videoEditorChromaKeyAutoDetect),
      );
      expect(autoDetect.isLoading, isTrue);
      expect(autoDetect.onPressed, isNull);

      // The measurement on open is not something the user asked for, so the
      // presets cannot sit greyed out behind it: someone who shot on blue
      // taps "Blue" straight away, and the cubit writes the measurement off.
      await tester.tap(find.text(en.videoEditorChromaKeyPresetBlue));
      await tester.tap(find.text(en.videoEditorChromaKeyPresetGreen));
      verify(() => cubit.useBlueScreenPreset()).called(1);
      verify(() => cubit.useGreenScreenPreset()).called(1);

      // The swatch and the Amount slider were never gated. The dartdoc used to
      // claim they were, and gating them now would freeze the panel for the
      // whole of a measurement that has no timeout (#8905).
      final swatch = tester.getSemantics(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.button == true &&
              widget.properties.label ==
                  en.videoEditorChromaKeyScreenColorLabel,
        ),
      );
      expect(swatch.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      await tester.drag(find.byType(Slider).first, const Offset(80, 0));
      verify(() => cubit.setSimilarity(any())).called(greaterThan(0));
      verifyNever(() => cubit.detectFromFootage());
    });

    testWidgets('holds at the largest system text scale', (tester) async {
      startOn(
        const ChromaKeyEditorState(
          chromaKey: ClipChromaKey(key: ChromaKey.greenScreen()),
          detectionStatus: ChromaKeyDetectionStatus.failure,
        ),
      );
      await pump(
        tester,
        VineTheme.theme,
        textScaler: const TextScaler.linear(2),
      );
      await openFineTune(tester);

      expect(tester.takeException(), isNull);
      expect(
        find.text(
          lookupAppLocalizations(
            const Locale('en'),
          ).videoEditorChromaKeySpillHint,
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

    testWidgets('lifts the canvas hint off the muted register on dark', (
      tester,
    ) async {
      await pump(tester, VineTheme.theme, surface: ChromaKeySurface.canvas);

      // `onSurfaceMuted` is 50% white — 5.30:1 on the canvas this screen used
      // to paint — and the hint takes the same `onSurfaceVariant` as the
      // panel's other secondary text, 11.19:1 on the canvas it paints today.
      final hint = tester.widget<Text>(
        find.text(
          lookupAppLocalizations(
            const Locale('en'),
          ).videoEditorChromaKeyCanvasTransparentHint,
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
