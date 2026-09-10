import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';

class AudioCategoryBar extends StatelessWidget {
  const AudioCategoryBar({
    required this.onSelect,
    required this.category,
    super.key,
  });

  final ValueChanged<AudioCategory> onSelect;
  final AudioCategory category;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: .horizontal,
      padding: const .all(16),
      child: Row(
        spacing: 8,
        children: [
          _Chip(
            onTap: () => onSelect(.divine),
            isSelected: category == .divine,
            label: context.l10n.videoEditorAudioCategoryDivine,
          ),
          _Chip(
            onTap: () => onSelect(.community),
            isSelected: category == .community,
            label: context.l10n.videoEditorAudioCategoryCommunity,
          ),
          _Chip(
            onTap: () => onSelect(.featured),
            isSelected: category == .featured,
            label: context.l10n.videoEditorAudioCategoryFeatured,
          ),
          _Chip(
            onTap: () => onSelect(.mySounds),
            isSelected: category == .mySounds,
            label: context.l10n.videoEditorAudioCategoryMySounds,
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.isSelected,
    required this.onTap,
    required this.label,
  });

  final VoidCallback onTap;
  final bool isSelected;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const .symmetric(horizontal: 16, vertical: 8),
          decoration: ShapeDecoration(
            color: isSelected ? context.vineColors.containerLow : null,
            shape: RoundedRectangleBorder(borderRadius: .circular(16)),
          ),
          child: Text(
            label,
            style: VineTheme.titleSmallFont(
              color: isSelected
                  ? context.vineColors.accentPositive
                  : context.vineColors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

enum AudioCategory { divine, community, featured, mySounds }
