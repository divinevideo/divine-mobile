// ABOUTME: Drift-based UserProfile provider using reactive streams - replaces manual cache management
// ABOUTME: Provides automatic reactivity via Drift's watchProfile() - when database changes, all watchers auto-update

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:openvine/models/user_profile.dart';
import 'package:openvine/providers/database_provider.dart';

part 'user_profile_drift_provider.g.dart';

/// Stream provider for a single user profile from Drift database
///
/// This replaces ~100 lines of manual cache management with simple reactive streams.
/// When profile is inserted/updated in database, all watchers auto-update.
///
/// Usage:
/// ```dart
/// final profileAsync = ref.watch(userProfileProvider('pubkey123'));
/// profileAsync.when(
///   data: (profile) => profile != null ? Text(profile.displayName) : Text('Unknown'),
///   loading: () => CircularProgressIndicator(),
///   error: (e, s) => Text('Error: $e'),
/// );
/// ```
@riverpod
Stream<UserProfile?> userProfile(Ref ref, String pubkey) {
  final db = ref.watch(databaseProvider);
  return db.userProfilesDao.watchProfile(pubkey);
}
