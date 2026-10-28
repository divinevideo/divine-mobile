// ABOUTME: An info sticker (time, date, day count, place, weather, sun, moon,
// ABOUTME: altitude, battery or REC timer), kept in the meta of its layer.

import 'dart:ui' show Locale;

import 'package:equatable/equatable.dart';
import 'package:intl/intl.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

/// The meta key that names what kind of widget layer a layer is.
const String infoStickerLayerKindKey = 'kind';

/// The [infoStickerLayerKindKey] value of an info sticker layer.
const String infoStickerLayerKind = 'divine.infoSticker';

/// What an info sticker shows.
enum InfoStickerKind {
  time,
  date,
  dayCount,
  location,
  weather,
  sun,
  moon,
  altitude,
  battery,

  /// A camcorder's recording timer that runs with the video.
  recTimer;

  /// The looks this kind can take, the default first.
  List<InfoStickerStyle> get styles => switch (this) {
    time => const [..._cardStyles, .film, .camcorder, .digital, .analog],
    date => const [..._cardStyles, .film, .camcorder],
    recTimer => const [.camcorder, .dark, .digital, .film],
    _ => _cardStyles,
  };

  static const List<InfoStickerStyle> _cardStyles = [
    .light,
    .dark,
    .glass,
    .brand,
    .highlight,
    .neon,
    .plain,
    .outline,
  ];

  /// Whether the sheet searches a place for this kind: the place itself for
  /// a location sticker, where to read the weather, the sun or the altitude
  /// for the others.
  bool get searchesPlace =>
      this == location || this == weather || this == sun || this == altitude;

  /// Whether the sticker shows a moment, which starts at the time the clip
  /// was recorded and can be switched to now.
  bool get showsMoment => this == time || this == date || this == moon;
}

/// How an info sticker looks.
enum InfoStickerStyle {
  /// A white pill with dark text.
  light,

  /// A dark see-through pill with white text.
  dark,

  /// A pale see-through pill with white text, the video showing through.
  glass,

  /// A Divine green pill with dark text.
  brand,

  /// A yellow pill with dark text, like a highlighter.
  highlight,

  /// White text glowing green, with no pill.
  neon,

  /// White text with a soft shadow, with no pill.
  plain,

  /// White text in a white outline.
  outline,

  /// Glowing orange digits, like the date a film camera prints on a photo.
  film,

  /// A camcorder's viewfinder: a red recording dot and white digits.
  camcorder,

  /// Green digits on a dark panel.
  digital,

  /// A clock face with hands; time only.
  analog,
}

/// How a date sticker writes its date.
enum InfoStickerDateFormat {
  weekday,
  dayMonth,
  full,
  numeric,

  /// A film camera's date stamp, such as `'26 10 26`.
  stamp,
}

/// What a location sticker shows in front of the place's name.
enum InfoStickerPlaceSymbol {
  pin,

  /// The flag of the place's country.
  flag,

  /// A globe turned to the place's side of the world.
  globe,

  /// A folded map.
  map,
}

/// The side of the world a globe shows, for a location sticker's globe.
///
/// Kept instead of the place's longitude, which would say far more about
/// where the place is than the sticker shows.
enum InfoStickerGlobe {
  americas,
  europeAfrica,
  asiaPacific;

  /// Where the globe with the Americas ends in the east, in degrees.
  static const double _americasEast = -25;

  /// Where the globe with the Americas ends in the west; the Pacific islands
  /// past it sit on the one with Asia and Australia.
  static const double _americasWest = -170;

  /// Where the globe with Europe and Africa ends in the east.
  static const double _europeAfricaEast = 60;

  /// The globe that shows [longitude], in degrees east.
  static InfoStickerGlobe at(double longitude) {
    if (longitude >= _americasWest && longitude < _americasEast) {
      return americas;
    }
    if (longitude >= _americasEast && longitude < _europeAfricaEast) {
      return europeAfrica;
    }
    return asiaPacific;
  }
}

/// The phase of the moon, in eight steps from new moon to new moon.
enum InfoStickerMoonPhase {
  newMoon,
  waxingCrescent,
  firstQuarter,
  waxingGibbous,
  fullMoon,
  waningGibbous,
  lastQuarter,
  waningCrescent;

