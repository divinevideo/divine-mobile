import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/widgets/profile/profile_tab_bottom_inset_sliver.dart';

void main() {
  group(ProfileTabBottomInsetSliver, () {
    group('renders', () {
      testWidgets('as tall as the bottom safe area', (tester) async {
        await tester.pumpWidget(
          const MediaQuery(
            data: MediaQueryData(viewPadding: EdgeInsets.only(bottom: 34)),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: CustomScrollView(
                slivers: [ProfileTabBottomInsetSliver()],
              ),
            ),
          ),
        );

        expect(
          tester.getSize(find.byType(SizedBox)).height,
          equals(34),
        );
      });
    });
  });
}
