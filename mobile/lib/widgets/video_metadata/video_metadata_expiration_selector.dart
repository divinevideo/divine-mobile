import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_metadata/video_metadata_expiration.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_selection_tile.dart';

/// UI-side localization for [VideoMetadataExpiration]. Lives in the widget
/// layer so the model itself stays free of Flutter imports.
extension VideoMetadataExpirationL10n on VideoMetadataExpiration {
  /// Returns the localized label for this expiration option.
  String localizedLabel(BuildContext context) {
    return switch (this) {
      VideoMetadataExpiration.notExpire =>
        context.l10n.videoMetadataExpirationNotExpire,
      VideoMetadataExpiration.oneDay =>
        context.l10n.videoMetadataExpirationOneDay,
      VideoMetadataExpiration.oneWeek =>
        context.l10n.videoMetadataExpirationOneWeek,
      VideoMetadataExpiration.oneMonth =>
        context.l10n.videoMetadataExpirationOneMonth,
      VideoMetadataExpiration.oneYear =>
        context.l10n.videoMetadataExpirationOneYear,
      VideoMetadataExpiration.oneDecade =>
        context.l10n.videoMetadataExpirationOneDecade,
    };
  }
}

/// Widget for selecting video expiration time.
///
/// Displays the currently selected expiration option and opens
/// a bottom sheet with all available options when tapped.
class VideoMetadataExpirationSelector extends ConsumerWidget {
  /// Creates a video expiration selector.
  const VideoMetadataExpirationSelector({super.key});

  /// Opens the bottom sheet for selecting expiration time.
  Future<void> _selectExpiration(BuildContext context, WidgetRef ref) async {
    // Dismiss keyboard before showing bottom sheet
    FocusManager.instance.primaryFocus?.unfocus();

    final currentOption = ref.read(
      videoEditorProvider.select((s) => s.expiration),
    );

    final result = await VineBottomSheetSelectionMenu.show(
      context: context,
      selectedValue: currentOption.name,
      headerLeadingAction: DivineIconButton(
        icon: .x,
        onPressed: context.pop,
        type: .secondary,
        size: .small,
      ),
      title: Text(context.l10n.videoMetadataExpiration),
      options: VideoMetadataExpiration.values.map((option) {
        return VineBottomSheetSelectionOptionData(
          label: option.localizedLabel(context),
          value: option.name,
        );
      }).toList(),
    );

    if (result != null && context.mounted) {
      final option = VideoMetadataExpiration.values.firstWhere(
        (el) => el.name == result,
        orElse: () => .notExpire,
      );
      ref.read(videoEditorProvider.notifier).setExpiration(option);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get currently selected expiration option
    final currentOption = ref.watch(
      videoEditorProvider.select((s) => s.expiration),
    );

    return VideoMetadataSelectionTile(
      onTap: () => _selectExpiration(context, ref),
      semanticsLabel: context.l10n.videoMetadataSelectExpirationSemanticLabel,
      labelText: context.l10n.videoMetadataExpirationLabel,
      value: currentOption.localizedLabel(context),
    );
  }
}
