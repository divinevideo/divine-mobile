// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'concord_store_dao.dart';

// ignore_for_file: type=lint
mixin _$ConcordStoreDaoMixin on DatabaseAccessor<AppDatabase> {
  $ConcordStoreEntriesTable get concordStoreEntries =>
      attachedDatabase.concordStoreEntries;
  ConcordStoreDaoManager get managers => ConcordStoreDaoManager(this);
}

class ConcordStoreDaoManager {
  final _$ConcordStoreDaoMixin _db;
  ConcordStoreDaoManager(this._db);
  $$ConcordStoreEntriesTableTableManager get concordStoreEntries =>
      $$ConcordStoreEntriesTableTableManager(
        _db.attachedDatabase,
        _db.concordStoreEntries,
      );
}
