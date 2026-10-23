import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/models/content_label.dart';
import 'package:openvine/models/notification_preferences.dart';
import 'package:openvine/services/account_preference_store.dart';
import 'package:openvine/services/age_verification_service.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/content_filter_service.dart';
import 'package:openvine/services/language_preference_service.dart';
import 'package:openvine/services/moderation_label_service.dart';
import 'package:openvine/services/notification_preferences_service.dart';
import 'package:openvine/services/subtitle_language_preference_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_account_state.dart';

class _Client extends Mock implements NostrClient {}

class _Auth extends Mock implements AuthService {}

class _PushStore extends Mock implements NotificationPreferencesStore {}

class _HeldProjectionStore extends AccountPreferenceStore {
  _HeldProjectionStore(super._preferences);
  final persisted = Completer<void>();
  final release = Completer<void>();
  bool _held = false;

  @override
  Future<void> writeValues(Map<String, Object?> values) async {
    await super.writeValues(values);
    if (!_held) {
      _held = true;
      persisted.complete();
      await release.future;
    }
  }
}

const _first =
    '1111111111111111111111111111111111111111111111111111111111111111';
const _second =
    '2222222222222222222222222222222222222222222222222222222222222222';
const _labeler =
    '3333333333333333333333333333333333333333333333333333333333333333';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => registerFallbackValue(const NotificationPreferences()));
  group('service mutation account ownership', () {
    for (final preload in [false, true]) {
      group(preload ? 'preloaded services' : 'first-use services', () {
        for (final mutation in [
          'content language',
          'content language reset',
          'subtitle target',
          'subtitle target reset',
          'subtitle originals',
          'labeler addition',
          'labeler removal',
          'followed moderation',
          'notification flags',
        ]) {
          test(
            '$mutation rejects a switch before its first durable write',
            () async {
              SharedPreferences.setMockInitialValues({});
              final preferences = await SharedPreferences.getInstance();
              final port = AccountPreferenceStore(preferences);
              final first = FakeAccountState(_first);
              final second = FakeAccountState(_second);
              await port.bind(first);
              var owner = _first;
              final language = LanguagePreferenceService(
                accountPreferences: port,
              );
              final subtitles = SubtitleLanguagePreferenceService(
                accountPreferences: port,
              );
              final moderation = ModerationLabelService(
                nostrClient: _Client(),
                authService: _Auth(),
                sharedPreferences: preferences,
                accountPreferences: port,
                canQueryRelays: () => false,
              );
              final pushStore = _PushStore();
              when(() => pushStore.markDirty(any(), any()))
                  .thenAnswer((_) async {});
              final notifications = NotificationPreferencesService(
                store: pushStore,
                currentPubkey: () => owner,
                publishPreferences: (_, _) async => false,
                accountPreferences: port,
              );
              if (preload) {
                await language.initialize();
                await subtitles.initialize();
                await moderation.ensureLoaded();
                await notifications.loadPreferences();
              }
              final operation = switch (mutation) {
                'content language' => language.setContentLanguage('es'),
                'content language reset' => language.clearContentLanguage(),
                'subtitle target' => subtitles.setTargetLanguage('es'),
                'subtitle target reset' => subtitles.setTargetLanguage(null),
                'subtitle originals' => subtitles.setKeepOriginalLanguages({
                  'es',
                }),
                'labeler addition' => moderation.addLabeler(_labeler),
                'labeler removal' => moderation.removeLabeler(_labeler),
                'followed moderation' =>
                  moderation.setFollowingModerationEnabled(true),
                _ => notifications.updatePreferences(
                  const NotificationPreferences(likesEnabled: false),
                ),
              };
              final outcome = operation.then<Object?>(
                (_) => null,
                onError: (Object error, StackTrace _) => error,
              );
              owner = _second;
              await port.bind(second);
              final error = await outcome;
              expect(
                second.values,
                isEmpty,
                reason: 'The action belongs to the outgoing account',
              );
              expect(
                error,
                isA<StateError>(),
                reason: 'An aborted operation must report cancellation',
              );
              language.dispose();
              subtitles.dispose();
              moderation.dispose();
              notifications.dispose();
              port.dispose();
              await first.close();
              await second.close();
            },
          );
        }
      });
    }

    test('category lock cannot send later fields to the incoming account after a completed write', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final port = _HeldProjectionStore(preferences);
      final first = FakeAccountState(_first);
      final second = FakeAccountState(_second);
      await port.bind(first);
      final age = AgeVerificationService(
        preferences: preferences,
        currentPubkeyHex: () => _first,
      );
      final filters = ContentFilterService(
        ageVerificationService: age,
        accountPreferences: port,
      );
      final operation = filters.lockAdultCategories().then<Object?>(
        (_) => null,
        onError: (Object error, StackTrace _) => error,
      );
      await port.persisted.future;
      await port.bind(second);
      port.release.complete();
      final error = await operation;
      expect(second.values, isEmpty);
      expect(error, isA<StateError>());
      filters.dispose();
      port.dispose();
      await first.close();
      await second.close();
    });
  });

  group('account-backed age re-confirmation', () {
    test('promotes only eligible locked categories and persists the effective choices', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final port = AccountPreferenceStore(preferences);
      final repository = FakeAccountState(_first);
      await port.bind(repository);
      final age = AgeVerificationService(
        preferences: preferences,
        currentPubkeyHex: () => _first,
      );
      final filters = ContentFilterService(
        ageVerificationService: age,
        accountPreferences: port,
      );
      await filters.initialize();
      await age.setAdultContentVerified(false);
      await filters.lockAdultCategories();
      await age.setAdultContentVerified(true);
      await filters.unlockAdultCategories();
      for (final label in [
        ContentLabel.alcohol,
        ContentLabel.tobacco,
        ContentLabel.profanity,
        ContentLabel.gambling,
      ]) {
        expect(filters.getPreference(label), ContentFilterPreference.warn);
        expect(repository.value('content_filter/${label.value}'), 'warn');
      }
      for (final label in [
        ContentLabel.nudity,
        ContentLabel.sexual,
        ContentLabel.drugs,
      ]) {
        expect(filters.getPreference(label), ContentFilterPreference.hide);
        expect(repository.value('content_filter/${label.value}'), 'hide');
      }
      filters.dispose();
      port.dispose();
      await repository.close();
    });

    test(
      'protected minors cannot promote synced age-restricted preferences',
      () async {
        SharedPreferences.setMockInitialValues({});
        final preferences = await SharedPreferences.getInstance();
        final port = AccountPreferenceStore(preferences);
        final repository = FakeAccountState(_first);
        await port.bind(repository);
        final age = AgeVerificationService(
          preferences: preferences,
          currentPubkeyHex: () => _first,
          isProtectedMinor: () => true,
        );
        final filters = ContentFilterService(
          ageVerificationService: age,
          accountPreferences: port,
        );
        await filters.initialize();
        await filters.lockAdultCategories();
        await age.setAdultContentVerified(true);
        await filters.unlockAdultCategories();
        expect(
          filters.getPreference(ContentLabel.alcohol),
          ContentFilterPreference.hide,
        );
        expect(
          repository.value('content_filter/${ContentLabel.alcohol.value}'),
          'hide',
        );
        filters.dispose();
        port.dispose();
        await repository.close();
      },
    );
  });
}
