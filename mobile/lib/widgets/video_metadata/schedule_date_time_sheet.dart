// ABOUTME: Bottom sheet with a date-and-time wheel for a scheduled post.
// ABOUTME: Pops the chosen time (UTC) via context.pop, or null on cancel.

import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoDatePicker;
import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/extensions/modal_pop_extension.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_metadata/schedule_time_policy.dart';

/// Picks when a scheduled post goes out (#3538).
///
/// Shown in a [VineBottomSheet]; pops the chosen time as UTC on confirm, or
/// `null` on cancel. The wheel is bounded by [ScheduleTimePolicy] and steps
/// in its interval; the choice is validated on confirm rather than on every
/// scroll, since the wheel reports positions past its bounds while it snaps
/// back.
class ScheduleDateTimeSheet extends StatefulWidget {
  const ScheduleDateTimeSheet({
    required this.initialTime,
    required this.now,
    super.key,
  });

  /// Where the wheel opens; clamped into the allowed range and snapped to
  /// the step.
  final DateTime? initialTime;

  /// The moment the sheet opened, which fixes the allowed range.
  final DateTime now;

  /// Opens the sheet and returns the chosen time (UTC), or null.
  static Future<DateTime?> show(
    BuildContext context, {
    DateTime? initialTime,
    DateTime? now,
  }) {
    return VineBottomSheet.show<DateTime>(
      context: context,
      expanded: false,
      scrollable: false,
      isScrollControlled: true,
      body: ScheduleDateTimeSheet(
        initialTime: initialTime,
        now: now ?? DateTime.now(),
      ),
    );
  }

  @override
  State<ScheduleDateTimeSheet> createState() => _ScheduleDateTimeSheetState();
}

class _ScheduleDateTimeSheetState extends State<ScheduleDateTimeSheet> {
  late final DateTime _minimum;
  late final DateTime _maximum;
  late DateTime _value;
  ScheduleTimeValidation _validation = ScheduleTimeValidation.ok;

  @override
  void initState() {
    super.initState();
    final now = widget.now.toLocal();
    _minimum = ScheduleTimePolicy.minScheduleTime(now);
    _maximum = ScheduleTimePolicy.maxScheduleTime(now);
    final requested = widget.initialTime?.toLocal();
    var initial = requested == null || requested.isBefore(_minimum)
        ? _minimum
        : ScheduleTimePolicy.roundUpToStep(requested);
    if (initial.isAfter(_maximum)) initial = _minimum;
    _value = initial;
  }

  void _confirm() {
    final validation = ScheduleTimePolicy.validate(
      _value,
      widget.now.toLocal(),
    );
    if (validation != ScheduleTimeValidation.ok) {
      setState(() => _validation = validation);
      return;
    }
    context.popModalIfMounted<DateTime>(_value.toUtc());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final message = switch (_validation) {
      ScheduleTimeValidation.ok => null,
      ScheduleTimeValidation.tooSoon => l10n.videoMetadataScheduleTooSoon(
        ScheduleTimePolicy.minLead.inMinutes,
      ),
      ScheduleTimeValidation.tooFar => l10n.videoMetadataScheduleTooFar(
        ScheduleTimePolicy.maxLead.inDays,
      ),
    };

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
                semanticLabel: l10n.commonCancel,
                onPressed: () => context.popModalIfMounted<DateTime>(),
              ),
              Flexible(
                child: Text(
                  l10n.videoMetadataSchedulePickerTitle,
                  style: VineTheme.titleMediumFont(
                    color: context.vineColors.primaryText,
                  ),
                ),
              ),
              DivineIconButton(
                icon: DivineIconName.check,
                size: DivineIconButtonSize.small,
                semanticLabel: l10n.videoMetadataScheduleButton,
                onPressed: _confirm,
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
          height: 216,
          child: CupertinoDatePicker(
            initialDateTime: _value,
            minimumDate: _minimum,
            maximumDate: _maximum,
            minuteInterval: ScheduleTimePolicy.step.inMinutes,
            use24hFormat: MediaQuery.of(context).alwaysUse24HourFormat,
            backgroundColor: context.vineColors.surface,
            onDateTimeChanged: (value) {
              _value = value;
              if (_validation != ScheduleTimeValidation.ok) {
                setState(() => _validation = ScheduleTimeValidation.ok);
              }
            },
          ),
        ),
        if (message != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              message,
              style: VineTheme.bodyMediumFont(
                color: context.vineColors.accentWarning,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        SizedBox(height: MediaQuery.paddingOf(context).bottom + 8),
      ],
    );
  }
}
