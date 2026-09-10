// ABOUTME: Tests for UserNotAvailableScreen.
// ABOUTME: Verifies the placeholder renders and keeps the more-sheet reachable.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/screens/user_not_available_screen.dart';
import 'package:openvine/widgets/profile/unavailable_profile_actions.dart';

const _userIdHex =
    'd4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5';

void main() {
  group(UserNotAvailableScreen, () {
    final l10n = lookupAppLocalizations(const Locale('en'));

    Widget buildSubject({VoidCallback? onBack}) {
      return ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: UserNotAvailableScreen(
            onBack: onBack ?? () {},
            userIdHex: _userIdHex,
          ),
        ),
      );
    }

    testWidgets('displays the unavailable copy', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.text(l10n.userNotAvailableTitle), findsOneWidget);
      expect(find.text(l10n.userNotAvailableBody), findsOneWidget);
    });

    testWidgets('calls onBack when back button tapped', (tester) async {
      var backCalled = false;

      await tester.pumpWidget(buildSubject(onBack: () => backCalled = true));
      await tester.tap(find.byType(DivineAppBarIconButton));
      await tester.pump();

      expect(backCalled, isTrue);
    });

    // #7025. This screen replaces the whole profile when someone blocks us,
    // which also removed the only route to reporting or unfollowing them.
    testWidgets('keeps the more-sheet reachable', (tester) async {
      await tester.pumpWidget(buildSubject());

      final actions = tester.widget<UnavailableProfileActions>(
        find.byType(UnavailableProfileActions),
      );
      expect(actions.userIdHex, equals(_userIdHex));
    });
  });
}
