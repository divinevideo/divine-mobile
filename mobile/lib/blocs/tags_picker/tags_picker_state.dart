// ABOUTME: State for [TagsPickerBloc].

part of 'tags_picker_bloc.dart';

/// Status of the tags picker search lifecycle.
enum TagsPickerStatus {
  /// No query is active; suggestions are empty.
  initial,

  /// A debounced search is in flight.
  searching,

  /// Search completed; [TagsPickerState.searchResults] is populated (possibly
  /// empty if the repository found no matches or fell back silently).
  success,
}

/// Why a recent commit did not add a tag. A limit notice stays until a tag
/// is removed.
enum TagsPickerNotice {
  /// Nothing to explain.
  none,

  /// A token was longer than [HashtagExtractor.maxHashtagLength] and was
  /// rejected.
  tagTooLong,

  /// A valid tag the video did not already have was dropped because the
  /// video carries [HashtagExtractor.maxHashtagsPerVideo] tags.
  tagLimitReached,
}

/// State for the tags picker sheet.
final class TagsPickerState extends Equatable {
  const TagsPickerState({
    this.selectedTags = const <String>{},
    this.stickerTags = const <String>{},
    this.query = '',
    this.searchResults = const <String>[],
    this.status = TagsPickerStatus.initial,
    this.notice = TagsPickerNotice.none,
  });

  /// Tags the user has committed in this session.
  final Set<String> selectedTags;

  /// The hashtags of the hashtag stickers on the video. They count toward
  /// the limit and cannot be removed here, only with their sticker.
  final Set<String> stickerTags;

  /// Every tag the video will carry: [stickerTags] and [selectedTags].
  Set<String> get allTags => {...stickerTags, ...selectedTags};

  /// Current (trimmed) query driving the suggestion list.
  final String query;

  /// Raw search results returned by [HashtagRepository] for [query].
  final List<String> searchResults;

  /// Lifecycle of the suggestion search.
  final TagsPickerStatus status;

  /// Why a recent commit did not add a tag, if one was rejected.
  final TagsPickerNotice notice;

  /// Whether the video already carries [HashtagExtractor.maxHashtagsPerVideo]
  /// tags, so nothing more can be added.
  bool get isAtTagLimit =>
      allTags.length >= HashtagExtractor.maxHashtagsPerVideo;

  /// How many of the video's own tags must go before another tag fits: 0
  /// below the limit, more than 1 when sticker hashtags push the video past
  /// it (#11244), and `null` when removing tags here cannot make room because
  /// the sticker hashtags alone fill the limit.
  int? get tagsToRemoveForRoom {
    final needed = allTags.length - HashtagExtractor.maxHashtagsPerVideo + 1;
    if (needed <= 0) return 0;
    // A tag that is also a sticker's hashtag stays on the video when removed.
    final removable = selectedTags.difference(stickerTags).length;
    return needed <= removable ? needed : null;
  }

  /// Whether committing [raw] would be turned away for the tag limit: it is a
  /// valid tag the video does not carry yet, and the video is at the limit.
  bool turnsAwayAtLimit(String raw) {
    if (!isAtTagLimit) return false;
    final tag = HashtagExtractor.normalizeVideoHashtag(raw);
    return tag != null && !allTags.contains(tag);
  }

  /// Search results in the form they would be added — normalized and
  /// deduplicated — minus anything already selected or not addable.
  List<String> get suggestions {
    if (searchResults.isEmpty) return searchResults;
    return searchResults
        .map(HashtagExtractor.normalizeVideoHashtag)
        .nonNulls
        .toSet()
        .where((s) => !allTags.contains(s))
        .toList();
  }

  /// The normalized query — i.e. what would be added if the user committed
  /// it — or an empty string when it would be rejected.
  String get sanitizedQuery =>
      HashtagExtractor.normalizeVideoHashtag(query) ?? '';

  /// Whether committing the query would add a new tag.
  bool get canAddQuery {
    final s = sanitizedQuery;
    if (s.isEmpty || isAtTagLimit) return false;
    return !allTags.contains(s);
  }

  TagsPickerState copyWith({
    Set<String>? selectedTags,
    String? query,
    List<String>? searchResults,
    TagsPickerStatus? status,
    TagsPickerNotice? notice,
  }) {
    return TagsPickerState(
      selectedTags: selectedTags ?? this.selectedTags,
      stickerTags: stickerTags,
      query: query ?? this.query,
      searchResults: searchResults ?? this.searchResults,
      status: status ?? this.status,
      notice: notice ?? this.notice,
    );
  }

  @override
  List<Object?> get props => [
    selectedTags,
    stickerTags,
    query,
    searchResults,
    status,
    notice,
  ];
}
