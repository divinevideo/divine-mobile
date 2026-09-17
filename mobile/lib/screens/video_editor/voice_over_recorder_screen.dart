// ABOUTME: Voice-over recorder laid over the video editor's muted preview.
// ABOUTME: Close/done on top, video timeline + live waveform in the middle,
// ABOUTME: record below; drives the preview so each take plays over its spot.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/blocs/video_editor/voice_over/voice_over_cubit.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/upload_media_providers.dart';
import 'package:openvine/widgets/video_editor/video_editor_toolbar.dart';
import 'package:openvine/widgets/video_editor/voice_over/voice_over_video_timeline.dart';
import 'package:permissions_service/permissions_service.dart';

/// Full-screen recorder that lets the user capture one or more voice-over
/// takes without leaving the screen.
///
/// Pushed as a translucent route over the editor, so the muted preview shows
/// through behind the controls: when a take starts, the preview is seeked to
/// where that take will land and played, and it pauses again when the take
/// stops or the video runs out. That needs a [VideoEditorMainBloc] above the
/// route and the editor's [playTime]; without either the recorder simply has
/// no preview to drive.
///
/// Returns the recorded takes (as draft-local [AudioEvent]s) via
/// [Navigator.pop] when the user taps Done, or `null` when they close the
/// screen (in which case the recordings are discarded).
class VoiceOverRecorderScreen extends ConsumerWidget {
  /// Creates the voice-over recorder screen.
  const VoiceOverRecorderScreen({
    required this.availableDuration,
    this.priorTakeCount = 0,
    this.playTime,
    super.key,
  });

  /// Length of the video the voice-over will be laid over. Shown next to the
  /// recorded total so the user can tell when their audio runs too long.
  final Duration availableDuration;

  /// Number of voice-over takes already on the editor timeline, used only to
  /// continue the take numbering (e.g. "Recording 5"). The count and duration
  /// shown still reset to zero each time the recorder opens.
  final int priorTakeCount;

  /// The editor's fine-grained play time, on which the preview's end is
  /// detected so it can be paused before the composition loops. `null` when
  /// there is no preview behind the recorder.
  final ValueListenable<Duration>? playTime;

  /// Route name for navigation.
  static const routeName = 'voice-over-recorder';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Resolve l10n here (a valid place) and capture the AppLocalizations
    // instance — `create` runs in a one-time lifecycle that cannot listen to
    // the AppLocalizations InheritedWidget, but the captured object can be
    // formatted later when each take is named.
    final l10n = context.l10n;
    return BlocProvider<VoiceOverCubit>(
      create: (_) => VoiceOverCubit(
        permissionsService: const PermissionHandlerPermissionsService(),
        audioSessionService: ref.read(audioSessionServiceProvider),
        takeTitleBuilder: l10n.videoEditorVoiceOverTakeName,
        availableDuration: availableDuration,
        priorTakeCount: priorTakeCount,
      ),
      child: VoiceOverRecorderView(playTime: playTime),
    );
  }
}

/// UI for the voice-over recorder. Split from the page so it can be tested
/// in isolation with a mock [VoiceOverCubit].
class VoiceOverRecorderView extends StatelessWidget {
  /// Creates the voice-over recorder view.
  @visibleForTesting
  const VoiceOverRecorderView({this.playTime, super.key});

  /// See [VoiceOverRecorderScreen.playTime].
  final ValueListenable<Duration>? playTime;

  /// How much of the dark surface sits over the preview.
  ///
  /// Enough for the controls to read on any footage; low enough that a cut or
  /// a movement in the video is still easy to see while timing a line.
  @visibleForTesting
  static const double previewScrimAlpha = 0.7;

