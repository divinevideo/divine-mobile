// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'my_followers_dao.dart';

// ignore_for_file: type=lint
mixin _$MyFollowersDaoMixin on DatabaseAccessor<AppDatabase> {
  $MyFollowersTable get myFollowers => attachedDatabase.myFollowers;
  MyFollowersDaoManager get managers => MyFollowersDaoManager(this);
}

class MyFollowersDaoManager {
  final _$MyFollowersDaoMixin _db;
  MyFollowersDaoManager(this._db);
  $$MyFollowersTableTableManager get myFollowers =>
      $$MyFollowersTableTableManager(_db.attachedDatabase, _db.myFollowers);
}
