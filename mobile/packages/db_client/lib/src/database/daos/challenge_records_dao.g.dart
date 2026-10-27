// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'challenge_records_dao.dart';

// ignore_for_file: type=lint
mixin _$ChallengeRecordsDaoMixin on DatabaseAccessor<AppDatabase> {
  $ChallengeOwnersTable get challengeOwners => attachedDatabase.challengeOwners;
  $ChallengeRecordsTable get challengeRecords =>
      attachedDatabase.challengeRecords;
  ChallengeRecordsDaoManager get managers => ChallengeRecordsDaoManager(this);
}

class ChallengeRecordsDaoManager {
  final _$ChallengeRecordsDaoMixin _db;
  ChallengeRecordsDaoManager(this._db);
  $$ChallengeOwnersTableTableManager get challengeOwners =>
      $$ChallengeOwnersTableTableManager(
        _db.attachedDatabase,
        _db.challengeOwners,
      );
  $$ChallengeRecordsTableTableManager get challengeRecords =>
      $$ChallengeRecordsTableTableManager(
        _db.attachedDatabase,
        _db.challengeRecords,
      );
}
