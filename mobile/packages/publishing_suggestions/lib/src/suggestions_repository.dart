import 'dart:async';
import 'dart:math';

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

  /// Deals up to three localized, handwritten ideas without premature repeats.
  List<PublishingIdea> premade(List<PublishingIdea> deck) {
    if (!identical(deck, _deck)) {
      _remaining.clear();
      _deck = deck;
    }
    if (_remaining.isEmpty) _remaining.addAll([...deck]..shuffle(_random));
    final result = _remaining.take(3).toList();
    _remaining.removeRange(0, result.length);
    return result;
  }

  /// Falls back from visual context to transcript, then the UI's curated deck.
  Future<SuggestedPublishing> generate(SuggestionRequest request) async {
    final generation = ++_generation;
    const fallback = SuggestedPublishing(source: SuggestionSource.premade);
    try {
      final support = await capabilities(request.language);
      if (generation != _generation ||
          support.availability != ModelAvailability.ready) {
        return fallback;
      }
      final usable = support.images ? request : request.withoutFrames();
      if (usable.frames.isEmpty && usable.transcript.trim().isEmpty) {
        return fallback;
      }
      try {
        return await _generate(usable, generation);
      } on Exception {
        if (generation != _generation ||
            usable.frames.isEmpty ||
            usable.transcript.trim().isEmpty) {
          return fallback;
        }
        return await _generate(usable.withoutFrames(), generation);
      }
    } on Exception {
      return fallback;
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
