// ABOUTME: Owns a TabController whose animation length follows the platform's
// ABOUTME: reduced-motion setting, rebuilding it when that or the tab count
// ABOUTME: changes and carrying the open tab and listener across.

import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:openvine/extensions/media_query_extensions.dart';

/// Owns a [TabController] that honours the platform's reduced-motion setting.
///
/// [TabController.animationDuration] drives both the [TabBar] indicator slide
/// and the [TabBarView] page transition, and Flutter short-circuits both when
/// it is [Duration.zero] — but it is fixed at construction. Reacting to a
/// mid-session toggle therefore means building a replacement controller, which
/// is what [syncTabController] does. It handles the same swap for a changed
/// [tabCount], so screens with conditional tabs need only the one call.
///
/// Requires [TickerProviderStateMixin] rather than
/// `SingleTickerProviderStateMixin`, which permits only one ticker per State
/// and throws on the second controller.
///
/// ```dart
/// class _MyViewState extends State<MyView>
///     with TickerProviderStateMixin, ReducedMotionTabControllerMixin {
///   @override
///   int get tabCount => 3;
///
///   @override
///   void onTabChanged() => setState(() {});
///
///   @override
///   void didChangeDependencies() {
///     super.didChangeDependencies();
///     syncTabController();
///   }
///
///   @override
///   Widget build(BuildContext context) =>
///       TabBar(controller: tabController, tabs: ...);
/// }
/// ```
mixin ReducedMotionTabControllerMixin<T extends StatefulWidget>
    on State<T>, TickerProviderStateMixin<T> {
  TabController? _tabController;

  /// The current controller.
  ///
  /// Valid from the first [syncTabController] call until `dispose`, so call
  /// that from `didChangeDependencies` before the first `build`.
  TabController get tabController => _tabController!;

  /// How many tabs the controller should carry. Re-read on every sync.
  int get tabCount;

  /// Tab the *first* controller opens on — a restored or deep-linked tab.
  ///
  /// Later rebuilds carry the open tab over instead, so this is read once.
  int get initialTabIndex => 0;

  /// Invoked on every [TabController] notification.
  ///
  /// The mixin moves this across controller rebuilds, so implementers never
  /// add or remove the listener themselves.
  void onTabChanged() {}

  /// Installs a controller matching [tabCount] and the current reduced-motion
  /// setting, keeping the existing one when it already matches.
  ///
  /// Opens on [index] when given, otherwise carries the open tab over — or
  /// [initialTabIndex] on the first sync — clamped into the new range. Returns
  /// whether a new controller was installed.
  ///
  /// Call this from `didChangeDependencies` — that is what picks up a
  /// reduced-motion toggle — and again wherever [tabCount] can change.
  bool syncTabController({int? index}) {
    final duration = kTabScrollDuration.autoReduceMotion(context);
    final previous = _tabController;
    if (previous != null &&
        previous.length == tabCount &&
        previous.animationDuration == duration &&
        (index == null || index == previous.index)) {
      return false;
    }
    _tabController = TabController(
      length: tabCount,
      vsync: this,
      initialIndex: (index ?? previous?.index ?? initialTabIndex).clamp(
        0,
        math.max(0, tabCount - 1),
      ),
      animationDuration: duration,
    )..addListener(onTabChanged);
    previous
      ?..removeListener(onTabChanged)
      ..dispose();
    return true;
  }

  @override
  void dispose() {
    _tabController
      ?..removeListener(onTabChanged)
      ..dispose();
    super.dispose();
  }
}
