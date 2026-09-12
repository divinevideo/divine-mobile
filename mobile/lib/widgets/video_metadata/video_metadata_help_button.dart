import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_svg/svg.dart';
import 'package:material_ui/material_ui.dart';

class VideoMetadataHelpButton extends StatelessWidget {
  const VideoMetadataHelpButton({
    required this.onTap,
    required this.tooltip,
    super.key,
  });

  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: SvgPicture.asset(
              DivineIconName.info.assetPath,
              colorFilter: ColorFilter.mode(
                context.vineColors.onSurfaceVariant,
                BlendMode.srcIn,
              ),
              width: 16,
              height: 16,
              semanticsLabel: tooltip,
            ),
          ),
        ),
      ),
    );
  }
}
