import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_editor/video_editor_category_tabs.dart';

/// The sound picker's list tabs, moving like the editor's other category
/// rows: the highlight slides along with [controller] as the lists swipe.
class AudioCategoryBar extends StatelessWidget {
  const AudioCategoryBar({
    required this.controller,
    required this.onSelect,
    super.key,
  });

  /// Drives the lists below; one tab per [AudioCategory], in order.
  final TabController controller;

  final ValueChanged<AudioCategory> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return VideoEditorCategoryTabs(
      controller: controller,
      labels: [
        for (final category in AudioCategory.values)
          switch (category) {
            AudioCategory.forYou => l10n.exploreTabForYou,
            AudioCategory.popular => l10n.exploreTabPopular,
            AudioCategory.newest => l10n.exploreTabNew,
            AudioCategory.mySounds => l10n.videoEditorAudioCategoryMySounds,
          },
      ],
      onTap: (index) => onSelect(AudioCategory.values[index]),
    );
  }
}

/// The picker's sound lists, in tab order.
enum AudioCategory {
  /// Sounds from people the viewer follows, then Divine's own.
  forYou,

  /// The sounds being picked up right now.
  popular,

  /// The newest community sounds.
  newest,

  /// The viewer's saved sounds.
  mySounds,
}
