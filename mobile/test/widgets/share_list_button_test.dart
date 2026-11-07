import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/share_list_button.dart';

import '../helpers/test_provider_overrides.dart';

void main() {
  group(ShareListButton, () {
    final l10n = lookupAppLocalizations(const Locale('en'));

    testWidgets('is an outline Share button that fills its slot', (
      tester,
    ) async {
      await tester.pumpWidget(
        testMaterialApp(
          home: Scaffold(body: ShareListButton(onPressed: () {})),
        ),
      );

      final button = tester.widget<DivineButton>(find.byType(DivineButton));
      expect(button.label, l10n.listShareButton);
      expect(button.type, DivineButtonType.secondary);
      expect(button.expanded, isTrue);
    });

    testWidgets('reports a tap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        testMaterialApp(
          home: Scaffold(
            body: ShareListButton(onPressed: () => tapped = true),
          ),
        ),
      );

      await tester.tap(find.text(l10n.listShareButton));
      expect(tapped, isTrue);
    });
  });
}
