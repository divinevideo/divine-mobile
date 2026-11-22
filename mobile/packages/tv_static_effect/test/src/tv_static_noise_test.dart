import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tv_static_effect/tv_static_effect.dart';

class _MockCustomPainter extends Mock implements CustomPainter {}

class _FakeCustomPainter extends Fake implements CustomPainter {}

class _FakeCanvas extends Fake implements Canvas {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeCustomPainter());
    registerFallbackValue(_FakeCanvas());
    registerFallbackValue(Size.zero);
  });

  group(TvStaticNoise, () {
    late _MockCustomPainter mockPainter;

    setUp(() {
      mockPainter = _MockCustomPainter();

      when(() => mockPainter.shouldRepaint(any())).thenReturn(false);
      when(() => mockPainter.paint(any(), any())).thenReturn(null);
      when(() => mockPainter.semanticsBuilder).thenReturn(null);
      when(() => mockPainter.addListener(any())).thenReturn(null);
      when(() => mockPainter.removeListener(any())).thenReturn(null);
    });

    ShaderLoader createTestLoader({
      void Function(double time, double opacity)? onCreatePainter,
    }) {
      return () async => ({required double time, required double opacity}) {
        onCreatePainter?.call(time, opacity);
        return mockPainter;
      };
    }

    group('renders', () {
      testWidgets('$SizedBox before shader is loaded', (tester) async {
        final completer = Completer<PainterFactory>();

        await tester.pumpWidget(
          TvStaticNoise(shaderLoader: () => completer.future),
        );

        expect(find.byType(SizedBox), findsOneWidget);
        expect(find.byType(CustomPaint), findsNothing);

        // Complete and remove widget to avoid pending timer issues.
        completer.complete(
          ({required double time, required double opacity}) => mockPainter,
        );
        await tester.pumpWidget(const SizedBox());
      });

      testWidgets('$CustomPaint after shader is loaded', (tester) async {
        await tester.pumpWidget(
          TvStaticNoise(shaderLoader: createTestLoader()),
        );
        await tester.pump();

        expect(find.byType(CustomPaint), findsOneWidget);
        expect(find.byType(ColoredBox), findsNothing);
      });
    });

    testWidgets('passes default opacity to painter factory', (tester) async {
      double? receivedOpacity;

      await tester.pumpWidget(
        TvStaticNoise(
          shaderLoader: createTestLoader(
            onCreatePainter: (_, opacity) => receivedOpacity = opacity,
          ),
        ),
      );
      await tester.pump();

      expect(receivedOpacity, equals(TvStaticNoise.defaultOpacity));
    });

    testWidgets('passes custom opacity to painter factory', (tester) async {
      double? receivedOpacity;

      await tester.pumpWidget(
        TvStaticNoise(
          opacity: 0.5,
          shaderLoader: createTestLoader(
            onCreatePainter: (_, opacity) => receivedOpacity = opacity,
          ),
        ),
      );
      await tester.pump();

      expect(receivedOpacity, equals(0.5));
    });

    testWidgets('passes updated time to painter after tick', (tester) async {
      final receivedTimes = <double>[];

      await tester.pumpWidget(
        TvStaticNoise(
          shaderLoader: createTestLoader(
            onCreatePainter: (time, _) => receivedTimes.add(time),
          ),
        ),
      );
      await tester.pump();

      final initialTime = receivedTimes.last;

      // Advance enough to cross a 12-fps frame boundary.
      await tester.pump(const Duration(seconds: 1));

      expect(receivedTimes.last, greaterThan(initialTime));
    });

    testWidgets('renders a static frame when animations are disabled', (
      tester,
    ) async {
      final receivedTimes = <double>[];

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: TvStaticNoise(
            shaderLoader: createTestLoader(
              onCreatePainter: (time, _) => receivedTimes.add(time),
            ),
          ),
        ),
      );
      await tester.pump();
      final initialTime = receivedTimes.last;
      await tester.pump(const Duration(seconds: 1));

      expect(receivedTimes.last, initialTime);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('does not call setState when disposed before shader loads', (
      tester,
    ) async {
      final completer = Completer<PainterFactory>();

      await tester.pumpWidget(
        TvStaticNoise(shaderLoader: () => completer.future),
      );

      // Remove the widget before the shader loads.
      await tester.pumpWidget(const SizedBox());

      // Complete the loader after disposal.
      completer.complete(
        ({required double time, required double opacity}) => mockPainter,
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('disposes ticker on widget removal', (tester) async {
      await tester.pumpWidget(TvStaticNoise(shaderLoader: createTestLoader()));
      await tester.pump();

      // Remove the widget — should dispose without errors.
      await tester.pumpWidget(const SizedBox());
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'renders $SizedBox and does not throw when shader loading fails',
      (tester) async {
        await tester.pumpWidget(
          TvStaticNoise(
            shaderLoader: () async => throw Exception('GPU unsupported'),
          ),
        );
        await tester.pump();

        // Should remain as SizedBox, no crash.
        expect(find.byType(SizedBox), findsOneWidget);
        expect(find.byType(CustomPaint), findsNothing);
        expect(tester.takeException(), isNull);

        // Clean up ticker.
        await tester.pumpWidget(const SizedBox());
      },
    );

    group('shader lifetime', () {
      // Loaded by the package-relative key: the package-qualified key the
      // widget uses only resolves in an app that depends on this package.
      Future<ui.FragmentShader> loadShader(WidgetTester tester) async {
        final program = await tester.runAsync(
          () => ui.FragmentProgram.fromAsset('shaders/tv_static.frag'),
        );
        return program!.fragmentShader();
      }

      testWidgets('disposes its shader when unmounted', (tester) async {
        final shader = await loadShader(tester);

        await tester.pumpWidget(
          TvStaticNoise(fragmentShaderLoader: () async => shader),
        );
        await tester.pump();
        expect(find.byType(CustomPaint), findsOneWidget);
        expect(shader.debugDisposed, isFalse);

        await tester.pumpWidget(const SizedBox());

        expect(shader.debugDisposed, isTrue);
      });

      testWidgets('disposes a shader that finishes loading after unmount', (
        tester,
      ) async {
        final shader = await loadShader(tester);
        final completer = Completer<ui.FragmentShader>();

        await tester.pumpWidget(
          TvStaticNoise(fragmentShaderLoader: () => completer.future),
        );
        await tester.pumpWidget(const SizedBox());

        completer.complete(shader);
        await tester.pump();

        expect(shader.debugDisposed, isTrue);
      });

      testWidgets('paints successive frames with the one shader it loaded', (
        tester,
      ) async {
        final shader = await loadShader(tester);
        var loads = 0;

        await tester.pumpWidget(
          TvStaticNoise(
            fragmentShaderLoader: () async {
              loads++;
              return shader;
            },
          ),
        );
        await tester.pump();
        final firstPainter = tester
            .widget<CustomPaint>(find.byType(CustomPaint))
            .painter;

        await tester.pump(const Duration(seconds: 1));
        final laterPainter = tester
            .widget<CustomPaint>(find.byType(CustomPaint))
            .painter;

        expect(laterPainter, isNot(same(firstPainter)));
        expect(loads, equals(1));
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(const SizedBox());
      });
    });

    group('asserts opacity', () {
      test('throws AssertionError when opacity is negative', () {
        expect(() => TvStaticNoise(opacity: -0.1), throwsAssertionError);
      });

      test('throws AssertionError when opacity is greater than 1', () {
        expect(() => TvStaticNoise(opacity: 1.1), throwsAssertionError);
      });
    });
  });
}
