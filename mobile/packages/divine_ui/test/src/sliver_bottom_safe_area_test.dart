import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group(SliverBottomSafeArea, () {
    testWidgets(
      'renders $SizedBox with system bottom padding',
      (tester) async {
        await tester.pumpWidget(
          const MediaQuery(
            data: MediaQueryData(
              viewPadding: EdgeInsets.only(bottom: 34),
            ),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: SizedBox(height: 100)),
                  SliverBottomSafeArea(),
                ],
              ),
            ),
          ),
        );

        final sizedBox = tester.widget<SizedBox>(
          find.descendant(
            of: find.byType(SliverBottomSafeArea),
            matching: find.byType(SizedBox),
          ),
        );
        expect(sizedBox.height, equals(34));
      },
    );
  });
}
