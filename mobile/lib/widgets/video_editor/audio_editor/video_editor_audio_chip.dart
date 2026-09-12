import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/constants/text_scale_limits.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/video_editor/video_audio_editor_timing_screen.dart';
import 'package:openvine/widgets/video_editor/audio_editor/audio_selection_bottom_sheet.dart';

/// Audio chip widget for selecting and displaying audio in video recording/editing.
///
/// This widget is provider-agnostic - it receives the current sound as input
/// and reports changes via callbacks. The parent widget is responsible for
/// updating the appropriate provider (recorder or editor).
class VideoEditorAudioChip extends StatelessWidget {
  const VideoEditorAudioChip({
    required this.selectedSound,
    required this.onSoundChanged,
    this.onSelectionStarted,
    this.onSelectionEnded,
    super.key,
  });

  /// The currently selected sound, or null if none selected.
  final AudioEvent? selectedSound;

  /// Called when the sound selection changes.
  ///
  /// Called with the new [AudioEvent] when a sound is selected or its
  /// start offset is changed. Called with `null` when the sound is cleared.
  final ValueChanged<AudioEvent?> onSoundChanged;

  /// Called when audio selection begins (e.g. to pause playback).
  final VoidCallback? onSelectionStarted;

  /// Called when audio selection ends (e.g. to resume playback).
  final VoidCallback? onSelectionEnded;

  @visibleForTesting
  static bool shouldOpenTimingScreen(AudioEvent? selectedSound) =>
      selectedSound != null;

  Future<void> _selectAudio(BuildContext context) async {
    final previousSound = selectedSound;
    onSelectionStarted?.call();

    try {
      // No sound yet: the selection sheet already trims long sounds via the
      // timing screen and returns the final, timed sound, so use its result
      // directly. Re-opening the timing screen here would show it twice.
      if (!shouldOpenTimingScreen(previousSound)) {
        final result = await VineBottomSheet.show<AudioEvent>(
          context: context,
          maxChildSize: 1,
          initialChildSize: 1,
          minChildSize: VineTheme.bottomSheetDismissFloor,
          buildScrollBody: (scrollController) =>
              AudioSelectionBottomSheet(scrollController: scrollController),
        );
        onSoundChanged(result);
        return;
      }

      // Re-editing an already-selected sound: jump straight to the timing
      // screen so the user can adjust the start offset or remove the sound.
      final timingResult = await Navigator.of(context).push<AudioTimingResult>(
        PageRouteBuilder(
          settings: const RouteSettings(name: 'audio_timing'),
          opaque: false,
          barrierColor: VineTheme.transparent,
          pageBuilder: (_, _, _) =>
              VideoAudioEditorTimingScreen(sound: previousSound!),
        ),
      );

      if (timingResult != null) {
        switch (timingResult) {
          case AudioTimingConfirmed(:final sound):
            onSoundChanged(sound);
          case AudioTimingDeleted():
            onSoundChanged(null);
        }
      }
    } finally {
      onSelectionEnded?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasSelectedSound = selectedSound != null;

    return Hero(
      tag: VideoEditorConstants.heroAudioChipId,
      child: Material(
        type: .transparency,
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: chipLabelTextScaleLimit,
          child: Semantics(
            identifier: SemanticIds.audioChip,
            // The chip is an InkWell around a Row, so nothing here reported as
            // a button before. The label stays with the text inside, which is
            // what already carries the sound's title.
            button: true,
            child: InkWell(
              onTap: () => _selectAudio(context),
              borderRadius: .circular(16),
              child: Container(
                constraints: const BoxConstraints(minHeight: 40),
                padding: const .fromLTRB(16, 8, 8, 8),
                decoration: ShapeDecoration(
                  color: VineTheme.scrim15,
                  shape: RoundedRectangleBorder(borderRadius: .circular(16)),
                ),
                child: Row(
                  mainAxisSize: .min,
                  mainAxisAlignment: .center,
                  children: [
                    const _AudioBars(),
                    Flexible(
                      child: Padding(
                        padding: const .symmetric(horizontal: 8),
                        child: hasSelectedSound
                            ? Text.rich(
                                TextSpan(
                                  style: VineTheme.labelLargeFont(
                                    color: VineTheme.whiteText,
                                  ),
                                  children: [
                                    TextSpan(
                                      text:
                                          selectedSound?.title ??
                                          context.l10n.videoEditorAudioUntitled,
                                    ),
                                    if (selectedSound?.source != null) ...[
                                      const TextSpan(text: ' ∙ '),
                                      TextSpan(
                                        text: selectedSound!.source,
                                        style: VineTheme.bodyMediumFont(
                                          color: VineTheme.whiteText,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                textAlign: .center,
                                maxLines: 1,
                                overflow: .ellipsis,
                              )
                            : Text(
                                context.l10n.videoEditorAudioAddAudio,
                                textAlign: .center,
                                style: VineTheme.titleMediumFont(
                                  color: VineTheme.whiteText,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The five-bar waveform glyph that stands in for an icon on the chip.
///
/// Its own build context sits below the chip's
/// [MediaQuery.withClampedTextScaling], so reading the scaler here — rather
/// than in the chip's `build` — is what keeps the bars inside the clamp the
/// label beside them obeys.
class _AudioBars extends StatelessWidget {
  const _AudioBars();

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: DivineIcon.scaleSize(context, 1.5),
      children: const [
        _AudioBar(height: 7),
        _AudioBar(height: 16),
        _AudioBar(height: 13),
        _AudioBar(height: 7),
        _AudioBar(height: 10),
      ],
    );
  }
}

class _AudioBar extends StatelessWidget {
  const _AudioBar({required this.height});

  /// Height at 1.0x text scale. Scaled here rather than by the caller so
  /// the value stays inside the chip's clamped subtree.
  final double height;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: DivineIcon.scaleSize(context, 2),
      height: DivineIcon.scaleSize(context, height),
      decoration: BoxDecoration(
        color: VineTheme.whiteText,
        borderRadius: .circular(2),
      ),
    );
  }
}
