// ABOUTME: Looks up what info stickers show: places, weather and altitude
// ABOUTME: from Open-Meteo, the battery level and when a clip was recorded.

import 'dart:async';
import 'dart:convert';

import 'package:battery_plus/battery_plus.dart';
import 'package:clock/clock.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:http/http.dart' as http;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/info_sticker.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show ProVideoEditor;
import 'package:timezone/data/latest.dart' deferred as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// A place the place search found.
class InfoStickerPlace extends Equatable {
  const InfoStickerPlace({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.detail,
    this.elevation,
    this.countryCode,
    this.timeZone,
  });

  /// What the place is called: a town, a district or a mountain.
  final String name;

  /// Where it is, such as "Kanton Bern, Schweiz", or `null` when [name] says
  /// it all.
  final String? detail;

  final double latitude;
  final double longitude;

  /// Its altitude above sea level in metres, when the search knew it.
  final double? elevation;

  /// The ISO 3166 code of its country, such as `CH`.
  final String? countryCode;

  /// Its IANA time zone, such as `Europe/Zurich`.
  final String? timeZone;

  @override
  List<Object?> get props => [
    name,
    detail,
    latitude,
    longitude,
    elevation,
    countryCode,
    timeZone,
  ];
}

/// The weather at a place and time.
class InfoStickerWeatherReading extends Equatable {
  const InfoStickerWeatherReading({
    required this.temperatureCelsius,
    required this.isDay,
    this.weather,
  });

  final double temperatureCelsius;
  final bool isDay;

  /// The kind of weather, or `null` for a code the WMO table does not define.
  final InfoStickerWeather? weather;

  @override
  List<Object?> get props => [temperatureCelsius, isDay, weather];
}

/// When the sun rose and set at a place on a day, as wall-clock times of the
/// place. Either is `null` on a day it does not happen, near the poles.
typedef InfoStickerSunTimes = ({DateTime? sunrise, DateTime? sunset});

/// A lookup for an info sticker failed: the service could not be reached,
/// did not answer in time, or answered with something unreadable.
class InfoStickerLookupException implements Exception {
  const InfoStickerLookupException(this.message);

  final String message;

  @override
  String toString() => 'InfoStickerLookupException: $message';
}

/// Settings of [InfoStickerRepository].
abstract final class InfoStickerRepositoryConfig {
  /// How long a lookup may take.
  static const Duration requestTimeout = Duration(seconds: 10);

  /// How many places a search lists at most.
  static const int maxPlaces = 8;

  /// The shortest query the search answers; Open-Meteo returns nothing for a
  /// single character.
  static const int minQueryLength = 2;

  /// The newest data the Open-Meteo forecast API keeps hourly values for,
  /// counted back from now. Older hours come from its archive.
  static const Duration forecastHistory = Duration(days: 60);

  static const String forecastHost = 'api.open-meteo.com';
  static const String archiveHost = 'archive-api.open-meteo.com';
  static const String geocodingHost = 'geocoding-api.open-meteo.com';
}

/// Looks up what info stickers show.
///
/// A place is searched by name, so the app never asks for the device's
/// position, and the search names towns and landmarks rather than addresses.
/// Its coordinates are only used to ask for the weather or the altitude
/// there, and are never kept on a sticker. Open-Meteo receives what the
/// creator types and the coordinates, never who is asking.
class InfoStickerRepository {
  InfoStickerRepository({
    http.Client? client,
    Battery? battery,
    ProVideoEditor? videoEditor,
  }) : _client = client ?? http.Client(),
       _batteryOverride = battery,
       _videoEditor = videoEditor ?? ProVideoEditor.instance;

  final http.Client _client;
  final Battery? _batteryOverride;
  final ProVideoEditor _videoEditor;

  // Created on first use: it reaches a platform plugin when it is built.
  late final Battery _battery = _batteryOverride ?? Battery();

  /// Closes the HTTP client. Lookups still running then fail with an
  /// [InfoStickerLookupException].
  void close() => _client.close();

  /// The places [query] finds, named in [languageCode], at most
  /// [InfoStickerRepositoryConfig.maxPlaces] and none twice. A query shorter
  /// than [InfoStickerRepositoryConfig.minQueryLength] finds nothing.
  ///
  /// Throws an [InfoStickerLookupException] when the search cannot be reached
  /// or answers with something unreadable.
  Future<List<InfoStickerPlace>> searchPlaces(
    String query, {
    required String languageCode,
  }) async {
    final trimmed = query.trim();
    if (trimmed.length < InfoStickerRepositoryConfig.minQueryLength) {
      return const [];
    }
    final body = await _getJson(
      Uri.https(InfoStickerRepositoryConfig.geocodingHost, '/v1/search', {
        'name': trimmed,
        // Asks for more than it lists: the same town comes back once per
        // feature (the town, its airport), and those collapse into one.
        'count': '${InfoStickerRepositoryConfig.maxPlaces * 2}',
        'language': languageCode,
        'format': 'json',
      }),
    );
    final results = body['results'];
    if (results is! List) return const [];
    final places = <String, InfoStickerPlace>{};
    for (final result in results) {
      final place = result is Map<String, dynamic> ? _placeOf(result) : null;
      if (place == null) continue;
      places.putIfAbsent('${place.name}|${place.detail}', () => place);
      if (places.length == InfoStickerRepositoryConfig.maxPlaces) break;
    }
    return places.values.toList();
  }

