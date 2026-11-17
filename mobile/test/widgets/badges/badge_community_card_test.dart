import 'package:badge_repository/badge_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart' show UserProfile;
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/widgets/badges/badge_community_card.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:openvine/widgets/vine_cached_image.dart';

import '../../helpers/decoded_images.dart';
import '../../helpers/test_provider_overrides.dart';

void main() {
  group(BadgeCommunityCard, () {
    group('renders', () {
      for (final suppliedName in ['', ' \n ']) {
        testWidgets(
          'unnamed public badge stays visible and accessible (${suppliedName.length})',
          (tester) async {
            final semantics = tester.ensureSemantics();
            final issuer = '2'.padLeft(64, '0');
            final definition = Nip58BadgeDefinition(
              event: Event(issuer, EventKind.badgeDefinition, const [], ''),
              coordinate: '30009:$issuer:loop-makers',
              dTag: 'loop-makers',
              name: suppliedName,
            );
            await tester.pumpWidget(
              testMaterialApp(
                home: Scaffold(
                  body: SizedBox(
                    width: 200,
                    child: BadgeCommunityCard(
                      definition: definition,
                      onTap: () {},
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(find.text('loop-makers'), findsOneWidget);
            expect(
              find.bySemanticsLabel(
                'loop-makers, ${UserProfile.defaultDisplayNameFor(issuer)}',
              ),
              findsOneWidget,
            );
            semantics.dispose();
          },
        );
      }
      testWidgets('names an issuer without a profile instead of showing hex', (
        tester,
      ) async {
        final issuer = '2'.padLeft(64, '0');
        final definition = Nip58BadgeDefinition(
          event: Event(issuer, EventKind.badgeDefinition, const [], ''),
          coordinate: '30009:$issuer:loop-makers',
          dTag: 'loop-makers',
          name: 'Loop makers',
        );
        await tester.pumpWidget(
          testMaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 200,
                child: BadgeCommunityCard(
                  definition: definition,
                  onTap: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.text(issuer), findsNothing);
        expect(
          find.text(UserProfile.defaultDisplayNameFor(issuer)),
          findsOneWidget,
        );
      });

      testWidgets('announces the issuer with the badge name', (tester) async {
        final semantics = tester.ensureSemantics();
        final issuer = '2'.padLeft(64, '0');
        final definition = Nip58BadgeDefinition(
          event: Event(issuer, EventKind.badgeDefinition, const [], ''),
          coordinate: '30009:$issuer:loop-makers',
          dTag: 'loop-makers',
          name: 'Loop makers',
        );
        await tester.pumpWidget(
          testMaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 200,
                child: BadgeCommunityCard(
                  definition: definition,
                  onTap: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(
          find.bySemanticsLabel(
            'Loop makers, ${UserProfile.defaultDisplayNameFor(issuer)}',
          ),
          findsOneWidget,
        );
        semantics.dispose();
      });

      testWidgets('renders nothing for a vanished issuer', (tester) async {
        final issuer = '2'.padLeft(64, '0');
        final definition = Nip58BadgeDefinition(
          event: Event(issuer, EventKind.badgeDefinition, const [], ''),
          coordinate: '30009:$issuer:loop-makers',
          dTag: 'loop-makers',
          name: 'Loop makers',
        );
        await tester.pumpWidget(
          testMaterialApp(
            additionalOverrides: [
              profileVanishedProvider(issuer).overrideWithValue(true),
            ],
            home: Scaffold(
              body: SizedBox(
                width: 200,
                child: BadgeCommunityCard(
                  definition: definition,
                  onTap: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.text('Loop makers'), findsNothing);
        expect(find.byType(InkWell), findsNothing);
      });

      testWidgets('shows at most three members and skips vanished ones', (
        tester,
      ) async {
        final issuer = '2'.padLeft(64, '0');
        final members = [for (var i = 3; i < 7; i++) '$i'.padLeft(64, '0')];
        final definition = Nip58BadgeDefinition(
          event: Event(issuer, EventKind.badgeDefinition, const [], ''),
          coordinate: '30009:$issuer:loop-makers',
          dTag: 'loop-makers',
          name: 'Loop makers',
        );
        await tester.pumpWidget(
          testMaterialApp(
            additionalOverrides: [
              profileVanishedProvider(members[1]).overrideWithValue(true),
            ],
            home: Scaffold(
              body: SizedBox(
                width: 200,
                child: BadgeCommunityCard(
                  definition: definition,
                  memberPubkeys: members,
                  onTap: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        final faces = tester.widgetList<UserAvatar>(
          find.byWidgetPredicate((w) => w is UserAvatar && w.size == 28),
        );
        expect(faces.map((face) => face.placeholderSeed), [
          members[0],
          members[2],
        ]);
      });

      for (final size in [const Size(1200, 1200), const Size(1200, 1800)]) {
        testWidgets(
          'preserves ${size.width}:${size.height} artwork through bounded decoding',
          (tester) async {
            final issuer = '2'.padLeft(64, '0');
            final definition = Nip58BadgeDefinition(
              event: Event(issuer, EventKind.badgeDefinition, const [], ''),
              coordinate: '30009:$issuer:artwork',
              dTag: 'artwork',
              name: 'Loop Makers',
              imageUrl: 'https://example.com/badge-${size.height}.png',
            );
            await pumpWithDecodedImages(
              tester,
              testMaterialApp(
                home: Scaffold(
                  body: SizedBox(
                    width: 200,
                    child: BadgeCommunityCard(
                      definition: definition,
                      onTap: () {},
                    ),
                  ),
                ),
              ),
              imageSize: size,
              images: find.descendant(
                of: find.byType(VineCachedImage),
                matching: find.byType(Image),
              ),
            );
            final raw = tester.widget<RawImage>(
              find.descendant(
                of: find.byType(VineCachedImage),
                matching: find.byType(RawImage),
              ),
            );
            expect(raw.image, isNotNull);
            expect(
              raw.image!.width / raw.image!.height,
              closeTo(size.width / size.height, .01),
            );
            expect(
              raw.image!.width,
              lessThanOrEqualTo(200 * tester.view.devicePixelRatio),
            );
            expect(tester.takeException(), isNull);
          },
        );
      }
    });
  });
}
