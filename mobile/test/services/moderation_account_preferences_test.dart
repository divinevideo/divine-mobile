import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/account_preference_store.dart';
import 'package:openvine/services/moderation_account_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_account_state.dart';

const _account =
    '1111111111111111111111111111111111111111111111111111111111111111';
const _labelerA =
    '3333333333333333333333333333333333333333333333333333333333333333';
const _labelerB =
    '4444444444444444444444444444444444444444444444444444444444444444';

void main() {
  group('moderation account preference binding', () {
    test('distinct snapshots retain pending work; changed choices and close invalidate it', () async {
      SharedPreferences.setMockInitialValues({});
      final port = AccountPreferenceStore(
        await SharedPreferences.getInstance(),
      );
      final repository = FakeAccountState(_account);
      await port.bind(repository);
      final blocked = Completer<void>();
      final snapshots = <ModerationAccountPreferenceSnapshot>[];
      final ownership = <bool Function()>[];
      final binding = ModerationAccountPreferences(
        preferences: port,
        labelersStorageKey: 'subscribed_labeler_pubkeys',
        followingEnabledStorageKey: 'following_moderation_enabled',
        reconcile: (snapshot, isCurrent) {
          snapshots.add(snapshot);
          ownership.add(isCurrent);
          return blocked.future;
        },
      );
      repository.receive({'trusted_labeler/$_labelerA': true});
      await pumpEventQueue();
      repository.receive({'content_language': 'es'});
      await pumpEventQueue();
      expect(snapshots.length, 1);
      expect(ownership.first(), isTrue);
      repository.receive({
        'trusted_labeler/$_labelerB': true,
        'following_moderation_enabled': true,
      });
      await pumpEventQueue();
      expect(snapshots.last.labelers, {_labelerA, _labelerB});
      expect(snapshots.last.followingEnabled, isTrue);
      expect(ownership.first(), isFalse);
      expect(ownership.last(), isTrue);
      binding.close();
      expect(ownership.last(), isFalse);
      repository.receive({'trusted_labeler/$_labelerB': false});
      await pumpEventQueue();
      expect(snapshots.length, 2);
      blocked.complete();
      await pumpEventQueue();
      port.dispose();
      await repository.close();
    });

    test(
      'failed owner reconciliation can retry on a later account update',
      () async {
        SharedPreferences.setMockInitialValues({});
        final port = AccountPreferenceStore(
          await SharedPreferences.getInstance(),
        );
        final repository = FakeAccountState(_account);
        await port.bind(repository);
        var attempts = 0;
        final binding = ModerationAccountPreferences(
          preferences: port,
          labelersStorageKey: 'subscribed_labeler_pubkeys',
          followingEnabledStorageKey: 'following_moderation_enabled',
          reconcile: (_, _) async {
            if (++attempts == 1) throw StateError('offline');
          },
        );
        repository.receive({'trusted_labeler/$_labelerA': true});
        await pumpEventQueue();
        repository.receive({'content_language': 'es'});
        await pumpEventQueue();
        expect(attempts, 2);
        binding.close();
        port.dispose();
        await repository.close();
      },
    );
  });
}
