// ABOUTME: Style controls bar for text editor with color, alignment, background, outline and shadow, and font buttons.
// ABOUTME: Directly accesses VideoEditorTextBloc for state management.

import 'dart:math';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/text_editor/video_editor_text_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_editor/text_editor/video_editor_text_extensions.dart';
import 'package:openvine/widgets/video_editor/text_editor/video_text_editor_scope.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

/// Style controls bar for text editor.
///
/// Displays buttons for color, alignment, background style, outline and
/// shadow, and font selection.
/// Directly accesses [VideoEditorTextBloc] for state management and syncs
/// changes with the [TextEditorState] via [VideoTextEditorScope].
class VideoEditorTextStyleBar extends StatelessWidget {
  const VideoEditorTextStyleBar({super.key});

  static const double _horizontalPadding = 16;

  /// The narrowest the font button gets before the bar scrolls instead.
  static const double _minFontButtonWidth = 120;

  void _toggleFontSelector(BuildContext context, VideoEditorTextState state) {
    _togglePanel(
      context: context,
      isOpen: state.showFontSelector,
      event: const VideoEditorTextFontSelectorToggled(),
    );
  }

  void _toggleColorPicker(BuildContext context, VideoEditorTextState state) {
    _togglePanel(
      context: context,
      isOpen: state.showColorPicker,
      event: const VideoEditorTextColorPickerToggled(),
    );
  }

  void _toggleEffectsPanel(BuildContext context, VideoEditorTextState state) {
    _togglePanel(
      context: context,
      isOpen: state.showEffectsPanel,
      event: const VideoEditorTextEffectsPanelToggled(),
    );
  }

  /// Toggles a panel (font selector, color picker, or outline and shadow) and
  /// manages keyboard focus.
  void _togglePanel({
    required BuildContext context,
    required bool isOpen,
    required VideoEditorTextEvent event,
  }) {
    final textEditor = VideoTextEditorScope.of(context).editor;

    if (isOpen) {
      // Closing panel - show keyboard again
      textEditor.focusNode.requestFocus();
    } else {
      // Opening panel - hide keyboard
      if (textEditor.focusNode.hasFocus) {
        textEditor.focusNode.unfocus();
      } else {
        FocusManager.instance.primaryFocus?.unfocus();
      }
    }

    context.read<VideoEditorTextBloc>().add(event);
  }

  @override
  Widget build(BuildContext context) {
    final textEditor = VideoTextEditorScope.of(context).editor;

    return Material(
      type: .transparency,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final available = constraints.maxWidth - _horizontalPadding * 2;
          // The four 48 dp style buttons with their 8 dp gaps, and the 16 dp
          // gap before the font button. Should this undercount, the bar
          // scrolls a little; it never overflows.
          final styleButtonsWidth =
              DivineIcon.scaleSize(context, 48) * 4 + 8 * 3 + 16;
          final fontButtonMaxWidth = max(
            _minFontButtonWidth,
            available - styleButtonsWidth,
          );
          return SingleChildScrollView(
            // On a narrow screen the bar scrolls out to the screen edge instead
            // of overflowing or squeezing the font name to nothing.
            scrollDirection: .horizontal,
            padding: const .symmetric(horizontal: _horizontalPadding),
            child: ConstrainedBox(
              // Where everything fits, the font button sits at the far end.
              constraints: BoxConstraints(minWidth: available),
              child: BlocBuilder<VideoEditorTextBloc, VideoEditorTextState>(
                buildWhen: (previous, current) =>
                    previous.selectedFontIndex != current.selectedFontIndex ||
                    previous.showFontSelector != current.showFontSelector ||
                    previous.showColorPicker != current.showColorPicker ||
                    previous.showEffectsPanel != current.showEffectsPanel ||
                    previous.backgroundStyle != current.backgroundStyle ||
                    previous.alignment != current.alignment ||
                    previous.color != current.color,
                builder: (context, state) {
                  return Row(
                    spacing: 16,
                    mainAxisAlignment: .spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: .min,
                        spacing: 8,
                        children: [
                          _ColorSwatchButton(
                            semanticsLabel:
                                context.l10n.videoEditorTextColorSemanticLabel,
                            color: state.color,
                            onTap: () => _toggleColorPicker(context, state),
                          ),
                          DivineIconButton(
                            semanticLabel: context
                                .l10n
                                .videoEditorTextAlignmentSemanticLabel,
                            semanticValue: state.alignment
                                .localizedAccessibilityName(
                                  context.l10n,
                                ),
                            size: .small,
                            type: .secondary,
                            icon: state.alignment.icon,
                            onPressed: textEditor.toggleTextAlign,
                          ),
                          DivineIconButton(
                            semanticLabel: context
                                .l10n
                                .videoEditorTextBackgroundSemanticLabel,
                            semanticValue: state.backgroundStyle
                                .localizedAccessibilityName(context.l10n),
                            size: .small,
                            type: .secondary,
                            icon: state.backgroundStyle.icon,
                            onPressed: textEditor.toggleBackgroundMode,
                          ),
                          DivineIconButton(
                            semanticLabel: context
                                .l10n
                                .videoEditorTextEffectsSemanticLabel,
                            size: .small,
                            type: .secondary,
                            icon: .textOutlineShadow,
                            onPressed: () =>
                                _toggleEffectsPanel(context, state),
                          ),
                        ],
                      ),
                      // Font selector button; a long font name ellipsizes.
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: fontButtonMaxWidth,
                        ),
                        child: _FontSelectorButton(
                          fontName: state.selectedFontName,
                          isOpen: state.showFontSelector,
                          onTap: () => _toggleFontSelector(context, state),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Color swatch button showing the current text color.
class _ColorSwatchButton extends StatelessWidget {
  const _ColorSwatchButton({
    required this.semanticsLabel,
    required this.color,
    this.onTap,
  });

  final String semanticsLabel;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dimension = DivineIcon.scaleSize(context, 20);
    return Semantics(
      label: semanticsLabel,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: VineTheme.primary.withValues(alpha: 0.1),
        highlightColor: VineTheme.primary.withValues(alpha: 0.05),
        child: Ink(
          decoration: BoxDecoration(
            color: context.vineColors.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: context.vineColors.outlineMuted,
              width: 2,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Container(
              width: dimension,
              height: dimension,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
        ),
      ),
    );
  }
}

/// Font selector button showing current font name with dropdown arrow.
class _FontSelectorButton extends StatelessWidget {
  const _FontSelectorButton({
    required this.fontName,
    this.isOpen = false,
    this.onTap,
  });

  final String fontName;
  final bool isOpen;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(
      context,
    ).clamp(maxScaleFactor: 1.2);
    final display = fontName == 'Unknown'
        ? context.l10n.videoEditorFontUnknown
        : fontName;
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: textScaler),
      child: Semantics(
        label: context.l10n.videoEditorSelectFontSemanticLabel,
        value: display,
        button: true,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const .symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: context.vineColors.surfaceContainer,
              borderRadius: .circular(16),
              border: Border.all(
                color: context.vineColors.outlineMuted,
                width: 2,
              ),
            ),
            child: Row(
              mainAxisSize: .min,
              spacing: 8,
              children: [
                Flexible(
                  child: Text(
                    display,
                    overflow: .ellipsis,
                    style: VineTheme.titleMediumFont(
                      color: context.vineColors.accentPositive,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: isOpen ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: DivineIcon(
                    icon: .caretDown,
                    color: context.vineColors.accentPositive,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
