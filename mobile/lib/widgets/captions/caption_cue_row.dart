// ABOUTME: One caption cue's editing row — a range slider for its timing and
// ABOUTME: a text field for its wording, shared by every caption editor.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';

/// The editing row for a single caption cue.
///
/// Shared by the video editor's captions sheet and the subtitle editor so a
/// caption is written the same way whether it is authored before publishing or
/// corrected afterwards.
///
/// The slider spans the whole video — cues may freely overlap each other. The
/// owning cubit enforces whatever minimum duration applies between the thumbs.
class CaptionCueRow extends StatefulWidget {
  /// Creates the row for the cue spanning [start] to [end].
  const CaptionCueRow({
    required this.text,
    required this.start,
    required this.end,
    required this.totalDuration,
    required this.onTimingChanged,
    required this.onTextChanged,
    required this.onRemoved,
    required this.textFieldLabel,
    required this.removeSemanticLabel,
    this.onFocused,
    this.isSelected = false,
    super.key,
  });

  /// The cue's caption text.
  final String text;

  /// Where the cue starts.
  final Duration start;

  /// Where the cue ends.
  final Duration end;

  /// Slider range: the full video.
  final Duration totalDuration;

  /// Called as either slider thumb moves.
  final void Function(Duration start, Duration end) onTimingChanged;

  /// Called on every keystroke in the text field.
  final ValueChanged<String> onTextChanged;

  /// Called when the row's delete action is used.
  final VoidCallback onRemoved;

  /// Label of the text field. Each editor words its captions its own way —
  /// "line" in the subtitle editor, "caption" in the video editor.
  final String textFieldLabel;

  /// Screen-reader label of the delete action.
  final String removeSemanticLabel;

  /// Called when the text field takes focus.
  ///
  /// Editors that also show the cue somewhere else use this to follow the
  /// creator to the cue they are typing in.
  final VoidCallback? onFocused;

  /// Whether this is the cue the surrounding editor is focused on.
  final bool isSelected;

  @override
  State<CaptionCueRow> createState() => _CaptionCueRowState();
}

class _CaptionCueRowState extends State<CaptionCueRow> {
  late final TextEditingController _textController = TextEditingController(
    text: widget.text,
  );
  late final FocusNode _focusNode = FocusNode()..addListener(_onFocusChanged);

  void _onFocusChanged() {
    if (_focusNode.hasFocus) widget.onFocused?.call();
  }

  @override
  void didUpdateWidget(CaptionCueRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only when the value changed underneath us — comparing first keeps the
    // caret still while the creator types.
    if (widget.text != _textController.text) {
      _textController.text = widget.text;
    }
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_onFocusChanged)
      ..dispose();
    _textController.dispose();
    super.dispose();
  }

  static double _seconds(Duration value) =>
      value.inMilliseconds / Duration.millisecondsPerSecond;

  static String _label(Duration value) =>
      '${_seconds(value).toStringAsFixed(1)}s';

  static Duration _duration(double seconds) => Duration(
    milliseconds: (seconds * Duration.millisecondsPerSecond).round(),
  );

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: widget.isSelected ? context.vineColors.containerLow : null,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          spacing: 8,
          children: [
            Row(
              spacing: 12,
              children: [
                Text(
                  _label(widget.start),
                  style: VineTheme.bodySmallFont(
                    color: context.vineColors.secondaryText,
                  ),
                ),
                Expanded(
                  child: DivineRangeSlider(
                    values: RangeValues(
                      _seconds(widget.start),
                      _seconds(widget.end),
                    ),
                    max: _seconds(widget.totalDuration),
                    onChanged: (values) => widget.onTimingChanged(
                      _duration(values.start),
                      _duration(values.end),
                    ),
                  ),
                ),
                Text(
                  _label(widget.end),
                  style: VineTheme.bodySmallFont(
                    color: context.vineColors.secondaryText,
                  ),
                ),
              ],
            ),
            Row(
              spacing: 8,
              children: [
                Expanded(
                  child: _InputSurface(
                    child: DivineTextField(
                      controller: _textController,
                      focusNode: _focusNode,
                      labelText: widget.textFieldLabel,
                      minLines: 1,
                      maxLines: 3,
                      keyboardType: .multiline,
                      textInputAction: .newline,
                      onChanged: widget.onTextChanged,
                    ),
                  ),
                ),
                DivineIconButton(
                  icon: .trash,
                  type: .ghostSecondary,
                  semanticLabel: widget.removeSemanticLabel,
                  onPressed: widget.onRemoved,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Container surface for the row's input, mirroring the metadata form's field
/// styling on a contrasting background.
class _InputSurface extends StatelessWidget {
  const _InputSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.vineColors.containerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}
