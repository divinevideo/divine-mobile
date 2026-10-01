// ABOUTME: Tests the E2E welcome-screen helpers against both welcome layouts:
// ABOUTME: a device that has signed in before labels its buttons differently.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';

import '../../integration_test/helpers/navigation_helpers.dart';

/// Stands in for the welcome screen: one tappable label per entry in
/// [labels], replaced by a registration field once any of them is tapped.
class _FakeWelcome extends StatefulWidget {
  const _FakeWelcome({required this.labels, required this.onTap});

  final List<String> labels;
  final ValueChanged<String> onTap;

  @override
  State<_FakeWelcome> createState() => _FakeWelcomeState();
}

class _FakeWelcomeState extends State<_FakeWelcome> {
  var _showForm = false;

  @override
  Widget build(BuildContext context) {
    if (_showForm) return const DivineAuthTextField();
    return Column(
      children: [
        for (final label in widget.labels)
          GestureDetector(
            onTap: () {
              widget.onTap(label);
              setState(() => _showForm = true);
            },
            child: Text(label),
          ),
      ],
    );
  }
}

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  Future<List<String>> pumpWelcome(
    WidgetTester tester,
    List<String> labels,
  ) async {
    final tapped = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: VineTheme.theme,
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: _FakeWelcome(labels: labels, onTap: tapped.add),
        ),
      ),
    );
    return tapped;
  }

  group('navigateToCreateAccount', () {
    testWidgets('taps the new-user label on a fresh install', (tester) async {
      final tapped = await pumpWelcome(tester, [
        l10n.authCreateNewAccount,
        l10n.authSignInDifferentAccount,
      ]);

      await navigateToCreateAccount(tester);

      expect(tapped, equals([l10n.authCreateNewAccount]));
    });

    testWidgets('taps the shorter label on the returning-user layout', (
      tester,
    ) async {
      final tapped = await pumpWelcome(tester, [
        l10n.authUseAnotherAccount,
        l10n.authCreateNewAccountShort,
      ]);

      await navigateToCreateAccount(tester);

      expect(tapped, equals([l10n.authCreateNewAccountShort]));
    });
  });

  group('navigateToLoginOptions', () {
    testWidgets('taps the new-user label on a fresh install', (tester) async {
      final tapped = await pumpWelcome(tester, [
        l10n.authCreateNewAccount,
        l10n.authSignInDifferentAccount,
      ]);

      await navigateToLoginOptions(tester);

      expect(tapped, equals([l10n.authSignInDifferentAccount]));
    });

    testWidgets('taps "use another account" on the returning-user layout', (
      tester,
    ) async {
      final tapped = await pumpWelcome(tester, [
        l10n.authUseAnotherAccount,
        l10n.authCreateNewAccountShort,
      ]);

      await navigateToLoginOptions(tester);

      expect(tapped, equals([l10n.authUseAnotherAccount]));
    });
  });
}
