import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_video_feed/src/services/pointer_scroll_pager.dart';

Duration _ms(int milliseconds) => Duration(milliseconds: milliseconds);

void main() {
  group(PointerScrollPager, () {
    late PointerScrollPager pager;

    setUp(() {
      pager = PointerScrollPager();
    });

    int add(
      double delta, {
      required int atMs,
      double threshold = 0,
      bool canStep = true,
    }) => pager.add(
      delta,
      timeStamp: _ms(atMs),
      threshold: threshold,
      canStep: canStep,
    );

    group('add', () {
      test('steps forward on a wheel notch down', () {
        expect(add(4, atMs: 0), equals(1));
      });

      test('steps back on a wheel notch up', () {
        expect(add(-4, atMs: 0), equals(-1));
      });

      test('ignores the rest of a gesture that already stepped', () {
        expect(add(40, atMs: 0), equals(1));
        expect(add(40, atMs: 100), equals(0));
        expect(add(40, atMs: 200), equals(0));
      });

      test('steps again once the scroll events pause', () {
        expect(add(40, atMs: 0), equals(1));
        expect(add(40, atMs: 100), equals(0));

        expect(add(40, atMs: 250), equals(1));
      });

      test('does not step while the page is still moving', () {
        expect(add(40, atMs: 0, canStep: false), equals(0));
        expect(add(40, atMs: 20, canStep: false), equals(0));

        expect(
          add(40, atMs: 40),
          equals(1),
          reason: 'the gesture steps once the page has settled',
        );
      });

      test('ignores a scroll without movement', () {
        expect(add(0, atMs: 0), equals(0));
        expect(add(4, atMs: 20), equals(1));
      });

      test('adds up a trackpad swipe until it passes the threshold', () {
        expect(add(15, atMs: 0, threshold: 40), equals(0));
        expect(add(15, atMs: 16, threshold: 40), equals(0));

        expect(add(15, atMs: 32, threshold: 40), equals(1));
      });

      test('forgets a scroll that stopped short of the threshold', () {
        expect(add(30, atMs: 0, threshold: 40), equals(0));

        expect(
          add(30, atMs: 500, threshold: 40),
          equals(0),
          reason: 'a new gesture starts counting from zero',
        );
      });

      test('starts counting again when the gesture turns around', () {
        expect(add(30, atMs: 0, threshold: 40), equals(0));
        expect(add(-30, atMs: 16, threshold: 40), equals(0));

        expect(add(-15, atMs: 32, threshold: 40), equals(-1));
      });
    });
  });
}
