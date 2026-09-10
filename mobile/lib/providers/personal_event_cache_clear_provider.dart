// ABOUTME: Clears personal-event storage without constructing auth-dependent services.
// ABOUTME: Covers both open Hive boxes and caches left on disk between sessions.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:openvine/constants/hive_box_names.dart';

/// Clears the device-wide personal-event cache during account cleanup.
///
/// Reading the auth-dependent cache service from the cleanup callback would
/// recreate a provider cycle (#7389). Its own `clearCache()` also returns early
/// before initialization, leaving on-disk events intact. Clear the boxes
/// directly so the departing account's events cannot survive cleanup (#8314).
final personalEventCacheClearProvider = Provider<Future<void> Function()>((
  ref,
) {
  return () async {
    // Keep literal box names visible to the Hive wipe-policy guard.
    final events = Hive.isBoxOpen(HiveBoxNames.personalEvents)
        ? Hive.box<dynamic>(HiveBoxNames.personalEvents)
        : await Hive.openBox<dynamic>(HiveBoxNames.personalEvents);
    await events.clear();

    final metadata = Hive.isBoxOpen(HiveBoxNames.personalEventsMetadata)
        ? Hive.box<dynamic>(HiveBoxNames.personalEventsMetadata)
        : await Hive.openBox<dynamic>(HiveBoxNames.personalEventsMetadata);
    await metadata.clear();
  };
});
