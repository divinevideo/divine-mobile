import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/share_list_button.dart';

import '../helpers/finders.dart';
import '../helpers/test_provider_overrides.dart';

void main() {
  group(ShareListButton, () {
    final l10n = lookupAppLocalizations(const Locale('en'));

    testWidgets('announces the share action and reports a tap', (
      tester,
    ) async {
      var tapped = false;
      await tester.pumpWidget(
        testMaterialApp(
          home: Scaffold(
            body: ShareListButton(onPressed: () => tapped = true),
          ),
        ),
      );

      expect(findByTooltip(l10n.listShareAction), findsOneWidget);
      final semantics = tester.getSemantics(find.byType(ShareListButton));
      expect(semantics.label, equals(l10n.listShareAction));

      await tester.tap(find.byType(ShareListButton));
      expect(tapped, isTrue);
    });
  });
}
