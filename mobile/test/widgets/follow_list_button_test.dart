// ABOUTME: Widget tests for FollowListButton, the Follow/Following pill in a
// ABOUTME: list screen's app bar.

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
