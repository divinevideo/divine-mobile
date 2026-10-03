// ABOUTME: Tests for VideoTextEditorScreen.
// ABOUTME: Validates screen rendering, BLoC interactions, and panel behavior.
// ABOUTME: Note: Some async GoogleFonts errors may appear but tests pass.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_editor/text_editor/video_editor_text_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/text_effects.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/screens/video_editor/video_text_editor_screen.dart';
import 'package:openvine/widgets/video_editor/text_editor/video_editor_text_effects_panel.dart';
import 'package:openvine/widgets/video_editor/text_editor/video_editor_text_font_selector.dart';
import 'package:openvine/widgets/video_editor/text_editor/video_editor_text_overlay_controls.dart';
import 'package:openvine/widgets/video_editor/text_effects_controls.dart';
import 'package:openvine/widgets/video_editor/video_editor_color_picker_sheet.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockVideoEditorTextBloc
    extends MockBloc<VideoEditorTextEvent, VideoEditorTextState>
    implements VideoEditorTextBloc {}

class MockGoRouter extends Mock implements GoRouter {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Store original error handler
  void Function(FlutterErrorDetails)? originalOnError;

  setUpAll(() {
    // Disable GoogleFonts network fetching in tests
    GoogleFonts.config.allowRuntimeFetching = false;

    // Store original handler to restore later
    originalOnError = FlutterError.onError;

    // Ignore GoogleFonts errors that occur asynchronously after test completion
    // These happen because the font selector widget triggers async font loading
    FlutterError.onError = (details) {
      final message = details.exception.toString();
      if (message.contains('GoogleFonts') || message.contains('font')) {
        // Ignore GoogleFonts-related errors in tests
        return;
      }
      // Forward other errors to the original handler
      originalOnError?.call(details);
    };

    registerFallbackValue(
      const VideoEditorTextInitFromLayer(
        text: '',
        alignment: TextAlign.center,
        color: Colors.white,
        backgroundStyle: LayerBackgroundMode.backgroundAndColor,
        selectedFontIndex: 0,
      ),
    );
    registerFallbackValue(const VideoEditorTextColorSelected(Colors.white));
    registerFallbackValue(
      const VideoEditorTextBackgroundStyleChanged(
        LayerBackgroundMode.backgroundAndColor,
      ),
    );
    registerFallbackValue(
      const VideoEditorTextAlignmentChanged(TextAlign.center),
    );
  });

  tearDownAll(() {
    // Restore original error handler
    if (originalOnError != null) {
      FlutterError.onError = originalOnError;
    }
  });

  group('VideoTextEditorScreen', () {
    late MockVideoEditorTextBloc mockBloc;
    late MockGoRouter mockGoRouter;
    late SharedPreferences sharedPreferences;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      sharedPreferences = await SharedPreferences.getInstance();
      mockBloc = MockVideoEditorTextBloc();
      mockGoRouter = MockGoRouter();

      when(() => mockBloc.state).thenReturn(const VideoEditorTextState());
      when(() => mockBloc.stream).thenAnswer((_) => const Stream.empty());
      when(() => mockGoRouter.canPop()).thenReturn(true);
      when(() => mockGoRouter.pop<void>()).thenAnswer((_) async {});
    });

