// ABOUTME: Bottom sheet with a wheel picker for stop-motion frames-per-image
// ABOUTME: Returns the chosen frames-per-image as an int via context.pop

import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoPicker;
import 'package:divine_ui/divine_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/stop_motion/stop_motion_frame_ops.dart';

/// Wheel picker for how many output frames each stop-motion still is held for.
///
/// Shown in a [VineBottomSheet]; pops the chosen value — in
/// [StopMotionFrameOps.minFramesPerImage]..[StopMotionFrameOps.maxFramesPerImage]
/// — on confirm, or `null` on cancel.
class StopMotionFramesPerImageSheet extends StatefulWidget {
  const StopMotionFramesPerImageSheet({required this.initialValue, super.key});

  /// Current frames-per-image; the wheel opens centered on this value.
  final int initialValue;

  @override
  State<StopMotionFramesPerImageSheet> createState() =>
      _StopMotionFramesPerImageSheetState();
}

class _StopMotionFramesPerImageSheetState
    extends State<StopMotionFramesPerImageSheet> {
  static const int _min = StopMotionFrameOps.minFramesPerImage;
  static const int _max = StopMotionFrameOps.maxFramesPerImage;

  late final FixedExtentScrollController _controller;
  late int _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue.clamp(_min, _max);
    _controller = FixedExtentScrollController(initialItem: _value - _min);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            spacing: 8,
            children: [
              DivineIconButton(
                icon: DivineIconName.x,
                type: DivineIconButtonType.secondary,
                size: DivineIconButtonSize.small,
                onPressed: () => context.pop<int>(),
              ),
              Flexible(
                child: Text(
                  context.l10n.videoEditorStopMotionFramesPerImageLabel,
                  style: VineTheme.titleMediumFont(
                    color: context.vineColors.primaryText,
                  ),
                ),
              ),
              DivineIconButton(
                icon: DivineIconName.check,
                size: DivineIconButtonSize.small,
                onPressed: () => context.pop<int>(_value),
              ),
            ],
          ),
        ),
        Divider(
          height: 2,
          thickness: 2,
          color: context.vineColors.surfaceContainer,
        ),
        SizedBox(
          height: 200,
          // Lazy builder: the range can be hundreds of items, so build only
          // the visible rows instead of eagerly constructing every one.
          child: CupertinoPicker.builder(
            scrollController: _controller,
            itemExtent: 44,
            backgroundColor: context.vineColors.surface,
            onSelectedItemChanged: (index) => _value = _min + index,
            childCount: _max - _min + 1,
            itemBuilder: (context, index) => Center(
              child: Text(
                context.l10n.videoEditorStopMotionFramesCount(_min + index),
                style: VineTheme.titleMediumFont(
                  color: context.vineColors.primaryText,
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: MediaQuery.paddingOf(context).bottom + 8),
      ],
    );
  }
}
