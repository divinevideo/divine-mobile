// ABOUTME: Loads the time zone database for info sticker sun times: compiled
// ABOUTME: in on native builds and in tests, fetched when needed on the web.

export 'package:openvine/repositories/info_sticker_time_zones_io.dart'
    if (dart.library.js_interop) 'package:openvine/repositories/info_sticker_time_zones_web.dart';
