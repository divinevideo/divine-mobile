// ABOUTME: Checks bounded relay snapshot completion and subscription cleanup.
// ABOUTME: Partial snapshots never claim a completed query or publish anything.

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/services/curated_lists/curated_list_relay_snapshot_reader.dart';

class _MockNostrClient extends Mock implements NostrClient {}

void main() {
  group(CuratedListRelaySnapshotReader, () {
    final owner = 'a' * 64;
    final event = Event.fromJson({
      'id': 'b' * 64,
      'pubkey': owner,
      'created_at': 1786000000,
      'kind': 30005,
      'tags': [
        ['d', 'my_vine_list'],
      ],
      'content': '',
      'sig': 'c' * 128,
    });
    late _MockNostrClient client;
    late CuratedListRelaySnapshotReader reader;

    setUp(() {
      client = _MockNostrClient();
      reader = CuratedListRelaySnapshotReader(nostrClient: client);
    });

    test('reads only the captured owner and marks normal completion', () async {
      var cancellations = 0;
      final controller = StreamController<Event>(
        onCancel: () => cancellations++,
      );
      when(() => client.subscribe(any())).thenAnswer((_) => controller.stream);

      final pending = reader.read(
        ownerPubkey: owner,
        timeout: const Duration(seconds: 10),
      );
      controller.add(event);
      unawaited(controller.close());
      final snapshot = await pending;

      expect(snapshot.events, [event]);
      expect(snapshot.completedNormally, isTrue);
      expect(cancellations, 1);
      final filters =
          verify(
                () => client.subscribe(captureAny()),
              ).captured.single
              as List<Filter>;
      expect(filters.single.authors, [owner]);
      expect(filters.single.kinds, [30005]);
      expect(snapshot.events.clear, throwsUnsupportedError);
    });

    test('retains partial timeout results and cancels at the deadline', () {
      fakeAsync((async) {
        var cancellations = 0;
        final controller = StreamController<Event>(
          onCancel: () => cancellations++,
        );
        when(() => client.subscribe(any()))
            .thenAnswer((_) => controller.stream);
        CuratedListRelaySnapshot? snapshot;
        unawaited(
          reader
              .read(ownerPubkey: owner, timeout: const Duration(seconds: 10))
              .then((result) => snapshot = result),
        );
        controller.add(event);
        async.flushMicrotasks();
        expect(snapshot, isNull);
        expect(cancellations, 0);

        async.elapse(const Duration(seconds: 10));
        async.flushMicrotasks();

        expect(snapshot?.events, [event]);
        expect(snapshot?.completedNormally, isFalse);
        expect(cancellations, 1);
        expect(async.nonPeriodicTimerCount, 0);
        unawaited(controller.close());
        async.flushMicrotasks();
      });
    });

    test(
      'retains partial errors without authorizing a completed read',
      () async {
        var cancellations = 0;
        final controller = StreamController<Event>(
          onCancel: () => cancellations++,
        );
        when(() => client.subscribe(any()))
            .thenAnswer((_) => controller.stream);
        final pending = reader.read(
          ownerPubkey: owner,
          timeout: const Duration(seconds: 10),
        );
        controller
          ..add(event)
          ..addError(StateError('relay disconnected'));
        final snapshot = await pending;
        await controller.close();

        expect(snapshot.events, [event]);
        expect(snapshot.completedNormally, isFalse);
        expect(cancellations, 1);
      },
    );

    test('propagates setup failure to the service without leaking timers', () {
      fakeAsync((async) {
        final setupError = StateError('subscription unavailable');
        when(() => client.subscribe(any())).thenThrow(setupError);
        Object? observedError;
        unawaited(
          reader
              .read(ownerPubkey: owner, timeout: const Duration(seconds: 10))
              .then<void>(
                (_) => fail('A failed setup cannot return a snapshot'),
                onError: (Object error) {
                  observedError = error;
                },
              ),
        );
        async.flushMicrotasks();
        expect(observedError, same(setupError));
        expect(async.nonPeriodicTimerCount, 0);
      });
    });
  });
}
