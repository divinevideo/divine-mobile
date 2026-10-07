import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:publishing_suggestions/publishing_suggestions.dart';

class _FakeClient implements SuggestionsClient {
  ModelAvailability availability = ModelAvailability.ready;
  bool images = true;
  int capabilityCalls = 0;
  bool failImages = false;
  bool failAll = false;
  final requests = <SuggestionRequest>[];
  @override
  Future<ModelCapabilities> capabilities(String language) async {
    capabilityCalls++;
    return ModelCapabilities(availability: availability, images: images);
  }

  @override
  Future<void> prepare() async {}
  @override
  Future<void> cancel() async {}
  @override
  Future<String> generate(SuggestionRequest request) async {
    requests.add(request);
    if (failAll) throw const FormatException();
    if (failImages && request.frames.isNotEmpty) {
      throw const FormatException('vision');
    }
    return jsonEncode({
      'ideas': [
        {'title': 'A small moment', 'description': 'Here it is.'},
      ],
      'hashtags': ['#Dogs', 'dogs', 'play', 'bad tag', '@person'],
    });
  }
}

void main() {
  group('generateWithContext', () {
    test(
      'one probe selects frames and reports availability with the result',
      () async {
        final client = _FakeClient();
        final repo = SuggestionsRepository(client: client);
        var loads = 0;
        final outcome = await repo.generateWithContext(
          const SuggestionRequest(language: 'en'),
          loadFrames: () async {
            loads++;
            return [
              Uint8List.fromList([7]),
            ];
          },
        );
        expect(client.capabilityCalls, 1);
        expect(loads, 1);
        expect(outcome.capabilities!.availability, ModelAvailability.ready);
        expect(outcome.frames!.single.single, 7);
        expect(outcome.result.source, SuggestionSource.video);
      },
    );

    for (final availability in [
      ModelAvailability.unavailable,
      ModelAvailability.downloadable,
    ]) {
      test(
        '$availability never loads frames and deals one curated idea',
        () async {
          final client = _FakeClient()..availability = availability;
          final repo = SuggestionsRepository(client: client);
          final outcome = await repo.generateWithContext(
            const SuggestionRequest(language: 'en', transcript: 'private'),
            loadFrames: () => throw StateError('Must not load media'),
            fallback: const [
              PublishingIdea(title: 'Curated', description: 'Human'),
            ],
          );
          expect(client.capabilityCalls, 1);
          expect(client.requests, isEmpty);
          expect(outcome.result.ideas.single.title, 'Curated');
          expect(outcome.capabilities!.availability, availability);
        },
      );
    }

    test('text-only capability never loads frames', () async {
      final client = _FakeClient()..images = false;
      final repo = SuggestionsRepository(client: client);
      final outcome = await repo.generateWithContext(
        const SuggestionRequest(language: 'en', transcript: 'words'),
        loadFrames: () => throw StateError('Must not load media'),
      );
      expect(outcome.result.source, SuggestionSource.transcript);
      expect(client.capabilityCalls, 1);
    });

    test(
      'frame extraction failure uses transcript and caches the failed load',
      () async {
        final client = _FakeClient();
        final repo = SuggestionsRepository(client: client);
        final outcome = await repo.generateWithContext(
          const SuggestionRequest(language: 'en', transcript: 'words'),
          loadFrames: () async => throw const FormatException('No frame'),
        );
        expect(outcome.result.source, SuggestionSource.transcript);
        expect(outcome.frames, isEmpty);
        expect(client.capabilityCalls, 1);
        final cached = await repo.generateWithContext(
          const SuggestionRequest(language: 'en', transcript: 'words'),
          cachedFrames: outcome.frames,
          loadFrames: () => throw StateError('Must use cached failure'),
        );
        expect(cached.result.source, SuggestionSource.transcript);
      },
    );
  });

  group('generate and premade', () {
    test('equivalent localized decks retain the remaining unseen ideas', () {
      final repo = SuggestionsRepository(
        client: _FakeClient(),
        random: Random(3),
      );
      final seen = <String>{};
      for (var i = 0; i < 6; i++) {
        final rebuiltDeck = List.generate(
          6,
          (index) => PublishingIdea(title: '$index', description: '$index'),
        );
        expect(
          seen.add(repo.premade(rebuiltDeck, count: 1).single.title),
          isTrue,
        );
      }
    });

    test('inline dealing keeps unseen options for later requests', () {
      final repo = SuggestionsRepository(
        client: _FakeClient(),
        random: Random(3),
      );
      final deck = List.generate(
        6,
        (i) => PublishingIdea(title: '$i', description: '$i'),
      );
      final seen = <PublishingIdea>{};
      for (var i = 0; i < deck.length; i++) {
        expect(seen.add(repo.premade(deck, count: 1).single), isTrue);
      }
    });

    test(
      'cancelled visual generation never retries the private transcript',
      () async {
        final client = _PendingClient();
        final repo = SuggestionsRepository(client: client);
        final pending = repo.generate(
          SuggestionRequest(
            language: 'en',
            transcript: 'private',
            frames: [Uint8List(1)],
          ),
        );
        await client.started.future;
        await repo.cancel();
        client.pending.completeError(const FormatException('cancelled'));
        expect((await pending).source, SuggestionSource.premade);
        expect(client.requests, 1);
      },
    );

    testWidgets('timeout cancels native generation and returns a fallback', (
      tester,
    ) async {
      final client = _PendingClient();
      final repo = SuggestionsRepository(client: client);
      final pending = repo.generate(
        const SuggestionRequest(language: 'en', transcript: 'hello'),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 31));
      expect((await pending).source, SuggestionSource.premade);
      expect(client.cancelled, 1);
    });

    test('premade deck does not repeat until exhausted', () {
      final repo = SuggestionsRepository(
        client: _FakeClient(),
        random: Random(1),
      );
      final deck = List.generate(
        6,
        (i) => PublishingIdea(title: '$i', description: '$i'),
      );
      final first = repo.premade(deck);
      final second = repo.premade(deck);
      expect({...first, ...second}, hasLength(6));
      expect(repo.premade(deck), hasLength(3));
    });

    test(
      'visual failure retries transcript only and filters existing tags',
      () async {
        final client = _FakeClient()..failImages = true;
        final repo = SuggestionsRepository(client: client);
        final result = await repo.generate(
          SuggestionRequest(
            language: 'en',
            transcript: 'A dog playing',
            frames: [
              Uint8List.fromList([1]),
            ],
            existingTags: {'DOGS'},
          ),
        );
        expect(result.source, SuggestionSource.transcript);
        expect(result.ideas.single.title, 'A small moment');
        expect(result.hashtags, ['play']);
        expect(client.requests.last.frames, isEmpty);
      },
    );

    test('unsupported model never sends the private transcript', () async {
      final client = _FakeClient()
        ..availability = ModelAvailability.unavailable;
      final repo = SuggestionsRepository(client: client);
      final result = await repo.generate(
        const SuggestionRequest(language: 'en', transcript: 'private'),
      );
      expect(result.source, SuggestionSource.premade);
      expect(client.requests, isEmpty);
    });

    test(
      'silent video uses images or falls back without fabricating context',
      () async {
        final client = _FakeClient();
        final repo = SuggestionsRepository(client: client);
        final request = SuggestionRequest(
          language: 'en',
          frames: [Uint8List(1)],
        );
        expect((await repo.generate(request)).source, SuggestionSource.video);
        client.images = false;
        expect((await repo.generate(request)).source, SuggestionSource.premade);
      },
    );

    test('all generation failures return curated fallback', () async {
      final client = _FakeClient()..failAll = true;
      final repo = SuggestionsRepository(client: client);
      expect(
        (await repo.generate(
          const SuggestionRequest(language: 'en', transcript: 'hello'),
        )).source,
        SuggestionSource.premade,
      );
      expect(
        (await repo.generate(
          SuggestionRequest(
            language: 'en',
            transcript: 'hello',
            frames: [Uint8List(1)],
          ),
        )).source,
        SuggestionSource.premade,
      );
      await repo.prepare();
      await repo.cancel();
    });

    test(
      'malformed entries, duplicates, and excessive results are excluded',
      () {
        final raw = jsonEncode({
          'ideas': [
            null,
            {'title': 12},
            {'title': ' ', 'description': 'x'},
            {'title': 'one', 'description': 'first'},
            {'title': 'one', 'description': 'first'},
            {'title': 'two', 'description': 'second'},
            {'title': 'three', 'description': 'third'},
            {'title': 'four', 'description': 'fourth'},
          ],
          'hashtags': [1, 'a', 'b', 'c', 'd', 'e', 'f'],
        });
        final result = SuggestedPublishing.decode(
          raw,
          source: SuggestionSource.video,
        );
        expect(result.ideas.map((i) => i.title), ['one', 'two', 'three']);
        expect(result.hashtags, ['a', 'b', 'c', 'd', 'e']);
        expect(
          () =>
              SuggestedPublishing.decode('[]', source: SuggestionSource.video),
          throwsFormatException,
        );
      },
    );

    test('invalid output is rejected instead of inserted', () {
      expect(
        () => SuggestedPublishing.decode(
          'not json',
          source: SuggestionSource.video,
        ),
        throwsFormatException,
      );
      expect(
        () => SuggestedPublishing.decode(
          '{"ideas":[{"title":"#spam","description":"@someone"}]}',
          source: SuggestionSource.video,
        ),
        throwsFormatException,
      );
    });
  });
}

class _PendingClient implements SuggestionsClient {
  final pending = Completer<String>();
  final started = Completer<void>();
  int requests = 0;
  int cancelled = 0;
  @override
  Future<ModelCapabilities> capabilities(String language) async =>
      const ModelCapabilities(
        availability: ModelAvailability.ready,
        images: true,
      );
  @override
  Future<void> prepare() async {}
  @override
  Future<void> cancel() async {
    cancelled++;
  }

  @override
  Future<String> generate(SuggestionRequest request) {
    requests++;
    started.complete();
    return pending.future;
  }
}
