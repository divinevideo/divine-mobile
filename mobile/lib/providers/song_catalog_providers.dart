// ABOUTME: Wires the experimental song catalog: the repository the sound
// ABOUTME: picker's Songs list reads, present only while its flag is on.

import 'dart:ui' show PlatformDispatcher;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/config/song_catalog_config.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:sounds_repository/sounds_repository.dart';

/// The developer token this build was made with, empty when it has none.
///
/// A provider so a test can stand in a token: the real one only exists in a
/// build made with its dart-define.
final songCatalogDeveloperTokenProvider = Provider<String>(
  (ref) => SongCatalogConfig.developerToken,
);

/// The song catalog, or `null` while [FeatureFlag.songCatalog] is off or the
/// build has no developer token. The sound picker lists songs only when this
/// is present.
///
/// Reads the catalog of the device's region, which is where the people
/// trying the songs are.
final songCatalogRepositoryProvider = Provider<SongCatalogRepository?>((ref) {
  if (!ref.watch(isFeatureEnabledProvider(FeatureFlag.songCatalog))) {
    return null;
  }
  final developerToken = ref.watch(songCatalogDeveloperTokenProvider);
  if (developerToken.isEmpty) return null;
  final client = AppleMusicApiClient(developerToken: developerToken);
  ref.onDispose(client.close);
  return SongCatalogRepository(
    client: client,
    countryCode: PlatformDispatcher.instance.locale.countryCode,
  );
});
