// ABOUTME: Pins the shared account facts line and its recent-post boundary.
// ABOUTME: Uses an explicit clock and localized expectations.

import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/user_indicator_line.dart';

void main() {
  group(UserIndicatorLine, () {
    final now = DateTime.utc(2030, 3, 8, 12);
    final l10n = lookupAppLocalizations(const Locale('en'));

    Future<void> pumpLine(
      WidgetTester tester, {
      String? identifier,
      FollowRelationship relationship = FollowRelationship.none,
      bool isOgViner = false,
      int? videoCount,
      DateTime? lastPostedAt,
      Locale locale = const Locale('en'),
    }) => tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: UserIndicatorLine(
            identifier: identifier,
            relationship: relationship,
            isOgViner: isOgViner,
            videoCount: videoCount,
            lastPostedAt: lastPostedAt,
            now: now,
          ),
        ),
      ),
    );

    testWidgets('joins present parts in the existing search order', (
      tester,
    ) async {
      await pumpLine(
        tester,
        identifier: '@ada',
        relationship: FollowRelationship.mutual,
        isOgViner: true,
        videoCount: 18,
        lastPostedAt: now.subtract(const Duration(hours: 2)),
      );
      expect(
        find.text(
          '${l10n.socialProofMutual} · @ada · ${l10n.ogVinerBadgeLabel} · '
          '${l10n.searchUserVideoCount(18, '18')} · ${l10n.userRowPosted(l10n.timeAgo(l10n.timeShortHours(2)))}',
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders no text when all facts are absent', (tester) async {
      await pumpLine(tester);
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('omits an empty identifier and nonpositive count', (
      tester,
    ) async {
      await pumpLine(tester, identifier: '', videoCount: 0);
      expect(find.byType(Text), findsNothing);
      await pumpLine(tester, videoCount: -1);
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('each relationship renders alone', (tester) async {
      for (final (relationship, label) in [
        (FollowRelationship.mutual, l10n.socialProofMutual),
        (FollowRelationship.followsYou, l10n.socialProofFollowsYou),
        (FollowRelationship.youFollow, l10n.socialProofYouFollow),
      ]) {
        await pumpLine(tester, relationship: relationship);
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('identifier, OG, and positive count render independently', (
      tester,
    ) async {
      await pumpLine(tester, identifier: '@ada');
      expect(find.text('@ada'), findsOneWidget);
      await pumpLine(tester, isOgViner: true);
      expect(find.text(l10n.ogVinerBadgeLabel), findsOneWidget);
      await pumpLine(tester, videoCount: 1);
      expect(find.text(l10n.searchUserVideoCount(1, '1')), findsOneWidget);
    });

    testWidgets('Posted is hidden at exactly seven days and beyond', (
      tester,
    ) async {
      for (final age in [const Duration(days: 7), const Duration(days: 8)]) {
        await pumpLine(tester, lastPostedAt: now.subtract(age));
        expect(find.byType(Text), findsNothing);
      }
    });

    testWidgets('Posted is present immediately before seven days', (
      tester,
    ) async {
      await pumpLine(
        tester,
        lastPostedAt: now
            .subtract(const Duration(days: 7))
            .add(const Duration(seconds: 1)),
      );
      expect(
        find.text(l10n.userRowPosted(l10n.timeAgo(l10n.timeShortDays(6)))),
        findsOneWidget,
      );
    });

    testWidgets('Posted uses the explicit now and two-hour localized string', (
      tester,
    ) async {
      for (final locale in [const Locale('en'), const Locale('de')]) {
        final strings = lookupAppLocalizations(locale);
        await pumpLine(
          tester,
          locale: locale,
          lastPostedAt: now.subtract(const Duration(hours: 2)),
        );
        expect(
          find.text(
            strings.userRowPosted(strings.timeAgo(strings.timeShortHours(2))),
          ),
          findsOneWidget,
        );
      }
    });
  });
}
