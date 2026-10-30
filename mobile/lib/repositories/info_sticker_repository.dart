// ABOUTME: Looks up what info stickers show: places from the phone's geocoder,
// ABOUTME: weather and altitude from MET Norway, sun times, battery and time.

import 'dart:async';
import 'dart:convert';
import 'dart:ui' show Locale;

import 'package:battery_plus/battery_plus.dart';
import 'package:clock/clock.dart';
import 'package:daylight/daylight.dart';
import 'package:equatable/equatable.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/info_sticker.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show ProVideoEditor;

/// A place the place search found.
class InfoStickerPlace extends Equatable {
  const InfoStickerPlace({
    required this.name,
    required this.address,
    this.detail,
    this.countryCode,
  });

  /// What the place is called: a town, a district or a mountain.
  final String name;

  /// Where it is, such as "Bern, Schweiz", or `null` when [name] says it all.
  final String? detail;

  /// What the geocoder is asked to find the place again, and what a viewer's
  /// map app searches for on the published sticker: [name] with everything
  /// that tells it apart, such as "Zermatt, Wallis, Schweiz". The search names
  /// places without their coordinates.
  final String address;

  /// The ISO 3166 code of its country, such as `CH`.
  final String? countryCode;

  @override
  List<Object?> get props => [name, detail, address, countryCode];
}

/// Where a place is, in degrees.
typedef InfoStickerCoordinates = ({double latitude, double longitude});

/// The weather at a place and time.
class InfoStickerWeatherReading extends Equatable {
  const InfoStickerWeatherReading({
    required this.temperatureCelsius,
    required this.isDay,
    this.weather,
  });

  final double temperatureCelsius;
  final bool isDay;

  /// The kind of weather, or `null` for a symbol MET Norway has no group for.
  final InfoStickerWeather? weather;

  @override
  List<Object?> get props => [temperatureCelsius, isDay, weather];
}

/// When the sun rose and set at a place on a day, as wall-clock times of the
/// phone: the search tells no place's time zone. Either is `null` on a day it
/// does not happen, near the poles.
typedef InfoStickerSunTimes = ({DateTime? sunrise, DateTime? sunset});

/// A lookup for an info sticker failed: the service could not be reached,
/// did not answer in time, or answered with something unreadable.
class InfoStickerLookupException implements Exception {
  const InfoStickerLookupException(this.message);

  final String message;

  @override
  String toString() => 'InfoStickerLookupException: $message';
}

/// The weather was asked for an hour too long ago: MET Norway only tells the
/// weather from the current hour on.
class InfoStickerWeatherTooOldException extends InfoStickerLookupException {
  const InfoStickerWeatherTooOldException()
    : super('No weather for an hour that long ago');
}

/// Settings of [InfoStickerRepository].
abstract final class InfoStickerRepositoryConfig {
  /// How long a lookup may take. Android's geocoder never answers a request
  /// that fails, so the place search needs this to end at all.
  static const Duration requestTimeout = Duration(seconds: 10);

  /// How many places a search lists at most: as many as Android's geocoder
  /// finds.
  static const int maxPlaces = 5;

  /// How long before the current hour a recording may be for its weather:
  /// the current hour's then stands in for it. MET Norway keeps no hour
  /// that has passed.
  static const Duration weatherHistory = Duration(hours: 1);

  static const String metHost = 'api.met.no';
  static const String forecastPath = '/weatherapi/locationforecast/2.0/compact';

  /// How the app introduces itself to MET Norway, whose terms ask every
  /// request to name the app and a way to reach its makers.
  static const String userAgent = 'DivineMobile/1.0 (+https://divine.video)';
}

/// Looks up what info stickers show.
///
/// A place is searched by name with the phone's own geocoder, so the app
/// never asks for the device's position, and a street address is shown by
/// its town only. Its coordinates are only used to ask MET Norway for the
/// weather or the altitude there and to work out the sun times, and are never
/// kept on a sticker. MET Norway receives the coordinates, never who is
/// asking.
class InfoStickerRepository {
  InfoStickerRepository({
    http.Client? client,
    Geocoding? geocoding,
    Battery? battery,
    ProVideoEditor? videoEditor,
  }) : _client = client ?? http.Client(),
       _geocodingOverride = geocoding,
       _batteryOverride = battery,
       _videoEditor = videoEditor ?? ProVideoEditor.instance;

