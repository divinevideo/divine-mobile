// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sound_request_state_dao.dart';

// ignore_for_file: type=lint
mixin _$SoundRequestStateDaoMixin on DatabaseAccessor<AppDatabase> {
  $SoundRequestStatesTable get soundRequestStates =>
      attachedDatabase.soundRequestStates;
  SoundRequestStateDaoManager get managers => SoundRequestStateDaoManager(this);
}

class SoundRequestStateDaoManager {
  final _$SoundRequestStateDaoMixin _db;
  SoundRequestStateDaoManager(this._db);
  $$SoundRequestStatesTableTableManager get soundRequestStates =>
      $$SoundRequestStatesTableTableManager(
        _db.attachedDatabase,
        _db.soundRequestStates,
      );
}
