import 'dart:async';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:post_live_activity_repository/post_live_activity_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef _StartRequest = ({String owner, bool note, String? thumb});
typedef _Update = ({
  String id,
  LiveActivityPhase phase,
  bool note,
  String? coordinate,
  String? eventId,
});
typedef _End = ({String id, bool immediate});

class _FakePlatform implements LiveActivityPlatform {
  final _events = StreamController<LiveActivityPlatformEvent>();
  final calls = <String>[];
  final startRequests = <_StartRequest>[];
  final startedIds = <String>[];
  final updates = <_Update>[];
  final ends = <_End>[];
  final startGates = <Completer<String>>[];
  bool enabled = true;
  Completer<bool>? enabledGate;
  List<RunningLiveActivity> running = [];
  StateError? enabledError;
  StateError? listError;
  StateError? updateError;
  StateError? endError;
  StateError? thumbnailError;
  StateError? startError;
  bool get hasListener => _events.hasListener;
  var _nextId = 0;

  void emit(LiveActivityPlatformEvent event) => _events.add(event);

  List<String> get endedIds => [for (final end in ends) end.id];

  @override
  Stream<LiveActivityPlatformEvent> get events => _events.stream;

  @override
  Future<bool> isEnabled() async {
    if (enabledError case final error?) throw error;
    if (enabledGate case final gate?) return gate.future;
    return enabled;
  }

  @override
  Future<String> writeThumbnail(Uint8List bytes) async {
    calls.add('writeThumbnail');
    if (thumbnailError case final error?) throw error;
    return 'thumb.jpg';
  }

  @override
  Future<String> start({
    required String ownerPubkey,
    required bool showFirstRunNote,
    String? thumbnailFileName,
  }) async {
    calls.add('start');
    startRequests.add((
      owner: ownerPubkey,
      note: showFirstRunNote,
      thumb: thumbnailFileName,
    ));
    if (startError case final error?) throw error;
    final id = startGates.isNotEmpty
        ? await startGates.removeAt(0).future
        : 'act-${++_nextId}';
    startedIds.add(id);
    return id;
  }

  @override
  Future<void> update(
    String id, {
    required LiveActivityPhase phase,
    required bool showFirstRunNote,
    String? postCoordinate,
    String? postEventId,
  }) async {
    calls.add('update $id');
    updates.add((
      id: id,
      phase: phase,
      note: showFirstRunNote,
      coordinate: postCoordinate,
      eventId: postEventId,
    ));
    if (updateError case final error?) throw error;
  }

  @override
  Future<void> end(String id, {required bool immediate}) async {
    calls.add('end $id');
    ends.add((id: id, immediate: immediate));
    if (endError case final error?) throw error;
  }

  @override
  Future<List<RunningLiveActivity>> list() async {
    calls.add('list');
    if (listError case final error?) throw error;
    return List.of(running);
  }
}

class _FakeRegistrar implements LiveActivityRegistrar {
  final sent = <LiveActivityRegistration>[];
  final queued = <Future<LiveActivityRegistrarResult>>[];
  LiveActivityRegistrarResult fallback = LiveActivityRegistrarResult.published;
  Object? error;

  List<LiveActivityRegistration> get active => [
    for (final r in sent)
      if (r.state == LiveActivityRegistrationState.active) r,
  ];

  List<LiveActivityRegistration> get ended => [
    for (final r in sent)
      if (r.state == LiveActivityRegistrationState.ended) r,
  ];

  @override
  Future<LiveActivityRegistrarResult> register(
    LiveActivityRegistration registration,
  ) {
    sent.add(registration);
    if (error case final error?) return Future.error(error);
    if (queued.isNotEmpty) return queued.removeAt(0);
    return Future.value(fallback);
  }
}

final String _ownerA = 'a' * 64;
final String _ownerB = 'b' * 64;
final _coordA = '34236:$_ownerA:d-a';
final _coordB = '34236:$_ownerA:d-b';
const _eventA = 'event-a';
const _enabledKey = 'post_live_activity_enabled';
const _noteKey = 'post_live_activity_first_run_note_shown';

RunningLiveActivity _running(
  String id, {
  required String owner,
  required DateTime startedAt,
  LiveActivityState state = LiveActivityState.active,
  String? coordinate,
  String? eventId,
}) => RunningLiveActivity(
  id: id,
  ownerPubkey: owner,
  startedAt: startedAt,
  state: state,
  postCoordinate: coordinate,
  postEventId: eventId,
);