  final http.Client _client;
  final Geocoding? _geocodingOverride;
  final Battery? _batteryOverride;
  final ProVideoEditor _videoEditor;
  final _coordinates = <String, InfoStickerCoordinates>{};
  final _forecasts = <String, Future<Map<String, dynamic>>>{};

  // Created on first use: both reach a platform plugin when they are built.
  // The web has no geocoder plugin at all.
  late final Geocoding? _geocoder =
      _geocodingOverride ??
      (GeocodingPlatformFactory.instance == null ? null : Geocoding());
  late final Battery _battery = _batteryOverride ?? Battery();

  /// Closes the HTTP client. Lookups still running then fail with an
  /// [InfoStickerLookupException].
  void close() => _client.close();

  /// Whether the phone has a place search at all. Android phones without
  /// Google's services have none, and neither has the web.
  Future<bool> isPlaceSearchAvailable() async {
    final geocoder = _geocoder;
    if (geocoder == null) return false;
    try {
      return await geocoder.isPresent();
    } on Exception {
      return false;
    }
  }

  /// The places [query] finds, named in [languageCode], at most
  /// [InfoStickerRepositoryConfig.maxPlaces] and none twice.
  ///
  /// Throws an [InfoStickerLookupException] when the phone has no geocoder or
  /// it does not answer in time.
  Future<List<InfoStickerPlace>> searchPlaces(
    String query, {
    required String languageCode,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    final List<Placemark> placemarks;
    try {
      placemarks = await _requireGeocoder()
          .placemarkFromAddress(trimmed, locale: Locale(languageCode))
          .timeout(InfoStickerRepositoryConfig.requestTimeout);
    } on TimeoutException {
      throw const InfoStickerLookupException('The place search timed out');
    } on InfoStickerLookupException {
      rethrow;
    } on Exception {
      // Both geocoders report a search that found nothing as an error.
      return const [];
    }
    final places = <String, InfoStickerPlace>{};
    for (final placemark in placemarks) {
      final place = _placeOf(placemark);
      if (place == null) continue;
      places.putIfAbsent('${place.name}|${place.detail}', () => place);
      if (places.length == InfoStickerRepositoryConfig.maxPlaces) break;
    }
    return places.values.toList();
  }

  /// Where [place] is.
  ///
  /// Throws an [InfoStickerLookupException] when the geocoder cannot find it
  /// again or does not answer in time.
  Future<InfoStickerCoordinates> locate(InfoStickerPlace place) async {
    final known = _coordinates[place.address];
    if (known != null) return known;
    final List<Location> locations;
    try {
      locations = await _requireGeocoder()
          .locationFromAddress(place.address)
          .timeout(InfoStickerRepositoryConfig.requestTimeout);
    } on TimeoutException {
      throw const InfoStickerLookupException('Locating the place timed out');
    } on InfoStickerLookupException {
      rethrow;
    } on Exception catch (error) {
      throw InfoStickerLookupException('Place not found: $error');
    }
    if (locations.isEmpty) {
      throw const InfoStickerLookupException('Place not found');
    }
    final location = locations.first;
    return _coordinates[place.address] = (
      latitude: location.latitude,
      longitude: location.longitude,
    );
  }

  /// The weather at [place] at [time].
  ///
  /// Throws an [InfoStickerWeatherTooOldException] when [time] lies more than
  /// [InfoStickerRepositoryConfig.weatherHistory] before the current hour,
  /// and an [InfoStickerLookupException] when the place cannot be found or
  /// MET Norway cannot be reached or has no value for that hour.
  Future<InfoStickerWeatherReading> weatherAt(
    InfoStickerPlace place,
    DateTime time,
  ) async {
    final hour = _hourOf(time.toUtc());
    if (_hourOf(clock.now().toUtc()).difference(hour) >
        InfoStickerRepositoryConfig.weatherHistory) {
      throw const InfoStickerWeatherTooOldException();
    }
    final coordinates = await locate(place);
    final forecast = await _forecast(coordinates);
    final properties = forecast['properties'];
    final series = properties is Map ? properties['timeseries'] : null;
    final entry = series is List ? _entryAt(series, hour) : null;
    final data = entry?['data'];
    final instant = data is Map ? data['instant'] : null;
    final details = instant is Map ? instant['details'] : null;
    final temperature = details is Map ? details['air_temperature'] : null;
    if (data is! Map || temperature is! num) {
      throw const InfoStickerLookupException('No weather for that hour');
    }
    final symbol = _symbolOf(data);
    return InfoStickerWeatherReading(
      temperatureCelsius: temperature.toDouble(),
      isDay: switch (symbol?.split('_').last) {
        'day' => true,
        'night' || 'polartwilight' => false,
        _ => _isSunUp(coordinates, hour),
      },
      weather: symbol == null ? null : InfoStickerWeather.fromMetSymbol(symbol),
    );
  }

  /// When the sun rose and set at [place] on the day of [day], as wall-clock
  /// times of the phone.
  ///
  /// Throws an [InfoStickerLookupException] when the place cannot be found or
  /// the sun neither rose nor set there that day.
  Future<InfoStickerSunTimes> sunTimesAt(
    InfoStickerPlace place,
    DateTime day,
  ) async {
    final coordinates = await locate(place);
    final times = _daylightAt(
      coordinates,
    ).calculateForDay(DateTime.utc(day.year, day.month, day.day));
    if (times.sunrise == null && times.sunset == null) {
      throw const InfoStickerLookupException(
        'The sun neither rose nor set there that day',
      );
    }
    return (
      sunrise: _phoneTime(times.sunrise),
      sunset: _phoneTime(times.sunset),
    );
  }

  /// The altitude of [place] above sea level, in metres, from MET Norway's
  /// terrain model.
  ///
  /// Throws an [InfoStickerLookupException] when the place cannot be found or
  /// MET Norway cannot be reached.
  Future<double> elevationAt(InfoStickerPlace place) async {
    final forecast = await _forecast(await locate(place));
    final geometry = forecast['geometry'];
    final point = geometry is Map ? geometry['coordinates'] : null;
    if (point is List && point.length > 2 && point[2] is num) {
      return (point[2] as num).toDouble();
    }
    throw const InfoStickerLookupException('No altitude in the answer');
  }

  /// The battery level, from 0 to 100.
  ///
  /// Throws an [InfoStickerLookupException] when the platform cannot tell,
  /// or has no battery plugin at all.
  Future<int> batteryLevel() async {
    try {
      return (await _battery.batteryLevel).clamp(0, 100);
    } on Exception catch (error) {
      throw InfoStickerLookupException('No battery level: $error');
    }
  }

  /// When [clip] was recorded, as local time.
  ///
  /// A clip picked from the gallery was added to the editor long after it was
  /// shot, so the date its file carries comes first. A file date that names
  /// no time zone, lies before 2000 (an unset MP4 date reads as 1904) or in
  /// the future is ignored, and so is a file that cannot be read: the time
  /// the clip was added is then the best there is.
  Future<DateTime> recordingTimeOf(DivineVideoClip clip) async {
    final video = clip.video;
    if (video == null) return clip.recordedAt;
    try {
      final metadata = await _videoEditor
          .getMetadata(video)
          .timeout(InfoStickerRepositoryConfig.requestTimeout);
      final date = metadata.date;
      if (date != null &&
          date.isUtc &&
          date.year >= 2000 &&
          !date.isAfter(clock.now().toUtc())) {
        return date.toLocal();
      }
    } on Exception {
      // The file date is a refinement: a file that cannot be read in time,
      // or by a platform without the plugin, keeps the clip's own time.
    }
    return clip.recordedAt;
  }

  Geocoding _requireGeocoder() =>
      _geocoder ??
      (throw const InfoStickerLookupException('This platform has no geocoder'));

  /// MET Norway's forecast for [coordinates], asked for once per place.
  ///
  /// Its terms ask for at most four decimals, which also keeps nearby
  /// places on one answer.
  Future<Map<String, dynamic>> _forecast(InfoStickerCoordinates coordinates) {
    final latitude = coordinates.latitude.toStringAsFixed(4);
    final longitude = coordinates.longitude.toStringAsFixed(4);
    final key = '$latitude,$longitude';
    final asked = _forecasts[key];
    if (asked != null) return asked;
    final request = _getJson(
      Uri.https(
        InfoStickerRepositoryConfig.metHost,
        InfoStickerRepositoryConfig.forecastPath,
        {'lat': latitude, 'lon': longitude},
      ),
    );
    _forecasts[key] = request;
    // A failed answer is not kept, so asking again can succeed.
    unawaited(
      request.then<void>(
        (_) {},
        onError: (Object _) => _forecasts.remove(key)?.ignore(),
      ),
    );
    return request;
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final http.Response response;
    try {
      response = await _client
          .get(
            uri,
            headers: const {
              'User-Agent': InfoStickerRepositoryConfig.userAgent,
            },
          )
          .timeout(InfoStickerRepositoryConfig.requestTimeout);
    } on TimeoutException {
      throw InfoStickerLookupException('${uri.host} timed out');
    } on Exception catch (error) {
      // Not only a ClientException: http lets a TLS failure, such as a
      // HandshakeException on a captive portal, through unwrapped.
      throw InfoStickerLookupException('${uri.host}: $error');
    }
    if (response.statusCode != 200) {
      throw InfoStickerLookupException(
        '${uri.host} answered ${response.statusCode}',
      );
    }
    try {
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) return body;
    } on FormatException {
      // Falls through to the exception below.
    }
    throw InfoStickerLookupException('${uri.host} sent no JSON object');
  }

