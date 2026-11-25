// ABOUTME: Escape closes the dialog, sheet or screen on top, like the system
// ABOUTME: back button; in a text field it first gives up the focus

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:unified_logger/unified_logger.dart';

/// Goes back one step: closes the dialog or sheet on top, or else the screen
/// on top.
class GoBackIntent extends Intent {
  /// Creates a [GoBackIntent].
  const GoBackIntent();
}

/// Lets Escape close a screen opened over another, such as a profile or a
/// fullscreen feed opened from the home feed.
///
/// Flutter's default shortcuts map Escape to [DismissIntent], which dialogs,
/// sheets and menus handle. Every full screen route answers that intent too,
/// with an action that stays disabled, and the nearest action is the only one
/// asked, so a fallback further up never hears it. Escape is mapped to
/// [GoBackIntent] here instead, which in turn:
///
/// * in a dialog or sheet route, does only what [DismissIntent] did before, so
///   one shown with `barrierDismissible: false` stays open;
/// * otherwise gives up the focus of a text field, so a half-written comment
///   is not closed with its screen;
/// * otherwise dismisses a menu that takes [DismissIntent], as before;
/// * otherwise pops the innermost navigator that can pop, the way the system
///   back button does, so a screen that guards its back navigation still
///   gets to ask first.
///
/// It acts only from the route on top. A screen that handles Escape itself,
/// such as the image editor, which closes on Escape through a keyboard
/// handler that runs before any shortcut, has left the top by then, so the
/// screen under it stays.
///
/// With nothing to close, the key passes on unhandled.
class BackOnEscape extends StatefulWidget {
  const BackOnEscape({required this.child, super.key});

  /// The routes Escape can close.
  final Widget child;

  @override
  State<BackOnEscape> createState() => _BackOnEscapeState();
}

class _BackOnEscapeState extends State<BackOnEscape> {
  final _actions = <Type, Action<Intent>>{GoBackIntent: _GoBackAction()};

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.escape): GoBackIntent(),
      },
      child: Actions(actions: _actions, child: widget.child),
    );
  }
}

class _GoBackAction extends ContextAction<GoBackIntent> {
  /// Goes back one step from [context] and answers whether it did anything.
  @override
  bool invoke(GoBackIntent intent, [BuildContext? context]) {
    if (context == null || !_isOnTop(context)) return false;
    // A dialog or sheet decides itself whether Escape may close it, through
    // its barrierDismissible.
    if (ModalRoute.of(context) is PopupRoute) return _dismissModal(context);
    final textFieldFocus = context
        .findAncestorWidgetOfExactType<EditableText>()
        ?.focusNode;
    // A text field answers DismissIntent itself and passes it on to whatever
    // is around it, so the answer cannot tell a closed menu from nothing
    // done. On a full screen it only gives up the focus instead.
    if (textFieldFocus != null) {
      textFieldFocus.unfocus();
      return true;
    }
    if (_dismissModal(context)) return true;
    final navigator = _poppableNavigator(context);
    if (navigator == null) return false;
    runDetached(
      navigator.maybePop(),
      'go back on Escape',
      logName: 'BackOnEscape',
      category: LogCategory.ui,
    );
    return true;
  }

  /// Leaves the key to the rest of the app when nothing went back.
  @override
  KeyEventResult toKeyEventResult(GoBackIntent intent, bool invokeResult) =>
      invokeResult ? KeyEventResult.handled : KeyEventResult.ignored;

  /// Runs the nearest [DismissIntent] action, if it is enabled, as Escape
  /// did before this widget mapped it.
  static bool _dismissModal(BuildContext context) {
    const intent = DismissIntent();
    final action = Actions.maybeFind<DismissIntent>(context, intent: intent);
    if (action == null) return false;
    final (enabled, _) = Actions.of(
      context,
    ).invokeActionIfEnabled(action, intent, context);
    return enabled;
  }

  /// Whether the route around [context], and each route around its
  /// navigator, is the top one. A route already popped or covered is not.
  static bool _isOnTop(BuildContext context) {
    var route = ModalRoute.of(context);
    while (route != null) {
      if (!route.isCurrent) return false;
      final navigatorContext = route.navigator?.context;
      if (navigatorContext == null) return true;
      route = ModalRoute.of(navigatorContext);
    }
    return true;
  }

  /// The innermost navigator above [context] with a route to pop.
  static NavigatorState? _poppableNavigator(BuildContext context) {
    var navigator = Navigator.maybeOf(context);
    while (navigator != null && !navigator.canPop()) {
      // Navigator.maybeOf would answer the navigator itself for its own
      // context, so step to its parent.
      navigator = navigator.context.findAncestorStateOfType<NavigatorState>();
    }
    return navigator;
  }
}
