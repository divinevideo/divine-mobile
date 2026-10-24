// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_sync_dao.dart';

// ignore_for_file: type=lint
mixin _$AccountSyncDaoMixin on DatabaseAccessor<AppDatabase> {
  $AccountSyncRecordsTable get accountSyncRecords =>
      attachedDatabase.accountSyncRecords;
  $NotificationReadsTable get notificationReads =>
      attachedDatabase.notificationReads;
  $NotificationReadMembersTable get notificationReadMembers =>
      attachedDatabase.notificationReadMembers;
  AccountSyncDaoManager get managers => AccountSyncDaoManager(this);
}

class AccountSyncDaoManager {
  final _$AccountSyncDaoMixin _db;
  AccountSyncDaoManager(this._db);
  $$AccountSyncRecordsTableTableManager get accountSyncRecords =>
      $$AccountSyncRecordsTableTableManager(
        _db.attachedDatabase,
        _db.accountSyncRecords,
      );
  $$NotificationReadsTableTableManager get notificationReads =>
      $$NotificationReadsTableTableManager(
        _db.attachedDatabase,
        _db.notificationReads,
      );
  $$NotificationReadMembersTableTableManager get notificationReadMembers =>
      $$NotificationReadMembersTableTableManager(
        _db.attachedDatabase,
        _db.notificationReadMembers,
      );
}
