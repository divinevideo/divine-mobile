// ABOUTME: The localized names of info sticker kinds and styles, for the
// ABOUTME: sticker sheet, the info sticker sheet and the timeline.

import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/info_sticker.dart';

extension InfoStickerLabels on AppLocalizations {
  /// What [kind] is called: "Time", "Weather" and so on.
  String infoStickerKindLabel(InfoStickerKind kind) => switch (kind) {
    InfoStickerKind.time => videoEditorInfoStickerTime,
    InfoStickerKind.date => videoEditorInfoStickerDate,
    InfoStickerKind.dayCount => videoEditorInfoStickerDayCount,
    InfoStickerKind.location => videoEditorInfoStickerLocation,
    InfoStickerKind.weather => videoEditorInfoStickerWeather,
    InfoStickerKind.sun => videoEditorInfoStickerSun,
    InfoStickerKind.moon => videoEditorInfoStickerMoon,
    InfoStickerKind.altitude => videoEditorInfoStickerAltitude,
    InfoStickerKind.battery => videoEditorInfoStickerBattery,
    InfoStickerKind.recTimer => videoEditorInfoStickerRecTimer,
  };

  /// What [style] is called.
  String infoStickerStyleLabel(InfoStickerStyle style) => switch (style) {
    InfoStickerStyle.light => videoEditorInfoStickerStyleLight,
    InfoStickerStyle.dark => videoEditorInfoStickerStyleDark,
    InfoStickerStyle.glass => videoEditorInfoStickerStyleGlass,
    InfoStickerStyle.brand => videoEditorInfoStickerStyleBrand,
    InfoStickerStyle.highlight => videoEditorInfoStickerStyleHighlight,
    InfoStickerStyle.neon => videoEditorInfoStickerStyleNeon,
    InfoStickerStyle.plain => videoEditorInfoStickerStylePlain,
    InfoStickerStyle.outline => videoEditorInfoStickerStyleOutline,
    InfoStickerStyle.film => videoEditorInfoStickerStyleFilm,
    InfoStickerStyle.camcorder => videoEditorInfoStickerStyleCamcorder,
    InfoStickerStyle.digital => videoEditorInfoStickerStyleDigital,
    InfoStickerStyle.analog => videoEditorInfoStickerStyleAnalog,
  };
}
