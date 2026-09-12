// ABOUTME: Full-screen takeover that renders a message over TV static noise
// ABOUTME: Shared retro "no signal" look for permission and video dead ends

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/widgets/takeover_close_button.dart';
import 'package:tv_static_effect/tv_static_effect.dart';

/// Full-screen takeover that renders a message over animated TV static.
///
/// The retro "no signal" look the camera permission screen introduced, reused
/// wherever the app has nothing to play: a missing video, a failed load, a
/// denied permission. A close affordance sits in the top-left corner; the
/// primary action and the [footer] chrome are optional.
class TvStaticMessageScreen extends StatelessWidget {
  const TvStaticMessageScreen({
    required this.sticker,
    required this.title,
    required this.onClose,
    this.description,
    this.actionLabel,
    this.onAction,
    this.closeSemanticLabel,
    this.footer,
    super.key,
  });

  /// Sticker shown above the title.
  final DivineStickerName sticker;

  final String title;

  /// Optional supporting copy below the title.
  final String? description;

  /// Label of the primary action. Rendered only alongside [onAction].
  final String? actionLabel;

  /// Primary action. Rendered only alongside [actionLabel].
  final VoidCallback? onAction;

  /// Invoked by the top-left close button.
  final VoidCallback onClose;

  /// Accessibility label for the close button.
  final String? closeSemanticLabel;

  /// Optional chrome pinned to the bottom edge, below the message.
  ///
  /// A footer owns its own bottom inset — [SafeArea] here stops at the
  /// message column so the footer can paint all the way to the screen edge.
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    // The takeover replaces the whole screen, so it owns the status-bar tint
    // rather than inheriting whatever route it covered.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: VideoEditorConstants.uiOverlayStyleFor(context.vineColors),
      child: Scaffold(
        backgroundColor: context.vineColors.background,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const TvStaticNoise(),
            SafeArea(
              bottom: footer == null,
              child: Column(
                children: [
                  TakeoverCloseButton(
                    onPressed: onClose,
                    semanticLabel: closeSemanticLabel,
                  ),

                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const .symmetric(horizontal: 48),
                        child: _TvStaticMessage(
                          sticker: sticker,
                          title: title,
                          description: description,
                          actionLabel: actionLabel,
                          onAction: onAction,
                        ),
                      ),
                    ),
                  ),

                  ?footer,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TvStaticMessage extends StatelessWidget {
  const _TvStaticMessage({
    required this.sticker,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onAction,
  });

  final DivineStickerName sticker;
  final String title;
  final String? description;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: .center,
      children: [
        DivineSticker(sticker: sticker, size: 154),
        const SizedBox(height: 20),
        Text(
          title,
          style: VineTheme.titleMediumFont(
            color: context.vineColors.onSurfaceMuted,
          ),
          textAlign: .center,
        ),
        if (description case final description?) ...[
          const SizedBox(height: 8),
          Text(
            description,
            style: VineTheme.bodyMediumFont(
              color: context.vineColors.onSurfaceMuted,
            ),
            textAlign: .center,
          ),
        ],
        if ((actionLabel, onAction) case (final label?, final onAction?)) ...[
          const SizedBox(height: 32),
          DivineButton(label: label, onPressed: onAction),
        ],
      ],
    );
  }
}
