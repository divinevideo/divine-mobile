// ABOUTME: Web builds: the time zone database is a library of its own,
// ABOUTME: fetched the first time a sun sticker needs it.

import 'package:timezone/data/latest.dart' deferred as tz_data;

/// Fetches the time zone database and initialises it.
///
/// It holds each zone's whole history, several hundred kilobytes the web app
/// does not download until a sun sticker asks for a place's local time.
Future<void> loadTimeZoneDatabase() async {
  await tz_data.loadLibrary();
  tz_data.initializeTimeZones();
}
