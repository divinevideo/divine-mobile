import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/features/publishing_ideas/publishing_ideas_cubit.dart';
import 'package:openvine/features/publishing_ideas/publishing_ideas_source.dart';
import 'package:publishing_suggestions/publishing_suggestions.dart';

class _FakeClient implements SuggestionsClient {
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

PublishingIdeasSource _source(String revision, {String transcript = ''}) =>
    PublishingIdeasSource(
      identity: revision,
      revision: revision,
      language: 'en',
      transcript: transcript,
      hasCaptions: false,
      canTranscribe: false,
    );

void main() {
  group('source and UI state', () {
    test(
      'same source preserves editing state and does not cancel native work',
      () async {
        final client = _FakeClient();
        final cubit = PublishingIdeasCubit(
          repository: SuggestionsRepository(client: client),
        );
        cubit.updateSource(_source('first', transcript: 'saved'));
        cubit.toggleExpanded();
        cubit.toggleTranscriptEditing();
        cubit.editTranscript('corrected');
        final cancellations = client.cancelled;
        cubit.updateSource(_source('first', transcript: 'saved'));
        expect(cubit.state.transcript, 'corrected');
        expect(cubit.state.editingTranscript, isTrue);
        expect(cubit.state.expanded, isTrue);
        expect(client.cancelled, cancellations);
        cubit.updateSource(_source('second'));
        expect(cubit.state.transcript, isEmpty);
        expect(cubit.state.editingTranscript, isFalse);
        expect(cubit.state.expanded, isTrue);
        await cubit.close();
      },
    );

    test(
      'obsolete transcription cannot overwrite a changed composition',
      () async {
        final cubit = PublishingIdeasCubit(
          repository: SuggestionsRepository(client: _FakeClient()),
        );
        final transcript = Completer<String>();
        cubit.updateSource(_source('first'));
        final pending = cubit.transcribe(() => transcript.future);
        cubit.updateSource(_source('second', transcript: 'new'));
        transcript.complete('obsolete');
        expect(await pending, isNull);
        expect(cubit.state.transcript, 'new');
        expect(cubit.state.busy, isFalse);
        await cubit.close();
      },
    );
  });
  group('generate and source changes', () {
    test('old frame failure cannot erase the new composition cache', () async {
      final client = _RecordingClient();
      final cubit = PublishingIdeasCubit(
        repository: SuggestionsRepository(client: client),
      );
      final oldFrames = Completer<List<Uint8List>>();
      final framesStarted = Completer<void>();
      cubit.updateSource(_source('old'));
      final old = cubit.generate(
        const SuggestionRequest(language: 'en'),
        loadFrames: () {
          framesStarted.complete();
          return oldFrames.future;
        },
      );
      await framesStarted.future;
      cubit.updateSource(_source('new'));
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
      expect(client.capabilityCalls, 3);
      expect(
        () => cubit.state.frames!.add(Uint8List(1)),
        throwsUnsupportedError,
      );
      expect(() => cubit.state.frames!.single[0] = 9, throwsUnsupportedError);
      await cubit.close();
    });

    test('discard a response when source revision changes', () async {
      final client = _FakeClient();
      final cubit = PublishingIdeasCubit(
        repository: SuggestionsRepository(client: client),
      );
      cubit.updateSource(_source('first'));
      final result = cubit.generate(
        const SuggestionRequest(language: 'en', transcript: 'one'),
      );
      await client.started.future;
      cubit.updateSource(_source('second'));
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
        repository: SuggestionsRepository(client: _FakeClient()),
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

class _RecordingClient implements SuggestionsClient {
  int capabilityCalls = 0;
  final frames = <int>[];
  @override
  Future<ModelCapabilities> capabilities(String language) async {
    capabilityCalls++;
    return const ModelCapabilities(
      availability: ModelAvailability.ready,
      images: true,
    );
  }

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