    Widget buildWidget({TextLayer? layer, VideoEditorTextState? state}) {
      if (state != null) {
        when(() => mockBloc.state).thenReturn(state);
      }

      return ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        ],
        child: MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: InheritedGoRouter(
            goRouter: mockGoRouter,
            child: BlocProvider<VideoEditorTextBloc>.value(
              value: mockBloc,
              child: Scaffold(body: VideoTextEditorScreen(layer: layer)),
            ),
          ),
        ),
      );
    }

    group('Rendering', () {
      testWidgets('renders without layer', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pump();

        expect(find.byType(VideoTextEditorScreen), findsOneWidget);
      });

      testWidgets('disables autocorrect for overlay text input', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget());
        await tester.pump();

        final textField = tester.widget<TextField>(find.byType(TextField));

        expect(textField.autocorrect, isFalse);
      });

      testWidgets('renders TextEditor widget', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pump();

        expect(find.byType(TextEditor), findsOneWidget);
      });

      testWidgets('renders VideoEditorTextOverlayControls', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pump();

        expect(find.byType(VideoEditorTextOverlayControls), findsOneWidget);
      });
    });

    group('Layer initialization', () {
      testWidgets('does not dispatch InitFromLayer when layer is null', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget());
        await tester.pump();

        verifyNever(
          () => mockBloc.add(any(that: isA<VideoEditorTextInitFromLayer>())),
        );
      });

      testWidgets(
        'dispatches InitFromLayer when layer is provided',
        (tester) async {
          final layer = TextLayer(
            text: 'Test Text',
            color: Colors.red,
            background: Colors.blue,
            colorMode: LayerBackgroundMode.onlyColor,
            fontScale: 1.5,
            textStyle: const TextStyle(fontFamily: 'Test'),
          );

          await tester.pumpWidget(buildWidget(layer: layer));
          await tester.pump();

          verify(
            () => mockBloc.add(any(that: isA<VideoEditorTextInitFromLayer>())),
          ).called(1);
        },
      );

      testWidgets('selects the catalogue index of a serialized layer font', (
        tester,
      ) async {
        final layer = TextLayer(
          text: 'Test Text',
          color: Colors.red,
          background: Colors.blue,
          colorMode: LayerBackgroundMode.onlyColor,
          fontScale: 1.5,
          textStyle: const TextStyle(fontFamily: 'BebasNeue_regular'),
        );

        await tester.pumpWidget(buildWidget(layer: layer));
        await tester.pump();

        final captured = verify(
          () => mockBloc.add(
            captureAny(that: isA<VideoEditorTextInitFromLayer>()),
          ),
        ).captured;

        final event = captured.first as VideoEditorTextInitFromLayer;
        expect(
          event.selectedFontIndex,
          VideoEditorConstants.textFonts.indexOf(GoogleFonts.bebasNeue),
        );
      });

      testWidgets(
        'uses color from layer when colorMode is onlyColor',
        (tester) async {
          final layer = TextLayer(
            text: 'Test',
            color: Colors.red,
            background: Colors.blue,
            colorMode: LayerBackgroundMode.onlyColor,
            align: TextAlign.center,
            textStyle: const TextStyle(),
          );

          await tester.pumpWidget(buildWidget(layer: layer));
          await tester.pump();

          final captured = verify(
            () => mockBloc.add(
              captureAny(that: isA<VideoEditorTextInitFromLayer>()),
            ),
          ).captured;

          expect(captured, isNotEmpty);
          final event = captured.first as VideoEditorTextInitFromLayer;
          expect(event.color, Colors.red);
        },
      );

      testWidgets(
        'uses background from layer when colorMode is background',
        (tester) async {
          final layer = TextLayer(
            text: 'Test',
            color: Colors.red,
            background: Colors.blue,
            colorMode: LayerBackgroundMode.background,
            align: TextAlign.center,
            textStyle: const TextStyle(),
          );

          await tester.pumpWidget(buildWidget(layer: layer));
          await tester.pump();

          final captured = verify(
            () => mockBloc.add(
              captureAny(that: isA<VideoEditorTextInitFromLayer>()),
            ),
          ).captured;

          expect(captured, isNotEmpty);
          final event = captured.first as VideoEditorTextInitFromLayer;
          expect(event.color, Colors.blue);
        },
      );
    });

    group('Outline and shadow', () {
      const effects = TextEffects(
        outlineThickness: 0.5,
        outlineColor: Color(0xFFFF7FAF),
        shadowStrength: 0.5,
      );
      final l10n = lookupAppLocalizations(const Locale('en'));

      Finder slider(String label) => find.byWidgetPredicate(
        (widget) => widget is Slider && widget.label == label,
      );

      TextEditorState editor(WidgetTester tester) =>
          tester.state<TextEditorState>(find.byType(TextEditor));

      testWidgets('dispatches the outline and shadow of the edited layer', (
        tester,
      ) async {
        final layer = effects.applyTo(
          TextLayer(text: 'Test', textStyle: const TextStyle()),
        );

        await tester.pumpWidget(buildWidget(layer: layer));
        await tester.pump();

        final captured = verify(
          () => mockBloc.add(
            captureAny(that: isA<VideoEditorTextInitFromLayer>()),
          ),
        ).captured;
        final event = captured.first as VideoEditorTextInitFromLayer;
        expect(event.effects, equals(effects));
      });

      testWidgets('previews the shadow of the edited layer while typing', (
        tester,
      ) async {
        // Without an outline the typed glyphs cast the shadow themselves.
        final layer = const TextEffects(shadowStrength: 0.5).applyTo(
          TextLayer(text: 'Test', textStyle: const TextStyle()),
        );

        await tester.pumpWidget(buildWidget(layer: layer));
        await tester.pump();

        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.style?.shadows, isNotEmpty);
      });

      testWidgets('shows the panel when showEffectsPanel is true', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(
            state: const VideoEditorTextState(showEffectsPanel: true),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(VideoEditorTextEffectsPanel), findsOneWidget);
        expect(find.byType(TextEffectsControls), findsOneWidget);
        expect(find.byType(VideoEditorColorPickerSheet), findsNothing);
      });

      testWidgets('writes an outline from the panel to the live editor', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(
            state: const VideoEditorTextState(showEffectsPanel: true),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(slider(l10n.videoEditorTextOutlineThickness));
        await tester.pump();

        expect(editor(tester).outlineWidth, greaterThan(0));
        verify(
          () => mockBloc.add(any(that: isA<VideoEditorTextEffectsChanged>())),
        ).called(1);
      });

      testWidgets('writes a shadow from the panel to the live editor', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(
            state: const VideoEditorTextState(showEffectsPanel: true),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(slider(l10n.videoEditorTextShadowStrength));
        await tester.pump();

        expect(editor(tester).selectedTextStyle.shadows, isNotEmpty);
      });
    });

    group('Editing an existing overlay', () {
      testWidgets('keeps its time window and animations', (tester) async {
        final layer = TextLayer(
          text: 'Hello',
          startTime: const Duration(seconds: 1),
          endTime: const Duration(seconds: 3),
          animations: const [
            LayerAnimation(
              type: LayerAnimationType.fade,
              phase: AnimationPhase.animateIn,
              duration: Duration(milliseconds: 300),
            ),
          ],
        );
        TextLayer? edited;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(sharedPreferences),
            ],
            child: MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    edited = await Navigator.of(context).push<TextLayer>(
                      MaterialPageRoute(
                        builder: (_) => InheritedGoRouter(
                          goRouter: mockGoRouter,
                          child: BlocProvider<VideoEditorTextBloc>.value(
                            value: mockBloc,
                            child: Scaffold(
                              body: VideoTextEditorScreen(layer: layer),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        tester.state<TextEditorState>(find.byType(TextEditor)).done();
        await tester.pumpAndSettle();

        // pro_image_editor before 14.6.0 returned the edited text without
        // them, which turned the overlay full length with no animation.
        expect(edited, isNotNull);
        expect(edited!.startTime, const Duration(seconds: 1));
        expect(edited!.endTime, const Duration(seconds: 3));
        expect(edited!.animations, layer.animations);
      });
    });

    group('Panel visibility', () {
      testWidgets('does not show font selector by default', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pump();

        // Font selector should not be visible
        expect(find.byType(VideoEditorTextFontSelector), findsNothing);
      });

      testWidgets('does not show color picker by default', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pump();

        expect(find.byType(VideoEditorColorPickerSheet), findsNothing);
      });

      testWidgets('shows color picker when showColorPicker is true', (
        tester,
      ) async {
        final controller = StreamController<VideoEditorTextState>.broadcast();

        when(
          () => mockBloc.state,
        ).thenReturn(const VideoEditorTextState(showColorPicker: true));
        when(() => mockBloc.stream).thenAnswer((_) => controller.stream);

        await tester.pumpWidget(
          buildWidget(state: const VideoEditorTextState(showColorPicker: true)),
        );
        await tester.pumpAndSettle();

        expect(find.byType(VideoEditorColorPickerSheet), findsOneWidget);

        await controller.close();
      });
    });

    group('Font scale', () {
      testWidgets('starts new text at the initial font scale', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pump();

        expect(
          tester.state<TextEditorState>(find.byType(TextEditor)).fontScale,
          VideoEditorConstants.initialFontScale,
        );
      });

      testWidgets('keeps the font scale of an edited layer', (tester) async {
        final layer = TextLayer(text: 'Hello', fontScale: 3.1);

        await tester.pumpWidget(buildWidget(layer: layer));
        await tester.pump();

        expect(
          tester.state<TextEditorState>(find.byType(TextEditor)).fontScale,
          3.1,
        );
      });
    });

    group('TextEditor configuration', () {
      testWidgets('TextEditor uses base font size', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pump();

        final textEditor = tester.widget<TextEditor>(find.byType(TextEditor));
        expect(
          textEditor.configs.textEditor.initFontSize,
          VideoEditorConstants.baseFontSize,
        );
      });
    });
  });

  group('Input alignment', () {
    final alignmentTestCases = [
      (TextAlign.left, Alignment.centerLeft),
      (TextAlign.right, Alignment.centerRight),
      (TextAlign.center, Alignment.center),
    ];

    for (final (textAlign, expectedAlignment) in alignmentTestCases) {
      testWidgets('$textAlign uses $expectedAlignment', (tester) async {
        final mockBloc = MockVideoEditorTextBloc();
        when(
          () => mockBloc.state,
        ).thenReturn(VideoEditorTextState(alignment: textAlign));
        when(() => mockBloc.stream).thenAnswer((_) => const Stream.empty());

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: BlocProvider<VideoEditorTextBloc>.value(
              value: mockBloc,
              child: const Scaffold(body: VideoTextEditorScreen()),
            ),
          ),
        );
        await tester.pump();

        final textEditor = tester.widget<TextEditor>(find.byType(TextEditor));
        expect(
          textEditor.configs.textEditor.inputTextFieldAlign,
          expectedAlignment,
        );
      });
    }
  });

  group('TextEditor callbacks', () {
    testWidgets('onBackgroundModeChanged dispatches event to BLoC', (
      tester,
    ) async {
      final mockBloc = MockVideoEditorTextBloc();
      when(() => mockBloc.state).thenReturn(const VideoEditorTextState());
      when(() => mockBloc.stream).thenAnswer((_) => const Stream.empty());

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BlocProvider<VideoEditorTextBloc>.value(
            value: mockBloc,
            child: const Scaffold(body: VideoTextEditorScreen()),
          ),
        ),
      );
      await tester.pump();

      final textEditor = tester.widget<TextEditor>(find.byType(TextEditor));
      final callbacks = textEditor.callbacks.textEditorCallbacks;

      // Simulate callback
      callbacks?.onBackgroundModeChanged?.call(LayerBackgroundMode.onlyColor);

      verify(
        () => mockBloc.add(
          const VideoEditorTextBackgroundStyleChanged(
            LayerBackgroundMode.onlyColor,
          ),
        ),
      ).called(1);
    });

    testWidgets('onTextAlignChanged dispatches event to BLoC', (tester) async {
      final mockBloc = MockVideoEditorTextBloc();
      when(() => mockBloc.state).thenReturn(const VideoEditorTextState());
      when(() => mockBloc.stream).thenAnswer((_) => const Stream.empty());

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BlocProvider<VideoEditorTextBloc>.value(
            value: mockBloc,
            child: const Scaffold(body: VideoTextEditorScreen()),
          ),
        ),
      );
      await tester.pump();

      final textEditor = tester.widget<TextEditor>(find.byType(TextEditor));
      final callbacks = textEditor.callbacks.textEditorCallbacks;

      // Simulate callback
      callbacks?.onTextAlignChanged?.call(TextAlign.right);

      verify(
        () => mockBloc.add(
          const VideoEditorTextAlignmentChanged(TextAlign.right),
        ),
      ).called(1);
    });
  });
}