  @override
  Widget build(BuildContext context) {
    // The ground here is the footage, not an app surface, so this is fixed
    // media chrome (ui_theming.md): the recorder keeps the dark palette in
    // both appearances — a light scrim over a video reads as haze — and
    // lights the status bar icons to match.
    return Theme(
      data: VineTheme.theme,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: VideoEditorConstants.uiOverlayStyleFor(VineTheme.darkColors),
        child: Scaffold(
          // Translucent: the editor's preview plays on beneath this route.
          backgroundColor: VineTheme.darkColors.surface.withValues(
            alpha: previewScrimAlpha,
          ),
          body: _RecorderListeners(
            child: _EditorPreviewDriver(
              playTime: playTime,
              child: const Column(
                children: [
                  _Toolbar(),
                  Expanded(child: _RecorderBody()),
                  _RecordControls(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Screen-reader announcements for the recorder's state changes.
class _RecorderListeners extends StatelessWidget {
  const _RecorderListeners({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        // Announce when a take starts recording.
        BlocListener<VoiceOverCubit, VoiceOverState>(
          listenWhen: (previous, current) =>
              !previous.isRecording && current.isRecording,
          listener: (context, _) => _announce(
            context,
            context.l10n.videoEditorVoiceOverRecordingStarted,
          ),
        ),
        // Announce only when a take is saved (the count grew) — never on a
        // delete, which also changes recordingCount.
        BlocListener<VoiceOverCubit, VoiceOverState>(
          listenWhen: (previous, current) =>
              current.recordingCount > previous.recordingCount,
          listener: (context, _) => _announce(
            context,
            context.l10n.videoEditorVoiceOverRecordingSaved,
          ),
        ),
        // Announce when the recording first outgrows the video — the readout
        // also turns red, but color alone misses color-blind users.
        BlocListener<VoiceOverCubit, VoiceOverState>(
          listenWhen: (previous, current) =>
              !previous.isOverAvailable && current.isOverAvailable,
          listener: (context, _) =>
              _announce(context, context.l10n.videoEditorVoiceOverTooLong),
        ),
      ],
      child: child,
    );
  }

  void _announce(BuildContext context, String message) {
    unawaited(
      SemanticsService.sendAnnouncement(
        View.of(context),
        message,
        Directionality.of(context),
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar();

  @override
  Widget build(BuildContext context) {
    final hasLiveTake = context.select(
      (VoiceOverCubit c) => c.state.hasLiveTake,
    );
    final hasTakes = context.select((VoiceOverCubit c) => c.state.hasTakes);
    return VideoEditorToolbar(
      closeSemanticLabel: context.l10n
          .videoEditorDiscardToolChangesSemanticLabel(
            context.l10n.videoEditorVoiceOverLabel,
          ),
      doneSemanticLabel: context.l10n.videoEditorApplyToolChangesSemanticLabel(
        context.l10n.videoEditorVoiceOverLabel,
      ),
      onClose: () => _close(context),
      // Done waits for a stopped take to land, or it would leave without it.
      onDone: (!hasLiveTake && hasTakes) ? () => _done(context) : null,
    );
  }

  Future<void> _close(BuildContext context) async {
    await context.read<VoiceOverCubit>().discardAll();
    if (context.mounted) Navigator.of(context).pop();
  }

  void _done(BuildContext context) {
    final cubit = context.read<VoiceOverCubit>()..markCommitted();
    Navigator.of(context).pop<List<AudioEvent>>(cubit.state.takes);
  }
}

/// Drives the editor's preview behind the recorder from the recorder's state.
///
/// Bridges the two blocs from the UI, as `state_management.md` asks: the
/// [VoiceOverCubit] knows nothing about the editor. Every take starts with the
/// preview seeked to where that take lands and playing; it pauses the moment
/// the take is stopped, or just before the video runs out so the last frame
/// holds instead of the composition looping back to its start under a take
/// that is still recording. A stopped take leaves the preview on the frame it
/// stopped on — the next take seeks to its own start anyway, and a corrective
/// seek here read as the video jumping back — while a deleted take parks it
/// where the next one now starts.
///
/// Inert without a [VideoEditorMainBloc] above the route — there is nothing
/// to drive then.
class _EditorPreviewDriver extends StatefulWidget {
  const _EditorPreviewDriver({required this.playTime, required this.child});

  final ValueListenable<Duration>? playTime;
  final Widget child;

  @override
  State<_EditorPreviewDriver> createState() => _EditorPreviewDriverState();
}

class _EditorPreviewDriverState extends State<_EditorPreviewDriver> {
  /// How far before the video's end the preview is paused.
  ///
  /// The composition loops, and the player reports its position only every
  /// ~200ms; pausing on the reported end would race the wrap and sometimes
  /// freeze on the first frame instead of the last. Stopping this much early
  /// lands reliably on the closing frames.
  static const Duration _endGuard = Duration(milliseconds: 120);

  VideoEditorMainBloc? _editor;
  bool _isPreviewPlaying = false;

  @override
  void initState() {
    super.initState();
    _editor = context.read<VideoEditorMainBloc?>();
    if (_editor == null) return;
    widget.playTime?.addListener(_onPlayTime);
    // The editor was paused wherever it happened to be; show the frame the
    // first take will sit over.
    _seekTo(context.read<VoiceOverCubit>().state.nextTakeStart);
  }

  @override
  void didUpdateWidget(_EditorPreviewDriver oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_editor == null || identical(oldWidget.playTime, widget.playTime)) {
      return;
    }
    oldWidget.playTime?.removeListener(_onPlayTime);
    widget.playTime?.addListener(_onPlayTime);
  }

  @override
  void dispose() {
    widget.playTime?.removeListener(_onPlayTime);
    super.dispose();
  }

  void _onPlayTime() {
    if (!_isPreviewPlaying) return;
    final playTime = widget.playTime?.value;
    final available = context.read<VoiceOverCubit>().state.availableDuration;
    if (playTime == null || available <= Duration.zero) return;
    if (playTime >= available - _endGuard) _pause();
  }

  void _play(Duration from) {
    // The resume is a state change, so re-assert the pause first: after a
    // request the canvas dropped (its player was not ready yet) the bloc
    // already holds "not paused", and a bare resume would change nothing.
    _editor
      ?..add(const VideoEditorExternalPauseRequested(isPaused: true))
      ..add(VideoEditorSeekRequested(from))
      ..add(const VideoEditorExternalPauseRequested(isPaused: false));
    _isPreviewPlaying = true;
  }

  /// Catches the preview up once the editor's player is (back) in service.
  ///
  /// The canvas drops seek and play requests while its player is being
  /// rebuilt — after a visit to the metadata screen it stays released until
  /// the render there idles, which can be a while. Without this the recorder
  /// would sit on a still frame for the rest of its session.
  void _onPlayerReady() {
    final state = context.read<VoiceOverCubit>().state;
    if (_isPreviewPlaying) {
      _play(state.nextTakeStart + state.currentDuration);
    } else {
      _seekTo(state.nextTakeStart);
    }
  }

  void _pause() {
    _isPreviewPlaying = false;
    _editor?.add(const VideoEditorExternalPauseRequested(isPaused: true));
  }

  void _seekTo(Duration position) {
    _editor?.add(VideoEditorSeekRequested(position));
  }

  @override
  Widget build(BuildContext context) {
    if (_editor == null) return widget.child;
    return MultiBlocListener(
      listeners: [
        BlocListener<VoiceOverCubit, VoiceOverState>(
          listenWhen: (previous, current) =>
              previous.isRecording != current.isRecording,
          listener: (_, state) =>
              state.isRecording ? _play(state.nextTakeStart) : _pause(),
        ),
        BlocListener<VoiceOverCubit, VoiceOverState>(
          listenWhen: (previous, current) =>
              current.recordingCount < previous.recordingCount,
          listener: (_, state) => _seekTo(state.nextTakeStart),
        ),
        BlocListener<VideoEditorMainBloc, VideoEditorMainState>(
          listenWhen: (previous, current) =>
              !previous.isPlayerReady && current.isPlayerReady,
          listener: (_, _) => _onPlayerReady(),
        ),
      ],
      child: widget.child,
    );
  }
}

class _RecorderBody extends StatelessWidget {
  const _RecorderBody();

  @override
  Widget build(BuildContext context) {
    final isPermissionDenied = context.select(
      (VoiceOverCubit c) => c.state.status == VoiceOverStatus.permissionDenied,
    );
    return isPermissionDenied
        ? const _PermissionDenied()
        : const _WaveformPanel();
  }
}

class _PermissionDenied extends StatelessWidget {
  const _PermissionDenied();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 12,
          children: [
            DivineIcon(
              icon: .microphone,
              size: 48,
              color: context.vineColors.secondaryText,
            ),
            Text(
              l10n.videoEditorVoiceOverPermissionTitle,
              textAlign: .center,
              style: VineTheme.titleMediumFont(
                color: context.vineColors.primaryText,
              ),
            ),
            Text(
              l10n.videoEditorVoiceOverPermissionBody,
              textAlign: .center,
              style: VineTheme.bodyMediumFont(
                color: context.vineColors.secondaryText,
              ),
            ),
            const SizedBox(height: 4),
            DivineButton(
              label: l10n.videoEditorVoiceOverOpenSettings,
              type: .secondary,
              onPressed: () => context.read<VoiceOverCubit>().openSettings(),
            ),
          ],
        ),
      ),
    );
  }
}

class _WaveformPanel extends StatelessWidget {
  const _WaveformPanel();

  static const _textPadding = EdgeInsets.symmetric(horizontal: 24);

  @override
  Widget build(BuildContext context) {
    // A stopped take counts as live until it lands, or the hint would blink
    // back in for the moment between the two.
    final hasLiveTake = context.select(
      (VoiceOverCubit c) => c.state.hasLiveTake,
    );
    final recordingCount = context.select(
      (VoiceOverCubit c) => c.state.recordingCount,
    );
    final hasVideo = context.select(
      (VoiceOverCubit c) => c.state.availableDuration > Duration.zero,
    );
    final l10n = context.l10n;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 16,
        children: [
          if (hasVideo)
            const Padding(
              padding: _textPadding,
              child: RepaintBoundary(
                child: SizedBox(
                  height: VoiceOverVideoTimeline.height,
                  width: double.infinity,
                  child: VoiceOverVideoTimeline(),
                ),
              ),
            ),
          const RepaintBoundary(
            child: SizedBox(
              height: 120,
              width: double.infinity,
              child: _Wave(),
            ),
          ),
          // Always in the column, so the panel keeps its height — and its
          // centred position — from the first tap on record. Before any take
          // it reads 0:00 over the video length.
          const _TimeReadout(),
          Padding(
            padding: _textPadding,
            child: Text(
              l10n.videoEditorVoiceOverRecordingsCount(recordingCount),
              style: VineTheme.bodyMediumFont(
                color: context.vineColors.secondaryText,
              ),
            ),
          ),
          // Hidden once the first take starts, but its space is kept for the
          // same reason.
          Visibility(
            visible: !hasLiveTake && recordingCount == 0,
            maintainSize: true,
            maintainAnimation: true,
            maintainState: true,
            child: Padding(
              padding: _textPadding,
              child: Text(
                l10n.videoEditorVoiceOverHint,
                textAlign: .center,
                style: VineTheme.bodySmallFont(
                  color: context.vineColors.mutedText,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Wave extends StatefulWidget {
  const _Wave();

  @override
  State<_Wave> createState() => _WaveState();
}

class _WaveState extends State<_Wave> with SingleTickerProviderStateMixin {
  // Phase-locked 0->1 scroll fraction between two amplitude samples. Restarted
  // on every new sample so the strip glides one bar to the left and parks
  // (clamped at 1) if the next sample is late — never running off-screen. The
  // glide spans exactly one amplitude interval so each new bar slides fully in.
  late final AnimationController _scroll;

  @override
  void initState() {
    super.initState();
    _scroll = AnimationController(
      vsync: this,
      duration: VoiceOverCubit.amplitudeInterval,
    );
  }

  void _onState(VoiceOverState state, {required bool reduceMotion}) {
    // Honor the reduced-motion preference: park the strip so new bars appear
    // in place instead of gliding (accessibility.md).
    if (state.isRecording && !reduceMotion) {
      _scroll.forward(from: 0);
    } else {
      _scroll
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bars = context.select((VoiceOverCubit c) => c.state.waveformBars);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return BlocListener<VoiceOverCubit, VoiceOverState>(
      // currentDuration advances once per amplitude sample, so it is a
      // reliable "new sample" signal even after the bar buffer hits its cap
      // (where the list length stops changing).
      listenWhen: (previous, current) =>
          previous.isRecording != current.isRecording ||
          previous.currentDuration != current.currentDuration,
      listener: (_, state) => _onState(state, reduceMotion: reduceMotion),
      child: ExcludeSemantics(
        child: CustomPaint(
          painter: _VoiceOverWaveformPainter(
            bars: bars,
            color: context.vineColors.accentPositive,
            scroll: _scroll,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

/// Shows the combined recorded time over the available video length, e.g.
/// `0:12 / 0:06`, turning red once the audio is longer than the video.
class _TimeReadout extends StatelessWidget {
  const _TimeReadout();

  @override
  Widget build(BuildContext context) {
    final total = context.select(
      (VoiceOverCubit c) => c.state.totalRecordedDuration,
    );
    final available = context.select(
      (VoiceOverCubit c) => c.state.availableDuration,
    );
    final isOver = context.select(
      (VoiceOverCubit c) => c.state.isOverAvailable,
    );
    final readout = Text(
      '${_formatClock(total)} / ${_formatClock(available)}',
      style: VineTheme.titleLargeFont(
        color: isOver ? VineTheme.error : context.vineColors.onSurface,
      ),
    );
    if (!isOver) return readout;
    // Pair the red color with a shape cue so the over-length warning reaches
    // color-blind users too (accessibility.md). The screen-reader announcement
    // carries the meaning, so the icon itself is excluded from semantics.
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 6,
      children: [
        const ExcludeSemantics(
          child: DivineIcon(icon: .warning, size: 20, color: VineTheme.error),
        ),
        readout,
      ],
    );
  }
}

String _formatClock(Duration duration) {
  final minutes = duration.inMinutes.remainder(60).toString();
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

class _RecordControls extends StatelessWidget {
  const _RecordControls();

  @override
  Widget build(BuildContext context) {
    final isPermissionDenied = context.select(
      (VoiceOverCubit c) => c.state.status == VoiceOverStatus.permissionDenied,
    );
    // While denied, the body shows the "Open Settings" call to action; hide the
    // record button so it doesn't compete with it. Tapping it would only
    // silently re-request and re-emit the denial.
    if (isPermissionDenied) return const SizedBox.shrink();
    final hasLiveTake = context.select(
      (VoiceOverCubit c) => c.state.hasLiveTake,
    );
    final hasTakes = context.select((VoiceOverCubit c) => c.state.hasTakes);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 8,
          children: [
            const _RecordButton(),
            SizedBox(
              height: 40,
              child: (hasTakes && !hasLiveTake)
                  ? TextButton(
                      onPressed: () =>
                          context.read<VoiceOverCubit>().deleteLastTake(),
                      child: Text(
                        context.l10n.videoEditorVoiceOverDeleteLast,
                        style: VineTheme.labelLargeFont(
                          color: context.vineColors.secondaryText,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordButton extends StatelessWidget {
  const _RecordButton();

  static const _size = 76.0;

  @override
  Widget build(BuildContext context) {
    // Keeps the stop shape while a stopped take is still landing, so the
    // button does not offer a new take the cubit would ignore.
    final isRecording = context.select(
      (VoiceOverCubit c) => c.state.hasLiveTake,
    );
    final l10n = context.l10n;
    return Semantics(
      button: true,
      label: isRecording
          ? l10n.videoEditorVoiceOverStopSemanticLabel
          : l10n.videoEditorVoiceOverRecordSemanticLabel,
      child: GestureDetector(
        onTap: () => context.read<VoiceOverCubit>().toggleRecording(),
        child: Container(
          width: _size,
          height: _size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: context.vineColors.onSurface, width: 4),
          ),
          child: Center(
            child: AnimatedContainer(
              // Skip the morph animation under the reduced-motion preference.
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 200),
              width: isRecording ? 30 : 60,
              height: isRecording ? 30 : 60,
              decoration: BoxDecoration(
                color: VineTheme.error,
                borderRadius: BorderRadius.circular(isRecording ? 8 : 30),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints the rolling live amplitude buffer as centered vertical bars.
///
/// Unlike `StereoWaveformPainter` (which renders a fully-extracted file's
/// channels), this draws the most recent [bars] streamed from the recorder.
/// Bars are positioned **relative to the buffer** — the newest sits at the
/// right edge — so the strip never runs off-screen once the buffer hits its
/// cap. [scroll] is a `0->1` fraction that slides every bar left by one step
/// between samples for smooth motion.
class _VoiceOverWaveformPainter extends CustomPainter {
  _VoiceOverWaveformPainter({
    required this.bars,
    required this.color,
    required this.scroll,
  }) : super(repaint: scroll);

  final List<double> bars;
  final Color color;
  final Animation<double> scroll;

  static const _barWidth = 3.0;
  static const _gap = 3.0;
  static const _minBarHeight = 2.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty) return;

    final centerY = size.height / 2;
    const step = _barWidth + _gap;
    final fraction = scroll.value;
    final paint = Paint()
      ..color = color
      ..strokeWidth = _barWidth
      ..strokeCap = StrokeCap.round;

    // Walk from the newest bar (right edge) toward older ones (left). Each
    // bar sits `(fromRight + fraction)` steps left of the right edge, so the
    // whole strip glides left as `fraction` runs 0 -> 1.
    final lastIndex = bars.length - 1;
    for (var i = lastIndex; i >= 0; i--) {
      final fromRight = lastIndex - i;
      final x = size.width - (fromRight + fraction) * step - _barWidth / 2;
      if (x < -_barWidth) break;
      final amplitude = bars[i].clamp(0.0, 1.0);
      final barHeight =
          _minBarHeight + amplitude * (size.height - _minBarHeight);
      final half = barHeight / 2;
      canvas.drawLine(
        Offset(x, centerY - half),
        Offset(x, centerY + half),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_VoiceOverWaveformPainter oldDelegate) =>
      oldDelegate.bars != bars ||
      oldDelegate.color != color ||
      oldDelegate.scroll != scroll;
}
