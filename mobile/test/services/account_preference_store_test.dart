import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/audio_sharing/audio_sharing_cubit.dart';
import 'package:openvine/blocs/content_filters/content_filters_cubit.dart';
import 'package:openvine/blocs/language_setting/language_setting_cubit.dart';
import 'package:openvine/blocs/locale/locale_cubit.dart';
import 'package:openvine/features/appearance/bloc/appearance_cubit.dart';
import 'package:openvine/features/appearance/models/appearance_mode.dart';
import 'package:openvine/features/appearance/repositories/appearance_repository.dart';
import 'package:openvine/models/content_label.dart';
import 'package:openvine/services/account_preference_store.dart';
import 'package:openvine/services/age_verification_service.dart';
import 'package:openvine/services/audio_sharing_preference_service.dart';
import 'package:openvine/services/content_filter_service.dart';
import 'package:openvine/services/divine_host_filter_service.dart';
import 'package:openvine/services/feed_aspect_ratio_preference_service.dart';
import 'package:openvine/services/language_preference_service.dart';
import 'package:openvine/services/locale_preference_service.dart';
import 'package:openvine/services/stats_visibility_preferences.dart';
import 'package:openvine/services/subtitle_language_preference_service.dart';
import 'package:openvine/services/video_provenance_filter_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_account_state.dart';

const _accountA =
    '1111111111111111111111111111111111111111111111111111111111111111';
