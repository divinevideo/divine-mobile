// ABOUTME: Widget tests for ProfileWebsiteRow — render, tap, snackbar on failure.

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/profile/profile_website_row.dart';

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: Center(child: child)),
);

void main() {
  group(ProfileWebsiteRow, () {
    testWidgets('displays URL with scheme stripped', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ProfileWebsiteRow(
            url: 'https://example.com',
            launcher: (_) async => true,
          ),
        ),
      );
      expect(find.text('example.com'), findsOneWidget);
    });

    testWidgets('strips www prefix from display URL', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ProfileWebsiteRow(
            url: 'https://www.example.com',
            launcher: (_) async => true,
          ),
        ),
      );
      expect(find.text('example.com'), findsOneWidget);
    });

    testWidgets('adds https scheme when missing before launching', (
      tester,
    ) async {
      Uri? launched;
      await tester.pumpWidget(
        _wrap(
          ProfileWebsiteRow(
            url: 'example.com/path',
            launcher: (uri) async {
              launched = uri;
              return true;
            },
          ),
        ),
      );
      await tester.tap(find.byType(InkWell));
      await tester.pumpAndSettle();
      expect(launched?.scheme, equals('https'));
      expect(launched?.host, equals('example.com'));
      expect(launched?.path, equals('/path'));
    });

    testWidgets('launches the URL on tap', (tester) async {
      Uri? launched;
      await tester.pumpWidget(
        _wrap(
          ProfileWebsiteRow(
            url: 'https://example.com',
            launcher: (uri) async {
              launched = uri;
              return true;
            },
          ),
        ),
      );
      await tester.tap(find.byType(InkWell));
      await tester.pumpAndSettle();
      expect(launched, equals(Uri.parse('https://example.com')));
    });

    testWidgets('shows snackbar when launcher returns false', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ProfileWebsiteRow(
            url: 'https://example.com',
            launcher: (_) async => false,
          ),
        ),
      );
      await tester.tap(find.byType(InkWell));
      await tester.pump();
      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.profileCouldNotOpenWebsite), findsOneWidget);
    });

    testWidgets('has semantic button label containing the URL', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ProfileWebsiteRow(
            url: 'https://example.com',
            launcher: (_) async => true,
          ),
        ),
      );
      expect(
        find.bySemanticsLabel(RegExp('example.com')),
        findsOneWidget,
      );
    });
  });
}
