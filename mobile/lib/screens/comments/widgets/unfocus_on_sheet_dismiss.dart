// ABOUTME: Drops the keyboard when the enclosing modal sheet starts dismissing
// ABOUTME: so iOS does not strand an orphaned keyboard over the screen below.

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:unified_logger/unified_logger.dart';

/// Unfocuses the active text field and hides the software keyboard the moment
/// the enclosing [ModalRoute] begins its dismiss transition.
///
/// The comments bottom sheet has no close button — it is dismissed by dragging
/// it down, tapping the scrim, or the system back gesture. Most of those
/// vectors reverse the modal route's transition animation, so
/// [AnimationStatus.reverse] is the primary dismiss signal (#5604). Two
/// teardown paths never emit it (#5959):
///
/// * a chrome drag that rides the route controller to its 0.0 clamp goes
///   completed→forward→dismissed (both fling branches in
///   `material/bottom_sheet.dart` are guarded by `value > 0.0`, and the
///   follow-up pop's `reverse()` takes the zero-duration branch), covered by
///   also reacting to [AnimationStatus.dismissed];
/// * route removal without a pop emits no status change at all, covered by
///   the [dispose] fallback.
///
/// `unfocus()` alone is not enough: when iOS tears down the text-input
/// session during a background/resume cycle, the framework nulls its side of
/// the connection without any outbound `TextInput.hide`, while iOS
/// re-presents the keyboard for the stale first responder on resume. In that
/// split-brain state `unfocus()` produces zero text-input channel traffic, so
/// an explicit `TextInput.hide` — which resigns the first responder
/// engine-side regardless of framework connection state — is sent as well.
///
/// `TextInput.hide` alone is still not enough (#6007): the engine's
/// `hideTextInput` resigns the first responder but never zeroes
/// `_textInputClient`, and in the split-brain state the framework never sends
/// its own `TextInput.clearClient` either. The dismissal then leaves an
/// in-hierarchy `FlutterTextInputView` whose `canBecomeFirstResponder` is
/// still `YES` — a session iOS 26 re-presents on its own (observed in #5959
/// on resume, and stranded over the feed in #6007 with no resume at all). An
/// explicit `TextInput.clearClient` is therefore sent before the hide — the
/// engine's own reset order — so every dismissal ends with client 0, first
/// responder resigned, and the input view removed: nothing left for UIKit to
/// re-present. In the healthy case both raw messages are no-ops racing the
/// framework's identical `clearClient` + scheduled hide, and the resign
/// delegate reports client 0, which the framework's client-id guard drops.
///
/// The [dispose] fallback runs only when no route-status change already
/// dismissed the keyboard and only when there was an enclosing modal route, so
/// it is scoped to a sheet actually tearing down rather than firing on every
/// disposal of a generic subtree.
///
/// Renders [child] unchanged; it only observes the route animation. No-op when
/// there is no enclosing modal route (e.g. a non-modal host).
class UnfocusOnSheetDismiss extends StatefulWidget {
  const UnfocusOnSheetDismiss({required this.child, super.key});

  /// The sheet subtree this widget wraps and renders unchanged.
  final Widget child;

  @override
  State<UnfocusOnSheetDismiss> createState() => _UnfocusOnSheetDismissState();
}

class _UnfocusOnSheetDismissState extends State<UnfocusOnSheetDismiss> {
  Animation<double>? _animation;
  bool _dismissed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animation = ModalRoute.of(context)?.animation;
    if (animation != _animation) {
      _animation?.removeStatusListener(_onStatusChanged);
      _animation = animation;
      _animation?.addStatusListener(_onStatusChanged);
    }
  }

  void _onStatusChanged(AnimationStatus status) {
    // reverse: pop-driven dismissals (scrim tap, drag release, back, pop),
    // fired while the comment field still holds focus. dismissed: a chrome
    // drag that reaches the route controller's 0.0 clamp skips reverse
    // entirely — see the class doc.
    if (status == AnimationStatus.reverse ||
        status == AnimationStatus.dismissed) {
      _dismissKeyboard(trigger: status.name);
    }
  }

  void _dismissKeyboard({required String trigger}) {
    // A single teardown can surface more than one signal (a pop emits reverse
    // then dismissed); dismiss exactly once so we don't re-send TextInput.hide.
    if (_dismissed) return;
    _dismissed = true;
    final primaryFocus = FocusManager.instance.primaryFocus;
    // Field forensics for the stranded-keyboard reports (#5959, #6007): the
    // trigger names the dismissal path, and the focus shape distinguishes a
    // healthy teardown (a focused field node) from the split-brain state
    // (focus already fell back to a scope, so unfocus() will be silent).
    Log.info(
      'Keyboard teardown (trigger=$trigger, focus=${switch (primaryFocus) {
        null => 'none',
        FocusScopeNode() => 'scope',
        FocusNode() => 'node',
      }}): unfocus + clearClient + hide',
      name: 'UnfocusOnSheetDismiss',
      category: LogCategory.ui,
    );
    primaryFocus?.unfocus();
    // unfocus() sends nothing over the text-input channel when the framework
    // side of the connection is already gone (platform-initiated teardown
    // during background/resume — see the class doc). clearClient zeroes the
    // engine's stale client id so the orphaned FlutterTextInputView stops
    // being re-presentable (#6007); hide then resigns the first responder and
    // removes the view. Both are harmless no-ops when the keyboard is already
    // down or the framework connection is healthy.
    unawaited(
      SystemChannels.textInput.invokeMethod<void>('TextInput.clearClient'),
    );
    unawaited(SystemChannels.textInput.invokeMethod<void>('TextInput.hide'));
  }

  @override
  void dispose() {
    _animation?.removeStatusListener(_onStatusChanged);
    // Fallback for the one teardown that emits no status change at all: a
    // route removed without a pop. Gated on `!_dismissed` so a status-handled
    // close doesn't fire it again, and on an enclosing modal route having
    // existed so a generic non-sheet host that never stranded a keyboard
    // doesn't yank global focus / hide another route's keyboard on disposal.
    if (!_dismissed && _animation != null) {
      _dismissKeyboard(trigger: 'dispose');
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
