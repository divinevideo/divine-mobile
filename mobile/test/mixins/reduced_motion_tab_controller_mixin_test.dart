import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/mixins/reduced_motion_tab_controller_mixin.dart';

void main() {
  group('ReducedMotionTabControllerMixin', () {
    Future<_HostState> pumpHost(
      WidgetTester tester, {
      bool reduceMotion = false,
      int tabCount = 3,
      int initialTabIndex = 0,
    }) async {
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: _Host(
              tabCount: tabCount,
              initialTabIndex: initialTabIndex,
            ),
          ),
        ),
      );
      return tester.state<_HostState>(find.byType(_Host));
    }

    testWidgets('opens on initialTabIndex with the default duration', (
      tester,
    ) async {
      final host = await pumpHost(tester, initialTabIndex: 2);

      expect(host.tabController.index, equals(2));
      expect(host.tabController.animationDuration, equals(kTabScrollDuration));
    });

    testWidgets('collapses the duration when reduced motion is on', (
      tester,
    ) async {
      final host = await pumpHost(tester, reduceMotion: true);

      expect(host.tabController.animationDuration, equals(Duration.zero));
    });

    testWidgets('clamps initialTabIndex into range', (tester) async {
      final host = await pumpHost(tester, tabCount: 2, initialTabIndex: 7);

      expect(host.tabController.index, equals(1));
    });

    testWidgets('reuses the controller when nothing changed', (tester) async {
      final host = await pumpHost(tester);
      final first = host.tabController;

      expect(host.syncTabController(), isFalse);
      expect(host.tabController, same(first));
    });

    testWidgets('swaps the controller when reduced motion is toggled', (
      tester,
    ) async {
      final host = await pumpHost(tester);
      host.tabController.index = 2;
      final first = host.tabController;

      await pumpHost(tester, reduceMotion: true);

      expect(host.tabController, isNot(same(first)));
      expect(host.tabController.animationDuration, equals(Duration.zero));
      // The open tab survives the swap.
      expect(host.tabController.index, equals(2));
    });

    testWidgets('carries the open tab across a tab-count change, clamped', (
      tester,
    ) async {
      final host = await pumpHost(tester, tabCount: 4);
      host.tabController.index = 3;

      host
        ..tabCount = 2
        ..syncTabController();

      expect(host.tabController.length, equals(2));
      expect(host.tabController.index, equals(1));
    });

    testWidgets('moves onTabChanged onto the replacement controller', (
      tester,
    ) async {
      final host = await pumpHost(tester);
      await pumpHost(tester, reduceMotion: true);
      host.changes = 0;

      host.tabController.index = 1;

      expect(host.changes, greaterThan(0));
    });

    testWidgets('disposes the controller it owns', (tester) async {
      final host = await pumpHost(tester);
      final controller = host.tabController;

      await tester.pumpWidget(const SizedBox.shrink());

      // A disposed TabController drops its animation.
      expect(controller.animation, isNull);
    });
  });
}

class _Host extends StatefulWidget {
  const _Host({required this.tabCount, required this.initialTabIndex});

  final int tabCount;
  final int initialTabIndex;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host>
    with TickerProviderStateMixin, ReducedMotionTabControllerMixin {
  int? _tabCountOverride;
  int changes = 0;

  @override
  int get tabCount => _tabCountOverride ?? widget.tabCount;

  set tabCount(int value) => _tabCountOverride = value;

  @override
  int get initialTabIndex => widget.initialTabIndex;

  @override
  void onTabChanged() => changes++;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    syncTabController();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
