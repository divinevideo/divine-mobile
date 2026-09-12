// ABOUTME: Tests how RelayPool reports the way each one-shot query ended.
// ABOUTME: End reasons, cap detection, NIP-67 hints and the completion line.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:nostr_sdk/relay/client_connected.dart';
import 'package:nostr_sdk/relay/relay_info.dart';

/// Relay that records what it was sent and only answers when the test says so.
class _ScriptedRelay extends Relay {
  _ScriptedRelay(String url, {int? maxLimit}) : super(url, RelayStatus(url)) {
    if (maxLimit != null) {
      info = RelayInfo('', '', '', '', const [], '', '', maxLimit: maxLimit);
    }
  }

  final List<List<dynamic>> sentMessages = [];

  /// When false, [send] reports failure the way a dead socket does.
  bool sendSucceeds = true;

  /// When set, a `REQ` write blocks until the gate completes, which holds the
  /// pool's fan-out open.
  Completer<void>? reqGate;

  /// When set, a `CLOSE` write blocks until the gate completes, which holds
  /// the pool part-way through settling this relay's `EOSE`.
  Completer<void>? closeGate;

  /// The id of the NIP-42 `AUTH` event the pool last sent this relay.
  String? capturedAuthEventId;

  @override
  Future<bool> doConnect() async {
    relayStatus.connected = ClientConnected.connected;
    return true;
  }

  @override
  Future<void> disconnect() async {
    relayStatus.connected = ClientConnected.disconnect;
  }

  @override
  Future<bool> send(
    List<dynamic> message, {
    bool queueIfFailed = true,
    bool skipReconnect = false,
    DateTime? deadline,
  }) async {
    sentMessages.add(message);
    final payload = message.length > 1 ? message[1] : null;
    if (message.firstOrNull == 'AUTH' && payload is Map) {
      capturedAuthEventId = payload['id'] as String?;
    }
    final gate = switch (message.firstOrNull) {
      'REQ' => reqGate,
      'CLOSE' => closeGate,
      _ => null,
    };
    if (gate != null) await gate.future;
    return sendSucceeds;
  }

  Future<void> deliver(List<dynamic> json) async {
    final handler = onMessage;
    expect(handler, isNotNull, reason: 'RelayPool did not wire onMessage');
    final dynamic result = handler!(this, json);
    if (result is Future) await result;
  }
}

/// A relay that stays connected yet reads as silent, so the pool force-cycles
/// it as a half-open zombie; that force-cycle stays in flight until
/// [reconnectGate] completes.
class _ZombieRelay extends RelayBase {
  _ZombieRelay(String url) : super(url, RelayStatus(url));

  final reconnectGate = Completer<bool>();

  /// Force-cycles the pool has started on this relay.
  int reconnectsStarted = 0;

  @override
  Future<bool> doConnect() async {
    relayStatus.connected = ClientConnected.connected;
    return true;
  }

  @override
  Future<void> disconnect() async {
    relayStatus.connected = ClientConnected.disconnect;
  }

  @override
  Future<bool> send(
    List<dynamic> message, {
    bool queueIfFailed = true,
    bool skipReconnect = false,
    DateTime? deadline,
  }) async => true;

  @override
  bool isSilentSince(DateTime since) => true;

  @override
  Future<bool> forceReconnect() {
    reconnectsStarted++;
    return reconnectGate.future;
  }
}

/// Hides every event from the caller, the way a block list does.
class _BlockEverything implements EventFilter {
  @override
  bool check(Event e) => true;
}

/// Verify worker that turns down the events whose ids it holds, the way the
/// verify isolate turns down a forged signature.
class _VerifyWorker implements EventVerifyWorker {
  final Set<String> rejects = {};

  @override
  Future<bool> verify(Map<String, dynamic> eventJson) async =>
      !rejects.contains(eventJson['id']);

  @override
  void close() {}
}

const _privateKey =
    '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';

const _queryId = 'outcome-query';

Matcher _summary({
  required String url,
  required int oldestCreatedAt,
  required bool capped,
}) => isA<QueryRelaySummary>()
    .having((summary) => summary.url, 'url', url)
    .having(
      (summary) => summary.oldestCreatedAt,
      'oldestCreatedAt',
      oldestCreatedAt,
    )
    .having((summary) => summary.capped, 'capped', capped);

