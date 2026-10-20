part of 'loop_suggestion_cubit.dart';

/// Where the search for a smoother loop stands.
enum LoopSuggestionStatus {
  /// Nothing is being searched, or the last result was handled.
  idle,

  /// The end of the last clip is compared with the start of the video.
  searching,

  /// A smoother end was found; [LoopSuggestionState.suggested] holds the
  /// last clip trimmed to it.
  suggested,

  /// The video already loops smoothly, and no cut would do much better.
  alreadySmooth,

  /// No frame near the end looks like the start, so no cut makes the loop
  /// much smoother: the motion never comes back around.
  noMatch,

  /// A clip could not be read, or the search stopped responding.
  failed,
}

/// The state of [LoopSuggestionCubit].
class LoopSuggestionState extends Equatable {
  const LoopSuggestionState({
    this.status = LoopSuggestionStatus.idle,
    this.progress = 0,
    this.original,
    this.originalClips = const [],
    this.suggested,
    this.isCloseMatch = false,
  });

  final LoopSuggestionStatus status;

  /// How much of the frames were read so far, 0..1.
  final double progress;

  /// The last clip as it was when the search started.
  final DivineVideoClip? original;

  /// The composition the search compared, before its asynchronous analysis.
  /// A result cannot be applied to a different start or timeline.
  final List<DivineVideoClip> originalClips;

  /// [original] trimmed to the suggested end, once [status] is
  /// [LoopSuggestionStatus.suggested].
  final DivineVideoClip? suggested;

  /// Whether the suggested end matches the start closely, rather than being
  /// only the closest frame there is.
  final bool isCloseMatch;

  /// The clip the search is about.
  String? get clipId => original?.id;

  /// Whether a search runs now.
  bool get isSearching => status == LoopSuggestionStatus.searching;

  LoopSuggestionState copyWith({double? progress}) => LoopSuggestionState(
    status: status,
    progress: progress ?? this.progress,
    original: original,
    originalClips: originalClips,
    suggested: suggested,
    isCloseMatch: isCloseMatch,
  );

  @override
  List<Object?> get props => [
    status,
    progress,
    original,
    originalClips,
    suggested,
    isCloseMatch,
  ];
}