  /// The length of a lunar month in days.
  static const double _synodicMonth = 29.530588853;

  /// A new moon to count from.
  static final DateTime _knownNewMoon = DateTime.utc(2000, 1, 6, 18, 14);

  /// The phase at [time], to within a few hours; plenty for a sticker.
  static InfoStickerMoonPhase at(DateTime time) {
    final days =
        time.toUtc().difference(_knownNewMoon).inMinutes /
        Duration.minutesPerDay;
    final age = days % _synodicMonth;
    // Each phase is centred on its moment, so the new moon covers the last
    // and the first sixteenth of the month.
    final step = ((age / _synodicMonth) * 8 + 0.5).floor() % 8;
    return values[step];
  }
}

/// The weather a weather sticker shows, grouped from MET Norway's symbols.
enum InfoStickerWeather {
  clear,
  partlyCloudy,
  cloudy,
  fog,
  drizzle,
  rain,
  snow,
  showers,
  thunderstorm;

  /// The group of a MET Norway weather [symbol] such as `rainshowers_day`, or
  /// `null` for a symbol it does not know. Sleet counts as rain.
  static InfoStickerWeather? fromMetSymbol(String symbol) {
    final weather = symbol.split('_').first;
    if (weather.contains('thunder')) return thunderstorm;
    if (weather.contains('snow')) return snow;
    if (weather.contains('showers')) return showers;
    return switch (weather) {
      'clearsky' => clear,
      'fair' || 'partlycloudy' => partlyCloudy,
      'cloudy' => cloudy,
      'fog' => fog,
      'lightrain' => drizzle,
      'rain' || 'heavyrain' || 'lightsleet' || 'sleet' || 'heavysleet' => rain,
      _ => null,
    };
  }
}

/// What an info sticker layer shows and how it looks.
///
/// Stored in both meta slots of its `WidgetLayer`, like an audio visualizer,
/// so it survives undo, drafts and the re-import of a draft. Every value is
/// the one the sticker showed when the creator placed it: the sticker is drawn
/// into the video, so nothing is looked up again when a draft reopens. A place
/// is kept by name only, never by coordinates.
class InfoStickerData extends Equatable {
  const InfoStickerData({
    required this.kind,
    required this.localeName,
    this.style = InfoStickerStyle.light,
    this.dateTime,
    this.use24HourFormat = false,
    this.dateFormat = InfoStickerDateFormat.dayMonth,
    this.placeName,
    this.countryCode,
    this.placeSymbol = InfoStickerPlaceSymbol.pin,
    this.globe,
    this.dayNumber,
    this.dayTotal,
    this.sunrise,
    this.sunset,
    this.weather,
    this.isDay = true,
    this.temperatureCelsius,
    this.useFahrenheit = false,
    this.altitudeMeters,
    this.useFeet = false,
    this.batteryLevel,
  });

  /// A new sticker of [kind] as the sheet opens it: in the first style its
  /// kind takes, in [locale]'s language written the way the region
  /// [regionCode] writes dates where that is known (`de_CH`, `en_GB`), and
  /// with temperature and altitude in that region's units.
  factory InfoStickerData.initial({
    required InfoStickerKind kind,
    required Locale locale,
    required bool use24HourFormat,
    String? regionCode,
  }) => InfoStickerData(
    kind: kind,
    localeName: _formatLocale(locale, regionCode),
    style: kind.styles.first,
    use24HourFormat: use24HourFormat,
    dayNumber: kind == InfoStickerKind.dayCount ? 1 : null,
    useFahrenheit: _fahrenheitRegions.contains(regionCode),
    useFeet: _feetRegions.contains(regionCode),
  );

  /// [locale]'s language in [regionCode]'s date conventions when the date
  /// data knows that pair, and the language alone otherwise.
  static String _formatLocale(Locale locale, String? regionCode) {
    if (regionCode != null) {
      final regional = '${locale.languageCode}_$regionCode';
      if (DateFormat.localeExists(regional)) return regional;
    }
    return locale.toString();
  }