  /// The weather at [place] at [time].
  ///
  /// Throws an [InfoStickerLookupException] when Open-Meteo cannot be reached
  /// or has no value for that hour.
  Future<InfoStickerWeatherReading> weatherAt(
    InfoStickerPlace place,
    DateTime time,
  ) async {
    final hour = time.toUtc();
    final isRecent =
        clock.now().toUtc().difference(hour) <=
        InfoStickerRepositoryConfig.forecastHistory;
    final hosts = [
      if (isRecent) InfoStickerRepositoryConfig.forecastHost,
      InfoStickerRepositoryConfig.archiveHost,
    ];
    for (final host in hosts) {
      final reading = await _hourlyWeather(host, place, hour);
      if (reading != null) return reading;
    }
    throw const InfoStickerLookupException('No weather for that hour');
  }

  /// When the sun rose and set at [place] on the day of [day].
  ///
  /// Open-Meteo is asked for UTC: its own local times use the place's offset
  /// of today for every day, an hour off across a change to or from summer
  /// time. The times are turned into the place's time zone here instead, or
  /// the phone's when the search named none.
  ///
  /// Throws an [InfoStickerLookupException] when Open-Meteo cannot be reached,
  /// has no times for that day, or the sun neither rose nor set there.
  Future<InfoStickerSunTimes> sunTimesAt(
    InfoStickerPlace place,
    DateTime day,
  ) async {
    final date = [
      day.year.toString().padLeft(4, '0'),
      day.month.toString().padLeft(2, '0'),
      day.day.toString().padLeft(2, '0'),
    ].join('-');
    final isRecent =
        clock.now().difference(day).abs() <=
        InfoStickerRepositoryConfig.forecastHistory;
    for (final host in [
      if (isRecent) InfoStickerRepositoryConfig.forecastHost,
      InfoStickerRepositoryConfig.archiveHost,
    ]) {
      final Map<String, dynamic> body;
      try {
        body = await _getJson(
          Uri.https(
            host,
            host == InfoStickerRepositoryConfig.archiveHost
                ? '/v1/archive'
                : '/v1/forecast',
            {
              'latitude': '${place.latitude}',
              'longitude': '${place.longitude}',
              'daily': 'sunrise,sunset',
              'timezone': 'GMT',
              'start_date': date,
              'end_date': date,
            },
          ),
        );
      } on InfoStickerLookupException {
        // The other host may still have the day.
        continue;
      }
      final daily = body['daily'];
      if (daily is! Map) continue;
      final sunrise = _firstUtcTime(daily['sunrise']);
      final sunset = _firstUtcTime(daily['sunset']);
      if (sunrise == null && sunset == null) continue;
      if (_isPolarDay(sunrise, sunset)) {
        throw const InfoStickerLookupException(
          'The sun neither rose nor set there that day',
        );
      }
      if (place.timeZone != null) await _loadTimeZones();
      return (
        sunrise: _placeTime(sunrise, place.timeZone),
        sunset: _placeTime(sunset, place.timeZone),
      );
    }
    throw const InfoStickerLookupException('No sun times for that day');
  }

  /// Whether Open-Meteo's [sunrise] and [sunset] stand for a day the sun
  /// stays up or down: it answers with midnight for both, the same one in a
  /// polar night and the next day's in a midnight sun.
  static bool _isPolarDay(DateTime? sunrise, DateTime? sunset) {
    if (sunrise == null || sunset == null) return false;
    final span = sunset.difference(sunrise);
    return span == Duration.zero || span == const Duration(days: 1);
  }

  /// The altitude of [place] above sea level, in metres: the one the search
  /// found it with, or else Open-Meteo's for its coordinates.
  ///
  /// Throws an [InfoStickerLookupException] when Open-Meteo cannot be reached.
  Future<double> elevationAt(InfoStickerPlace place) async {
    final known = place.elevation;
    if (known != null) return known;
    final body = await _getJson(
      Uri.https(InfoStickerRepositoryConfig.forecastHost, '/v1/elevation', {
        'latitude': '${place.latitude}',
        'longitude': '${place.longitude}',
      }),
    );
    final elevation = body['elevation'];
    if (elevation is List && elevation.isNotEmpty && elevation.first is num) {
      return (elevation.first as num).toDouble();
    }
    throw const InfoStickerLookupException('No elevation in the answer');
  }

