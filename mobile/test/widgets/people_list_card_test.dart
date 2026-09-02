// ABOUTME: Tests for PeopleListCard: member collage tiles, count badge,
// ABOUTME: text block, and tap handling.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/widgets/people_list_card.dart';
import 'package:openvine/widgets/vine_cached_image.dart';
import 'package:riverpod/misc.dart' show Override;

import '../helpers/test_provider_overrides.dart';

UserList _userList({List<String> pubkeys = const [], String? description}) =>
    UserList(
      id: 'people-1',
      name: 'Divine Team',
      description: description,
      pubkeys: pubkeys,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

UserProfile _profile(String pubkey, {String? picture}) => UserProfile(
  pubkey: pubkey,
  rawData: const {},
  createdAt: DateTime(2026),
  eventId: 'e' * 64,
  picture: picture,
);

void main() {
  group(PeopleListCard, () {
    Widget buildSubject({
      required UserList userList,
      List<Override> profileOverrides = const [],
    }) {
      return ProviderScope(
        overrides: [...getStandardTestOverrides(), ...profileOverrides],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 185,
              child: PeopleListCard(userList: userList, onTap: () {}),
            ),
          ),
        ),
      );
    }

    Finder glyphTiles() => find.byWidgetPredicate(
      (widget) => widget is DivineIcon && widget.icon == DivineIconName.user,
    );

    testWidgets('renders title, description, and member count', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          userList: _userList(
            pubkeys: ['a' * 64, 'b' * 64, 'c' * 64, 'd' * 64],
            description: 'Curated by the team.',
          ),
          profileOverrides: [
            for (final pubkey in ['a' * 64, 'b' * 64, 'c' * 64, 'd' * 64])
              fetchUserProfileProvider(
                pubkey,
              ).overrideWith((ref) async => _profile(pubkey)),
          ],
        ),
      );
      await tester.pump();

      expect(find.text('Divine Team'), findsOneWidget);
      expect(find.text('Curated by the team.'), findsOneWidget);
      // The badge shows the full member count, not the tile count.
      expect(find.text('4'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is DivineIcon && widget.icon == DivineIconName.users,
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders accent glyph tiles when profiles have no picture', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(
          userList: _userList(pubkeys: ['a' * 64]),
          profileOverrides: [
            fetchUserProfileProvider(
              'a' * 64,
            ).overrideWith((ref) async => _profile('a' * 64)),
          ],
        ),
      );
      await tester.pump();

      // One member without a picture plus two empty slots: all three collage
      // tiles fall back to the glyph placeholder.
      expect(glyphTiles(), findsNWidgets(3));
      expect(find.byType(VineCachedImage), findsNothing);
    });

    testWidgets('renders the profile picture when one resolves', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(
          userList: _userList(pubkeys: ['a' * 64]),
          profileOverrides: [
            fetchUserProfileProvider('a' * 64).overrideWith(
              (ref) async =>
                  _profile('a' * 64, picture: 'https://example.com/a.jpg'),
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(VineCachedImage), findsOneWidget);
      expect(glyphTiles(), findsNWidgets(2));
    });

    testWidgets('paints the Figma seam structure over the collage', (
      tester,
    ) async {
      // Container outline 2, large tile right 2, and the two small tiles
      // splitting the horizontal seam as bottom 1 / top 1.
      await tester.pumpWidget(
        buildSubject(
          userList: _userList(pubkeys: ['a' * 64]),
          profileOverrides: [
            fetchUserProfileProvider(
              'a' * 64,
            ).overrideWith((ref) async => _profile('a' * 64)),
          ],
        ),
      );
      await tester.pump();

      final seams = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .where((box) => box.position == DecorationPosition.foreground)
          .map((box) => (box.decoration as BoxDecoration).border)
          .whereType<Border>()
          .toList();

      final surface = VineTheme.darkColors.surface;
      bool only(BorderSide side, double width) =>
          side.width == width && side.color == surface;

      expect(
        seams.any(
          (b) =>
              only(b.top, 2) &&
              only(b.bottom, 2) &&
              only(b.left, 2) &&
              only(b.right, 2),
        ),
        isTrue,
        reason: 'collage container outline',
      );
      expect(
        seams.any(
          (b) =>
              only(b.right, 2) &&
              b.top == BorderSide.none &&
              b.bottom == BorderSide.none &&
              b.left == BorderSide.none,
        ),
        isTrue,
        reason: 'large tile right seam',
      );
      expect(
        seams.any(
          (b) =>
              only(b.bottom, 1) &&
              b.top == BorderSide.none &&
              b.left == BorderSide.none &&
              b.right == BorderSide.none,
        ),
        isTrue,
        reason: 'top small tile bottom half-seam',
      );
      expect(
        seams.any(
          (b) =>
              only(b.top, 1) &&
              b.bottom == BorderSide.none &&
              b.left == BorderSide.none &&
              b.right == BorderSide.none,
        ),
        isTrue,
        reason: 'bottom small tile top half-seam',
      );
    });

    testWidgets('invokes onTap when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [...getStandardTestOverrides()],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SizedBox(
                width: 185,
                child: PeopleListCard(
                  userList: _userList(),
                  onTap: () => tapped = true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Divine Team'));
      expect(tapped, isTrue);
    });
  });
}