  /// Regions that give the temperature in degrees Fahrenheit.
  static const _fahrenheitRegions = {'US', 'BS', 'BZ', 'KY', 'PW', 'LR'};

  /// Regions that give altitudes in feet.
  static const _feetRegions = {'US', 'LR', 'MM'};

  /// What the sticker shows.
  final InfoStickerKind kind;

  /// How the sticker looks.
  final InfoStickerStyle style;

  /// The locale the sticker writes its text in, as `Locale.toString` gives
  /// it (`de` or `en_US`). Kept so a draft reopened in another language looks
  /// the way it was published.
  final String localeName;

  /// The wall-clock time a time or date sticker shows, or the time a weather
  /// sticker read the weather for. Kept without a time zone, so it reads the
  /// same anywhere.
  final DateTime? dateTime;

  /// Whether a time sticker writes 24-hour time.
  final bool use24HourFormat;

  /// How a date sticker writes its date.
  final InfoStickerDateFormat dateFormat;

  /// The name of the place a location sticker shows.
  final String? placeName;

  /// The ISO 3166 code of the country the place is in, for its flag.
  final String? countryCode;

  /// What a location sticker shows in front of the place's name.
  final InfoStickerPlaceSymbol placeSymbol;

  /// The side of the world the place is on, for a globe in front of it.
  final InfoStickerGlobe? globe;

  /// The day a day counter shows, such as 12 in "Day 12 of 30".
  final int? dayNumber;

  /// How many days a day counter counts to, or `null` for no end.
  final int? dayTotal;

  /// The wall-clock time the sun rose at the place, in its own time zone.
  final DateTime? sunrise;

  /// The wall-clock time the sun set at the place, in its own time zone.
  final DateTime? sunset;

  /// The weather a weather sticker shows.
  final InfoStickerWeather? weather;

  /// Whether it was day when the weather was read, for a sun or a moon.
  final bool isDay;

  /// The temperature a weather sticker shows.
  final double? temperatureCelsius;

  /// Whether a weather sticker shows the temperature in degrees Fahrenheit.
  final bool useFahrenheit;

  /// The altitude an altitude sticker shows.
  final double? altitudeMeters;

  /// Whether an altitude sticker shows feet rather than metres.
  final bool useFeet;

  /// The battery level a battery sticker shows, from 0 to 100.
  final int? batteryLevel;

  /// Whether the sticker has everything it needs to be placed.
  bool get isComplete => switch (kind) {
    InfoStickerKind.time ||
    InfoStickerKind.date ||
    InfoStickerKind.moon => dateTime != null,
    InfoStickerKind.dayCount => dayNumber != null,
    InfoStickerKind.location => placeName != null,
    InfoStickerKind.sun => sunrise != null || sunset != null,
    InfoStickerKind.recTimer => true,
    InfoStickerKind.weather => temperatureCelsius != null,
    InfoStickerKind.altitude => altitudeMeters != null,
    InfoStickerKind.battery => batteryLevel != null,
  };

  /// The temperature in the unit the sticker shows, rounded.
  int? get displayTemperature {
    final celsius = temperatureCelsius;
    if (celsius == null) return null;
    return (useFahrenheit ? celsius * 9 / 5 + 32 : celsius).round();
  }

  /// The altitude in the unit the sticker shows, rounded.
  int? get displayAltitude {
    final meters = altitudeMeters;
    if (meters == null) return null;
    return (useFeet ? meters / _metersPerFoot : meters).round();
  }

  static const double _metersPerFoot = 0.3048;

  /// [localeName] as a [Locale].
  Locale get locale {
    final [language, ...rest] = localeName.split(RegExp('[_-]'));
    return Locale(language, rest.isEmpty ? null : rest.last);
  }

  /// [value] in the unit the sticker shows its temperature in, as Celsius.
  double celsiusFromDisplay(num value) =>
      useFahrenheit ? (value - 32) * 5 / 9 : value.toDouble();

  /// [value] in the unit the sticker shows its altitude in, as metres.
  double metersFromDisplay(num value) =>
      useFeet ? value * _metersPerFoot : value.toDouble();