void main() {
  group(PostLiveActivityRepository, () {
    final t0 = DateTime.utc(2026, 11, 19, 12);
    late _FakePlatform platform;
    late _FakeRegistrar registrar;
    late SharedPreferences prefs;
    late List<({Object error, String site})> reported;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      platform = _FakePlatform();
      registrar = _FakeRegistrar();
      reported = [];
    });

    PostLiveActivityRepository build(FakeAsync async) =>
        PostLiveActivityRepository(
          platform: platform,
          registrar: registrar,
          sharedPreferences: prefs,
          now: () => t0.add(async.elapsed),
          errorReporter: (error, stack, {required site}) =>
              reported.add((error: error, site: site)),
        );

    DateTime nowOf(FakeAsync async) => t0.add(async.elapsed);

    /// Starts [key], lets the start return, and returns the activity id.
    String started(
      FakeAsync async,
      PostLiveActivityRepository repo, {
      String key = 'draft-1',
      String? owner,
    }) {
      repo.startPosting(
        key: key,
        ownerPubkey: owner ?? _ownerA,
        thumbnail: Future.value(),
      );
      async.flushMicrotasks();
      return platform.startedIds.last;
    }

    /// Starts [key], gives it a token, marks it live and returns its id.
    String live(
      FakeAsync async,
      PostLiveActivityRepository repo, {
      String key = 'draft-1',
      String? owner,
      String? coordinate,
      String token = 'tok-1',
    }) {
      final id = started(async, repo, key: key, owner: owner);
      platform.emit(PushTokenChanged(activityId: id, token: token));
      unawaited(
        repo.markLive(
          key: key,
          postCoordinate: coordinate ?? _coordA,
          postEventId: _eventA,
        ),
      );
      async.flushMicrotasks();
      return id;
    }

    group('starting', () {
      test('startPosting does nothing when the toggle is off', () {
        fakeAsync((async) {
          unawaited(prefs.setBool(_enabledKey, false));
          build(async).startPosting(
            key: 'draft-1',
            ownerPubkey: _ownerA,
            thumbnail: Future.value(),
          );
          async.flushMicrotasks();

          expect(platform.calls, isEmpty);
        });
      });

      test('startPosting does nothing when the feature is off', () {
        fakeAsync((async) {
          build(async)
            ..featureEnabled = false
            ..startPosting(
              key: 'draft-1',
              ownerPubkey: _ownerA,
              thumbnail: Future.error(StateError('ignored')),
            );
          async.flushMicrotasks();

          expect(platform.calls, isEmpty);
        });
      });

      test('startPosting does nothing when the system switch is off', () {
        fakeAsync((async) {
          platform.enabled = false;
          final repo = build(async)
            ..startPosting(
              key: 'draft-1',
              ownerPubkey: _ownerA,
              thumbnail: Future.value(Uint8List(1)),
            );
          async.flushMicrotasks();
          unawaited(
            repo.markLive(
              key: 'draft-1',
              postCoordinate: _coordA,
              postEventId: _eventA,
            ),
          );
          async.flushMicrotasks();

          expect(platform.calls, isEmpty);
        });
      });

      test('startPosting ends everything list() returns (including ended '
          'activities still showing a summary), sends ended for any '
          'registered one detached, then writes the thumbnail and starts', () {
        fakeAsync((async) {
          final repo = build(async);
          final id = live(async, repo);
          platform
            ..running = [
              _running(id, owner: _ownerA, startedAt: t0),
              _running(
                'summary-1',
                owner: _ownerA,
                startedAt: t0,
                state: LiveActivityState.ended,
              ),
            ]
            ..calls.clear();
          final endedSend = Completer<LiveActivityRegistrarResult>();
          registrar.queued.add(endedSend.future);

          repo.startPosting(
            key: 'draft-2',
            ownerPubkey: _ownerA,
            thumbnail: Future.value(Uint8List.fromList([1, 2, 3])),
          );
          async.flushMicrotasks();

          expect(platform.calls, [
            'list',
            'end $id',
            'end summary-1',
            'writeThumbnail',
            'start',
          ]);
          expect(platform.ends.every((end) => end.immediate), isTrue);
          expect(registrar.ended, hasLength(1));
          expect(registrar.ended.single.activityId, id);
          expect(endedSend.isCompleted, isFalse);
          expect(platform.startRequests.last.thumb, 'thumb.jpg');
        });
      });

      test('the first-run note shows on the first start only', () {
        fakeAsync((async) {
          final repo = build(async);
          platform.startError = StateError('start refused');
          repo.startPosting(
            key: 'draft-0',
            ownerPubkey: _ownerA,
            thumbnail: Future.value(),
          );
          async.flushMicrotasks();
          expect(platform.startRequests.single.note, isTrue);
          expect(prefs.getBool(_noteKey), isNull);

          platform.startError = null;
          started(async, repo);
          expect(platform.startRequests[1].note, isTrue);
          expect(prefs.getBool(_noteKey), isTrue);

          started(async, repo, key: 'draft-2');
          expect(platform.startRequests[2].note, isFalse);
        });
      });

      group('a start that returns after its key was cancelled or superseded '
          'is ended immediately and not tracked', () {
        test('sign-out mid-start', () {
          fakeAsync((async) {
            final repo = build(async);
            final gate = Completer<String>();
            platform.startGates.add(gate);
            repo.startPosting(
              key: 'draft-1',
              ownerPubkey: _ownerA,
              thumbnail: Future.value(),
            );
            async.flushMicrotasks();

            unawaited(repo.endLocally(ownerPubkey: _ownerA));
            gate.complete('act-late');
            async.flushMicrotasks();
            platform.emit(
              const PushTokenChanged(activityId: 'act-late', token: 't'),
            );
            unawaited(
              repo.markLive(
                key: 'draft-1',
                postCoordinate: _coordA,
                postEventId: _eventA,
              ),
            );
            async.flushMicrotasks();

            expect(platform.endedIds, ['act-late']);
            expect(platform.updates, isEmpty);
            expect(registrar.sent, isEmpty);
            expect(prefs.getBool(_noteKey), isNull);
          });
        });

        test('toggle-off mid-start', () {
          fakeAsync((async) {
            final repo = build(async);
            final gate = Completer<String>();
            platform.startGates.add(gate);
            repo.startPosting(
              key: 'draft-1',
              ownerPubkey: _ownerA,
              thumbnail: Future.value(),
            );
            async.flushMicrotasks();

            unawaited(repo.setToggleOn(false));
            gate.complete('act-late');
            async.flushMicrotasks();
            unawaited(
              repo.markLive(
                key: 'draft-1',
                postCoordinate: _coordA,
                postEventId: _eventA,
              ),
            );
            async.flushMicrotasks();

            expect(platform.endedIds, ['act-late']);
            expect(platform.updates, isEmpty);
            expect(prefs.getBool(_noteKey), isNull);
          });
        });

        test('two quick posts: only the second survives', () {
          fakeAsync((async) {
            final repo = build(async);
            final gate = Completer<String>();
            platform.startGates.add(gate);
            repo.startPosting(
              key: 'draft-1',
              ownerPubkey: _ownerA,
              thumbnail: Future.value(),
            );
            async.flushMicrotasks();
            repo.startPosting(
              key: 'draft-2',
              ownerPubkey: _ownerA,
              thumbnail: Future.value(),
            );
            async.flushMicrotasks();
            gate.complete('act-first');
            async.flushMicrotasks();

            unawaited(
              repo.markLive(
                key: 'draft-1',
                postCoordinate: _coordB,
                postEventId: 'event-b',
              ),
            );
            unawaited(
              repo.markLive(
                key: 'draft-2',
                postCoordinate: _coordA,
                postEventId: _eventA,
              ),
            );
            async.flushMicrotasks();

            expect(platform.startedIds, ['act-first', 'act-1']);
            expect(platform.endedIds, ['act-first']);
            expect(platform.updates.single.id, 'act-1');
            expect(platform.updates.single.coordinate, _coordA);
          });
        });
      });

      test('markLive and end for a superseded key do nothing', () {
        fakeAsync((async) {
          final repo = build(async);
          final first = started(async, repo);
          platform.emit(PushTokenChanged(activityId: first, token: 'tok'));
          async.flushMicrotasks();
          platform
            ..running = [_running(first, owner: _ownerA, startedAt: t0)]
            ..enabledGate = Completer<bool>();

          repo.startPosting(
            key: 'draft-2',
            ownerPubkey: _ownerA,
            thumbnail: Future.value(),
          );
          unawaited(
            repo.markLive(
              key: 'draft-1',
              postCoordinate: _coordA,
              postEventId: _eventA,
            ),
          );
          unawaited(repo.end(key: 'draft-1'));
          async.flushMicrotasks();
          expect(platform.updates, isEmpty);
          expect(platform.ends, isEmpty);

          platform.enabledGate!.complete(true);
          async.flushMicrotasks();

          expect(platform.updates, isEmpty);
          expect(registrar.sent, isEmpty);
          expect(platform.endedIds, [first]);
        });
      });

      test('a failed platform start clears the pending key', () {
        fakeAsync((async) {
          platform.startError = StateError('start refused');
          final repo = build(async)
            ..startPosting(
              key: 'draft-1',
              ownerPubkey: _ownerA,
              thumbnail: Future.value(),
            );
          async.flushMicrotasks();
          unawaited(
            repo.markLive(
              key: 'draft-1',
              postCoordinate: _coordA,
              postEventId: _eventA,
            ),
          );
          unawaited(repo.end(key: 'draft-1'));
          async.flushMicrotasks();

          expect(platform.updates, isEmpty);
          expect(platform.ends, isEmpty);
        });
      });
    });

    group('the publish race', () {
      test('markLive awaits a start still in flight for the same key, then '
          'goes live (RF5)', () {
        fakeAsync((async) {
          final repo = build(async);
          final gate = Completer<String>();
          platform.startGates.add(gate);
          repo.startPosting(
            key: 'draft-1',
            ownerPubkey: _ownerA,
            thumbnail: Future.value(),
          );
          async.flushMicrotasks();
          unawaited(
            repo.markLive(
              key: 'draft-1',
              postCoordinate: _coordA,
              postEventId: _eventA,
            ),
          );
          async.flushMicrotasks();
          expect(platform.updates, isEmpty);

          gate.complete('act-slow');
          async.flushMicrotasks();

          expect(platform.updates, [
            (
              id: 'act-slow',
              phase: LiveActivityPhase.live,
              note: true,
              coordinate: _coordA,
              eventId: _eventA,
            ),
          ]);
        });
      });

      test('end awaits a start in flight, then ends', () {
        fakeAsync((async) {
          final repo = build(async);
          final gate = Completer<String>();
          platform.startGates.add(gate);
          repo.startPosting(
            key: 'draft-1',
            ownerPubkey: _ownerA,
            thumbnail: Future.value(),
          );
          async.flushMicrotasks();
          unawaited(repo.end(key: 'draft-1'));
          async.flushMicrotasks();
          expect(platform.ends, isEmpty);

          gate.complete('act-slow');
          async.flushMicrotasks();

          expect(platform.ends, [(id: 'act-slow', immediate: true)]);
        });
      });

      test('markLive for a key that never started does nothing', () {
        fakeAsync((async) {
          final repo = build(async);
          unawaited(
            repo.markLive(
              key: 'never',
              postCoordinate: _coordA,
              postEventId: _eventA,
            ),
          );
          async.flushMicrotasks();

          expect(platform.calls, isEmpty);
          expect(registrar.sent, isEmpty);
        });
      });
    });

    group('registration', () {
      test('markLive sets postedAt to now, updates the platform with '
          'identity, and registers once a token exists', () {
        fakeAsync((async) {
          final repo = build(async);
          final id = started(async, repo);
          async.elapse(const Duration(minutes: 2));
          final postedAt = nowOf(async);
          unawaited(
            repo.markLive(
              key: 'draft-1',
              postCoordinate: _coordA,
              postEventId: _eventA,
            ),
          );
          async.flushMicrotasks();

          expect(platform.updates.single.id, id);
          expect(platform.updates.single.phase, LiveActivityPhase.live);
          expect(platform.updates.single.coordinate, _coordA);
          expect(platform.updates.single.eventId, _eventA);
          expect(registrar.sent, isEmpty);

          async.elapse(const Duration(seconds: 5));
          platform.emit(PushTokenChanged(activityId: id, token: 'tok-1'));
          async.flushMicrotasks();

          expect(registrar.sent, [
            LiveActivityRegistration.forPost(
              activityId: id,
              ownerPubkey: _ownerA,
              activityPushToken: 'tok-1',
              postCoordinate: _coordA,
              postEventIds: const [_eventA],
              postedAt: postedAt,
              showFirstRunNote: true,
            ),
          ]);
        });
      });

      test('a token for an id start has not returned yet is buffered and '
          'applied when it returns', () {
        fakeAsync((async) {
          final repo = build(async);
          final gate = Completer<String>();
          platform.startGates.add(gate);
          repo.startPosting(
            key: 'draft-1',
            ownerPubkey: _ownerA,
            thumbnail: Future.value(),
          );
          async.flushMicrotasks();
          platform.emit(
            const PushTokenChanged(activityId: 'act-slow', token: 'early'),
          );
          async.flushMicrotasks();
          gate.complete('act-slow');
          async.flushMicrotasks();
          unawaited(
            repo.markLive(
              key: 'draft-1',
              postCoordinate: _coordA,
              postEventId: _eventA,
            ),
          );
          async.flushMicrotasks();

          expect(registrar.sent.single.activityId, 'act-slow');
          expect(registrar.sent.single.activityPushToken, 'early');
        });
      });

      test(
        'an identical token is a no-op and a rotated token re-registers',
        () {
          fakeAsync((async) {
            final repo = build(async);
            final id = live(async, repo);
            expect(registrar.sent, hasLength(1));

            platform.emit(PushTokenChanged(activityId: id, token: 'tok-1'));
            async.flushMicrotasks();
            expect(registrar.sent, hasLength(1));

            platform.emit(PushTokenChanged(activityId: id, token: 'tok-2'));
            async.flushMicrotasks();
            expect(registrar.active, hasLength(2));
            expect(registrar.sent.last.activityPushToken, 'tok-2');
          });
        },
      );

      test('retryLater is retried with backoff 15 s, 30 s, 60 s, 120 s, then '
          'every 300 s until the window ends', () {
        fakeAsync((async) {
          registrar.fallback = LiveActivityRegistrarResult.retryLater;
          final repo = build(async);
          live(async, repo);
          expect(registrar.sent, hasLength(1));

          void after(int seconds, int expected) {
            async.elapse(Duration(seconds: seconds));
            expect(registrar.sent, hasLength(expected));
          }

          after(14, 1);
          after(1, 2);
          after(29, 2);
          after(1, 3);
          after(60, 4);
          after(119, 4);
          after(1, 5);
          after(299, 5);
          after(1, 6);
          after(3000, 16); // every 300 s up to 3525 s
          async.elapse(const Duration(hours: 2));
          expect(registrar.sent, hasLength(16));
          expect(platform.ends, isEmpty);
        });
      });

      test('skipped is neither retried nor reported', () {
        fakeAsync((async) {
          registrar.fallback = LiveActivityRegistrarResult.skipped;
          final repo = build(async);
          live(async, repo);
          async.elapse(const Duration(hours: 1));

          expect(registrar.sent, hasLength(1));
          expect(reported, isEmpty);
          expect(platform.ends, isEmpty);
        });
      });

      test('failed is reported (site: register) and not retried', () {
        fakeAsync((async) {
          registrar.fallback = LiveActivityRegistrarResult.failed;
          final repo = build(async);
          live(async, repo);
          async.elapse(const Duration(hours: 1));

          expect(registrar.sent, hasLength(1));
          expect(reported, hasLength(1));
          expect(reported.single.site, 'register');
          expect(reported.single.error, isA<Exception>());
          expect(reported.single.error.toString(), contains('act-1'));
          expect(platform.ends, isEmpty);
        });
      });

      test('a registrar that throws is reported (site: register) and not '
          'retried', () {
        fakeAsync((async) {
          registrar.error = StateError('signer exploded');
          final repo = build(async);
          live(async, repo);
          async.elapse(const Duration(hours: 1));

          expect(registrar.sent, hasLength(1));
          expect(reported.single.site, 'register');
          expect(reported.single.error, isA<StateError>());
        });
      });

      group('an ended registration waits for an in-flight active send and '
          'cancels its retries first', () {
        test('a pending retry is cancelled', () {
          fakeAsync((async) {
            registrar.queued.add(
              Future.value(LiveActivityRegistrarResult.uncertain),
            );
            final repo = build(async);
            live(async, repo);
            unawaited(repo.end(key: 'draft-1'));
            async.elapse(const Duration(hours: 1));

            expect(
              registrar.sent.map((r) => r.state),
              [
                LiveActivityRegistrationState.active,
                LiveActivityRegistrationState.ended,
              ],
            );
          });
        });

        test('an in-flight active send is awaited', () {
          fakeAsync((async) {
            final inFlight = Completer<LiveActivityRegistrarResult>();
            registrar.queued.add(inFlight.future);
            final repo = build(async);
            live(async, repo);
            unawaited(repo.end(key: 'draft-1'));
            async.flushMicrotasks();
            expect(registrar.sent, hasLength(1));

            inFlight.complete(LiveActivityRegistrarResult.uncertain);
            async.elapse(const Duration(hours: 1));

            expect(
              registrar.sent.map((r) => r.state),
              [
                LiveActivityRegistrationState.active,
                LiveActivityRegistrationState.ended,
              ],
            );
          });
        });
      });

      test('an activity whose only attempt was uncertainFailure counts as '
          'registered', () {
        fakeAsync((async) {
          registrar.queued.add(
            Future.value(LiveActivityRegistrarResult.uncertain),
          );
          final repo = build(async);
          live(async, repo);
          unawaited(repo.end(key: 'draft-1'));
          async.flushMicrotasks();

          expect(registrar.ended, hasLength(1));
        });
      });

      test('an activity whose only attempt was retryLater is not told it '
          'ended', () {
        fakeAsync((async) {
          registrar.queued.add(
            Future.value(LiveActivityRegistrarResult.retryLater),
          );
          final repo = build(async);
          live(async, repo);
          unawaited(repo.end(key: 'draft-1'));
          async.elapse(const Duration(hours: 1));

          expect(registrar.sent, hasLength(1));
        });
      });
    });

    group('echoes and state events', () {
      test('an app-initiated end does not send a second ended when its ended '
          'state event echoes back', () {
        fakeAsync((async) {
          final repo = build(async);
          final id = live(async, repo);
          unawaited(repo.end(key: 'draft-1'));
          async.flushMicrotasks();
          platform
            ..emit(
              ActivityStateChanged(
                activityId: id,
                state: LiveActivityState.ended,
              ),
            )
            ..emit(
              ActivityStateChanged(
                activityId: id,
                state: LiveActivityState.dismissed,
              ),
            )
            ..emit(PushTokenChanged(activityId: id, token: 'tok-late'));
          async.flushMicrotasks();

          expect(registrar.ended, hasLength(1));
          expect(registrar.active, hasLength(1));
        });
      });

      test('ActivityStateChanged dismissed for a tracked activity inside its '
          'window sends ended once and stops tracking, without calling '
          'platform.end (RF3)', () {
        fakeAsync((async) {
          final repo = build(async);
          final id = live(async, repo);
          for (var i = 0; i < 2; i++) {
            platform.emit(
              ActivityStateChanged(
                activityId: id,
                state: LiveActivityState.dismissed,
              ),
            );
          }
          async.flushMicrotasks();
          platform.emit(PushTokenChanged(activityId: id, token: 'tok-2'));
          async.flushMicrotasks();

          expect(registrar.ended, hasLength(1));
          expect(registrar.active, hasLength(1));
          expect(platform.ends, isEmpty);
        });
      });

      test('ActivityStateChanged ended stops tracking and sends nothing', () {
        fakeAsync((async) {
          final repo = build(async);
          final id = live(async, repo);
          platform.emit(
            ActivityStateChanged(
              activityId: id,
              state: LiveActivityState.ended,
            ),
          );
          async.flushMicrotasks();
          unawaited(repo.stopForPost(_coordA));
          async.flushMicrotasks();

          expect(registrar.ended, isEmpty);
          expect(platform.ends, isEmpty);
        });
      });

      test('stale is ignored', () {
        fakeAsync((async) {
          final repo = build(async);
          final id = live(async, repo);
          platform.emit(
            ActivityStateChanged(
              activityId: id,
              state: LiveActivityState.stale,
            ),
          );
          async.flushMicrotasks();
          expect(registrar.sent, hasLength(1));

          unawaited(repo.end(key: 'draft-1'));
          async.flushMicrotasks();
          expect(registrar.ended, hasLength(1));
        });
      });

      test('state events after the window end are ignored', () {
        fakeAsync((async) {
          final repo = build(async);
          final id = live(async, repo);
          async.elapse(const Duration(minutes: 61));
          platform.emit(
            ActivityStateChanged(
              activityId: id,
              state: LiveActivityState.dismissed,
            ),
          );
          async.flushMicrotasks();

          expect(registrar.ended, isEmpty);
          expect(platform.ends, isEmpty);
        });
      });

      test('state events for untracked activities are ignored', () {
        fakeAsync((async) {
          build(async);
          platform.emit(
            const ActivityStateChanged(
              activityId: 'stranger',
              state: LiveActivityState.dismissed,
            ),
          );
          async.flushMicrotasks();

          expect(registrar.sent, isEmpty);
          expect(platform.ends, isEmpty);
        });
      });
    });

    group('ending', () {
      test('end and stopForPost end immediately and send ended when '
          'registered', () {
        fakeAsync((async) {
          final repo = build(async);
          final first = live(async, repo);
          unawaited(repo.end(key: 'draft-1'));
          async.flushMicrotasks();
          expect(platform.ends, [(id: first, immediate: true)]);
          expect(registrar.ended.single.activityId, first);

          final second = live(async, repo, key: 'draft-2');
          unawaited(repo.stopForPost(_coordA));
          async.flushMicrotasks();
          expect(platform.ends.last, (id: second, immediate: true));
          expect(registrar.ended.last.activityId, second);
        });
      });

      test('end sends nothing when the activity never registered', () {
        fakeAsync((async) {
          final repo = build(async);
          final id = started(async, repo);
          unawaited(repo.end(key: 'draft-1'));
          async.flushMicrotasks();

          expect(platform.endedIds, [id]);
          expect(registrar.sent, isEmpty);
        });
      });

      test('stopForPost ends an untracked listed activity with a replayed '
          'token and sends one ended registration', () {
        fakeAsync((async) {
          final repo = build(async);
          final startedAt = t0.subtract(const Duration(minutes: 9));
          platform
            ..emit(const PushTokenChanged(activityId: 'cold', token: 'tok'))
            ..running = [
              _running(
                'cold',
                owner: _ownerA,
                startedAt: startedAt,
                coordinate: _coordA,
                eventId: _eventA,
              ),
              _running('other', owner: _ownerA, startedAt: t0),
            ];
          async.flushMicrotasks();
          unawaited(repo.stopForPost(_coordA));
          async.flushMicrotasks();

          expect(platform.ends, [(id: 'cold', immediate: true)]);
          expect(registrar.sent, [
            LiveActivityRegistration.forPost(
              activityId: 'cold',
              ownerPubkey: _ownerA,
              activityPushToken: 'tok',
              postCoordinate: _coordA,
              postEventIds: const [_eventA],
              postedAt: startedAt,
              showFirstRunNote: false,
            ).ended(),
          ]);
        });
      });

      test('stopForPost ends an untracked listed activity without a token on '
          'the device only', () {
        fakeAsync((async) {
          final repo = build(async);
          platform.running = [
            _running(
              'cold',
              owner: _ownerA,
              startedAt: t0,
              coordinate: _coordA,
              eventId: _eventA,
            ),
            _running('other', owner: _ownerA, startedAt: t0),
          ];
          unawaited(repo.stopForPost(_coordA));
          async.flushMicrotasks();

          expect(platform.ends, [(id: 'cold', immediate: true)]);
          expect(registrar.sent, isEmpty);
        });
      });

      test('setToggleOn(false) ends every running activity and tells the '
          'server', () {
        fakeAsync((async) {
          final repo = build(async);
          final id = live(async, repo);
          platform.running = [
            _running(id, owner: _ownerA, startedAt: t0),
            _running('orphan', owner: _ownerA, startedAt: t0),
          ];
          unawaited(repo.setToggleOn(false));
          async.flushMicrotasks();

          expect(platform.endedIds, [id, 'orphan']);
          expect(registrar.ended.single.activityId, id);
          expect(repo.isToggleOn, isFalse);
          expect(prefs.getBool(_enabledKey), isFalse);
        });
      });

      test('setToggleOn(true) neither starts nor adopts an activity (RF2)', () {
        fakeAsync((async) {
          final repo = build(async);
          unawaited(repo.setToggleOn(false));
          async.flushMicrotasks();
          // An adoptable activity: the current owner's, live, inside its
          // window, with a post identity and a replayed token.
          platform
            ..emit(const PushTokenChanged(activityId: 'cold', token: 'tok'))
            ..running = [
              _running(
                'cold',
                owner: _ownerA,
                startedAt: nowOf(async).subtract(const Duration(minutes: 10)),
                coordinate: _coordA,
                eventId: _eventA,
              ),
            ];
          async.flushMicrotasks();
          platform.calls.clear();
          unawaited(repo.setToggleOn(true));
          async.elapse(const Duration(minutes: 1));

          expect(repo.isToggleOn, isTrue);
          expect(platform.calls, isNot(contains('start')));
          expect(registrar.sent, isEmpty);
        });
      });

      test("endLocally ends only that owner's activities, cancels their "
          'retries, and sends nothing (RF1)', () {
        fakeAsync((async) {
          registrar.fallback = LiveActivityRegistrarResult.uncertain;
          final repo = build(async);
          final id = live(async, repo);
          platform.running = [
            _running(id, owner: _ownerA, startedAt: t0),
            _running('b-act', owner: _ownerB, startedAt: t0),
            _running('a-orphan', owner: _ownerA, startedAt: t0),
          ];
          unawaited(repo.endLocally(ownerPubkey: _ownerA));
          async.elapse(const Duration(hours: 1));

          expect(platform.endedIds, [id, 'a-orphan']);
          expect(registrar.sent, hasLength(1));
          expect(registrar.ended, isEmpty);
        });
      });

      test("endLocally leaves another owner's tracked activity alone", () {
        fakeAsync((async) {
          final repo = build(async);
          final id = live(async, repo, owner: _ownerB);
          unawaited(repo.endLocally(ownerPubkey: _ownerA));
          async.flushMicrotasks();
          unawaited(repo.end(key: 'draft-1'));
          async.flushMicrotasks();

          expect(platform.endedIds, [id]);
          expect(registrar.ended.single.activityId, id);
        });
      });
    });

    group('sweep', () {
      test('sweep ends, on the device, listed activities of another owner, '
          'all of them when signed out, and any past startedAt + 90 min', () {
        fakeAsync((async) {
          final repo = build(async);
          async.elapse(const Duration(hours: 3));
          final now = nowOf(async);
          platform.running = [
            _running(
              'b-recent',
              owner: _ownerB,
              startedAt: now.subtract(const Duration(minutes: 5)),
              coordinate: _coordB,
              eventId: 'event-b',
            ),
            _running(
              'a-old',
              owner: _ownerA,
              startedAt: now.subtract(const Duration(minutes: 91)),
              state: LiveActivityState.ended,
              coordinate: _coordA,
              eventId: _eventA,
            ),
            _running(
              'a-summary',
              owner: _ownerA,
              startedAt: now.subtract(const Duration(minutes: 80)),
              state: LiveActivityState.ended,
              coordinate: _coordA,
              eventId: _eventA,
            ),
          ];
          unawaited(repo.sweep(currentOwnerPubkey: _ownerA));
          async.flushMicrotasks();

          expect(platform.endedIds, ['b-recent', 'a-old']);
          expect(registrar.sent, isEmpty);
        });
      });

      test('sweep times a tracked activity from when its post went live, '
          'not from when its upload started', () {
        fakeAsync((async) {
          final repo = build(async);
          final id = started(async, repo);
          platform.emit(PushTokenChanged(activityId: id, token: 'tok-1'));
          // A long upload: the post only goes live 80 minutes in.
          async.elapse(const Duration(minutes: 80));
          unawaited(
            repo.markLive(
              key: 'draft-1',
              postCoordinate: _coordA,
              postEventId: _eventA,
            ),
          );
          async.elapse(const Duration(minutes: 20));
          platform.running = [
            _running(
              id,
              owner: _ownerA,
              startedAt: t0,
              coordinate: _coordA,
              eventId: _eventA,
            ),
          ];
          unawaited(repo.sweep(currentOwnerPubkey: _ownerA));
          async.flushMicrotasks();
          expect(platform.endedIds, isEmpty);

          // Window end (live + 60) plus the 30-minute summary has passed.
          async.elapse(const Duration(minutes: 70));
          unawaited(repo.sweep(currentOwnerPubkey: _ownerA));
          async.flushMicrotasks();
          expect(platform.endedIds, [id]);
        });
      });

      test('sweep ends everything listed when signed out, telling no one', () {
        fakeAsync((async) {
          final repo = build(async);
          final id = live(async, repo);
          platform.running = [
            _running(
              id,
              owner: _ownerA,
              startedAt: t0,
              coordinate: _coordA,
              eventId: _eventA,
            ),
          ];
          unawaited(repo.sweep(currentOwnerPubkey: null));
          async.flushMicrotasks();
          unawaited(repo.end(key: 'draft-1'));
          async.flushMicrotasks();

          expect(platform.endedIds, [id]);
          expect(registrar.ended, isEmpty);
        });
      });

      test("sweep re-adopts the current owner's untracked live activity", () {
        fakeAsync((async) {
          final repo = build(async);
          async.elapse(const Duration(hours: 1));
          final startedAt = nowOf(
            async,
          ).subtract(const Duration(minutes: 20));
          platform
            ..emit(const PushTokenChanged(activityId: 'kept', token: 'tok'))
            ..running = [
              _running(
                'kept',
                owner: _ownerA,
                startedAt: startedAt,
                coordinate: _coordA,
                eventId: _eventA,
              ),
            ];
          async.flushMicrotasks();
          unawaited(repo.sweep(currentOwnerPubkey: _ownerA));
          async.flushMicrotasks();

          expect(registrar.sent, [
            LiveActivityRegistration.forPost(
              activityId: 'kept',
              ownerPubkey: _ownerA,
              activityPushToken: 'tok',
              postCoordinate: _coordA,
              postEventIds: const [_eventA],
              postedAt: startedAt,
              showFirstRunNote: false,
            ),
          ]);
          expect(platform.ends, isEmpty);

          unawaited(repo.stopForPost(_coordA));
          async.flushMicrotasks();
          expect(registrar.ended.single.activityId, 'kept');
        });
      });

      test('sweep re-adopts a stale activity and registers once its token '
          'arrives', () {
        fakeAsync((async) {
          final repo = build(async);
          platform.running = [
            _running(
              'stale',
              owner: _ownerA,
              startedAt: t0,
              state: LiveActivityState.stale,
              coordinate: _coordA,
              eventId: _eventA,
            ),
          ];
          unawaited(repo.sweep(currentOwnerPubkey: _ownerA));
          async.flushMicrotasks();
          expect(registrar.sent, isEmpty);

          platform.emit(
            const PushTokenChanged(activityId: 'stale', token: 't'),
          );
          async.flushMicrotasks();
          expect(registrar.sent.single.activityId, 'stale');
          expect(registrar.sent.single.postedAt, t0);
        });
      });

      test("sweep ends the current owner's untracked live activity when the "
          'toggle or the feature is off or its window has passed', () {
        fakeAsync((async) {
          final repo = build(async);
          async.elapse(const Duration(hours: 2));
          final now = nowOf(async);
          RunningLiveActivity candidate(String id, Duration age) => _running(
            id,
            owner: _ownerA,
            startedAt: now.subtract(age),
            coordinate: _coordA,
            eventId: _eventA,
          );

          platform.running = [
            candidate('late', const Duration(minutes: 61)),
          ];
          unawaited(repo.sweep(currentOwnerPubkey: _ownerA));
          async.flushMicrotasks();

          repo.featureEnabled = false;
          platform.running = [candidate('flagged', const Duration(minutes: 5))];
          unawaited(repo.sweep(currentOwnerPubkey: _ownerA));
          async.flushMicrotasks();

          repo.featureEnabled = true;
          unawaited(prefs.setBool(_enabledKey, false));
          platform.running = [candidate('toggled', const Duration(minutes: 5))];
          unawaited(repo.sweep(currentOwnerPubkey: _ownerA));
          async.flushMicrotasks();

          expect(platform.endedIds, ['late', 'flagged', 'toggled']);
          expect(registrar.sent, isEmpty);
        });
      });

      test('sweep leaves an untracked dismissed activity to the system', () {
        fakeAsync((async) {
          final repo = build(async);
          platform.running = [
            _running(
              'gone',
              owner: _ownerA,
              startedAt: t0,
              state: LiveActivityState.dismissed,
              coordinate: _coordA,
              eventId: _eventA,
            ),
          ];
          unawaited(repo.sweep(currentOwnerPubkey: _ownerA));
          async.flushMicrotasks();

          expect(platform.ends, isEmpty);
          expect(registrar.sent, isEmpty);
        });
      });

      test('sweep ends an untracked activity with no identity that started '
          'over 15 min ago', () {
        fakeAsync((async) {
          final repo = build(async);
          async.elapse(const Duration(hours: 1));
          final now = nowOf(async);
          platform.running = [
            _running(
              'stuck',
              owner: _ownerA,
              startedAt: now.subtract(const Duration(minutes: 16)),
            ),
            _running(
              'fresh',
              owner: _ownerA,
              startedAt: now.subtract(const Duration(minutes: 5)),
            ),
          ];
          unawaited(repo.sweep(currentOwnerPubkey: _ownerA));
          async.flushMicrotasks();

          expect(platform.endedIds, ['stuck']);
        });
      });

      test('sweep leaves a tracked activity of the current owner alone', () {
        fakeAsync((async) {
          final repo = build(async);
          final id = live(async, repo);
          platform.running = [
            _running(
              id,
              owner: _ownerA,
              startedAt: t0,
              coordinate: _coordA,
              eventId: _eventA,
            ),
          ];
          unawaited(repo.sweep(currentOwnerPubkey: _ownerA));
          async.flushMicrotasks();

          expect(platform.ends, isEmpty);
          expect(registrar.sent, hasLength(1));
        });
      });

      test('sweep does not re-adopt an activity ended while it was '
          'listing', () {
        fakeAsync((async) {
          final repo = build(async);
          platform.running = [
            _running(
              'leaving',
              owner: _ownerA,
              startedAt: t0,
              coordinate: _coordA,
              eventId: _eventA,
            ),
          ];
          unawaited(repo.sweep(currentOwnerPubkey: _ownerA));
          unawaited(repo.endLocally(ownerPubkey: _ownerA));
          async.flushMicrotasks();
          platform.emit(
            const PushTokenChanged(activityId: 'leaving', token: 'tok'),
          );
          async.flushMicrotasks();

          expect(platform.endedIds, ['leaving']);
          expect(registrar.sent, isEmpty);
        });
      });

      test('sweep does nothing when list() fails', () {
        fakeAsync((async) {
          platform.listError = StateError('list failed');
          final repo = build(async);
          unawaited(repo.sweep(currentOwnerPubkey: null));
          async.flushMicrotasks();

          expect(platform.ends, isEmpty);
        });
      });
    });

    group('edits', () {
      test('noteEdited re-registers with the new id appended', () {
        fakeAsync((async) {
          final repo = build(async);
          live(async, repo);
          unawaited(
            repo.noteEdited(postCoordinate: _coordB, newEventId: 'event-x'),
          );
          async.flushMicrotasks();
          expect(registrar.sent, hasLength(1));

          unawaited(
            repo.noteEdited(postCoordinate: _coordA, newEventId: 'event-2'),
          );
          async.flushMicrotasks();
          expect(registrar.sent, hasLength(2));
          expect(registrar.sent.last.postEventIds, [_eventA, 'event-2']);

          unawaited(
            repo.noteEdited(postCoordinate: _coordA, newEventId: 'event-2'),
          );
          async.flushMicrotasks();
          expect(registrar.sent, hasLength(2));
        });
      });
    });

    group('per-post queries', () {
      test('isRunningFor and postedAtFor answer from tracking', () {
        fakeAsync((async) {
          final repo = build(async);
          async.elapse(const Duration(minutes: 3));
          live(async, repo);
          platform.calls.clear();
          bool? running;
          DateTime? postedAt;
          unawaited(repo.isRunningFor(_coordA).then((v) => running = v));
          unawaited(repo.postedAtFor(_coordA).then((v) => postedAt = v));
          async.flushMicrotasks();

          expect(running, isTrue);
          expect(postedAt, t0.add(const Duration(minutes: 3)));
          expect(platform.calls, isNot(contains('list')));
        });
      });

      test('isRunningFor stops answering from tracking at the window end, '
          'when only the summary shows', () {
        fakeAsync((async) {
          final repo = build(async);
          final id = live(async, repo);
          async.elapse(const Duration(minutes: 60));
          platform.running = [
            _running(
              id,
              owner: _ownerA,
              startedAt: t0,
              state: LiveActivityState.ended,
              coordinate: _coordA,
              eventId: _eventA,
            ),
          ];
          bool? running;
          unawaited(repo.isRunningFor(_coordA).then((v) => running = v));
          async.flushMicrotasks();

          expect(running, isFalse);
        });
      });

      test('isRunningFor and postedAtFor fall back to list() before the '
          'sweep', () {
        fakeAsync((async) {
          final repo = build(async);
          final startedAt = t0.subtract(const Duration(minutes: 7));
          platform.running = [
            _running(
              'cold',
              owner: _ownerA,
              startedAt: startedAt,
              state: LiveActivityState.stale,
              coordinate: _coordA,
              eventId: _eventA,
            ),
            _running(
              'summary',
              owner: _ownerA,
              startedAt: t0,
              state: LiveActivityState.ended,
              coordinate: _coordB,
              eventId: 'event-b',
            ),
          ];
          final answers = <String, Object?>{};
          void ask(String coordinate) {
            unawaited(
              repo
                  .isRunningFor(coordinate)
                  .then((v) => answers['running $coordinate'] = v),
            );
            unawaited(
              repo
                  .postedAtFor(coordinate)
                  .then((v) => answers['postedAt $coordinate'] = v),
            );
          }

          ask(_coordA);
          ask(_coordB);
          ask('34236:x:none');
          async.flushMicrotasks();

          expect(answers, {
            'running $_coordA': true,
            'postedAt $_coordA': startedAt,
            'running $_coordB': false,
            'postedAt $_coordB': t0,
            'running 34236:x:none': false,
            'postedAt 34236:x:none': null,
          });
        });
      });

      test('isRunningFor and postedAtFor answer no when list() fails', () {
        fakeAsync((async) {
          platform.listError = StateError('list failed');
          final repo = build(async);
          bool? running;
          DateTime? postedAt = t0;
          unawaited(repo.isRunningFor(_coordA).then((v) => running = v));
          unawaited(repo.postedAtFor(_coordA).then((v) => postedAt = v));
          async.flushMicrotasks();

          expect(running, isFalse);
          expect(postedAt, isNull);
        });
      });
    });

    group('system switch', () {
      test('isSystemEnabled reports the platform switch and treats an error '
          'as off', () {
        fakeAsync((async) {
          final repo = build(async);
          final answers = <bool>[];
          unawaited(repo.isSystemEnabled().then(answers.add));
          async.flushMicrotasks();
          platform.enabledError = StateError('no answer');
          unawaited(repo.isSystemEnabled().then(answers.add));
          async.flushMicrotasks();

          expect(answers, [true, false]);
        });
      });

      test('systemEnabledChanges forwards enablement events', () {
        fakeAsync((async) {
          final repo = build(async);
          final seen = <bool>[];
          repo.systemEnabledChanges.listen(seen.add);
          platform
            ..emit(const EnablementChanged(enabled: false))
            ..emit(const EnablementChanged(enabled: true));
          async.flushMicrotasks();

          expect(seen, [false, true]);
        });
      });
    });

    group('platform failures', () {
      test('a failed list() still lets the new activity start', () {
        fakeAsync((async) {
          platform.listError = StateError('list failed');
          final repo = build(async);
          started(async, repo);

          expect(platform.calls, ['list', 'start']);
        });
      });

      test('a thumbnail that fails to load or write starts without one', () {
        fakeAsync((async) {
          final repo = build(async)
            ..startPosting(
              key: 'draft-1',
              ownerPubkey: _ownerA,
              thumbnail: Future.error(StateError('render failed')),
            );
          async.flushMicrotasks();
          platform.thumbnailError = StateError('disk full');
          repo.startPosting(
            key: 'draft-2',
            ownerPubkey: _ownerA,
            thumbnail: Future.value(Uint8List(4)),
          );
          async.flushMicrotasks();

          expect(platform.startRequests.map((r) => r.thumb), [null, null]);
          expect(platform.startedIds, hasLength(2));
        });
      });

      test('failed update and end calls do not stop registration or '
          'ending', () {
        fakeAsync((async) {
          platform
            ..updateError = StateError('update failed')
            ..endError = StateError('end failed');
          final repo = build(async);
          final id = live(async, repo);
          expect(registrar.active.single.activityId, id);

          Object? thrown;
          unawaited(
            repo.end(key: 'draft-1').catchError((Object e) {
              thrown = e;
            }),
          );
          async.flushMicrotasks();

          expect(thrown, isNull);
          expect(platform.endedIds, [id]);
          expect(registrar.ended.single.activityId, id);
        });
      });

      test('a failed ended registration is reported (site: register)', () {
        fakeAsync((async) {
          final repo = build(async);
          live(async, repo);
          registrar.fallback = LiveActivityRegistrarResult.failed;
          unawaited(repo.end(key: 'draft-1'));
          async.flushMicrotasks();

          expect(registrar.ended, hasLength(1));
          expect(reported.single.site, 'register');
        });
      });

      test('an ended registration asked to retry later is not retried', () {
        fakeAsync((async) {
          final repo = build(async);
          live(async, repo);
          registrar.fallback = LiveActivityRegistrarResult.retryLater;
          unawaited(repo.end(key: 'draft-1'));
          async.elapse(const Duration(hours: 1));

          expect(registrar.ended, hasLength(1));
          expect(reported, isEmpty);
        });
      });
    });

    group('dispose', () {
      test('dispose cancels retry timers and stops listening', () {
        fakeAsync((async) {
          registrar.fallback = LiveActivityRegistrarResult.retryLater;
          final repo = build(async);
          live(async, repo);
          expect(registrar.sent, hasLength(1));

          unawaited(repo.dispose());
          async.elapse(const Duration(hours: 1));

          expect(platform.hasListener, isFalse);
          expect(registrar.sent, hasLength(1));
          expect(platform.ends, isEmpty);
        });
      });

      test('a start that returns after dispose is ended, and nothing starts '
          'or sweeps afterwards', () {
        fakeAsync((async) {
          final repo = build(async);
          final gate = Completer<String>();
          platform.startGates.add(gate);
          repo.startPosting(
            key: 'draft-1',
            ownerPubkey: _ownerA,
            thumbnail: Future.value(),
          );
          async.flushMicrotasks();

          unawaited(repo.dispose());
          async.flushMicrotasks();
          gate.complete('act-late');
          async.flushMicrotasks();
          expect(platform.endedIds, ['act-late']);

          platform.calls.clear();
          repo.startPosting(
            key: 'draft-2',
            ownerPubkey: _ownerA,
            thumbnail: Future.value(),
          );
          unawaited(repo.sweep(currentOwnerPubkey: _ownerA));
          unawaited(repo.dispose());
          async.flushMicrotasks();
          expect(platform.calls, isEmpty);
        });
      });
    });
  });
}
