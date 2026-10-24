// ABOUTME: Tests for the badge chips that float up through the profile banner
// ABOUTME: Covers the overlap-avoiding spawner and the reduced-motion fallback

import 'dart:math' as math;

import 'package:badge_repository/badge_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/widgets/profile/profile_header_widget.dart';

const _ownerHex =
    'a0b1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b1';
const _issuerHex =
    'f0e1d2c3b4a5f6e7d8c9b0a1f2e3d4c5b6a7f8e9d0c1b2a3f4e5d6c7b8a9f0e1';

/// The banner band on an iPhone-sized profile.
const _band = Size(402, 334);

ProfileBadgeViewData _badge(String name) {
  final coordinate = '30009:$_issuerHex:${name.toLowerCase()}';
  return ProfileBadgeViewData(
    badge: Nip58ProfileBadgeRef(
      definitionCoordinate: coordinate,
      awardEventId:
          '00000000000000000000000000000000000000000000000000000000000000aa',
    ),
    definition: Nip58BadgeDefinition(
      event: Event.fromJson({
        'id':
            '00000000000000000000000000000000000000000000000000000000000000bb',
        'pubkey': _issuerHex,
        'created_at': 1000,
        'kind': EventKind.badgeDefinition,
        'tags': [
          ['d', name.toLowerCase()],
          ['name', name],
        ],
        'content': '',
        'sig': '',
      }),
      coordinate: coordinate,
      dTag: name.toLowerCase(),
      name: name,
    ),
  );
}

double _coveredShare(Rect a, Rect b) {
  final overlap = a.intersect(b);
  if (overlap.width <= 0 || overlap.height <= 0) return 0;
  final smaller = math.min(a.width * a.height, b.width * b.height);
  return overlap.width * overlap.height / smaller;
}

void main() {
  group(FloatingBadgeField, () {
    group('advanceTo', () {
      test('never lets a chip cover more than maxOverlap of another', () {
        final field = FloatingBadgeField(badgeCount: 12);
        var worstShare = 0.0;
        var mostRising = 0;

        // Two minutes at the field's own 0.1s resolution.
        for (var tick = 0; tick <= 1200; tick++) {
          final seconds = tick / 10;
          field.advanceTo(seconds, _band, (_) => const Size(150, 32));
          final visible = [
            for (final badge in field.rising)
              if (badge.opacityAt(seconds) >= FloatingBadgeField.visibleOpacity)
                badge.rectAt(seconds, _band),
          ];
          mostRising = math.max(mostRising, visible.length);
          for (var i = 0; i < visible.length; i++) {
            for (var j = i + 1; j < visible.length; j++) {
              worstShare = math.max(
                worstShare,
                _coveredShare(visible[i], visible[j]),
              );
            }
          }
        }

        // A crowded banner, or the overlap bound would be met trivially.
        expect(mostRising, greaterThanOrEqualTo(5));
        expect(
          worstShare,
          lessThanOrEqualTo(FloatingBadgeField.maxOverlap + 0.01),
        );
      });

      test('retires chips once they leave the top of the band', () {
        final field = FloatingBadgeField(badgeCount: 1)
          ..advanceTo(0, _band, (_) => const Size(150, 32));
        expect(field.rising, hasLength(1));
        final first = field.rising.single;

        field.advanceTo(first.endsAt, _band, (_) => const Size(150, 32));

        expect(field.rising, isNot(contains(first)));
      });
    });

    group('slotCount', () {
      test('repeats a lone badge so the banner still drifts', () {
        expect(FloatingBadgeField(badgeCount: 1).slotCount, equals(6));
      });

      test('gives every badge a slot past the minimum', () {
        expect(FloatingBadgeField(badgeCount: 12).slotCount, equals(12));
      });
    });

    group('layerOf', () {
      test('spreads slots evenly across the depth layers', () {
        final perLayer = List.filled(FloatingBadgeField.depthLayers, 0);
        for (var slot = 0; slot < 12; slot++) {
          perLayer[FloatingBadgeField.layerOf(slot)]++;
        }

        expect(perLayer, everyElement(equals(3)));
      });
    });
  });

  group(FloatingBadge, () {
    group('scaleFor', () {
      test('shrinks layers further back', () {
        final scales = [
          for (var layer = 0; layer < FloatingBadgeField.depthLayers; layer++)
            FloatingBadge.scaleFor(layer),
        ];

        expect(scales.first, equals(1));
        for (var i = 1; i < scales.length; i++) {
          expect(scales[i], lessThan(scales[i - 1]));
        }
      });
    });
  });

  group(ProfileFloatingBadgesLayer, () {
    Widget buildLayer({
      bool disableAnimations = false,
      bool accessibleNavigation = false,
      double bannerWidth = 402,
      String badgeName = 'Glitter',
    }) {
      return ProviderScope(
        overrides: [
          profileAcceptedBadgesProvider(
            _ownerHex,
          ).overrideWith((ref) async => [_badge(badgeName)]),
        ],
        child: MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                disableAnimations: disableAnimations,
                accessibleNavigation: accessibleNavigation,
              ),
              child: Scaffold(
                body: SizedBox(
                  width: bannerWidth,
                  height: 334,
                  child: const ProfileFloatingBadgesLayer(userIdHex: _ownerHex),
                ),
              ),
            ),
          ),
        ),
      );
    }

    /// Advances the drift by [seconds], one frame at a time: a single long
    /// pump is clamped to one short step, like a hidden route coming back.
    Future<void> drift(WidgetTester tester, double seconds) async {
      for (var i = 0; i < seconds * 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets('floats chips into view once they enter', (tester) async {
      await tester.pumpWidget(buildLayer());
      await tester.pump();

      // The first chip enters fully transparent, so nothing is on screen yet.
      expect(find.text('Glitter').hitTestable(), findsNothing);

      await drift(tester, 2);

      expect(find.text('Glitter').hitTestable(), findsWidgets);
    });

    testWidgets('fits a long badge name inside its chip on a narrow banner', (
      tester,
    ) async {
      const name = 'Keeper of the Extremely Long and Winding Badge Name';
      await tester.pumpWidget(buildLayer(bannerWidth: 320, badgeName: name));
      await tester.pump();
      await drift(tester, 2);

      expect(find.text(name).hitTestable(), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders nothing under reduce motion', (tester) async {
      await tester.pumpWidget(buildLayer(disableAnimations: true));
      await tester.pump();
      await drift(tester, 2);

      expect(find.text('Glitter'), findsNothing);
    });

    testWidgets('renders nothing for a screen reader', (tester) async {
      await tester.pumpWidget(buildLayer(accessibleNavigation: true));
      await tester.pump();
      await drift(tester, 2);

      expect(find.text('Glitter'), findsNothing);
    });
  });
}
