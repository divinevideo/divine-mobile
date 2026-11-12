import 'package:flutter/widgets.dart';

/// Shared shutter gesture handling for recorder surfaces that support both
/// tap-to-toggle and long-press-to-record on the same target.
///
/// Contract:
/// - All recorder shutter surfaces that combine tap and long-press gestures
///   must route through this widget.
/// - A tap-started recording must never be stopped by an incidental
///   long-press release.
/// - In press-down mode, a press on an already-active recording (started by
///   any other source — volume key, BLE remote, toggle, or a dropped release)
///   must still stop it, so the button is never a dead control.
///
/// This encodes the issue #4409 regression guard once so new shutter surfaces
/// inherit the same behavior by default instead of reimplementing it.
class ShutterGestureDetector extends StatefulWidget {
  const ShutterGestureDetector({
    required this.child,
    required this.isEnabled,
    required this.isRecording,
    required this.onTapToggle,
    required this.onLongPressStartRecording,
    required this.onLongPressStopRecording,
    super.key,
    this.isLongPressSupported = true,
    this.startsRecordingOnPressDown = false,
    this.onLongPressZoomStart,
    this.onLongPressMoveUpdate,
    this.behavior,
  });

  final Widget child;
  final bool isEnabled;
  final bool isRecording;
  final bool isLongPressSupported;
  final bool startsRecordingOnPressDown;
  final VoidCallback onTapToggle;
  final VoidCallback onLongPressStartRecording;
  final VoidCallback onLongPressStopRecording;

  /// Fires at the start of every long-press gesture, before any move updates
  /// and even when the press lands on an already-active recording. Lets the
  /// host capture the zoom level that [onLongPressMoveUpdate] drags anchor to.
  final VoidCallback? onLongPressZoomStart;
  final GestureLongPressMoveUpdateCallback? onLongPressMoveUpdate;
  final HitTestBehavior? behavior;

  @override
  State<ShutterGestureDetector> createState() => _ShutterGestureDetectorState();
}

class _ShutterGestureDetectorState extends State<ShutterGestureDetector> {
  bool _startedByLongPress = false;
  bool _startedByPressDown = false;

  void _handleTap() {
    _startedByLongPress = false;
    _startedByPressDown = false;
    widget.onTapToggle();
  }

  void _handleTapDown(TapDownDetails _) {
    if (widget.isRecording) {
      // A fresh press-down while recording is already active means this
      // gesture didn't start it (volume key, BLE remote, toggle, or a release
      // event that never arrived). Without stopping here the press-down button
      // is a dead control: _handlePressEnd bails on !_startedByPressDown and
      // tap / long-press handlers are disabled in press-down mode.
      _startedByPressDown = false;
      widget.onLongPressStopRecording();
      return;
    }
    _startedByPressDown = true;
    widget.onLongPressStartRecording();
  }

  void _handlePressEnd() {
    if (!_startedByPressDown) return;
    _startedByPressDown = false;
    widget.onLongPressStopRecording();
  }

  void _handleLongPressStart(LongPressStartDetails _) {
    // Anchor the zoom base for this gesture before the recording-state gate,
    // so a long-press that only zooms (recording already active) still
    // captures it.
    widget.onLongPressZoomStart?.call();
    if (widget.isRecording) return;
    _startedByLongPress = true;
    widget.onLongPressStartRecording();
  }

  void _handleLongPressUp() {
    if (!_startedByLongPress) return;
    _startedByLongPress = false;
    widget.onLongPressStopRecording();
  }

  @override
  Widget build(BuildContext context) {
    final usePressDownRecording =
        widget.isEnabled && widget.startsRecordingOnPressDown;

    // A screen reader activates a control with one synthetic tap, which the
    // detector would replay as press-down and release in the same instant:
    // in press-down mode the take starts and stops at once. Activation
    // toggles instead, and the long-press action is left out — it would also
    // start and stop in one go.
    return Semantics(
      onTap: widget.isEnabled ? _handleTap : null,
      child: GestureDetector(
        excludeFromSemantics: true,
        behavior: widget.behavior,
        onTapDown: usePressDownRecording ? _handleTapDown : null,
        onTapUp: usePressDownRecording ? (_) => _handlePressEnd() : null,
        onTapCancel: usePressDownRecording ? _handlePressEnd : null,
        onTap: widget.isEnabled && !widget.startsRecordingOnPressDown
            ? _handleTap
            : null,
        onLongPressStart:
            widget.isEnabled &&
                widget.isLongPressSupported &&
                !widget.startsRecordingOnPressDown
            ? _handleLongPressStart
            : null,
        onLongPressMoveUpdate:
            widget.isRecording &&
                widget.isLongPressSupported &&
                !widget.startsRecordingOnPressDown
            ? widget.onLongPressMoveUpdate
            : null,
        onLongPressUp:
            widget.isLongPressSupported && !widget.startsRecordingOnPressDown
            ? _handleLongPressUp
            : null,
        child: widget.child,
      ),
    );
  }
}
