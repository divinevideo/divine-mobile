// ABOUTME: Opens the viewer's map app on a search for a place's full name,
// ABOUTME: for a location sticker tapped on a playing video.

import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Launches [uri] outside the app; [launchUrl] unless a test replaces it.
typedef MapUrlLauncher = Future<bool> Function(Uri uri, {LaunchMode mode});

/// The web page [openMapSearch] falls back to: OpenStreetMap's search, which
/// needs no account and no app.
Uri mapSearchWebUri(String query) => Uri.https(
  'www.openstreetmap.org',
  '/search',
  {'query': query},
);

/// Opens the map app of the phone on a search for [query], such as
/// "Zermatt, Wallis, Schweiz": Apple Maps on iOS and macOS, the app Android
/// picks for a `geo:` address, and OpenStreetMap in the browser elsewhere or
/// when Android has no map app.
///
/// Returns whether anything opened. A location sticker keeps no coordinates,
/// so the map searches the name.
Future<bool> openMapSearch(
  String query, {
  TargetPlatform? platform,
  bool isWeb = kIsWeb,
  MapUrlLauncher launch = launchUrl,
}) async {
  final target = platform ?? defaultTargetPlatform;
  final appUri = isWeb
      ? null
      : switch (target) {
          TargetPlatform.iOS || TargetPlatform.macOS => Uri.https(
            'maps.apple.com',
            '/',
            {'q': query},
          ),
          TargetPlatform.android => Uri(
            scheme: 'geo',
            path: '0,0',
            queryParameters: {'q': query},
          ),
          _ => null,
        };
  if (appUri != null &&
      await _tryLaunch(launch, appUri, LaunchMode.externalApplication)) {
    return true;
  }
  return _tryLaunch(
    launch,
    mapSearchWebUri(query),
    LaunchMode.externalApplication,
  );
}

/// Whether [launch] opened [uri]; a phone with nothing to open it with
/// answers `false` on one platform and throws on another.
Future<bool> _tryLaunch(
  MapUrlLauncher launch,
  Uri uri,
  LaunchMode mode,
) async {
  try {
    return await launch(uri, mode: mode);
  } on Exception {
    return false;
  }
}
