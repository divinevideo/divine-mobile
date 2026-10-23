import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/content_label.dart';
import 'package:openvine/services/account_preference_store.dart';
import 'package:openvine/services/age_verification_service.dart';
import 'package:openvine/services/content_filter_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_account_state.dart';

const _account =
    '1111111111111111111111111111111111111111111111111111111111111111';

class _HeldProjectionStore extends AccountPreferenceStore {
  _HeldProjectionStore(super._preferences);

  final projected = Completer<void>();
  final release = Completer<void>();
  bool _held = false;

  @override
  Future<void> writeValues(Map<String, Object?> values) async {
    await super.writeValues(values);
    if (!_held) {
      _held = true;
      projected.complete();
      await release.future;
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('content filter storage reload', () {
    for (final usePort in [false, true]) {
      test(
        '${usePort ? 'unbound port' : 'legacy'} cleanup notifies once for '
        'the effective reset',
        () async {
          SharedPreferences.setMockInitialValues({});
          final preferences = await SharedPreferences.getInstance();
          final store = AccountPreferenceStore(preferences);
          final filters = ContentFilterService(
            ageVerificationService: AgeVerificationService(
              preferences: preferences,
            ),
            accountPreferences: usePort ? store : null,
          );
          addTearDown(filters.dispose);
          addTearDown(store.dispose);
          await filters.initialize();
          await filters.setPreference(
            ContentLabel.spoiler,
            ContentFilterPreference.hide,
          );
          var notifications = 0;
          filters.addListener(() => notifications++);

          await preferences.remove('content_filter/spoiler');
          await preferences.remove(ContentFilterService.filterPrefsStorageKey);
          await preferences.remove(
            ContentFilterService.filterMigratedStorageKey,
          );
          await filters.reloadFromStorage();

          expect(
            filters.getPreference(ContentLabel.spoiler),
            ContentFilterPreference.warn,
          );
          expect(notifications, 1);
          await filters.reloadFromStorage();
          expect(notifications, 1);
        },
      );
    }

    test('reload awaits revocation of effective adult access', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final store = AccountPreferenceStore(preferences);
      final age = AgeVerificationService(
        preferences: preferences,
        currentPubkeyHex: () => _account,
      );
      await age.initialize();
      await age.setAdultContentVerified(true);
      final releaseRevocation = Completer<void>();
      var revocations = 0;
      final filters = ContentFilterService(
        ageVerificationService: age,
        accountPreferences: store,
        onAdultMediaAccessRevoked: () {
          revocations++;
          return releaseRevocation.future;
        },
      );
      addTearDown(() async {
        if (!releaseRevocation.isCompleted) releaseRevocation.complete();
        await pumpEventQueue();
        filters.dispose();
        store.dispose();
      });
      await filters.initialize();
      await filters.setPreference(
        ContentLabel.nudity,
        ContentFilterPreference.show,
      );
      await filters.setPreference(
        ContentLabel.sexual,
        ContentFilterPreference.show,
      );
      expect(filters.adultPlaybackPreference, ContentFilterPreference.show);
      var notifications = 0;
      filters.addListener(() => notifications++);
      await preferences.remove('content_filter/nudity');
      await preferences.remove('content_filter/sexual');

      var reloadCompleted = false;
      final reload = filters.reloadFromStorage().then(
        (_) => reloadCompleted = true,
      );
      await pumpEventQueue();
      expect(filters.adultPlaybackPreference, ContentFilterPreference.hide);
      expect(revocations, 1);
      expect(notifications, 1);
      expect(reloadCompleted, isFalse);

      releaseRevocation.complete();
      await reload;
      expect(reloadCompleted, isTrue);
    });
  });

  group('content filter pending revocation', () {
    for (final fails in [false, true]) {
      test(
        'awaits revocation across unrelated updates when the callback '
        '${fails ? 'fails' : 'succeeds'}',
        () async {
          SharedPreferences.setMockInitialValues({});
          final preferences = await SharedPreferences.getInstance();
          final repository = FakeAccountState(_account, {
            'content_filter/nudity': 'show',
            'content_filter/sexual': 'show',
          });
          final store = _HeldProjectionStore(preferences);
          await store.bind(repository);
          final age = AgeVerificationService(
            preferences: preferences,
            currentPubkeyHex: () => _account,
          );
          await age.initialize();
          await age.setAdultContentVerified(true);
          final revocationStarted = Completer<void>();
          final releaseRevocation = Completer<void>();
          var revocations = 0;
          final filters = ContentFilterService(
            ageVerificationService: age,
            accountPreferences: store,
            onAdultMediaAccessRevoked: () async {
              revocations++;
              if (revocations == 1) {
                revocationStarted.complete();
                await releaseRevocation.future;
                if (fails) throw StateError('Cache invalidation failed');
              }
            },
          );
          addTearDown(() async {
            if (!store.release.isCompleted) store.release.complete();
            if (!releaseRevocation.isCompleted) releaseRevocation.complete();
            await pumpEventQueue();
            filters.dispose();
            store.dispose();
            await repository.close();
          });
          await filters.initialize();
          expect(filters.adultPlaybackPreference, ContentFilterPreference.show);
          var notifications = 0;
          filters.addListener(() => notifications++);

          var setterCompleted = false;
          final mutation = filters
              .setPreference(ContentLabel.nudity, ContentFilterPreference.hide)
              .then((_) => setterCompleted = true);
          await store.projected.future;
          await revocationStarted.future;
          expect(filters.adultPlaybackPreference, ContentFilterPreference.hide);
          expect(notifications, 1);

          repository.receive({'content_filter/flashing-lights': 'hide'});
          await pumpEventQueue();
          expect(
            filters.getPreference(ContentLabel.flashingLights),
            ContentFilterPreference.hide,
          );
          expect(notifications, 2);
          expect(revocations, 1);
          expect(repository.localWrites, 1);

          store.release.complete();
          await pumpEventQueue();
          expect(
            setterCompleted,
            isFalse,
            reason: 'The original cache invalidation is still pending',
          );

          releaseRevocation.complete();
          await mutation;
          expect(setterCompleted, isTrue);
          expect(notifications, 2);

          // A completed or failed callback must not poison later revocations.
          await filters.setPreference(
            ContentLabel.nudity,
            ContentFilterPreference.show,
          );
          await filters.setPreference(
            ContentLabel.nudity,
            ContentFilterPreference.hide,
          );
          expect(revocations, 2);
          expect(notifications, 4);
        },
      );
    }
  });
}
