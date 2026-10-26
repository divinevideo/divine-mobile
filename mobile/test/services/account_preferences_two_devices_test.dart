import 'dart:async';
import 'dart:convert';

import 'package:account_state_repository/account_state_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/features/appearance/bloc/appearance_cubit.dart';
import 'package:openvine/features/appearance/models/appearance_mode.dart';
import 'package:openvine/features/appearance/repositories/appearance_repository.dart';
import 'package:openvine/services/account_preference_store.dart';
import 'package:openvine/services/audio_sharing_preference_service.dart';
import 'package:openvine/services/divine_host_filter_service.dart';
import 'package:openvine/services/feed_aspect_ratio_preference_service.dart';
import 'package:openvine/services/language_preference_service.dart';
import 'package:openvine/services/stats_visibility_preferences.dart';
import 'package:openvine/services/video_provenance_filter_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_account_state.dart';

class _Client extends Mock implements NostrClient {}

class _Preferences extends Mock implements SharedPreferences {}

SharedPreferences _devicePreferences({
  Future<void> Function(String key, String value)? beforeStringWrite,
}) {
  final data = <String, Object>{};
  final preferences = _Preferences();
  when(() => preferences.get(any()))
      .thenAnswer((call) => data[call.positionalArguments.first]);
  when(() => preferences.getString(any()))
      .thenAnswer((call) => data[call.positionalArguments.first] as String?);
  when(() => preferences.getBool(any()))
      .thenAnswer((call) => data[call.positionalArguments.first] as bool?);
  when(
    () => preferences.getStringList(any()),
  ).thenAnswer((call) => data[call.positionalArguments.first] as List<String>?);
  when(() => preferences.setString(any(), any())).thenAnswer((call) async {
    await beforeStringWrite?.call(
      call.positionalArguments[0] as String,
      call.positionalArguments[1] as String,
    );
    data[call.positionalArguments[0] as String] =
        call.positionalArguments[1] as String;
    return true;
  });
  when(() => preferences.setBool(any(), any())).thenAnswer((call) async {
    data[call.positionalArguments[0] as String] =
        call.positionalArguments[1] as bool;
    return true;
  });
  when(() => preferences.setStringList(any(), any())).thenAnswer((call) async {
    data[call.positionalArguments[0] as String] = List<String>.of(
      call.positionalArguments[1] as List<String>,
    );
    return true;
  });
  when(() => preferences.remove(any())).thenAnswer((call) async {
    data.remove(call.positionalArguments.first);
    return true;
  });
  return preferences;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    registerFallbackValue(<Filter>[]);
    registerFallbackValue(<String>[]);
    registerFallbackValue(Event('0'.padLeft(64, '0'), 1, [], ''));
  });

  group('account preferences across devices', () {
    test('new account projection follows an outstanding native write from the disposed container', () async {
      final blocked = Completer<void>();
      var entered = false;
      final preferences = _devicePreferences(
        beforeStringWrite: (key, value) async {
          if (key == 'content_language' && value == 'es') {
            entered = true;
            await blocked.future;
          }
        },
      );
      final firstRepository = FakeAccountState('1'.padLeft(64, '0'));
      final first = AccountPreferenceStore(preferences);
      await first.bind(firstRepository);
      final writing = first.write('content_language', 'es');
      await pumpEventQueue();
      expect(entered, isTrue);
      final secondRepository = FakeAccountState('2'.padLeft(64, '0'), {
        'content_language': 'ja',
      });
      final second = AccountPreferenceStore(preferences);
      final binding = second.bind(secondRepository);
      first.dispose();
      blocked.complete();
      await writing;
      await binding;
      expect(preferences.getString('content_language'), 'ja');
      expect(second.read('content_language'), 'ja');
      second.dispose();
      await firstRepository.close();
      await secondRepository.close();
    });

    test('explicit default choices before first sync beat older signed remote opposites', () async {
      final signer = LocalNostrSigner('1'.padLeft(64, '0'));
      final pubkey = (await signer.getPublicKey())!;
      final opposites = <String, Object?>{
        'feed_aspect_ratio_preference': 'squareOnly',
        'appearance_mode_preference': 'light',
        'stats_show_video_loops': true,
        'show_verified_only': true,
        'show_divine_hosted_only': false,
      };
      final ciphertext = (await signer.nip44Encrypt(
        pubkey,
        jsonEncode({
          'version': 1,
          'entries': {
            for (final entry in opposites.entries)
              entry.key: {'value': entry.value, 'updated_at': 1},
          },
        }),
      ))!;
      final old = (await signer.signEvent(
        Event(
          pubkey,
          EventKind.appSpecificData,
          [
            ['d', 'divine/preferences/v1'],
          ],
          ciphertext,
          createdAt: 1,
        ),
      ))!;
      final relay = [old];
      final client = _Client();
      when(
        () => client.queryEventsDetailed(
          any(),
          useCache: false,
          requireAllRelaysSettled: true,
        ),
      ).thenAnswer(
        (_) async => (events: relay.toList(), timedOut: false, noRelays: false),
      );
      when(() => client.publishEventAwaitOk(any())).thenAnswer((call) async {
        final event = call.positionalArguments.first as Event;
        relay.add(event);
        return PublishOutcome(
          eventId: event.id,
          acceptedBy: ['wss://relay.example'],
          rejectedBy: {},
          noResponseFrom: [],
        );
      });
      final preferences = _devicePreferences();
      final repository = AccountStateRepository(
        nostrClient: client,
        sharedPreferences: preferences,
        pubkey: pubkey,
        signer: () => signer,
        namespace: 'divine/preferences/v1',
      );
      final port = AccountPreferenceStore(preferences);
      await port.bind(repository);
      final shape = FeedAspectRatioPreferenceService(
        preferences,
        accountPreferences: port,
      );
      final appearance = AppearanceCubit(
        AppearanceRepository(preferences, accountPreferences: port),
      );
      final stats = StatsVisibilityPreferences(
        preferences,
        accountPreferences: port,
      );
      final provenance = VideoProvenanceFilterService(
        preferences,
        accountPreferences: port,
      );
      final hosting = DivineHostFilterService(
        preferences,
        accountPreferences: port,
      );
      await shape.setPreference(FeedAspectRatioPreference.squareAndPortrait);
      await appearance.setMode(defaultAppearanceMode);
      await stats.setShowVideoLoops(false);
      await provenance.setShowVerifiedOnly(false);
      await hosting.setShowDivineHostedOnly(true);
      await repository.synchronize();
      await pumpEventQueue();
      expect(repository.values, {
        'feed_aspect_ratio_preference': 'squareAndPortrait',
        'appearance_mode_preference': defaultAppearanceMode.name,
        'stats_show_video_loops': false,
        'show_verified_only': false,
        'show_divine_hosted_only': true,
      });
      expect(shape.preference, FeedAspectRatioPreference.squareAndPortrait);
      expect(appearance.state, defaultAppearanceMode);
      expect(stats.showVideoLoops, isFalse);
      expect(provenance.showVerifiedOnly, isFalse);
      expect(hosting.showDivineHostedOnly, isTrue);
      shape.dispose();
      await appearance.close();
      stats.dispose();
      provenance.dispose();
      hosting.dispose();
      port.dispose();
      await repository.close();
    });

    test('real encrypted settings retain offline restart edits, merge fields and propagate reset between two stores', () async {
      final client = _Client();
      final signer = LocalNostrSigner('1'.padLeft(64, '0'));
      final pubkey = (await signer.getPublicKey())!;
      final relay = <Event>[];
      var offline = true;
      when(
        () => client.queryEventsDetailed(
          any(),
          useCache: false,
          requireAllRelaysSettled: true,
        ),
      ).thenAnswer(
        (_) async => (
          events: offline ? <Event>[] : relay.toList(),
          timedOut: false,
          noRelays: offline,
        ),
      );
      when(() => client.publishEventAwaitOk(any())).thenAnswer((call) async {
        final event = call.positionalArguments.first as Event;
        if (!offline) relay.add(event);
        return PublishOutcome(
          eventId: event.id,
          acceptedBy: offline ? [] : ['wss://relay.example'],
          rejectedBy: {},
          noResponseFrom: [],
        );
      });
      final firstPreferences = _devicePreferences();
      final secondPreferences = _devicePreferences();
      AccountStateRepository repository(SharedPreferences preferences) =>
          AccountStateRepository(
            nostrClient: client,
            sharedPreferences: preferences,
            pubkey: pubkey,
            signer: () => signer,
            namespace: 'divine/preferences/v1',
          );
      var first = repository(firstPreferences);
      var firstPort = AccountPreferenceStore(firstPreferences);
      await firstPort.bind(first);
      var firstLanguage = LanguagePreferenceService(
        accountPreferences: firstPort,
      );
      await firstLanguage.setContentLanguage('es');
      await expectLater(
        first.synchronize(),
        throwsA(isA<AccountStateException>()),
      );
      expect(first.hasPendingChanges, isTrue);
      firstLanguage.dispose();
      firstPort.dispose();
      await first.close();

      first = repository(firstPreferences);
      firstPort = AccountPreferenceStore(firstPreferences);
      await firstPort.bind(first);
      firstLanguage = LanguagePreferenceService(accountPreferences: firstPort);
      final firstAudio = AudioSharingPreferenceService(
        firstPreferences,
        accountPreferences: firstPort,
      );
      await firstLanguage.initialize();
      expect(firstLanguage.declaredContentLanguage, 'es');
      final second = repository(secondPreferences);
      final secondPort = AccountPreferenceStore(secondPreferences);
      await secondPort.bind(second);
      final secondLanguage = LanguagePreferenceService(
        accountPreferences: secondPort,
      );
      final secondAudio = AudioSharingPreferenceService(
        secondPreferences,
        accountPreferences: secondPort,
      );
      await secondLanguage.initialize();
      await secondAudio.setAudioSharingEnabled(true);
      offline = false;
      await first.synchronize();
      await second.synchronize();
      await first.synchronize();
      await pumpEventQueue();
      expect(secondLanguage.declaredContentLanguage, 'es');
      expect(firstAudio.isAudioSharingEnabled, isTrue);
      await secondLanguage.clearContentLanguage();
      await second.synchronize();
      await first.synchronize();
      await pumpEventQueue();
      expect(firstLanguage.declaredContentLanguage, isNull);
      expect(first.contains('content_language'), isTrue);
      expect(first.value('content_language'), isNull);
      expect(first.value('audio_sharing_enabled'), isTrue);
      firstLanguage.dispose();
      firstAudio.dispose();
      secondLanguage.dispose();
      secondAudio.dispose();
      firstPort.dispose();
      secondPort.dispose();
      await first.close();
      await second.close();
    });
  });
}
