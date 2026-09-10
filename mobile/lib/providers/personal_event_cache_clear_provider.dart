// ABOUTME: Clears personal-event storage without constructing auth-dependent services.
// ABOUTME: Empties the personal_events table for every owner on this device.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/database_provider.dart';

/// Clears the device-wide personal-event cache during account cleanup.
///
/// Reading the auth-dependent cache service from the cleanup callback would
/// recreate a provider cycle (#7389). Its own `clearCache()` also returns early
/// before initialization, leaving stored events intact. Go straight to the DAO
/// so the departing account's events cannot survive cleanup (#8314).
///
/// Personal events live in the `personal_events` table rather than Hive boxes
/// (#6986). Every owner's rows are removed, which is the same device-wide scope
/// the box clear had — the caller is account cleanup, not an owner-scoped
/// delete.
final personalEventCacheClearProvider = Provider<Future<void> Function()>((
  ref,
) {
  return () async {
    await ref.read(databaseProvider).personalEventsDao.deleteAll();
  };
});
