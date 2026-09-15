// ABOUTME: Tests for the custom caption-style sheet: color swatch semantics
// ABOUTME: and the "Save style" action that keeps the look for later videos.

import 'dart:ui' show SemanticsAction, Tristate;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/caption_style.dart';
import 'package:openvine/models/video_editor/saved_caption_style.dart';
import 'package:openvine/providers/saved_caption_style_repository_provider.dart';
import 'package:openvine/repositories/saved_caption_style_repository.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_caption_custom_style_sheet.dart';
import 'package:pro_image_editor/pro_image_editor.dart'
    show LayerBackgroundMode;

class _MockSavedCaptionStyleRepository extends Mock
    implements SavedCaptionStyleRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    registerFallbackValue(CaptionCustomStyle.initial());
  });

  const customColor = Color.fromARGB(255, 100, 20, 20);
  final initial = CaptionCustomStyle.initial().copyWith(
    color: customColor,
    colorMode: LayerBackgroundMode.onlyColor,
  );

  late _MockSavedCaptionStyleRepository repository;

  setUp(() {
    repository = _MockSavedCaptionStyleRepository();
    when(repository.getStyles).thenAnswer((_) async => []);
  });

  Future<void> pumpSheet(
    WidgetTester tester, {
    Locale? locale,
    bool disableAnimations = false,
  }) async {
    tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          savedCaptionStyleRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: disableAnimations),
            child: child!,
          ),
          locale: locale,
          theme: VineTheme.theme,
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () =>
                    showCaptionCustomStyleSheet(context, initial: initial),
                child: const Text('Open style sheet'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open style sheet'));
    await tester.pump(const Duration(milliseconds: 300));
  }

  String expectedLabel(AppLocalizations l10n) =>
      l10n.videoEditorColorPickerSwatchSemanticLabel(
        l10n.videoEditorColorPickerSemanticLabel,
        l10n.rgbColorSemanticLabel(100, 20, 20),
      );

  group('custom color swatch semantics', () {
    testWidgets('stops preview loops when animations are disabled', (
      tester,
    ) async {
      await pumpSheet(tester, disableAnimations: true);

      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('keeps the caption preview visible with reduced motion', (
      tester,
    ) async {
      await pumpSheet(tester, disableAnimations: true);

      final visiblePreview = find.byWidgetPredicate(
        (widget) => widget is Opacity && widget.opacity == 1,
      );
      expect(visiblePreview, findsWidgets);
      await tester.pumpAndSettle();
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('custom color swatch exposes RGB semantics', (tester) async {
      await pumpSheet(tester);

      final l10n = lookupAppLocalizations(const Locale('en'));
      final semantics = tester.getSemantics(
        find.bySemanticsLabel(expectedLabel(l10n)),
      );
      final data = semantics.getSemanticsData();

      expect(data.flagsCollection.isButton, isTrue);
      expect(data.flagsCollection.isSelected, Tristate.isTrue);
      expect(data.hasAction(SemanticsAction.tap), isTrue);
    });

    testWidgets('custom color swatch joins its label the way the locale lists', (
      tester,
    ) async {
      // Japanese lists with '、', so a swatch label rebuilt by hand with a Latin
      // ', ' would still read correctly in English and wrong here. Pinning ja is
      // what stops the join from drifting back into Dart.
      await pumpSheet(tester, locale: const Locale('ja'));

      final ja = lookupAppLocalizations(const Locale('ja'));
      expect(expectedLabel(ja), contains('、'));
      expect(find.bySemanticsLabel(expectedLabel(ja)), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          expectedLabel(lookupAppLocalizations(const Locale('en'))),
        ),
        findsNothing,
      );
    });
  });

  group('save style', () {
    final l10n = lookupAppLocalizations(const Locale('en'));

    Finder saveButton() => find.descendant(
      of: find.byType(DivineButton),
      matching: find.text(l10n.videoEditorCaptionsSavedStyleSaveTitle),
    );

    testWidgets('sits under the animation section', (tester) async {
      await pumpSheet(tester, disableAnimations: true);
      await tester.pumpAndSettle();

      expect(saveButton(), findsOneWidget);
      expect(
        tester.getTopLeft(saveButton()).dy,
        greaterThan(
          tester
              .getBottomLeft(find.text(l10n.videoEditorCaptionsCustomAnimation))
              .dy,
        ),
      );
    });

    testWidgets('saves the edited look under the confirmed name', (
      tester,
    ) async {
      when(
        () => repository.save(
          rawName: any(named: 'rawName'),
          style: any(named: 'style'),
        ),
      ).thenAnswer(
        (invocation) async => SavedCaptionStyle(
          id: 'new',
          name: invocation.namedArguments[#rawName] as String,
          style: invocation.namedArguments[#style] as CaptionCustomStyle,
          createdAt: DateTime(2026, 9, 15),
        ),
      );
      await pumpSheet(tester, disableAnimations: true);
      await tester.pumpAndSettle();

      // Change the animation first, so the save carries the edited look
      // rather than the one the sheet opened with.
      await tester.tap(find.text(l10n.videoEditorCaptionsAnimationPop));
      await tester.pumpAndSettle();

      await tester.ensureVisible(saveButton());
      await tester.tap(saveButton());
      await tester.pumpAndSettle();

      // The prompt suggests the font's name so a single tap saves.
      final field = tester.widget<DivineTextField>(
        find.byKey(const Key('saved_caption_style_name_field')),
      );
      expect(field.controller?.text, equals('Inter'));

      await tester.tap(
        find.descendant(
          of: find.byType(DivineButton),
          matching: find.text(l10n.videoEditorCaptionsSavedStyleSaveAction),
        ),
      );
      await tester.pumpAndSettle();

      verify(
        () => repository.save(
          rawName: 'Inter',
          style: initial.copyWith(animation: CaptionAnimationStyle.pop),
        ),
      ).called(1);
      // The editor stays open with the confirmation under the button.
      expect(
        find.text(l10n.videoEditorCaptionsSavedStyleSaved('Inter')),
        findsOneWidget,
      );
      expect(saveButton(), findsOneWidget);
    });

    testWidgets('an edit after saving clears the confirmation', (
      tester,
    ) async {
      when(
        () => repository.save(
          rawName: any(named: 'rawName'),
          style: any(named: 'style'),
        ),
      ).thenAnswer(
        (_) async => SavedCaptionStyle(
          id: 'new',
          name: 'Inter',
          style: initial,
          createdAt: DateTime(2026, 9, 15),
        ),
      );
      await pumpSheet(tester, disableAnimations: true);
      await tester.pumpAndSettle();
      await tester.ensureVisible(saveButton());
      await tester.tap(saveButton());
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(DivineButton),
          matching: find.text(l10n.videoEditorCaptionsSavedStyleSaveAction),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(l10n.videoEditorCaptionsSavedStyleSaved('Inter')),
        findsOneWidget,
      );

      await tester.tap(find.text(l10n.videoEditorCaptionsAnimationSpring));
      await tester.pumpAndSettle();

      expect(
        find.text(l10n.videoEditorCaptionsSavedStyleSaved('Inter')),
        findsNothing,
      );
    });

    testWidgets('reports a failed save under the button', (tester) async {
      when(
        () => repository.save(
          rawName: any(named: 'rawName'),
          style: any(named: 'style'),
        ),
      ).thenThrow(StateError('disk full'));
      await pumpSheet(tester, disableAnimations: true);
      await tester.pumpAndSettle();
      await tester.ensureVisible(saveButton());
      await tester.tap(saveButton());
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(DivineButton),
          matching: find.text(l10n.videoEditorCaptionsSavedStyleSaveAction),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(l10n.videoEditorCaptionsSavedStyleSaveFailed),
        findsOneWidget,
      );
    });

    testWidgets('dismissing the prompt saves nothing', (tester) async {
      await pumpSheet(tester, disableAnimations: true);
      await tester.pumpAndSettle();
      await tester.ensureVisible(saveButton());
      await tester.tap(saveButton());
      await tester.pumpAndSettle();

      // Tap outside the prompt to dismiss it.
      await tester.tapAt(const Offset(540, 40));
      await tester.pumpAndSettle();

      verifyNever(
        () => repository.save(
          rawName: any(named: 'rawName'),
          style: any(named: 'style'),
        ),
      );
      expect(saveButton(), findsOneWidget);
    });
  });
}
