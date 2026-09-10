// ABOUTME: Widget tests for the featured tab's presence in the Explore bar.
// ABOUTME: Absent means absent — no placeholder, no disabled tab.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/explore_tabs/explore_tabs_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/explore/widgets/explore_tab_bar.dart';

FeaturedTabConfig _featured({
  Map<String, String> pillLabel = const {'default': 'Skate Week'},
  Map<String, String> disclosureLabel = const {},
}) {
  return FeaturedTabConfig(
    id: 'ft_a1b2c3d4',
    slug: 'featured-slug',
    // Pinned server-side to the English word; the client renders its own
    // translated label and ignores this.
    label: const {'default': 'Featured'},
    pillLabel: pillLabel,
    disclosureLabel: disclosureLabel,
    startsAt: null,
    endsAt: null,
    enabled: true,
    hasContent: true,
  );
}

/// English copy the bar renders through `context.l10n`.
///
/// Matching the literals instead would pass just as well against a bar that
/// hardcoded English, which is the regression these tests exist to catch.
final AppLocalizations _l10n = lookupAppLocalizations(const Locale('en'));

/// Colour the pill's text is painted in, which is what separates the
/// sponsored state from the unsponsored one.
Color? _pillTextColor(WidgetTester tester, String pillText) =>
    tester.widget<Text>(find.text(pillText)).style?.color;

