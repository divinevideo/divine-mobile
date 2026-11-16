// ABOUTME: Guards where a profile tapped inside linkified text in a modal
// ABOUTME: lands, including your own profile (#11097).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/other_profile_screen.dart';
import 'package:openvine/screens/profile_screen_router.dart';
import 'package:openvine/widgets/linkified_text/linkified_text_navigation.dart';

import '../../helpers/test_provider_overrides.dart';
import '../../helpers/test_pubkeys.dart';

void main() {
  group(LinkifiedTextNavigation, () {
    group('navigateToProfileFromModal', () {
      Future<void> tapProfileInSheet(
        WidgetTester tester,
        String hexPubkey,
      ) async {
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      builder: (sheetContext) => TextButton(
                        onPressed: () =>
                            LinkifiedTextNavigation.navigateToProfileFromModal(
                              sheetContext,
                              hexPubkey,
                            ),
                        child: const Text('mention'),
                      ),
                    ),
                    child: const Text('open sheet'),
                  ),
                ),
              ),
            ),
            GoRoute(
              path: ProfileScreenRouter.pathWithNpub,
              builder: (_, _) => const Scaffold(body: Text('profile tab')),
            ),
            GoRoute(
              path: OtherProfileScreen.pathWithNpub,
              builder: (_, _) => const Scaffold(body: Text('profile viewer')),
            ),
          ],
        );
        addTearDown(router.dispose);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authServiceProvider.overrideWithValue(
                createMockAuthService(currentPublicKeyHex: syntheticTestPubkey),
              ),
            ],
            child: MaterialApp.router(
              routerConfig: router,
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        );
        await tester.tap(find.text('open sheet'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('mention'));
        await tester.pumpAndSettle();
      }

      // Pushing your own viewer route from above the tab shell stacks a
      // second shell page, so your own mention goes to your Profile tab.
      testWidgets('opens your own Profile tab after closing the sheet', (
        tester,
      ) async {
        await tapProfileInSheet(tester, syntheticTestPubkey);

        expect(find.text('mention'), findsNothing);
        expect(find.text('profile tab'), findsOneWidget);
        expect(find.text('profile viewer'), findsNothing);
      });

      testWidgets("pushes another user's viewer after closing the sheet", (
        tester,
      ) async {
        await tapProfileInSheet(tester, syntheticOtherTestPubkey);

        expect(find.text('mention'), findsNothing);
        expect(find.text('profile viewer'), findsOneWidget);
        expect(find.text('profile tab'), findsNothing);
      });
    });
  });
}
