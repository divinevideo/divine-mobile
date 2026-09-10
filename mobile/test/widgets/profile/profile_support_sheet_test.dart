import 'package:analytics/analytics.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/features/monetization/monetization_storefront_policy.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/profile/profile_support_sheet.dart';

void main() {
  tearDown(() {
    debugUsesAppleAppStoreTipPolicyOverride = null;
  });

  group('showProfileSupportSheet', () {
    testWidgets('uses tip-only copy and links on iOS storefronts', (
      tester,
    ) async {
      debugUsesAppleAppStoreTipPolicyOverride = true;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return TextButton(
                  onPressed: () => showProfileSupportSheet(
                    context: context,
                    links: [
                      const MonetizationLink(
                        provider: MonetizationLinkProvider.cashApp,
                        category: MonetizationLinkCategory.tip,
                        url: r'https://cash.app/$creator',
                        enabled: true,
                      ),
                      const MonetizationLink(
                        provider: MonetizationLinkProvider.patreon,
                        category: MonetizationLinkCategory.subscription,
                        url: 'https://www.patreon.com/creator',
                        enabled: true,
                      ),
                    ],
                    analytics: const NoOpAnalyticsEventSink(),
                  ),
                  child: const Text('Open'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.profileTipSheetTitle), findsOneWidget);
      expect(find.text(l10n.profileTipSheetBody), findsOneWidget);
      expect(find.text('Cash App'), findsOneWidget);
      expect(find.text('Patreon'), findsNothing);
      expect(find.text(l10n.profileSupportSubscriptionSection), findsNothing);
    });

    testWidgets('tapping a link row starts the outbound flow', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return TextButton(
                  onPressed: () => showProfileSupportSheet(
                    context: context,
                    links: [
                      const MonetizationLink(
                        provider: MonetizationLinkProvider.cashApp,
                        category: MonetizationLinkCategory.tip,
                        url: r'https://cash.app/$creator',
                        enabled: true,
                      ),
                    ],
                    analytics: const NoOpAnalyticsEventSink(),
                  ),
                  child: const Text('Open'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cash App'));
      await tester.pumpAndSettle();

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.messageExternalLinkDialogTitle), findsOneWidget);
    });
  });
}