void main() {
  group('$ExploreTabBar featured tab', () {
    Future<void> pumpBar(
      WidgetTester tester,
      ExploreTabsState tabsState, {
      Locale? locale,
      ThemeData? theme,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme ?? VineTheme.theme,
          locale: locale,
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DefaultTabController(
            length: tabsState.tabCount,
            child: Builder(
              builder: (context) => Scaffold(
                body: ExploreTabBar(
                  controller: DefaultTabController.of(context),
                  tabsState: tabsState,
                  onTap: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('renders no featured tab when none is configured', (
      tester,
    ) async {
      await pumpBar(tester, const ExploreTabsState());

      expect(find.text(_l10n.exploreTabFeatured), findsNothing);
      expect(find.byType(Tab), findsNWidgets(4));
    });

    testWidgets('renders the configured label as a tab', (tester) async {
      await pumpBar(tester, ExploreTabsState(featuredTab: _featured()));

      expect(find.text(_l10n.exploreTabFeatured), findsOneWidget);
    });

    testWidgets('renders tab labels in the active locale', (tester) async {
      // Resolving the English keys above cannot tell a localized bar from one
      // that hardcodes English, because the English ARB values are those very
      // words. A second locale is what separates them.
      final es = lookupAppLocalizations(const Locale('es'));
      await pumpBar(
        tester,
        ExploreTabsState(featuredTab: _featured()),
        locale: const Locale('es'),
      );

      expect(find.text(es.exploreTabFeatured), findsOneWidget);
      expect(find.text(es.exploreTabNew), findsOneWidget);
      expect(find.text(es.exploreTabPopular), findsOneWidget);
      expect(find.text(_l10n.exploreTabFeatured), findsNothing);
    });

    testWidgets('places the tab between New and Popular', (tester) async {
      await pumpBar(tester, ExploreTabsState(featuredTab: _featured()));

      final newX = tester.getCenter(find.text(_l10n.exploreTabNew)).dx;
      final featuredX = tester
          .getCenter(find.text(_l10n.exploreTabFeatured))
          .dx;
      final popularX = tester.getCenter(find.text(_l10n.exploreTabPopular)).dx;

      expect(featuredX, greaterThan(newX));
      expect(featuredX, lessThan(popularX));
    });

    testWidgets('renders the collection name in a pill beside the label', (
      tester,
    ) async {
      await pumpBar(tester, ExploreTabsState(featuredTab: _featured()));

      expect(find.text(_l10n.exploreTabFeatured), findsOneWidget);
      expect(find.text('Skate Week'), findsOneWidget);
    });

    testWidgets('renders no pill when the server sends no pill label', (
      tester,
    ) async {
      await pumpBar(
        tester,
        ExploreTabsState(featuredTab: _featured(pillLabel: const {})),
      );

      expect(find.text(_l10n.exploreTabFeatured), findsOneWidget);
      expect(find.text('Skate Week'), findsNothing);
    });

    testWidgets('tints the pill yellow when the collection is unsponsored', (
      tester,
    ) async {
      await pumpBar(tester, ExploreTabsState(featuredTab: _featured()));

      expect(
        _pillTextColor(tester, 'Skate Week'),
        equals(VineTheme.darkColors.accentChipYellow.onContainer),
      );
    });

    testWidgets(
      'tints the pill yellow when the sponsor resolves only for another locale',
      (tester) async {
        // A pink "sponsored" pill with no partnership line for this viewer is
        // the one combination that actively misleads, so sponsorship follows
        // the locale-resolved sponsor name, not the raw field.
        await pumpBar(
          tester,
          ExploreTabsState(
            featuredTab: _featured(
              disclosureLabel: const {'pt': 'Acme Bicicletas'},
            ),
          ),
        );

        expect(
          _pillTextColor(tester, 'Skate Week'),
          equals(VineTheme.darkColors.accentChipYellow.onContainer),
        );
      },
    );

    testWidgets('tints the pill from the active appearance, not the dark one', (
      tester,
    ) async {
      // The pill reads adaptive context.vineColors, so pinning only the dark
      // values would stay green if it were switched to VineTheme.darkColors —
      // pixel-identical in dark, and dark-on-dark in light.
      await pumpBar(
        tester,
        ExploreTabsState(featuredTab: _featured()),
        theme: VineTheme.lightTheme,
      );

      expect(
        VineTheme.lightColors.accentChipYellow.onContainer,
        isNot(VineTheme.darkColors.accentChipYellow.onContainer),
        reason: 'the appearances must differ for this test to mean anything',
      );
      expect(
        _pillTextColor(tester, 'Skate Week'),
        equals(VineTheme.lightColors.accentChipYellow.onContainer),
      );
    });

    testWidgets('tints the pill pink when a sponsor is configured', (
      tester,
    ) async {
      await pumpBar(
        tester,
        ExploreTabsState(
          featuredTab: _featured(
            disclosureLabel: const {'default': 'Acme Bikes'},
          ),
        ),
      );

      expect(
        _pillTextColor(tester, 'Skate Week'),
        equals(VineTheme.darkColors.accentChipPink.onContainer),
      );
    });

    testWidgets('speaks the sponsored state rather than relying on colour', (
      tester,
    ) async {
      // Disposed in a finally rather than an addTearDown: flutter_test runs
      // _verifySemanticsHandlesWereDisposed inside the test body, before any
      // teardown callback, so a deferred dispose reads as a leak. A bare
      // dispose after the expect would be skipped when the expect throws,
      // leaving semantics enabled for the rest of the merged isolate.
      final handle = tester.ensureSemantics();
      try {
        await pumpBar(
          tester,
          ExploreTabsState(
            featuredTab: _featured(
              disclosureLabel: const {'default': 'Acme Bikes'},
            ),
          ),
        );

        // Matched as a substring: Tab merges its children into one node, so
        // the pill's label arrives joined to the tab's own.
        expect(
          find.bySemanticsLabel(
            RegExp(
              RegExp.escape(
                _l10n.exploreFeaturedSponsoredPillSemanticLabel('Skate Week'),
              ),
            ),
          ),
          findsWidgets,
        );
      } finally {
        handle.dispose();
      }
    });

    testWidgets('truncates an overlong pill harder than the label', (
      tester,
    ) async {
      await pumpBar(
        tester,
        ExploreTabsState(
          featuredTab: _featured(pillLabel: {'default': 'x' * 40}),
        ),
      );

      // 16 graphemes, the last of which is the ellipsis.
      expect(find.text('${'x' * 15}…'), findsOneWidget);
    });

    testWidgets('lays out at the narrowest supported width', (tester) async {
      tester.view.physicalSize = const Size(320 * 3, 640 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await pumpBar(tester, ExploreTabsState(featuredTab: _featured()));

      expect(find.text(_l10n.exploreTabFeatured), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('drops the tab again when the configuration is cleared', (
      tester,
    ) async {
      await pumpBar(tester, ExploreTabsState(featuredTab: _featured()));
      expect(find.text(_l10n.exploreTabFeatured), findsOneWidget);

      await pumpBar(tester, const ExploreTabsState());

      expect(find.text(_l10n.exploreTabFeatured), findsNothing);
    });
  });
}
