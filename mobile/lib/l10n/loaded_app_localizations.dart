// ABOUTME: Picks how app localizations load: synchronously on native builds and
// ABOUTME: in tests, from deferred per-locale libraries on the web.

export 'package:openvine/l10n/loaded_app_localizations_io.dart'
    if (dart.library.js_interop) 'package:openvine/l10n/loaded_app_localizations_web.dart';
