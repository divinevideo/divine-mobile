// ABOUTME: Regression tests for shared Explore tab label resolution.
// ABOUTME: Covers shell titles plus sanitising of server-supplied tab copy.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:openvine/blocs/explore_tabs/explore_tabs_cubit.dart';
import 'package:openvine/l10n/generated/app_localizations_en.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/explore/explore_tab_labels.dart';

FeaturedTabConfig _configWithSponsor(Map<String, String> disclosureLabel) {
  return FeaturedTabConfig(
    id: 'ft_a1b2c3d4',
    slug: 'featured-slug',
    label: const {'default': 'Featured'},
    disclosureLabel: disclosureLabel,
    startsAt: null,
    endsAt: null,
    enabled: true,
    hasContent: true,
  );
}

void main() {
  group('labelForExploreTabName', () {
    final l10n = AppLocalizationsEn();

    test('returns tab-bar labels for every canonical tab name', () {
      const state = ExploreTabsState(
        classicsAvailable: true,
        forYouAvailable: true,
        appsAvailable: true,
      );

      expect(
        state.tabNames.map((name) => labelForExploreTabName(l10n, name)),
        const [
          'Classics',
          'New',
          'Popular',
          'Categories',
          'For You',
          'Lists',
          'Badges',
          'Integrated Apps',
        ],
      );
    });

    test('returns feed-mode shell titles for every canonical tab name', () {
      const state = ExploreTabsState(
        classicsAvailable: true,
        forYouAvailable: true,
        appsAvailable: true,
      );

      expect(
        state.tabNames.map(
          (name) => labelForExploreTabName(l10n, name, shellTitle: true),
        ),
        const [
          'Classics',
          'New Videos',
          'Trending',
          'Categories',
          'For You',
          'Lists',
          'Badges',
          'Integrated Apps',
        ],
      );
    });
  });

  group('labelForExploreTabName featured tab', () {
    late AppLocalizations en;

    setUp(() {
      en = lookupAppLocalizations(const Locale('en'));
    });

    test('reads the compiled label, not the server one', () {
      expect(
        labelForExploreTabName(en, exploreFeaturedTabName),
        equals(en.exploreTabFeatured),
      );
    });

    test('translates with the rest of the bar', () {
      // The server pins its own label to the English word, so echoing it
      // would have shipped English to every locale.
      final es = lookupAppLocalizations(const Locale('es'));
      final label = labelForExploreTabName(es, exploreFeaturedTabName);

      expect(label, equals(es.exploreTabFeatured));
      expect(label, isNot(equals(en.exploreTabFeatured)));
    });

    test('leaves the other compiled tab labels untouched', () {
      expect(
        labelForExploreTabName(en, exploreListsTabName),
        equals(en.exploreTabLists),
      );
    });
  });

  group('sanitizeFeaturedTabText', () {
    test('clamps an overlong disclosure marker', () {
      final sanitized = sanitizeFeaturedTabText('x' * 80);

      expect(sanitized.characters.length, equals(featuredTabLabelMaxLength));
      expect(sanitized.endsWith('…'), isTrue);
    });

    test('keeps a short marker verbatim', () {
      expect(sanitizeFeaturedTabText('  Ad  '), equals('Ad'));
    });

    test('returns empty when nothing renderable survives', () {
      expect(sanitizeFeaturedTabText('\n\t '), isEmpty);
    });

    test('honours a caller-supplied shorter limit', () {
      final sanitized = sanitizeFeaturedTabText(
        'x' * 80,
        maxLength: featuredTabPillMaxLength,
      );

      expect(
        sanitized.characters.length,
        equals(featuredTabPillMaxLength),
      );
    });

    test('keeps text at exactly the limit intact', () {
      final exact = 'x' * featuredTabLabelMaxLength;

      expect(sanitizeFeaturedTabText(exact), equals(exact));
    });

    test('clamps without splitting a compound emoji', () {
      const family = '\u{1F468}\u200d\u{1F469}\u200d\u{1F467}\u200d\u{1F466}';
      final sanitized = sanitizeFeaturedTabText(family * 40);

      expect(sanitized, startsWith(family));
      expect(sanitized, isNot(contains('\uFFFD')));
      expect(sanitized, endsWith('\u2026'));
    });

    test('collapses newlines a grapheme count would let through', () {
      // Tab lays out at a fixed height, so extra lines overflow the bar even
      // though four graphemes are well inside the clamp.
      expect(sanitizeFeaturedTabText('a\nb\nc\nd'), equals('a b c d'));
    });

    test('strips bidi overrides', () {
      final sanitized = sanitizeFeaturedTabText('Spot\u202elight');

      expect(sanitized, equals('Spot light'));
      expect(sanitized.contains('\u202e'), isFalse);
    });

    test('returns empty for control-only copy', () {
      expect(sanitizeFeaturedTabText('\n\u202e\t'), isEmpty);
    });
  });

  group('featuredTabSponsorName', () {
    test('resolves and sanitises the active locale entry', () {
      final config = _configWithSponsor(const {'default': '  Acme Bikes '});

      expect(featuredTabSponsorName(config, 'en'), equals('Acme Bikes'));
      expect(featuredTabIsSponsored(config, 'en'), isTrue);
    });

    test('resolves no sponsor for a locale the map does not cover', () {
      // The pill and the partnership line must agree per locale: a map that
      // only resolves elsewhere means this viewer sees no sponsor at all.
      final config = _configWithSponsor(const {'pt': 'Acme Bicicletas'});

      expect(featuredTabSponsorName(config, 'en'), isNull);
      expect(featuredTabIsSponsored(config, 'en'), isFalse);
      expect(featuredTabSponsorName(config, 'pt'), equals('Acme Bicicletas'));
      expect(featuredTabIsSponsored(config, 'pt'), isTrue);
    });

    test('resolves no sponsor for control-only copy', () {
      final config = _configWithSponsor(const {'default': '\n\u202e\t'});

      expect(featuredTabSponsorName(config, 'en'), isNull);
      expect(featuredTabIsSponsored(config, 'en'), isFalse);
    });

    test('resolves no sponsor when the field is absent', () {
      final config = _configWithSponsor(const {});

      expect(featuredTabSponsorName(config, 'en'), isNull);
      expect(featuredTabIsSponsored(config, 'en'), isFalse);
    });
  });
}
