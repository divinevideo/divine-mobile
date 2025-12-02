// ABOUTME: Data Access Object for user profile operations with reactive Drift queries
// ABOUTME: Provides CRUD operations and Stream-based reactivity for UserProfile caching

import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:openvine/database/app_database.dart';
import 'package:openvine/database/tables.dart';
import 'package:openvine/models/user_profile.dart';

part 'user_profiles_dao.g.dart';

@DriftAccessor(tables: [UserProfiles])
class UserProfilesDao extends DatabaseAccessor<AppDatabase>
    with _$UserProfilesDaoMixin {
  UserProfilesDao(AppDatabase db) : super(db);

  /// Get single profile (one-time fetch)
  ///
  /// Returns null if profile doesn't exist in cache.
  Future<UserProfile?> getProfile(String pubkey) async {
    final row = await (select(
      userProfiles,
    )..where((p) => p.pubkey.equals(pubkey))).getSingleOrNull();

    return row != null ? UserProfile.fromDrift(row) : null;
  }

  /// Watch profile (reactive stream)
  ///
  /// Stream emits whenever the profile is inserted, updated, or deleted.
  /// Emits null if profile doesn't exist.
  Stream<UserProfile?> watchProfile(String pubkey) {
    return (select(userProfiles)..where((p) => p.pubkey.equals(pubkey)))
        .watchSingleOrNull()
        .map((row) => row != null ? UserProfile.fromDrift(row) : null);
  }

  /// Upsert profile (insert or update)
  ///
  /// If profile with same pubkey exists, updates it. Otherwise inserts new profile.
  /// Automatically triggers all watchers of this profile.
  Future<void> upsertProfile(UserProfile profile) {
    return into(userProfiles).insertOnConflictUpdate(
      UserProfilesCompanion.insert(
        pubkey: profile.pubkey,
        displayName: Value(profile.displayName),
        name: Value(profile.name),
        about: Value(profile.about),
        picture: Value(profile.picture),
        banner: Value(profile.banner),
        website: Value(profile.website),
        nip05: Value(profile.nip05),
        lud16: Value(profile.lud16),
        lud06: Value(profile.lud06),
        rawData: Value(
          profile.rawData.isNotEmpty ? jsonEncode(profile.rawData) : null,
        ),
        createdAt: profile.createdAt,
        eventId: profile.eventId,
        lastFetched: DateTime.now(),
      ),
    );
  }

  /// Delete profile
  ///
  /// Removes profile from cache. Automatically triggers watchers.
  Future<void> deleteProfile(String pubkey) {
    return (delete(userProfiles)..where((p) => p.pubkey.equals(pubkey))).go();
  }

  /// Get all profiles (one-time fetch)
  ///
  /// Returns all cached profiles. Use sparingly - prefer filtered queries.
  Future<List<UserProfile>> getAllProfiles() async {
    final rows = await select(userProfiles).get();
    return rows.map((row) => UserProfile.fromDrift(row)).toList();
  }

  /// Watch all profiles (reactive stream)
  ///
  /// Stream emits whenever any profile changes. Use sparingly - prefer filtered queries.
  Stream<List<UserProfile>> watchAllProfiles() {
    return select(userProfiles).watch().map(
      (rows) => rows.map((row) => UserProfile.fromDrift(row)).toList(),
    );
  }
}
