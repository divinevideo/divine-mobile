// ABOUTME: Shows reviewed public Classics during the first guest welcome.
// ABOUTME: Drops all in-memory playback authority on expiry or background.

import 'dart:async';
import 'dart:math';

import 'package:divine_ui/divine_ui.dart';
import 'package:divine_video_player/divine_video_player.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';
import 'package:openvine/features/guest_classics/guest_classics_adaptation.dart';
import 'package:openvine/features/guest_classics/guest_classics_manifest.dart';
import 'package:openvine/features/guest_classics/guest_classics_providers.dart';
import 'package:openvine/l10n/l10n.dart';

class GuestClassicsEntry extends StatefulWidget {
  const GuestClassicsEntry({
    required this.load,
    required this.welcome,
    required this.now,
    this.onObservation,
    super.key,
  });

  final Future<GuestClassicsManifest?> Function(
    http.Client, {
    required bool muted,
  })
  load;
  final Widget Function(VoidCallback? open) welcome;
  final DateTime Function() now;
  final ValueChanged<GuestClassicsObservation>? onObservation;

  @override
  State<GuestClassicsEntry> createState() => _GuestClassicsEntryState();
}

class _GuestClassicsEntryState extends State<GuestClassicsEntry>
    with WidgetsBindingObserver {
  GuestClassicsManifest? _manifest;
  http.Client? _loading;
  Timer? _expiry;
  bool _viewing = false;
  bool _muted = true;
  bool _inactive = false;
  final _muteRequests = ValueNotifier<int>(0);
  final _seen = <String>{};
  final _unplayable = <String>{};
  List<GuestClassic> _clips = const [];
  var _adaptation = GuestClassicsAdaptation();
  var _queueGeneration = Object();
  int _page = 0;
  int _furthestPage = 0;
  int _preparedThrough = 0;

  void _replaceClips(List<GuestClassic> clips) {
    _clips = clips;
    _queueGeneration = Object();
    _page = 0;
    _furthestPage = 0;
    _preparedThrough = 0;
    _adaptation.resetPlayback();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _inactive = lifecycle == AppLifecycleState.inactive;
    if (lifecycle == null || lifecycle == AppLifecycleState.resumed) {
      unawaited(_load(muted: _muted, retire: false));
    }
  }

  void _retire() {
    _loading?.close();
    _loading = null;
    _expiry?.cancel();
    _expiry = null;
    _manifest = null;
    _adaptation = GuestClassicsAdaptation();
    _replaceClips(const []);
  }

  void _resetToWelcome() {
    _viewing = false;
    _muted = true;
    _retire();
  }

  void _close() {
    _muteRequests.value++;
    _viewing = false;
    _muted = true;
    unawaited(_refresh());
  }

  Future<void> _refresh() => _load(muted: _muted, retire: true);

  Future<void> _load({
    required bool muted,
    required bool retire,
    bool keepCurrent = false,
  }) async {
    final currentId = keepCurrent && _clips.isNotEmpty
        ? _clips[_page].id
        : null;
    if (retire) setState(_retire);
    _loading?.close();
    final client = http.Client();
    _loading = client;
    GuestClassicsManifest? manifest;
    try {
      manifest = await widget.load(client, muted: muted);
    } on Exception {
      // Preserve welcome on startup and the current authorized mode on a switch.
    } finally {
      client.close();
    }
    if (!mounted || _loading != client) return;
    _loading = null;
    if (manifest == null) {
      if (retire) setState(_resetToWelcome);
      return;
    }
    final remaining = manifest.expiresAt.difference(widget.now());
    if (remaining <= Duration.zero) {
      if (retire) setState(_resetToWelcome);
      return;
    }
    // A new manifest starts a new queue in the approved mode. On a sound change
    // or expiry refresh, the current clip continues only if the new manifest
    // independently admits it.
    final current = manifest.clips.where((clip) => clip.id == currentId);
    final clips = [
      ...current,
      ...manifest.clips.where(
        (clip) =>
            clip.id != currentId &&
            !_seen.contains(clip.id) &&
            !_unplayable.contains(clip.id),
      ),
    ];
    if (clips.isEmpty) {
      if (retire) setState(_resetToWelcome);
      return;
    }
    _expiry?.cancel();
    _expiry = Timer(remaining, _onExpiry);
    setState(() {
      _manifest = manifest;
      _adaptation = GuestClassicsAdaptation();
      _replaceClips(clips);
      _muted = muted;
    });
  }

  void _onExpiry() {
    if (!mounted) return;
    if (_inactive) {
      setState(_resetToWelcome);
      return;
    }
    unawaited(_load(muted: _muted, retire: true, keepCurrent: _viewing));
  }

  void _toggleSound() {
    if (_muted) {
      unawaited(_load(muted: false, retire: false, keepCurrent: true));
      return;
    }
    // Stop sound immediately. Muted viewing needs its own current manifest.
    _muteRequests.value++;
    _muted = true;
    unawaited(_load(muted: true, retire: true, keepCurrent: true));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        final needsRefresh =
            _manifest == null || !_manifest!.expiresAt.isAfter(widget.now());
        if (_inactive) setState(() => _inactive = false);
        if (needsRefresh) unawaited(_refresh());
      case AppLifecycleState.inactive:
        if (!_inactive) setState(() => _inactive = true);
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _inactive = false;
        if (_viewing) _muteRequests.value++;
        setState(_resetToWelcome);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _retire();
    _muteRequests.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final manifest = _manifest;
    if (manifest == null || !manifest.expiresAt.isAfter(widget.now())) {
      if (_viewing && _loading != null) {
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _close();
          },
          child: Scaffold(
            backgroundColor: VineTheme.backgroundColor,
            body: Stack(
              fit: StackFit.expand,
              children: [
                const Center(child: DivineCircularProgressIndicator()),
                SafeArea(
                  child: Align(
                    alignment: Alignment.topRight,
                    child: DivineIconButton(
                      type: DivineIconButtonType.ghostOverMedia,
                      semanticLabel: context.l10n.commonClose,
                      tooltip: context.l10n.commonClose,
                      icon: DivineIconName.x,
                      onPressed: _close,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
      return widget.welcome(null);
    }
    if (!_viewing) {
      return widget.welcome(() => setState(() => _viewing = true));
    }
    final clip = _clips[_page];
    final generation = _queueGeneration;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        backgroundColor: VineTheme.backgroundColor,
        body: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              key: ObjectKey(generation),
              scrollDirection: Axis.vertical,
              itemCount: _clips.length,
              onPageChanged: (page) {
                if (_manifest != manifest ||
                    _queueGeneration != generation ||
                    !_viewing ||
                    page == _page ||
                    page >= _clips.length) {
                  return;
                }
                setState(() {
                  _adaptation.leave(_clips[_page]);
                  _page = page;
                  _furthestPage = max(_furthestPage, page);
                  _clips = _adaptation.orderTail(
                    _clips,
                    starterOrder: manifest.clips,
                    keep: max(_furthestPage, _preparedThrough) + 1,
                  );
                });
                widget.onObservation?.call(GuestClassicsObservation.swipe);
              },
              itemBuilder: (_, index) {
                if (index != _page) return const SizedBox.shrink();
                return _GuestPlayer(
                  key: ValueKey(clip.id),
                  clip: clip,
                  muted: _muted,
                  paused: _inactive,
                  muteRequests: _muteRequests,
                  allowed: () =>
                      mounted &&
                      _viewing &&
                      _manifest == manifest &&
                      _queueGeneration == generation &&
                      _clips.isNotEmpty &&
                      _clips[_page].id == clip.id &&
                      manifest.expiresAt.isAfter(widget.now()) &&
                      _page == index,
                  progress: _adaptation.observe,
                  firstFrame: () {
                    if (_seen.add(clip.id)) {
                      widget.onObservation?.call(
                        GuestClassicsObservation.firstFrame,
                      );
                    }
                    if (index + 1 < _clips.length) {
                      _preparedThrough = max(_preparedThrough, index + 1);
                      unawaited(
                        DivineVideoPlayerController.preload([
                          VideoClip.network(
                            _clips[index + 1].url.toString(),
                          ),
                        ]).catchError((Object _) {}),
                      );
                    }
                  },
                  failed: () {
                    if (mounted &&
                        _manifest == manifest &&
                        _queueGeneration == generation &&
                        _page == index &&
                        _clips.isNotEmpty &&
                        _clips[index].id == clip.id) {
                      setState(() {
                        _unplayable.add(clip.id);
                        _replaceClips(_clips.skip(index + 1).toList());
                        if (_clips.isEmpty) _resetToWelcome();
                      });
                    }
                  },
                );
              },
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: DivineIconButton(
                  type: DivineIconButtonType.ghostOverMedia,
                  semanticLabel: context.l10n.commonClose,
                  tooltip: context.l10n.commonClose,
                  icon: DivineIconName.x,
                  onPressed: _close,
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: ColoredBox(
                  color: VineTheme.scrim65,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            clip.attribution,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: VineTheme.bodyMediumFont(
                              color: VineTheme.whiteText,
                            ),
                          ),
                        ),
                        DivineIconButton(
                          type: DivineIconButtonType.ghostOverMedia,
                          semanticLabel: _muted
                              ? context.l10n.videoPlayerUnmute
                              : context.l10n.videoPlayerMute,
                          tooltip: _muted
                              ? context.l10n.videoPlayerUnmute
                              : context.l10n.videoPlayerMute,
                          onPressed: _toggleSound,
                          icon: _muted
                              ? DivineIconName.speakerSimpleSlash
                              : DivineIconName.speakerHigh,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuestPlayer extends StatefulWidget {
  const _GuestPlayer({
    required this.clip,
    required this.muted,
    required this.paused,
    required this.muteRequests,
    required this.allowed,
    required this.progress,
    required this.firstFrame,
    required this.failed,
    super.key,
  });
  final GuestClassic clip;
  final bool muted;
  final bool paused;
  final ValueNotifier<int> muteRequests;
  final bool Function() allowed;
  final ValueChanged<DivineVideoPlayerState> progress;
  final VoidCallback firstFrame;
  final VoidCallback failed;
  @override
  State<_GuestPlayer> createState() => _GuestPlayerState();
}

class _GuestPlayerState extends State<_GuestPlayer> {
  final _player = DivineVideoPlayerController(
    debugLabel: 'guest-classic',
    useTexture: true,
  );
  StreamSubscription<DivineVideoPlayerState>? _events;
  Timer? _watchdog;
  bool _ready = false;
  bool _nativeFrame = false;
  bool _reported = false;
  bool _presentationPending = false;
  double _aspectRatio = 1;

  @override
  void initState() {
    super.initState();
    widget.muteRequests.addListener(_silence);
    unawaited(_start());
  }

  @override
  void didUpdateWidget(covariant _GuestPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.paused == widget.paused) return;
    if (widget.paused) {
      _watchdog?.cancel();
      _watchdog = null;
    } else if (!_reported) {
      _watchdog ??= Timer(const Duration(seconds: 6), _fail);
    }
    if (_player.isInitialized) {
      unawaited(
        (widget.paused ? _player.pause() : _player.play()).catchError(
          (Object _) => _fail(),
        ),
      );
    }
  }

  void _silence() {
    if (_player.isInitialized) {
      unawaited(_player.setVolume(0).catchError((Object _) => _fail()));
    }
  }

  bool get _allowed => mounted && widget.allowed();

  Future<void> _start() async {
    if (!widget.paused) {
      _watchdog = Timer(const Duration(seconds: 6), _fail);
    }
    try {
      await _player.initialize();
      if (!_allowed) return;
      _events = _player.stateStream.listen((state) {
        if (!_allowed) return;
        if (state.hasError) return _fail();
        if (state.aspectRatio.isFinite &&
            state.aspectRatio > 0 &&
            state.aspectRatio != _aspectRatio) {
          setState(() => _aspectRatio = state.aspectRatio);
        }
        if (state.isFirstFrameRendered) {
          _nativeFrame = true;
          _reportPresentation();
        }
        if (mounted && _reported && ModalRoute.isCurrentOf(context) == true) {
          widget.progress(state);
        }
      }, onError: (Object _) => _fail());
      await _player.setSource(VideoClip.network(widget.clip.url.toString()));
      if (!_allowed) return;
      await _player.setLooping(looping: true);
      if (!_allowed) return;
      await _player.setVolume(widget.muted ? 0 : 1);
      if (!_allowed) return;
      setState(() => _ready = true);
      _reportPresentation();
      if (!_allowed || widget.paused) return;
      await _player.play();
    } on Object {
      _fail();
    }
  }

  void _reportPresentation() {
    if (!_nativeFrame || !_ready || _reported || _presentationPending) return;
    _presentationPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _presentationPending = false;
      if (!_allowed || _reported || ModalRoute.isCurrentOf(context) != true) {
        return;
      }
      final box = context.findRenderObject();
      if (box is! RenderBox || !box.attached || !box.hasSize) return;
      final frame = box.localToGlobal(Offset.zero) & box.size;
      if (!frame.overlaps(Offset.zero & MediaQuery.sizeOf(context))) return;
      _reported = true;
      _watchdog?.cancel();
      widget.firstFrame();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _fail() {
    if (_allowed) widget.failed();
  }

  @override
  void dispose() {
    widget.muteRequests.removeListener(_silence);
    _watchdog?.cancel();
    unawaited(_events?.cancel());
    unawaited(_player.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _ready
      ? Center(
          child: AspectRatio(
            aspectRatio: _aspectRatio,
            child: DivineVideoPlayer(controller: _player),
          ),
        )
      : const Center(child: DivineCircularProgressIndicator());
}