void main() {
  group('RelayPool query outcome', () {
    late List<RelayDiagnostic> diagnostics;
    late Nostr nostr;
    var eventNumber = 0;

    Nostr newNostr({List<EventFilter> eventFilters = const []}) => Nostr(
      LocalNostrSigner(_privateKey),
      eventFilters,
      (url) => RelayBase(url, RelayStatus(url)),
      diagnosticsSink: diagnostics.add,
    );

    setUp(() {
      diagnostics = [];
      nostr = newNostr();
    });

    List<RelayDiagnostic> completionLines() => [
      for (final entry in diagnostics)
        if (entry.site == RelayDiagnosticSite.queryCompletion) entry,
    ];

    Future<_ScriptedRelay> addRelay(String url, {int? maxLimit}) async {
      final relay = _ScriptedRelay(url, maxLimit: maxLimit);
      expect(await nostr.relayPool.add(relay), isTrue);
      return relay;
    }

    /// Runs the query's fan-out, then hands back the completer its outcome
    /// lands in once the pool completes the query.
    Future<Completer<QueryOutcome>> startQuery(
      List<Map<String, dynamic>> filters, {
      void Function(Event event)? onEvent,
    }) async {
      final outcome = Completer<QueryOutcome>();
      await nostr.relayPool.query(
        filters,
        onEvent ?? (_) {},
        id: _queryId,
        onOutcome: outcome.complete,
      );
      return outcome;
    }

    Future<Event> signedEvent({
      int kind = EventKind.textNote,
      List<List<String>> tags = const [],
      int? createdAt,
    }) async {
      final pubkey = await nostr.ensurePublicKey();
      final event = await nostr.nostrSigner.signEvent(
        Event(
          pubkey,
          kind,
          tags,
          'outcome-event-${eventNumber++}',
          createdAt: createdAt,
        ),
      );
      return event!;
    }

    /// Sends [relay]'s text notes for the query, one per entry of
    /// [createdAts].
    Future<void> sendEventsAt(
      _ScriptedRelay relay,
      List<int> createdAts,
    ) async {
      for (final createdAt in createdAts) {
        final event = await signedEvent(createdAt: createdAt);
        await relay.deliver(['EVENT', _queryId, event.toJson()]);
      }
    }

    Future<void> sendEvents(
      _ScriptedRelay relay,
      int count, {
      int kind = EventKind.textNote,
    }) async {
      for (var i = 0; i < count; i++) {
        final event = await signedEvent(kind: kind);
        await relay.deliver(['EVENT', _queryId, event.toJson()]);
      }
    }

    group('endedBy', () {
      test('is complete when every relay sends EOSE', () async {
        final first = await addRelay('wss://first.example');
        final second = await addRelay('wss://second.example');
        final outcome = await startQuery([
          {
            'kinds': [1],
            'limit': 10,
          },
        ]);

        await first.deliver(['EOSE', _queryId]);
        await second.deliver(['EOSE', _queryId]);

        expect((await outcome.future).endedBy, QueryEnd.complete);
      });

      test('is settledEarly when the settle window releases a silent '
          'relay', () async {
        final answering = await addRelay('wss://answers.example');
        await addRelay('wss://never-answers.example');
        final outcome = await startQuery([
          {
            'kinds': [1],
            'limit': 10,
          },
        ]);

        await answering.deliver(['EOSE', _queryId]);

        expect((await outcome.future).endedBy, QueryEnd.settledEarly);
      });

      test('is relayClosed when a relay sends CLOSED', () async {
        final refusing = await addRelay('wss://refuses.example');
        final outcome = await startQuery([
          {
            'kinds': [1],
            'limit': 10,
          },
        ]);

        await refusing.deliver([
          'CLOSED',
          _queryId,
          'error: too many concurrent REQs',
        ]);

        expect((await outcome.future).endedBy, QueryEnd.relayClosed);
      });

      test('is socketDropped when a relay socket drops', () async {
        final dropping = await addRelay('wss://drops.example');
        final outcome = await startQuery([
          {
            'kinds': [1],
            'limit': 10,
          },
        ]);

        dropping.onError('socket closed', reconnect: true);

        expect((await outcome.future).endedBy, QueryEnd.socketDropped);
      });

      test('is noRelay, delivered as the fan-out ends, when no relay took '
          'the REQ', () async {
        final unreachable = await addRelay('wss://send-fails.example');
        unreachable.sendSucceeds = false;

        final outcome = await startQuery([
          {
            'kinds': [1],
            'limit': 10,
          },
        ]);

        expect(
          outcome.isCompleted,
          isTrue,
          reason:
              'nothing can answer, so the pool completes the query as its '
              'fan-out ends',
        );
        expect((await outcome.future).endedBy, QueryEnd.noRelay);
      });

      test('is noRelay when the pool has no relay to ask', () async {
        final outcome = await startQuery([
          {
            'kinds': [1],
          },
        ]);

        expect((await outcome.future).endedBy, QueryEnd.noRelay);
      });

      test('a dropped socket outranks a CLOSED and an EOSE', () async {
        final answering = await addRelay('wss://answers.example');
        final refusing = await addRelay('wss://refuses.example');
        final dropping = await addRelay('wss://drops.example');
        final outcome = await startQuery([
          {
            'kinds': [1],
            'limit': 10,
          },
        ]);

        await answering.deliver(['EOSE', _queryId]);
        await refusing.deliver([
          'CLOSED',
          _queryId,
          'error: too many concurrent REQs',
        ]);
        dropping.onError('socket closed', reconnect: true);

        expect((await outcome.future).endedBy, QueryEnd.socketDropped);
      });

      test('a CLOSED outranks a relay the settle window released', () async {
        final answering = await addRelay('wss://answers.example');
        final refusing = await addRelay('wss://refuses.example');
        await addRelay('wss://never-answers.example');
        final outcome = await startQuery([
          {
            'kinds': [1],
            'limit': 10,
          },
        ]);

        await answering.deliver(['EOSE', _queryId]);
        await refusing.deliver([
          'CLOSED',
          _queryId,
          'error: too many concurrent REQs',
        ]);

        expect((await outcome.future).endedBy, QueryEnd.relayClosed);
      });

      test('an EOSE whose CLOSE is still being written counts as an '
          'answer', () async {
        final slow = await addRelay('wss://slow-to-close.example');
        slow.closeGate = Completer<void>();
        final fast = await addRelay('wss://fast.example');
        final outcome = await startQuery([
          {
            'kinds': [1],
            'limit': 10,
          },
        ]);

        // The pool forgets `slow`'s query the moment its EOSE lands, then
        // waits on the CLOSE write while `fast` completes the query.
        final slowEose = slow.deliver(['EOSE', _queryId]);
        await fast.deliver(['EOSE', _queryId]);

        expect(
          (await outcome.future).endedBy,
          QueryEnd.complete,
          reason:
              'both relays answered; a CLOSE still in flight does not '
              'make the slower one a dropped socket',
        );
        slow.closeGate!.complete();
        await slowEose;
      });

      test('is relayClosed when a relay whose NIP-42 gate shut never sent '
          'CLOSED', () async {
        final gated = await addRelay('wss://rejects-auth.example');
        final outcome = await startQuery([
          {
            'kinds': [1],
            'limit': 10,
          },
        ]);

        // The relay challenges us and refuses our AUTH event without ever
        // closing the query, so the pool stops waiting on it.
        await gated.deliver(['AUTH', 'test-challenge']);
        expect(gated.capturedAuthEventId, isNotNull);
        await gated.deliver([
          'OK',
          gated.capturedAuthEventId,
          false,
          'invalid: bad signature',
        ]);

        expect((await outcome.future).endedBy, QueryEnd.relayClosed);
        expect(completionLines(), hasLength(1));
        expect(
          completionLines().single.message,
          contains(
            'not answered: wss://rejects-auth.example (closed: auth-required',
          ),
        );
      });

      test('a post-AUTH replay that answers replaces the earlier '
          'auth-required CLOSED', () async {
        final gated = await addRelay('wss://gated.example');
        final outcome = await startQuery([
          {
            'kinds': [1],
            'limit': 10,
          },
        ]);

        // The relay challenges us and refuses the REQ until we authenticate,
        // which parks the query for the post-AUTH replay.
        await gated.deliver(['AUTH', 'test-challenge']);
        await gated.deliver(['CLOSED', _queryId, 'auth-required: sign in']);
        expect(gated.capturedAuthEventId, isNotNull);
        await gated.deliver(['OK', gated.capturedAuthEventId, true, '']);
        expect(
          gated.sentMessages.where((message) => message.first == 'REQ'),
          hasLength(2),
          reason: 'the accepted AUTH replays the parked query',
        );

        await gated.deliver(['EOSE', _queryId]);

        expect(
          (await outcome.future).endedBy,
          QueryEnd.complete,
          reason: 'the answer to the replay supersedes the refusal',
        );
      });

      test('is socketDropped when a relay is being force-cycled as a '
          'zombie', () async {
        final answering = await addRelay('wss://answers.example');
        final zombie = _ZombieRelay('wss://zombie.example');
        expect(await nostr.relayPool.add(zombie), isTrue);
        final outcome = await startQuery([
          {
            'kinds': [1],
            'limit': 10,
          },
        ]);

        // Abandoning another query the zombie never answered starts the
        // force-cycle, which stays in flight until the gate completes.
        await nostr.relayPool.query(
          [
            {
              'kinds': [7],
            },
          ],
          (_) {},
          id: 'abandoned-query',
          targetRelays: [zombie.url],
          onComplete: () {},
        );
        nostr.relayPool.unsubscribe('abandoned-query');
        expect(zombie.reconnectsStarted, 1);

        await answering.deliver(['EOSE', _queryId]);

        expect((await outcome.future).endedBy, QueryEnd.socketDropped);
        expect(completionLines(), hasLength(1));
        expect(
          completionLines().single.message,
          contains('not answered: wss://zombie.example (dropped'),
        );
        zombie.reconnectGate.complete(true);
      });
    });

    group('possiblyCapped', () {
      test('is set when a relay returns as many events as the filter '
          'limit', () async {
        final relay = await addRelay('wss://relay.example');
        final outcome = await startQuery([
          {
            'kinds': [1],
            'limit': 2,
          },
        ]);

        await sendEvents(relay, 2);
        await relay.deliver(['EOSE', _queryId]);

        final result = await outcome.future;
        expect(result.endedBy, QueryEnd.complete);
        expect(result.possiblyCapped, isTrue);
      });

      test('is clear when a relay returns fewer events than the filter '
          'limit', () async {
        final relay = await addRelay('wss://relay.example');
        final outcome = await startQuery([
          {
            'kinds': [1],
            'limit': 3,
          },
        ]);

        await sendEvents(relay, 2);
        await relay.deliver(['EOSE', _queryId]);

        expect((await outcome.future).possiblyCapped, isFalse);
      });

      test('is set when a relay reaches its NIP-11 max_limit below the '
          'filter limit', () async {
        final relay = await addRelay('wss://relay.example', maxLimit: 2);
        final outcome = await startQuery([
          {
            'kinds': [1],
            'limit': 10,
          },
        ]);

        await sendEvents(relay, 2);
        await relay.deliver(['EOSE', _queryId]);

        expect((await outcome.future).possiblyCapped, isTrue);
      });

      test('is set when a relay reaches the filter limit below its NIP-11 '
          'max_limit', () async {
        final relay = await addRelay('wss://relay.example', maxLimit: 10);
        final outcome = await startQuery([
          {
            'kinds': [1],
            'limit': 2,
          },
        ]);

        await sendEvents(relay, 2);
        await relay.deliver(['EOSE', _queryId]);

        expect(
          (await outcome.future).possiblyCapped,
          isTrue,
          reason: 'the smaller of the filter limit and max_limit applies',
        );
      });

      test('with no filter limit, is set at a known max_limit', () async {
        final relay = await addRelay('wss://relay.example', maxLimit: 2);
        final outcome = await startQuery([
          {
            'kinds': [1],
          },
        ]);

        await sendEvents(relay, 2);
        await relay.deliver(['EOSE', _queryId]);

        expect((await outcome.future).possiblyCapped, isTrue);
      });

      test('with no filter limit, is clear below a known max_limit', () async {
        final relay = await addRelay('wss://relay.example', maxLimit: 5);
        final outcome = await startQuery([
          {
            'kinds': [1],
          },
        ]);

        await sendEvents(relay, 2);
        await relay.deliver(['EOSE', _queryId]);

        expect((await outcome.future).possiblyCapped, isFalse);
      });

      test('with no filter limit and no known max_limit, is set by any '
          'event', () async {
        final relay = await addRelay('wss://relay.example');
        final outcome = await startQuery([
          {
            'kinds': [1],
          },
        ]);

        await sendEvents(relay, 1);
        await relay.deliver(['EOSE', _queryId]);

        expect((await outcome.future).possiblyCapped, isTrue);
      });

      test('with no filter limit and no known max_limit, is clear with no '
          'events', () async {
        final relay = await addRelay('wss://relay.example');
        final outcome = await startQuery([
          {
            'kinds': [1],
          },
        ]);

        await relay.deliver(['EOSE', _queryId]);

        expect((await outcome.future).possiblyCapped, isFalse);
      });

      test('counts each event against the filter it matches', () async {
        final relay = await addRelay('wss://relay.example');
        final outcome = await startQuery([
          {
            'kinds': [EventKind.textNote],
            'limit': 2,
          },
          {
            'kinds': [EventKind.reaction],
            'limit': 5,
          },
        ]);

        await sendEvents(relay, 1);
        await sendEvents(relay, 2, kind: EventKind.reaction);
        await relay.deliver(['EOSE', _queryId]);

        expect(
          (await outcome.future).possiblyCapped,
          isFalse,
          reason:
              'three events arrived, but neither filter reached its own '
              'limit',
        );
      });

      test('is set when one of several filters reaches its limit', () async {
        final relay = await addRelay('wss://relay.example');
        final outcome = await startQuery([
          {
            'kinds': [EventKind.textNote],
            'limit': 2,
          },
          {
            'kinds': [EventKind.reaction],
            'limit': 5,
          },
        ]);

        await sendEvents(relay, 2);
        await sendEvents(relay, 1, kind: EventKind.reaction);
        await relay.deliver(['EOSE', _queryId]);

        expect((await outcome.future).possiblyCapped, isTrue);
      });

      test(
        'still counts events the block list hides from the caller',
        () async {
          nostr = newNostr(eventFilters: [_BlockEverything()]);
          final relay = await addRelay('wss://relay.example');
          final delivered = <Event>[];
          final outcome = await startQuery([
            {
              'kinds': [1],
              'limit': 1,
            },
          ], onEvent: delivered.add);

          await sendEvents(relay, 1);
          await relay.deliver(['EOSE', _queryId]);

          expect(
            delivered,
            isEmpty,
            reason: 'the block list hid the event from the caller',
          );
          expect(
            (await outcome.future).possiblyCapped,
            isTrue,
            reason: 'the event still took the one slot the filter asked for',
          );
        },
      );

      test('is set by an event outside the query filters', () async {
        final relay = await addRelay('wss://relay.example');
        final outcome = await startQuery([
          {
            'kinds': [EventKind.textNote],
            'limit': 10,
          },
        ]);

        await sendEvents(relay, 1, kind: EventKind.reaction);
        await relay.deliver(['EOSE', _queryId]);

        expect(
          (await outcome.future).possiblyCapped,
          isTrue,
          reason:
              'a relay that does not honour the filter may have spent its '
              'limit on events the query never asked for',
        );
      });

      test('is clear when only a cache relay reaches the filter '
          'limit', () async {
        final cache = _ScriptedRelay('wss://cache.example')
          ..relayStatus.relayType = RelayType.cache;
        expect(
          await nostr.relayPool.add(cache, relayType: RelayType.cache),
          isTrue,
        );
        final outcome = await startQuery([
          {
            'kinds': [1],
            'limit': 2,
          },
        ]);

        await sendEvents(cache, 2);
        await cache.deliver(['EOSE', _queryId]);

        expect(
          (await outcome.future).possiblyCapped,
          isFalse,
          reason:
              "a cache relay serves the pool's own copies of what relays "
              'sent, so reaching the limit says nothing a relay withheld',
        );
        expect(completionLines(), isEmpty);
      });
    });

    group('events outside the filters', () {
      test('are counted in the completion line', () async {
        final relay = await addRelay('wss://relay.example');
        final outcome = await startQuery([
          {
            'kinds': [EventKind.textNote],
            'limit': 10,
          },
        ]);

        await sendEvents(relay, 2, kind: EventKind.reaction);
        await relay.deliver(['EOSE', _queryId]);
        await outcome.future;

        expect(completionLines(), hasLength(1));
        expect(
          completionLines().single.message,
          contains(
            'wss://relay.example (events=0, 2 events outside the filter, '
            'capped)',
          ),
        );
      });

      test('keep a finish hint from confirming the relay exhaustive', () async {
        final relay = await addRelay('wss://relay.example');
        final outcome = await startQuery([
          {
            'kinds': [EventKind.textNote],
            'limit': 10,
          },
        ]);

        await sendEvents(relay, 1, kind: EventKind.reaction);
        await relay.deliver([
          'EOSE',
          _queryId,
          ['finish'],
        ]);

        final ended = await outcome.future;
        expect(
          ended.confirmedExhaustive,
          isFalse,
          reason: 'the relay did not honour the filter it says it finished',
        );
        expect(ended.possiblyCapped, isTrue);
      });

      test('leave out events a filter field is not judged on '
          'locally', () async {
        final relay = await addRelay('wss://relay.example');
        final outcome = await startQuery([
          {
            'kinds': [EventKind.textNote],
            'search': 'a term these events do not contain',
            'limit': 10,
          },
        ]);

        await sendEvents(relay, 1);
        await relay.deliver(['EOSE', _queryId]);

        expect(
          (await outcome.future).possiblyCapped,
          isFalse,
          reason:
              'NIP-50 search is judged by the relay, so an event it returns '
              'for one is not outside the filter',
        );
        expect(completionLines(), isEmpty);
      });
    });

    group('events the pool rejects', () {
      const url = 'wss://relay.example';

      /// Has a relay answer a query with room for ten events: an event the
      /// pool accepts, at 110, then an `EVENT` frame carrying [rejected],
      /// then an `EOSE` with [hints].
      Future<QueryOutcome> answerWith(
        Object? rejected, {
        List<String>? hints,
      }) async {
        final relay = await addRelay(url);
        final outcome = await startQuery([
          {
            'kinds': [EventKind.textNote],
            'limit': 10,
          },
        ]);
        await sendEventsAt(relay, [110]);
        await relay.deliver(['EVENT', _queryId, rejected]);
        await relay.deliver(['EOSE', _queryId, ?hints]);
        return outcome.future;
      }

      /// The relay may have spent a slot of its limit on the rejected frame,
      /// so its page of one event may not be all it holds.
      void expectCapped(QueryOutcome ended) {
        expect(ended.possiblyCapped, isTrue);
        expect(ended.relays, [
          _summary(url: url, oldestCreatedAt: 110, capped: true),
        ]);
      }

      test('mark the relay capped when an event id does not match its '
          'content', () async {
        final event = await signedEvent(createdAt: 105);

        expectCapped(
          await answerWith({...event.toJson(), 'content': 'forged'}),
        );
      });

      test(
        'mark the relay capped when an event carries no signature',
        () async {
          final event = await signedEvent(createdAt: 105);

          expectCapped(await answerWith({...event.toJson(), 'sig': ''}));
        },
      );

      test('mark the relay capped when an event signature does not '
          'verify', () async {
        final event = await signedEvent(createdAt: 105);
        final sig = event.sig;
        final forged =
            '${sig.substring(0, sig.length - 1)}'
            '${sig.endsWith('0') ? '1' : '0'}';

        expectCapped(await answerWith({...event.toJson(), 'sig': forged}));
      });

      test('mark the relay capped when the verify worker turns an event '
          'down', () async {
        final worker = _VerifyWorker();
        nostr.relayPool.eventVerifyWorker = worker;
        final event = await signedEvent(createdAt: 105);
        worker.rejects.add(event.id);

        expectCapped(await answerWith(event.toJson()));
      });

      test('mark the relay capped when a frame carries something other than '
          'an object', () async {
        expectCapped(await answerWith('not an event'));
      });

      test('mark the relay capped when a frame carries an object that is not '
          'an event', () async {
        expectCapped(await answerWith({'kind': EventKind.textNote}));
      });

      test('are counted in the completion line', () async {
        final event = await signedEvent(createdAt: 105);

        await answerWith({...event.toJson(), 'sig': ''});

        expect(completionLines(), hasLength(1));
        expect(
          completionLines().single.message,
          contains('$url (events=1, 1 event rejected, capped)'),
        );
      });

      test('keep a finish hint from confirming the relay exhaustive', () async {
        final event = await signedEvent(createdAt: 105);

        final ended = await answerWith(
          {...event.toJson(), 'sig': ''},
          hints: ['finish'],
        );

        expect(
          ended.confirmedExhaustive,
          isFalse,
          reason: 'the relay says it finished, yet sent a frame nobody can use',
        );
        expect(ended.possiblyCapped, isTrue);
      });

      test(
        'are not counted from a relay that does not hold the query',
        () async {
          final asked = await addRelay(url);
          final outcome = await startQuery([
            {
              'kinds': [EventKind.textNote],
              'limit': 10,
            },
          ]);
          final late = await addRelay('wss://late.example');
          final event = await signedEvent(createdAt: 105);

          await late.deliver(['EVENT', _queryId, event.toJson()..['sig'] = '']);
          await asked.deliver(['EOSE', _queryId]);

          final ended = await outcome.future;
          expect(
            ended.endedBy,
            QueryEnd.complete,
            reason:
                'the fan-out never asked the late relay, so it owes nothing',
          );
          expect(ended.possiblyCapped, isFalse);
        },
      );
    });

    group('NIP-67 EOSE hints', () {
      test('finish clears the cap and confirms the read exhaustive', () async {
        final relay = await addRelay('wss://relay.example');
        final outcome = await startQuery([
          {
            'kinds': [1],
            'limit': 2,
          },
        ]);

        await sendEvents(relay, 2);
        await relay.deliver([
          'EOSE',
          _queryId,
          ['finish'],
        ]);

        final result = await outcome.future;
        expect(result.possiblyCapped, isFalse);
        expect(result.confirmedExhaustive, isTrue);
      });

      test('more marks the relay capped', () async {
        final relay = await addRelay('wss://relay.example');
        final outcome = await startQuery([
          {
            'kinds': [1],
            'limit': 10,
          },
        ]);

        await sendEvents(relay, 1);
        await relay.deliver([
          'EOSE',
          _queryId,
          ['more'],
        ]);

        final result = await outcome.future;
        expect(result.possiblyCapped, isTrue);
        expect(result.confirmedExhaustive, isFalse);
      });

      test('more beside finish still marks the relay capped', () async {
        final relay = await addRelay('wss://relay.example');
        final outcome = await startQuery([
          {
            'kinds': [1],
            'limit': 10,
          },
        ]);

        await sendEvents(relay, 1);
        await relay.deliver([
          'EOSE',
          _queryId,
          ['finish', 'more'],
        ]);

        final result = await outcome.future;
        expect(result.possiblyCapped, isTrue);
        expect(result.confirmedExhaustive, isFalse);
      });

      test('auth beside finish does not confirm the read exhaustive', () async {
        final relay = await addRelay('wss://relay.example');
        final outcome = await startQuery([
          {
            'kinds': [1],
            'limit': 10,
          },
        ]);

        await sendEvents(relay, 1);
        await relay.deliver([
          'EOSE',
          _queryId,
          ['auth', 'finish'],
        ]);

        final result = await outcome.future;
        expect(
          result.possiblyCapped,
          isFalse,
          reason: 'finish still says the relay sent all it would without AUTH',
        );
        expect(
          result.confirmedExhaustive,
          isFalse,
          reason:
              'auth says more matching events may follow a NIP-42 '
              'handshake',
        );
      });

      test('a third element that is not a list is ignored', () async {
        final relay = await addRelay('wss://relay.example');
        final outcome = await startQuery([
          {
            'kinds': [1],
            'limit': 2,
          },
        ]);

        await sendEvents(relay, 2);
        await relay.deliver(['EOSE', _queryId, 'finish']);

        final result = await outcome.future;
        expect(result.endedBy, QueryEnd.complete);
        expect(result.possiblyCapped, isTrue);
        expect(result.confirmedExhaustive, isFalse);
      });

      test('unknown and non-string hints are ignored', () async {
        final relay = await addRelay('wss://relay.example');
        final outcome = await startQuery([
          {
            'kinds': [1],
            'limit': 10,
          },
        ]);

        await sendEvents(relay, 1);
        await relay.deliver([
          'EOSE',
          _queryId,
          ['paused', 7],
        ]);

        final result = await outcome.future;
        expect(result.possiblyCapped, isFalse);
        expect(result.confirmedExhaustive, isFalse);
      });

      test('confirms the read exhaustive only when every relay that answered '
          'sent finish', () async {
        final finishing = await addRelay('wss://finishes.example');
        final plain = await addRelay('wss://plain.example');
        final outcome = await startQuery([
          {
            'kinds': [1],
            'limit': 10,
          },
        ]);

        await finishing.deliver([
          'EOSE',
          _queryId,
          ['finish'],
        ]);
        await plain.deliver(['EOSE', _queryId]);

        expect((await outcome.future).confirmedExhaustive, isFalse);
      });
    });

    group('queryCompletion diagnostic', () {
      test('a query that did not complete emits exactly one warning line, '
          'free of identifiers', () async {
        final answering = await addRelay('wss://answers.example');
        final refusing = await addRelay('wss://refuses.example');
        final pubkey = await nostr.ensurePublicKey();
        final tagValue = 'ab' * 32;
        final event = await signedEvent(
          tags: [
            ['e', tagValue],
            ['t', 'private-hashtag'],
          ],
        );
        final outcome = await startQuery([
          {
            'ids': [event.id],
            'authors': [pubkey],
            'kinds': [EventKind.textNote],
            '#e': [tagValue],
            '#t': ['private-hashtag'],
            'limit': 5,
          },
        ]);

        await refusing.deliver(['EVENT', _queryId, event.toJson()]);
        await refusing.deliver([
          'CLOSED',
          _queryId,
          'rate-limited: raw relay text',
        ]);
        await answering.deliver(['EOSE', _queryId]);

        expect((await outcome.future).endedBy, QueryEnd.relayClosed);
        expect(completionLines(), hasLength(1));
        final line = completionLines().single;
        expect(line.level, RelayDiagnosticLevel.warning);
        expect(line.relayUrl, 'wss://refuses.example');
        expect(
          line.message,
          allOf(
            contains('relayClosed'),
            contains('; answered: wss://answers.example (events=0)'),
            contains(
              'not answered: wss://refuses.example (closed: rate-limited, '
              'events=1)',
            ),
            contains('kinds: [1], limit: 5'),
            matches(RegExp(r'after \d+ms')),
          ),
        );
        for (final identifier in [
          event.id,
          pubkey,
          tagValue,
          'private-hashtag',
          'raw relay text',
        ]) {
          expect(line.message, isNot(contains(identifier)));
        }
      });

      test('a complete query nothing capped emits no line', () async {
        final relay = await addRelay('wss://relay.example');
        final outcome = await startQuery([
          {
            'kinds': [1],
            'limit': 5,
          },
        ]);

        await sendEvents(relay, 1);
        await relay.deliver(['EOSE', _queryId]);

        final result = await outcome.future;
        expect(result.endedBy, QueryEnd.complete);
        expect(result.possiblyCapped, isFalse);
        expect(
          diagnostics.map((entry) => entry.site),
          contains(RelayDiagnosticSite.requestSettlement),
          reason: 'the sink is wired: it captured the EOSE settlement',
        );
        expect(completionLines(), isEmpty);
      });

      test(
        'a complete but possibly capped query emits one info line',
        () async {
          final relay = await addRelay('wss://relay.example');
          final outcome = await startQuery([
            {
              'kinds': [1],
              'limit': 1,
            },
          ]);

          await sendEvents(relay, 1);
          await relay.deliver(['EOSE', _queryId]);

          expect((await outcome.future).possiblyCapped, isTrue);
          expect(completionLines(), hasLength(1));
          final line = completionLines().single;
          expect(line.level, RelayDiagnosticLevel.info);
          expect(line.relayUrl, 'wss://relay.example');
          expect(
            line.message,
            allOf(
              contains('complete'),
              contains('possiblyCapped=true'),
              contains('answered: wss://relay.example (events=1, capped)'),
            ),
          );
        },
      );

      test('settledEarly is reported at info level', () async {
        final answering = await addRelay('wss://answers.example');
        await addRelay('wss://never-answers.example');
        final outcome = await startQuery([
          {
            'kinds': [1],
            'limit': 10,
          },
        ]);

        await answering.deliver(['EOSE', _queryId]);

        expect((await outcome.future).endedBy, QueryEnd.settledEarly);
        expect(completionLines(), hasLength(1));
        final line = completionLines().single;
        expect(line.level, RelayDiagnosticLevel.info);
        expect(line.relayUrl, 'wss://never-answers.example');
        expect(
          line.message,
          contains('not answered: wss://never-answers.example (no answer'),
        );
      });

      test('a query no relay took names the relays that did not take '
          'it', () async {
        final unreachable = await addRelay('wss://send-fails.example');
        unreachable.sendSucceeds = false;

        final outcome = await startQuery([
          {
            'kinds': [1],
            'limit': 10,
          },
        ]);

        expect((await outcome.future).endedBy, QueryEnd.noRelay);
        expect(completionLines(), hasLength(1));
        final line = completionLines().single;
        expect(line.level, RelayDiagnosticLevel.warning);
        expect(line.relayUrl, 'wss://send-fails.example');
        expect(
          line.message,
          contains('did not take the REQ: wss://send-fails.example'),
        );
      });
    });

    group('reportQueryDeadline', () {
      test('reports a deadline, judged on what arrived, in one warning '
          'line', () async {
        final streaming = await addRelay('wss://streams.example');
        await addRelay('wss://never-answers.example');
        final outcome = await startQuery([
          {
            'kinds': [1],
            'limit': 2,
          },
        ]);
        await sendEvents(streaming, 2);

        final atDeadline = nostr.relayPool.reportQueryDeadline(_queryId);
        nostr.relayPool.unsubscribe(_queryId);
        await pumpEventQueue();

        expect(atDeadline?.endedBy, QueryEnd.deadline);
        expect(
          atDeadline?.possiblyCapped,
          isTrue,
          reason: 'the streaming relay had already reached the limit',
        );
        expect(completionLines(), hasLength(1));
        final line = completionLines().single;
        expect(line.level, RelayDiagnosticLevel.warning);
        expect(line.message, contains('deadline'));
        expect(
          outcome.isCompleted,
          isFalse,
          reason:
              'the caller ended this query, so the pool has no outcome '
              'of its own to deliver',
        );
      });

      test('the pool adds no second line when it completes the query '
          'afterwards', () async {
        final relay = await addRelay('wss://refuses.example');
        final outcome = await startQuery([
          {
            'kinds': [1],
            'limit': 5,
          },
        ]);

        expect(
          nostr.relayPool.reportQueryDeadline(_queryId)?.endedBy,
          QueryEnd.deadline,
        );
        await relay.deliver([
          'CLOSED',
          _queryId,
          'error: too many concurrent REQs',
        ]);

        expect(
          (await outcome.future).endedBy,
          QueryEnd.relayClosed,
          reason:
              'the pool still completed the query, which on its own emits '
              'a line',
        );
        expect(completionLines(), hasLength(1));
        expect(completionLines().single.message, contains('deadline'));
      });

      test(
        'a deadline during the fan-out is deadline, never noRelay',
        () async {
          final relay = await addRelay('wss://slow-to-refuse.example')
            ..sendSucceeds = false
            ..reqGate = Completer<void>();
          var outcomes = 0;
          final fanout = nostr.relayPool.query(
            [
              {
                'kinds': [1],
              },
            ],
            (_) {},
            id: _queryId,
            onOutcome: (_) => outcomes++,
          );
          expect(
            relay.sentMessages.where((message) => message.first == 'REQ'),
            hasLength(1),
            reason: 'the REQ write is still in flight',
          );

          final atDeadline = nostr.relayPool.reportQueryDeadline(_queryId);
          nostr.relayPool.unsubscribe(_queryId);
          relay.reqGate!.complete();
          await fanout;

          expect(
            atDeadline?.endedBy,
            QueryEnd.deadline,
            reason:
                'the fan-out had not finished, so whether any relay took '
                'the REQ was still unknown',
          );
          expect(
            nostr.relayPool.reportQueryDeadline(_queryId),
            isNull,
            reason:
                'a fan-out that finishes after its caller left must not '
                'revive the record',
          );
          expect(
            completionLines(),
            hasLength(1),
            reason: 'the deadline line stays the only one for this read',
          );
          expect(
            outcomes,
            0,
            reason: 'the caller ended this read, so the pool delivers nothing',
          );
        },
      );

      test('a deadline during the fan-out names the relays still being '
          'asked', () async {
        await addRelay('wss://fast.example');
        final slow = await addRelay('wss://slow.example')
          ..reqGate = Completer<void>();
        final fanout = nostr.relayPool.query(
          [
            {
              'kinds': [1],
            },
          ],
          (_) {},
          id: _queryId,
          onOutcome: (_) {},
        );
        // `fast` takes the REQ while `slow` is still writing it.
        await pumpEventQueue();

        nostr.relayPool.reportQueryDeadline(_queryId);
        nostr.relayPool.unsubscribe(_queryId);
        slow.reqGate!.complete();
        await fanout;

        expect(completionLines(), hasLength(1));
        final line = completionLines().single;
        expect(
          line.relayUrl,
          isIn(['wss://fast.example', 'wss://slow.example']),
          reason: 'the line is filed under a relay the query asked',
        );
        expect(
          line.message,
          allOf(
            contains('wss://fast.example (no answer, events=0)'),
            contains('wss://slow.example (REQ in flight, events=0)'),
          ),
        );
      });

      test('returns null once the pool has completed the query', () async {
        final relay = await addRelay('wss://relay.example');
        final outcome = await startQuery([
          {
            'kinds': [1],
            'limit': 5,
          },
        ]);
        expect(
          nostr.relayPool.reportQueryDeadline(_queryId),
          isNotNull,
          reason: 'the query is in flight',
        );

        await relay.deliver(['EOSE', _queryId]);
        await outcome.future;

        expect(nostr.relayPool.reportQueryDeadline(_queryId), isNull);
      });

      test('returns null once the caller unsubscribed', () async {
        await addRelay('wss://relay.example');
        await startQuery([
          {
            'kinds': [1],
            'limit': 5,
          },
        ]);
        expect(
          nostr.relayPool.reportQueryDeadline(_queryId),
          isNotNull,
          reason: 'the query is in flight',
        );

        nostr.relayPool.unsubscribe(_queryId);

        expect(nostr.relayPool.reportQueryDeadline(_queryId), isNull);
      });

      test('keeps no record of a query that asked for no completion', () async {
        await addRelay('wss://relay.example');

        await nostr.relayPool.query(
          [
            {
              'kinds': [1],
            },
          ],
          (_) {},
          id: _queryId,
        );

        expect(
          nostr.relayPool.reportQueryDeadline(_queryId),
          isNull,
          reason: 'nothing would ever complete it and release the record',
        );
      });
    });

    group('relays', () {
      test('names each relay that sent events, with the oldest created_at '
          'and whether it may be capped', () async {
        final full = await addRelay('wss://full.example');
        final short = await addRelay('wss://short.example');
        final empty = await addRelay('wss://empty.example');
        final outcome = await startQuery([
          {
            'kinds': [1],
            'limit': 2,
          },
        ]);

        await sendEventsAt(full, [103, 101]);
        await sendEventsAt(short, [102]);
        for (final relay in [full, short, empty]) {
          await relay.deliver(['EOSE', _queryId]);
        }

        expect(
          (await outcome.future).relays,
          unorderedMatches([
            _summary(
              url: 'wss://full.example',
              oldestCreatedAt: 101,
              capped: true,
            ),
            _summary(
              url: 'wss://short.example',
              oldestCreatedAt: 102,
              capped: false,
            ),
          ]),
          reason: 'a relay that sent nothing has nothing to report',
        );
      });

      test('counts events the block list hides from the caller', () async {
        nostr = newNostr(eventFilters: [_BlockEverything()]);
        final relay = await addRelay('wss://relay.example');
        final delivered = <Event>[];
        final outcome = await startQuery([
          {
            'kinds': [1],
            'limit': 2,
          },
        ], onEvent: delivered.add);

        await sendEventsAt(relay, [105, 104]);
        await relay.deliver(['EOSE', _queryId]);

        expect(delivered, isEmpty, reason: 'the block list hid both events');
        expect((await outcome.future).relays, [
          _summary(
            url: 'wss://relay.example',
            oldestCreatedAt: 104,
            capped: true,
          ),
        ]);
      });

      test('judges each relay by its own hints and events outside the '
          'filter', () async {
        final finishes = await addRelay('wss://finishes.example');
        final more = await addRelay('wss://more.example');
        final offFilter = await addRelay('wss://off-filter.example');
        final outcome = await startQuery([
          {
            'kinds': [EventKind.textNote],
            'limit': 2,
          },
        ]);

        await sendEventsAt(finishes, [110, 109]);
        await finishes.deliver([
          'EOSE',
          _queryId,
          ['finish'],
        ]);
        await sendEventsAt(more, [108]);
        await more.deliver([
          'EOSE',
          _queryId,
          ['more'],
        ]);
        await sendEventsAt(offFilter, [107]);
        await sendEvents(offFilter, 1, kind: EventKind.reaction);
        await offFilter.deliver(['EOSE', _queryId]);

        expect(
          (await outcome.future).relays,
          unorderedMatches([
            _summary(
              url: 'wss://finishes.example',
              oldestCreatedAt: 109,
              capped: false,
            ),
            _summary(
              url: 'wss://more.example',
              oldestCreatedAt: 108,
              capped: true,
            ),
            _summary(
              url: 'wss://off-filter.example',
              oldestCreatedAt: 107,
              capped: true,
            ),
          ]),
          reason:
              'finish clears the cap its count would set, more sets one, '
              'and so does an event outside the filter',
        );
      });

      test('leaves out a cache relay', () async {
        final relay = await addRelay('wss://relay.example');
        final cache = _ScriptedRelay('wss://cache.example')
          ..relayStatus.relayType = RelayType.cache;
        expect(
          await nostr.relayPool.add(cache, relayType: RelayType.cache),
          isTrue,
        );
        final outcome = await startQuery([
          {
            'kinds': [1],
            'limit': 5,
          },
        ]);

        await sendEventsAt(relay, [103]);
        await sendEventsAt(cache, [90]);
        await relay.deliver(['EOSE', _queryId]);
        await cache.deliver(['EOSE', _queryId]);

        expect(
          (await outcome.future).relays,
          [
            _summary(
              url: 'wss://relay.example',
              oldestCreatedAt: 103,
              capped: false,
            ),
          ],
          reason:
              "a cache relay serves the pool's own copies, which say nothing "
              "about any relay's history",
        );
      });

      test('come with the outcome reportQueryDeadline returns', () async {
        final relay = await addRelay('wss://streams.example');
        await startQuery([
          {
            'kinds': [1],
            'limit': 5,
          },
        ]);
        await sendEventsAt(relay, [103, 102]);

        final atDeadline = nostr.relayPool.reportQueryDeadline(_queryId);
        nostr.relayPool.unsubscribe(_queryId);

        expect(atDeadline?.relays, [
          _summary(
            url: 'wss://streams.example',
            oldestCreatedAt: 102,
            capped: false,
          ),
        ]);
      });
    });

    group('cappedWithoutEvents', () {
      test('names a relay that may be capped and sent no matching '
          'event', () async {
        final offFilter = await addRelay('wss://off-filter.example');
        final answering = await addRelay('wss://answering.example');
        final outcome = await startQuery([
          {
            'kinds': [EventKind.textNote],
            'limit': 2,
          },
        ]);

        await sendEvents(offFilter, 2, kind: EventKind.reaction);
        await offFilter.deliver(['EOSE', _queryId]);
        await sendEventsAt(answering, [110]);
        await answering.deliver(['EOSE', _queryId]);

        final ended = await outcome.future;

        expect(
          ended.cappedWithoutEvents,
          ['wss://off-filter.example'],
          reason:
              'it spent its limit on events nobody asked for, and no summary '
              'can name it without a created_at to carry',
        );
        expect(ended.relays.map((relay) => relay.url), [
          'wss://answering.example',
        ]);
      });

      test('stays empty for a relay that sent nothing at all', () async {
        final silent = await addRelay('wss://silent.example');
        final answering = await addRelay('wss://answering.example');
        final outcome = await startQuery([
          {
            'kinds': [EventKind.textNote],
            'limit': 2,
          },
        ]);

        await sendEventsAt(answering, [110, 109]);
        for (final relay in [silent, answering]) {
          await relay.deliver(['EOSE', _queryId]);
        }

        final ended = await outcome.future;

        expect(
          ended.cappedWithoutEvents,
          isEmpty,
          reason: 'silence is not a cap: nothing says it withheld anything',
        );
        expect(
          ended.possiblyCapped,
          isTrue,
          reason: 'the other relay did fill the limit, so the page is capped',
        );
      });
    });

    group('onComplete', () {
      test('still fires when onOutcome is given too', () async {
        final relay = await addRelay('wss://relay.example');
        var completions = 0;
        final outcome = Completer<QueryOutcome>();
        await nostr.relayPool.query(
          [
            {
              'kinds': [1],
              'limit': 5,
            },
          ],
          (_) {},
          id: _queryId,
          onComplete: () => completions++,
          onOutcome: outcome.complete,
        );

        await relay.deliver(['EOSE', _queryId]);

        expect((await outcome.future).endedBy, QueryEnd.complete);
        expect(completions, 1);
      });

      test('alone still gets the query judged and its line emitted', () async {
        final refusing = await addRelay('wss://refuses.example');
        var completions = 0;
        await nostr.relayPool.query(
          [
            {
              'kinds': [1],
              'limit': 5,
            },
          ],
          (_) {},
          id: _queryId,
          onComplete: () => completions++,
        );

        await refusing.deliver([
          'CLOSED',
          _queryId,
          'error: too many concurrent REQs',
        ]);

        expect(completions, 1);
        expect(
          completionLines(),
          hasLength(1),
          reason: 'the legacy read path is judged like any other',
        );
        expect(completionLines().single.message, contains('relayClosed'));
      });
    });
  });
}
