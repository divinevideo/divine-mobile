// ABOUTME: Clears personal-event storage without constructing auth-dependent services.
// ABOUTME: Scopes the delete to the departing owner, or wipes it when signed out.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/database_provider.dart';

/// Clears the departing account's personal events during account cleanup.
///
/// Reading the auth-dependent cache service from the cleanup callback would
/// recreate a provider cycle (#7389). Its own `clearCache()` also returns early
/// before initialization, leaving stored events intact. Go straight to the DAO
/// so the departing account's events cannot survive cleanup (#8314).
///
/// Personal events moved from a Hive box to the `personal_events` table
/// (#6986), and the table carries an owner column. That changes the correct
/// scope: the box held one account's events and was cleared whole, whereas
/// deleting every row here would destroy a *surviving* account's cache during
/// an ordinary account switch. Pass the departing pubkey and only its rows go.
///
/// A null pubkey means there is no identity to scope by — a signed-out wipe —
/// so the table is emptied, which is what clearing the box did.
final personalEventCacheClearProvider =
    Provider<Future<void> Function(String? pubkey)>((ref) {
      return (pubkey) async {
        final dao = ref.read(databaseProvider).personalEventsDao;
        await (pubkey == null
            ? dao.deleteAll()
            : dao.deleteAllForOwner(pubkey));
      };
    });
