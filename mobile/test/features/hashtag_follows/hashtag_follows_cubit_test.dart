import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hashtag_subscription_repository/hashtag_subscription_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/features/hashtag_follows/cubit/hashtag_follows_cubit.dart';
import 'package:openvine/features/hashtag_follows/data/shared_preferences_hashtag_subscription_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TestStore implements HashtagSubscriptionStore {
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
    if (fail) throw Exception('failed');
    this.value = value;
  }
}

class FailedPreferences extends Mock implements SharedPreferences {}

void main() {
  group('hashtag_follows_cubit_test', () {
    test('adapter rejects an unconfirmed preference write', () async {
      final prefs = FailedPreferences();
      when(() => prefs.setString(any(), any())).thenAnswer((_) async => false);
      final store = SharedPreferencesHashtagSubscriptionStore(
        prefs: prefs,
        pubkey: 'a' * 64,
      );
      await expectLater(store.write('[]'), throwsException);
    });
    test(
      'adapter reports corrupt preference types without overwriting',
      () async {
        SharedPreferences.setMockInitialValues({
          'followed_hashtags_${'a' * 64}': 12,
        });
        final prefs = await SharedPreferences.getInstance();
        final store = SharedPreferencesHashtagSubscriptionStore(
          prefs: prefs,
          pubkey: 'a' * 64,
        );
        await expectLater(store.read(), throwsFormatException);
        expect(prefs.get('followed_hashtags_${'a' * 64}'), 12);
      },
    );
    test('preference adapter separates full account keys', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final first = SharedPreferencesHashtagSubscriptionStore(
        prefs: prefs,
        pubkey: 'a' * 64,
      );
      final other = SharedPreferencesHashtagSubscriptionStore(
        prefs: prefs,
        pubkey: 'b' * 64,
      );
      await first.write('["LNIC"]');
      expect(await first.read(), '["LNIC"]');
      expect(await other.read(), isNull);
      expect(prefs.getKeys().single, contains('a' * 64));
    });
    test('confirmed follows, pending protection and failed unfollow', () async {
      final store = TestStore();
      final repository = HashtagSubscriptionRepository(store: store);
      final cubit = HashtagFollowsCubit(repository: repository);
      addTearDown(repository.dispose);
      addTearDown(cubit.close);
      await cubit.initialize();
      store.gate = Completer<void>();
      final follow = cubit.follow('LNIC');
      expect(cubit.state.pendingTags, contains('lnic'));
      await cubit.follow('lnic');
      store.gate!.complete();
      await follow;
      expect(cubit.state.subscriptions.single.displayTag, 'LNIC');
      store.fail = true;
      await cubit.unfollow('lnic');
      expect(cubit.state.hasWriteError, isTrue);
      expect(cubit.state.subscriptions, hasLength(1));
      expect(cubit.state.pendingTags, isEmpty);
    });
    test('read failure supports explicit retry', () async {
      final store = TestStore()..value = 'broken';
      final repository = HashtagSubscriptionRepository(store: store);
      final cubit = HashtagFollowsCubit(repository: repository);
      addTearDown(repository.dispose);
      addTearDown(cubit.close);
      await cubit.initialize();
      expect(cubit.state.hasReadError, isTrue);
      store.value = null;
      await cubit.initialize();
      expect(cubit.state.hasReadError, isFalse);
      expect(cubit.state.isLoading, isFalse);
    });
    test('close during a write cannot emit after close', () async {
      final store = TestStore()..gate = Completer<void>();
      final repository = HashtagSubscriptionRepository(store: store);
      final cubit = HashtagFollowsCubit(repository: repository);
      addTearDown(repository.dispose);
      await cubit.initialize();
      final follow = cubit.follow('one');
      await cubit.close();
      store.gate!.complete();
      await follow;
      expect(cubit.isClosed, isTrue);
    });
    test(
      'account teardown during initialization does not escape the Cubit',
      () async {
        final store = TestStore()..readGate = Completer<void>();
        final repository = HashtagSubscriptionRepository(store: store);
        final cubit = HashtagFollowsCubit(repository: repository);
        final loading = cubit.initialize();
        await cubit.close();
        await repository.dispose();
        store.readGate!.complete();
        await loading;
        expect(cubit.isClosed, isTrue);
      },
    );
  });
}
