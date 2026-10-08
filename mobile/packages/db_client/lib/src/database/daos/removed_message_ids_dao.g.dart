// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'removed_message_ids_dao.dart';

// ignore_for_file: type=lint
mixin _$RemovedMessageIdsDaoMixin on DatabaseAccessor<AppDatabase> {
  $RemovedMessageIdsTable get removedMessageIds =>
      attachedDatabase.removedMessageIds;
  RemovedMessageIdsDaoManager get managers => RemovedMessageIdsDaoManager(this);
}

class RemovedMessageIdsDaoManager {
  final _$RemovedMessageIdsDaoMixin _db;
  RemovedMessageIdsDaoManager(this._db);
  $$RemovedMessageIdsTableTableManager get removedMessageIds =>
      $$RemovedMessageIdsTableTableManager(
        _db.attachedDatabase,
        _db.removedMessageIds,
      );
}
