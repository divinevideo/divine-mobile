// ABOUTME: Widget tests for the placeholder Divine Confirmation screen.
// ABOUTME: Pins the disabled buy button and the store-only note for builds
// ABOUTME: that cannot buy.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/supporter_providers.dart';
import 'package:openvine/screens/verify/verify_confirmation_screen.dart';

import '../../helpers/l10n.dart';

Future<void> _pump(WidgetTester tester, {required bool canBuy}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        supporterStoreBillingAvailableProvider.overrideWithValue(canBuy),
      ],
      child: buildLocalizedWidget(const VerifyConfirmationPage()),
    ),
  );
  await tester.pump();
}

// The hero title repeats the app bar title, so look in the body only.
Finder _inBody(String text) =>
    find.descendant(of: find.byType(ListView), matching: find.text(text));

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  group(VerifyConfirmationPage, () {
    testWidgets('shows the hero, what is included, and a disabled Coming '
        'soon button', (tester) async {
      await _pump(tester, canBuy: true);

      expect(_inBody(l10n.verifyConfirmationHeroTitle), findsOneWidget);
      expect(find.text(l10n.verifyConfirmationHeroBody), findsOneWidget);
      expect(find.text(l10n.verifyConfirmationIncludedTitle), findsOneWidget);
      expect(find.text(l10n.verifyConfirmationIncludedSignIn), findsOneWidget);
      expect(find.text(l10n.verifyConfirmationSmallPrint), findsOneWidget);
      expect(find.text(l10n.verifyConfirmationStoreOnly), findsNothing);

      final buy = tester.widget<DivineButton>(
        find.widgetWithText(DivineButton, l10n.verifyConfirmationComingSoon),
      );
      expect(buy.onPressed, isNull);
    });

    testWidgets('restore is shown and disabled on a build that can buy', (
      tester,
    ) async {
      await _pump(tester, canBuy: true);

      final restore = tester.widget<DivineButton>(
        find.widgetWithText(DivineButton, l10n.supporterRestorePurchases),
      );
      expect(restore.onPressed, isNull);
    });

    testWidgets('buy and restore read as unavailable buttons', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, canBuy: true);

      for (final label in [
        l10n.verifyConfirmationBuySemantic,
        l10n.verifyConfirmationRestoreSemantic,
      ]) {
        expect(
          tester.getSemantics(find.bySemanticsLabel(label)),
          matchesSemantics(
            label: label,
            isButton: true,
            hasEnabledState: true,
          ),
        );
      }
      handle.dispose();
    });

    testWidgets('a build that cannot buy shows the store note instead of '
        'buttons [P1]', (tester) async {
      await _pump(tester, canBuy: false);

      expect(find.text(l10n.verifyConfirmationStoreOnly), findsOneWidget);
      expect(find.text(l10n.verifyConfirmationComingSoon), findsNothing);
      expect(find.text(l10n.supporterRestorePurchases), findsNothing);
      // The pitch still renders; only the buy controls are gated.
      expect(_inBody(l10n.verifyConfirmationHeroTitle), findsOneWidget);
    });
  });
}
