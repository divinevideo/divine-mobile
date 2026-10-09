import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/profile/profile_outer_scroll_physics.dart';

ScrollMetrics _metrics({required double pixels, double max = 500}) =>
    FixedScrollMetrics(
      minScrollExtent: 0,
      maxScrollExtent: max,
      pixels: pixels,
      viewportDimension: 800,
      axisDirection: AxisDirection.down,
      devicePixelRatio: 3,
    );

void main() {
  group('profileOuterScrollExtentFor', () {
    test('stops before the tab bar pins when the content is short', () {
      expect(
        profileOuterScrollExtentFor(
          header: 700,
          tabBar: 50,
          safeAreaTop: 60,
          content: 200,
          viewport: 800,
        ),
        equals(150),
      );
    });

    test('counts the status-bar inset once the tab bar has to pin', () {
      expect(
        profileOuterScrollExtentFor(
          header: 700,
          tabBar: 50,
          safeAreaTop: 60,
          content: 720,
          viewport: 800,
        ),
        equals(730),
      );
    });

    test('does not scroll at all when everything already fits', () {
      expect(
        profileOuterScrollExtentFor(
          header: 300,
          tabBar: 50,
          safeAreaTop: 60,
          content: 100,
          viewport: 800,
        ),
        equals(0),
      );
    });
  });

  group('profileTabMinimumContentExtent', () {
    test('is one row of the three-column grid plus the safe area', () {
      expect(
        profileTabMinimumContentExtent(tabWidth: 404, bottomSafeArea: 34),
        equals(166),
      );
    });
  });

  group(ProfileOuterScrollPhysics, () {
    const physics = ProfileOuterScrollPhysics(
      scrollLimit: _limitAt200,
      parent: ClampingScrollPhysics(),
    );

    group('applyBoundaryConditions', () {
      test('refuses to move past the limit', () {
        expect(
          physics.applyBoundaryConditions(_metrics(pixels: 190), 230),
          equals(30),
        );
      });

      test('lets an offset beyond the limit scroll back', () {
        expect(
          physics.applyBoundaryConditions(_metrics(pixels: 300), 280),
          equals(0),
        );
      });

      test('does nothing when the limit is past the natural end', () {
        expect(
          physics.applyBoundaryConditions(
            _metrics(pixels: 100, max: 150),
            140,
          ),
          equals(0),
        );
      });
    });

    group('createBallisticSimulation', () {
      test('ends a fling on the limit', () {
        final simulation = physics.createBallisticSimulation(
          _metrics(pixels: 100),
          5000,
        )!;

        expect(simulation.x(10), equals(200));
        expect(simulation.isDone(10), isTrue);
      });

      test('leaves a downward fling to the parent', () {
        final simulation = physics.createBallisticSimulation(
          _metrics(pixels: 100),
          -5000,
        )!;

        expect(simulation.x(10), lessThan(100));
      });
    });
  });
}

double? _limitAt200(double viewportExtent) => 200;
