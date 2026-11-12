// ABOUTME: Widget tests for FollowListButton, the Follow/Following button in a
// ABOUTME: list header's action row, or a compact pill in an app bar.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/follow_list_button.dart';

void main() {
  group(FollowListButton, () {
    final l10n = lookupAppLocalizations(const Locale('en'));

    Future<void> pumpButton(
      WidgetTester tester, {
      required bool isFollowing,
      bool isBusy = false,
      bool compact = false,
      VoidCallback? onPressed,
    }) {
      return tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: FollowListButton(
                isFollowing: isFollowing,
                isBusy: isBusy,
                compact: compact,
                onPressed: onPressed ?? () {},
              ),
            ),
          ),
        ),
      );
    }

    group('renders', () {
      testWidgets('invites a follow for a list that is not followed', (
        tester,
      ) async {
        await pumpButton(tester, isFollowing: false);

        expect(find.text(l10n.listFollowButton), findsOneWidget);
        expect(find.text(l10n.listFollowingButton), findsNothing);
      });

      testWidgets('says Following for a followed list', (tester) async {
        await pumpButton(tester, isFollowing: true);

        expect(find.text(l10n.listFollowingButton), findsOneWidget);
        expect(find.text(l10n.listFollowButton), findsNothing);
      });

      testWidgets('Follow is primary and Following is secondary', (
        tester,
      ) async {
        await pumpButton(tester, isFollowing: false);
        expect(
          tester.widget<DivineButton>(find.byType(DivineButton)).type,
          DivineButtonType.primary,
        );

        await pumpButton(tester, isFollowing: true);
        expect(
          tester.widget<DivineButton>(find.byType(DivineButton)).type,
          DivineButtonType.secondary,
        );
      });

      testWidgets('fills its slot by default', (tester) async {
        await pumpButton(tester, isFollowing: false);

        final button = tester.widget<DivineButton>(find.byType(DivineButton));
        expect(button.expanded, isTrue);
        expect(button.size, DivineButtonSize.base);
      });

      testWidgets('is a small pill when compact', (tester) async {
        await pumpButton(tester, isFollowing: false, compact: true);

        final button = tester.widget<DivineButton>(find.byType(DivineButton));
        expect(button.expanded, isFalse);
        expect(button.size, DivineButtonSize.small);
      });
    });

    group('interactions', () {
      testWidgets('reports a tap', (tester) async {
        var taps = 0;
        await pumpButton(tester, isFollowing: false, onPressed: () => taps++);

        await tester.tap(find.byType(DivineButton));

        expect(taps, equals(1));
      });

      testWidgets('ignores taps while a follow is in flight', (tester) async {
        var taps = 0;
        await pumpButton(
          tester,
          isFollowing: false,
          isBusy: true,
          onPressed: () => taps++,
        );

        await tester.tap(find.byType(DivineButton), warnIfMissed: false);

        expect(taps, equals(0));
      });
    });
  });
}
