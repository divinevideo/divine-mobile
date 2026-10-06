import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:publishing_suggestions/publishing_suggestions.dart';

/// Inline ideas state; never owns the creator's actual metadata.
class PublishingIdeasState {
  const PublishingIdeasState({
    this.busy = false,
    this.result,
    this.capabilities,
    this.failed = false,
  });
  final bool busy;
  final SuggestedPublishing? result;
  final ModelCapabilities? capabilities;
  final bool failed;
}

/// Coordinates optional suggestions and discards work from obsolete edits.
class PublishingIdeasCubit extends Cubit<PublishingIdeasState> {
  PublishingIdeasCubit({required SuggestionsRepository repository})
    : _repository = repository,
      super(const PublishingIdeasState());
  final SuggestionsRepository _repository;
  String? _revision;
  int _generation = 0;
  List<Uint8List>? _frames;

  void setSource(String revision) {
    if (_revision == revision) return;
    _revision = revision;
    _frames = null;
    cancel();
  }

  void cancel() {
    _generation++;
    unawaited(_repository.cancel());
    if (!isClosed) emit(const PublishingIdeasState());
  }

  void surprise(List<PublishingIdea> deck) {
    cancel();
    emit(
      PublishingIdeasState(
        result: SuggestedPublishing(
          source: SuggestionSource.premade,
          ideas: _repository.premade(deck),
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
    emit(PublishingIdeasState(busy: true, result: state.result));
    try {
      final capabilities = await _repository.capabilities(request.language);
      if (isClosed || generation != _generation) return;
      if (capabilities.availability != ModelAvailability.ready) {
        emit(
          PublishingIdeasState(
            capabilities: capabilities,
            result: SuggestedPublishing(
              source: SuggestionSource.premade,
              ideas: _repository.premade(fallback),
            ),
          ),
        );
        return;
      }
      if (capabilities.images && loadFrames != null && _frames == null) {
        try {
          final frames = await loadFrames();
          if (isClosed || generation != _generation) return;
          _frames = frames;
        } on Exception {
          if (isClosed || generation != _generation) return;
          _frames = [];
        }
      }
      if (isClosed || generation != _generation) return;
      final result = await _repository.generate(
        SuggestionRequest(
          language: request.language,
          transcript: request.transcript,
          existingTags: request.existingTags,
          frames: _frames ?? request.frames,
        ),
      );
      if (isClosed || generation != _generation) return;
      emit(
        PublishingIdeasState(
          result: result.source == SuggestionSource.premade
              ? SuggestedPublishing(
                  source: SuggestionSource.premade,
                  ideas: _repository.premade(fallback),
                )
              : result,
          capabilities: capabilities,
        ),
      );
    } on Exception {
      if (!isClosed && generation == _generation) {
        emit(const PublishingIdeasState(failed: true));
      }
    }
  }

  Future<String?> transcribe(Future<String> Function() load) async {
    final generation = ++_generation;
    emit(const PublishingIdeasState(busy: true));
    try {
      final text = await load();
      if (isClosed || generation != _generation) return null;
      emit(PublishingIdeasState(failed: text.trim().isEmpty));
      return text;
    } on Exception {
      if (!isClosed && generation == _generation) {
        emit(const PublishingIdeasState(failed: true));
      }
      return null;
    }
  }

  Future<void> prepare() async {
    final generation = ++_generation;
    emit(const PublishingIdeasState(busy: true));
    try {
      await _repository.prepare();
      if (!isClosed && generation == _generation) {
        emit(const PublishingIdeasState());
      }
    } on Exception {
      if (!isClosed && generation == _generation) {
        emit(const PublishingIdeasState(failed: true));
      }
    }
  }

  @override
  Future<void> close() async {
    _generation++;
    _frames = null;
    await _repository.cancel();
    await super.close();
  }
}
