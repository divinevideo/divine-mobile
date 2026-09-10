// ABOUTME: Widget tests for NotificationTypeIcon — the shared 32×32 rounded
// ABOUTME: square type indicator used by both notification list-item variants.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/widgets/notification_type_icon.dart';

void main() {
  group(NotificationTypeIcon, () {
    Widget buildSubject({required bool showUnreadDot}) {
      return MaterialApp(
        home: Scaffold(
          body: NotificationTypeIcon(
            icon: DivineIconName.heart,
            backgroundColor: VineTheme.accentPinkBackground,
            foregroundColor: VineTheme.accentPink,
            showUnreadDot: showUnreadDot,
          ),
        ),
      );
    }

    testWidgets('renders the requested icon', (tester) async {
      await tester.pumpWidget(buildSubject(showUnreadDot: false));

      final icon = tester.widget<DivineIcon>(find.byType(DivineIcon));
      expect(icon.icon, DivineIconName.heart);
      expect(icon.color, VineTheme.accentPink);
    });

    testWidgets('omits unread dot by default', (tester) async {
      await tester.pumpWidget(buildSubject(showUnreadDot: false));

      // Without the dot, the only Container in the subtree is the icon
      // background tile (the outer sizing widget is a SizedBox.square).
      // With the dot, the dot ring and fill add two more Containers.
      // Use the count as a proxy to assert the dot is absent.
      expect(
        tester.widgetList<Container>(find.byType(Container)).length,
        equals(1),
      );
    });

    testWidgets('renders unread dot when requested', (tester) async {
      await tester.pumpWidget(buildSubject(showUnreadDot: true));

      // Icon container + dot ring + dot fill = 3 Containers total.
      expect(
        tester.widgetList<Container>(find.byType(Container)).length,
        equals(3),
      );
    });
  });
}