  /// The meta stored on the layer.
  Map<String, dynamic> toMeta() => {
    infoStickerLayerKindKey: infoStickerLayerKind,
    'infoKind': kind.name,
    'style': style.name,
    'locale': localeName,
    if (dateTime case final dateTime?)
      'dateTime': _wallClock(dateTime).toIso8601String(),
    'use24HourFormat': use24HourFormat,
    'dateFormat': dateFormat.name,
    'placeName': ?placeName,
    'countryCode': ?countryCode,
    'placeSymbol': placeSymbol.name,
    'globe': ?globe?.name,
    'dayNumber': ?dayNumber,
    'dayTotal': ?dayTotal,
    if (sunrise case final sunrise?)
      'sunrise': _wallClock(sunrise).toIso8601String(),
    if (sunset case final sunset?)
      'sunset': _wallClock(sunset).toIso8601String(),
    'weather': ?weather?.name,
    'isDay': isDay,
    'temperatureCelsius': ?temperatureCelsius,
    'useFahrenheit': useFahrenheit,
    'altitudeMeters': ?altitudeMeters,
    'useFeet': useFeet,
    'batteryLevel': ?batteryLevel,
  };

  /// This sticker with what is given changed.
  InfoStickerData copyWith({
    InfoStickerStyle? style,
    DateTime? dateTime,
    InfoStickerDateFormat? dateFormat,
    String? placeName,
    String? countryCode,
    InfoStickerPlaceSymbol? placeSymbol,
    InfoStickerGlobe? globe,
    int? dayNumber,
    bool clearDayNumber = false,
    int? dayTotal,
    bool clearDayTotal = false,
    DateTime? sunrise,
    DateTime? sunset,
    InfoStickerWeather? weather,
    bool? isDay,
    double? temperatureCelsius,
    bool clearTemperatureCelsius = false,
    bool? useFahrenheit,
    double? altitudeMeters,
    bool clearAltitudeMeters = false,
    bool? useFeet,
    int? batteryLevel,
  }) => InfoStickerData(
    kind: kind,
    localeName: localeName,
    style: style ?? this.style,
    dateTime: dateTime ?? this.dateTime,
    use24HourFormat: use24HourFormat,
    dateFormat: dateFormat ?? this.dateFormat,
    placeName: placeName ?? this.placeName,
    countryCode: countryCode ?? this.countryCode,
    placeSymbol: placeSymbol ?? this.placeSymbol,
    globe: globe ?? this.globe,
    dayNumber: clearDayNumber ? null : dayNumber ?? this.dayNumber,
    dayTotal: clearDayTotal ? null : dayTotal ?? this.dayTotal,
    sunrise: sunrise ?? this.sunrise,
    sunset: sunset ?? this.sunset,
    weather: weather ?? this.weather,
    isDay: isDay ?? this.isDay,
    temperatureCelsius: clearTemperatureCelsius
        ? null
        : temperatureCelsius ?? this.temperatureCelsius,
    useFahrenheit: useFahrenheit ?? this.useFahrenheit,
    altitudeMeters: clearAltitudeMeters
        ? null
        : altitudeMeters ?? this.altitudeMeters,
    useFeet: useFeet ?? this.useFeet,
    batteryLevel: batteryLevel ?? this.batteryLevel,
  );

  /// This sticker without what a place gave it: the place name, country and
  /// side of the world, the weather, the sun times and the altitude.
  /// [copyWith] cannot unset them, so another place's values start from
  /// here, and a value the new place lacks is not left over from the last
  /// one.
  InfoStickerData withoutPlaceValues() => InfoStickerData(
    kind: kind,
    localeName: localeName,
    style: style,
    dateTime: dateTime,
    use24HourFormat: use24HourFormat,
    dateFormat: dateFormat,
    placeSymbol: placeSymbol,
    dayNumber: dayNumber,
    dayTotal: dayTotal,
    useFahrenheit: useFahrenheit,
    useFeet: useFeet,
    batteryLevel: batteryLevel,
  );

  /// Whether [meta] describes an info sticker.
  static bool isInfoStickerMeta(Map<String, dynamic>? meta) =>
      meta != null && meta[infoStickerLayerKindKey] == infoStickerLayerKind;