  static DateTime _hourOf(DateTime utc) =>
      DateTime.utc(utc.year, utc.month, utc.day, utc.hour);

  /// The forecast step [hour] falls in, or the first when [hour] lies before
  /// them all. The steps are an hour long at first and six hours later on.
  static Map<dynamic, dynamic>? _entryAt(List<dynamic> series, DateTime hour) {
    Map<dynamic, dynamic>? found;
    for (final entry in series) {
      if (entry is! Map) continue;
      final start = DateTime.tryParse('${entry['time']}');
      if (start == null) continue;
      if (start.isAfter(hour)) return found ?? entry;
      found = entry;
    }
    final lastStart = DateTime.tryParse('${found?['time']}');
    return lastStart != null &&
            hour.difference(lastStart) < const Duration(hours: 6)
        ? found
        : null;
  }

  /// The symbol of the next hour, or of the next six or twelve when a later
  /// step has no hourly one.
  static String? _symbolOf(Map<dynamic, dynamic> data) {
    for (final period in const [
      'next_1_hours',
      'next_6_hours',
      'next_12_hours',
    ]) {
      final next = data[period];
      final summary = next is Map ? next['summary'] : null;
      final symbol = summary is Map ? summary['symbol_code'] : null;
      if (symbol is String && symbol.isNotEmpty) return symbol;
    }
    return null;
  }

