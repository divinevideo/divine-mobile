// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pending_reports_dao.dart';

// ignore_for_file: type=lint
mixin _$PendingReportsDaoMixin on DatabaseAccessor<AppDatabase> {
  $PendingReportsTable get pendingReports => attachedDatabase.pendingReports;
  PendingReportsDaoManager get managers => PendingReportsDaoManager(this);
}

class PendingReportsDaoManager {
  final _$PendingReportsDaoMixin _db;
  PendingReportsDaoManager(this._db);
  $$PendingReportsTableTableManager get pendingReports =>
      $$PendingReportsTableTableManager(
        _db.attachedDatabase,
        _db.pendingReports,
      );
}
