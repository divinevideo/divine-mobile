import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/features/publishing_ideas/publishing_ideas_source.dart';
import 'package:publishing_suggestions/publishing_suggestions.dart';

/// Inline ideas state; never owns the creator's actual metadata.
class PublishingIdeasState {
  const PublishingIdeasState({
    this.busy = false,
    this.result,
    this.capabilities,
    this.failed = false,
    this.source,
    this.frames,
    this.expanded = false,
    this.editingTranscript = false,
    this.selected = 0,
    this.transcript = '',
  });
  final bool busy;
  final SuggestedPublishing? result;
  final ModelCapabilities? capabilities;
  final bool failed;
  final PublishingIdeasSource? source;
  final List<Uint8List>? frames;
  final bool expanded;
  final bool editingTranscript;
  final int selected;
  final String transcript;

  PublishingIdeasState copyWith({
    bool? busy,
    SuggestedPublishing? result,
    ModelCapabilities? capabilities,
    bool? failed,
    PublishingIdeasSource? source,
    List<Uint8List>? frames,
    bool? expanded,
    bool? editingTranscript,
    int? selected,
    String? transcript,
    bool resetResult = false,
    bool resetFrames = false,
  }) => PublishingIdeasState(
    busy: busy ?? this.busy,
    result: resetResult ? null : result ?? this.result,
    capabilities: resetResult ? null : capabilities ?? this.capabilities,
    failed: failed ?? this.failed,
    source: source ?? this.source,
    frames: resetFrames ? null : frames ?? this.frames,
    expanded: expanded ?? this.expanded,
    editingTranscript: editingTranscript ?? this.editingTranscript,
    selected: selected ?? this.selected,
    transcript: transcript ?? this.transcript,
  );
}

/// Coordinates optional suggestions and discards work from obsolete edits.
class PublishingIdeasCubit extends Cubit<PublishingIdeasState> {
  PublishingIdeasCubit({required SuggestionsRepository repository})
    : _repository = repository,
      super(const PublishingIdeasState());
  final SuggestionsRepository _repository;
  int _generation = 0;

  void updateSource(PublishingIdeasSource source) {
    if (state.source?.identity == source.identity) return;
    final resetTranscript =
        state.source?.revision != source.revision ||
        state.source?.language != source.language;
    _generation++;
    unawaited(_repository.cancel());
    emit(
      state.copyWith(
        source: source,
        busy: false,
        failed: false,
        resetResult: true,
        resetFrames: true,
        selected: 0,
        editingTranscript: !resetTranscript && state.editingTranscript,
        transcript: resetTranscript || source.hasCaptions
            ? source.transcript
            : state.transcript,
      ),
    );
  }

  void toggleExpanded() {
    final expanded = !state.expanded;
    if (!expanded) cancel();
    emit(state.copyWith(expanded: expanded));
  }

  void toggleTranscriptEditing() => emit(
    state.copyWith(
      editingTranscript: !state.editingTranscript,
    ),
  );

  void editTranscript(String text) {
    cancel();
    emit(state.copyWith(transcript: text));
  }

  void nextIdea() => emit(state.copyWith(selected: state.selected + 1));

  void cancel() {
    _generation++;
    unawaited(_repository.cancel());
    if (!isClosed) {
      emit(
        state.copyWith(
          busy: false,
          failed: false,
          resetResult: true,
          selected: 0,
        ),
      );
    }
  }

  void surprise(List<PublishingIdea> deck) {
    cancel();
    emit(
      state.copyWith(
        result: SuggestedPublishing(
          source: SuggestionSource.premade,
          ideas: _repository.premade(deck, count: 1),
        ),
      ),
    );
  }

  Future<void> generate(
    SuggestionRequest request, {
    Future<List<Uint8List>> Function()? loadFrames,
    List<PublishingIdea> fallback = const [],
  }) async {
    final generation = ++_generation;
    emit(state.copyWith(busy: true, failed: false, selected: 0));
    try {
      final outcome = await _repository.generateWithContext(
        request,
        loadFrames: loadFrames,
        cachedFrames: state.frames,
        fallback: fallback,
      );
      if (isClosed || generation != _generation) return;
      emit(
        state.copyWith(
          busy: false,
          result: outcome.result,
          capabilities: outcome.capabilities,
          frames: outcome.frames == null
              ? null
              : List.unmodifiable(
                  outcome.frames!.map(
                    (frame) => Uint8List.fromList(frame).asUnmodifiableView(),
                  ),
                ),
        ),
      );
    } on Exception {
      if (!isClosed && generation == _generation) {
        emit(state.copyWith(busy: false, failed: true, resetResult: true));
      }
    }
  }

  Future<String?> transcribe(Future<String> Function() load) async {
    final generation = ++_generation;
    emit(state.copyWith(busy: true, failed: false, resetResult: true));
    try {
      final text = await load();
      if (isClosed || generation != _generation) return null;
      emit(
        state.copyWith(
          busy: false,
          failed: text.trim().isEmpty,
          transcript: text,
          editingTranscript: true,
        ),
      );
      return text;
    } on Exception {
      if (!isClosed && generation == _generation) {
        emit(state.copyWith(busy: false, failed: true));
      }
      return null;
    }
  }

  Future<void> prepare() async {
    final generation = ++_generation;
    emit(state.copyWith(busy: true, failed: false, resetResult: true));
    try {
      await _repository.prepare();
      if (!isClosed && generation == _generation) {
        emit(state.copyWith(busy: false));
      }
    } on Exception {
      if (!isClosed && generation == _generation) {
        emit(state.copyWith(busy: false, failed: true));
      }
    }
  }

  @override
  Future<void> close() async {
    _generation++;
    await _repository.cancel();
    await super.close();
  }
}
