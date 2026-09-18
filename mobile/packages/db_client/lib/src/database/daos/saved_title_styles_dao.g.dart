// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'saved_title_styles_dao.dart';

// ignore_for_file: type=lint
mixin _$SavedTitleStylesDaoMixin on DatabaseAccessor<AppDatabase> {
  $SavedTitleStylesTable get savedTitleStyles =>
      attachedDatabase.savedTitleStyles;
  SavedTitleStylesDaoManager get managers => SavedTitleStylesDaoManager(this);
}

class SavedTitleStylesDaoManager {
  final _$SavedTitleStylesDaoMixin _db;
  SavedTitleStylesDaoManager(this._db);
  $$SavedTitleStylesTableTableManager get savedTitleStyles =>
      $$SavedTitleStylesTableTableManager(
        _db.attachedDatabase,
        _db.savedTitleStyles,
      );
}
