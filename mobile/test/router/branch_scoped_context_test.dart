// ABOUTME: Proves each StatefulShellRoute branch sees its own scoped pageContext
// ABOUTME: so a kept-alive inactive branch keeps rendering its real content

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/router/routes/shell.dart' show branchPage;

/// Counts how many times it is built from scratch, so a test can tell a
/// re-scope (new element, new State) from a plain rebuild.
class _MountCounter extends StatefulWidget {
  const _MountCounter();

  static int mounts = 0;

  @override
  State<_MountCounter> createState() => _MountCounterState();
}

class _MountCounterState extends State<_MountCounter> {
  @override
  void initState() {
    super.initState();
    _MountCounter.mounts++;
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

class _Probe extends ConsumerWidget {
  const _Probe(this.label);

  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scoped = ref.watch(pageContextProvider).asData?.value.type;
    return Text(
      '$label scoped=${scoped?.name ?? 'none'}',
      textDirection: TextDirection.ltr,
    );
  }
}

GoRouter _buildRouter() => GoRouter(
  initialLocation: '/home/0',
  routes: [
    StatefulShellRoute(
      builder: (context, state, shell) => shell,
      navigatorContainerBuilder: (context, shell, children) =>
          AppShellBranchContainer(
            currentIndex: shell.currentIndex,
            children: children,
          ),
      branches: [
        StatefulShellBranch(
          initialLocation: '/home/0',
          routes: [
            GoRoute(
              path: '/home/:index',
              pageBuilder: (context, state) =>
                  branchPage(state, const _Probe('home')),
            ),
          ],
        ),
        StatefulShellBranch(
          initialLocation: '/explore',
          routes: [
            GoRoute(
              path: '/explore',
              pageBuilder: (context, state) =>
                  branchPage(state, const _Probe('explore')),
            ),
          ],
        ),
      ],
    ),
  ],
);

void main() {
  group('branch-scoped pageContext', () {
    testWidgets('an inactive branch keeps its own scoped pageContext', (
      tester,
    ) async {
      final router = _buildRouter();
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('home scoped=home'), findsOneWidget);

      router.go('/explore');
      await tester.pumpAndSettle();

      // The newly active branch shows its own context...
      expect(find.text('explore scoped=explore'), findsOneWidget);
      // ...and the kept-alive home branch STILL renders its OWN content (it did
      // NOT blank to the active 'explore' route) — that is what gives the
      // cross-fade two live tabs to dissolve between.
      expect(find.text('home scoped=home'), findsOneWidget);
    });

    // go_router keys a branch page on the route PATTERN, so `/profile/<a>`
    // and `/profile/<b>` arrive with the identical `state.pageKey`. Before
    // #7851's patrol the scope was therefore never re-created for a changed
    // path parameter, and the single-value override replayed the first npub
    // for the life of the element: the shell app bar named the account the
    // user tapped while the body below it still showed the previous one —
    // wrong name, wrong npub, wrong counts, and a Follow button pointed at
    // an account the user never opened.
    testWidgets('a changed path parameter re-scopes the branch', (
      tester,
    ) async {
      const npubA =
          'npub1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqlz5yt';
      const npubB =
          'npub1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqp6yfjr';

      final router = GoRouter(
        initialLocation: '/profile/$npubA',
        routes: [
          StatefulShellRoute(
            builder: (context, state, shell) => shell,
            navigatorContainerBuilder: (context, shell, children) =>
                AppShellBranchContainer(
                  currentIndex: shell.currentIndex,
                  children: children,
                ),
            branches: [
              StatefulShellBranch(
                initialLocation: '/profile/$npubA',
                routes: [
                  GoRoute(
                    path: '/profile/:npub',
                    pageBuilder: (context, state) => branchPage(
                      state,
                      Consumer(
                        builder: (context, ref, _) {
                          final ctx = ref
                              .watch(pageContextProvider)
                              .asData
                              ?.value;
                          return Text(
                            'scoped=${ctx?.npub ?? 'none'}',
                            textDirection: TextDirection.ltr,
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('scoped=$npubA'), findsOneWidget);

      router.go('/profile/$npubB');
      await tester.pumpAndSettle();

      expect(
        find.text('scoped=$npubB'),
        findsOneWidget,
        reason:
            'the branch must re-scope to the npub actually navigated to; '
            "replaying the first one renders another account's profile",
      );
      expect(find.text('scoped=$npubA'), findsNothing);
    });

    // ExploreFeedContent and ProfileVideoFeedView both write their own URL
    // from `onPageChanged`, so a feed rewrites its path on EVERY swipe.
    // Keying the branch scope on the whole path would therefore dispose the
    // video players and the scroll position mid-swipe — which is why
    // `RouteContext.subjectKey` leaves `videoIndex` out.
    testWidgets('paging within the same subject does not re-scope', (
      tester,
    ) async {
      _MountCounter.mounts = 0;

      final router = GoRouter(
        initialLocation: '/explore/0',
        routes: [
          StatefulShellRoute(
            builder: (context, state, shell) => shell,
            navigatorContainerBuilder: (context, shell, children) =>
                AppShellBranchContainer(
                  currentIndex: shell.currentIndex,
                  children: children,
                ),
            branches: [
              StatefulShellBranch(
                initialLocation: '/explore/0',
                routes: [
                  GoRoute(
                    path: '/explore/:index',
                    pageBuilder: (context, state) =>
                        branchPage(state, const _MountCounter()),
                  ),
                ],
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(_MountCounter.mounts, 1);

      // Three swipes.
      for (final index in [1, 2, 3]) {
        router.go('/explore/$index');
        await tester.pumpAndSettle();
      }

      expect(
        _MountCounter.mounts,
        1,
        reason:
            'paging a feed must not tear down its subtree; a feed rewrites '
            'its own URL on every swipe',
      );
    });

    testWidgets('branch-scoped pageContext ignores query parameters', (
      tester,
    ) async {
      RouteContext? captured;
      final router = GoRouter(
        initialLocation: '/profile/npub1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqlz5yt?utm_source=test',
        routes: [
          StatefulShellRoute(
            builder: (context, state, shell) => shell,
            navigatorContainerBuilder: (context, shell, children) =>
                AppShellBranchContainer(
                  currentIndex: shell.currentIndex,
                  children: children,
                ),
            branches: [
              StatefulShellBranch(
                initialLocation: '/profile/me',
                routes: [
                  GoRoute(
                    path: '/profile/:npub',
                    pageBuilder: (context, state) => branchPage(
                      state,
                      Consumer(
                        builder: (context, ref, _) {
                          final ctx = ref
                              .watch(pageContextProvider)
                              .asData
                              ?.value;
                          if (ctx != null) captured = ctx;
                          return const SizedBox();
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final ctx = captured;
      expect(ctx, isNotNull);
      expect(ctx!.type, RouteType.profile);
      expect(
        ctx.npub,
        'npub1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqlz5yt',
      );
    });
  });
}
