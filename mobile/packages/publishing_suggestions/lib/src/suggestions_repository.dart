import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:publishing_suggestions/src/suggestions_client.dart';
import 'package:publishing_suggestions/src/suggestions_models.dart';

/// Owns validation, fallback, and a nonrepeating curated deck.
class SuggestionsRepository {
  /// Creates a repository using the device client.
  SuggestionsRepository({required this._client, Random? random})
    : _random = random ?? Random();

  final SuggestionsClient _client;
  final Random _random;
  int _generation = 0;
  final List<PublishingIdea> _remaining = [];
  List<PublishingIdea>? _deck;

  /// Reports availability without loading the user's media.
  Future<ModelCapabilities> capabilities(String language) =>
      _client.capabilities(language);

  /// User-initiated system model preparation.
  Future<void> prepare() => _client.prepare();

  /// Stops native work; callers also discard obsolete results.
  Future<void> cancel() {
    _generation++;
    return _client.cancel();
  }

  /// Deals localized premade ideas without premature repeats.
  ///
  /// Inline callers request one so unseen options remain in the deck.
  List<PublishingIdea> premade(List<PublishingIdea> deck, {int count = 3}) {
    if (_deck == null ||
        deck.length != _deck!.length ||
        Iterable<int>.generate(deck.length).any(
          (index) =>
              deck[index].title != _deck![index].title ||
              deck[index].description != _deck![index].description,
        )) {
      _remaining.clear();
      _deck = deck;
    }
    if (_remaining.isEmpty) _remaining.addAll([...deck]..shuffle(_random));
    final result = _remaining.take(count).toList();
    _remaining.removeRange(0, result.length);
    return result;
  }

  /// Generates suggestions using the same policy as [generateWithContext].
  Future<SuggestedPublishing> generate(SuggestionRequest request) async =>
      (await generateWithContext(request)).result;

  /// Owns availability checks, optional frame loading and curated fallback.
  /// Returns loaded frames for the caller to cache by source revision.
  Future<SuggestionOutcome> generateWithContext(
    SuggestionRequest request, {
    Future<List<Uint8List>> Function()? loadFrames,
    List<Uint8List>? cachedFrames,
    List<PublishingIdea> fallback = const [],
  }) async {
    final generation = ++_generation;
    ModelCapabilities? support;
    var frames = cachedFrames;
    SuggestionOutcome outcome(SuggestedPublishing result) => SuggestionOutcome(
      capabilities: support,
      frames: frames,
      result:
          result.source == SuggestionSource.premade && generation == _generation
          ? SuggestedPublishing(
              source: SuggestionSource.premade,
              ideas: premade(fallback, count: 1),
            )
          : result,
    );
    const unavailable = SuggestedPublishing(source: SuggestionSource.premade);
    try {
      support = await capabilities(request.language);
      if (generation != _generation ||
          support.availability != ModelAvailability.ready) {
        return outcome(unavailable);
      }
      if (support.images && frames == null && loadFrames != null) {
        try {
          frames = await loadFrames();
        } on Exception {
          frames = const [];
        }
      }
      if (generation != _generation) return outcome(unavailable);
      final usable = SuggestionRequest(
        language: request.language,
        transcript: request.transcript,
        existingTags: request.existingTags,
        frames: support.images ? frames ?? request.frames : const [],
      );
      if (usable.frames.isEmpty && usable.transcript.trim().isEmpty) {
        return outcome(unavailable);
      }
      try {
        return outcome(await _generate(usable, generation));
      } on Exception {
        if (generation != _generation ||
            usable.frames.isEmpty ||
            usable.transcript.trim().isEmpty) {
          return outcome(unavailable);
        }
        return outcome(await _generate(usable.withoutFrames(), generation));
      }
    } on Exception {
      return outcome(unavailable);
    }
  }

  Future<SuggestedPublishing> _generate(
    SuggestionRequest request,
    int generation,
  ) async {
    final raw = await _client
        .generate(request)
        .timeout(
          const Duration(seconds: 30),
          onTimeout: () async {
            if (generation == _generation) await _client.cancel();
            throw TimeoutException('Local generation timed out');
          },
        );
    if (generation != _generation) {
      return const SuggestedPublishing(source: SuggestionSource.premade);
    }
    return SuggestedPublishing.decode(
      raw,
      source: request.frames.isNotEmpty
          ? SuggestionSource.video
          : SuggestionSource.transcript,
      existingTags: request.existingTags,
    );
  }
}

/// The result and reusable inputs from one repository operation.
class SuggestionOutcome {
  /// Creates an outcome without assigning it to a particular UI revision.
  const SuggestionOutcome({
    required this.result,
    this.capabilities,
    this.frames,
  });

  /// Validated generated or curated suggestions.
  final SuggestedPublishing result;

  /// Availability from the single capability check for this operation.
  final ModelCapabilities? capabilities;

  /// Frames loaded for this operation, including an empty failed-load cache.
  final List<Uint8List>? frames;
}
