// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'saved_caption_styles_dao.dart';

// ignore_for_file: type=lint
mixin _$SavedCaptionStylesDaoMixin on DatabaseAccessor<AppDatabase> {
  $SavedCaptionStylesTable get savedCaptionStyles =>
      attachedDatabase.savedCaptionStyles;
  SavedCaptionStylesDaoManager get managers =>
      SavedCaptionStylesDaoManager(this);
}

class SavedCaptionStylesDaoManager {
  final _$SavedCaptionStylesDaoMixin _db;
  SavedCaptionStylesDaoManager(this._db);
  $$SavedCaptionStylesTableTableManager get savedCaptionStyles =>
      $$SavedCaptionStylesTableTableManager(
        _db.attachedDatabase,
        _db.savedCaptionStyles,
      );
}
