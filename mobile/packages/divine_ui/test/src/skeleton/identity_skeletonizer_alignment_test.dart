// ABOUTME: Pins IdentitySkeletonizer's child to the leading edge of its slot,
// ABOUTME: which AnimatedSwitcher's centring default silently took away.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const _leadingInset = 76.0;
const _trailingInset = 60.0;
const _slotWidth = 400.0;
const double _expectedChildWidth = _slotWidth - _leadingInset - _trailingInset;

Future<Rect> _pumpAndMeasure(
  WidgetTester tester, {
  required bool isLoading,
  String name = 'Gastric Fox 26',
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: _slotWidth,
          child: Row(
            children: [
              const SizedBox(width: _leadingInset),
              Expanded(
                child: IdentitySkeletonizer(
                  isLoading: isLoading,
                  excludeSemantics: true,
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: _trailingInset),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return tester.getRect(find.byType(Text).first);
}

void main() {
  group('IdentitySkeletonizer alignment', () {
    testWidgets('starts the child at the leading edge once resolved', (
      tester,
    ) async {
      final rect = await _pumpAndMeasure(tester, isLoading: false);

      expect(
        rect.left,
        equals(_leadingInset),
        reason:
            'a centred name floats to a different x on every row, so the '
            'inbox title drifts away from the preview beneath it',
      );
    });

    testWidgets('still leads while the shimmer is showing', (tester) async {
      final rect = await _pumpAndMeasure(tester, isLoading: true);

      expect(rect.left, equals(_leadingInset));
    });

    testWidgets('lays out where the slot is horizontally unbounded', (
      tester,
    ) async {
      // The following bar puts this inside a horizontal list, so the child
      // gets unbounded width. A tight fit throws `RenderBox was not laid
      // out` there — caught on a physical device, not by the bounded cases.
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 80,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: IdentitySkeletonizer(
                  isLoading: false,
                  excludeSemantics: true,
                  child: Text('Gastric Fox 26'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Gastric Fox 26'), findsOneWidget);
    });

    testWidgets(
      'a long name ellipsizes inside the slot instead of overflowing',
      (tester) async {
        final rect = await _pumpAndMeasure(
          tester,
          isLoading: false,
          name: 'A very long display name that cannot possibly fit this slot',
        );

        expect(rect.left, equals(_leadingInset));
        expect(rect.width, equals(_expectedChildWidth));
        expect(
          tester.takeException(),
          isNull,
          reason:
              'a shrink-wrapped child overflows here instead of ellipsizing',
        );
      },
    );
  });
}
