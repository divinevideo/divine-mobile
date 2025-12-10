// ABOUTME: Data Access Object for user profile operations with domain
// ABOUTME: model conversion. Provides upsert from UserProfile model.
// ABOUTME: Simple CRUD is in AppDbClient.

import 'dart:convert';

import 'package:db_client/db_client.dart';
import 'package:drift/drift.dart';
import 'package:models/models.dart';

part 'user_profiles_dao.g.dart';

@DriftAccessor(tables: [UserProfiles])
class UserProfilesDao extends DatabaseAccessor<AppDatabase>
    with _$UserProfilesDaoMixin {
  UserProfilesDao(super.attachedDatabase);

  /// Upsert profile from domain model (insert or update)
  ///
  /// Converts UserProfile domain model to database companion and
  /// inserts/updates.
  /// If profile with same pubkey exists, updates it. Otherwise inserts
  /// new profile.
  ///
  /// For simple CRUD operations (get, watch, delete), use AppDbClient instead.
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
}