  /// Whether [layer] is an info sticker, checked on the kind alone.
  static bool isInfoStickerLayer(Layer layer) =>
      layer is WidgetLayer &&
      (isInfoStickerMeta(layer.exportConfigs.meta) ||
          isInfoStickerMeta(layer.meta));

  /// The sticker [meta] describes, or `null` when it describes none or names
  /// a kind this version does not know. Anything else missing or unreadable
  /// takes its default.
  static InfoStickerData? fromMeta(Map<String, dynamic>? meta) {
    if (!isInfoStickerMeta(meta)) return null;
    final kind = _byName(InfoStickerKind.values, meta!['infoKind']);
    if (kind == null) return null;
    final style = _byName(InfoStickerStyle.values, meta['style']);
    final dateTime = meta['dateTime'];
    final battery = meta['batteryLevel'];
    final sunrise = meta['sunrise'];
    final sunset = meta['sunset'];
    final dayNumber = meta['dayNumber'];
    final dayTotal = meta['dayTotal'];
    return InfoStickerData(
      kind: kind,
      localeName: meta['locale'] is String ? meta['locale'] as String : 'en',
      style: style != null && kind.styles.contains(style)
          ? style
          : kind.styles.first,
      dateTime: dateTime is String ? DateTime.tryParse(dateTime) : null,
      use24HourFormat: meta['use24HourFormat'] == true,
      dateFormat:
          _byName(InfoStickerDateFormat.values, meta['dateFormat']) ??
          InfoStickerDateFormat.dayMonth,
      placeName: meta['placeName'] is String
          ? meta['placeName'] as String
          : null,
      countryCode: meta['countryCode'] is String
          ? meta['countryCode'] as String
          : null,
      placeSymbol:
          _byName(InfoStickerPlaceSymbol.values, meta['placeSymbol']) ??
          InfoStickerPlaceSymbol.pin,
      globe: _byName(InfoStickerGlobe.values, meta['globe']),
      dayNumber: dayNumber is int ? dayNumber : null,
      dayTotal: dayTotal is int ? dayTotal : null,
      sunrise: sunrise is String ? DateTime.tryParse(sunrise) : null,
      sunset: sunset is String ? DateTime.tryParse(sunset) : null,
      weather: _byName(InfoStickerWeather.values, meta['weather']),
      isDay: meta['isDay'] != false,
      temperatureCelsius: _double(meta['temperatureCelsius']),
      useFahrenheit: meta['useFahrenheit'] == true,
      altitudeMeters: _double(meta['altitudeMeters']),
      useFeet: meta['useFeet'] == true,
      batteryLevel: battery is int && battery >= 0 && battery <= 100
          ? battery
          : null,
    );
  }

  /// The sticker [layer] shows, read from whichever of its two meta slots
  /// holds it: `exportConfigs.meta` on a re-imported layer, `Layer.meta` on
  /// one built in this session.
  static InfoStickerData? of(Layer layer) {
    if (layer is! WidgetLayer) return null;
    return fromMeta(layer.exportConfigs.meta) ?? fromMeta(layer.meta);
  }

  static T? _byName<T extends Enum>(List<T> values, Object? name) =>
      values.where((value) => value.name == name).firstOrNull;

  static double? _double(Object? value) =>
      value is num ? value.toDouble() : null;

  /// [dateTime] as a time-zone-free wall-clock time, so its ISO string carries
  /// no `Z` and parses back to the same hour anywhere.
  static DateTime _wallClock(DateTime dateTime) => DateTime(
    dateTime.year,
    dateTime.month,
    dateTime.day,
    dateTime.hour,
    dateTime.minute,
  );

  @override
  List<Object?> get props => [
    kind,
    style,
    localeName,
    dateTime,
    use24HourFormat,
    dateFormat,
    placeName,
    countryCode,
    placeSymbol,
    globe,
    dayNumber,
    dayTotal,
    sunrise,
    sunset,
    weather,
    isDay,
    temperatureCelsius,
    useFahrenheit,
    altitudeMeters,
    useFeet,
    batteryLevel,
  ];
}
