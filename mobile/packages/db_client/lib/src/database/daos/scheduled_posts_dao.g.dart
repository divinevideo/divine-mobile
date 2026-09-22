// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scheduled_posts_dao.dart';

// ignore_for_file: type=lint
mixin _$ScheduledPostsDaoMixin on DatabaseAccessor<AppDatabase> {
  $ScheduledPostsTable get scheduledPosts => attachedDatabase.scheduledPosts;
  ScheduledPostsDaoManager get managers => ScheduledPostsDaoManager(this);
}

class ScheduledPostsDaoManager {
  final _$ScheduledPostsDaoMixin _db;
  ScheduledPostsDaoManager(this._db);
  $$ScheduledPostsTableTableManager get scheduledPosts =>
      $$ScheduledPostsTableTableManager(
        _db.attachedDatabase,
        _db.scheduledPosts,
      );
}
