import 'dart:async';

import 'package:challenge_protocol/challenge_protocol.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:divine_video_player/divine_video_player.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart' show VideoEvent;
import 'package:nostr_sdk/event.dart';
import 'package:openvine/l10n/l10n.dart';

/// Plays only the pinned signed revision. No latest/stable-ID resolver runs.
/// A current policy lease expiring or an account hide immediately tears it down.
class ChallengePlayback extends StatefulWidget {
  const ChallengePlayback({
    required this.video,
    required this.allowed,
    this.onAvailabilityChanged,
    super.key,
  });
  final void Function(bool)? onAvailabilityChanged;
  final NostrEvent video;
  final bool Function(NostrEvent) allowed;
  @override
  State<ChallengePlayback> createState() => _ChallengePlaybackState();
}

class _ChallengePlaybackState extends State<ChallengePlayback>
    with WidgetsBindingObserver {
  final _controller = DivineVideoPlayerController(
    debugLabel: 'challenge-pinned',
    useTexture: true,
  );
  Timer? _policy;
  Future<void>? _initializing;
  StreamSubscription<DivineVideoPlayerState>? _playerState;
  bool _reportedReady = false;
  bool _ready = false;
  bool _failed = false;
  bool _retired = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _policy = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!widget.allowed(widget.video)) _retire();
    });
    unawaited(_start());
  }

  Future<void> _start() async {
    try {
      if (!widget.allowed(widget.video)) return _retire();
      final video = VideoEvent.fromNostrEvent(
        Event.fromJson(widget.video.toJson()),
      );
      final url = video.videoUrl;
      if (url == null) return _retire();
      _initializing = _controller.initialize();
      await _initializing;
      if (_retired || !mounted || !widget.allowed(widget.video)) {
        return _retire();
      }
      _playerState = _controller.stateStream.listen((state) {
        if (state.hasError) {
          _retire();
          return;
        }
        if (state.isFirstFrameRendered && !_reportedReady) {
          _reportedReady = true;
          widget.onAvailabilityChanged?.call(true);
        }
      });
      await _controller.setSource(VideoClip.network(url));
      if (_retired || !mounted || !widget.allowed(widget.video)) {
        return _retire();
      }
      await _controller.setLooping(looping: true);
      await _controller.play();
      if (mounted && !_retired) setState(() => _ready = true);
    } on Object {
      _retire();
    }
  }

  void _retire() {
    if (_retired) return;
    _retired = true;
    _policy?.cancel();
    unawaited(_playerState?.cancel());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onAvailabilityChanged?.call(false);
    });
    unawaited(_disposeController());
    if (mounted) {
      setState(() {
        _failed = true;
        _ready = false;
      });
    }
  }

  Future<void> _disposeController() async {
    // Native creation can finish after this screen retires. The controller
    // only releases its native player once initialization has completed.
    try {
      await _initializing;
    } on Object {
      // Failed creation still needs the controller's stream cleanup.
    }
    await _controller.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _retire();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _policy?.cancel();
    if (!_retired) {
      _retired = true;
      unawaited(_disposeController());
    }
    unawaited(_playerState?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 1,
    child: _failed
        ? Center(child: Text(context.l10n.challengePreviewUnavailable))
        : _ready
        ? DivineVideoPlayer(controller: _controller)
        : const Center(child: DivineCircularProgressIndicator()),
  );
}
