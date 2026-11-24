// ABOUTME: Guards where a link tapped inside linkified text in a modal lands,
// ABOUTME: including your own profile (#11097), and that a sheet already
// ABOUTME: closing is never popped twice.

import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/other_profile_screen.dart';
import 'package:openvine/screens/profile_screen_router.dart';
import 'package:openvine/screens/search_results/view/search_results_page.dart';
import 'package:openvine/widgets/linkified_text/linkified_text.dart';
import 'package:openvine/widgets/linkified_text/linkified_text_navigation.dart';
import 'package:profile_repository/profile_repository.dart';

import '../../helpers/test_provider_overrides.dart';
import '../../helpers/test_pubkeys.dart';

class _MockProfileRepository extends Mock implements ProfileRepository {}

/// Pumps a one-page router whose page opens a bottom sheet built by [sheet].
///
/// Popping that page is what empties go_router's match list, as popping the
/// app's tab shell does.
Future<GoRouter> _pumpSheetHost(
  WidgetTester tester, {
  required WidgetBuilder sheet,
  List<Override> overrides = const [],
}) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  showModalBottomSheet<void>(context: context, builder: sheet),
              child: const Text('open sheet'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: SearchResultsPage.path,
        builder: (_, state) => Text('search:${state.pathParameters['query']}'),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.tap(find.text('open sheet'));
  await tester.pumpAndSettle();
  return router;
}

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

    // A mention navigates only after an async profile lookup, so the sheet
    // can already be closing: dismissed by the viewer, or popped by an
    // earlier tap. Popping again then removed the page beneath it, and
    // popping the last page left go_router with no matches, which crashed
    // the next system back.
    group('once the sheet is closing', () {
      final entryPoints =
          <String, void Function(BuildContext, VoidCallback beforeNavigate)>{
            'navigateToHashtagFeedFromModal': (context, beforeNavigate) =>
                LinkifiedTextNavigation.navigateToHashtagFeedFromModal(
                  context,
                  'divine',
                  beforeNavigate: beforeNavigate,
                ),
            'navigateToProfileFromModal': (context, beforeNavigate) =>
                LinkifiedTextNavigation.navigateToProfileFromModal(
                  context,
                  syntheticOtherTestPubkey,
                  beforeNavigate: beforeNavigate,
                ),
            'navigateToVideoFromModal': (context, beforeNavigate) =>
                LinkifiedTextNavigation.navigateToVideoFromModal(
                  context,
                  'video-reference',
                  beforeNavigate: beforeNavigate,
                ),
            'navigateToSearchFromModal': (context, beforeNavigate) =>
                LinkifiedTextNavigation.navigateToSearchFromModal(
                  context,
                  'ann',
                  beforeNavigate: beforeNavigate,
                ),
          };

      for (final MapEntry(key: name, value: navigate) in entryPoints.entries) {
        testWidgets('$name keeps the page the sheet was opened from', (
          tester,
        ) async {
          var beforeNavigateCalls = 0;
          late BuildContext sheetContext;
          final router = await _pumpSheetHost(
            tester,
            sheet: (context) {
              sheetContext = context;
              return const Text('sheet');
            },
          );

          Navigator.of(sheetContext).pop();
          await tester.pump();
          expect(sheetContext.mounted, isTrue);

          navigate(sheetContext, () => beforeNavigateCalls++);
          await tester.pumpAndSettle();

          expect(find.text('open sheet'), findsOneWidget);
          expect(find.text('sheet'), findsNothing);
          expect(beforeNavigateCalls, 0);
          final configuration = router.routerDelegate.currentConfiguration;
          expect(configuration.matches, hasLength(1));
          expect(configuration.uri.path, '/');
        });
      }
    });
  });

  group('$LinkifiedText mention inside a sheet', () {
    const mention = 'ann';

    // A slow lookup gives no feedback, so a second tap is the natural
    // response; both lookups then finish together.
    testWidgets('opens the search once when tapped twice during the lookup', (
      tester,
    ) async {
      // Created in the test body so it completes inside the test's fake
      // async zone.
      final cachedLookup = Completer<List<UserProfile>>();
      final profileRepository = _MockProfileRepository();
      when(
        () => profileRepository.searchCachedProfilesByIdentity(
          query: mention,
          limit: 10,
        ),
      ).thenAnswer((_) => cachedLookup.future);
      when(
        () => profileRepository.searchUsers(query: mention, limit: 10),
      ).thenAnswer((_) async => const []);
      final router = await _pumpSheetHost(
        tester,
        overrides: [
          profileRepositoryProvider.overrideWithValue(profileRepository),
        ],
        sheet: (_) => const LinkifiedText(
          text: '@$mention hi',
          dismissModalBeforeNavigation: true,
        ),
      );
      final text = tester.widget<Text>(
        find.descendant(
          of: find.byType(LinkifiedText),
          matching: find.byType(Text),
        ),
      );
      final mentionSpan = (text.textSpan! as TextSpan).children!
          .cast<TextSpan>()
          .firstWhere((span) => span.text == '@$mention');
      final onTap = (mentionSpan.recognizer! as TapGestureRecognizer).onTap!;

      onTap();
      onTap();
      cachedLookup.complete(const []);
      await tester.pumpAndSettle();

      expect(find.text('search:$mention'), findsOneWidget);
      expect(router.routerDelegate.currentConfiguration.matches, hasLength(2));

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('open sheet'), findsOneWidget);
    });
  });
}
