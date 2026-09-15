// ABOUTME: Sheet-local cubit for the saved caption styles list: loads the
// ABOUTME: styles and applies save, rename, delete and reorder to them.

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/models/video_editor/caption_style.dart';
import 'package:openvine/models/video_editor/saved_caption_style.dart';
import 'package:openvine/repositories/saved_caption_style_repository.dart';

part 'saved_caption_styles_state.dart';

/// Manages the saved caption styles shown by the saved-styles sheet.
///
/// Created per sheet visit, like `CaptionsEditorCubit`. Every write goes to
/// the repository and then reloads the list, so the picker never shows an
/// order or a name the database does not hold.
class SavedCaptionStylesCubit extends Cubit<SavedCaptionStylesState>
    with CloseGuardedEmit<SavedCaptionStylesState> {
  /// Creates the cubit over [repository].
  SavedCaptionStylesCubit({required SavedCaptionStyleRepository repository})
    : _repository = repository,
      super(const SavedCaptionStylesState());

  final SavedCaptionStyleRepository _repository;

  /// Reads the saved styles.
  Future<void> load() async {
    emit(state.copyWith(status: SavedCaptionStylesStatus.loading));
    await _reload();
  }

  /// Saves [style] under [name]. A blank name is ignored.
  Future<void> save({
    required String name,
    required CaptionCustomStyle style,
  }) => _write(() => _repository.save(rawName: name, style: style));

  /// Renames the style [id] to [name]. A blank name is ignored.
  Future<void> rename({required String id, required String name}) =>
      _write(() => _repository.rename(id: id, rawName: name));

  /// Deletes the style [id].
  Future<void> delete(String id) => _write(() => _repository.delete(id));

  /// Moves the style at [oldIndex] so it ends up at [newIndex] — the
  /// position it lands on once removed, as `ReorderableListView.onReorderItem`
  /// reports it.
  ///
  /// The new order is shown at once and persisted behind it, so a drag does
  /// not snap back while the database catches up.
  Future<void> reorder(int oldIndex, int newIndex) async {
    final styles = List<SavedCaptionStyle>.of(state.styles);
    if (oldIndex < 0 || oldIndex >= styles.length) return;
    final target = newIndex.clamp(0, styles.length - 1);
    if (target == oldIndex) return;

    final moved = styles.removeAt(oldIndex);
    styles.insert(target, moved);
    emit(
      state.copyWith(
        styles: [
          for (var index = 0; index < styles.length; index++)
            styles[index].copyWith(orderIndex: index),
        ],
      ),
    );
    await _write(
      () => _repository.reorder([for (final style in styles) style.id]),
    );
  }

  Future<void> _write(Future<void> Function() write) async {
    try {
      await write();
    } catch (e, stackTrace) {
      addError(e, stackTrace);
      emitIfOpen(state.copyWith(status: SavedCaptionStylesStatus.failure));
      return;
    }
    await _reload();
  }

  Future<void> _reload() async {
    try {
      final styles = await _repository.getStyles();
      emitIfOpen(
        state.copyWith(
          status: SavedCaptionStylesStatus.ready,
          styles: styles,
        ),
      );
    } catch (e, stackTrace) {
      addError(e, stackTrace);
      emitIfOpen(state.copyWith(status: SavedCaptionStylesStatus.failure));
    }
  }
}
