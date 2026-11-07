// ABOUTME: Tests the store of the newest addressable events shared by the
// ABOUTME: writers that replace the same event.

import 'dart:async';

import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:test/test.dart';

String _hex(int n) => n.toRadixString(16).padLeft(64, '0');

final String _owner = getPublicKey(_hex(1));
final String _other = getPublicKey(_hex(2));

Event _event({
  required int createdAt,
  String dTag = 'divine:replies:video',
  String? pubkey,
  int kind = 30078,
  String content = '',
}) => Event(
  pubkey ?? _owner,
  kind,
  [
    ['d', dTag],
  ],
  content,
  createdAt: createdAt,
)..sign(pubkey == _other ? _hex(2) : _hex(1));

void main() {
  group(LatestAddressableEvents, () {
    late LatestAddressableEvents store;

    setUp(() {
      store = LatestAddressableEvents();
      addTearDown(store.dispose);
    });

    Event? latest({String? pubkey, String dTag = 'divine:replies:video'}) =>
        store.latest(pubkey: pubkey ?? _owner, kind: 30078, dTag: dTag);

    test('continues the coordinate queue after a failed operation', () async {
      Future<T> run<T>(Future<T> Function() operation) => store.run(
        pubkey: _owner,
        kind: 30078,
        dTag: 'synthetic',
        operation: operation,
      );
      final failure = run<void>(() async => throw StateError('synthetic'));
      final assertion = expectLater(failure, throwsStateError);
      final next = run(() async => 'saved');
      await assertion;
      expect(await next, 'saved');
      expect(await run(() async => 'again'), 'again');
    });

    test('observes the current revision and only newer events', () async {
      store.remember(_event(createdAt: 1000));
      final changes = StreamIterator<int>(
        store.revisionsFor(
          pubkey: _owner,
          kind: 30078,
          dTags: const ['divine:replies:video'],
        ),
      );
      addTearDown(changes.cancel);
      expect(await changes.moveNext(), isTrue);
      expect(changes.current, 1);
      store
        ..remember(_event(createdAt: 1000))
        ..remember(_event(createdAt: 999))
        ..remember(_event(createdAt: 1001));
      expect(
        store.revisionFor(
          pubkey: _owner,
          kind: 30078,
          dTags: const ['divine:replies:video'],
        ),
        2,
      );
      expect(await changes.moveNext(), isTrue);
      expect(changes.current, 2);
    });

    test('closes revision listeners when disposed', () async {
      final revisions = store
          .revisionsFor(
            pubkey: _owner,
            kind: 30078,
            dTags: const ['divine:replies:video'],
          )
          .toList();
      await store.dispose();
      expect(await revisions, [0]);
    });

    test(
      'ignores other authors, kinds and identifiers in a scoped watch',
      () async {
        final changes = StreamIterator<int>(
          store.revisionsFor(
            pubkey: _owner,
            kind: 30078,
            dTags: const ['divine:replies:video'],
          ),
        );
        addTearDown(changes.cancel);
        expect(await changes.moveNext(), isTrue);
        expect(changes.current, 0);
        store
          ..remember(_event(createdAt: 1000, pubkey: _other))
          ..remember(_event(createdAt: 1000, kind: 30079))
          ..remember(_event(createdAt: 1000, dTag: 'other'))
          ..remember(_event(createdAt: 1000));
        expect(await changes.moveNext(), isTrue);
        expect(changes.current, 4);
        expect(
          store.revisionFor(
            pubkey: _owner,
            kind: 30078,
            dTags: const ['missing'],
          ),
          0,
        );
      },
    );

    test('knows nothing it was not told', () {
      expect(latest(), isNull);
    });

    test('keeps the newer of two versions, in either order', () {
      final older = _event(createdAt: 1000);
      final newer = _event(createdAt: 2000);

      store
        ..remember(newer)
        ..remember(older);

      expect(latest()?.id, equals(newer.id));
    });

    test('keeps the lower id of two versions signed in one second', () {
      final versions =
          [
              _event(createdAt: 1000, content: 'a'),
              _event(createdAt: 1000, content: 'b'),
            ]
            ..sort((a, b) => b.id.compareTo(a.id))
            ..forEach(store.remember);

      expect(latest()?.id, equals(versions.last.id));
    });

    test('keeps each author, kind and d tag apart', () {
      store
        ..remember(_event(createdAt: 1000))
        ..remember(_event(createdAt: 2000, pubkey: _other))
        ..remember(_event(createdAt: 3000, dTag: 'divine:hidden-commenters'))
        ..remember(_event(createdAt: 4000, kind: 30079));

      expect(latest()?.createdAt, equals(1000));
      expect(latest(pubkey: _other)?.createdAt, equals(2000));
      expect(
        latest(dTag: 'divine:hidden-commenters')?.createdAt,
        equals(3000),
      );
    });

    test('keeps a copy the caller cannot change', () {
      final event = _event(createdAt: 1000);
      store.remember(event);

      event.tags.add(['e', _hex(9), '', 'hidden']);

      expect(latest()?.tags, hasLength(1));
    });
  });
}
