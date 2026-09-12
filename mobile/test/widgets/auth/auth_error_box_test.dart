// ABOUTME: Tests for AuthErrorBox widget
// ABOUTME: Verifies error message rendering and styling

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/auth/auth_error_box.dart';

void main() {
  group(AuthErrorBox, () {
    Widget createTestWidget({required String message}) {
      return MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: VineTheme.theme,
        home: Scaffold(body: AuthErrorBox(message: message)),
      );
    }

    group('renders', () {
      testWidgets('displays error message text', (tester) async {
        await tester.pumpWidget(
          createTestWidget(message: 'Something went wrong'),
        );

        expect(find.text('Something went wrong'), findsOneWidget);
      });

      testWidgets('centers the error text', (tester) async {
        await tester.pumpWidget(createTestWidget(message: 'Centered error'));

        final text = tester.widget<Text>(find.text('Centered error'));
        expect(text.textAlign, equals(TextAlign.center));
      });

      testWidgets('uses error color for text', (tester) async {
        await tester.pumpWidget(createTestWidget(message: 'Error text'));

        final text = tester.widget<Text>(find.text('Error text'));
        expect(text.style?.color, equals(VineTheme.error));
      });

      testWidgets('displays different error messages', (tester) async {
        await tester.pumpWidget(
          createTestWidget(message: 'Invalid email address'),
        );

        expect(find.text('Invalid email address'), findsOneWidget);
        expect(find.text('Something went wrong'), findsNothing);
      });
    });
  });
}
