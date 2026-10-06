import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/features/publishing_ideas/publishing_ideas_cubit.dart';
import 'package:publishing_suggestions/publishing_suggestions.dart';

class FakeClient implements SuggestionsClient {
  final pending = Completer<String>();
  final started = Completer<void>();
  int cancelled = 0;
  @override
  Future<ModelCapabilities> capabilities(String language) async =>
      const ModelCapabilities(availability: ModelAvailability.ready);
  @override
  Future<void> cancel() async {
    cancelled++;
  }

  @override
  Future<void> prepare() async {}
  @override
  Future<String> generate(SuggestionRequest request) {
    started.complete();
    return pending.future;
  }
}

void main() {
  group('generate and source changes', () {
    test('old frame failure cannot erase the new composition cache', () async {
      final client = RecordingClient();
      final cubit = PublishingIdeasCubit(
        repository: SuggestionsRepository(client: client),
      );
      final oldFrames = Completer<List<Uint8List>>();
      final framesStarted = Completer<void>();
      cubit.setSource('old');
      final old = cubit.generate(
        const SuggestionRequest(language: 'en'),
        loadFrames: () {
          framesStarted.complete();
          return oldFrames.future;
        },
      );
      await framesStarted.future;
      cubit.setSource('new');
      await cubit.generate(
        const SuggestionRequest(language: 'en'),
        loadFrames: () async => [
          Uint8List.fromList([2]),
        ],
      );
      oldFrames.completeError(const FormatException('old failed'));
      await old;
      await cubit.generate(
        const SuggestionRequest(language: 'en'),
        loadFrames: () async => [
          Uint8List.fromList([3]),
        ],
      );
      expect(client.frames, [2, 2]);
      await cubit.close();
    });

    test('discard a response when source revision changes', () async {
      final client = FakeClient();
      final cubit = PublishingIdeasCubit(
        repository: SuggestionsRepository(client: client),
      );
      cubit.setSource('first');
      final result = cubit.generate(
        const SuggestionRequest(language: 'en', transcript: 'one'),
      );
      await client.started.future;
      cubit.setSource('second');
      client.pending.complete(
        '{"ideas":[{"title":"Old","description":"Stale"}]}',
      );
      await result;
      expect(cubit.state.result, isNull);
      expect(cubit.state.busy, isFalse);
      expect(client.cancelled, greaterThan(0));
      await cubit.close();
    });

    test('curated ideas are immediate and never come with hashtags', () async {
      final cubit = PublishingIdeasCubit(
        repository: SuggestionsRepository(client: FakeClient()),
      );
      cubit.surprise(const [
        PublishingIdea(title: 'Hello', description: 'A moment'),
      ]);
      expect(cubit.state.result!.ideas.single.title, 'Hello');
      expect(cubit.state.result!.hashtags, isEmpty);
      await cubit.close();
    });
  });
}

class RecordingClient implements SuggestionsClient {
  final frames = <int>[];
  @override
  Future<ModelCapabilities> capabilities(String language) async =>
      const ModelCapabilities(
        availability: ModelAvailability.ready,
        images: true,
      );
  @override
  Future<void> prepare() async {}
  @override
  Future<void> cancel() async {}
  @override
  Future<String> generate(SuggestionRequest request) async {
    frames.add(request.frames.single.first);
    return '{"ideas":[{"title":"A moment","description":"Here it is"}]}';
  }
}
