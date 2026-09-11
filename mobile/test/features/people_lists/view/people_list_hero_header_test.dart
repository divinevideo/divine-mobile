import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/features/people_lists/view/people_list_hero_header.dart';
import 'package:openvine/features/people_lists/view/people_list_member_avatar.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';

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
}) async {
  await tester.pumpWidget(
    testProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
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
  );
  await tester.pump();
}

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  group(PeopleListHeroHeader, () {
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
