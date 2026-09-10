// ABOUTME: Tests for sharePositionOriginForContext, the popover anchor
// ABOUTME: helper required by share_plus on iPad idiom (incl. iOS-on-Mac).

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/utils/share_position_origin.dart';

void main() {
  group('sharePositionOriginForContext', () {
    testWidgets('returns the global bounds of a laid-out widget', (
      tester,
    ) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Center(child: SizedBox(key: key, width: 120, height: 48)),
        ),
      );

      final origin = sharePositionOriginForContext(key.currentContext!);

      final box = key.currentContext!.findRenderObject()! as RenderBox;
      final expected = box.localToGlobal(Offset.zero) & box.size;
      expect(origin, equals(expected));
      expect(origin!.isEmpty, isFalse);
      expect(origin.size, equals(const Size(120, 48)));
    });

    testWidgets('returns null for a zero-sized widget', (tester) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox.shrink(key: key),
          ),
        ),
      );

      final origin = sharePositionOriginForContext(key.currentContext!);

      expect(origin, isNull);
    });
  });
}
