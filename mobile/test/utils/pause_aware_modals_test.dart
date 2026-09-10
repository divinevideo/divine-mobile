// ABOUTME: Tests for PauseAwareModals extension, specifically the
// ABOUTME: VineBottomSheet wrapper that video-feed sheets (Metadata,
// ABOUTME: Comments after migration) rely on for tap-outside dismissal
// ABOUTME: and overlay-visibility integration.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/providers/overlay_visibility_provider.dart';
import 'package:openvine/utils/pause_aware_modals.dart';

void main() {
  group('showVideoPausingVineBottomSheet', () {
    Future<void> setSheetTestSurface(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
    }

    testWidgets('default path dismisses on tap above the sheet (inherits '
        'tapOutsideToDismiss default)', (tester) async {
      await setSheetTestSurface(tester);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    context.showVideoPausingVineBottomSheet<void>(
                      showHeader: false,
                      initialChildSize: 0.7,
                      buildScrollBody: (scrollController) => ListView(
                        controller: scrollController,
                        children: const [Text('Metadata Body')],
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Metadata Body'), findsOneWidget);

      // Tap above the sheet — simulates the scrim tap.
      await tester.tapAt(const Offset(200, 20));
      await tester.pumpAndSettle();

      expect(find.text('Metadata Body'), findsNothing);
    });

    testWidgets(
      'sets and clears isBottomSheetOpen on the overlay visibility provider',
      (tester) async {
        await setSheetTestSurface(tester);

        late ProviderContainer container;
        await tester.pumpWidget(
          ProviderScope(
            child: Consumer(
              builder: (context, ref, _) {
                container = ProviderScope.containerOf(context, listen: false);
                return MaterialApp(
                  home: Scaffold(
                    body: Builder(
                      builder: (innerContext) => ElevatedButton(
                        onPressed: () {
                          innerContext.showVideoPausingVineBottomSheet<void>(
                            title: const Text('Title'),
                            children: const [Text('Body')],
                          );
                        },
                        child: const Text('Open'),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );

        expect(
          container.read(overlayVisibilityProvider).isBottomSheetOpen,
          isFalse,
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        expect(
          container.read(overlayVisibilityProvider).isBottomSheetOpen,
          isTrue,
        );

        // Dismiss with outside tap.
        await tester.tapAt(const Offset(200, 20));
        await tester.pumpAndSettle();

        expect(
          container.read(overlayVisibilityProvider).isBottomSheetOpen,
          isFalse,
        );
      },
    );

    testWidgets(
      'keeps isBottomSheetOpen true until nested sheets all dismiss',
      (tester) async {
        await setSheetTestSurface(tester);

        late ProviderContainer container;
        await tester.pumpWidget(
          ProviderScope(
            child: Consumer(
              builder: (context, ref, _) {
                container = ProviderScope.containerOf(context, listen: false);
                return MaterialApp(
                  home: Scaffold(
                    body: Builder(
                      builder: (innerContext) => ElevatedButton(
                        onPressed: () {
                          innerContext.showVideoPausingVineBottomSheet<void>(
                            title: const Text('Sheet A'),
                            children: [
                              Builder(
                                builder: (sheetContext) => ElevatedButton(
                                  onPressed: () {
                                    sheetContext
                                        .showVideoPausingVineBottomSheet<void>(
                                          title: const Text('Sheet B'),
                                          children: [
                                            const Text('Body B'),
                                            ElevatedButton(
                                              onPressed: () => Navigator.of(
                                                sheetContext,
                                                rootNavigator: true,
                                              ).pop(),
                                              child: const Text('Close B'),
                                            ),
                                          ],
                                        );
                                  },
                                  child: const Text('Open nested'),
                                ),
                              ),
                              Builder(
                                builder: (sheetContext) => ElevatedButton(
                                  onPressed: () => Navigator.of(
                                    sheetContext,
                                    rootNavigator: true,
                                  ).pop(),
                                  child: const Text('Close A'),
                                ),
                              ),
                            ],
                          );
                        },
                        child: const Text('Open'),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(
          container.read(overlayVisibilityProvider).isBottomSheetOpen,
          isTrue,
        );

        await tester.tap(find.text('Open nested'));
        await tester.pumpAndSettle();
        expect(find.text('Body B'), findsOneWidget);
        expect(
          container.read(overlayVisibilityProvider).isBottomSheetOpen,
          isTrue,
        );

        await tester.tap(find.text('Close B'));
        await tester.pumpAndSettle();
        expect(find.text('Body B'), findsNothing);
        expect(find.text('Sheet A'), findsOneWidget);
        expect(
          container.read(overlayVisibilityProvider).isBottomSheetOpen,
          isTrue,
        );

        await tester.tap(find.text('Close A'));
        await tester.pumpAndSettle();
        expect(find.text('Sheet A'), findsNothing);
        expect(
          container.read(overlayVisibilityProvider).isBottomSheetOpen,
          isFalse,
        );
      },
    );

    testWidgets(
      'tapOutsideToDismiss: false keeps the sheet open on outside tap',
      (tester) async {
        await setSheetTestSurface(tester);

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () {
                      context.showVideoPausingVineBottomSheet<void>(
                        tapOutsideToDismiss: false,
                        initialChildSize: 0.5,
                        title: const Text('Pinned Sheet'),
                        children: const [Text('Pinned Body')],
                      );
                    },
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(find.text('Pinned Body'), findsOneWidget);

        await tester.tapAt(const Offset(200, 20));
        await tester.pumpAndSettle();

        expect(find.text('Pinned Body'), findsOneWidget);
      },
    );
  });

  group('showVideoPausingSelectionMenu', () {
    testWidgets(
      'sets and clears isBottomSheetOpen on the overlay visibility provider',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () {
                      context.showVideoPausingSelectionMenu(
                        options: const [
                          VineBottomSheetSelectionOptionData(
                            label: 'Option A',
                            value: 'a',
                          ),
                        ],
                      );
                    },
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        );

        final container = ProviderScope.containerOf(
          tester.element(find.text('Open')),
          listen: false,
        );
        expect(
          container.read(overlayVisibilityProvider).isBottomSheetOpen,
          isFalse,
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        expect(
          container.read(overlayVisibilityProvider).isBottomSheetOpen,
          isTrue,
        );

        await tester.tap(find.text('Option A'));
        await tester.pumpAndSettle();

        expect(
          container.read(overlayVisibilityProvider).isBottomSheetOpen,
          isFalse,
        );
      },
    );
  });

  group('pushWithVideoPause', () {
    GoRouter buildRouter() => GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          pageBuilder: (_, state) => NoTransitionPage<void>(
            key: state.pageKey,
            child: Scaffold(
              body: Builder(
                builder: (context) => Column(
                  children: [
                    TextButton(
                      onPressed: () => unawaited(
                        context.pushWithVideoPause<void>('/hashtag'),
                      ),
                      child: const Text('Open'),
                    ),
                    TextButton(
                      onPressed: () => unawaited(
                        context.pushWithVideoPause<void>('/profile'),
                      ),
                      child: const Text('Open profile'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/profile',
          pageBuilder: (_, state) => MaterialPage<void>(
            key: state.pageKey,
            child: Scaffold(
              body: Column(
                children: [
                  Builder(
                    builder: (context) => TextButton(
                      onPressed: () => unawaited(
                        context.pushWithVideoPause<void>('/hashtag'),
                      ),
                      child: const Text('Open nested route'),
                    ),
                  ),
                  Builder(
                    builder: (context) => TextButton(
                      onPressed: () => unawaited(
                        context.showVideoPausingDialog<void>(
                          builder: (_) =>
                              const AlertDialog(content: Text('Route dialog')),
                        ),
                      ),
                      child: const Text('Open route dialog'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/explore',
          pageBuilder: (_, state) => NoTransitionPage<void>(
            key: state.pageKey,
            child: const Scaffold(body: Text('Explore')),
          ),
        ),
        GoRoute(
          path: '/hashtag',
          pageBuilder: (_, state) => MaterialPage<void>(
            key: state.pageKey,
            child: const Scaffold(body: Text('Hashtag')),
          ),
        ),
      ],
    );

    Future<(GoRouter, ProviderContainer)> pumpApp(WidgetTester tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final router = buildRouter();
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      return (router, container);
    }

    testWidgets('clears isPageOpen when the pushed route is popped', (
      tester,
    ) async {
      final (router, container) = await pumpApp(tester);

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Hashtag'), findsOneWidget);
      expect(container.read(overlayVisibilityProvider).isPageOpen, isTrue);

      router.pop();
      await tester.pumpAndSettle();
      expect(container.read(overlayVisibilityProvider).isPageOpen, isFalse);
    });

    testWidgets('keeps page open while an outer pushed route remains', (
      tester,
    ) async {
      final (router, container) = await pumpApp(tester);

      await tester.tap(find.text('Open profile'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open nested route'));
      await tester.pumpAndSettle();
      expect(find.text('Hashtag'), findsOneWidget);
      expect(container.read(overlayVisibilityProvider).isPageOpen, isTrue);

      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('Open nested route'), findsOneWidget);
      expect(container.read(overlayVisibilityProvider).isPageOpen, isTrue);

      router.pop();
      await tester.pumpAndSettle();
      expect(container.read(overlayVisibilityProvider).isPageOpen, isFalse);
    });

    testWidgets('dialog release preserves an outer pushed route hold', (
      tester,
    ) async {
      final (router, container) = await pumpApp(tester);

      await tester.tap(find.text('Open profile'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open route dialog'));
      await tester.pumpAndSettle();
      expect(find.text('Route dialog'), findsOneWidget);
      expect(container.read(overlayVisibilityProvider).isPageOpen, isTrue);

      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('Open route dialog'), findsOneWidget);
      expect(container.read(overlayVisibilityProvider).isPageOpen, isTrue);

      router.pop();
      await tester.pumpAndSettle();
      expect(container.read(overlayVisibilityProvider).isPageOpen, isFalse);
    });

    testWidgets(
      'leaves isPageOpen set when a go() removes the pushed route — the '
      'go_router behaviour AppShell has to compensate for (#6239)',
      (tester) async {
        final (router, container) = await pumpApp(tester);

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(container.read(overlayVisibilityProvider).isPageOpen, isTrue);

        // What the Android back handler does for several route types, and what
        // a deep link or a refresh redirect does: navigate rather than pop. The
        // route is removed from the match list, so go_router's
        // `_completeRouteMatch` never runs and the `push` future stays pending
        // forever — the `whenComplete` clear below never fires.
        router.go('/explore');
        await tester.pumpAndSettle();
        expect(find.text('Explore'), findsOneWidget);

        expect(
          container.read(overlayVisibilityProvider).isPageOpen,
          isTrue,
          reason:
              'if go_router ever completes the future on removal, drop this '
              'test and the AppShell safety net it justifies',
        );
      },
    );
  });

  group('showVideoPausingDialog', () {
    testWidgets('nested dialog release preserves the outer dialog hold', (
      tester,
    ) async {
      late ProviderContainer container;
      await tester.pumpWidget(
        ProviderScope(
          child: Consumer(
            builder: (context, ref, _) {
              container = ProviderScope.containerOf(context, listen: false);
              return MaterialApp(
                home: Scaffold(
                  body: Builder(
                    builder: (context) => TextButton(
                      onPressed: () => unawaited(
                        context.showVideoPausingDialog<void>(
                          builder: (_) => AlertDialog(
                            content: Builder(
                              builder: (dialogContext) => TextButton(
                                onPressed: () => unawaited(
                                  dialogContext.showVideoPausingDialog<void>(
                                    builder: (_) => const AlertDialog(
                                      content: Text('Inner dialog'),
                                    ),
                                  ),
                                ),
                                child: const Text('Open inner dialog'),
                              ),
                            ),
                          ),
                        ),
                      ),
                      child: const Text('Open outer dialog'),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open outer dialog'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open inner dialog'));
      await tester.pumpAndSettle();
      expect(find.text('Inner dialog'), findsOneWidget);
      expect(container.read(overlayVisibilityProvider).isPageOpen, isTrue);

      Navigator.of(
        tester.element(find.text('Inner dialog')),
        rootNavigator: true,
      ).pop();
      await tester.pumpAndSettle();
      expect(find.text('Open inner dialog'), findsOneWidget);
      expect(container.read(overlayVisibilityProvider).isPageOpen, isTrue);

      Navigator.of(
        tester.element(find.text('Open inner dialog')),
        rootNavigator: true,
      ).pop();
      await tester.pumpAndSettle();
      expect(container.read(overlayVisibilityProvider).isPageOpen, isFalse);
    });
  });
}
