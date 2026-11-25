// ABOUTME: Keyboard commands for a video feed: arrows page, Space plays or
// ABOUTME: pauses, M mutes; the macOS menu bar invokes the same intents

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Moves the focused feed to the previous video.
class PreviousVideoIntent extends Intent {
  /// Creates a [PreviousVideoIntent].
  const PreviousVideoIntent();
}

/// Moves the focused feed to the next video.
class NextVideoIntent extends Intent {
  /// Creates a [NextVideoIntent].
  const NextVideoIntent();
}

/// Plays or pauses the video the focused feed shows.
class TogglePlaybackIntent extends Intent {
  /// Creates a [TogglePlaybackIntent].
  const TogglePlaybackIntent();
}

/// Mutes or unmutes feed playback.
class ToggleMuteIntent extends Intent {
  /// Creates a [ToggleMuteIntent].
  const ToggleMuteIntent();
}

/// The key for each feed command, shared with the macOS menu bar so the menu
/// shows the keys that work.
///
/// Held keys do not repeat: a held arrow would otherwise start a player for
/// every video it skips through.
abstract final class FeedShortcutKeys {
  static const previousVideo = SingleActivator(
    LogicalKeyboardKey.arrowUp,
    includeRepeats: false,
  );
  static const nextVideo = SingleActivator(
    LogicalKeyboardKey.arrowDown,
    includeRepeats: false,
  );
  static const togglePlayback = SingleActivator(
    LogicalKeyboardKey.space,
    includeRepeats: false,
  );
  static const toggleMute = SingleActivator(
    LogicalKeyboardKey.keyM,
    includeRepeats: false,
  );
}

/// Gives a video feed its keyboard commands: the up and down arrows move to
/// the previous and next video, Space plays or pauses, and M mutes.
///
/// The commands work while the feed itself holds keyboard focus. It takes
/// focus when it becomes the active feed and when it is clicked with a mouse
/// or trackpad, but never from a text field someone is typing in. While a
/// control inside the feed has focus, the keys keep their usual meaning, such
/// as Space pressing a focused button.
class FeedKeyboardShortcuts extends StatefulWidget {
  const FeedKeyboardShortcuts({
    required this.isActive,
    required this.onPreviousVideo,
    required this.onNextVideo,
    required this.onTogglePlayback,
    required this.onToggleMute,
    required this.child,
    super.key,
  });

  /// Whether this is the feed on screen that should take keyboard focus.
  final bool isActive;

  /// Called for [PreviousVideoIntent].
  final VoidCallback onPreviousVideo;

  /// Called for [NextVideoIntent].
  final VoidCallback onNextVideo;

  /// Called for [TogglePlaybackIntent].
  final VoidCallback onTogglePlayback;

  /// Called for [ToggleMuteIntent].
  final VoidCallback onToggleMute;

  /// The feed.
  final Widget child;

  @override
  State<FeedKeyboardShortcuts> createState() => _FeedKeyboardShortcutsState();
}

class _FeedKeyboardShortcutsState extends State<FeedKeyboardShortcuts> {
  final _focusNode = FocusNode(debugLabel: 'FeedKeyboardShortcuts');
  late final Map<Type, Action<Intent>> _actions = {
    PreviousVideoIntent: _FeedAction<PreviousVideoIntent>(
      _focusNode,
      () => widget.onPreviousVideo(),
    ),
    NextVideoIntent: _FeedAction<NextVideoIntent>(
      _focusNode,
      () => widget.onNextVideo(),
    ),
    TogglePlaybackIntent: _FeedAction<TogglePlaybackIntent>(
      _focusNode,
      () => widget.onTogglePlayback(),
    ),
    ToggleMuteIntent: _FeedAction<ToggleMuteIntent>(
      _focusNode,
      () => widget.onToggleMute(),
    ),
  };

  @override
  void initState() {
    super.initState();
    if (widget.isActive) _claimFocusAfterBuild();
  }

  @override
  void didUpdateWidget(FeedKeyboardShortcuts oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) _claimFocusAfterBuild();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _claimFocusAfterBuild() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.isActive || _isTyping()) return;
      _focusNode.requestFocus();
    });
  }

  /// Whether keyboard focus is in a text field, which keeps it.
  static bool _isTyping() =>
      FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<EditableText>() !=
      null;

  void _claimFocusOnClick(PointerDownEvent event) {
    if (event.kind == PointerDeviceKind.mouse ||
        event.kind == PointerDeviceKind.trackpad) {
      _focusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        FeedShortcutKeys.previousVideo: PreviousVideoIntent(),
        FeedShortcutKeys.nextVideo: NextVideoIntent(),
        FeedShortcutKeys.togglePlayback: TogglePlaybackIntent(),
        FeedShortcutKeys.toggleMute: ToggleMuteIntent(),
      },
      child: Actions(
        actions: _actions,
        child: Focus(
          focusNode: _focusNode,
          // The page view already describes the feed to screen readers.
          includeSemantics: false,
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: _claimFocusOnClick,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// A feed command, enabled only while the feed itself holds focus so a
/// focused control inside it keeps its own keys.
class _FeedAction<T extends Intent> extends Action<T> {
  _FeedAction(this._focusNode, this._onInvoke);

  final FocusNode _focusNode;
  final VoidCallback _onInvoke;

  @override
  bool isEnabled(T intent) => _focusNode.hasPrimaryFocus;

  @override
  void invoke(T intent) => _onInvoke();
}
