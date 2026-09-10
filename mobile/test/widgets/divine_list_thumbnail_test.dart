// ABOUTME: Tests for DivineListThumbnail: the shared card scaffold plus its
// ABOUTME: two media variants (video fan, people collage), seams, badges,
// ABOUTME: fixed-height footer, and tap handling.

import 'dart:async';

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
import 'package:openvine/widgets/user_avatar.dart';
import 'package:openvine/widgets/video_thumbnail_widget.dart';
import 'package:openvine/widgets/vine_cached_image.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:skeletonizer/skeletonizer.dart';

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
    bool isPublic = true,
  }) {
    return CuratedList(
      id: id,
      name: name,
      description: description,
      imageUrl: imageUrl,
      videoEventIds: videoEventIds,
      thumbnailUrls: thumbnailUrls,
      isPublic: isPublic,
      createdAt: now,
      updatedAt: now,
    );
  }

  final l10n = lookupAppLocalizations(const Locale('en'));

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

  UserProfile profileFor(
    String pubkey, {
    String? picture,
    String? displayName,
  }) => UserProfile(
    pubkey: pubkey,
    rawData: const {},
    createdAt: DateTime(2026),
    eventId: 'e' * 64,
    picture: picture,
    displayName: displayName,
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
                    eventId: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
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
        // The reserved two-line box stays (see the equal-height test below),
        // but nothing is rendered into it — asserting only the title would
        // still pass if the box held a literal "null" or a stray empty Text.
        expect(find.byType(LinkifiedText), findsNothing);
      });

      testWidgets('renders no description text when empty', (tester) async {
        await tester.pumpWidget(
          buildSubject(curatedList: createList(description: '')),
        );

        expect(find.text('Test List'), findsOneWidget);
        expect(find.byType(LinkifiedText), findsNothing);
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
        // All 5 slots stay regardless of how many thumbnails arrive: 5 slot
        // clips plus the outer media-block clip, same count as the
        // no-thumbnails case above. `findsAtLeastN` on DecoratedBox could
        // not catch a drop to 3 slots — each slot builds two of them.
        expect(find.byType(ClipRRect), findsNWidgets(6));
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

      testWidgets('activates through the semantics owner', (tester) async {
        // A pointer tap proves hit testing; assistive tech activates the
        // node's own action, which the excluded subtree cannot supply.
        final handle = tester.ensureSemantics();
        var tapped = false;
        await tester.pumpWidget(
          buildSubject(curatedList: createList(), onTap: () => tapped = true),
        );

        final node = tester.getSemantics(find.byType(DivineListThumbnail));
        node.owner!.performAction(node.id, SemanticsAction.tap);
        await tester.pump();

        expect(tapped, isTrue);
        handle.dispose();
      });

      testWidgets('speaks the description as the hint', (tester) async {
        await tester.pumpWidget(
          buildSubject(
            curatedList: createList(description: 'Best skate clips'),
          ),
        );

        final card = tester
            .getSemantics(find.byType(DivineListThumbnail))
            .getSemanticsData();
        expect(card.hint, equals('Best skate clips'));
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

      testWidgets('speaks the name and video count as one label', (
        tester,
      ) async {
        // The subtree is excluded, so the title is not read twice with a
        // bare badge count in between.
        await tester.pumpWidget(
          buildSubject(
            curatedList: createList(
              name: 'My Playlist',
              videoEventIds: ['v1', 'v2', 'v3'],
            ),
          ),
        );

        final card = tester
            .getSemantics(find.byType(DivineListThumbnail))
            .getSemanticsData();
        expect(card.label, 'My Playlist, ${l10n.listVideoCount(3)}');
      });

      testWidgets('marks a private list with a lock and says so', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildSubject(
            curatedList: createList(name: 'Just Mine', isPublic: false),
          ),
        );

        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is DivineIcon &&
                widget.icon == DivineIconName.lockSimple,
          ),
          findsOneWidget,
        );
        final card = tester
            .getSemantics(find.byType(DivineListThumbnail))
            .getSemanticsData();
        expect(
          card.label,
          'Just Mine, ${l10n.listVisibilityPrivate}, '
          '${l10n.listVideoCount(0)}',
        );
      });

      testWidgets('shows no lock on a public list', (tester) async {
        await tester.pumpWidget(
          buildSubject(curatedList: createList(name: 'Shared')),
        );

        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is DivineIcon &&
                widget.icon == DivineIconName.lockSimple,
          ),
          findsNothing,
        );
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

      testWidgets('names its members when the list has no description', (
        tester,
      ) async {
        final alice = 'a' * 64;
        final bob = 'b' * 64;
        await tester.pumpWidget(
          buildSubject(
            userList: createUserList(pubkeys: [alice, bob]),
            profileOverrides: [
              fetchUserProfileProvider(alice).overrideWith(
                (ref) async => profileFor(alice, displayName: 'Alice'),
              ),
              fetchUserProfileProvider(bob).overrideWith(
                (ref) async => profileFor(bob, displayName: 'Bob'),
              ),
            ],
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(
          find.text('Alice${l10n.listMemberNamesSeparator}Bob'),
          findsOneWidget,
        );
      });

      testWidgets('keeps its own description over member names', (
        tester,
      ) async {
        final alice = 'a' * 64;
        await tester.pumpWidget(
          buildSubject(
            userList: createUserList(pubkeys: [alice], description: 'Crew'),
            profileOverrides: [
              fetchUserProfileProvider(alice).overrideWith(
                (ref) async => profileFor(alice, displayName: 'Alice'),
              ),
            ],
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('Crew'), findsOneWidget);
        expect(find.textContaining('Alice'), findsNothing);
      });

      testWidgets('names a member without a profile the usual way', (
        tester,
      ) async {
        final ghost = 'f' * 64;
        await tester.pumpWidget(
          buildSubject(
            userList: createUserList(pubkeys: [ghost]),
            profileOverrides: [
              fetchUserProfileProvider(ghost).overrideWith((ref) async => null),
            ],
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(
          find.text(UserProfile.defaultDisplayNameFor(ghost)),
          findsOneWidget,
        );
      });

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
        final card = tester
            .getSemantics(find.byType(DivineListThumbnail))
            .getSemanticsData();
        expect(card.label, 'Divine Team, ${l10n.listMemberCount(4)}');
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

      testWidgets('inks placeholder glyphs from the avatar palette', (
        tester,
      ) async {
        // The member keeps the accent UserAvatar gives that pubkey, and the
        // glyph takes that accent's figure ink — never white, which reads
        // at 1.16:1 on the lime fill.
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

        final expected = userAvatarPlaceholderColors(
          userAvatarToneForSeed('a' * 64),
        );
        final glyphColors = tester
            .widgetList<DivineIcon>(glyphTiles())
            .map((icon) => icon.color)
            .toList();
        expect(glyphColors, contains(expected.figure));
        expect(glyphColors, isNot(contains(VineTheme.whiteText)));
        final tileFills = tester
            .widgetList<ColoredBox>(find.byType(ColoredBox))
            .map((box) => box.color);
        expect(tileFills, contains(expected.base));
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

  group(DivineListThumbnailSkeleton, () {
    Widget sideBySide({required Widget card, required Widget skeleton}) {
      return ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 180, child: card),
                SizedBox(
                  width: 180,
                  child: Skeletonizer(ignoreContainers: true, child: skeleton),
                ),
              ],
            ),
          ),
        ),
      );
    }

    testWidgets('the video silhouette stands as tall as a video card', (
      tester,
    ) async {
      // Rows stay level when placeholders give way to cards only if the
      // silhouette reserves the same media box and footer.
      await tester.pumpWidget(
        sideBySide(
          card: DivineListThumbnail.videos(
            curatedList: createList(description: 'Two lines\nof it'),
            onTap: () {},
          ),
          skeleton: const DivineListThumbnailSkeleton.videos(),
        ),
      );

      final card = tester.getSize(find.byType(DivineListThumbnail));
      final skeleton = tester.getSize(find.byType(DivineListThumbnailSkeleton));
      expect(card.height, greaterThan(0));
      expect(skeleton.height, equals(card.height));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the people silhouette stands as tall as a people card', (
      tester,
    ) async {
      await tester.pumpWidget(
        sideBySide(
          card: DivineListThumbnail.people(
            userList: createUserList(description: 'Two lines\nof it'),
            onTap: () {},
          ),
          skeleton: const DivineListThumbnailSkeleton.people(),
        ),
      );

      final card = tester.getSize(find.byType(DivineListThumbnail));
      final skeleton = tester.getSize(find.byType(DivineListThumbnailSkeleton));
      expect(card.height, greaterThan(0));
      expect(skeleton.height, equals(card.height));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the video silhouette fans out five slots', (tester) async {
      await tester.pumpWidget(
        sideBySide(
          card: const SizedBox(),
          skeleton: const DivineListThumbnailSkeleton.videos(),
        ),
      );

      final slots = find.descendant(
        of: find.byType(DivineListThumbnailSkeleton),
        matching: find.byType(Positioned),
      );
      expect(slots, findsNWidgets(5));
    });

    testWidgets('the people silhouette tiles the three-slot collage', (
      tester,
    ) async {
      await tester.pumpWidget(
        sideBySide(
          card: const SizedBox(),
          skeleton: const DivineListThumbnailSkeleton.people(),
        ),
      );

      // A tile bone is a filled box that rounds an outer corner of the
      // collage; the skeletonizer paints bones outside the frame's clip,
      // so the four corners have to come from the tiles themselves.
      const corner = Radius.circular(16);
      bool isTileBone(Widget w) =>
          w is DecoratedBox &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).color != null &&
          [
            (w.decoration as BoxDecoration).borderRadius,
          ].whereType<BorderRadius>().any(
            (r) =>
                r.topLeft == corner ||
                r.topRight == corner ||
                r.bottomLeft == corner ||
                r.bottomRight == corner,
          );
      final tiles = find.descendant(
        of: find.byType(DivineListThumbnailSkeleton),
        matching: find.byWidgetPredicate(isTileBone),
      );
      expect(tiles, findsNWidgets(3));
      final radii = tester
          .widgetList<DecoratedBox>(tiles)
          .map((w) => (w.decoration as BoxDecoration).borderRadius!)
          .cast<BorderRadius>()
          .toList();
      expect(radii.where((r) => r.topLeft == corner), hasLength(1));
      expect(radii.where((r) => r.bottomLeft == corner), hasLength(1));
      expect(radii.where((r) => r.topRight == corner), hasLength(1));
      expect(radii.where((r) => r.bottomRight == corner), hasLength(1));
      // The large tile keeps the collage's Figma split.
      final large = tester.getSize(tiles.first);
      final media = tester.getSize(
        find
            .descendant(
              of: find.byType(DivineListThumbnailSkeleton),
              matching: find.byType(AspectRatio),
            )
            .first,
      );
      expect(large.width / media.width, closeTo(0.661, 0.01));
    });
  });

  group('pending thumbnails', () {
    Widget pending({
      required Widget child,
      List<Override> overrides = const [],
    }) {
      return ProviderScope(
        overrides: [...getStandardTestOverrides(), ...overrides],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SizedBox(width: 185, child: child)),
        ),
      );
    }

    // The skeletonizer widget is built through a subclass, so it has to be
    // found by predicate rather than by type.
    Finder skeletonizer() => find.byWidgetPredicate((w) => w is Skeletonizer);

    // A flat placeholder slot clips its image; a bone has no clip. The
    // frame itself adds one clip around the whole fan.
    Finder slotClips() => find.descendant(
      of: find.byType(DivineListThumbnail),
      matching: find.byType(ClipRRect),
    );

    testWidgets('shimmers the fan slots a video could still fill', (
      tester,
    ) async {
      await tester.pumpWidget(
        pending(
          child: DivineListThumbnail.videos(
            curatedList: createList(videoEventIds: const ['a', 'b', 'c']),
            thumbnailsPending: true,
            onTap: () {},
          ),
        ),
      );

      expect(
        tester.widget<Skeletonizer>(skeletonizer()).enabled,
        isTrue,
      );
      // Three of five slots are bones; the two the list can never fill
      // keep their flat placeholder.
      expect(slotClips(), findsNWidgets(1 + 2));
    });

    testWidgets('keeps every slot flat once thumbnails are resolved', (
      tester,
    ) async {
      await tester.pumpWidget(
        pending(
          child: DivineListThumbnail.videos(
            curatedList: createList(videoEventIds: const ['a', 'b', 'c']),
            onTap: () {},
          ),
        ),
      );

      expect(
        tester.widget<Skeletonizer>(skeletonizer()).enabled,
        isFalse,
      );
      expect(slotClips(), findsNWidgets(1 + 5));
    });

    testWidgets('shimmers a collage tile while the member profile loads', (
      tester,
    ) async {
      final member = 'c' * 64;
      final neverResolves = Completer<UserProfile?>();
      await tester.pumpWidget(
        pending(
          overrides: [
            fetchUserProfileProvider(
              member,
            ).overrideWith((ref) => neverResolves.future),
          ],
          child: DivineListThumbnail.people(
            userList: createUserList(pubkeys: [member]),
            onTap: () {},
          ),
        ),
      );
      await tester.pump();

      expect(
        tester.widget<Skeletonizer>(skeletonizer()).enabled,
        isTrue,
      );
      // Exactly the member's tile is a bone: the one filled box with a
      // rounded collage corner.
      const corner = Radius.circular(16);
      final bones = find.descendant(
        of: find.byType(DivineListThumbnail),
        matching: find.byWidgetPredicate(
          (w) =>
              w is DecoratedBox &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).color != null &&
              ((w.decoration as BoxDecoration).borderRadius as BorderRadius?)
                      ?.topLeft ==
                  corner,
        ),
      );
      expect(bones, findsOneWidget);
    });

    testWidgets('settles the tile once the profile is known', (tester) async {
      final member = 'c' * 64;
      await tester.pumpWidget(
        pending(
          overrides: [
            fetchUserProfileProvider(
              member,
            ).overrideWith((ref) async => profileFor(member)),
          ],
          child: DivineListThumbnail.people(
            userList: createUserList(pubkeys: [member]),
            onTap: () {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(
        tester.widget<Skeletonizer>(skeletonizer()).enabled,
        isFalse,
      );
    });
  });
}
