// ABOUTME: Drift table definitions for OpenVine's shared Nostr database
// ABOUTME: Defines NostrEvents (read-only from nostr_sdk) and UserProfiles (denormalized cache)

import 'package:drift/drift.dart';

/// Maps to nostr_sdk's existing 'event' table (read-only for now)
///
/// This table is managed by nostr_sdk's embedded relay and contains all Nostr events.
/// We map to it for querying but don't create/modify it.
@DataClassName('NostrEventRow')
class NostrEvents extends Table {
  @override
  String get tableName => 'event'; // Use existing table from nostr_sdk

  TextColumn get id => text()();
  TextColumn get pubkey => text()();
  IntColumn get createdAt => integer().named('created_at')();
  IntColumn get kind => integer()();
  TextColumn get tags => text()(); // JSON-encoded array
  TextColumn get content => text()();
  TextColumn get sig => text()();
  TextColumn get sources => text().nullable()(); // JSON-encoded array

  @override
  Set<Column> get primaryKey => {id};
}

/// Denormalized cache of user profiles extracted from kind 0 events
///
/// Profiles are parsed from kind 0 events and stored here for fast reactive queries.
/// This avoids having to parse JSON for every profile display.
@DataClassName('UserProfileRow')
class UserProfiles extends Table {
  @override
  String get tableName => 'user_profiles';

  TextColumn get pubkey => text()();
  TextColumn get displayName => text().nullable().named('display_name')();
  TextColumn get name => text().nullable()();
  TextColumn get about => text().nullable()();
  TextColumn get picture => text().nullable()();
  TextColumn get banner => text().nullable()();
  TextColumn get website => text().nullable()();
  TextColumn get nip05 => text().nullable()();
  TextColumn get lud16 => text().nullable()();
  TextColumn get lud06 => text().nullable()();
  TextColumn get rawData => text().nullable().named('raw_data')(); // JSON-encoded map
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  TextColumn get eventId => text().named('event_id')();
  DateTimeColumn get lastFetched => dateTime().named('last_fetched')();

  @override
  Set<Column> get primaryKey => {pubkey};
}
