// coverage:ignore-file
// ignore_for_file: public_member_api_docs // internal Drift table definition, not re-exported by the package
import 'package:drift/drift.dart';

/// Drift table for persisting cache entries.
///
/// [cacheKey] is the primary key — typically `'${pubkeyHex}:feature:variant'`.
/// [payload] holds the serialised JSON returned by the caller's `toJson` fn.
/// [cachedAt] is the UTC instant the row was written.
/// [expiresAt] is the optional UTC expiry instant; NULL means no expiry.
/// The generated row class is named `CacheRow` so it does not collide with the
/// public `CacheEntry` value type.
@DataClassName('CacheRow')
class CacheEntries extends Table {
  TextColumn get cacheKey => text()();
  TextColumn get payload => text()();
  DateTimeColumn get cachedAt => dateTime()();
  DateTimeColumn get expiresAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {cacheKey};
}
