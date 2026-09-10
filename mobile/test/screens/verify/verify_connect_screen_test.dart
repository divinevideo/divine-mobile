// ABOUTME: Widget tests for the single-platform verify connect form.
// ABOUTME: Covers the manual account fallback used when a proof link is opaque.

import 'package:analytics/analytics.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart' hide VerificationResult;
import 'package:openvine/blocs/verify/verify_connect_cubit.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/screens/verify/verify_connect_screen.dart';
import 'package:openvine/screens/verify/verify_platform_labels.dart';
import 'package:profile_repository/profile_repository.dart';

class _MockIdentityClaimsRepository extends Mock
    implements IdentityClaimsRepository {}

class _MockAnalyticsEventSink extends Mock implements AnalyticsEventSink {}

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
          localizationsDelegates: AppLocalizations.localizationsDelegates,
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
          localizationsDelegates: AppLocalizations.localizationsDelegates,
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
          localizationsDelegates: AppLocalizations.localizationsDelegates,
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
      // Not verifyIdentityHint('bluesky') — that is 'alice.bsky.social', and
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
}
