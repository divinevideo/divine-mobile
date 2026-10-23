// ABOUTME: Which text layer the editor offers to stop or start wrapping at the
// ABOUTME: video edges for: briefly after it is pinched, or while it is selected.

import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/close_guard.dart';

part 'text_wrap_hint_state.dart';

/// Decides which text layer the toolbar's wrap hint is about.
///
/// The hint itself reads the live layer: it shows only while the video edges
/// wrap that layer, or while the layer runs past them, and offers to switch
/// between the two. Pinching a text shows it for [transientDuration], long
/// enough to reach for it once the fingers are off the canvas; selecting a
/// text in the timeline keeps it up until the selection changes, which is
/// also how a screen reader, which cannot pinch, reaches it.
class TextWrapHintCubit extends Cubit<TextWrapHintState>
    with CloseGuardedEmit<TextWrapHintState> {
  /// Creates a cubit with no hint.
  TextWrapHintCubit({this.transientDuration = defaultTransientDuration})
    : super(const TextWrapHintState());

  /// How long the hint stays after a pinch.
  static const defaultTransientDuration = Duration(seconds: 4);

  /// How long the hint stays after a pinch or a tap on it.
  final Duration transientDuration;

  Timer? _hideTimer;

  /// A layer was moved, scaled or turned on the canvas.
  ///
  /// [layerId] is the text layer the hint is about, or `null` when the
  /// gesture moved anything else. A text selected in the timeline keeps the
  /// hint whatever else is moved.
  void layerTransformed(String? layerId) {
    if (state.isPinned) return;
    _hideTimer?.cancel();
    if (layerId == null) {
      emit(TextWrapHintState(revision: state.revision));
      return;
    }
    emit(TextWrapHintState(layerId: layerId, revision: state.revision));
    _hideTimer = Timer(transientDuration, _hideTransient);
  }

  /// The timeline selected [layerId], or nothing when it is `null`.
  void layerSelected(String? layerId) {
    _hideTimer?.cancel();
    emit(
      TextWrapHintState(
        layerId: layerId,
        isPinned: layerId != null,
        revision: state.revision,
      ),
    );
  }

  /// The user switched the wrapping from the hint; a hint shown after a
  /// pinch stays for another [transientDuration] so the switch can be undone.
  void wrapToggled() {
    if (state.layerId == null || state.isPinned) return;
    _hideTimer?.cancel();
    _hideTimer = Timer(transientDuration, _hideTransient);
  }

  /// The editor's layers changed, so the hint reads its layer again.
  void layersChanged() {
    if (state.layerId == null) return;
    emit(state.copyWith(revision: state.revision + 1));
  }

  void _hideTransient() {
    if (state.isPinned) return;
    emitIfOpen(TextWrapHintState(revision: state.revision));
  }

  @override
  Future<void> close() {
    _hideTimer?.cancel();
    return super.close();
  }
}