  /// The battery level, from 0 to 100.
  ///
  /// Throws an [InfoStickerLookupException] when the platform cannot tell.
  Future<int> batteryLevel() async {
    try {
      return (await _battery.batteryLevel).clamp(0, 100);
    } on PlatformException catch (error) {
      throw InfoStickerLookupException('No battery level: ${error.code}');
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
    } on TimeoutException {
      // The file date is a refinement; the clip's own time stands in.
    } on PlatformException {
      // As above: a file the platform cannot read keeps the clip's time.
    }
    return clip.recordedAt;
  }

  /// The weather [host] has for [hour], or `null` when it has none.
  Future<InfoStickerWeatherReading?> _hourlyWeather(
    String host,
    InfoStickerPlace place,
    DateTime hour,
  ) async {
    final stamp =
        '${hour.toIso8601String().substring(0, 13)}:00'; // yyyy-MM-ddTHH:00
    final path = host == InfoStickerRepositoryConfig.archiveHost
        ? '/v1/archive'
        : '/v1/forecast';
    final Map<String, dynamic> body;
    try {
      body = await _getJson(
        Uri.https(host, path, {
          'latitude': '${place.latitude}',
          'longitude': '${place.longitude}',
          'hourly': 'temperature_2m,weather_code,is_day',
          'timezone': 'GMT',
          'start_hour': stamp,
          'end_hour': stamp,
        }),
      );
    } on InfoStickerLookupException {
      // The other host may still have the hour; the caller throws when none
      // does.
      return null;
    }
    final hourly = body['hourly'];
    if (hourly is! Map) return null;
    final temperature = _first(hourly['temperature_2m']);
    if (temperature == null) return null;
    final code = _first(hourly['weather_code']);
    return InfoStickerWeatherReading(
      temperatureCelsius: temperature.toDouble(),
      isDay: _first(hourly['is_day']) != 0,
      weather: code == null
          ? null
          : InfoStickerWeather.fromWmoCode(code.toInt()),
    );
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final http.Response response;
    try {
      response = await _client
          .get(uri)
          .timeout(InfoStickerRepositoryConfig.requestTimeout);
    } on TimeoutException {
      throw InfoStickerLookupException('${uri.host} timed out');
    } on http.ClientException catch (error) {
      throw InfoStickerLookupException('${uri.host}: ${error.message}');
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

  /// The first time in [values], read as UTC.
  static DateTime? _firstUtcTime(Object? values) {
    final raw = values is List && values.isNotEmpty ? values.first : null;
    return raw is String ? DateTime.tryParse('${raw}Z') : null;
  }

  /// [utc] as a wall-clock time in [timeZone].
  static DateTime? _placeTime(DateTime? utc, String? timeZone) {
    if (utc == null) return null;
    final local = _inTimeZone(utc, timeZone);
    return DateTime(
      local.year,
      local.month,
      local.day,
      local.hour,
      local.minute,
    );
  }

  /// [utc] in [timeZone], once [_loadTimeZones] has run.
  static DateTime _inTimeZone(DateTime utc, String? timeZone) {
    if (timeZone == null) return utc.toLocal();
    try {
      return tz.TZDateTime.from(utc, tz.getLocation(timeZone));
    } on tz.LocationNotFoundException {
      return utc.toLocal();
    }
  }

  /// Loads the time zone database once. It holds each zone's whole history,
  /// so an older day gets the summer or winter time it had then; on the web
  /// it is a library of its own, fetched when a sun sticker first needs it.
  ///
  /// Throws an [InfoStickerLookupException] when it cannot be fetched.
  static Future<void> _loadTimeZones() async {
    if (_timeZonesLoaded) return;
    try {
      await tz_data.loadLibrary();
    } on Exception catch (error) {
      throw InfoStickerLookupException('No time zone data: $error');
    }
    tz_data.initializeTimeZones();
    _timeZonesLoaded = true;
  }

  static bool _timeZonesLoaded = false;

  static num? _first(Object? values) =>
      values is List && values.isNotEmpty && values.first is num
      ? values.first as num
      : null;

  /// The place one Open-Meteo search result describes, or `null` when it
  /// has no name or coordinates.
  static InfoStickerPlace? _placeOf(Map<String, dynamic> result) {
    final name = _nonEmpty(result['name']);
    final latitude = result['latitude'];
    final longitude = result['longitude'];
    if (name == null || latitude is! num || longitude is! num) return null;
    final region = _nonEmpty(result['admin1']);
    final country = _nonEmpty(result['country']);
    final detail = [
      if (region != null && region != name) region,
      if (country != null && country != name) country,
    ].join(', ');
    final elevation = result['elevation'];
    return InfoStickerPlace(
      name: name,
      detail: detail.isEmpty ? null : detail,
      latitude: latitude.toDouble(),
      longitude: longitude.toDouble(),
      elevation: elevation is num ? elevation.toDouble() : null,
      countryCode: _nonEmpty(result['country_code']),
      timeZone: _nonEmpty(result['timezone']),
    );
  }

  static String? _nonEmpty(Object? value) {
    final trimmed = value is String ? value.trim() : null;
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
