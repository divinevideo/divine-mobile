// ABOUTME: Tests for the AutoActionButton widget.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_feed_item/actions/auto_action_button.dart';

void main() {
  Widget buildSubject({
    required bool isEnabled,
    VoidCallback? onPressed,
    Locale? locale,
  }) {
    return MaterialApp(
      locale: locale,
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: AutoActionButton(
          isEnabled: isEnabled,
          onPressed: onPressed ?? () {},
        ),
      ),
    );
  }

  group(AutoActionButton, () {
    testWidgets('renders a double-play icon with the Compilation label', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(isEnabled: false));

      final icons = tester
          .widgetList<DivineIcon>(find.byType(DivineIcon))
          .toList();

      expect(icons, hasLength(2));
      expect(icons.every((icon) => icon.icon == DivineIconName.play), isTrue);
      expect(find.text('Auto'), findsNothing);
      expect(find.text('Compilation'), findsOneWidget);
    });

    testWidgets('uses enable semantics when disabled', (tester) async {
      await tester.pumpWidget(buildSubject(isEnabled: false));

      expect(find.bySemanticsLabel('Enable auto advance'), findsOneWidget);
    });

    testWidgets('uses disable semantics when enabled', (tester) async {
      await tester.pumpWidget(buildSubject(isEnabled: true));

      expect(find.bySemanticsLabel('Disable auto advance'), findsOneWidget);
    });

    testWidgets('renders translated semantics for Spanish locale', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(isEnabled: false, locale: const Locale('es')),
      );

      expect(
        find.bySemanticsLabel('Activar avance automático'),
        findsOneWidget,
      );
    });

    testWidgets('tints the double-play icon green when enabled', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(isEnabled: true));

      final icons = tester
          .widgetList<DivineIcon>(find.byType(DivineIcon))
          .toList();

      expect(icons, hasLength(2));
      expect(icons.every((icon) => icon.color == VineTheme.vineGreen), isTrue);
    });
  });
}
