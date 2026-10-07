import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/features/people_lists/view/people_list_hero_header.dart';
import 'package:openvine/features/people_lists/view/people_list_member_avatar.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:riverpod/misc.dart' show Override;

import '../../../helpers/test_provider_overrides.dart';

// Full-length 64-char pubkeys — never truncate.
List<String> _members(int count) => [
  for (var i = 0; i < count; i++) i.toRadixString(16).padLeft(64, '0'),
];

Future<void> _pumpHeader(
  WidgetTester tester, {
  required List<String> previewPubkeys,
  required VoidCallback onViewAll,
  int memberCount = 3,
  String? description,
  int? totalVideos,
  double? totalLoops,
  double textScale = 1,
  TextDirection textDirection = TextDirection.ltr,
  List<Override> overrides = const [],
}) async {
  await tester.pumpWidget(
    testProviderScope(
      additionalOverrides: overrides,
      child: MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Directionality(
          textDirection: textDirection,
          child: Scaffold(
            body: SingleChildScrollView(
              child: PeopleListHeroHeader(
                name: 'Approved',
                memberCount: memberCount,
                previewPubkeys: previewPubkeys,
                onViewAll: onViewAll,
                description: description,
                totalVideos: totalVideos,
                totalLoops: totalLoops,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  group(PeopleListHeroHeader, () {
    testWidgets(
      'review regression View all does not overflow large text at narrow width',
      (tester) async {
        tester.view.physicalSize = const Size(320, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await _pumpHeader(
          tester,
          previewPubkeys: _members(3),
          onViewAll: () {},
          textScale: 3,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('review regression preview hides vanished photograph', (
      tester,
    ) async {
      final pubkey = _members(1).single;
      final profile = UserProfile(
        pubkey: pubkey,
        displayName: 'Old identity',
        picture: 'https://example.invalid/old.png',
        rawData: const {},
        createdAt: DateTime(2026),
        eventId: 'e' * 64,
      );
      await _pumpHeader(
        tester,
        previewPubkeys: [pubkey],
        onViewAll: () {},
        overrides: [
          userProfileReactiveProvider(pubkey)
              .overrideWith((ref) => Stream.value(profile)),
          profileVanishedProvider(pubkey).overrideWith((ref) => true),
        ],
      );
      await tester.pump();
      expect(
        tester
            .widget<PeopleListMemberAvatar>(find.byType(PeopleListMemberAvatar))
            .pictureUrl,
        isNull,
      );
    });

    testWidgets('review regression View all offers a 48dp tap target', (
      tester,
    ) async {
      await _pumpHeader(tester, previewPubkeys: _members(3), onViewAll: () {});
      expect(
        tester.getSize(find.byType(PeopleListMembersPreview)).height,
        greaterThanOrEqualTo(48),
      );
    });

    testWidgets('review regression list name is a heading', (tester) async {
      final handle = tester.ensureSemantics();

      await _pumpHeader(tester, previewPubkeys: _members(3), onViewAll: () {});
      try {
        expect(
          tester.getSemantics(find.text('Approved')).flagsCollection.isHeader,
          isTrue,
        );
      } finally {
        handle.dispose();
      }
    });

    group('renders', () {
      testWidgets('the name, every known figure and the description', (
        tester,
      ) async {
        await _pumpHeader(
          tester,
          previewPubkeys: _members(2),
          onViewAll: () {},
          memberCount: 33,
          description: 'Stories and events from those profiles.',
          totalVideos: 88,
          totalLoops: 89400000000,
        );

        expect(find.text('Approved'), findsOneWidget);
        expect(
          find.text('Stories and events from those profiles.'),
          findsOneWidget,
        );
        final stats = tester.widget<RichText>(
          find.byWidgetPredicate(
            (widget) =>
                widget is RichText &&
                widget.text.toPlainText().contains(l10n.listMemberCount(33)),
          ),
        );
        final line = stats.text.toPlainText();
        expect(line, contains(l10n.listVideoCount(88)));
        expect(line, contains('loops'));
        expect(line, contains(l10n.listStatsSeparator));
      });

      testWidgets('only the member count until stats arrive', (tester) async {
        await _pumpHeader(
          tester,
          previewPubkeys: _members(1),
          onViewAll: () {},
          memberCount: 4,
        );

        final stats = tester.widget<RichText>(
          find.byWidgetPredicate(
            (widget) =>
                widget is RichText &&
                widget.text.toPlainText().contains(l10n.listMemberCount(4)),
          ),
        );
        expect(stats.text.toPlainText(), equals(l10n.listMemberCount(4)));
      });

      testWidgets(
        'no members row when every member is hidden from the viewer',
        (tester) async {
          await _pumpHeader(tester, previewPubkeys: const [], onViewAll: () {});

          // The count stays list-wide; only the row into an empty roster goes.
          expect(
            find.byWidgetPredicate(
              (widget) =>
                  widget is RichText &&
                  widget.text.toPlainText().contains(l10n.listMemberCount(3)),
            ),
            findsOneWidget,
          );
          expect(find.byType(PeopleListMembersPreview), findsNothing);
          expect(find.text(l10n.peopleListsViewAllMembers), findsNothing);
        },
      );

      testWidgets('at most five piled avatars, best-ranked first', (
        tester,
      ) async {
        final ranked = _members(8);
        await _pumpHeader(
          tester,
          previewPubkeys: ranked,
          onViewAll: () {},
          memberCount: 8,
        );

        final avatars = tester
            .widgetList<PeopleListMemberAvatar>(
              find.byType(PeopleListMemberAvatar),
            )
            .map((avatar) => avatar.pubkey)
            .toSet();
        expect(avatars, equals(ranked.take(kPeopleListPreviewMembers).toSet()));
        // The first-ranked member is painted last, so it sits on top.
        expect(
          tester
              .widgetList<PeopleListMemberAvatar>(
                find.byType(PeopleListMemberAvatar),
              )
              .last
              .pubkey,
          equals(ranked.first),
        );
      });

      for (final direction in TextDirection.values) {
        testWidgets('the best-ranked avatar leads the pile in $direction', (
          tester,
        ) async {
          final ranked = _members(3);
          await _pumpHeader(
            tester,
            previewPubkeys: ranked,
            onViewAll: () {},
            textDirection: direction,
          );

          double leftOf(String pubkey) => tester
              .getTopLeft(
                find.byWidgetPredicate(
                  (widget) =>
                      widget is PeopleListMemberAvatar &&
                      widget.pubkey == pubkey,
                ),
              )
              .dx;

          expect(
            leftOf(ranked.first) < leftOf(ranked[1]),
            direction == TextDirection.ltr,
          );
          expect(
            leftOf(ranked[1]) < leftOf(ranked[2]),
            direction == TextDirection.ltr,
          );
        });
      }

      testWidgets('no description block when the list has none', (
        tester,
      ) async {
        await _pumpHeader(
          tester,
          previewPubkeys: _members(1),
          onViewAll: () {},
          description: '   ',
        );

        // Only the description Text is capped at three lines.
        expect(
          find.byWidgetPredicate(
            (widget) => widget is Text && widget.maxLines == 3,
          ),
          findsNothing,
        );
      });
    });

    group('interactions', () {
      testWidgets('tapping the members row asks for the full roster', (
        tester,
      ) async {
        var opened = 0;
        await _pumpHeader(
          tester,
          previewPubkeys: _members(3),
          onViewAll: () => opened++,
        );

        await tester.tap(find.text(l10n.peopleListsViewAllMembers));
        await tester.pump();
        expect(opened, equals(1));

        await tester.tap(find.byType(PeopleListMemberAvatar).first);
        await tester.pump();
        expect(opened, equals(2));
      });
    });
  });
}
