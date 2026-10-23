import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/providers/account_preferences_provider.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/preferences_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Client extends Mock implements NostrClient {}

class _Session extends NostrSession {
  _Session(this.initial);
  final NostrSessionReadiness initial;
  @override
  NostrSessionReadiness build() => initial;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    registerFallbackValue(<Filter>[]);
    registerFallbackValue(Event('0'.padLeft(64, '0'), 1, [], ''));
  });

  group('account preference provider lifecycle', () {
    test(
      'identity-known edits survive readiness; signed-out bridge quarantines old projection',
      () async {
        SharedPreferences.setMockInitialValues({});
        final preferences = await SharedPreferences.getInstance();
        final client = _Client();
        final signer = LocalNostrSigner('1'.padLeft(64, '0'));
        final pubkey = (await signer.getPublicKey())!;
        final events = StreamController<Event>.broadcast();
        final statuses =
            StreamController<Map<String, RelayConnectionStatus>>.broadcast();
        when(() => client.signer).thenReturn(signer);
        when(() => client.hasKeys).thenReturn(true);
        when(() => client.publicKey).thenReturn(pubkey);
        when(() => client.subscribe(any())).thenAnswer((_) => events.stream);
        when(() => client.relayStatusStream).thenAnswer((_) => statuses.stream);
        when(
          () => client.queryEventsDetailed(
            any(),
            useCache: false,
            requireAllRelaysSettled: true,
          ),
        ).thenAnswer(
          (_) async => (events: <Event>[], timedOut: false, noRelays: true),
        );
        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(preferences),
            nostrServiceProvider.overrideWithValue(client),
            nostrSessionProvider.overrideWith(
              () =>
                  _Session(NostrSessionReadiness.identityKnown(pubkey: pubkey)),
            ),
          ],
        );
        final binding = container.listen(
          accountPreferenceSyncProvider,
          (_, _) {},
        );
        final language = container.read(languagePreferenceServiceProvider);
        final versions = <int>[];
        final version = container.listen(
          languagePreferenceVersionProvider,
          (_, next) => versions.add(next),
        );
        await pumpEventQueue();
        final before = container.read(accountPreferenceSyncProvider);
        await language.setContentLanguage('ja');
        expect(before!.value('content_language'), 'ja');
        verifyNever(() => client.subscribe(any()));
        container
            .read(nostrSessionProvider.notifier)
            .update(
              NostrSessionReadiness.nostrReady(pubkey: pubkey, client: client),
            );
        await pumpEventQueue();
        expect(
          identical(container.read(accountPreferenceSyncProvider), before),
          isTrue,
        );
        expect(language.declaredContentLanguage, 'ja');
        verify(() => client.subscribe(any())).called(1);
        container
            .read(nostrSessionProvider.notifier)
            .update(const NostrSessionReadiness.signedOut());
        await pumpEventQueue();
        expect(container.read(accountPreferenceSyncProvider), isNull);
        expect(language.declaredContentLanguage, isNull);
        expect(versions, isNotEmpty);
        version.close();
        binding.close();
        container.dispose();
        await events.close();
        await statuses.close();
      },
    );

    test(
      'initial signed-out state never exposes prior account language',
      () async {
        SharedPreferences.setMockInitialValues({'content_language': 'es'});
        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(
              await SharedPreferences.getInstance(),
            ),
            nostrSessionProvider.overrideWith(
              () => _Session(const NostrSessionReadiness.signedOut()),
            ),
          ],
        );
        final binding = container.listen(
          accountPreferenceSyncProvider,
          (_, _) {},
        );
        final language = container.read(languagePreferenceServiceProvider);
        await language.initialize();
        expect(language.declaredContentLanguage, isNull);
        binding.close();
        container.dispose();
      },
    );
  });
}
