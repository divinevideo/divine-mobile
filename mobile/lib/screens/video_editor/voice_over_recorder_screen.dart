// ABOUTME: Full-screen voice-over recorder for the video editor.
// ABOUTME: Close/done on top, live waveform + count in the middle, record below.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/blocs/video_editor/voice_over/voice_over_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/upload_media_providers.dart';
import 'package:openvine/widgets/video_editor/video_editor_toolbar.dart';
import 'package:permissions_service/permissions_service.dart';

/// Full-screen recorder that lets the user capture one or more voice-over
/// takes without leaving the screen.
///
/// Returns the recorded takes (as draft-local [AudioEvent]s) via
/// [Navigator.pop] when the user taps Done, or `null` when they close the
/// screen (in which case the recordings are discarded).
class VoiceOverRecorderScreen extends ConsumerWidget {
  /// Creates the voice-over recorder screen.
  const VoiceOverRecorderScreen({
    required this.availableDuration,
    this.priorTakeCount = 0,
    super.key,
  });

  /// Length of the video the voice-over will be laid over. Shown next to the
  /// recorded total so the user can tell when their audio runs too long.
  final Duration availableDuration;

  /// Number of voice-over takes already on the editor timeline, used only to
  /// continue the take numbering (e.g. "Recording 5"). The count and duration
  /// shown still reset to zero each time the recorder opens.
  final int priorTakeCount;

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
      child: const VoiceOverRecorderView(),
    );
  }
}

/// UI for the voice-over recorder. Split from the page so it can be tested
/// in isolation with a mock [VoiceOverCubit].
class VoiceOverRecorderView extends StatelessWidget {
  /// Creates the voice-over recorder view.
  @visibleForTesting
  const VoiceOverRecorderView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.vineColors.surface,
      body: MultiBlocListener(
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
        child: const Column(
          children: [
            _Toolbar(),
            Expanded(child: _RecorderBody()),
            _RecordControls(),
          ],
        ),
      ),
    );
  }

  void _announce(BuildContext context, String message) {
    SemanticsService.sendAnnouncement(
      View.of(context),
      message,
      Directionality.of(context),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar();

  @override
  Widget build(BuildContext context) {
    final isRecording = context.select(
      (VoiceOverCubit c) => c.state.isRecording,
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
      onDone: (!isRecording && hasTakes) ? () => _done(context) : null,
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
    final isRecording = context.select(
      (VoiceOverCubit c) => c.state.isRecording,
    );
    final recordingCount = context.select(
      (VoiceOverCubit c) => c.state.recordingCount,
    );
    final l10n = context.l10n;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 16,
        children: [
          const RepaintBoundary(
            child: SizedBox(
              height: 120,
              width: double.infinity,
              child: _Wave(),
            ),
          ),
          if (isRecording || recordingCount > 0) const _TimeReadout(),
          Padding(
            padding: _textPadding,
            child: Text(
              l10n.videoEditorVoiceOverRecordingsCount(recordingCount),
              style: VineTheme.bodyMediumFont(
                color: context.vineColors.secondaryText,
              ),
            ),
          ),
          if (!isRecording && recordingCount == 0)
            Padding(
              padding: _textPadding,
              child: Text(
                l10n.videoEditorVoiceOverHint,
                textAlign: .center,
                style: VineTheme.bodySmallFont(
                  color: context.vineColors.mutedText,
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
    final isRecording = context.select(
      (VoiceOverCubit c) => c.state.isRecording,
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
              child: (hasTakes && !isRecording)
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
    final isRecording = context.select(
      (VoiceOverCubit c) => c.state.isRecording,
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
