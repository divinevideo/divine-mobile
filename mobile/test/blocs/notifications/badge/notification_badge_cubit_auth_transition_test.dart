// ABOUTME: Widget-level test for the badge cubit's auth-transition contract.
// ABOUTME: Verifies that the stable BlocProvider wiring around the cubit
// ABOUTME: swaps only the unread-count subscription when the Riverpod
// ABOUTME: notificationRepositoryProvider flips identity (signed-out ->
// ABOUTME: signed-in, account switch A->B), without remounting descendants.

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:notification_repository/notification_repository.dart';
import 'package:openvine/blocs/notifications/badge/notification_badge_cubit.dart';
import 'package:openvine/notifications/providers/notification_repository_provider.dart';

class _MockNotificationRepository extends Mock
    implements NotificationRepository {}

/// Override target — tests mutate this StateProvider to flip the
/// repository that [notificationRepositoryProvider] returns.
final _testRepoSelector = StateProvider<NotificationRepository?>((_) => null);

int _mountCount = 0;

class _MountProbe extends StatefulWidget {
  const _MountProbe({required this.child});

  final Widget child;

  @override
  State<_MountProbe> createState() => _MountProbeState();
}

class _MountProbeState extends State<_MountProbe> {
  @override
  void initState() {
    super.initState();
    _mountCount += 1;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _BadgeRepositorySync extends ConsumerWidget {
  const _BadgeRepositorySync({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(notificationRepositoryProvider, (_, repository) {
      context.read<NotificationBadgeCubit>().setRepository(repository);
    });
    return child;
  }
}

/// Probe widget mirroring `AppShellBadgeScope`'s wiring around the badge cubit:
/// the [BlocProvider] identity stays stable, and repository flips are forwarded
/// to the existing cubit so descendants do not remount.
class _BadgeProbe extends ConsumerWidget {
  const _BadgeProbe();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BlocProvider(
      create: (_) => NotificationBadgeCubit(
        repository: ref.read(notificationRepositoryProvider),
      ),
      child: _BadgeRepositorySync(
        child: _MountProbe(
          child: BlocBuilder<NotificationBadgeCubit, int>(
            builder: (context, count) => Text('count=$count'),
          ),
        ),
      ),
    );
  }
}

void main() {
  // The eager-create pin (`lazy: false`) for NotificationBadgeCubit lives in
  // `test/widgets/app_shell_badge_scope_test.dart`, which pumps the real
  // AppShellBadgeScope. This file covers the cubit's setRepository
  // auth-transition behaviour: descendants stay mounted while only the
  // unread-count subscription swaps.
  group('NotificationBadgeCubit auth transition', () {
    setUp(() {
      _mountCount = 0;
    });

    testWidgets(
      'signed-out -> signed-in: badge resets at 0, then emits from the new '
      "repository's stream",
      (tester) async {
        final controllerB = StreamController<int>.broadcast();
        addTearDown(controllerB.close);
        final repoB = _MockNotificationRepository();
        when(repoB.watchUnreadCount).thenAnswer((_) => controllerB.stream);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              notificationRepositoryProvider.overrideWith(
                (ref) => ref.watch(_testRepoSelector),
              ),
            ],
            child: const MaterialApp(home: _BadgeProbe()),
          ),
        );

        expect(find.text('count=0'), findsOneWidget);
        expect(_mountCount, 1);
        verifyNever(repoB.watchUnreadCount);

        final container = ProviderScope.containerOf(
          tester.element(find.byType(_BadgeProbe)),
        );
        container.read(_testRepoSelector.notifier).state = repoB;
        await tester.pumpAndSettle();

        controllerB.add(5);
        await tester.pumpAndSettle();

        expect(find.text('count=5'), findsOneWidget);
        expect(_mountCount, 1);
        verify(repoB.watchUnreadCount).called(1);
      },
    );

    testWidgets(
      'account switch A -> B: old subscription is cancelled and the existing '
      "cubit subscribes to B's stream",
      (tester) async {
        final controllerA = StreamController<int>.broadcast();
        final controllerB = StreamController<int>.broadcast();
        addTearDown(() async {
          await controllerA.close();
          await controllerB.close();
        });

        final repoA = _MockNotificationRepository();
        final repoB = _MockNotificationRepository();
        when(repoA.watchUnreadCount).thenAnswer((_) => controllerA.stream);
        when(repoB.watchUnreadCount).thenAnswer((_) => controllerB.stream);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              notificationRepositoryProvider.overrideWith(
                (ref) => ref.watch(_testRepoSelector),
              ),
            ],
            child: const MaterialApp(home: _BadgeProbe()),
          ),
        );

        final container = ProviderScope.containerOf(
          tester.element(find.byType(_BadgeProbe)),
        );
        container.read(_testRepoSelector.notifier).state = repoA;
        await tester.pumpAndSettle();

        controllerA.add(3);
        await tester.pumpAndSettle();
        expect(find.text('count=3'), findsOneWidget);
        expect(_mountCount, 1);

        // Swap repositories — production may transition through a null phase,
        // but the root wiring must keep descendants mounted and swap only the
        // cubit's unread-count subscription.
        container.read(_testRepoSelector.notifier).state = repoB;
        await tester.pumpAndSettle();

        expect(_mountCount, 1);

        controllerB.add(7);
        await tester.pumpAndSettle();
        expect(find.text('count=7'), findsOneWidget);

        // Late emission on A's stream must not reach the existing cubit,
        // proving the prior subscription was cancelled when the repository
        // identity changed.
        controllerA.add(99);
        await tester.pumpAndSettle();
        expect(find.text('count=99'), findsNothing);
        expect(find.text('count=7'), findsOneWidget);
      },
    );
  });
}
