// ABOUTME: The emoji info stickers draw: images in Fluent Emoji's 3D style,
// ABOUTME: the same on every phone, instead of the system's emoji font.

import 'package:flutter/widgets.dart';

/// An emoji an info sticker draws, bundled as an image so it looks the same
/// on every phone and in the exported video.
enum InfoStickerEmoji {
  pin('pin'),
  map('map'),
  globeAmericas('globe_americas'),
  globeEuropeAfrica('globe_europe_africa'),
  globeAsiaAustralia('globe_asia_australia'),
  globeMeridians('globe_meridians'),
  mountain('mountain'),
  sunrise('sunrise'),
  sunset('sunset'),
  moonNew('moon_new'),
  moonWaxingCrescent('moon_waxing_crescent'),
  moonFirstQuarter('moon_first_quarter'),
  moonWaxingGibbous('moon_waxing_gibbous'),
  moonFull('moon_full'),
  moonWaningGibbous('moon_waning_gibbous'),
  moonLastQuarter('moon_last_quarter'),
  moonWaningCrescent('moon_waning_crescent'),
  sun('weather_sun'),
  crescentMoon('weather_moon'),
  sunBehindCloud('weather_sun_behind_cloud'),
  cloud('weather_cloud'),
  fog('weather_fog'),
  rain('weather_rain'),
  sunBehindRainCloud('weather_sun_behind_rain_cloud'),
  snow('weather_snow'),
  thunderstorm('weather_thunderstorm');

  const InfoStickerEmoji(this._file);

  final String _file;

  String get assetPath => 'assets/info_stickers/$_file.png';
}

/// [emoji], [size] logical pixels square.
class InfoStickerEmojiImage extends StatelessWidget {
  const InfoStickerEmojiImage(this.emoji, {required this.size, super.key});

  final InfoStickerEmoji emoji;
  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
    emoji.assetPath,
    width: size,
    height: size,
    excludeFromSemantics: true,
    // A sticker that changes its emoji keeps showing the last one until the
    // next has loaded, instead of flickering through nothing.
    gaplessPlayback: true,
  );
}
