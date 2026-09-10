// ABOUTME: Tests that the app theme handed to pro_image_editor's own chrome
// ABOUTME: carries the app's colours across the material_ui type boundary.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' as material_ui;
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/utils/pro_editor_theme.dart';

void main() {
  group('proEditorTheme', () {
    /// Builds the editor theme the way a screen does: from the theme in scope.
    Future<material_ui.ThemeData> resolve(
      WidgetTester tester,
      ThemeData theme,
    ) async {
      late material_ui.ThemeData resolved;
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              resolved = proEditorTheme(context);
              return const SizedBox();
            },
          ),
        ),
      );
      return resolved;
    }

    testWidgets('carries a dark app theme across', (tester) async {
      final source = ThemeData(
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00FF9C),
          surface: Color(0xFF032017),
        ),
      );

      final resolved = await resolve(tester, source);

      expect(resolved.brightness, equals(Brightness.dark));
      expect(resolved.colorScheme.brightness, equals(Brightness.dark));
      expect(resolved.colorScheme.primary, equals(const Color(0xFF00FF9C)));
      expect(resolved.colorScheme.surface, equals(const Color(0xFF032017)));
      expect(
        resolved.scaffoldBackgroundColor,
        equals(source.scaffoldBackgroundColor),
      );
    });

    // Divine ships both appearances, so the editor's chrome has to follow the
    // one in scope rather than a compiled-in default.
    testWidgets('carries a light app theme across', (tester) async {
      final source = ThemeData(
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF006B45),
          surface: Color(0xFFFBFDF8),
        ),
      );

      final resolved = await resolve(tester, source);

      expect(resolved.brightness, equals(Brightness.light));
      expect(resolved.colorScheme.brightness, equals(Brightness.light));
      expect(resolved.colorScheme.primary, equals(const Color(0xFF006B45)));
      expect(resolved.colorScheme.surface, equals(const Color(0xFFFBFDF8)));
    });

    testWidgets('carries every colour role the editor paints with', (
      tester,
    ) async {
      const scheme = ColorScheme.dark(
        primary: Color(0xFF111111),
        onPrimary: Color(0xFF222222),
        secondary: Color(0xFF333333),
        onSecondary: Color(0xFF444444),
        error: Color(0xFF555555),
        onError: Color(0xFF666666),
        surface: Color(0xFF777777),
        onSurface: Color(0xFF888888),
      );

      final resolved = await resolve(
        tester,
        ThemeData(brightness: Brightness.dark, colorScheme: scheme),
      );

      expect(resolved.colorScheme.primary, equals(scheme.primary));
      expect(resolved.colorScheme.onPrimary, equals(scheme.onPrimary));
      expect(resolved.colorScheme.secondary, equals(scheme.secondary));
      expect(resolved.colorScheme.onSecondary, equals(scheme.onSecondary));
      expect(resolved.colorScheme.error, equals(scheme.error));
      expect(resolved.colorScheme.onError, equals(scheme.onError));
      expect(resolved.colorScheme.surface, equals(scheme.surface));
      expect(resolved.colorScheme.onSurface, equals(scheme.onSurface));
    });
  });
}
