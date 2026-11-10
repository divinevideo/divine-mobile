// ABOUTME: Shared app bar / bottom bar chrome for the crop-rotate editors
// ABOUTME: Used by the clip (video) and the stop-motion frame (image) screens

import 'dart:math' as math;

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:pro_image_editor/pro_image_editor.dart'
    show CropRotateEditorState;

/// Top bar for a [CropRotateEditorState]: back (cancel) and done (apply).
class TransformEditorAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const TransformEditorAppBar({required this.editorState, super.key});

  final CropRotateEditorState editorState;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: kToolbarHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              DivineIconButton(
                icon: .arrowLeft,
                type: .secondary,
                size: .small,
                semanticLabel:
                    context.l10n.videoEditorTransformCancelSemanticLabel,
                onPressed: editorState.close,
              ),
              DivineIconButton(
                icon: .check,
                size: .small,
                semanticLabel:
                    context.l10n.videoEditorTransformApplySemanticLabel,
                onPressed: editorState.done,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom bar for a [CropRotateEditorState]: rotate, flip and reset, with an
/// optional [leading] action (the clip editor puts play/pause there; a still
/// has nothing to play).
///
/// The actions stay on one row, so their labels stop growing with the system
/// text size once the row is full: at 1.4x German "Zurücksetzen" already
/// pushed Reset past the edge of a 360-wide phone.
class TransformEditorBottomBar extends StatelessWidget {
  const TransformEditorBottomBar({
    required this.editorState,
    this.leading,
    this.leadingLabels = const [],
    super.key,
  });

  final CropRotateEditorState editorState;

  /// Action rendered before Rotate — typically a [TransformEditorAction].
  final Widget? leading;

  /// Every label [leading] can show, so the bar sizes the text for the widest.
  final List<String> leadingLabels;

  /// The least room left between two neighbouring actions.
  static const double _minActionGap = 8;

  @override
  Widget build(BuildContext context) {
    final rotateLabel = context.l10n.videoEditorTransformRotateLabel;
    final flipLabel = context.l10n.videoEditorTransformFlipLabel;
    final resetLabel = context.l10n.videoEditorTransformResetLabel;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.vineColors.surfaceContainerHigh,
        boxShadow: const [
          BoxShadow(
            color: VineTheme.shadow25,
            blurRadius: 8,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: LayoutBuilder(
            builder: (context, constraints) =>
                MediaQuery.withClampedTextScaling(
                  maxScaleFactor: _fittingTextScale(
                    context,
                    width: constraints.maxWidth,
                    actionLabels: [
                      if (leading != null) leadingLabels,
                      [rotateLabel],
                      [flipLabel],
                      [resetLabel],
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      ?leading,
                      TransformEditorAction(
                        icon: .arrowArcLeft,
                        label: rotateLabel,
                        onPressed: editorState.rotate,
                      ),
                      TransformEditorAction(
                        icon: .cameraRotate,
                        label: flipLabel,
                        onPressed: editorState.flip,
                      ),
                      TransformEditorAction(
                        icon: .arrowsCounterClockwise,
                        label: resetLabel,
                        onPressed: editorState.reset,
                      ),
                    ],
                  ),
                ),
          ),
        ),
      ),
    );
  }

  /// The largest text scale at which the actions, each as wide as its widest
  /// label in [actionLabels] or its button, still fit side by side in
  /// [width]. Never below the normal size.
  static double _fittingTextScale(
    BuildContext context, {
    required double width,
    required List<List<String>> actionLabels,
  }) {
    var style = DefaultTextStyle.of(
      context,
    ).style.merge(TransformEditorAction.labelStyle(context));
    // Text switches to bold when the platform asks for Bold Text.
    if (MediaQuery.boldTextOf(context)) {
      style = style.copyWith(fontWeight: FontWeight.bold);
    }
    final fontSize = style.fontSize ?? 14;
    final ambientScale =
        MediaQuery.textScalerOf(context).scale(fontSize) / fontSize;
    if (!width.isFinite || ambientScale <= 1) return ambientScale;

    final textDirection = Directionality.of(context);
    final locale = Localizations.maybeLocaleOf(context);
    double labelWidth(String label) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: style),
        textDirection: textDirection,
        locale: locale,
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    final labelWidths = [
      for (final labels in actionLabels)
        labels.map(labelWidth).fold(0.0, math.max),
    ];
    // The row spreads what is left around the actions, half a share at each
    // end, so a share per action keeps a whole gap between neighbours.
    final available = width - _minActionGap * actionLabels.length;
    // Labels grow a little slower than their scale, since the theme's letter
    // spacing does not scale, so this errs on the side of fitting.
    bool fits(double scale) {
      final buttonWidth =
          TransformEditorAction.buttonSize *
          math.min(scale, DivineIcon.maxScaleFactor);
      final needed = labelWidths.fold(
        0.0,
        (sum, labelWidth) => sum + math.max(buttonWidth, labelWidth * scale),
      );
      return needed <= available;
    }

    if (fits(ambientScale)) return ambientScale;
    var low = 1.0;
    var high = ambientScale;
    for (var i = 0; i < 20; i++) {
      final middle = (low + high) / 2;
      if (fits(middle)) {
        low = middle;
      } else {
        high = middle;
      }
    }
    return low;
  }
}

/// One labelled icon action in a [TransformEditorBottomBar].
class TransformEditorAction extends StatelessWidget {
  const TransformEditorAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    super.key,
  });

  final DivineIconName icon;
  final String label;
  final VoidCallback onPressed;

  /// The small [DivineIconButton]'s tap target before text scaling.
  static const double buttonSize = 48;

  /// The style the label is drawn in.
  static TextStyle labelStyle(BuildContext context) =>
      VineTheme.bodySmallFont(color: context.vineColors.primaryText);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [
        DivineIconButton(
          icon: icon,
          semanticLabel: label,
          onPressed: onPressed,
          type: .secondary,
          size: .small,
        ),
        ExcludeSemantics(
          child: Text(label, style: labelStyle(context)),
        ),
      ],
    );
  }
}
