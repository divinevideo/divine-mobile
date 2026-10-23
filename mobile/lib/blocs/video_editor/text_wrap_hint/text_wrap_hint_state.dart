part of 'text_wrap_hint_cubit.dart';

/// The text layer the wrap hint is about.
class TextWrapHintState extends Equatable {
  /// Creates a state; the default shows no hint.
  const TextWrapHintState({
    this.layerId,
    this.isPinned = false,
    this.revision = 0,
  });

  /// The id of the text layer the hint is about, or `null` for no hint.
  final String? layerId;

  /// Whether the layer is selected in the timeline, which keeps the hint up
  /// rather than letting it go after a pinch.
  final bool isPinned;

  /// Bumped whenever the editor's layers change, so the hint reads the live
  /// layer again even though its id did not change.
  final int revision;

  /// Creates a copy with the given fields replaced.
  TextWrapHintState copyWith({int? revision}) => TextWrapHintState(
    layerId: layerId,
    isPinned: isPinned,
    revision: revision ?? this.revision,
  );

  @override
  List<Object?> get props => [layerId, isPinned, revision];
}
