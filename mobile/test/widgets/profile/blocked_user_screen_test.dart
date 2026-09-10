// ABOUTME: Tests for BlockedUserScreen widget
// ABOUTME: Verifies the placeholder renders and keeps the more-sheet reachable

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/profile/blocked_user_screen.dart';
import 'package:openvine/widgets/profile/unavailable_profile_actions.dart';

const _userIdHex =
    'c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4';

void main() {
  group(BlockedUserScreen, () {
    final l10n = lookupAppLocalizations(const Locale('en'));

    Widget buildSubject({VoidCallback? onBack}) {
      return ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BlockedUserScreen(
            onBack: onBack ?? () {},
            userIdHex: _userIdHex,
          ),
        ),
      );
    }

    testWidgets('displays unavailable message', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(
        find.text(l10n.profileBlockedAccountNotAvailable),
        findsOneWidget,
      );
    });

    testWidgets('displays back button in app bar', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.byType(DivineAppBarIconButton), findsOneWidget);
    });

    testWidgets('calls onBack when back button tapped', (tester) async {
      var backCalled = false;

      await tester.pumpWidget(buildSubject(onBack: () => backCalled = true));
      await tester.tap(find.byType(DivineAppBarIconButton));
      await tester.pump();

      expect(backCalled, isTrue);
    });

    // #7025. Being blocked used to strip every affordance from the profile,
    // including the two the blocked person most needs: reporting the account
    // and unfollowing it.
    testWidgets('keeps the more-sheet reachable', (tester) async {
      await tester.pumpWidget(buildSubject());

      final actions = tester.widget<UnavailableProfileActions>(
        find.byType(UnavailableProfileActions),
      );
      expect(actions.userIdHex, equals(_userIdHex));
    });
  });
}
