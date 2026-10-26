// ABOUTME: The row of info stickers in the sticker sheet, each shown with a
// ABOUTME: sample of what it looks like; tapping one pops its kind.

import 'package:divine_ui/divine_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/info_sticker.dart';
import 'package:openvine/widgets/video_editor/info_sticker/info_sticker_labels.dart';
import 'package:openvine/widgets/video_editor/info_sticker/info_sticker_view.dart';

/// A horizontal row of every info sticker kind; tapping one pops the sheet
/// with its [InfoStickerKind].
class InfoStickerKindRow extends StatelessWidget {
  const InfoStickerKindRow({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final use24HourFormat = MediaQuery.alwaysUse24HourFormatOf(context);
    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: .horizontal,
        padding: const .symmetric(horizontal: 16),
        itemCount: InfoStickerKind.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final kind = InfoStickerKind.values[index];
          return _KindTile(
            kind: kind,
            sample: _sample(context, kind, locale, use24HourFormat),
          );
        },
      ),
    );
  }

  /// [kind] filled with made-up values, to show what it looks like.
  static InfoStickerData _sample(
    BuildContext context,
    InfoStickerKind kind,
    Locale locale,
    bool use24HourFormat,
  ) {
    final sticker = InfoStickerData.initial(
      kind: kind,
      locale: locale,
      use24HourFormat: use24HourFormat,
    );
    final now = DateTime.now();
    return switch (kind) {
      InfoStickerKind.time ||
      InfoStickerKind.date ||
      InfoStickerKind.moon => sticker.copyWith(dateTime: now),
      InfoStickerKind.dayCount => sticker.copyWith(dayNumber: 12, dayTotal: 30),
      InfoStickerKind.sun => sticker.copyWith(
        sunrise: DateTime(now.year, now.month, now.day, 7),
        sunset: DateTime(now.year, now.month, now.day, 19),
      ),
      InfoStickerKind.recTimer => sticker,
      InfoStickerKind.location => sticker.copyWith(
        placeName: context.l10n.videoEditorInfoStickerLocation,
      ),
      InfoStickerKind.weather => sticker.copyWith(
        weather: InfoStickerWeather.clear,
        temperatureCelsius: 21,
      ),
      InfoStickerKind.altitude => sticker.copyWith(altitudeMeters: 1200),
      InfoStickerKind.battery => sticker.copyWith(batteryLevel: 80),
    };
  }
}

/// One info sticker kind: a sample on a dark ground, and its name.
class _KindTile extends StatelessWidget {
  const _KindTile({required this.kind, required this.sample});

  final InfoStickerKind kind;
  final InfoStickerData sample;

  @override
  Widget build(BuildContext context) {
    final label = context.l10n.infoStickerKindLabel(kind);
    void pick() => context.pop(kind);
    return Semantics(
      label: label,
      button: true,
      onTap: pick,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: pick,
        behavior: .opaque,
        child: SizedBox(
          width: 104,
          child: Column(
            spacing: 8,
            children: [
              SizedBox(
                height: 76,
                width: 104,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: VineTheme.surfaceBackground,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const .all(10),
                    child: FittedBox(child: InfoStickerView(data: sample)),
                  ),
                ),
              ),
              Text(
                label,
                maxLines: 1,
                overflow: .ellipsis,
                style: VineTheme.bodySmallFont(
                  color: context.vineColors.onSurfaceMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
