import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/user_avatar.dart';

void main() {
  group('renders', () {
    testWidgets('UserAvatar renders without error when image URL is invalid', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: UserAvatar(
              imageUrl: 'https://invalid.example.invalid/nonexistent.jpg',
              name: 'Foo',
              size: 40,
            ),
          ),
        ),
      );

      // Allow widget to build - async image loading happens in background
      await tester.pump();

      // Widget should render without throwing errors
      expect(find.byType(UserAvatar), findsOneWidget);
    });

    testWidgets('UserAvatar renders without error when no imageUrl provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: UserAvatar(name: 'Test User', size: 40)),
        ),
      );

      await tester.pump();

      // Widget should render without throwing errors
      expect(find.byType(UserAvatar), findsOneWidget);
    });

    testWidgets('UserAvatar renders without error with empty imageUrl', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: UserAvatar(imageUrl: '', name: 'Test User', size: 40),
          ),
        ),
      );

      await tester.pump();

      // Widget should render without throwing errors
      expect(find.byType(UserAvatar), findsOneWidget);
    });

    testWidgets('UserAvatar has rounded border decoration', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: UserAvatar(size: 40)),
        ),
      );

      await tester.pump();

      // Should find ClipRRect for the rounded border
      expect(find.byType(ClipRRect), findsOneWidget);
      expect(find.byType(UserAvatar), findsOneWidget);
    });
  });
}
