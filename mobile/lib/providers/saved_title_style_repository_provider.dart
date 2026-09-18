// ABOUTME: Riverpod provider wiring SavedTitleStyleRepository to the Drift
// ABOUTME: DAO and the current account, so saved styles stay owner-scoped.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/repositories/saved_title_style_repository.dart';
import 'package:openvine/utils/local_content_owner.dart';

/// Provides the [SavedTitleStyleRepository] for the signed-in account.
///
/// Rebuilds when the account changes so the owner stays current, mirroring
/// `savedCaptionStyleRepositoryProvider` — the two stores share the same
/// ownership rules and the same legacy-row claim on sign-in.
final savedTitleStyleRepositoryProvider = Provider<SavedTitleStyleRepository>((
  ref,
) {
  final db = ref.watch(databaseProvider);
  ref.watch(currentAuthStateProvider);
  final authService = ref.watch(authServiceProvider);
  final ownerPubkey = resolveLocalContentOwnerPubkey(
    currentPubkeyHex: authService.currentPublicKeyHex,
    preferences: ref.watch(sharedPreferencesProvider),
  );
  return SavedTitleStyleRepository(
    dao: db.savedTitleStylesDao,
    ownerPubkey: ownerPubkey,
  );
});
