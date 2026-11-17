import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/featured_tabs/featured_tabs_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/explore/widgets/featured_campaign_gate.dart';

void main() {
  const id = 'ft_a1b2c3d4';
  final l10n = lookupAppLocalizations(const Locale('en'));
  FeaturedTabConfig tab(String id) => FeaturedTabConfig(
    id: id,
    slug: 'featured-slug',
    label: const {'default': 'Featured'},
    startsAt: null,
    endsAt: null,
    enabled: true,
    hasContent: true,
  );
  Future<void> pump(WidgetTester tester, FeaturedTabsState state) =>
      tester.pumpWidget(
        MaterialApp(
          theme: VineTheme.theme,
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: FeaturedCampaignGate(
            feedId: id,
            state: state,
            child: const Text('Requested feed content'),
          ),
        ),
      );
  group('renders', () {
    testWidgets('loading settles and stays static with reduced motion', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: VineTheme.theme,
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: FeaturedCampaignGate(
              feedId: id,
              state: FeaturedTabsState(),
              child: Text('Requested feed content'),
            ),
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Requested feed content'), findsNothing);
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 1),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });

  group('navigation', () {
    testWidgets(
      'cold lookup waits for config; exact config opens and withdrawal clears content',
      (tester) async {
        await pump(tester, const FeaturedTabsState());
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Requested feed content'), findsNothing);
        await pump(
          tester,
          FeaturedTabsState(status: FeaturedTabsStatus.resolved, tab: tab(id)),
        );
        expect(find.text('Requested feed content'), findsOneWidget);
        await pump(
          tester,
          const FeaturedTabsState(status: FeaturedTabsStatus.resolved),
        );
        expect(find.text('Requested feed content'), findsNothing);
        expect(find.text(l10n.featuredFeedUnavailable), findsOneWidget);
        await pump(
          tester,
          FeaturedTabsState(
            status: FeaturedTabsStatus.resolved,
            tab: tab('other-id'),
          ),
        );
        expect(find.text('Requested feed content'), findsNothing);
        expect(find.text(l10n.featuredFeedUnavailable), findsOneWidget);
      },
    );
    testWidgets(
      'an exact feed is unavailable when disabled or its window ends',
      (
        tester,
      ) async {
        var now = DateTime.utc(2026, 11, 17, 12);
        FeaturedTabConfig config({bool enabled = true}) => FeaturedTabConfig(
          id: id,
          slug: 'featured-slug',
          label: const {'default': 'Featured'},
          startsAt: now.subtract(const Duration(hours: 1)),
          endsAt: DateTime.utc(2026, 11, 17, 12, 0, 1),
          enabled: enabled,
          hasContent: true,
        );
        Future<void> show(FeaturedTabConfig config) => tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: FeaturedCampaignGate(
              feedId: id,
              state: FeaturedTabsState(
                status: FeaturedTabsStatus.resolved,
                tab: config,
              ),
              now: () => now,
              child: const Text('Exact feed'),
            ),
          ),
        );
        await show(config(enabled: false));
        expect(find.text('Exact feed'), findsNothing);
        expect(find.text(l10n.featuredFeedUnavailable), findsOneWidget);
        await show(config());
        expect(find.text('Exact feed'), findsOneWidget);
        now = now.add(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('Exact feed'), findsNothing);
        expect(find.text(l10n.featuredFeedUnavailable), findsOneWidget);
      },
    );
  });
}
