import 'dart:convert';
import 'dart:typed_data';

/// Whether the system model can run or needs explicit preparation.
enum ModelAvailability {
  /// Ready to generate locally.
  ready,

  /// User may download the system model.
  downloadable,

  /// System preparation is in progress.
  preparing,

  /// No compatible model or language.
  unavailable,
}

/// Which private source contributed to suggestions.
enum SuggestionSource {
  /// Sampled visual context, optionally with speech.
  video,

  /// Corrected speech without visual context.
  transcript,

  /// Human-written offline ideas.
  premade,
}

/// Capabilities for the requested language on this device.
class ModelCapabilities {
  /// Creates a capability report.
  const ModelCapabilities({required this.availability, this.images = false});

  /// System model readiness.
  final ModelAvailability availability;

  /// Whether visual understanding is available.
  final bool images;
}

/// An editable title and description pair.
class PublishingIdea {
  /// Creates a pair; hashtags are selected independently.
  const PublishingIdea({required this.title, required this.description});

  /// Suggested title.
  final String title;

  /// Suggested description.
  final String description;
}

/// Private inputs for one local generation request.
class SuggestionRequest {
  /// Creates a request from the current edited video.
  const SuggestionRequest({
    required this.language,
    this.transcript = '',
    this.frames = const [],
    this.existingTags = const {},
  });

  /// BCP-47 output language.
  final String language;

  /// Current creator-corrected transcript.
  final String transcript;

  /// Encoded frames sampled from the rendered video.
  final List<Uint8List> frames;

  /// Tags already selected by the creator.
  final Set<String> existingTags;

  /// A text-only retry with the same corrected context.
  SuggestionRequest withoutFrames() => SuggestionRequest(
    language: language,
    transcript: transcript,
    existingTags: existingTags,
  );
}

/// Validated suggestions; an empty result asks the UI to offer its local deck.
class SuggestedPublishing {
  /// Creates validated suggestions.
  const SuggestedPublishing({
    required this.source,
    this.ideas = const [],
    this.hashtags = const [],
  });

  /// Decodes bounded plain-text metadata from model JSON.
  factory SuggestedPublishing.decode(
    String raw, {
    required SuggestionSource source,
    Set<String> existingTags = const {},
  }) {
    final Object? decoded = jsonDecode(raw);
    if (decoded is! Map || decoded['ideas'] is! List) {
      throw const FormatException('Invalid suggestion result');
    }
    final ideas = <PublishingIdea>[];
    final seen = <String>{};
    for (final entry in decoded['ideas'] as List) {
      if (entry is! Map) continue;
      final title = entry['title'];
      final description = entry['description'];
      if (title is! String || description is! String) continue;
      if (title.trim().isEmpty ||
          description.trim().isEmpty ||
          title.length > 160 ||
          description.length > 500 ||
          RegExp('[#@]').hasMatch('$title $description')) {
        continue;
      }
      if (!seen.add('${title.trim()}\n${description.trim()}')) continue;
      ideas.add(
        PublishingIdea(title: title.trim(), description: description.trim()),
      );
      if (ideas.length == 3) break;
    }
    if (ideas.isEmpty) throw const FormatException('No usable suggestions');
    final tags = <String>{};
    final existing = existingTags.map((t) => t.toLowerCase()).toSet();
    final rawTags = decoded['hashtags'];
    if (rawTags is List) {
      for (final value in rawTags.whereType<String>()) {
        final tag = value.trim().replaceFirst(RegExp('^#'), '').toLowerCase();
        // Matches the app's tag selector without silently changing a phrase.
        if (RegExp(r'^[a-z0-9]{1,40}$').hasMatch(tag) &&
            !existing.contains(tag)) {
          tags.add(tag);
        }
        if (tags.length == 5) break;
      }
    }
    return SuggestedPublishing(
      source: source,
      ideas: ideas,
      hashtags: tags.toList(),
    );
  }

  /// Sources actually used, not merely requested.
  final SuggestionSource source;

  /// Up to three editable options.
  final List<PublishingIdea> ideas;

  /// Up to five independently selectable tags.
  final List<String> hashtags;
}
