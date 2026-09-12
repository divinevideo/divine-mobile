import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';

class VideoMetadataSelectionTile extends StatefulWidget {
  const VideoMetadataSelectionTile({
    required this.semanticsLabel,
    required this.labelText,
    required this.value,
    this.onTap,
    super.key,
  });

  final String semanticsLabel;
  final String labelText;
  final String value;
  final VoidCallback? onTap;

  @override
  State<VideoMetadataSelectionTile> createState() =>
      _VideoMetadataSelectionTileState();
}

class _VideoMetadataSelectionTileState
    extends State<VideoMetadataSelectionTile> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(VideoMetadataSelectionTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.semanticsLabel,
      value: widget.value,
      child: GestureDetector(
        behavior: .translucent,
        onTap: widget.onTap,
        child: ExcludeSemantics(
          child: Padding(
            padding: const .all(16),
            child: Row(
              spacing: 12,
              children: [
                Expanded(
                  child: IgnorePointer(
                    child: DivineTextField(
                      labelText: widget.labelText,
                      contentPadding: .zero,
                      canRequestFocus: false,
                      primaryWhenFilled: true,
                      controller: _controller,
                    ),
                  ),
                ),
                DivineIcon(
                  icon: .caretDown,
                  color: context.vineColors.accentPositive,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
