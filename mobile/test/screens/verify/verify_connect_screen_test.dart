// ABOUTME: Widget tests for the single-platform verify connect form.
// ABOUTME: Covers when sign-in is offered, the manual account fallback used
// ABOUTME: when a proof link is opaque, and approving a returned sign-in.

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
import 'package:openvine/blocs/verify/verify_connect_cubit.dart';
import 'package:openvine/features/oauth/app_oauth_support.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/auth_state.dart';
import 'package:openvine/providers/analytics_providers.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/screens/verify/verify_connect_screen.dart';
import 'package:openvine/screens/verify/verify_platform_labels.dart';
import 'package:profile_repository/profile_repository.dart';

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
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            identityClaimsRepositoryProvider.overrideWithValue(repository),
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
}
