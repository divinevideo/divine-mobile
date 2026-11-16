import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:videos_repository/videos_repository.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockApiClient extends Mock implements FunnelcakeApiClient {}

class _MockLocalStorage extends Mock implements VideoLocalStorage {}

void main() {
  late _MockNostrClient nostr;
  late _MockApiClient api;
  late _MockLocalStorage local;
  late Completer<List<Event>> localResults;
  late Completer<VideoSearchResponse> apiResults;
  late StreamController<Event> relayResults;
  late VideosRepository repository;

  void setUpSearch() {
    nostr = _MockNostrClient();
    api = _MockApiClient();
    local = _MockLocalStorage();
    localResults = Completer<List<Event>>();
    apiResults = Completer<VideoSearchResponse>();
    relayResults = StreamController<Event>();
    when(() => api.isAvailable).thenReturn(true);
    when(
      () => local.searchEvents(query: 'test-loop'),
    ).thenAnswer((_) => localResults.future);
    when(
      () => local.getEventsByHashtags(hashtags: ['test-loop'], limit: 100),
    ).thenAnswer((_) async => []);
    when(
      () => api.searchVideos(query: 'test-loop'),
    ).thenAnswer((_) => apiResults.future);
    when(
      () => nostr.searchVideos('test-loop', limit: 50),
    ).thenAnswer((_) => relayResults.stream);
    repository = VideosRepository(
      nostrClient: nostr,
      funnelcakeApiClient: api,
      localStorage: local,
    );
  }

  test('API results appear while local and relay are unresolved', () async {
    setUpSearch();
    final emissions = <List<VideoEvent>>[];
    final subscription = repository
        .searchVideos(query: 'test-loop')
        .listen(emissions.add);
    await pumpEventQueue();
    apiResults.complete(_response([_stats('1'), _stats('2')]));
    await pumpEventQueue();

    expect(emissions.last.map((video) => video.id), [_id('1'), _id('2')]);
    expect(localResults.isCompleted, isFalse);
    unawaited(subscription.cancel());
    await pumpEventQueue();
  });

  test('local and relay results appear while API is unresolved', () async {
    setUpSearch();
    final emissions = <List<VideoEvent>>[];
    final subscription = repository
        .searchVideos(query: 'test-loop')
        .listen(emissions.add);
    await pumpEventQueue();
    localResults.complete([_event('3')]);
    await pumpEventQueue();
    expect(emissions.last.map((video) => video.id), [_id('3')]);
    relayResults.add(_event('4'));
    unawaited(relayResults.close());
    await pumpEventQueue();

    expect(emissions.last.map((video) => video.id), [_id('3'), _id('4')]);
    expect(apiResults.isCompleted, isFalse);
    unawaited(subscription.cancel());
    await pumpEventQueue();
  });

  test(
    'late local results retain API precedence and append relay results',
    () async {
      setUpSearch();
      final emissions = <List<VideoEvent>>[];
      var done = false;
      repository
          .searchVideos(query: 'test-loop')
          .listen(
            emissions.add,
            onDone: () => done = true,
          );
      await pumpEventQueue();
      relayResults.add(_event('4'));
      unawaited(relayResults.close());
      await pumpEventQueue();
      apiResults.complete(_response([_stats('2'), _stats('1')]));
      await pumpEventQueue();
      localResults.complete([_event('1'), _event('3')]);
      await pumpEventQueue();

      expect(emissions.last.map((video) => video.id), [
        _id('2'),
        _id('1'),
        _id('3'),
        _id('4'),
      ]);
      expect(emissions.last[1].title, 'API test-loop');
      expect(done, isTrue);
    },
  );

  test('local timeout does not prevent API or relay results', () async {
    setUpSearch();
    final emissions = <List<VideoEvent>>[];
    repository.searchVideos(query: 'test-loop').listen(emissions.add);
    await pumpEventQueue();
    localResults.completeError(TimeoutException('cache unavailable'));
    apiResults.complete(_response([_stats('1')]));
    relayResults.add(_event('4'));
    unawaited(relayResults.close());
    await pumpEventQueue();

    expect(emissions.last.map((video) => video.id), [_id('1'), _id('4')]);
  });

  for (final remoteOutcome in ['empty', 'failed']) {
    test(
      'local timeout and $remoteOutcome remotes emit an empty result',
      () async {
        setUpSearch();
        final results = repository.searchVideos(query: 'test-loop').toList();
        localResults.completeError(TimeoutException('cache unavailable'));
        if (remoteOutcome == 'failed') {
          apiResults.completeError(TimeoutException('API unavailable'));
          relayResults.addError(TimeoutException('relay unavailable'));
        } else {
          apiResults.complete(_response([]));
        }
        await relayResults.close();
        expect(await results, [isEmpty]);
      },
    );
  }

  test(
    'a late local timeout preserves API results already published',
    () async {
      setUpSearch();
      final emissions = <List<VideoEvent>>[];
      final done = Completer<void>();
      repository
          .searchVideos(query: 'test-loop')
          .listen(
            emissions.add,
            onDone: done.complete,
          );
      apiResults.complete(_response([_stats('1')]));
      await pumpEventQueue();
      expect(emissions.last.map((video) => video.id), [_id('1')]);
      localResults.completeError(TimeoutException('cache unavailable'));
      await relayResults.close();
      await done.future;
      expect(emissions.last.map((video) => video.id), [_id('1')]);
    },
  );

  for (final source in ['local', 'API', 'relay']) {
    test(
      '$source programming errors reach an active consumer with their stack',
      () async {
        setUpSearch();
        final failure = StateError('invalid video invariant');
        final stack = StackTrace.fromString('synthetic video source stack');
        final failures = <Object>[];
        final stacks = <StackTrace>[];
        final done = Completer<void>();
        repository
            .searchVideos(query: 'test-loop')
            .listen(
              (_) {},
              onError: (Object error, StackTrace stackTrace) {
                failures.add(error);
                stacks.add(stackTrace);
              },
              onDone: done.complete,
            );
        if (source == 'local') {
          localResults.completeError(failure, stack);
        } else {
          localResults.complete([]);
        }
        if (source == 'API') {
          apiResults.completeError(failure, stack);
        } else {
          apiResults.complete(_response([]));
        }
        if (source == 'relay') relayResults.addError(failure, stack);
        await relayResults.close();
        await done.future;
        expect(failures, [same(failure)]);
        expect(stacks, [same(stack)]);
      },
    );
  }

  test('consumer cancellation completes before outstanding sources', () async {
    setUpSearch();
    final emissions = <List<VideoEvent>>[];
    final subscription = repository
        .searchVideos(query: 'test-loop')
        .listen(emissions.add);
    await pumpEventQueue();
    var cancelled = false;
    unawaited(subscription.cancel().then((_) => cancelled = true));
    await pumpEventQueue();
    expect(cancelled, isTrue);
    localResults.completeError(StateError('cache unavailable'));
    apiResults.completeError(Exception('API unavailable'));
    relayResults.addError(Exception('relay unavailable'));
    unawaited(relayResults.close());
    await pumpEventQueue();
    expect(emissions, isEmpty);
  });
}

String _id(String digit) => digit * 64;

Event _event(String digit) => Event.fromJson({
  'id': _id(digit),
  'pubkey': _id('a'),
  'created_at': 1704067200,
  'kind': EventKind.videoVertical,
  'content': 'test-loop',
  'tags': [
    ['d', digit],
    ['url', 'https://example.com/$digit.mp4'],
  ],
  'sig': '',
});

VideoStats _stats(String digit) => VideoStats(
  id: _id(digit),
  pubkey: _id('a'),
  dTag: digit,
  kind: EventKind.videoVertical,
  createdAt: DateTime.utc(2024),
  title: 'API test-loop',
  thumbnail: 'https://example.com/thumb.jpg',
  videoUrl: 'https://example.com/$digit.mp4',
  reactions: 0,
  comments: 0,
  reposts: 0,
  engagementScore: 0,
);

VideoSearchResponse _response(List<VideoStats> videos) => VideoSearchResponse(
  videos: videos,
  totalCount: videos.length,
);
