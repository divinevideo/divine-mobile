import 'dart:async';

import 'package:hashtag_subscription_repository/hashtag_subscription_repository.dart';
import 'package:test/test.dart';

class MemoryStore implements HashtagSubscriptionStore {
  String? value;
  bool fail = false;
  Completer<void>? readGate;
  Completer<void>? gate;
  @override
  Future<String?> read() async {
    await readGate?.future;
    return value;
  }

  @override
  Future<void> write(String value) async {
    await gate?.future;
    if (fail) throw StateError('disk unavailable');
    this.value = value;
  }
}

void main() {
  group('hashtag_subscription_repository_test', () {
    late MemoryStore store;
    late HashtagSubscriptionRepository repository;
    setUp(() {
      store = MemoryStore();
      repository = HashtagSubscriptionRepository(store: store);
    });
    tearDown(() => repository.dispose());

    test(
      'subscription equality includes spelling and canonical membership',
      () {
        expect(
          HashtagSubscription.fromTag('LNIC'),
          HashtagSubscription.fromTag('#LNIC'),
        );
        expect(
          HashtagSubscription.fromTag('LNIC'),
          isNot(HashtagSubscription.fromTag('other')),
        );
      },
    );
    test('dispose during initialization is a typed cancellation', () async {
      store.readGate = Completer<void>();
      final loading = repository.initialize();
      final cancelled = expectLater(
        loading,
        throwsA(isA<HashtagSubscriptionRepositoryDisposedException>()),
      );
      await repository.dispose();
      store.readGate!.complete();
      await cancelled;
    });
    test(
      'normalizes membership and preserves first display spelling',
      () async {
        await repository.follow(' #LNIC ');
        await repository.follow('lnic');
        expect(repository.subscriptions.single.canonicalTag, 'lnic');
        expect(repository.subscriptions.single.displayTag, 'LNIC');
        expect(
          await repository.subscriptionsStream.first,
          repository.subscriptions,
        );
      },
    );
    test('rejects invalid tags', () async {
      for (final tag in ['', '#', '##hello', 'two words', 'a#b']) {
        await expectLater(repository.follow(tag), throwsArgumentError);
      }
      expect(store.value, isNull);
    });
    test(
      'round trips Unicode and percent tags, sorted and immutable',
      () async {
        await repository.follow('日本語');
        await repository.follow('100%fun');
        final restored = HashtagSubscriptionRepository(store: store);
        addTearDown(restored.dispose);
        await restored.initialize();
        expect(restored.subscriptions.map((tag) => tag.displayTag), [
          '100%fun',
          '日本語',
        ]);
        expect(() => restored.subscriptions.clear(), throwsUnsupportedError);
        await restored.unfollow('#日本語');
        expect(restored.subscriptions.single.displayTag, '100%fun');
      },
    );
    test('serializes overlapping writes', () async {
      store.gate = Completer<void>();
      final first = repository.follow('one');
      final second = repository.follow('two');
      store.gate!.complete();
      await Future.wait([first, second]);
      expect(repository.subscriptions.map((tag) => tag.canonicalTag), [
        'one',
        'two',
      ]);
    });
    test(
      'failed writes retain confirmed state and do not poison queue',
      () async {
        await repository.follow('one');
        store.fail = true;
        await expectLater(repository.follow('two'), throwsStateError);
        expect(repository.subscriptions.single.canonicalTag, 'one');
        store.fail = false;
        await repository.follow('three');
        expect(repository.subscriptions.length, 2);
      },
    );
    test('malformed reads cannot overwrite storage and can retry', () async {
      store.value = 'broken';
      await expectLater(repository.follow('one'), throwsFormatException);
      expect(store.value, 'broken');
      store.value = null;
      await repository.follow('one');
      expect(repository.subscriptions.single.canonicalTag, 'one');
    });
    test('accounts use independent injected stores', () async {
      final other = HashtagSubscriptionRepository(store: MemoryStore());
      addTearDown(other.dispose);
      await repository.follow('one');
      await other.initialize();
      expect(other.subscriptions, isEmpty);
    });
    test('disposed repositories reject writes', () async {
      await repository.dispose();
      await expectLater(
        repository.initialize(),
        throwsA(isA<HashtagSubscriptionRepositoryDisposedException>()),
      );
      await expectLater(
        repository.follow('one'),
        throwsA(isA<HashtagSubscriptionRepositoryDisposedException>()),
      );
    });
  });
}
