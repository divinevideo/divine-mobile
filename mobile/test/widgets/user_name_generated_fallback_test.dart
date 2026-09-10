// ABOUTME: Pins UserName's fallback precedence — the signed-in user must
// ABOUTME: never be shown a generated "Adjective Animal NN" name (#6423).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/widgets/user_name.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockProfileRepository extends Mock implements ProfileRepository {}

void main() {
  // Synthetic full-length pubkey chosen for a stable generated fallback.
  const pubkey =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

  /// What `UserProfile.defaultDisplayNameFor` invents for [pubkey] — the
  /// kind of string the reporter saw in place of their own name.
  final generatedName = UserProfile.defaultDisplayNameFor(pubkey);

  Future<Widget> buildSubject({
    required ProfileReader? repository,
    String? anonymousName,
    bool neverGenerateName = false,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        profileReadRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: UserName.fromPubKey(
              pubkey,
              anonymousName: anonymousName,
              neverGenerateName: neverGenerateName,
            ),
          ),
        ),
      ),
    );
  }

  group(UserName, () {
    test('the generated name is a plausible human name, not an npub', () {
      // Guards the premise of every assertion below: if the app-wide fallback
      // strategy changes back to a truncated npub, these tests stop testing
      // what they claim to and should be revisited.
      expect(generatedName, matches(RegExp(r'^\w+ \w+ \d+$')));
    });

    testWidgets(
      'renders the cached profile name when the signing gate is shut',
      (tester) async {
        final repository = _MockProfileRepository();
        final cached = UserProfile(
          pubkey: pubkey,
          name: 'Wolf',
          rawData: const {},
          createdAt: DateTime.utc(2026),
          eventId: 'kind0_event_id',
        );
        when(
          () => repository.getCachedProfile(pubkey: pubkey),
        ).thenAnswer((_) async => cached);
        when(
          () => repository.watchProfile(pubkey: pubkey),
        ).thenAnswer((_) => Stream<UserProfile?>.value(cached));

        await tester.pumpWidget(await buildSubject(repository: repository));
        await tester.pumpAndSettle();

        expect(find.text('Wolf'), findsOneWidget);
        expect(find.text(generatedName), findsNothing);
      },
    );

    testWidgets('falls back to the generated name for other users', (
      tester,
    ) async {
      // The generated handle is still the right treatment for a stranger
      // whose profile has not resolved — this is the control arm proving the
      // assertions below are about the own-identity opt-in, not about the
      // fallback disappearing everywhere.
      await tester.pumpWidget(await buildSubject(repository: null));
      await tester.pumpAndSettle();

      expect(find.text(generatedName), findsOneWidget);
    });

    testWidgets('honours anonymousName instead of generating one', (
      tester,
    ) async {
      // Before #6423 this hint was threaded down by the profile header and
      // then silently dropped, so the header's displayNameHint could never
      // reach the failure case it existed for.
      await tester.pumpWidget(
        await buildSubject(repository: null, anonymousName: 'Wolf'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Wolf'), findsOneWidget);
      expect(find.text(generatedName), findsNothing);
    });

    testWidgets('renders nothing rather than a generated name for self', (
      tester,
    ) async {
      await tester.pumpWidget(
        await buildSubject(repository: null, neverGenerateName: true),
      );
      await tester.pumpAndSettle();

      expect(find.text(generatedName), findsNothing);
      expect(find.text(''), findsOneWidget);
    });

    testWidgets(
      'suppresses the generated name for a resolved but nameless profile',
      (tester) async {
        // A kind-0 that exists but carries neither name nor display_name is a
        // state users reach: publishing from divine-web with an empty name
        // strips both fields. Without the opt-in this resolved-profile path
        // falls through to the generated handle just like the unresolved one.
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final nameless = UserProfile(
          pubkey: pubkey,
          rawData: const {},
          createdAt: DateTime.utc(2026),
          eventId: 'kind0_event_id',
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
            child: MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: Center(
                  child: UserName.fromUserProfile(
                    nameless,
                    neverGenerateName: true,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(generatedName), findsNothing);
      },
    );

    testWidgets(
      'uses anonymousName as the steady state for a nameless own profile',
      (tester) async {
        // Own-profile surfaces pass a concrete handle/npub placeholder so the
        // generated-name suppression does not leave the title line blank.
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final nameless = UserProfile(
          pubkey: pubkey,
          rawData: const {},
          createdAt: DateTime.utc(2026),
          eventId: 'kind0_event_id',
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
            child: MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: Center(
                  child: UserName.fromUserProfile(
                    nameless,
                    anonymousName: 'npub_placeholder',
                    neverGenerateName: true,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('npub_placeholder'), findsOneWidget);
        expect(find.text(generatedName), findsNothing);
        expect(find.text(''), findsNothing);
      },
    );
  });
}
