// ABOUTME: Generic database client wrapper around Drift's GeneratedDatabase.
// ABOUTME: Provides simplified CRUD operations with filtering and watching.

import 'package:drift/drift.dart';
import 'package:meta/meta.dart';

/// A generic database table type.
typedef DatabaseTable = TableInfo<Table, DataClass>;

/// A filter function for queries.
typedef Filter = Expression<bool> Function(Table);

/// An ordering clause for queries.
typedef OrderClause = List<OrderingTerm Function(Table)>;

/// {@template db_client}
/// A database client that wraps Drift's GeneratedDatabase
/// and provides simplified CRUD operations with filtering and watching.
/// {@endtemplate}
class DbClient {
  /// {@macro db_client}
  DbClient({@visibleForTesting GeneratedDatabase? generatedDatabase}) {
    if (generatedDatabase != null) {
      this.generatedDatabase = generatedDatabase;
    }
  }

  @visibleForTesting
  late final GeneratedDatabase generatedDatabase;

  /// Inserts or replaces an entry in the table.
  Future<DataClass> insert(
    DatabaseTable table, {
    required Insertable<DataClass> entry,
  }) async {
    try {
      final statement = generatedDatabase.into(table);

      return await statement.insertReturning(
        entry,
        mode: InsertMode.insertOrReplace,
      );
    } on Exception {
      rethrow;
    }
  }

  /// Inserts multiple entries in a batch.
  Future<void> insertAll(
    DatabaseTable table, {
    required List<Insertable<DataClass>> entries,
  }) async {
    try {
      if (entries.isEmpty) return;

      await generatedDatabase.batch((batch) {
        batch.insertAll(
          table,
          entries,
          mode: InsertMode.insertOrReplace,
        );
      });
    } on Exception {
      rethrow;
    }
  }

  /// Gets a single row matching the filter.
  Future<DataClass?> getBy(
    DatabaseTable table, {
    required Filter filter,
  }) async {
    try {
      final query = generatedDatabase.select(table)..where(filter);

      return await query.getSingleOrNull();
    } on Exception {
      rethrow;
    }
  }

  /// Gets all rows from the table, optionally filtered and ordered.
  Future<List<DataClass>> getAll(
    DatabaseTable table, {
    Filter? filter,
    OrderClause? orderBy,
    int? limit,
    int? offset,
  }) async {
    try {
      var query = generatedDatabase.select(table);

      if (filter != null) {
        query = query..where(filter);
      }

      if (orderBy != null) {
        query = query..orderBy(orderBy);
      }

      if (limit != null || offset != null) {
        query = query..limit(limit ?? -1, offset: offset);
      }

      return await query.get();
    } on Exception {
      rethrow;
    }
  }

  /// Watches a single row matching the filter.
  Stream<DataClass?> watchSingleBy(
    DatabaseTable table, {
    required Filter filter,
  }) {
    try {
      final query = generatedDatabase.select(table)..where(filter);

      return query.watchSingleOrNull();
    } on Exception {
      rethrow;
    }
  }

  /// Watches rows matching the filter.
  Stream<List<DataClass>> watchBy(
    DatabaseTable table, {
    required Filter filter,
    OrderClause? orderBy,
    int? limit,
    int? offset,
  }) {
    try {
      var query = generatedDatabase.select(table)..where(filter);

      if (orderBy != null) {
        query = query..orderBy(orderBy);
      }

      if (limit != null || offset != null) {
        query = query..limit(limit ?? -1, offset: offset);
      }

      return query.watch();
    } on Exception {
      rethrow;
    }
  }

  /// Watches all rows from the table.
  Stream<List<DataClass>> watchAll(
    DatabaseTable table, {
    OrderClause? orderBy,
    int? limit,
    int? offset,
  }) {
    try {
      var query = generatedDatabase.select(table);

      if (orderBy != null) {
        query = query..orderBy(orderBy);
      }

      if (limit != null || offset != null) {
        query = query..limit(limit ?? -1, offset: offset);
      }

      return query.watch();
    } on Exception {
      rethrow;
    }
  }

  /// Deletes rows matching the filter.
  Future<int> delete(
    DatabaseTable table, {
    required Filter filter,
  }) async {
    try {
      final statement = generatedDatabase.delete(table)..where(filter);

      return await statement.go();
    } on Exception {
      rethrow;
    }
  }

  /// Deletes all rows from the table.
  Future<int> deleteAll(DatabaseTable table) async {
    try {
      final statement = generatedDatabase.delete(table);

      return await statement.go();
    } on Exception {
      rethrow;
    }
  }

  /// Updates rows matching the filter.
  Future<int> update(
    DatabaseTable table, {
    required Filter filter,
    required Insertable<DataClass> entry,
  }) async {
    try {
      final statement = generatedDatabase.update(table)..where(filter);

      return await statement.write(entry);
    } on Exception {
      rethrow;
    }
  }

  /// Counts rows matching the optional filter.
  Future<int> count(
    DatabaseTable table, {
    Filter? filter,
  }) async {
    try {
      final countExp = generatedDatabase.selectOnly(table)
        ..addColumns([countAll()]);

      if (filter != null) {
        countExp.where(filter(table.asDslTable));
      }

      final result = await countExp.getSingle();

      return result.read(countAll()) ?? 0;
    } on Exception {
      rethrow;
    }
  }
}
