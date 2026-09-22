// ABOUTME: "Post time" tile on the metadata screen (#3538): now, a preset,
// ABOUTME: or a picked date and time for a scheduled post.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_metadata/schedule_time_policy.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/widgets/video_metadata/schedule_date_time_sheet.dart';
import 'package:openvine/widgets/video_metadata/scheduled_time_format.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_selection_tile.dart';

/// Lets the user post now or pick when the post should go out.
///
/// Reads and writes [VideoEditorProviderState.scheduledAt]. The option menu
/// offers "Now", the quick presets that are still reachable, and a custom
/// date-and-time picker ([ScheduleDateTimeSheet]).
class VideoMetadataScheduleSelector extends ConsumerWidget {
  const VideoMetadataScheduleSelector({this.now, super.key});

  /// Clock override for tests; the presets and bounds derive from it.
  final DateTime Function()? now;

  DateTime _now() => (now ?? DateTime.now)();

  Future<void> _selectTime(BuildContext context, WidgetRef ref) async {
    FocusManager.instance.primaryFocus?.unfocus();

    final l10n = context.l10n;
    final current = ref.read(videoEditorProvider.select((s) => s.scheduledAt));
    final now = _now();
    final tonight = ScheduleTimePolicy.tonight(now);
    final tomorrowMorning = ScheduleTimePolicy.tomorrowMorning(now);

    final choice = await VineBottomSheetSelectionMenu.show(
      context: context,
      selectedValue: current == null
          ? ScheduleTimeOption.now.name
          : ScheduleTimeOption.custom.name,
      headerLeadingAction: DivineIconButton(
        icon: .x,
        onPressed: context.pop,
        type: .secondary,
        size: .small,
        semanticLabel: l10n.commonCancel,
      ),
      title: Text(l10n.videoMetadataScheduleLabel),
      options: [
        VineBottomSheetSelectionOptionData(
          label: l10n.videoMetadataScheduleNow,
          value: ScheduleTimeOption.now.name,
        ),
        if (tonight != null)
          VineBottomSheetSelectionOptionData(
            label: l10n.videoMetadataScheduleTonight(
              formatScheduledClockTime(context, tonight),
            ),
            value: ScheduleTimeOption.tonight.name,
          ),
        VineBottomSheetSelectionOptionData(
          label: l10n.videoMetadataScheduleTomorrowMorning(
            formatScheduledClockTime(context, tomorrowMorning),
          ),
          value: ScheduleTimeOption.tomorrowMorning.name,
        ),
        VineBottomSheetSelectionOptionData(
          label: l10n.videoMetadataSchedulePickDateTime,
          value: ScheduleTimeOption.custom.name,
        ),
      ],
    );
    if (choice == null || !context.mounted) return;

    final option = ScheduleTimeOption.values.firstWhere(
      (o) => o.name == choice,
      orElse: () => ScheduleTimeOption.now,
    );
    final DateTime? picked;
    switch (option) {
      case ScheduleTimeOption.now:
        picked = null;
      case ScheduleTimeOption.tonight:
      case ScheduleTimeOption.tomorrowMorning:
        picked = ScheduleTimePolicy.resolve(option, now);
      case ScheduleTimeOption.custom:
        picked = await ScheduleDateTimeSheet.show(
          context,
          initialTime: current,
          now: now,
        );
        // Cancelling the picker keeps whatever was set before.
        if (picked == null) return;
    }
    if (!context.mounted) return;
    ref.read(videoEditorProvider.notifier).setScheduledAt(picked);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheduledAt = ref.watch(
      videoEditorProvider.select((s) => s.scheduledAt),
    );

    return VideoMetadataSelectionTile(
      onTap: () => _selectTime(context, ref),
      semanticsLabel: context.l10n.videoMetadataSelectScheduleSemanticLabel,
      labelText: context.l10n.videoMetadataScheduleLabel,
      value: scheduledAt == null
          ? context.l10n.videoMetadataScheduleNow
          : formatScheduledDateTime(context, scheduledAt),
    );
  }
}
