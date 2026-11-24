// ABOUTME: Widget tests for the single-platform verify connect form.
// ABOUTME: Covers when sign-in is offered, the manual account fallback used
// ABOUTME: when a proof link is opaque, approving a returned sign-in, and the
// ABOUTME: Divine Confirmation card and refusal sheet.

import 'dart:async';

import 'package:analytics/analytics.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart' hide VerificationResult;
import 'package:openvine/blocs/verify/confirmation_requirement.dart';
import 'package:openvine/blocs/verify/verify_connect_cubit.dart';
import 'package:openvine/features/confirmation/confirmation_access_providers.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/features/oauth/app_oauth_support.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/auth_state.dart';
import 'package:openvine/providers/analytics_providers.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/supporter_providers.dart';
import 'package:openvine/screens/verify/verify_connect_screen.dart';
import 'package:openvine/screens/verify/verify_platform_labels.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:verifier_client/verifier_client.dart' show SigninRequirement;

import '../../helpers/test_provider_overrides.dart';

class _MockIdentityClaimsRepository extends Mock
    implements IdentityClaimsRepository {}

class _MockAnalyticsEventSink extends Mock implements AnalyticsEventSink {}

class _MockSignedIdentityClaim extends Mock implements SignedIdentityClaim {}

class _MockVerifyConnectCubit extends MockCubit<VerifyConnectState>
    implements VerifyConnectCubit {}

