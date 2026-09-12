import 'dart:ui' as ui;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group(DivineRangeSlider, () {
    Widget buildSlider({
      RangeValues values = const RangeValues(0.25, 0.75),
      ValueChanged<RangeValues>? onChanged,
      ValueChanged<RangeValues>? onChangeEnd,
      double min = 0,
      double max = 1,
      int? divisions,
      double trackHeight = 8,
      double thumbWidth = 4,
      double thumbHeight = 32,
      Color activeColor = VineTheme.primary,
      Color inactiveColor = VineTheme.onSurfaceDisabled,
      Color thumbColor = VineTheme.onSurface,
      RangeLabels? labels,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: DivineRangeSlider(
                values: values,
                onChanged: onChanged,
                onChangeEnd: onChangeEnd,
                min: min,
                max: max,
                divisions: divisions,
                trackHeight: trackHeight,
                thumbWidth: thumbWidth,
                thumbHeight: thumbHeight,
                activeColor: activeColor,
                inactiveColor: inactiveColor,
                thumbColor: thumbColor,
                labels: labels,
              ),
            ),
          ),
        ),
      );
    }

    group('renders', () {
      testWidgets('$DivineRangeSlider with default properties', (tester) async {
        await tester.pumpWidget(buildSlider());

        expect(find.byType(DivineRangeSlider), findsOneWidget);
        expect(find.byType(RangeSlider), findsOneWidget);
      });

      testWidgets('applies colors and shapes via $SliderTheme', (tester) async {
        await tester.pumpWidget(
          buildSlider(
            activeColor: Colors.red,
            inactiveColor: Colors.blue,
            thumbColor: Colors.green,
          ),
        );

        final sliderTheme = tester.widget<SliderTheme>(
          find.byType(SliderTheme),
        );

        expect(sliderTheme.data.activeTrackColor, equals(Colors.red));
        expect(sliderTheme.data.inactiveTrackColor, equals(Colors.blue));
        expect(sliderTheme.data.thumbColor, equals(Colors.green));
        expect(
          sliderTheme.data.rangeTrackShape,
          isA<DivineRangeSliderTrackShape>(),
        );
        expect(
          sliderTheme.data.rangeThumbShape,
          isA<DivineRangeSliderThumbShape>(),
        );
        expect(
          sliderTheme.data.overlayShape,
          equals(SliderComponentShape.noOverlay),
        );
        expect(
          sliderTheme.data.showValueIndicator,
          equals(ShowValueIndicator.never),
        );
      });

      testWidgets('uses custom track height', (tester) async {
        await tester.pumpWidget(buildSlider(trackHeight: 12));

        final sliderTheme = tester.widget<SliderTheme>(
          find.byType(SliderTheme),
        );

        expect(sliderTheme.data.trackHeight, equals(12));
      });

      testWidgets('passes divisions and labels to $RangeSlider', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildSlider(
            divisions: 11,
            labels: const RangeLabels('start', 'end'),
          ),
        );

        final slider = tester.widget<RangeSlider>(find.byType(RangeSlider));
        expect(slider.divisions, equals(11));
        expect(slider.labels, equals(const RangeLabels('start', 'end')));
      });

      testWidgets('clamps out-of-range values to min/max', (tester) async {
        await tester.pumpWidget(
          buildSlider(values: const RangeValues(-1, 2)),
        );

        final slider = tester.widget<RangeSlider>(find.byType(RangeSlider));
        expect(slider.values, equals(const RangeValues(0, 1)));
      });

      testWidgets('works with custom min/max', (tester) async {
        await tester.pumpWidget(
          buildSlider(
            values: const RangeValues(2, 4),
            min: 1,
            max: 5,
          ),
        );

        final slider = tester.widget<RangeSlider>(find.byType(RangeSlider));
        expect(slider.min, equals(1));
        expect(slider.max, equals(5));
        expect(slider.values, equals(const RangeValues(2, 4)));
      });
    });

    group('interactions', () {
      testWidgets('calls onChanged when a thumb is dragged', (tester) async {
        final changes = <RangeValues>[];

        await tester.pumpWidget(
          buildSlider(onChanged: changes.add),
        );

        final sliderRect = tester.getRect(find.byType(RangeSlider));
        // Grab the end thumb (at 75% of the track) and drag it right.
        await tester.dragFrom(
          Offset(
            sliderRect.left + sliderRect.width * 0.75,
            sliderRect.center.dy,
          ),
          const Offset(40, 0),
        );
        await tester.pump();

        expect(changes, isNotEmpty);
        for (final values in changes) {
          expect(values.start, inInclusiveRange(0, 1));
          expect(values.end, inInclusiveRange(0, 1));
        }
      });

      testWidgets('calls onChangeEnd with the final values when drag ends', (
        tester,
      ) async {
        RangeValues? ended;

        await tester.pumpWidget(
          buildSlider(
            onChanged: (_) {},
            onChangeEnd: (values) => ended = values,
          ),
        );

        final sliderRect = tester.getRect(find.byType(RangeSlider));
        await tester.dragFrom(
          Offset(
            sliderRect.left + sliderRect.width * 0.25,
            sliderRect.center.dy,
          ),
          const Offset(40, 0),
        );
        await tester.pump();

        expect(ended, isNotNull);
      });

      testWidgets('does not call onChanged when disabled', (tester) async {
        var wasCalled = false;

        await tester.pumpWidget(
          buildSlider(onChanged: (_) => wasCalled = true),
        );

        // Rebuild with onChanged set to null (disabled).
        await tester.pumpWidget(buildSlider());

        await tester.tap(find.byType(RangeSlider));
        await tester.pump();

        expect(wasCalled, isFalse);
      });
    });

    group('constructor assertions', () {
      test('asserts min <= max', () {
        expect(
          () => DivineRangeSlider(
            values: const RangeValues(0, 0),
            onChanged: (_) {},
            min: 10,
            max: 5,
          ),
          throwsAssertionError,
        );
      });

      test('asserts divisions > 0', () {
        expect(
          () => DivineRangeSlider(
            values: const RangeValues(0, 1),
            onChanged: (_) {},
            divisions: 0,
          ),
          throwsAssertionError,
        );
      });

      test('asserts trackHeight >= 0', () {
        expect(
          () => DivineRangeSlider(
            values: const RangeValues(0, 1),
            onChanged: (_) {},
            trackHeight: -1,
          ),
          throwsAssertionError,
        );
      });

      test('asserts thumbWidth > 0', () {
        expect(
          () => DivineRangeSlider(
            values: const RangeValues(0, 1),
            onChanged: (_) {},
            thumbWidth: 0,
          ),
          throwsAssertionError,
        );
      });

      test('asserts thumbHeight > 0', () {
        expect(
          () => DivineRangeSlider(
            values: const RangeValues(0, 1),
            onChanged: (_) {},
            thumbHeight: 0,
          ),
          throwsAssertionError,
        );
      });
    });

    group(DivineRangeSliderTrackShape, () {
      test('getPreferredRect returns correct dimensions', () {
        const trackShape = DivineRangeSliderTrackShape(trackHeight: 10);
        final parentBox = _FakeRenderBox(size: const Size(300, 48));

        final rect = trackShape.getPreferredRect(
          parentBox: parentBox,
          sliderTheme: const SliderThemeData(),
        );

        expect(rect.left, equals(0));
        expect(rect.width, equals(300));
        expect(rect.height, equals(10));
        // Vertically centered: (48 - 10) / 2 = 19
        expect(rect.top, equals(19));
      });

      test('getPreferredRect applies offset', () {
        const trackShape = DivineRangeSliderTrackShape();
        final parentBox = _FakeRenderBox(size: const Size(200, 40));

        final rect = trackShape.getPreferredRect(
          parentBox: parentBox,
          sliderTheme: const SliderThemeData(),
          offset: const Offset(10, 20),
        );

        expect(rect.left, equals(10));
        expect(rect.top, equals(20 + (40 - 8) / 2));
        expect(rect.width, equals(200));
        expect(rect.height, equals(8));
      });

      test('paints with ordered and reversed thumb centers', () {
        const trackShape = DivineRangeSliderTrackShape();
        const sliderTheme = SliderThemeData(
          activeTrackColor: Colors.red,
          inactiveTrackColor: Colors.grey,
          trackHeight: 8,
        );
        final parentBox = _FakeRenderBox(size: const Size(300, 48));

        for (final centers in const [
          (Offset(100, 24), Offset(200, 24)),
          (Offset(200, 24), Offset(100, 24)),
        ]) {
          final recorder = ui.PictureRecorder();
          trackShape.paint(
            _FakePaintingContext(Canvas(recorder)),
            Offset.zero,
            parentBox: parentBox,
            sliderTheme: sliderTheme,
            enableAnimation: kAlwaysCompleteAnimation,
            startThumbCenter: centers.$1,
            endThumbCenter: centers.$2,
            textDirection: TextDirection.ltr,
          );

          expect(recorder.endRecording(), isNotNull);
        }
      });
    });

    group(DivineRangeSliderThumbShape, () {
      test('getPreferredSize returns width and height', () {
        const thumbShape = DivineRangeSliderThumbShape(
          width: 6,
          height: 24,
        );

        final size = thumbShape.getPreferredSize(true, false);

        expect(size.width, equals(6));
        expect(size.height, equals(24));
      });

      test('getPreferredSize with defaults', () {
        const thumbShape = DivineRangeSliderThumbShape();

        final size = thumbShape.getPreferredSize(false, false);

        expect(size.width, equals(4));
        expect(size.height, equals(32));
      });

      test('paints the capsule thumb', () {
        const thumbShape = DivineRangeSliderThumbShape();
        final recorder = ui.PictureRecorder();

        thumbShape.paint(
          _FakePaintingContext(Canvas(recorder)),
          const Offset(50, 24),
          activationAnimation: kAlwaysCompleteAnimation,
          enableAnimation: kAlwaysCompleteAnimation,
          sliderTheme: const SliderThemeData(thumbColor: Colors.white),
        );

        expect(recorder.endRecording(), isNotNull);
      });
    });
  });
}

class _FakeRenderBox extends RenderBox {
  _FakeRenderBox({required Size size}) : _size = size;

  final Size _size;

  @override
  Size get size => _size;
}

class _FakePaintingContext extends PaintingContext {
  _FakePaintingContext(this._canvas)
    : super(
        _FakeContainerLayer(),
        Rect.largest,
      );

  final Canvas _canvas;

  @override
  Canvas get canvas => _canvas;
}

class _FakeContainerLayer extends ContainerLayer {}
