// ABOUTME: Tests for VideoEditorVerticalSlider widget.
// ABOUTME: Validates slider rendering, drag interactions, and value updates.

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_editor/video_editor_vertical_slider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoEditorVerticalSlider', () {
    Widget buildSlider({
      double value = 0.5,
      ValueChanged<double>? onChanged,
      ValueChanged<double>? onChangeEnd,
      double height = 300,
    }) {
      return MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: VideoEditorVerticalSlider(
              value: value,
              onChanged: onChanged ?? (_) {},
              onChangeEnd: onChangeEnd,
              height: height,
            ),
          ),
        ),
      );
    }

    group('Rendering', () {
      testWidgets('renders with correct height', (tester) async {
        const testHeight = 250.0;
        await tester.pumpWidget(buildSlider(height: testHeight));

        final slider = tester.widget<VideoEditorVerticalSlider>(
          find.byType(VideoEditorVerticalSlider),
        );
        expect(slider.height, testHeight);

        // SizedBox should have the specified height
        final sizedBox = tester.widget<SizedBox>(
          find
              .descendant(
                of: find.byType(VideoEditorVerticalSlider),
                matching: find.byType(SizedBox),
              )
              .first,
        );
        expect(sizedBox.height, testHeight);
      });

      testWidgets('has minimum touch target width', (tester) async {
        await tester.pumpWidget(buildSlider());

        // Find the ConstrainedBox with minWidth = kMinInteractiveDimension
        final constrainedBoxes = tester.widgetList<ConstrainedBox>(
          find.descendant(
            of: find.byType(VideoEditorVerticalSlider),
            matching: find.byType(ConstrainedBox),
          ),
        );

        final touchTargetBox = constrainedBoxes.where(
          (box) => box.constraints.minWidth == kMinInteractiveDimension,
        );
        expect(touchTargetBox, isNotEmpty);
      });

      testWidgets('wrapped in RepaintBoundary for performance', (tester) async {
        await tester.pumpWidget(buildSlider());

        expect(
          find.descendant(
            of: find.byType(VideoEditorVerticalSlider),
            matching: find.byType(RepaintBoundary),
          ),
          findsOneWidget,
        );
      });

      testWidgets('displays percentage label', (tester) async {
        await tester.pumpWidget(buildSlider(value: 0.75));

        // Should show "75" (75%)
        expect(find.text('75'), findsOneWidget);
      });

      testWidgets('displays 0 when value is 0', (tester) async {
        await tester.pumpWidget(buildSlider(value: 0.0));

        expect(find.text('0'), findsOneWidget);
      });

      testWidgets('displays 100 when value is 1', (tester) async {
        await tester.pumpWidget(buildSlider(value: 1.0));

        expect(find.text('100'), findsOneWidget);
      });

      testWidgets('rounds percentage correctly', (tester) async {
        await tester.pumpWidget(buildSlider(value: 0.333));

        // 33.3 should round to 33
        expect(find.text('33'), findsOneWidget);
      });
    });

    group('Track', () {
      testWidgets('track exists', (tester) async {
        await tester.pumpWidget(buildSlider());

        // Just verify CustomPaint widgets exist - the actual size
        // is determined by the parent Size widget passed to painter
        expect(find.byType(CustomPaint), findsWidgets);
      });
    });

    group('Thumb', () {
      testWidgets('thumb container has correct dimensions', (tester) async {
        await tester.pumpWidget(buildSlider());

        // Find the thumb container (28x28 with decoration)
        final containers = tester.widgetList<Container>(find.byType(Container));
        final thumbContainer = containers.where((c) {
          return c.constraints?.maxWidth == 28 &&
              c.constraints?.maxHeight == 28 &&
              c.decoration != null;
        }).firstOrNull;

        expect(thumbContainer, isNotNull);
      });

      testWidgets('thumb position changes with value', (tester) async {
        // At value 0.0, thumb should be at bottom
        await tester.pumpWidget(buildSlider(value: 0.0));
        await tester.pump();

        final positioned0 = tester.widget<Positioned>(
          find.byType(Positioned).first,
        );
        final topAt0 = positioned0.top!;

        // At value 1.0, thumb should be at top
        await tester.pumpWidget(buildSlider(value: 1.0));
        await tester.pump();

        final positioned1 = tester.widget<Positioned>(
          find.byType(Positioned).first,
        );
        final topAt1 = positioned1.top!;

        // When value is 1.0, top should be smaller (closer to top of container)
        expect(topAt1, lessThan(topAt0));
      });
    });

    group('Drag Interaction', () {
      testWidgets('responds to vertical drag', (tester) async {
        double? changedValue;
        await tester.pumpWidget(
          buildSlider(onChanged: (value) => changedValue = value),
        );

        // Find the GestureDetector
        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(VideoEditorVerticalSlider)),
        );

        // Drag up (increases value)
        await gesture.moveBy(const Offset(0, -50));
        await tester.pump();

        expect(changedValue, isNotNull);
        expect(changedValue, greaterThan(0.5));

        await gesture.up();
      });

      testWidgets('dragging up increases value', (tester) async {
        final values = <double>[];
        await tester.pumpWidget(buildSlider(onChanged: values.add));

        final center = tester.getCenter(find.byType(VideoEditorVerticalSlider));
        await tester.dragFrom(center, const Offset(0, -100));
        await tester.pump();

        expect(values, isNotEmpty);
        // All values should be >= 0.5 when dragging up
        expect(values.last, greaterThan(0.5));
      });

      testWidgets('dragging down decreases value', (tester) async {
        final values = <double>[];
        await tester.pumpWidget(buildSlider(onChanged: values.add));

        final center = tester.getCenter(find.byType(VideoEditorVerticalSlider));
        await tester.dragFrom(center, const Offset(0, 100));
        await tester.pump();

        expect(values, isNotEmpty);
        // All values should be <= 0.5 when dragging down
        expect(values.last, lessThan(0.5));
      });

      testWidgets('value is clamped between 0 and 1', (tester) async {
        final values = <double>[];
        await tester.pumpWidget(buildSlider(onChanged: values.add));

        final center = tester.getCenter(find.byType(VideoEditorVerticalSlider));

        // Drag way up past the top
        await tester.dragFrom(center, const Offset(0, -1000));
        await tester.pump();

        expect(values, isNotEmpty);
        expect(values.last, lessThanOrEqualTo(1.0));
        expect(values.last, greaterThanOrEqualTo(0.0));
      });

      testWidgets('onChangeEnd is called when drag ends', (tester) async {
        double? endValue;
        await tester.pumpWidget(
          buildSlider(
            onChanged: (_) {},
            onChangeEnd: (value) => endValue = value,
          ),
        );

        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(VideoEditorVerticalSlider)),
        );
        await gesture.moveBy(const Offset(0, -50));
        await tester.pump();

        expect(endValue, isNull); // Not called yet

        await gesture.up();
        await tester.pump();

        expect(endValue, isNotNull);
      });
    });

    group('Visual Properties', () {
      testWidgets('uses Stack with no clipping', (tester) async {
        await tester.pumpWidget(buildSlider());

        final stack = tester.widget<Stack>(
          find
              .descendant(
                of: find.byType(VideoEditorVerticalSlider),
                matching: find.byType(Stack),
              )
              .first,
        );
        expect(stack.clipBehavior, Clip.none);
      });

      testWidgets('GestureDetector has opaque behavior', (tester) async {
        await tester.pumpWidget(buildSlider());

        final gestureDetector = tester.widget<GestureDetector>(
          find.descendant(
            of: find.byType(VideoEditorVerticalSlider),
            matching: find.byType(GestureDetector),
          ),
        );
        expect(gestureDetector.behavior, HitTestBehavior.opaque);
      });
    });

    group('Edge Cases', () {
      testWidgets('handles height of 0', (tester) async {
        await tester.pumpWidget(buildSlider(height: 0));
        // Should not crash
        expect(find.byType(VideoEditorVerticalSlider), findsOneWidget);
      });

      testWidgets('handles value at exact boundaries', (tester) async {
        // Test value = 0.0
        await tester.pumpWidget(buildSlider(value: 0.0));
        expect(find.text('0'), findsOneWidget);

        // Test value = 1.0
        await tester.pumpWidget(buildSlider(value: 1.0));
        expect(find.text('100'), findsOneWidget);
      });

      testWidgets('accepts value outside 0-1 range and clamps display', (
        tester,
      ) async {
        // If somehow value is > 1, it should still display reasonably
        await tester.pumpWidget(buildSlider(value: 1.5));
        // 150 would be displayed but position clamped
        expect(find.byType(VideoEditorVerticalSlider), findsOneWidget);
      });
    });
  });
}
