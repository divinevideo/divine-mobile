import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_recorder/video_recorder_mode.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_mode_selector.dart';

void main() {
  group(VideoRecorderModeSelectorWheel, () {
    final l10n = lookupAppLocalizations(const Locale('en'));

    // Item widths follow each label's measured (wide, extra-bold) text, and
    // the wheel lazily builds only the items inside its viewport. The tests
    // below assert on every mode at once, so both the surface and the host
    // box are sized wide enough to lay out all modes on screen — otherwise
    // the outer labels scroll off and are never built or hit-testable.
    const surfaceWidth = 1500.0;

    late VideoRecorderMode selectedMode;
    late List<VideoRecorderMode> modeChanges;

    setUp(() {
      selectedMode = VideoRecorderMode.capture;
      modeChanges = [];
    });

    Widget buildWidget({
      VideoRecorderMode? mode,
      ThemeData? theme,
      bool reduceMotion = false,
    }) {
      return MaterialApp(
        theme: theme,
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: reduceMotion),
          child: child!,
        ),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: surfaceWidth,
              child: VideoRecorderModeSelectorWheel(
                selectedMode: mode ?? selectedMode,
                onModeChanged: (m) => modeChanges.add(m),
              ),
            ),
          ),
        ),
      );
    }

    Future<void> pumpSelector(
      WidgetTester tester, {
      VideoRecorderMode? mode,
      ThemeData? theme,
      bool reduceMotion = false,
    }) async {
      tester.view.physicalSize = const Size(surfaceWidth, 400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        buildWidget(mode: mode, theme: theme, reduceMotion: reduceMotion),
      );
      await tester.pumpAndSettle();
    }

    // `Material` also inserts an `AnimatedDefaultTextStyle`, so take the
    // closest ancestor — the wheel's own.
    Color labelColor(WidgetTester tester, String label) => tester
        .widget<AnimatedDefaultTextStyle>(
          find
              .ancestor(
                of: find.text(label),
                matching: find.byType(AnimatedDefaultTextStyle),
              )
              .first,
        )
        .style
        .color!;

    group('renders', () {
      testWidgets('renders all mode labels', (tester) async {
        await pumpSelector(tester);

        for (final mode in VideoRecorderMode.values) {
          expect(find.text(mode.label), findsOneWidget);
        }
      });

      testWidgets('renders with capture mode selected', (tester) async {
        await pumpSelector(tester, mode: VideoRecorderMode.capture);

        expect(find.byType(VideoRecorderModeSelectorWheel), findsOneWidget);
      });

      testWidgets('renders with classic mode selected', (tester) async {
        await pumpSelector(tester, mode: VideoRecorderMode.classic);

        expect(find.byType(VideoRecorderModeSelectorWheel), findsOneWidget);
      });

      testWidgets('renders pill background', (tester) async {
        await pumpSelector(tester);

        expect(find.byType(AnimatedContainer), findsOneWidget);
      });

      testWidgets('keeps the armed mode readable in light mode', (
        tester,
      ) async {
        await pumpSelector(
          tester,
          mode: VideoRecorderMode.capture,
          theme: VineTheme.lightTheme,
        );

        // The accent only reaches 1.92:1 on the `surfaceContainer` pill.
        expect(
          labelColor(tester, VideoRecorderMode.capture.label),
          VineTheme.lightColors.onSurface,
        );
        expect(
          labelColor(tester, VideoRecorderMode.classic.label),
          VineTheme.lightColors.mutedText,
        );

        final pill = tester.widget<AnimatedContainer>(
          find.byType(AnimatedContainer),
        );
        final decoration = pill.decoration! as BoxDecoration;
        expect(decoration.color, VineTheme.lightColors.surfaceContainer);
        expect(
          (decoration.border! as Border).top.color,
          VineTheme.lightColors.outline,
        );
      });

      testWidgets('keeps the accent on the armed mode in dark mode', (
        tester,
      ) async {
        await pumpSelector(
          tester,
          mode: VideoRecorderMode.capture,
          theme: VineTheme.theme,
        );

        expect(
          labelColor(tester, VideoRecorderMode.capture.label),
          VineTheme.primary,
        );
      });
    });

    group('interactions', () {
      testWidgets('calls onModeChanged when tapping a different mode', (
        tester,
      ) async {
        // Suppress haptic feedback method channel calls in test
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (call) async {
              return null;
            });
        addTearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(SystemChannels.platform, null);
        });

        await pumpSelector(tester, mode: VideoRecorderMode.capture);

        await tester.tap(find.text('Classic'));
        await tester.pumpAndSettle();

        expect(modeChanges, contains(VideoRecorderMode.classic));
      });

      testWidgets('a forward drag settles on one item, not the last', (
        tester,
      ) async {
        // Suppress haptic feedback method channel calls in test
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (call) async {
              return null;
            });
        addTearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(SystemChannels.platform, null);
        });

        await pumpSelector(tester, mode: VideoRecorderMode.capture);

        // A single user drag must produce a single snap. Regression guard:
        // the programmatic snap animation used to re-trigger snapping and run
        // the wheel all the way to the final ("Classic") item.
        await tester.drag(find.byType(ListView), const Offset(-60, 0));
        await tester.pumpAndSettle();

        expect(modeChanges, isNotEmpty);
        expect(modeChanges, isNot(contains(VideoRecorderMode.classic)));
      });

      testWidgets('uses ShaderMask for fade-out edges', (tester) async {
        await pumpSelector(tester);

        expect(find.byType(ShaderMask), findsOneWidget);
      });

      testWidgets('renders horizontal ListView', (tester) async {
        await pumpSelector(tester);

        final listView = tester.widget<ListView>(find.byType(ListView));
        expect(listView.scrollDirection, equals(Axis.horizontal));
      });
    });

    group('accessibility', () {
      testWidgets('each mode is exposed as a selectable Semantics button', (
        tester,
      ) async {
        await pumpSelector(tester, mode: VideoRecorderMode.capture);
        final semanticsHandle = tester.ensureSemantics();

        try {
          for (final mode in VideoRecorderMode.values) {
            final expectedLabel = mode == VideoRecorderMode.capture
                ? mode.label
                : l10n.videoRecorderSwitchToModeLabel(mode.label);
            final semantics = tester
                .widgetList<Semantics>(find.byType(Semantics))
                .firstWhere((s) => s.properties.label == expectedLabel);
            final semanticsNode = tester.getSemantics(
              find.bySemanticsIdentifier(SemanticIds.cameraMode(mode.name)),
            );
            expect(semanticsNode.label, expectedLabel);
            expect(semantics.properties.button, isTrue);
            expect(
              semantics.properties.selected,
              mode == VideoRecorderMode.capture,
            );
          }
        } finally {
          semanticsHandle.dispose();
        }
      });

      testWidgets('each mode tap target meets the 48dp minimum', (
        tester,
      ) async {
        await pumpSelector(tester);

        final targets = find.descendant(
          of: find.byType(ListView),
          matching: find.byType(GestureDetector),
        );
        expect(targets, findsWidgets);
        for (final target in targets.evaluate()) {
          expect(
            tester.getSize(find.byWidget(target.widget)).height,
            greaterThanOrEqualTo(kMinInteractiveDimension),
          );
        }
      });

      testWidgets('under reduced motion the pill resizes without tweening', (
        tester,
      ) async {
        await pumpSelector(
          tester,
          mode: VideoRecorderMode.capture,
          reduceMotion: true,
        );
        double pillWidth() =>
            tester.getSize(find.byType(AnimatedContainer)).width;
        final before = pillWidth();

        await tester.tap(find.text(VideoRecorderMode.stopMotion.label));
        await tester.pump();
        final immediate = pillWidth();
        await tester.pumpAndSettle();

        // One frame after the tap the pill is already at the width it settles
        // on — a tween would still be part-way there.
        expect(immediate, equals(pillWidth()));
        expect(immediate, isNot(equals(before)));
      });
    });

    group('didUpdateWidget', () {
      testWidgets('updates selection when mode changes externally', (
        tester,
      ) async {
        await pumpSelector(tester, mode: VideoRecorderMode.capture);

        await pumpSelector(tester, mode: VideoRecorderMode.classic);

        expect(find.byType(VideoRecorderModeSelectorWheel), findsOneWidget);
      });

      testWidgets(
        'an external mode change repositions instantly without a scroll '
        'animation (persisted-mode restore on open)',
        (tester) async {
          await pumpSelector(tester, mode: VideoRecorderMode.capture);
          final scrollable = tester.state<ScrollableState>(
            find.byType(Scrollable).first,
          );
          final offsetBefore = scrollable.position.pixels;

          await tester.pumpWidget(buildWidget(mode: VideoRecorderMode.classic));

          // The wheel is already on the new mode after the rebuild frame —
          // no in-flight animation left for pumpAndSettle to advance.
          final offsetAfterRebuild = scrollable.position.pixels;
          expect(offsetAfterRebuild, isNot(equals(offsetBefore)));
          await tester.pumpAndSettle();
          expect(scrollable.position.pixels, equals(offsetAfterRebuild));
        },
      );
    });
  });
}
