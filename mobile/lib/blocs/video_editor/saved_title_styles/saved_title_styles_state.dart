// ABOUTME: State for the saved title styles list: the styles and whether
// ABOUTME: they are loading, loaded, or could not be read or written.

part of 'saved_title_styles_cubit.dart';

/// Lifecycle of the saved-style list.
enum SavedTitleStylesStatus {
  /// Nothing requested yet.
  initial,

  /// The saved styles are being read.
  loading,

  /// The saved styles are current.
  ready,

  /// The last read or write failed; [SavedTitleStylesState.styles] holds
  /// whatever was loaded before.
  failure,
}

/// State of the saved title styles list.
class SavedTitleStylesState extends Equatable {
  /// Creates the state.
  const SavedTitleStylesState({
    this.status = SavedTitleStylesStatus.initial,
    this.styles = const [],
  });

  /// Current lifecycle status.
  final SavedTitleStylesStatus status;

  /// The user's saved styles, in picker order.
  final List<SavedTitleStyle> styles;

  /// Copy with the given fields replaced.
  SavedTitleStylesState copyWith({
    SavedTitleStylesStatus? status,
    List<SavedTitleStyle>? styles,
  }) => SavedTitleStylesState(
    status: status ?? this.status,
    styles: styles ?? this.styles,
  );

  @override
  List<Object?> get props => [status, styles];
}