/// Collects what the screen hands to screen readers.
List<Object?> _captureAnnouncements(WidgetTester tester) {
  final announced = <Object?>[];
  tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(
    SystemChannels.accessibility,
    (message) async {
      if (message is Map && message['type'] == 'announce') {
        announced.add((message['data'] as Map?)?['message']);
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger
        .setMockDecodedMessageHandler<Object?>(
          SystemChannels.accessibility,
          null,
        ),
  );
  return announced;
}

const _pubkey =
    '1111111111111111111111111111111111111111111111111111111111111111';
const _npub = 'npub1zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zygsh9cc9';
const _returnUrl = 'https://divine.video/app/callback';
const _telegram = VerifierPlatform(
  key: 'telegram',
  label: 'Telegram',
  supported: true,
);
const _bluesky = VerifierPlatform(
  key: 'bluesky',
  label: 'Bluesky',
  supported: true,
);

/// A reader that never knows, which shows sign-in as before.
Future<ConfirmationAccess> _unknownAccess({bool refresh = false}) async =>
    ConfirmationAccess.unknown;

void main() {
  group(VerifyConnectPage, () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    late _MockIdentityClaimsRepository repository;

    setUp(() {
      repository = _MockIdentityClaimsRepository();
    });

    Future<void> pump(
      WidgetTester tester, {
      required String platformKey,
      bool deviceSupportsOAuth = true,
      String? replacingIdentity,
      bool confirmationSignIn = false,
      ConfirmationAccessReader readConfirmationAccess = _unknownAccess,
      bool canBuy = true,
      bool simulateConfirmationRequirement = false,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            identityClaimsRepositoryProvider.overrideWithValue(repository),
            supporterStoreBillingAvailableProvider.overrideWithValue(canBuy),
            isFeatureEnabledProvider(
              FeatureFlag.confirmationSignIn,
            ).overrideWithValue(confirmationSignIn),
            confirmationAccessReaderProvider.overrideWithValue(
              readConfirmationAccess,
            ),
            simulateConfirmationRequirementProvider.overrideWithValue(
              simulateConfirmationRequirement,
            ),
            authServiceProvider.overrideWithValue(
              createMockAuthService(
                authState: AuthState.authenticated,
                currentPublicKeyHex: _pubkey,
              ),
            ),
            currentAuthStateProvider.overrideWithValue(
              AuthState.authenticated,
            ),
            appOAuthSupportProvider.overrideWith(
              (ref) async => deviceSupportsOAuth,
            ),
            analyticsEventSinkProvider.overrideWithValue(
              const NoOpAnalyticsEventSink(),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: VineTheme.theme,
            home: VerifyConnectPage(
              platformKey: platformKey,
              replacingIdentity: replacingIdentity,
            ),
          ),
        ),
      );
      await tester.pump();
    }

    Finder signInButton(String platformKey) => find.text(
      l10n.verifyConnectOauthCta(verifyPlatformLabel(platformKey)),
    );

    testWidgets(
      'offers only the proof post when the list said sign-in is off',
      (tester) async {
        const twitterOff = VerifierPlatform(
          key: 'twitter',
          label: 'Twitter / X',
          supported: true,
          oauth: false,
        );
        // Never answers, so only the list's entry can be what hides it.
        when(
          () => repository.startingPlatform('twitter'),
        ).thenReturn(twitterOff);
        when(
          () => repository.platform('twitter'),
        ).thenAnswer((_) => Completer<VerifierPlatform>().future);

        await pump(tester, platformKey: 'twitter');

        expect(signInButton('twitter'), findsNothing);
        expect(find.text(l10n.verifyConnectProofCta), findsOneWidget);
      },
    );

    const blueskyOn = VerifierPlatform(
      key: 'bluesky',
      label: 'Bluesky',
      supported: true,
      oauth: true,
    );

    testWidgets('offers sign-in from the first frame when the list said it '
        'is on', (tester) async {
      // Never answers: the screen must not need loadPlatform to show it.
      when(
        () => repository.startingPlatform('bluesky'),
      ).thenReturn(blueskyOn);
      when(
        () => repository.platform('bluesky'),
      ).thenAnswer((_) => Completer<VerifierPlatform>().future);

      await pump(tester, platformKey: 'bluesky');

      expect(signInButton('bluesky'), findsOneWidget);
    });

    testWidgets('fills in the handle of the link it renews', (tester) async {
      when(
        () => repository.startingPlatform('bluesky'),
      ).thenReturn(blueskyOn);
      when(
        () => repository.platform('bluesky'),
      ).thenAnswer((_) => Completer<VerifierPlatform>().future);

      await pump(
        tester,
        platformKey: 'bluesky',
        replacingIdentity: 'alice.bsky.social',
      );

      // Shown in the field the sign-in reads it from, not only held behind it.
      expect(
        find.widgetWithText(TextField, 'alice.bsky.social'),
        findsOneWidget,
      );
    });

    testWidgets("keeps sign-in hidden where the device can't finish it", (
      tester,
    ) async {
      when(
        () => repository.startingPlatform('bluesky'),
      ).thenReturn(blueskyOn);
      when(
        () => repository.platform('bluesky'),
      ).thenAnswer((_) async => blueskyOn);

      await pump(tester, platformKey: 'bluesky', deviceSupportsOAuth: false);
      await tester.pump();

      expect(signInButton('bluesky'), findsNothing);
      expect(find.text(l10n.verifyConnectProofCta), findsOneWidget);
    });

    testWidgets('opened without a list, offers only the proof post until the '
        'answer arrives, then follows it', (tester) async {
      final answer = Completer<VerifierPlatform>();
      when(() => repository.startingPlatform('twitter')).thenReturn(
        const VerifierPlatform(
          key: 'twitter',
          label: 'twitter',
          supported: true,
          oauth: false,
        ),
      );
      when(
        () => repository.platform('twitter'),
      ).thenAnswer((_) => answer.future);

      await pump(tester, platformKey: 'twitter');

      expect(signInButton('twitter'), findsNothing);
      expect(find.text(l10n.verifyConnectProofCta), findsOneWidget);

      // The verifier couldn't be asked, so the app's own list decides.
      answer.complete(
        const VerifierPlatform(
          key: 'twitter',
          label: 'twitter',
          supported: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(signInButton('twitter'), findsOneWidget);
      verify(() => repository.platform('twitter')).called(1);
    });

    group('Divine Confirmation access', () {
      const twitterGated = VerifierPlatform(
        key: 'twitter',
        label: 'Twitter / X',
        supported: true,
        oauth: true,
        signinRequires: SigninRequirement.confirmation,
      );

      void gate(_MockIdentityClaimsRepository repository) {
        when(
          () => repository.startingPlatform('twitter'),
        ).thenReturn(twitterGated);
        when(
          () => repository.platform('twitter'),
        ).thenAnswer((_) async => twitterGated);
      }

      testWidgets('reads access through the injected reader with the flag on', (
        tester,
      ) async {
        gate(repository);
        final reads = <bool>[];

        await pump(
          tester,
          platformKey: 'twitter',
          confirmationSignIn: true,
          readConfirmationAccess: ({bool refresh = false}) async {
            reads.add(refresh);
            return ConfirmationAccess.hasNot;
          },
        );
        await tester.pump();

        expect(reads, equals([false]));
      });

      group('on a verifier that names no requirement', () {
        setUp(() {
          const twitterOpen = VerifierPlatform(
            key: 'twitter',
            label: 'Twitter / X',
            supported: true,
            oauth: true,
          );
          when(
            () => repository.startingPlatform('twitter'),
          ).thenReturn(twitterOpen);
          when(
            () => repository.platform('twitter'),
          ).thenAnswer((_) async => twitterOpen);
        });

        testWidgets(
          'reads no access and keeps the sign-in with the simulated '
          'requirement off',
          (tester) async {
            final reads = <bool>[];
            await pump(
              tester,
              platformKey: 'twitter',
              confirmationSignIn: true,
              readConfirmationAccess: ({bool refresh = false}) async {
                reads.add(refresh);
                return ConfirmationAccess.hasNot;
              },
            );
            await tester.pump();

            expect(reads, isEmpty);
            expect(find.text(l10n.verifyConfirmationCardTitle), findsNothing);
            expect(signInButton('twitter'), findsOneWidget);
          },
        );

        testWidgets(
          'reads access and shows the Confirmation card with the simulated '
          'requirement on',
          (tester) async {
            final reads = <bool>[];
            await pump(
              tester,
              platformKey: 'twitter',
              confirmationSignIn: true,
              simulateConfirmationRequirement: true,
              readConfirmationAccess: ({bool refresh = false}) async {
                reads.add(refresh);
                return ConfirmationAccess.hasNot;
              },
            );
            await tester.pump();

            expect(reads, equals([false]));
            expect(
              find.text(l10n.verifyConfirmationCardTitle),
              findsOneWidget,
            );
            expect(signInButton('twitter'), findsNothing);
          },
        );
      });

      testWidgets(
        'turning the simulated requirement over keeps the open flow and its '
        'cubit',
        (tester) async {
          // Turning it over must not close a cubit that may hold a sign-in to
          // approve, so the page reads it once per flow, as it does the flag.
          SharedPreferences.setMockInitialValues({});
          final prefs = await SharedPreferences.getInstance();
          const twitterOpen = VerifierPlatform(
            key: 'twitter',
            label: 'Twitter / X',
            supported: true,
            oauth: true,
          );
          when(
            () => repository.startingPlatform('twitter'),
          ).thenReturn(twitterOpen);
          when(
            () => repository.platform('twitter'),
          ).thenAnswer((_) async => twitterOpen);
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                identityClaimsRepositoryProvider.overrideWithValue(repository),
                sharedPreferencesProvider.overrideWithValue(prefs),
                confirmationAccessDebugBuildProvider.overrideWithValue(true),
                supporterStoreBillingAvailableProvider.overrideWithValue(true),
                isFeatureEnabledProvider(
                  FeatureFlag.confirmationSignIn,
                ).overrideWithValue(true),
                confirmationAccessReaderProvider.overrideWithValue(
                  _unknownAccess,
                ),
                authServiceProvider.overrideWithValue(
                  createMockAuthService(
                    authState: AuthState.authenticated,
                    currentPublicKeyHex: _pubkey,
                  ),
                ),
                currentAuthStateProvider.overrideWithValue(
                  AuthState.authenticated,
                ),
                appOAuthSupportProvider.overrideWith((ref) async => true),
                analyticsEventSinkProvider.overrideWithValue(
                  const NoOpAnalyticsEventSink(),
                ),
              ],
              child: MaterialApp(
                localizationsDelegates: appLocalizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                theme: VineTheme.theme,
                home: const VerifyConnectPage(platformKey: 'twitter'),
              ),
            ),
          );
          await tester.pump();
          VerifyConnectCubit cubit() => tester
              .element(find.byType(VerifyConnectView))
              .read<VerifyConnectCubit>();
          final container = ProviderScope.containerOf(
            tester.element(find.byType(VerifyConnectPage)),
          );
          final before = cubit();

          await container
              .read(confirmationRequirementSimulatedProvider.notifier)
              .set(on: true);
          await tester.pump();

          expect(
            container.read(simulateConfirmationRequirementProvider),
            isTrue,
          );
          expect(cubit(), same(before));
          expect(before.isClosed, isFalse);
          expect(cubit().state.platform, equals(twitterOpen));
        },
      );

      testWidgets(
        'asks the new account, not the old one, after an account change',
        (tester) async {
          // Each account has its own repository, which remembers its own
          // answer; a cubit kept across the change would ask the old one.
          gate(repository);
          final oldReads = <bool>[];
          await pump(
            tester,
            platformKey: 'twitter',
            confirmationSignIn: true,
            readConfirmationAccess: ({bool refresh = false}) async {
              oldReads.add(refresh);
              return ConfirmationAccess.has;
            },
          );
          await tester.pump();
          expect(oldReads, hasLength(1));

          repository = _MockIdentityClaimsRepository();
          gate(repository);
          final newReads = <bool>[];
          await pump(
            tester,
            platformKey: 'twitter',
            confirmationSignIn: true,
            readConfirmationAccess: ({bool refresh = false}) async {
              newReads.add(refresh);
              return ConfirmationAccess.hasNot;
            },
          );
          await tester.pump();

          expect(newReads, equals([false]));
          expect(oldReads, hasLength(1));
          final cubit = BlocProvider.of<VerifyConnectCubit>(
            tester.element(find.byType(VerifyConnectView)),
          );
          expect(cubit.state.confirmationAccess, ConfirmationAccess.hasNot);
          await cubit.refreshConfirmationAccess();
          expect(newReads, equals([false, true]));
          expect(oldReads, hasLength(1));
        },
      );

      testWidgets('shows the card with the flag on and no Confirmation', (
        tester,
      ) async {
        gate(repository);

        await pump(
          tester,
          platformKey: 'twitter',
          confirmationSignIn: true,
          readConfirmationAccess: ({bool refresh = false}) async =>
              ConfirmationAccess.hasNot,
        );
        await tester.pump();

        expect(find.text(l10n.verifyConfirmationCardTitle), findsOneWidget);
        expect(signInButton('twitter'), findsNothing);
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is DivineButton &&
                widget.label == l10n.verifyGetConfirmation,
          ),
          findsOneWidget,
        );
      });

      testWidgets('shows the store note where no store can bill', (
        tester,
      ) async {
        gate(repository);

        await pump(
          tester,
          platformKey: 'twitter',
          confirmationSignIn: true,
          canBuy: false,
          readConfirmationAccess: ({bool refresh = false}) async =>
              ConfirmationAccess.hasNot,
        );
        await tester.pump();

        expect(find.text(l10n.verifyConfirmationStoreOnly), findsOneWidget);
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is DivineButton &&
                widget.label == l10n.verifyGetConfirmation,
          ),
          findsNothing,
        );
      });
    });
  });

  group(VerifyConnectView, () {
    late _MockIdentityClaimsRepository repository;
    late _MockAnalyticsEventSink analytics;
    late VerifyConnectCubit cubit;

    setUp(() {
      repository = _MockIdentityClaimsRepository();
      analytics = _MockAnalyticsEventSink();
      when(
        () => analytics.logEvent(
          name: any(named: 'name'),
          parameters: any(named: 'parameters'),
        ),
      ).thenAnswer((_) async {});
      cubit = VerifyConnectCubit(
        confirmationSignIn: false,
        readConfirmationAccess: _unknownAccess,
        repository: repository,
        pubkey: _pubkey,
        platform: _telegram,
        oauthReturnUrl: _returnUrl,
        analytics: analytics,
        launchOAuth: (_) async => null,
      );
    });

    tearDown(() async {
      await cubit.close();
    });

    Future<void> pump(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          home: BlocProvider<VerifyConnectCubit>.value(
            value: cubit,
            child: const VerifyConnectView(npub: _npub),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('keeps manual account field visible while typing', (
      tester,
    ) async {
      final l10n = lookupAppLocalizations(const Locale('en'));
      await pump(tester);

      expect(find.byType(TextField), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'some nonsense');
      await tester.pump();

      expect(
        find.text(verifyIdentityFieldLabel(l10n, _telegram.key)),
        findsOneWidget,
      );
      expect(find.byType(TextField), findsNWidgets(2));

      await tester.enterText(find.byType(TextField).first, 'testdivine');
      await tester.pump();

      expect(
        find.text(verifyIdentityFieldLabel(l10n, _telegram.key)),
        findsOneWidget,
      );
      expect(find.byType(TextField), findsNWidgets(2));
    });

    testWidgets('does not autocorrect a typed proof link', (tester) async {
      await pump(tester);

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.autocorrect, isFalse);
      expect(field.keyboardType, TextInputType.url);
    });

    testWidgets('keeps the typed proof when the account field appears', (
      tester,
    ) async {
      await pump(tester);

      await tester.enterText(find.byType(TextField), 'some nonsense');
      await tester.pump();

      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.text('some nonsense'), findsOneWidget);
      expect(tester.testTextInput.isVisible, isTrue);
    });

    testWidgets('keeps a pasted link when the account field goes away', (
      tester,
    ) async {
      // Deliberately not verifyProofHint('telegram') — that string is the
      // field's own hint, so find.text would match an empty field.
      const pastedLink = 'https://t.me/divinechannel/456';
      await pump(tester);

      await tester.enterText(find.byType(TextField), 'nonsense');
      await tester.pump();
      expect(find.byType(TextField), findsNWidgets(2));

      await tester.enterText(find.byType(TextField).last, pastedLink);
      await tester.pump();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text(pastedLink), findsOneWidget);
    });
  });

  group('$VerifyConnectView rejection copy', () {
    late _MockIdentityClaimsRepository repository;
    late _MockAnalyticsEventSink analytics;
    late VerifyConnectCubit cubit;

    const discord = VerifierPlatform(
      key: 'discord',
      label: 'Discord',
      supported: true,
    );

    setUpAll(() {
      registerFallbackValue(
        const IdentityClaim(
          pubkey: _pubkey,
          platform: 'discord',
          identity: 'alice',
          proof: 'x',
        ),
      );
    });

    setUp(() {
      repository = _MockIdentityClaimsRepository();
      analytics = _MockAnalyticsEventSink();
      when(
        () => analytics.logEvent(
          name: any(named: 'name'),
          parameters: any(named: 'parameters'),
        ),
      ).thenAnswer((_) async {});
      cubit = VerifyConnectCubit(
        confirmationSignIn: false,
        readConfirmationAccess: _unknownAccess,
        repository: repository,
        pubkey: _pubkey,
        platform: discord,
        oauthReturnUrl: _returnUrl,
        launchOAuth: (_) async => null,
        analytics: analytics,
      );
    });

    tearDown(() async {
      await cubit.close();
    });

    Future<void> submit(WidgetTester tester, {required String? code}) async {
      when(() => repository.verifyClaim(any())).thenAnswer(
        (_) async => VerificationResult(
          platform: 'discord',
          identity: 'alice',
          verified: false,
          checkedAt: 1,
          cached: false,
          code: code,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          home: BlocProvider<VerifyConnectCubit>.value(
            value: cubit,
            child: const VerifyConnectView(npub: _npub),
          ),
        ),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextField).first, 'alice');
      await tester.enterText(
        find.byType(TextField).last,
        'https://discord.com/channels/1/2/3',
      );
      await tester.pump();

      await tester.tap(
        find.text(
          lookupAppLocalizations(const Locale('en')).verifyConnectProofCta,
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    testWidgets('names the account when the author does not match', (
      tester,
    ) async {
      final l10n = lookupAppLocalizations(const Locale('en'));

      await submit(tester, code: 'discord_author_mismatch');

      expect(find.text(l10n.verifyErrorDiscordAuthorMismatch), findsOneWidget);
      // The old behaviour showed this for every rejection, which is what sent
      // people back to re-post an npub that was already there.
      expect(find.text(l10n.verifyErrorProofRejected), findsNothing);
    });

    testWidgets('keeps the generic copy when the verifier sends no code', (
      tester,
    ) async {
      final l10n = lookupAppLocalizations(const Locale('en'));

      await submit(tester, code: null);

      expect(find.text(l10n.verifyErrorProofRejected), findsOneWidget);
    });

    testWidgets('the fallback does not blame the npub in any locale', (
      tester,
    ) async {
      // Every platform without rejection codes lands here, including a GitHub
      // gist-owner mismatch and a Mastodon author mismatch. Naming the npub
      // there reproduces the original bug for those platforms.
      final l10n = lookupAppLocalizations(const Locale('en'));

      await submit(tester, code: null);

      for (final locale in AppLocalizations.supportedLocales) {
        expect(
          lookupAppLocalizations(locale).verifyErrorProofRejected,
          isNot(contains('npub')),
          reason: '$locale must use the generic rejection fallback',
        );
      }
      expect(find.text(l10n.verifyErrorProofMissingNpub), findsNothing);
    });

    testWidgets('says the npub is missing only when that is the reason', (
      tester,
    ) async {
      final l10n = lookupAppLocalizations(const Locale('en'));

      await submit(tester, code: 'discord_npub_not_in_message');

      expect(find.text(l10n.verifyErrorProofMissingNpub), findsOneWidget);
      expect(find.text(l10n.verifyErrorProofRejected), findsNothing);
    });
  });

  group('$VerifyConnectView sign-in return', () {
    late _MockIdentityClaimsRepository repository;
    late VerifyConnectCubit cubit;
    late String startedReturnUrl;

    const twitter = VerifierPlatform(
      key: 'twitter',
      label: 'Twitter / X',
      supported: true,
    );

    setUp(() {
      repository = _MockIdentityClaimsRepository();
      when(
        () => repository.startSignIn(
          platform: any(named: 'platform'),
          pubkey: any(named: 'pubkey'),
          returnUrl: any(named: 'returnUrl'),
          startCheck: any(named: 'startCheck'),
          handle: any(named: 'handle'),
        ),
      ).thenAnswer((invocation) async {
        startedReturnUrl = invocation.namedArguments[#returnUrl] as String;
        return Uri.parse('https://provider.example/authorize?state=s');
      });
      cubit = VerifyConnectCubit(
        confirmationSignIn: false,
        readConfirmationAccess: _unknownAccess,
        repository: repository,
        pubkey: _pubkey,
        platform: twitter,
        oauthReturnUrl: _returnUrl,
        // This group never rejects a proof, so the sink is never reached.
        analytics: const NoOpAnalyticsEventSink(),
        // A return for this sign-in that carries no confirmation code.
        launchOAuth: (_) async =>
            Uri.parse('$startedReturnUrl&platform=twitter&identity=jack'),
      );
    });

    tearDown(() async {
      await cubit.close();
    });

    testWidgets('says to sign in again when the return has no code', (
      tester,
    ) async {
      final l10n = lookupAppLocalizations(const Locale('en'));
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          home: BlocProvider<VerifyConnectCubit>.value(
            value: cubit,
            child: const VerifyConnectView(npub: _npub),
          ),
        ),
      );
      await tester.pump();

      await cubit.connectWithOAuth();
      await tester.pump();

      expect(find.text(l10n.verifyErrorSignInNotConfirmed), findsOneWidget);
    });
  });

  group('$VerifyConnectView OAuth support arriving late', () {
    late VerifyConnectCubit cubit;

    setUp(() {
      cubit = VerifyConnectCubit(
        confirmationSignIn: false,
        readConfirmationAccess: _unknownAccess,
        repository: _MockIdentityClaimsRepository(),
        pubkey: _pubkey,
        platform: _bluesky,
        oauthReturnUrl: _returnUrl,
        // This group never rejects a proof, so the sink is never reached.
        analytics: const NoOpAnalyticsEventSink(),
        launchOAuth: (_) async => null,
      );
    });

    tearDown(() async {
      await cubit.close();
    });

    Future<void> pump(
      WidgetTester tester, {
      required bool oauthAvailable,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          home: BlocProvider<VerifyConnectCubit>.value(
            value: cubit,
            child: VerifyConnectView(
              npub: _npub,
              oauthAvailable: oauthAvailable,
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('keeps the typed handle when the OAuth block appears', (
      tester,
    ) async {
      // Not verifyIdentityHint('bluesky') — that is 'example.bsky.social', and
      // find.text would match the hint of an empty field.
      // appOAuthSupportProvider resolves a frame or two after the screen
      // opens, and the handle field moves from the proof block up into the
      // OAuth block when it does.
      await pump(tester, oauthAvailable: false);
      await tester.enterText(
        find.byType(TextField).first,
        'divine.bsky.social',
      );
      await tester.pump();

      await pump(tester, oauthAvailable: true);

      expect(find.text('divine.bsky.social'), findsOneWidget);
    });
  });

  group('$VerifyConnectView signing in again', () {
    const twitterOAuth = VerifierPlatform(
      key: 'twitter',
      label: 'Twitter / X',
      supported: true,
      oauth: true,
    );
    const blueskyOAuth = VerifierPlatform(
      key: 'bluesky',
      label: 'Bluesky',
      supported: true,
      oauth: true,
    );
    late VerifyConnectCubit cubit;

    tearDown(() async {
      await cubit.close();
    });

    Future<AppLocalizations> pump(
      WidgetTester tester, {
      required VerifierPlatform platform,
      required bool oauthAvailable,
      String? replacingIdentity,
      IdentityClaimsRepository? repository,
    }) async {
      cubit = VerifyConnectCubit(
        confirmationSignIn: false,
        readConfirmationAccess: _unknownAccess,
        repository: repository ?? _MockIdentityClaimsRepository(),
        pubkey: _pubkey,
        platform: platform,
        oauthReturnUrl: _returnUrl,
        analytics: const NoOpAnalyticsEventSink(),
        launchOAuth: (_) async => null,
        replacingIdentity: replacingIdentity,
      );
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          home: BlocProvider<VerifyConnectCubit>.value(
            value: cubit,
            child: VerifyConnectView(
              npub: _npub,
              oauthAvailable: oauthAvailable,
            ),
          ),
        ),
      );
      await tester.pump();
      return lookupAppLocalizations(const Locale('en'));
    }

    testWidgets('shows only the sign-in when sign-in can run', (tester) async {
      final l10n = await pump(
        tester,
        platform: twitterOAuth,
        oauthAvailable: true,
        replacingIdentity: 'jack',
      );

      expect(find.text(l10n.verifyConnectOauthCta('Twitter / X')), findsOne);
      expect(find.text(l10n.verifyConnectProofCta), findsNothing);
      expect(find.byKey(const ValueKey('verify-proof-field')), findsNothing);
      expect(find.text(l10n.verifyConnectProofTitle), findsNothing);
    });

    testWidgets("keeps Bluesky's handle field, filled in", (tester) async {
      final l10n = await pump(
        tester,
        platform: blueskyOAuth,
        oauthAvailable: true,
        replacingIdentity: 'alice.bsky.social',
      );

      expect(find.byKey(const ValueKey('verify-identity-field')), findsOne);
      expect(find.text('alice.bsky.social'), findsOneWidget);
      expect(find.text(l10n.verifyConnectProofCta), findsNothing);
      expect(find.byKey(const ValueKey('verify-proof-field')), findsNothing);
    });

    testWidgets('keeps the proof form where the app cannot sign in', (
      tester,
    ) async {
      // iOS below 17.4: the page would be blank without it.
      final l10n = await pump(
        tester,
        platform: twitterOAuth,
        oauthAvailable: false,
        replacingIdentity: 'jack',
      );

      expect(find.text(l10n.verifyConnectProofCta), findsOneWidget);
      expect(find.byKey(const ValueKey('verify-proof-field')), findsOne);
    });

    testWidgets('keeps the proof form where the platform has no sign-in', (
      tester,
    ) async {
      final l10n = await pump(
        tester,
        platform: _telegram,
        oauthAvailable: true,
        replacingIdentity: 'jack',
      );

      expect(find.text(l10n.verifyConnectProofCta), findsOneWidget);
      expect(find.byKey(const ValueKey('verify-proof-field')), findsOne);
    });

    testWidgets('keeps the proof form where sign-in is turned off', (
      tester,
    ) async {
      // What the verifier reports with sign-in off, and what a platform
      // still loading from /platforms reports.
      const twitterOff = VerifierPlatform(
        key: 'twitter',
        label: 'Twitter / X',
        supported: true,
        oauth: false,
      );
      final l10n = await pump(
        tester,
        platform: twitterOff,
        oauthAvailable: true,
        replacingIdentity: 'jack',
      );

      expect(
        find.text(l10n.verifyConnectOauthCta('Twitter / X')),
        findsNothing,
      );
      expect(find.text(l10n.verifyConnectProofCta), findsOneWidget);
      expect(find.byKey(const ValueKey('verify-proof-field')), findsOne);
    });

    testWidgets('brings the proof form back when sign-in turns out to be off', (
      tester,
    ) async {
      // Sign-in was on when the list was read; the verifier answers 503
      // from the start request, so the sign-in button can only keep failing.
      final repository = _MockIdentityClaimsRepository();
      when(
        () => repository.startSignIn(
          platform: any(named: 'platform'),
          pubkey: any(named: 'pubkey'),
          returnUrl: any(named: 'returnUrl'),
          startCheck: any(named: 'startCheck'),
          handle: any(named: 'handle'),
        ),
      ).thenAnswer((_) async => null);
      final l10n = await pump(
        tester,
        platform: twitterOAuth,
        oauthAvailable: true,
        replacingIdentity: 'jack',
        repository: repository,
      );
      expect(find.byKey(const ValueKey('verify-proof-field')), findsNothing);

      await tester.tap(find.text(l10n.verifyConnectOauthCta('Twitter / X')));
      await tester.pump();
      await tester.pump();

      expect(find.text(l10n.verifyErrorOauthUnavailable), findsOneWidget);
      expect(
        find.text(l10n.verifyConnectOauthCta('Twitter / X')),
        findsNothing,
      );
      expect(find.text(l10n.verifyConnectProofCta), findsOneWidget);
      expect(find.byKey(const ValueKey('verify-proof-field')), findsOne);
    });

    testWidgets('brings the proof form back when sign-in fails to start', (
      tester,
    ) async {
      // Not a 503, so the verifier still says sign-in is on: the button stays
      // for a retry, and the proof post is the way forward if it keeps failing.
      final repository = _MockIdentityClaimsRepository();
      when(
        () => repository.startSignIn(
          platform: any(named: 'platform'),
          pubkey: any(named: 'pubkey'),
          returnUrl: any(named: 'returnUrl'),
          startCheck: any(named: 'startCheck'),
          handle: any(named: 'handle'),
        ),
      ).thenThrow(const VerifierApiException(500, 'returned 500'));
      final l10n = await pump(
        tester,
        platform: twitterOAuth,
        oauthAvailable: true,
        replacingIdentity: 'jack',
        repository: repository,
      );
      expect(find.byKey(const ValueKey('verify-proof-field')), findsNothing);

      await tester.tap(find.text(l10n.verifyConnectOauthCta('Twitter / X')));
      await tester.pump();
      await tester.pump();

      expect(find.text(l10n.verifyErrorOauthFailed), findsOneWidget);
      expect(find.text(l10n.verifyConnectOauthCta('Twitter / X')), findsOne);
      expect(find.text(l10n.verifyConnectProofCta), findsOneWidget);
      expect(find.byKey(const ValueKey('verify-proof-field')), findsOne);
    });

    group('once a sign-in fails to start', () {
      late _MockIdentityClaimsRepository repository;

      setUp(() {
        repository = _MockIdentityClaimsRepository();
        when(
          () => repository.startSignIn(
            platform: any(named: 'platform'),
            pubkey: any(named: 'pubkey'),
            returnUrl: any(named: 'returnUrl'),
            startCheck: any(named: 'startCheck'),
            handle: any(named: 'handle'),
          ),
        ).thenThrow(const VerifierApiException(500, 'returned 500'));
      });

      TextField identityField(WidgetTester tester) => tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const ValueKey('verify-identity-field')),
          matching: find.byType(TextField),
        ),
      );

      testWidgets('fixes the handle to the one being renewed', (tester) async {
        final l10n = await pump(
          tester,
          platform: twitterOAuth,
          oauthAvailable: true,
          replacingIdentity: 'jack',
          repository: repository,
        );
        await tester.tap(find.text(l10n.verifyConnectOauthCta('Twitter / X')));
        await tester.pump();
        await tester.pump();

        await tester.enterText(
          find.byKey(const ValueKey('verify-proof-field')),
          'https://x.com/other/status/1',
        );
        await tester.pump();

        expect(find.text(l10n.verifyConnectProofCta), findsOneWidget);
        expect(identityField(tester).enabled, isFalse);
        expect(identityField(tester).controller!.text, equals('jack'));
      });

      testWidgets('shows the renewed Bluesky handle, not one typed before', (
        tester,
      ) async {
        final l10n = await pump(
          tester,
          platform: blueskyOAuth,
          oauthAvailable: true,
          replacingIdentity: 'alice.bsky.social',
          repository: repository,
        );
        await tester.enterText(
          find.byKey(const ValueKey('verify-identity-field')),
          'bob.bsky.social',
        );
        await tester.tap(find.text(l10n.verifyConnectOauthCta('Bluesky')));
        await tester.pump();
        await tester.pump();

        expect(find.text(l10n.verifyConnectProofCta), findsOneWidget);
        expect(identityField(tester).enabled, isFalse);
        expect(
          identityField(tester).controller!.text,
          equals('alice.bsky.social'),
        );
      });

      testWidgets('leaves the handle editable on a plain connect', (
        tester,
      ) async {
        final l10n = await pump(
          tester,
          platform: blueskyOAuth,
          oauthAvailable: true,
          repository: repository,
        );
        await tester.enterText(
          find.byKey(const ValueKey('verify-identity-field')),
          'bob.bsky.social',
        );
        await tester.tap(find.text(l10n.verifyConnectOauthCta('Bluesky')));
        await tester.pump();
        await tester.pump();

        expect(find.text(l10n.verifyConnectProofCta), findsOneWidget);
        expect(identityField(tester).enabled, isTrue);
        expect(
          identityField(tester).controller!.text,
          equals('bob.bsky.social'),
        );
      });
    });

    testWidgets(
      'keeps the Bluesky handle editable when the verifier refuses it',
      (
        tester,
      ) async {
        // A 400 is the verifier refusing the handle, not a sign-in that cannot
        // start: the person corrects it and signs in again.
        final repository = _MockIdentityClaimsRepository();
        when(
          () => repository.startSignIn(
            platform: any(named: 'platform'),
            pubkey: any(named: 'pubkey'),
            returnUrl: any(named: 'returnUrl'),
            startCheck: any(named: 'startCheck'),
            handle: any(named: 'handle'),
          ),
        ).thenThrow(const VerifierApiException(400, 'returned 400'));
        final l10n = await pump(
          tester,
          platform: blueskyOAuth,
          oauthAvailable: true,
          replacingIdentity: 'alice.bsky.social',
          repository: repository,
        );
        await tester.tap(find.text(l10n.verifyConnectOauthCta('Bluesky')));
        await tester.pump();
        await tester.pump();

        expect(find.text(l10n.verifyErrorOauthFailed), findsOneWidget);
        expect(find.text(l10n.verifyConnectProofCta), findsNothing);
        expect(find.byKey(const ValueKey('verify-proof-field')), findsNothing);
        final field = tester.widget<TextField>(
          find.descendant(
            of: find.byKey(const ValueKey('verify-identity-field')),
            matching: find.byType(TextField),
          ),
        );
        expect(field.enabled, isTrue);
        expect(field.controller!.text, equals('alice.bsky.social'));
      },
    );

    testWidgets('fixes the handle where a renewal can only post a proof', (
      tester,
    ) async {
      // iOS below 17.4: the proof post is all there is, and it is made for
      // the renewed handle whatever the field holds.
      await pump(
        tester,
        platform: _bluesky,
        oauthAvailable: false,
        replacingIdentity: 'alice.bsky.social',
      );

      final field = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const ValueKey('verify-identity-field')),
          matching: find.byType(TextField),
        ),
      );
      expect(field.enabled, isFalse);
      expect(field.controller!.text, equals('alice.bsky.social'));
    });

    testWidgets('keeps the proof form when not signing in again', (
      tester,
    ) async {
      final l10n = await pump(
        tester,
        platform: twitterOAuth,
        oauthAvailable: true,
      );

      expect(find.text(l10n.verifyConnectOauthCta('Twitter / X')), findsOne);
      expect(find.text(l10n.verifyConnectProofCta), findsOneWidget);
      expect(find.byKey(const ValueKey('verify-proof-field')), findsOne);
    });
  });

  group('$VerifyConnectView sign-in lifetime notice', () {
    const lasting30 = VerifierPlatform(
      key: 'bluesky',
      label: 'Bluesky',
      supported: true,
      oauth: true,
      signinExpiresAfterDays: 30,
    );
    late VerifyConnectCubit cubit;

    tearDown(() async {
      await cubit.close();
    });

    Future<AppLocalizations> pump(
      WidgetTester tester, {
      required VerifierPlatform platform,
      bool oauthAvailable = true,
      String? replacingIdentity,
    }) async {
      cubit = VerifyConnectCubit(
        confirmationSignIn: false,
        readConfirmationAccess: _unknownAccess,
        repository: _MockIdentityClaimsRepository(),
        pubkey: _pubkey,
        platform: platform,
        oauthReturnUrl: _returnUrl,
        analytics: const NoOpAnalyticsEventSink(),
        launchOAuth: (_) async => null,
        replacingIdentity: replacingIdentity,
      );
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          home: BlocProvider<VerifyConnectCubit>.value(
            value: cubit,
            child: VerifyConnectView(
              npub: _npub,
              oauthAvailable: oauthAvailable,
            ),
          ),
        ),
      );
      await tester.pump();
      return lookupAppLocalizations(const Locale('en'));
    }

    testWidgets('says how many days the verifier reports', (tester) async {
      final l10n = await pump(tester, platform: lasting30);

      expect(
        find.text(l10n.verifyConnectSignInLifetime(30)),
        findsOneWidget,
      );
      // The absence tests look the notice up by this key, so it has to be
      // on the notice for them to mean anything.
      expect(
        find.byKey(const ValueKey('verify-signin-lifetime')),
        findsOneWidget,
      );
    });

    testWidgets('uses the singular for one day', (tester) async {
      final l10n = await pump(
        tester,
        platform: const VerifierPlatform(
          key: 'bluesky',
          label: 'Bluesky',
          supported: true,
          oauth: true,
          signinExpiresAfterDays: 1,
        ),
      );

      expect(find.text(l10n.verifyConnectSignInLifetime(1)), findsOneWidget);
      // The one-day wording is its own, not the plural with a 1 in it.
      expect(
        l10n.verifyConnectSignInLifetime(1),
        isNot(l10n.verifyConnectSignInLifetime(2).replaceAll('2', '1')),
      );
    });

    testWidgets('shows nothing when the verifier reports no lifetime', (
      tester,
    ) async {
      final l10n = await pump(
        tester,
        platform: const VerifierPlatform(
          key: 'bluesky',
          label: 'Bluesky',
          supported: true,
          oauth: true,
        ),
      );

      expect(find.text(l10n.verifyConnectOauthCta('Bluesky')), findsOne);
      expect(
        find.byKey(const ValueKey('verify-signin-lifetime')),
        findsNothing,
      );
    });

    testWidgets('shows nothing when sign-in is not showing', (tester) async {
      await pump(tester, platform: lasting30, oauthAvailable: false);

      expect(
        find.byKey(const ValueKey('verify-signin-lifetime')),
        findsNothing,
      );
    });

    testWidgets('shows while signing in again', (tester) async {
      final l10n = await pump(
        tester,
        platform: lasting30,
        replacingIdentity: 'alice.bsky.social',
      );

      expect(
        find.text(l10n.verifyConnectSignInLifetime(30)),
        findsOneWidget,
      );
    });
  });

  group('$VerifyConnectView after a sign-in returns', () {
    late _MockIdentityClaimsRepository repository;
    late VerifyConnectCubit cubit;
    late String startedReturnUrl;

    const twitter = VerifierPlatform(
      key: 'twitter',
      label: 'Twitter / X',
      supported: true,
    );
    final l10n = lookupAppLocalizations(const Locale('en'));
    final platformLabel = verifyPlatformLabel(twitter.key);
    final signedInTitle = l10n.verifyConnectSignedInTitle(
      platformLabel,
      'jack',
    );

    Finder button(String label) => find.byWidgetPredicate(
      (widget) => widget is DivineButton && widget.label == label,
    );

    setUpAll(() {
      registerFallbackValue(
        const IdentityClaim(
          pubkey: _pubkey,
          platform: 'twitter',
          identity: 'jack',
          proof: IdentityClaim.oauthProof,
        ),
      );
      registerFallbackValue(_MockSignedIdentityClaim());
    });

    setUp(() {
      repository = _MockIdentityClaimsRepository();
      when(
        () => repository.startSignIn(
          platform: any(named: 'platform'),
          pubkey: any(named: 'pubkey'),
          returnUrl: any(named: 'returnUrl'),
          startCheck: any(named: 'startCheck'),
          handle: any(named: 'handle'),
        ),
      ).thenAnswer((invocation) async {
        startedReturnUrl = invocation.namedArguments[#returnUrl] as String;
        return Uri.parse('https://provider.example/authorize?state=s');
      });
      when(
        () => repository.signClaim(
          any(),
          confirmBinding: any(named: 'confirmBinding'),
        ),
      ).thenAnswer((_) async => _MockSignedIdentityClaim());
      when(
        () => repository.confirmSignIn(
          code: any(named: 'code'),
          startSecret: any(named: 'startSecret'),
          signed: any(named: 'signed'),
        ),
      ).thenAnswer(
        (_) async =>
            const SignInConfirmation(platform: 'twitter', identity: 'jack'),
      );
      when(
        () => repository.publishSignedClaim(any()),
      ).thenAnswer((_) async => []);
      cubit = VerifyConnectCubit(
        confirmationSignIn: false,
        readConfirmationAccess: _unknownAccess,
        repository: repository,
        pubkey: _pubkey,
        platform: twitter,
        oauthReturnUrl: _returnUrl,
        // This group never rejects a proof, so the sink is never reached.
        analytics: const NoOpAnalyticsEventSink(),
        launchOAuth: (_) async => Uri.parse(
          '$startedReturnUrl&platform=twitter&identity=jack'
          '&oauth_confirm=${'C' * 43}',
        ),
      );
    });

    tearDown(() async {
      await cubit.close();
    });

    // Pushed over a stand-in dashboard, so going back has somewhere to go.
    // Tall enough that the whole form is built, down to the proof button.
    Future<void> pumpWaitingForApproval(
      WidgetTester tester, {
      String? handle,
    }) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final router = GoRouter(
        initialLocation: '/connect',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Text('dashboard'),
            routes: [
              GoRoute(
                path: 'connect',
                builder: (_, _) => BlocProvider<VerifyConnectCubit>.value(
                  value: cubit,
                  child: const VerifyConnectView(npub: _npub),
                ),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          routerConfig: router,
        ),
      );
      await tester.pump();
      if (handle != null) {
        await tester.enterText(find.byType(TextField).first, handle);
        await tester.pump();
      }
      await cubit.connectWithOAuth();
      await tester.pump();
    }

    // Holds the approve in its confirm step until the returned completer is
    // completed.
    Completer<SignInConfirmation> holdConfirm() {
      final confirm = Completer<SignInConfirmation>();
      when(
        () => repository.confirmSignIn(
          code: any(named: 'code'),
          startSecret: any(named: 'startSecret'),
          signed: any(named: 'signed'),
        ),
      ).thenAnswer((_) => confirm.future);
      return confirm;
    }

    testWidgets('names the account and offers to link it', (tester) async {
      await pumpWaitingForApproval(tester);

      expect(find.text(signedInTitle), findsOneWidget);
      // The start button gives way to the approval.
      expect(
        find.text(l10n.verifyConnectOauthCta(platformLabel)),
        findsNothing,
      );

      await tester.tap(find.text(l10n.verifyConnectSignedInCta));
      await tester.pump();

      verify(
        () => repository.signClaim(
          any(),
          confirmBinding: any(named: 'confirmBinding'),
        ),
      ).called(1);
    });

    testWidgets('keeps approve and cancel when the verifier turns sign-in '
        'off meanwhile', (tester) async {
      when(() => repository.platform('twitter')).thenAnswer(
        (_) async => const VerifierPlatform(
          key: 'twitter',
          label: 'Twitter / X',
          supported: true,
          oauth: false,
        ),
      );
      await pumpWaitingForApproval(tester);

      await cubit.loadPlatform();
      await tester.pump();

      expect(find.text(signedInTitle), findsOneWidget);
      expect(button(l10n.verifyConnectSignedInCta), findsOneWidget);
      expect(button(l10n.verifyConnectSignedInCancel), findsOneWidget);

      await tester.tap(find.text(l10n.verifyConnectSignedInCancel));
      await tester.pump();

      expect(cubit.state.status, VerifyConnectStatus.editing);
      expect(find.text(signedInTitle), findsNothing);
    });

    testWidgets('cancel goes back to the sign-in button', (tester) async {
      await pumpWaitingForApproval(tester);

      await tester.tap(find.text(l10n.verifyConnectSignedInCancel));
      await tester.pump();

      expect(find.text(signedInTitle), findsNothing);
      expect(
        find.text(l10n.verifyConnectOauthCta(platformLabel)),
        findsOneWidget,
      );
    });

    // Not verifyIdentityHint('bluesky'), which find.text would match in an
    // empty field.
    const blueskyHandle = 'divine.bsky.social';

    // As pumpWaitingForApproval, for a Bluesky sign-in started with
    // [blueskyHandle] typed.
    Future<void> pumpBlueskyWaitingForApproval(WidgetTester tester) async {
      await cubit.close();
      cubit = VerifyConnectCubit(
        confirmationSignIn: false,
        readConfirmationAccess: _unknownAccess,
        repository: repository,
        pubkey: _pubkey,
        platform: _bluesky,
        oauthReturnUrl: _returnUrl,
        analytics: const NoOpAnalyticsEventSink(),
        launchOAuth: (_) async => Uri.parse(
          '$startedReturnUrl&platform=bluesky&identity=$blueskyHandle'
          '&oauth_confirm=${'C' * 43}',
        ),
      );
      await pumpWaitingForApproval(tester, handle: blueskyHandle);
    }

    testWidgets('keeps the typed Bluesky handle through a cancel', (
      tester,
    ) async {
      await pumpBlueskyWaitingForApproval(tester);
      expect(
        find.text(
          l10n.verifyConnectSignedInTitle(
            verifyPlatformLabel(_bluesky.key),
            blueskyHandle,
          ),
        ),
        findsOneWidget,
      );
      TextField handleField() => tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const ValueKey('verify-identity-field')),
          matching: find.byType(TextField),
        ),
      );
      expect(handleField().enabled, isFalse);

      await tester.tap(find.text(l10n.verifyConnectSignedInCancel));
      await tester.pump();

      expect(find.text(blueskyHandle), findsOneWidget);
      expect(handleField().enabled, isTrue);
      expect(cubit.state.identity, blueskyHandle);
    });

    testWidgets('hides the Bluesky proof note while the card is up', (
      tester,
    ) async {
      // "Signed in above? Nothing else needed." reads wrong while the card
      // still asks to link the account.
      final explainer = verifyProofExplainer(l10n, _bluesky.key);
      await pumpBlueskyWaitingForApproval(tester);

      expect(find.text(explainer), findsNothing);

      await tester.tap(find.text(l10n.verifyConnectSignedInCancel));
      await tester.pump();

      expect(find.text(explainer), findsOneWidget);
    });

    testWidgets("keeps other platforms' proof notes with the card up", (
      tester,
    ) async {
      await pumpWaitingForApproval(tester);

      expect(find.text(signedInTitle), findsOneWidget);
      expect(
        find.text(verifyProofExplainer(l10n, twitter.key)),
        findsOneWidget,
      );
    });

    testWidgets('says to sign in again when the verifier does not confirm', (
      tester,
    ) async {
      when(
        () => repository.confirmSignIn(
          code: any(named: 'code'),
          startSecret: any(named: 'startSecret'),
          signed: any(named: 'signed'),
        ),
      ).thenThrow(SignInConfirmException(401, SignInRefusal.notYours));
      await pumpWaitingForApproval(tester);

      await tester.tap(find.text(l10n.verifyConnectSignedInCta));
      await tester.pump();
      await tester.pump();

      expect(find.text(l10n.verifyErrorSignInNotConfirmed), findsOneWidget);
      expect(find.text(signedInTitle), findsNothing);
    });

    // With the flag off there is nowhere to buy, so a refusal is a snackbar
    // and nothing more [P2].
    testWidgets(
      'says linking by signing in needs Divine Confirmation, with no sheet',
      (tester) async {
        when(
          () => repository.confirmSignIn(
            code: any(named: 'code'),
            startSecret: any(named: 'startSecret'),
            signed: any(named: 'signed'),
          ),
        ).thenThrow(
          SignInConfirmException(403, SignInRefusal.confirmationRequired),
        );
        await pumpWaitingForApproval(tester);

        await tester.tap(find.text(l10n.verifyConnectSignedInCta));
        await tester.pump();
        await tester.pump();

        expect(
          find.text(l10n.verifyErrorConfirmationRequired),
          findsOneWidget,
        );
        expect(find.byType(BottomSheet), findsNothing);
        // The sign-in is dropped, so the proof post can be used.
        expect(find.text(signedInTitle), findsNothing);
      },
    );

    testWidgets("says Divine Confirmation couldn't be checked", (
      tester,
    ) async {
      when(
        () => repository.confirmSignIn(
          code: any(named: 'code'),
          startSecret: any(named: 'startSecret'),
          signed: any(named: 'signed'),
        ),
      ).thenThrow(
        SignInConfirmException(503, SignInRefusal.confirmationUnavailable),
      );
      await pumpWaitingForApproval(tester);

      await tester.tap(find.text(l10n.verifyConnectSignedInCta));
      // Past the retries inside the confirm window.
      await tester.pump();
      await tester.pump(const Duration(seconds: 10));
      await tester.pump();

      expect(
        find.text(l10n.verifyErrorConfirmationUnavailable),
        findsOneWidget,
      );
      expect(find.byType(BottomSheet), findsNothing);
      // Kept, so linking can be tried again in a few minutes.
      expect(find.text(signedInTitle), findsOneWidget);
    });

    testWidgets('says nothing was linked when the signer declines', (
      tester,
    ) async {
      when(
        () => repository.signClaim(
          any(),
          confirmBinding: any(named: 'confirmBinding'),
        ),
      ).thenThrow(
        const IdentityClaimNotSignedException(
          'Could not sign the identity event',
        ),
      );
      await pumpWaitingForApproval(tester);

      await tester.tap(find.text(l10n.verifyConnectSignedInCta));
      await tester.pump();
      await tester.pump();

      expect(find.text(l10n.verifyErrorNotSigned), findsOneWidget);
      expect(find.text(l10n.verifyErrorPublishFailed), findsNothing);
      // The sign-in is kept, so linking can be tried again.
      expect(find.text(signedInTitle), findsOneWidget);
    });

    testWidgets('says no relay took it when the publish fails', (
      tester,
    ) async {
      when(
        () => repository.publishSignedClaim(any()),
      ).thenThrow(const IdentityClaimPublishException('no relay confirmed'));
      await pumpWaitingForApproval(tester);

      await tester.tap(find.text(l10n.verifyConnectSignedInCta));
      await tester.pump();
      await tester.pump();

      expect(find.text(l10n.verifyErrorPublishFailed), findsOneWidget);
      expect(find.text(l10n.verifyErrorNotSigned), findsNothing);
    });

    testWidgets('tells a screen reader who the sign-in returned', (
      tester,
    ) async {
      final announced = _captureAnnouncements(tester);

      await pumpWaitingForApproval(tester);

      // The start button that had focus is gone, so this is how a screen
      // reader hears that the card arrived.
      expect(announced, [signedInTitle]);
    });

    testWidgets('does not announce the card again after a kept failure', (
      tester,
    ) async {
      when(
        () => repository.signClaim(
          any(),
          confirmBinding: any(named: 'confirmBinding'),
        ),
      ).thenThrow(
        const IdentityClaimNotSignedException(
          'Could not sign the identity event',
        ),
      );
      final announced = _captureAnnouncements(tester);
      await pumpWaitingForApproval(tester);

      await tester.tap(find.text(l10n.verifyConnectSignedInCta));
      await tester.pump();
      await tester.pump();

      // The snackbar speaks for the failure; the card was already there.
      expect(
        announced.where((message) => message == signedInTitle),
        hasLength(1),
      );
    });

    testWidgets('closes the proof form while a sign-in waits', (
      tester,
    ) async {
      await pumpWaitingForApproval(tester);
      // Text that isn't a link brings up the account field too.
      cubit.proofChanged('some nonsense');
      await tester.pump();

      final fields = tester.widgetList<TextField>(find.byType(TextField));
      expect(fields, hasLength(2));
      expect(fields.map((field) => field.enabled), everyElement(isFalse));
      expect(
        tester
            .widget<DivineButton>(button(l10n.verifyConnectProofCta))
            .onPressed,
        isNull,
      );
    });

    testWidgets('holds cancel while linking', (tester) async {
      final confirm = holdConfirm();
      await pumpWaitingForApproval(tester);

      await tester.tap(find.text(l10n.verifyConnectSignedInCta));
      await tester.pump();

      final link = tester.widget<DivineButton>(
        button(l10n.verifyConnectSignedInCta),
      );
      expect(link.isLoading, isTrue);
      expect(link.onPressed, isNull);
      expect(
        tester
            .widget<DivineButton>(button(l10n.verifyConnectSignedInCancel))
            .onPressed,
        isNull,
      );
      // The proof form below isn't what's working.
      final proof = tester.widget<DivineButton>(
        button(l10n.verifyConnectProofCta),
      );
      expect(proof.isLoading, isFalse);
      expect(proof.onPressed, isNull);

      confirm.complete(
        const SignInConfirmation(platform: 'twitter', identity: 'jack'),
      );
      await tester.pump();
    });

    testWidgets('stays on the page while linking', (tester) async {
      final confirm = holdConfirm();
      await pumpWaitingForApproval(tester);
      await tester.tap(find.text(l10n.verifyConnectSignedInCta));
      await tester.pump();

      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(VerifyConnectView), findsOneWidget);

      await tester.tap(find.bySemanticsIdentifier('back_button'));
      await tester.pump();
      expect(find.byType(VerifyConnectView), findsOneWidget);

      // Once linked, the page closes itself.
      confirm.complete(
        const SignInConfirmation(platform: 'twitter', identity: 'jack'),
      );
      await tester.pumpAndSettle();
      expect(find.byType(VerifyConnectView), findsNothing);
    });

    testWidgets('goes back while a sign-in waits', (tester) async {
      await pumpWaitingForApproval(tester);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byType(VerifyConnectView), findsNothing);
      expect(find.text('dashboard'), findsOneWidget);
    });

    testWidgets('the back button leaves while a sign-in waits', (
      tester,
    ) async {
      await pumpWaitingForApproval(tester);

      await tester.tap(find.bySemanticsIdentifier('back_button'));
      await tester.pumpAndSettle();

      expect(find.byType(VerifyConnectView), findsNothing);
    });
  });

  group('$VerifyConnectView once linked', () {
    const linked = IdentityClaim(
      pubkey: _pubkey,
      platform: 'twitter',
      identity: 'jack_renamed',
      proof: IdentityClaim.oauthProof,
    );
    const twitter = VerifierPlatform(
      key: 'twitter',
      label: 'Twitter / X',
      supported: true,
    );

    // Pushed from a stand-in dashboard that keeps what the flow hands back.
    Future<VerifyConnectResult?> linkAndReturn(
      WidgetTester tester,
      VerifyConnectState linkedState,
    ) async {
      final cubit = _MockVerifyConnectCubit();
      const editing = VerifyConnectState(platform: twitter);
      whenListen(
        cubit,
        Stream.value(linkedState),
        initialState: editing,
      );
      VerifyConnectResult? result;
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, _) => TextButton(
              onPressed: () async {
                result = await context.push<VerifyConnectResult>('/connect');
              },
              child: const Text('open'),
            ),
            routes: [
              GoRoute(
                path: 'connect',
                builder: (_, _) => BlocProvider<VerifyConnectCubit>.value(
                  value: cubit,
                  child: const VerifyConnectView(npub: _npub),
                ),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          routerConfig: router,
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('hands back the claim and the handle it replaced', (
      tester,
    ) async {
      final result = await linkAndReturn(
        tester,
        const VerifyConnectState(
          platform: twitter,
          status: VerifyConnectStatus.linked,
          linkedClaim: linked,
          replacedIdentity: 'jack',
        ),
      );

      expect(result?.linked, equals(linked));
      expect(result?.replacedIdentity, equals('jack'));
    });

    testWidgets('hands back no replaced handle when none was replaced', (
      tester,
    ) async {
      final result = await linkAndReturn(
        tester,
        const VerifyConnectState(
          platform: twitter,
          status: VerifyConnectStatus.linked,
          linkedClaim: linked,
        ),
      );

      expect(result?.linked, equals(linked));
      expect(result?.replacedIdentity, isNull);
    });
  });

  group('$VerifyConnectView Divine Confirmation', () {
    const twitterGated = VerifierPlatform(
      key: 'twitter',
      label: 'Twitter / X',
      supported: true,
      oauth: true,
      signinRequires: SigninRequirement.confirmation,
    );
    const blueskyGated = VerifierPlatform(
      key: 'bluesky',
      label: 'Bluesky',
      supported: true,
      oauth: true,
      signinRequires: SigninRequirement.confirmation,
    );
    final l10n = lookupAppLocalizations(const Locale('en'));
    final twitterLabel = verifyPlatformLabel(twitterGated.key);
    final signedInTitle = l10n.verifyConnectSignedInTitle(twitterLabel, 'jack');

    late _MockIdentityClaimsRepository repository;
    late VerifyConnectCubit cubit;
    late GoRouter router;
    late String startedReturnUrl;

    Finder button(String label) => find.byWidgetPredicate(
      (widget) => widget is DivineButton && widget.label == label,
    );
    Finder sheetButton(String label) =>
        find.descendant(of: find.byType(BottomSheet), matching: button(label));
    TextField fieldIn(WidgetTester tester, String key) =>
        tester.widget<TextField>(
          find.descendant(
            of: find.byKey(ValueKey(key)),
            matching: find.byType(TextField),
          ),
        );

    /// A reader that gives [answers] in turn, the last one from then on, and
    /// records whether each read asked to refresh.
    ConfirmationAccessReader answering(
      List<ConfirmationAccess> answers, {
      List<bool>? reads,
    }) {
      var next = 0;
      return ({bool refresh = false}) async {
        reads?.add(refresh);
        final answer =
            answers[next < answers.length ? next : answers.length - 1];
        next++;
        return answer;
      };
    }

    setUpAll(() {
      registerFallbackValue(
        const IdentityClaim(
          pubkey: _pubkey,
          platform: 'twitter',
          identity: 'jack',
          proof: IdentityClaim.oauthProof,
        ),
      );
      registerFallbackValue(_MockSignedIdentityClaim());
    });

    setUp(() {
      repository = _MockIdentityClaimsRepository();
      when(
        () => repository.startSignIn(
          platform: any(named: 'platform'),
          pubkey: any(named: 'pubkey'),
          returnUrl: any(named: 'returnUrl'),
          startCheck: any(named: 'startCheck'),
          handle: any(named: 'handle'),
        ),
      ).thenAnswer((invocation) async {
        startedReturnUrl = invocation.namedArguments[#returnUrl] as String;
        return Uri.parse('https://provider.example/authorize?state=s');
      });
      when(
        () => repository.signClaim(
          any(),
          confirmBinding: any(named: 'confirmBinding'),
          replacingIdentity: any(named: 'replacingIdentity'),
          replaceOnlySignIn: any(named: 'replaceOnlySignIn'),
        ),
      ).thenAnswer((_) async => _MockSignedIdentityClaim());
      when(
        () => repository.publishSignedClaim(any()),
      ).thenAnswer((_) async => []);
    });

    tearDown(() async {
      await cubit.close();
    });

    void refuseForConfirmation() {
      when(
        () => repository.confirmSignIn(
          code: any(named: 'code'),
          startSecret: any(named: 'startSecret'),
          signed: any(named: 'signed'),
        ),
      ).thenThrow(
        SignInConfirmException(403, SignInRefusal.confirmationRequired),
      );
    }

    // Pushed over a stand-in dashboard, beside a stand-in Confirmation screen
    // at its real location. Loads the platform as the page does, which reads
    // access with the flag on.
    Future<void> pump(
      WidgetTester tester, {
      required VerifierPlatform platform,
      required ConfirmationAccessReader readConfirmationAccess,
      bool confirmationSignIn = true,
      // The flag as the page draws with it, when it differs from the one the
      // flow started with.
      bool? drawnWithFlag,
      bool oauthAvailable = true,
      bool canBuy = true,
      String? replacingIdentity,
      String signedInAs = 'jack',
      Future<Uri?> Function(Uri)? launchOAuth,
      Size size = const Size(800, 1600),
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      when(
        () => repository.platform(platform.key),
      ).thenAnswer((_) async => platform);
      cubit = VerifyConnectCubit(
        confirmationSignIn: confirmationSignIn,
        readConfirmationAccess: readConfirmationAccess,
        repository: repository,
        pubkey: _pubkey,
        platform: platform,
        oauthReturnUrl: _returnUrl,
        analytics: const NoOpAnalyticsEventSink(),
        replacingIdentity: replacingIdentity,
        launchOAuth:
            launchOAuth ??
            (_) async => Uri.parse(
              '$startedReturnUrl&platform=${platform.key}'
              '&identity=$signedInAs&oauth_confirm=${'C' * 43}',
            ),
      );
      router = GoRouter(
        initialLocation: '/connect',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Text('dashboard'),
            routes: [
              GoRoute(
                path: 'connect',
                builder: (_, _) => BlocProvider<VerifyConnectCubit>.value(
                  value: cubit,
                  child: VerifyConnectView(
                    npub: _npub,
                    oauthAvailable: oauthAvailable,
                    confirmationSignIn: drawnWithFlag ?? confirmationSignIn,
                    canBuy: canBuy,
                  ),
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/verify/confirmation',
            builder: (_, _) => const Text('confirmation screen'),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          routerConfig: router,
        ),
      );
      unawaited(cubit.loadPlatform());
      await tester.pump();
      await tester.pump();
    }

    group('renders', () {
      testWidgets('hasNot replaces the sign-in button with the Confirmation '
          'card', (tester) async {
        await pump(
          tester,
          platform: twitterGated,
          readConfirmationAccess: answering([ConfirmationAccess.hasNot]),
        );

        expect(find.text(l10n.verifyConfirmationCardTitle), findsOneWidget);
        expect(find.text(l10n.verifyConfirmationCardBody), findsOneWidget);
        expect(button(l10n.verifyGetConfirmation), findsOneWidget);
        expect(
          find.text(l10n.verifyConnectOauthCta(twitterLabel)),
          findsNothing,
        );
        expect(find.text(l10n.verifyProofAlwaysAvailable), findsOneWidget);
        expect(find.text(l10n.verifyConnectProofCta), findsOneWidget);
      });

      for (final access in [
        ConfirmationAccess.has,
        ConfirmationAccess.unknown,
      ]) {
        testWidgets('${access.name} keeps the sign-in button', (tester) async {
          await pump(
            tester,
            platform: twitterGated,
            readConfirmationAccess: answering([access]),
          );

          expect(
            find.text(l10n.verifyConnectOauthCta(twitterLabel)),
            findsOneWidget,
          );
          expect(find.text(l10n.verifyConfirmationCardTitle), findsNothing);
          expect(find.text(l10n.verifyProofAlwaysAvailable), findsNothing);
        });
      }

      // Review Focus 2.
      testWidgets('flag off with the field present renders as today', (
        tester,
      ) async {
        final reads = <bool>[];
        await pump(
          tester,
          platform: twitterGated,
          confirmationSignIn: false,
          readConfirmationAccess: answering([
            ConfirmationAccess.hasNot,
          ], reads: reads),
        );

        expect(
          find.text(l10n.verifyConnectOauthCta(twitterLabel)),
          findsOneWidget,
        );
        expect(find.text(l10n.verifyConfirmationCardTitle), findsNothing);
        expect(find.text(l10n.verifyProofAlwaysAvailable), findsNothing);
        expect(reads, isEmpty);
      });

      // The page watches the flag while the cubit reads it once per flow, so
      // an answer read with it on can outlive it.
      testWidgets('turning the flag off hides the card', (tester) async {
        await pump(
          tester,
          platform: twitterGated,
          drawnWithFlag: false,
          readConfirmationAccess: answering([ConfirmationAccess.hasNot]),
        );

        expect(cubit.state.confirmationAccess, ConfirmationAccess.hasNot);
        expect(find.text(l10n.verifyConfirmationCardTitle), findsNothing);
        expect(
          find.text(l10n.verifyConnectOauthCta(twitterLabel)),
          findsOneWidget,
        );
      });

      testWidgets('iOS below 17.4 shows neither sign-in nor card', (
        tester,
      ) async {
        await pump(
          tester,
          platform: twitterGated,
          oauthAvailable: false,
          readConfirmationAccess: answering([ConfirmationAccess.hasNot]),
        );

        expect(
          find.text(l10n.verifyConnectOauthCta(twitterLabel)),
          findsNothing,
        );
        expect(find.text(l10n.verifyConfirmationCardTitle), findsNothing);
        expect(find.text(l10n.verifyProofAlwaysAvailable), findsNothing);
        expect(find.text(l10n.verifyConnectProofCta), findsOneWidget);
      });

      testWidgets('a build that cannot buy shows the store note in the card '
          '[P1]', (tester) async {
        await pump(
          tester,
          platform: twitterGated,
          canBuy: false,
          readConfirmationAccess: answering([ConfirmationAccess.hasNot]),
        );

        expect(find.text(l10n.verifyConfirmationCardTitle), findsOneWidget);
        expect(find.text(l10n.verifyConfirmationStoreOnly), findsOneWidget);
        expect(button(l10n.verifyGetConfirmation), findsNothing);
      });

      testWidgets('Bluesky hasNot moves the handle field to the proof block', (
        tester,
      ) async {
        await pump(
          tester,
          platform: blueskyGated,
          readConfirmationAccess: answering([ConfirmationAccess.hasNot]),
        );

        expect(find.text(l10n.verifyConfirmationCardTitle), findsOneWidget);
        final field = find.byKey(const ValueKey('verify-identity-field'));
        expect(field, findsOneWidget);
        expect(
          tester.getTopLeft(field).dy,
          greaterThan(
            tester.getTopLeft(find.text(l10n.verifyProofAlwaysAvailable)).dy,
          ),
        );
        expect(
          tester.getTopLeft(field).dy,
          greaterThan(
            tester.getTopLeft(find.text(l10n.verifyConfirmationCardTitle)).dy,
          ),
        );
      });

      // With the card in place of the sign-in button there is no sign-in
      // above, so the proof block gets one heading and the generic note.
      testWidgets('Bluesky hasNot shows one proof heading and the generic '
          'explainer', (tester) async {
        await pump(
          tester,
          platform: blueskyGated,
          readConfirmationAccess: answering([ConfirmationAccess.hasNot]),
        );

        expect(find.text(l10n.verifyProofAlwaysAvailable), findsOneWidget);
        expect(find.text(l10n.verifyConnectProofTitle), findsNothing);
        expect(
          find.text(l10n.verifyConnectProofExplainerBluesky),
          findsNothing,
        );
        expect(find.text(l10n.verifyConnectProofExplainer), findsOneWidget);
      });

      testWidgets('Bluesky with sign-in access keeps the proof title and the '
          'Bluesky explainer', (tester) async {
        await pump(
          tester,
          platform: blueskyGated,
          readConfirmationAccess: answering([ConfirmationAccess.has]),
        );

        expect(find.text(l10n.verifyConnectProofTitle), findsOneWidget);
        expect(find.text(l10n.verifyProofAlwaysAvailable), findsNothing);
        expect(
          find.text(l10n.verifyConnectProofExplainerBluesky),
          findsOneWidget,
        );
        expect(find.text(l10n.verifyConnectProofExplainer), findsNothing);
      });

      testWidgets('other platforms keep their own explainer under the card', (
        tester,
      ) async {
        await pump(
          tester,
          platform: twitterGated,
          readConfirmationAccess: answering([ConfirmationAccess.hasNot]),
        );

        expect(find.text(l10n.verifyProofAlwaysAvailable), findsOneWidget);
        expect(find.text(l10n.verifyConnectProofTitle), findsNothing);
        expect(
          find.text(l10n.verifyConnectProofExplainerTwitter),
          findsOneWidget,
        );
      });

      // Review Focus 5.
      testWidgets('a hasNot renewal of an expired link shows the card and the '
          'locked proof post', (tester) async {
        await pump(
          tester,
          platform: blueskyGated,
          replacingIdentity: 'alice.bsky.social',
          readConfirmationAccess: answering([ConfirmationAccess.hasNot]),
        );

        expect(find.text(l10n.verifyConfirmationCardTitle), findsOneWidget);
        expect(find.text(l10n.verifyConnectOauthCta('Bluesky')), findsNothing);
        expect(find.byKey(const ValueKey('verify-proof-field')), findsOne);
        final field = fieldIn(tester, 'verify-identity-field');
        expect(field.enabled, isFalse);
        expect(field.controller!.text, equals('alice.bsky.social'));
      });

      // Review Focus 1.
      testWidgets('access answering hasNot while a sign-in waits keeps the '
          'signed-in card', (tester) async {
        final access = Completer<ConfirmationAccess>();
        await pump(
          tester,
          platform: twitterGated,
          readConfirmationAccess: ({bool refresh = false}) => access.future,
        );
        await cubit.connectWithOAuth();
        await tester.pump();
        expect(find.text(signedInTitle), findsOneWidget);

        access.complete(ConfirmationAccess.hasNot);
        await tester.pump();
        await tester.pump();

        expect(cubit.state.confirmationAccess, ConfirmationAccess.hasNot);
        expect(find.text(signedInTitle), findsOneWidget);
        expect(button(l10n.verifyConnectSignedInCta), findsOneWidget);
        expect(find.text(l10n.verifyConfirmationCardTitle), findsNothing);

        // Only the start button gives way to the card.
        await tester.tap(find.text(l10n.verifyConnectSignedInCancel));
        await tester.pump();

        expect(find.text(signedInTitle), findsNothing);
        expect(find.text(l10n.verifyConfirmationCardTitle), findsOneWidget);
        expect(
          find.text(l10n.verifyConnectOauthCta(twitterLabel)),
          findsNothing,
        );
      });

      testWidgets('access answering hasNot while the browser is open keeps '
          'the start button', (tester) async {
        final access = Completer<ConfirmationAccess>();
        final browser = Completer<Uri?>();
        await pump(
          tester,
          platform: twitterGated,
          readConfirmationAccess: ({bool refresh = false}) => access.future,
          launchOAuth: (_) => browser.future,
        );
        unawaited(cubit.connectWithOAuth());
        await tester.pump();
        expect(cubit.state.status, VerifyConnectStatus.authorizing);

        access.complete(ConfirmationAccess.hasNot);
        await tester.pump();
        await tester.pump();

        expect(button(l10n.verifyConnectOauthCta(twitterLabel)), findsOne);
        expect(find.text(l10n.verifyConfirmationCardTitle), findsNothing);

        browser.complete(null);
        await tester.pump();
      });
    });

    group('interactions', () {
      Future<void> refuseAndOpenSheet(WidgetTester tester) async {
        await cubit.connectWithOAuth();
        await tester.pump();
        await tester.tap(find.text(l10n.verifyConnectSignedInCta));
        await tester.pump();
        await tester.pump();
        await tester.pumpAndSettle();
      }

      testWidgets('confirmation_required with the flag on opens the sheet, '
          'not a snackbar [P2]', (tester) async {
        refuseForConfirmation();
        await pump(
          tester,
          platform: twitterGated,
          readConfirmationAccess: answering([ConfirmationAccess.unknown]),
        );
        await refuseAndOpenSheet(tester);

        expect(find.byType(BottomSheet), findsOneWidget);
        expect(find.text(l10n.verifyConfirmationSheetTitle), findsOneWidget);
        expect(find.text(l10n.verifyConfirmationSheetSubtitle), findsOneWidget);
        expect(sheetButton(l10n.verifyGetConfirmation), findsOneWidget);
        expect(sheetButton(l10n.verifyConfirmationSheetUseProof), findsOne);
        expect(find.text(l10n.verifyErrorConfirmationRequired), findsNothing);
        // Kept, to approve once Confirmation is bought.
        expect(cubit.state.signedInAccount, equals('jack'));
      });

      testWidgets('the sheet in a build that cannot buy has no buy button '
          '[P1]', (tester) async {
        refuseForConfirmation();
        await pump(
          tester,
          platform: twitterGated,
          canBuy: false,
          readConfirmationAccess: answering([ConfirmationAccess.unknown]),
        );
        await refuseAndOpenSheet(tester);

        expect(find.text(l10n.verifyConfirmationSheetTitle), findsOneWidget);
        expect(sheetButton(l10n.verifyGetConfirmation), findsNothing);
        expect(
          find.descendant(
            of: find.byType(BottomSheet),
            matching: find.text(l10n.verifyConfirmationStoreOnly),
          ),
          findsOneWidget,
        );
        expect(sheetButton(l10n.verifyConfirmationSheetUseProof), findsOne);
      });

      // Leaving for the Confirmation screen mid-attempt would put it where
      // the listener pops with the linked claim, so the dashboard never gets
      // it.
      testWidgets('holds the card button while a proof post is checked and '
          'published', (tester) async {
        final verifying = Completer<VerificationResult>();
        final publishing = Completer<List<List<String>>>();
        when(
          () => repository.verifyClaim(any()),
        ).thenAnswer((_) => verifying.future);
        when(
          () => repository.publishClaim(
            any(),
            replacingIdentity: any(named: 'replacingIdentity'),
          ),
        ).thenAnswer((_) => publishing.future);
        await pump(
          tester,
          platform: twitterGated,
          readConfirmationAccess: answering([ConfirmationAccess.hasNot]),
        );
        await tester.enterText(
          find.byKey(const ValueKey('verify-proof-field')),
          'https://x.com/jack/status/123',
        );
        await tester.pump();
        await tester.tap(button(l10n.verifyConnectProofCta));
        await tester.pump();

        for (final status in [
          VerifyConnectStatus.verifying,
          VerifyConnectStatus.publishing,
        ]) {
          expect(cubit.state.status, status);
          expect(
            tester
                .widget<DivineButton>(button(l10n.verifyGetConfirmation))
                .onPressed,
            isNull,
          );
          await tester.tap(button(l10n.verifyGetConfirmation));
          // Not pumpAndSettle: the proof button's spinner never settles.
          await tester.pump(const Duration(seconds: 1));
          expect(find.text('confirmation screen'), findsNothing);
          if (status == VerifyConnectStatus.verifying) {
            verifying.complete(
              const VerificationResult(
                platform: 'twitter',
                identity: 'jack',
                verified: true,
                checkedAt: 1,
                cached: false,
              ),
            );
            await tester.pump();
            await tester.pump();
          }
        }

        publishing.complete([]);
        await tester.pumpAndSettle();
        expect(find.text('dashboard'), findsOneWidget);
      });

      testWidgets('Use a proof post cancels the sign-in and enables the proof '
          'field [D3b]', (tester) async {
        refuseForConfirmation();
        await pump(
          tester,
          platform: twitterGated,
          readConfirmationAccess: answering([ConfirmationAccess.unknown]),
        );
        await refuseAndOpenSheet(tester);
        expect(fieldIn(tester, 'verify-proof-field').enabled, isFalse);

        await tester.tap(sheetButton(l10n.verifyConfirmationSheetUseProof));
        await tester.pumpAndSettle();

        expect(find.byType(BottomSheet), findsNothing);
        expect(cubit.state.signedInAccount, isNull);
        expect(find.text(signedInTitle), findsNothing);
        expect(fieldIn(tester, 'verify-proof-field').enabled, isTrue);
        // The refusal said no access, so the card stands where a start
        // button would lead to the same refusal.
        expect(find.text(l10n.verifyConfirmationCardTitle), findsOneWidget);
        expect(
          find.text(l10n.verifyConnectOauthCta(twitterLabel)),
          findsNothing,
        );
      });

      testWidgets('Use a proof post scrolls the proof post into view', (
        tester,
      ) async {
        refuseForConfirmation();
        await pump(
          tester,
          platform: twitterGated,
          readConfirmationAccess: answering([ConfirmationAccess.unknown]),
          // Short enough that the proof post starts below the fold.
          size: const Size(800, 300),
        );
        final list = find.byType(Scrollable).first;
        double offset() => tester.state<ScrollableState>(list).position.pixels;
        await refuseAndOpenSheet(tester);
        expect(offset(), equals(0));

        // The sheet scrolls on a screen this short.
        final useProof = sheetButton(l10n.verifyConfirmationSheetUseProof);
        await tester.ensureVisible(useProof);
        await tester.pumpAndSettle();
        await tester.tap(useProof);
        await tester.pumpAndSettle();

        expect(offset(), greaterThan(0));
      });

      testWidgets('Use a proof post jumps there at once with reduced motion', (
        tester,
      ) async {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        refuseForConfirmation();
        await pump(
          tester,
          platform: twitterGated,
          readConfirmationAccess: answering([ConfirmationAccess.unknown]),
          size: const Size(800, 300),
        );
        final list = find.byType(Scrollable).first;
        double offset() => tester.state<ScrollableState>(list).position.pixels;
        await refuseAndOpenSheet(tester);
        final useProof = sheetButton(l10n.verifyConfirmationSheetUseProof);
        await tester.ensureVisible(useProof);
        await tester.pumpAndSettle();
        await tester.tap(useProof);
        // No time passes: an animated scroll would still be at its start.
        await tester.pump();
        await tester.pump();
        await tester.pump();

        expect(offset(), greaterThan(0));
      });

      // Carried from Task 5: the renewal kept a sign-in for another handle
      // while the proof form shows the renewed one.
      testWidgets('Use a proof post in a renewal drops the other handle and '
          'opens the locked proof post', (tester) async {
        refuseForConfirmation();
        await pump(
          tester,
          platform: twitterGated,
          replacingIdentity: 'jack',
          signedInAs: 'someone_else',
          readConfirmationAccess: answering([ConfirmationAccess.unknown]),
        );
        await refuseAndOpenSheet(tester);
        expect(cubit.state.signedInAccount, equals('someone_else'));

        await tester.tap(sheetButton(l10n.verifyConfirmationSheetUseProof));
        await tester.pumpAndSettle();

        expect(cubit.state.signedInAccount, isNull);
        expect(cubit.state.identity, equals('jack'));
        expect(fieldIn(tester, 'verify-proof-field').enabled, isTrue);
        expect(find.text(l10n.verifyConnectProofCta), findsOneWidget);
      });

      testWidgets('returning from the Confirmation screen with access shows '
          'the sign-in again', (tester) async {
        final reads = <bool>[];
        await pump(
          tester,
          platform: twitterGated,
          readConfirmationAccess: answering([
            ConfirmationAccess.hasNot,
            ConfirmationAccess.has,
          ], reads: reads),
        );

        await tester.tap(button(l10n.verifyGetConfirmation));
        await tester.pumpAndSettle();
        expect(find.text('confirmation screen'), findsOneWidget);

        router.pop();
        await tester.pumpAndSettle();

        expect(reads, equals([false, true]));
        expect(find.text(l10n.verifyConfirmationCardTitle), findsNothing);
        expect(
          find.text(l10n.verifyConnectOauthCta(twitterLabel)),
          findsOneWidget,
        );
      });

      testWidgets('returning from the Confirmation screen opened from the '
          'sheet re-reads access and keeps the sign-in', (tester) async {
        refuseForConfirmation();
        final reads = <bool>[];
        await pump(
          tester,
          platform: twitterGated,
          readConfirmationAccess: answering([
            ConfirmationAccess.unknown,
            ConfirmationAccess.has,
          ], reads: reads),
        );
        await refuseAndOpenSheet(tester);

        await tester.tap(sheetButton(l10n.verifyGetConfirmation));
        await tester.pumpAndSettle();
        expect(find.text('confirmation screen'), findsOneWidget);

        router.pop();
        await tester.pumpAndSettle();

        expect(reads, equals([false, true]));
        expect(cubit.state.confirmationAccess, ConfirmationAccess.has);
        expect(find.text(signedInTitle), findsOneWidget);
        expect(button(l10n.verifyConnectSignedInCta), findsOneWidget);
      });

      // Access read "has" on the way back, yet the verifier refuses again:
      // a purchase its gate hasn't caught up with. Offering to buy it again
      // would be wrong, so it says to wait instead.
      testWidgets('a second refusal after buying says Confirmation is still '
          'on its way, with no sheet', (tester) async {
        refuseForConfirmation();
        await pump(
          tester,
          platform: twitterGated,
          readConfirmationAccess: answering([
            ConfirmationAccess.unknown,
            ConfirmationAccess.has,
          ]),
        );
        await refuseAndOpenSheet(tester);
        await tester.tap(sheetButton(l10n.verifyGetConfirmation));
        await tester.pumpAndSettle();
        router.pop();
        await tester.pumpAndSettle();
        expect(cubit.state.confirmationAccess, ConfirmationAccess.has);

        await tester.tap(button(l10n.verifyConnectSignedInCta));
        await tester.pump();
        await tester.pump();
        await tester.pumpAndSettle();

        expect(cubit.state.error, VerifyConnectError.confirmationPending);
        expect(find.text(l10n.verifyErrorConfirmationPending), findsOneWidget);
        expect(find.text(l10n.verifyErrorConfirmationRequired), findsNothing);
        expect(find.byType(BottomSheet), findsNothing);
        // Kept, to approve once the purchase reaches the verifier.
        expect(cubit.state.signedInAccount, equals('jack'));
        expect(find.text(signedInTitle), findsOneWidget);
        expect(button(l10n.verifyConnectSignedInCta), findsOneWidget);
      });

      testWidgets('dismissing the sheet keeps the sign-in to approve or '
          'cancel', (tester) async {
        refuseForConfirmation();
        await pump(
          tester,
          platform: twitterGated,
          readConfirmationAccess: answering([ConfirmationAccess.unknown]),
        );
        await refuseAndOpenSheet(tester);
        expect(find.byType(BottomSheet), findsOneWidget);

        // The barrier above the sheet, not one of its buttons.
        await tester.tapAt(const Offset(400, 20));
        await tester.pumpAndSettle();

        expect(find.byType(BottomSheet), findsNothing);
        expect(find.text('confirmation screen'), findsNothing);
        expect(cubit.state.signedInAccount, equals('jack'));
        expect(find.text(signedInTitle), findsOneWidget);
        expect(button(l10n.verifyConnectSignedInCta), findsOneWidget);
        // The waiting sign-in still holds the proof post closed.
        expect(fieldIn(tester, 'verify-proof-field').enabled, isFalse);
      });
    });
  });
}
