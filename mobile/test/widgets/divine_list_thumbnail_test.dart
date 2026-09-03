// ABOUTME: Tests for DivineListThumbnail: the shared card scaffold plus its
// ABOUTME: two media variants (video fan, people collage), seams, badges,
// ABOUTME: fixed-height footer, and tap handling.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' hide AspectRatio;
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/widgets/divine_list_thumbnail.dart';
import 'package:openvine/widgets/linkified_text/linkified_text_widgets.dart';
import 'package:openvine/widgets/video_thumbnail_widget.dart';
import 'package:openvine/widgets/vine_cached_image.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../helpers/test_provider_overrides.dart';

void main() {
  final now = DateTime(2025, 6, 15);

  CuratedList createList({
    String id = 'test-list',
    String name = 'Test List',
    String? description,
    String? imageUrl,
    List<String> videoEventIds = const [],
    List<String> thumbnailUrls = const [],
  }) {
    return CuratedList(
      id: id,
      name: name,
      description: description,
      imageUrl: imageUrl,
      videoEventIds: videoEventIds,
      thumbnailUrls: thumbnailUrls,
      createdAt: now,
      updatedAt: now,
    );
  }

  UserList createUserList({
    List<String> pubkeys = const [],
    String? description,
  }) => UserList(
    id: 'people-1',
    name: 'Divine Team',
    description: description,
    pubkeys: pubkeys,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  UserProfile profileFor(String pubkey, {String? picture}) => UserProfile(
    pubkey: pubkey,
    rawData: const {},
    createdAt: DateTime(2026),
    eventId: 'e' * 64,
    picture: picture,
  );

  group(DivineListThumbnail, () {
    group('videos variant', () {
      Widget buildSubject({
        required CuratedList curatedList,
        VoidCallback? onTap,
        List<Override> overrides = const [],
      }) {
        return ProviderScope(
          overrides: overrides,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 200,
                  height: 300,
                  child: SingleChildScrollView(
                    child: DivineListThumbnail.videos(
                      curatedList: curatedList,
                      onTap: onTap ?? () {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }

      testWidgets('renders title', (tester) async {
        await tester.pumpWidget(
          buildSubject(curatedList: createList(name: 'Dance Moves')),
        );

        expect(find.text('Dance Moves'), findsOneWidget);
      });

      testWidgets('renders description when present', (tester) async {
        await tester.pumpWidget(
          buildSubject(curatedList: createList(description: 'Great videos')),
        );

        expect(find.text('Great videos'), findsOneWidget);
      });

      testWidgets('linkifies Nostr profile references in descriptions', (
        tester,
      ) async {
        const mentionedPubkey =
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
        final mentionedNpub = NostrKeyUtils.encodePubKey(mentionedPubkey);

        await tester.pumpWidget(
          buildSubject(
            curatedList: createList(description: 'by nostr:$mentionedNpub'),
            overrides: [
              userProfileReactiveProvider(mentionedPubkey).overrideWith(
                (ref) => Stream.value(
                  UserProfile(
                    pubkey: mentionedPubkey,
                    displayName: 'Alice',
                    rawData: const {},
                    createdAt: DateTime(2026),
                    eventId:
                        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
                  ),
                ),
              ),
            ],
          ),
        );
        await tester.pump();

        expect(find.byType(LinkifiedText), findsOneWidget);
        expect(find.text('by @Alice', findRichText: true), findsOneWidget);
        expect(find.textContaining('nostr:$mentionedNpub'), findsNothing);
      });

      testWidgets('renders links in the plain description style', (
        tester,
      ) async {
        // A URL in a preview is plain muted text — the whole card is the
        // tap target, so no accent color, weight, or size change.
        await tester.pumpWidget(
          buildSubject(
            curatedList: createList(
              description: 'DIY Merch: https://example.org/shop',
            ),
          ),
        );

        final richText = tester.widget<RichText>(
          find.descendant(
            of: find.byType(LinkifiedText),
            matching: find.byType(RichText),
          ),
        );
        final spanStyles = <TextStyle>[];
        richText.text.visitChildren((span) {
          if (span is TextSpan && span.style != null) {
            spanStyles.add(span.style!);
          }
          return true;
        });

        expect(spanStyles, isNotEmpty);
        for (final style in spanStyles) {
          expect(style.color, isNot(VineTheme.info));
          expect(style.fontSize, VineTheme.bodySmallFont().fontSize);
        }
      });

      testWidgets('renders no description text when null', (tester) async {
        await tester.pumpWidget(buildSubject(curatedList: createList()));

        expect(find.text('Test List'), findsOneWidget);
      });

      testWidgets('renders no description text when empty', (tester) async {
        await tester.pumpWidget(
          buildSubject(curatedList: createList(description: '')),
        );

        expect(find.text('Test List'), findsOneWidget);
      });

      testWidgets('keeps the same card height with and without a description', (
        tester,
      ) async {
        // The footer reserves a fixed two-line description box, so
        // equal-width cards align into rows in the gallery columns.
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: DivineListThumbnail.videos(
                        curatedList: createList(
                          id: 'with-description',
                          name: 'SLOP \u{1F51D} TEN',
                          description:
                              'A description long enough to wrap onto a '
                              'second line and then keep going past it.',
                        ),
                        onTap: () {},
                      ),
                    ),
                    Expanded(
                      child: DivineListThumbnail.videos(
                        curatedList: createList(id: 'without-description'),
                        onTap: () {},
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        final sizes = tester
            .widgetList(find.byType(DivineListThumbnail))
            .map((card) => tester.getSize(find.byWidget(card)))
            .toList();
        expect(sizes, hasLength(2));
        expect(sizes[0].height, sizes[1].height);
      });

      testWidgets('paints the fan seams over loaded thumbnails', (
        tester,
      ) async {
        // Regression: a background-positioned border sits under the
        // full-bleed thumbnail image, so populated cards lost their seams
        // while empty placeholder cards kept them.
        await tester.pumpWidget(
          buildSubject(
            curatedList: createList(
              videoEventIds: ['v1'],
              thumbnailUrls: ['https://example.com/t.jpg'],
            ),
          ),
        );
        await tester.pump();

        final seams = tester
            .widgetList<DecoratedBox>(find.byType(DecoratedBox))
            .where(
              (box) =>
                  box.position == DecorationPosition.foreground &&
                  (box.decoration as BoxDecoration).border != null,
            )
            .toList();
        expect(seams, isNotEmpty);
        final border =
            ((seams.first.decoration as BoxDecoration).border! as Border).top;
        expect(border.color, VineTheme.darkColors.surface);
      });

      testWidgets('renders the video count badge', (tester) async {
        await tester.pumpWidget(
          buildSubject(
            curatedList: createList(videoEventIds: ['v1', 'v2', 'v3']),
          ),
        );

        expect(find.text('3'), findsOneWidget);
      });

      testWidgets('renders a formatted count for large numbers', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildSubject(
            curatedList: createList(
              videoEventIds: List.generate(9100, (i) => 'v$i'),
            ),
          ),
        );

        expect(find.text('9.1K'), findsOneWidget);
      });

      testWidgets(
        'renders 5 card slots with no images when thumbnailUrls is empty',
        (tester) async {
          await tester.pumpWidget(buildSubject(curatedList: createList()));

          // 5 slot clips plus the outer media-block clip.
          expect(find.byType(ClipRRect), findsNWidgets(6));
          expect(find.byType(PassiveAuthThumbnailImage), findsNothing);
        },
      );

      testWidgets('renders $PassiveAuthThumbnailImage for each thumbnail URL '
          'while keeping all 5 card slots', (tester) async {
        await tester.pumpWidget(
          buildSubject(
            curatedList: createList(
              thumbnailUrls: [
                'https://example.com/thumb1.jpg',
                'https://example.com/thumb2.jpg',
              ],
              videoEventIds: ['v1', 'v2', 'v3'],
            ),
          ),
        );

        expect(find.byType(PassiveAuthThumbnailImage), findsNWidgets(2));
        for (final image in tester.widgetList<PassiveAuthThumbnailImage>(
          find.byType(PassiveAuthThumbnailImage),
        )) {
          expect(image.alignment, equals(Alignment.center));
        }
        // 5 card slots + 1 count badge remain regardless of how many
        // thumbnails are supplied.
        expect(find.byType(DecoratedBox), findsAtLeastNWidgets(6));
      });

      testWidgets('announces each card as a button', (tester) async {
        await tester.pumpWidget(
          buildSubject(curatedList: createList(name: 'Dance Moves')),
        );

        final card = tester
            .getSemantics(find.byType(DivineListThumbnail))
            .getSemanticsData();
        expect(
          card.flagsCollection.isButton,
          isTrue,
          reason: 'a list card is a tap target, not a label',
        );
        expect(card.hasAction(SemanticsAction.tap), isTrue);
      });

      testWidgets('calls onTap when tapped', (tester) async {
        var tapped = false;
        await tester.pumpWidget(
          buildSubject(curatedList: createList(), onTap: () => tapped = true),
        );

        await tester.tap(find.text('Test List'));
        await tester.pumpAndSettle();

        expect(tapped, isTrue);
      });

      testWidgets('has semantic label from list name', (tester) async {
        await tester.pumpWidget(
          buildSubject(curatedList: createList(name: 'My Playlist')),
        );

        final semantics = tester.widgetList<Semantics>(find.byType(Semantics));
        final cardSemantics = semantics.where(
          (s) => s.properties.label == 'My Playlist',
        );
        expect(cardSemantics, hasLength(1));
      });
    });

    group('people variant', () {
      Widget buildSubject({
        required UserList userList,
        VoidCallback? onTap,
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
                child: DivineListThumbnail.people(
                  userList: userList,
                  onTap: onTap ?? () {},
                ),
              ),
            ),
          ),
        );
      }

      Finder glyphTiles() => find.byWidgetPredicate(
        (widget) => widget is DivineIcon && widget.icon == DivineIconName.user,
      );

      testWidgets('renders title, description, and member count', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildSubject(
            userList: createUserList(
              pubkeys: ['a' * 64, 'b' * 64, 'c' * 64, 'd' * 64],
              description: 'Curated by the team.',
            ),
            profileOverrides: [
              for (final pubkey in ['a' * 64, 'b' * 64, 'c' * 64, 'd' * 64])
                fetchUserProfileProvider(
                  pubkey,
                ).overrideWith((ref) async => profileFor(pubkey)),
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
            userList: createUserList(pubkeys: ['a' * 64]),
            profileOverrides: [
              fetchUserProfileProvider(
                'a' * 64,
              ).overrideWith((ref) async => profileFor('a' * 64)),
            ],
          ),
        );
        await tester.pump();

        // One member without a picture plus two empty slots: all three
        // collage tiles fall back to the glyph placeholder.
        expect(glyphTiles(), findsNWidgets(3));
        expect(find.byType(VineCachedImage), findsNothing);
      });

      testWidgets('renders the profile picture when one resolves', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildSubject(
            userList: createUserList(pubkeys: ['a' * 64]),
            profileOverrides: [
              fetchUserProfileProvider('a' * 64).overrideWith(
                (ref) async =>
                    profileFor('a' * 64, picture: 'https://example.com/a.jpg'),
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
            userList: createUserList(pubkeys: ['a' * 64]),
            profileOverrides: [
              fetchUserProfileProvider(
                'a' * 64,
              ).overrideWith((ref) async => profileFor('a' * 64)),
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
          buildSubject(
            userList: createUserList(),
            onTap: () => tapped = true,
          ),
        );
        await tester.pump();

        await tester.tap(find.text('Divine Team'));
        expect(tapped, isTrue);
      });
    });
  });
}
