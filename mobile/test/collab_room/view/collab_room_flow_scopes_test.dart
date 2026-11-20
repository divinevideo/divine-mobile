import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/collab_room/collab_room_providers.dart';
import 'package:openvine/collab_room/view/collab_room_flow_scopes.dart';
import 'package:openvine/l10n/l10n.dart';

import 'collab_room_test_fixtures.dart';

void main() {
  /// A router at `/` that pushes `/flow`, the screen [scope] wraps.
  GoRouter router(Widget Function(Widget child) scope) => GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const SizedBox()),
      GoRoute(
        path: '/flow',
        builder: (_, _) => scope(const SizedBox()),
      ),
    ],
  );

  Future<ProviderContainer> pump(WidgetTester tester, GoRouter goRouter) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    addTearDown(goRouter.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: goRouter,
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    return container;
  }

  group(CollabRoomPartFlowScope, () {
    const part = CollabRoomPartContext(
      roomId: roomId,
      cellAspectRatio: 1,
      me: sam,
    );

    testWidgets('ends the part flow when a go() replaces the recorder', (
      tester,
    ) async {
      final goRouter = router(
        (child) => CollabRoomPartFlowScope(part: part, child: child),
      );
      final container = await pump(tester, goRouter);
      container.read(collabRoomPartProvider.notifier).set(part);
      // The room awaits this push; a go() never completes it.
      goRouter.push<void>('/flow').ignore();
      await tester.pumpAndSettle();
      expect(container.read(collabRoomPartProvider)?.isActive, isTrue);

      goRouter.go('/');
      await tester.pumpAndSettle();

      expect(container.read(collabRoomPartProvider)?.isActive, isFalse);
    });
  });

  group(CollabRoomPostFlowScope, () {
    testWidgets("ends the room's post flow when a go() replaces the room", (
      tester,
    ) async {
      final goRouter = router(
        (child) => CollabRoomPostFlowScope(roomId: roomId, child: child),
      );
      final container = await pump(tester, goRouter);
      container.read(collabRoomPostProvider.notifier).set(roomId);
      goRouter.push<void>('/flow').ignore();
      await tester.pumpAndSettle();

      goRouter.go('/');
      await tester.pumpAndSettle();

      expect(container.read(collabRoomPostProvider), isNull);
    });

    testWidgets("leaves another room's post flow alone", (tester) async {
      final goRouter = router(
        (child) => CollabRoomPostFlowScope(roomId: roomId, child: child),
      );
      final container = await pump(tester, goRouter);
      goRouter.push<void>('/flow').ignore();
      await tester.pumpAndSettle();
      container.read(collabRoomPostProvider.notifier).set('f' * 32);

      goRouter.go('/');
      await tester.pumpAndSettle();

      expect(container.read(collabRoomPostProvider), 'f' * 32);
    });
  });
}
