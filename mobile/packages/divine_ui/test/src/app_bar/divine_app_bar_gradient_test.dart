import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('DiVineAppBarGradient', () {
    group('constructor', () {
      test('creates with required colors', () {
        const gradient = DiVineAppBarGradient(
          colors: [Colors.black, Colors.transparent],
        );

        expect(gradient.colors, [Colors.black, Colors.transparent]);
        expect(gradient.begin, Alignment.topCenter);
        expect(gradient.end, Alignment.bottomCenter);
        expect(gradient.stops, isNull);
      });

      test('creates with all parameters', () {
        const gradient = DiVineAppBarGradient(
          colors: [Colors.red, Colors.blue, Colors.green],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          stops: [0.0, 0.5, 1.0],
        );

        expect(gradient.colors, [Colors.red, Colors.blue, Colors.green]);
        expect(gradient.begin, Alignment.centerLeft);
        expect(gradient.end, Alignment.centerRight);
        expect(gradient.stops, [0.0, 0.5, 1.0]);
      });
    });

    group('videoOverlay', () {
      test('has correct colors', () {
        final gradient = DiVineAppBarGradient.videoOverlay;

        expect(gradient.colors.length, 2);
        expect(gradient.colors[0], Colors.black.withValues(alpha: 0.7));
        expect(gradient.colors[1], Colors.transparent);
      });

      test('has correct alignment', () {
        final gradient = DiVineAppBarGradient.videoOverlay;

        expect(gradient.begin, Alignment.topCenter);
        expect(gradient.end, Alignment.bottomCenter);
      });

      test('has no stops', () {
        final gradient = DiVineAppBarGradient.videoOverlay;

        expect(gradient.stops, isNull);
      });
    });

    group('subtleOverlay', () {
      test('has correct colors', () {
        final gradient = DiVineAppBarGradient.subtleOverlay;

        expect(gradient.colors.length, 2);
        expect(gradient.colors[0], Colors.black.withValues(alpha: 0.4));
        expect(gradient.colors[1], Colors.transparent);
      });

      test('has correct alignment', () {
        final gradient = DiVineAppBarGradient.subtleOverlay;

        expect(gradient.begin, Alignment.topCenter);
        expect(gradient.end, Alignment.bottomCenter);
      });
    });

    group('toLinearGradient', () {
      test('creates LinearGradient with correct colors', () {
        const gradient = DiVineAppBarGradient(
          colors: [Colors.red, Colors.blue],
        );

        final linearGradient = gradient.toLinearGradient();

        expect(linearGradient.colors, [Colors.red, Colors.blue]);
      });

      test('creates LinearGradient with correct alignment', () {
        const gradient = DiVineAppBarGradient(
          colors: [Colors.red, Colors.blue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );

        final linearGradient = gradient.toLinearGradient();

        expect(linearGradient.begin, Alignment.topLeft);
        expect(linearGradient.end, Alignment.bottomRight);
      });

      test('creates LinearGradient with stops', () {
        const gradient = DiVineAppBarGradient(
          colors: [Colors.red, Colors.blue, Colors.green],
          stops: [0.0, 0.3, 1.0],
        );

        final linearGradient = gradient.toLinearGradient();

        expect(linearGradient.stops, [0.0, 0.3, 1.0]);
      });

      test('creates LinearGradient without stops when null', () {
        const gradient = DiVineAppBarGradient(
          colors: [Colors.red, Colors.blue],
        );

        final linearGradient = gradient.toLinearGradient();

        expect(linearGradient.stops, isNull);
      });
    });

    group('equality', () {
      test('equal gradients are equal', () {
        const gradient1 = DiVineAppBarGradient(
          colors: [Colors.red, Colors.blue],
          stops: [0.0, 1.0],
        );
        const gradient2 = DiVineAppBarGradient(
          colors: [Colors.red, Colors.blue],
          stops: [0.0, 1.0],
        );

        expect(gradient1, equals(gradient2));
      });

      test('gradients with different colors are not equal', () {
        const gradient1 = DiVineAppBarGradient(
          colors: [Colors.red, Colors.blue],
        );
        const gradient2 = DiVineAppBarGradient(
          colors: [Colors.green, Colors.yellow],
        );

        expect(gradient1, isNot(equals(gradient2)));
      });

      test('gradients with different alignments are not equal', () {
        const gradient1 = DiVineAppBarGradient(
          colors: [Colors.red, Colors.blue],
        );
        const gradient2 = DiVineAppBarGradient(
          colors: [Colors.red, Colors.blue],
          begin: Alignment.centerLeft,
        );

        expect(gradient1, isNot(equals(gradient2)));
      });

      test('gradients with different stops are not equal', () {
        const gradient1 = DiVineAppBarGradient(
          colors: [Colors.red, Colors.blue],
          stops: [0.0, 1.0],
        );
        const gradient2 = DiVineAppBarGradient(
          colors: [Colors.red, Colors.blue],
          stops: [0.0, 0.5],
        );

        expect(gradient1, isNot(equals(gradient2)));
      });

      test('gradients with null vs non-null stops are not equal', () {
        const gradient1 = DiVineAppBarGradient(
          colors: [Colors.red, Colors.blue],
        );
        const gradient2 = DiVineAppBarGradient(
          colors: [Colors.red, Colors.blue],
          stops: [0.0, 1.0],
        );

        expect(gradient1, isNot(equals(gradient2)));
      });
    });

    group('hashCode', () {
      test('is consistent for equal gradients', () {
        const gradient1 = DiVineAppBarGradient(
          colors: [Colors.red, Colors.blue],
          stops: [0.0, 1.0],
        );
        const gradient2 = DiVineAppBarGradient(
          colors: [Colors.red, Colors.blue],
          stops: [0.0, 1.0],
        );

        expect(gradient1.hashCode, equals(gradient2.hashCode));
      });

      test('differs for different gradients', () {
        const gradient1 = DiVineAppBarGradient(
          colors: [Colors.red, Colors.blue],
        );
        const gradient2 = DiVineAppBarGradient(
          colors: [Colors.green, Colors.yellow],
        );

        expect(gradient1.hashCode, isNot(equals(gradient2.hashCode)));
      });

      test('handles null stops correctly', () {
        const gradient = DiVineAppBarGradient(
          colors: [Colors.red, Colors.blue],
        );

        // Should not throw
        expect(() => gradient.hashCode, returnsNormally);
      });
    });
  });
}
