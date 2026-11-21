// ABOUTME: The color mask screen's frame, shared by the editor and the camera:
// ABOUTME: toolbar, a preview to tap, Remove, and the settings panel below.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_editor/video_editor_toolbar.dart';
import 'package:openvine/widgets/whole_word_button_text_scale.dart';

/// The color mask screen, around whatever it keys.
///
/// The editor shows a clip in [preview] and the camera shows its live picture,
/// so both set the mask the same way: tap the preview for the color, choose
/// what replaces it, and fine-tune below.
class ChromaKeyScreenLayout extends StatelessWidget {
  const ChromaKeyScreenLayout({
    required this.onClose,
    required this.closeSemanticLabel,
    required this.doneSemanticLabel,
    required this.preview,
    required this.controls,
    this.onDone,
    this.onRemove,
    this.showRemove = false,
    this.overlay,
    super.key,
  });

  final VoidCallback onClose;
  final String closeSemanticLabel;

  /// Confirms the screen; `null` holds Done disabled.
  final VoidCallback? onDone;
  final String doneSemanticLabel;

  /// What is keyed, filling the space between the toolbar and the controls.
  final Widget preview;

  /// The settings panel under the preview.
  final Widget controls;

  /// Whether Remove is shown at all.
  final bool showRemove;

  /// Takes the mask off; `null` holds Remove disabled.
  final VoidCallback? onRemove;

  /// Drawn over the whole screen, such as a blocking progress overlay.
  final Widget? overlay;

  @override
  Widget build(BuildContext context) {
    final overlay = this.overlay;
    return Scaffold(
      backgroundColor: context.vineColors.surfaceContainerHigh,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                VideoEditorToolbar(
                  onClose: onClose,
                  onDone: onDone,
                  closeSemanticLabel: closeSemanticLabel,
                  doneSemanticLabel: doneSemanticLabel,
                  // Flexible, so a large text size wraps the title instead of
                  // pushing Done off the screen.
                  center: Flexible(
                    child: DivineWordFitText(
                      context.l10n.videoEditorChromaKeyTitle,
                      textAlign: TextAlign.center,
                      style: VineTheme.titleMediumFont(
                        color: context.vineColors.onSurface,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: preview,
                  ),
                ),
                if (showRemove)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: WholeWordButtonTextScale(
                      label: context.l10n.videoEditorChromaKeyRemove,
                      child: DivineButton(
                        label: context.l10n.videoEditorChromaKeyRemove,
                        type: .ghost,
                        size: .small,
                        expanded: true,
                        maxLines: 2,
                        onPressed: onRemove,
                      ),
                    ),
                  ),
                Flexible(child: controls),
              ],
            ),
            ?overlay,
          ],
        ),
      ),
    );
  }
}

/// A short line over the top of the preview, saying what tapping it does or
/// that the color is still being found.
///
/// Belongs in a [Stack] over the preview.
class ChromaKeyPreviewHint extends StatelessWidget {
  const ChromaKeyPreviewHint({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    // Over video, so fixed media chrome rather than the adaptive palette.
    return Positioned(
      top: 12,
      left: 12,
      right: 12,
      // Never in the way of the tap it describes.
      child: IgnorePointer(
        child: Center(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: VineTheme.scrim65,
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: VineTheme.bodySmallFont(color: VineTheme.whiteText),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The hint [ChromaKeyPreviewHint] shows: that the color is being found,
/// that the preview can be tapped, or nothing once it has been.
String? chromaKeyPreviewHintText(
  BuildContext context, {
  required bool isDetecting,
  required bool hasPicked,
}) {
  if (isDetecting) return context.l10n.videoEditorChromaKeyDetecting;
  if (!hasPicked) return context.l10n.videoEditorChromaKeyTapToPick;
  return null;
}
