// ABOUTME: Widget tests for the special profile checkmark badge.
// ABOUTME: Covers the badge's accessible label and non-interactive behavior.

import 'dart:ui' as ui;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/config/official_accounts.dart';
import 'package:openvine/constants/og_beta_testers.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/special_profile_checkmark.dart';

Widget _buildSubject() {
  // The explanation sheet is pause-aware, so it reads the overlay-visibility
  // notifier off the enclosing ProviderScope.
  return const ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: Center(child: SpecialProfileCheckmark())),
    ),
  );
}

void main() {
  group('visibility', () {
    test('only team members on the OG Beta Tester roster get a checkmark', () {
      for (final pubkey in ogBetaTesterPubkeys) {
        expect(
          shouldShowSpecialProfileCheckmark(pubkey),
          kDivineTeamPubkeys.contains(pubkey),
          reason: 'checkmark visibility must be derived from team membership',
        );
      }
    });
  });

  group('renders', () {
    testWidgets('renders an accessible non-tappable checkmark', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_buildSubject());
      final l10n = lookupAppLocalizations(const Locale('en'));
      final data = tester
          .getSemantics(find.byType(SpecialProfileCheckmark))
          .getSemanticsData();

      expect(data.label, l10n.profileBadgeCheckmarkTitle);
      expect(data.hasAction(ui.SemanticsAction.tap), isFalse);
      expect(
        find.byWidgetPredicate(
          (w) => w is DivineIcon && w.icon == DivineIconName.check,
        ),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  group('interactions', () {
    testWidgets('does not open explanation sheet when tapped inline', (
      tester,
    ) async {
      await tester.pumpWidget(_buildSubject());
      final l10n = lookupAppLocalizations(const Locale('en'));

      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is DivineIcon && w.icon == DivineIconName.check,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(l10n.profileBadgeCheckmarkBody), findsNothing);
      expect(find.text(l10n.commonClose), findsNothing);
    });
  });
}
