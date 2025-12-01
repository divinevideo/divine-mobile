// ABOUTME: Comprehensive widget test for ALL settings screens scaffold structure
// ABOUTME: Ensures all settings screens use consistent Vine theme (green AppBar, black background)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/screens/relay_settings_screen.dart';
import 'package:openvine/screens/blossom_settings_screen.dart';
import 'package:openvine/theme/vine_theme.dart';

void main() {
  group('All Settings Screens Scaffold Consistency', () {
    testWidgets('RelaySettingsScreen has Vine green AppBar', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: RelaySettingsScreen())),
      );

      final appBarFinder = find.byType(AppBar);
      expect(appBarFinder, findsOneWidget);

      final AppBar appBar = tester.widget(appBarFinder);
      expect(
        appBar.backgroundColor,
        equals(VineTheme.vineGreen),
        reason: 'RelaySettingsScreen AppBar should be Vine green',
      );
      expect(appBar.foregroundColor, equals(VineTheme.whiteText));
    });

    testWidgets('BlossomSettingsScreen has Vine green AppBar', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: BlossomSettingsScreen())),
      );

      final appBarFinder = find.byType(AppBar);
      expect(appBarFinder, findsOneWidget);

      final AppBar appBar = tester.widget(appBarFinder);
      expect(
        appBar.backgroundColor,
        equals(VineTheme.vineGreen),
        reason: 'BlossomSettingsScreen AppBar should be Vine green',
      );
      expect(appBar.foregroundColor, equals(VineTheme.whiteText));
    });

    testWidgets('All settings screens have black background', (tester) async {
      final screensToTest = [
        const RelaySettingsScreen(),
        const BlossomSettingsScreen(),
      ];

      for (final screen in screensToTest) {
        await tester.pumpWidget(
          ProviderScope(child: MaterialApp(home: screen)),
        );

        final scaffoldFinder = find.byType(Scaffold);
        expect(scaffoldFinder, findsOneWidget);

        final Scaffold scaffold = tester.widget(scaffoldFinder);
        expect(
          scaffold.backgroundColor,
          equals(Colors.black),
          reason: '${screen.runtimeType} should have black background',
        );
      }
    });
  });
}
