// ABOUTME: State for the saved caption styles list: the styles and whether
// ABOUTME: they are loading, loaded, or could not be read or written.

part of 'saved_caption_styles_cubit.dart';

/// Lifecycle of the saved-style list.
enum SavedCaptionStylesStatus {
  /// Nothing requested yet.
  initial,

  /// The saved styles are being read.
  loading,

  /// The saved styles are current.
  ready,

  /// The last read or write failed; [SavedCaptionStylesState.styles] holds
  /// whatever was loaded before.
  failure,
}

/// State of the saved caption styles list.
class SavedCaptionStylesState extends Equatable {
  /// Creates the state.
  const SavedCaptionStylesState({
    this.status = SavedCaptionStylesStatus.initial,
    this.styles = const [],
  });

  /// Current lifecycle status.
  final SavedCaptionStylesStatus status;

  /// The user's saved styles, in picker order.
  final List<SavedCaptionStyle> styles;

  /// Copy with the given fields replaced.
  SavedCaptionStylesState copyWith({
    SavedCaptionStylesStatus? status,
    List<SavedCaptionStyle>? styles,
  }) => SavedCaptionStylesState(
    status: status ?? this.status,
    styles: styles ?? this.styles,
  );

  @override
  List<Object?> get props => [status, styles];
}