  static DaylightCalculator _daylightAt(InfoStickerCoordinates coordinates) =>
      DaylightCalculator(
        DaylightLocation(coordinates.latitude, coordinates.longitude),
      );

  /// Whether the sun is up at [coordinates] at the UTC [time]. The day it
  /// belongs to there may start or end on the UTC day before or after.
  static bool _isSunUp(InfoStickerCoordinates coordinates, DateTime time) {
    final calculator = _daylightAt(coordinates);
    for (final offset in const [-1, 0, 1]) {
      final day = DateTime.utc(time.year, time.month, time.day + offset);
      final times = calculator.calculateForDay(day);
      final (sunrise, sunset) = (times.sunrise, times.sunset);
      if (sunrise == null || sunset == null) {
        if (offset == 0) return times.type == DayType.allDay;
        continue;
      }
      if (!time.isBefore(sunrise) && time.isBefore(sunset)) return true;
    }
    return false;
  }

  /// [utc] as a wall-clock time of the phone, to the minute.
  static DateTime? _phoneTime(DateTime? utc) {
    if (utc == null) return null;
    final local = utc.toLocal();
    return DateTime(
      local.year,
      local.month,
      local.day,
      local.hour,
      local.minute,
    );
  }

  /// The place one geocoder result describes, or `null` when it has no name.
  /// A street address is shown by its town, so a creator who types their
  /// home address does not put it on a video.
  static InfoStickerPlace? _placeOf(Placemark placemark) {
    final town =
        _nonEmpty(placemark.locality) ??
        _nonEmpty(placemark.subAdministrativeArea);
    final region = _nonEmpty(placemark.administrativeArea);
    final country = _nonEmpty(placemark.country);
    final street = _nonEmpty(placemark.thoroughfare);
    final number = _nonEmpty(placemark.subThoroughfare);
    var name = _nonEmpty(placemark.name);
    if (name == null ||
        (number != null && name.contains(number)) ||
        (street != null && name.contains(street))) {
      name = town ?? region ?? country;
    }
    if (name == null) return null;
    final around = <String>{
      ?town,
      ?region,
      ?country,
    }.where((part) => part != name).toList();
    return InfoStickerPlace(
      name: name,
      detail: around.isEmpty ? null : around.join(', '),
      address: [name, ...around].join(', '),
      countryCode: _nonEmpty(placemark.isoCountryCode)?.toUpperCase(),
    );
  }

  static String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
