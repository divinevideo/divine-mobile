// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'personal_events_dao.dart';

// ignore_for_file: type=lint
mixin _$PersonalEventsDaoMixin on DatabaseAccessor<AppDatabase> {
  $PersonalEventsTable get personalEvents => attachedDatabase.personalEvents;
  PersonalEventsDaoManager get managers => PersonalEventsDaoManager(this);
}

class PersonalEventsDaoManager {
  final _$PersonalEventsDaoMixin _db;
  PersonalEventsDaoManager(this._db);
  $$PersonalEventsTableTableManager get personalEvents =>
      $$PersonalEventsTableTableManager(
        _db.attachedDatabase,
        _db.personalEvents,
      );
}
