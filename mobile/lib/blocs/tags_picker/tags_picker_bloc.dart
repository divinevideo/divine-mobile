// ABOUTME: BLoC for the video metadata tags picker sheet.
// ABOUTME: Sanitizes / dedups committed tags and searches suggestions.

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hashtag_repository/hashtag_repository.dart';
import 'package:openvine/constants/search_constants.dart';

part 'tags_picker_event.dart';
part 'tags_picker_state.dart';

/// Result of parsing a tag-input text change into committable tokens
/// plus a remainder that should stay in the text field.
class TagsPickerInputParseResult {
  /// Creates a parse result.
  const TagsPickerInputParseResult({
    required this.completed,
    required this.remainder,
  });

  /// Tokens that are ready to be added to the selected tags.
  final List<String> completed;

  /// Trailing partial token that should remain in the text field.
  final String remainder;
}

/// Pure parser that decides which tokens are completed and which is a
/// remainder partial token, based on the new and previous text.
///
/// A "paste" is detected when [text] grew by more than one character vs
/// [previousText]; in that case the trailing token is also committed
/// (so pasting `"foo, bar, baz"` adds all three).
///
/// A trailing token longer than [HashtagExtractor.maxHashtagLength] is
/// committed too, so the bloc rejects it instead of leaving it in the field.
///
/// This is the parsing rule for the tags picker text field. The widget
/// is only responsible for forwarding the result to the controller and
/// dispatching the bloc events.
TagsPickerInputParseResult parseTagsPickerInput({
  required String text,
  required String previousText,
}) {
  final separators = HashtagExtractor.separatorPattern;
  if (!text.contains(separators)) {
    if (text.length > HashtagExtractor.maxHashtagLength) {
      return TagsPickerInputParseResult(completed: [text], remainder: '');
    }
    return TagsPickerInputParseResult(completed: const [], remainder: text);
  }
  final parts = text.split(separators);
  // Heuristic: input that grew by >1 character in a single notifier tick
  // is treated as a paste. Safe today because the field filters to
  // [a-zA-Z0-9 ] — if the allow-list is widened, autocorrect / IME
  // (e.g. CJK composition, swipe-to-type, `omw` → `on my way`) may land
  // here and unexpectedly commit a token.
  final isPaste = text.length - previousText.length > 1;
  if (isPaste) {
    return TagsPickerInputParseResult(
      completed: parts.where((p) => p.isNotEmpty).toList(),
      remainder: '',
    );
  }
  final remainder = parts.last;
  final remainderTooLong = remainder.length > HashtagExtractor.maxHashtagLength;
  return TagsPickerInputParseResult(
    completed: [
      ...parts.sublist(0, parts.length - 1).where((p) => p.isNotEmpty),
      if (remainderTooLong) remainder,
    ],
    remainder: remainderTooLong ? '' : remainder,
  );
}

/// BLoC that owns the state of the tags picker sheet.
///
/// Responsibilities:
///   * normalize, deduplicate and cap tokens before adding them to
///     [TagsPickerState.selectedTags], using the [HashtagExtractor] rules
///   * debounce-restart hashtag search requests against [HashtagRepository]
///   * filter the resulting suggestions against already-selected tags
class TagsPickerBloc extends Bloc<TagsPickerEvent, TagsPickerState> {
  TagsPickerBloc({
    required HashtagRepository hashtagRepository,
    required Set<String> initialTags,
  }) : _hashtagRepository = hashtagRepository,
       super(
         TagsPickerState(
           selectedTags: HashtagExtractor.normalizeVideoHashtags(
             initialTags,
           ).toSet(),
         ),
       ) {
    on<TagsPickerTagsAdded>(_onTagsAdded);
    on<TagsPickerSuggestionSelected>(_onSuggestionSelected);
    on<TagsPickerTagRemoved>(_onTagRemoved);
    on<TagsPickerSearchCleared>(_onSearchCleared);
    on<TagsPickerQueryChanged>(
      _onQueryChanged,
      transformer: debounceRestartable(),
    );
  }

  final HashtagRepository _hashtagRepository;

  void _onTagsAdded(TagsPickerTagsAdded event, Emitter<TagsPickerState> emit) {
    final next = _withAddedTags(event.rawTokens);
    if (next != state) emit(next);
  }

  void _onSuggestionSelected(
    TagsPickerSuggestionSelected event,
    Emitter<TagsPickerState> emit,
  ) {
    final next = _withAddedTags([event.tag]);
    if (next != state) emit(next);
  }

  void _onTagRemoved(
    TagsPickerTagRemoved event,
    Emitter<TagsPickerState> emit,
  ) {
    if (!state.selectedTags.contains(event.tag)) return;
    final updated = Set<String>.of(state.selectedTags)..remove(event.tag);
    emit(state.copyWith(selectedTags: updated, notice: TagsPickerNotice.none));
  }

  void _onSearchCleared(
    TagsPickerSearchCleared event,
    Emitter<TagsPickerState> emit,
  ) {
    emit(
      state.copyWith(
        status: TagsPickerStatus.initial,
        query: '',
        searchResults: const [],
      ),
    );
  }

  Future<void> _onQueryChanged(
    TagsPickerQueryChanged event,
    Emitter<TagsPickerState> emit,
  ) async {
    final query = event.query.trim();
    if (query.isEmpty) {
      // Every commit clears the field, which lands here one debounce later,
      // so the notice is kept until the user types a new tag.
      emit(
        state.copyWith(
          status: TagsPickerStatus.initial,
          query: '',
          searchResults: const [],
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: TagsPickerStatus.searching,
        query: query,
        notice: TagsPickerNotice.none,
      ),
    );

    // HashtagRepository.searchHashtags is documented as never-throws and
    // falls back to an empty list on any upstream failure, so we don't need
    // a try/catch or a separate failure status here.
    final results = await _hashtagRepository.searchHashtags(query: query);
    emit(
      state.copyWith(status: TagsPickerStatus.success, searchResults: results),
    );
  }

  /// Adds every valid token that still fits under
  /// [HashtagExtractor.maxHashtagsPerVideo]. A token over
  /// [HashtagExtractor.maxHashtagLength] is dropped and flagged with
  /// [TagsPickerNotice.tagTooLong] rather than truncated.
  TagsPickerState _withAddedTags(List<String> rawTokens) {
    final updated = Set<String>.of(state.selectedTags);
    var notice = TagsPickerNotice.none;
    for (final raw in rawTokens) {
      if (updated.length >= HashtagExtractor.maxHashtagsPerVideo) break;
      final tag = HashtagExtractor.normalizeVideoHashtag(raw);
      if (tag == null) {
        if (raw.length > HashtagExtractor.maxHashtagLength) {
          notice = TagsPickerNotice.tagTooLong;
        }
        continue;
      }
      updated.add(tag);
    }
    return state.copyWith(selectedTags: updated, notice: notice);
  }
}