const _accountB =
    '2222222222222222222222222222222222222222222222222222222222222222';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences preferences;
  late AccountPreferenceStore store;
  late FakeAccountState repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    store = AccountPreferenceStore(preferences);
    repository = FakeAccountState(_accountA);
    await store.bind(repository);
  });
  tearDown(() async {
    store.dispose();
    await repository.close();
  });

  group('account preference projection', () {
    test('untouched defaults are never seeded or published', () async {
      final host = DivineHostFilterService(
        preferences,
        accountPreferences: store,
      );
      final stats = StatsVisibilityPreferences(
        preferences,
        accountPreferences: store,
      );
      expect(host.showDivineHostedOnly, isTrue);
      expect(stats.showTotalLoops, isTrue);
      expect(repository.values, isEmpty);
      expect(repository.localWrites, 0);
      host.dispose();
      stats.dispose();
    });

    test(
      'remote choices and explicit resets refresh services and open Cubits without echo',
      () async {
        final language = LanguagePreferenceService(accountPreferences: store);
        final subtitles = SubtitleLanguagePreferenceService(
          accountPreferences: store,
        );
        final audio = AudioSharingPreferenceService(
          preferences,
          accountPreferences: store,
        );
        final host = DivineHostFilterService(
          preferences,
          accountPreferences: store,
        );
        final provenance = VideoProvenanceFilterService(
          preferences,
          accountPreferences: store,
        );
        final shape = FeedAspectRatioPreferenceService(
          preferences,
          accountPreferences: store,
        );
        final stats = StatsVisibilityPreferences(
          preferences,
          accountPreferences: store,
        );
        final locale = LocaleCubit(
          localePreferenceService: LocalePreferenceService(
            sharedPreferences: preferences,
            accountPreferences: store,
          ),
        );
        final appearance = AppearanceCubit(
          AppearanceRepository(preferences, accountPreferences: store),
        );
        final languageCubit = LanguageSettingCubit(service: language);
        final audioCubit = AudioSharingCubit(service: audio)..load();
        await languageCubit.load();
        await subtitles.initialize();
        repository.receive({
          'content_language': 'es',
          'subtitle_target_language': 'de',
          'subtitle_keep_original_languages': ['ja'],
          'audio_sharing_enabled': true,
          'show_divine_hosted_only': false,
          'show_verified_only': true,
          'feed_aspect_ratio_preference': 'squareOnly',
          'stats_show_video_loops': true,
          'app_locale': 'fr',
          'appearance_mode_preference': 'light',
        });
        await pumpEventQueue();
        expect(languageCubit.state.currentCode, 'es');
        expect(subtitles.targetLanguage, 'de');
        expect(subtitles.keepOriginalLanguages, {'ja'});
        expect(audioCubit.state.isEnabled, isTrue);
        expect(host.showDivineHostedOnly, isFalse);
        expect(provenance.showVerifiedOnly, isTrue);
        expect(shape.preference, FeedAspectRatioPreference.squareOnly);
        expect(stats.showVideoLoops, isTrue);
        expect(locale.state.locale?.languageCode, 'fr');
        expect(appearance.state, AppearanceMode.light);
        expect(repository.localWrites, 0);

        repository.receive({
          for (final key in repository.values.keys) key: null,
        });
        await pumpEventQueue();
        expect(language.declaredContentLanguage, isNull);
        expect(subtitles.targetLanguage, isNull);
        expect(subtitles.keepOriginalLanguages, isEmpty);
        expect(audioCubit.state.isEnabled, isFalse);
        expect(host.showDivineHostedOnly, isTrue);
        expect(provenance.showVerifiedOnly, isFalse);
        expect(shape.preference, FeedAspectRatioPreference.squareAndPortrait);
        expect(stats.showVideoLoops, isFalse);
        expect(locale.state.locale, isNull);
        expect(appearance.state, defaultAppearanceMode);
        expect(repository.localWrites, 0);

        await locale.close();
        await appearance.close();
        await languageCubit.close();
        await audioCubit.close();
        language.dispose();
        subtitles.dispose();
        audio.dispose();
        host.dispose();
        provenance.dispose();
        shape.dispose();
        stats.dispose();
      },
    );

    test('clearing an already-unset language is a durable reset', () async {
      final language = LanguagePreferenceService(accountPreferences: store);
      await language.clearContentLanguage();
      expect(repository.contains('content_language'), isTrue);
      expect(repository.value('content_language'), isNull);
      expect(repository.localWrites, 1);
      language.dispose();
    });

    test(
      'account switch isolates values and rejects outgoing asynchronous completion',
      () async {
        repository.pendingWrite = Completer<void>();
        final oldWrite = store.write('content_language', 'es');
        final rejected = expectLater(oldWrite, throwsStateError);
        final second = FakeAccountState(_accountB, {'content_language': 'ja'});
        await store.bind(second);
        repository.pendingWrite!.complete();
        await rejected;
        expect(store.read('content_language'), 'ja');
        expect(preferences.getString('content_language'), 'ja');
        expect(second.localWrites, 0);
        repository.receive({'content_language': 'de'});
        await pumpEventQueue();
        expect(store.read('content_language'), 'ja');
        await second.close();
      },
    );

    test(
      'remote category settings cannot bypass protected-minor and local age gates',
      () async {
        var protectedMinor = true;
        final age = AgeVerificationService(
          preferences: preferences,
          currentPubkeyHex: () => _accountA,
          isProtectedMinor: () => protectedMinor,
        );
        final filters = ContentFilterService(
          ageVerificationService: age,
          accountPreferences: store,
        );
        final cubit = ContentFiltersCubit(
          contentFilterService: filters,
          ageVerificationService: age,
        );
        await cubit.load();
        repository.receive({
          'content_filter/nudity': 'show',
          'content_filter/flashing-lights': 'hide',
        });
        await pumpEventQueue();
        expect(
          filters.getPreference(ContentLabel.nudity),
          ContentFilterPreference.hide,
        );
        expect(
          cubit.state.preferences[ContentLabel.nudity],
          ContentFilterPreference.hide,
        );
        protectedMinor = false;
        expect(
          filters.getPreference(ContentLabel.nudity),
          ContentFilterPreference.hide,
        );
        await filters.setPreference(
          ContentLabel.nudity,
          ContentFilterPreference.show,
        );
        expect(repository.localWrites, 0);
        await cubit.close();
        filters.dispose();
      },
    );

    test(
      'only explicit legacy fields with proven matching owner seed absent entries',
      () async {
        await preferences.setString('current_user_pubkey_hex', _accountB);
        await preferences.setString('content_language', 'es');
        // Projection is proven to belong to A, so B cannot inherit it even if the
        // account activation marker has already advanced.
        final second = FakeAccountState(_accountB);
        await store.bind(second);
        expect(second.values, isEmpty);
        await preferences.remove(
          AccountPreferenceStore.projectionOwnerStorageKey,
        );
        final third = FakeAccountState(_accountB, {'app_locale': 'fr'});
        await preferences.setString('content_language', 'ja');
        await preferences.setString('app_locale', 'es');
        await store.bind(third);
        expect(third.value('content_language'), 'ja');
        expect(third.value('app_locale'), 'fr');
        expect(third.values.keys, isNot(contains('content_filter/nudity')));
        await second.close();
        await third.close();
      },
    );

    test('legacy category migration imports deviations and never materialized defaults', () async {
      await preferences.remove(
        AccountPreferenceStore.projectionOwnerStorageKey,
      );
      await preferences.setString('current_user_pubkey_hex', _accountB);
      await preferences.setString(
        'content_filter_prefs',
        jsonEncode({
          ContentLabel.nudity.value: 'hide',
          ContentLabel.flashingLights.value: 'show',
        }),
      );
      final second = FakeAccountState(_accountB);
      await store.bind(second);
      expect(second.values, {
        'content_filter/${ContentLabel.flashingLights.value}': 'show',
      });
      await second.close();
    });

    test('unregistered device and permission fields are refused', () async {
      await expectLater(
        store.write('adult_content_verified', true),
        throwsArgumentError,
      );
      await expectLater(
        store.write('preferred_audio_device', 'device'),
        throwsArgumentError,
      );
      await expectLater(
        store.write('appearance_mode_preference', 'invalid'),
        throwsArgumentError,
      );
      expect(repository.localWrites, 0);
    });

    test('disposed adapter ignores late account events', () async {
      final detached = AccountPreferenceStore(preferences);
      await detached.bind(repository);
      var notifications = 0;
      detached.changes.listen((_) => notifications++);
      detached.dispose();
      repository.receive({'app_locale': 'fr'});
      await pumpEventQueue();
      expect(notifications, 0);
    });
  });
}
