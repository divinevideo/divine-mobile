// ABOUTME: Tests linking one platform — proof post and OAuth — and that a
// ABOUTME: claim is published only once the verifier has confirmed it.

import 'dart:async';

import 'package:analytics/analytics.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart' hide VerificationResult;
import 'package:openvine/blocs/verify/verify_connect_cubit.dart';
import 'package:profile_repository/profile_repository.dart';

class _MockIdentityClaimsRepository extends Mock
    implements IdentityClaimsRepository {}

class _MockAnalyticsEventSink extends Mock implements AnalyticsEventSink {}

const _pubkey =
    '1111111111111111111111111111111111111111111111111111111111111111';
const _returnUrl = 'https://divine.video/app/callback';

const _github = VerifierPlatform(
  key: 'github',
  label: 'GitHub',
  supported: true,
);
const _twitter = VerifierPlatform(
  key: 'twitter',
  label: 'Twitter / X',
  supported: true,
);
const _bluesky = VerifierPlatform(
  key: 'bluesky',
  label: 'Bluesky',
  supported: true,
);
const _telegram = VerifierPlatform(
  key: 'telegram',
  label: 'Telegram',
  supported: true,
);
const _discord = VerifierPlatform(
  key: 'discord',
  label: 'Discord',
  supported: true,
);
const _youtube = VerifierPlatform(
  key: 'youtube',
  label: 'YouTube',
  supported: true,
);

VerificationResult _result({required bool verified, String? code}) =>
    VerificationResult(
      platform: 'github',
      identity: 'octocat',
      verified: verified,
      checkedAt: 1,
      cached: false,
      code: code,
    );

void main() {
  group(VerifyConnectCubit, () {
    late _MockIdentityClaimsRepository repository;
    late _MockAnalyticsEventSink analytics;
    late List<Uri> launched;
    late Uri? callback;

    setUpAll(() {
      registerFallbackValue(
        const IdentityClaim(
          pubkey: _pubkey,
          platform: 'github',
          identity: 'octocat',
          proof: 'abc',
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
      launched = [];
      callback = Uri.parse(
        '$_returnUrl?oauth_verified=true&platform=twitter&identity=jack',
      );
      when(
        () => repository.verifyClaim(any()),
      ).thenAnswer((_) async => _result(verified: true));
      when(() => repository.publishClaim(any())).thenAnswer((_) async => []);
      when(
        () => repository.resolveOAuthLaunchUri(
          platform: any(named: 'platform'),
          pubkey: any(named: 'pubkey'),
          returnUrl: any(named: 'returnUrl'),
          handle: any(named: 'handle'),
        ),
      ).thenAnswer(
        (_) async => Uri.parse('https://provider.example/authorize?state=s'),
      );
    });

    VerifyConnectCubit build(VerifierPlatform platform) => VerifyConnectCubit(
      repository: repository,
      pubkey: _pubkey,
      platform: platform,
      oauthReturnUrl: _returnUrl,
      analytics: analytics,
      launchOAuth: (uri) async {
        launched.add(uri);
        return callback;
      },
    );

    group('submitProof', () {
      blocTest<VerifyConnectCubit, VerifyConnectState>(
        'shows the reason the verifier gave rather than blaming the npub',
        setUp: () {
          when(() => repository.verifyClaim(any())).thenAnswer(
            (_) async =>
                _result(verified: false, code: 'discord_author_mismatch'),
          );
        },
        build: () => build(_discord),
        act: (cubit) async {
          cubit
            ..identityChanged('alice')
            ..proofChanged('https://discord.com/channels/1/2/3');
          await cubit.submitProof();
        },
        verify: (cubit) {
          expect(
            cubit.state.error,
            VerifyConnectError.discordAuthorMismatch,
          );
        },
      );

      blocTest<VerifyConnectCubit, VerifyConnectState>(
        'counts the rejection by reason, carrying nothing that identifies anyone',
        setUp: () {
          when(() => repository.verifyClaim(any())).thenAnswer(
            (_) async =>
                _result(verified: false, code: 'discord_bot_no_access'),
          );
        },
        build: () => build(_discord),
        act: (cubit) async {
          cubit
            ..identityChanged('alice')
            ..proofChanged('https://discord.com/channels/1/2/3');
          await cubit.submitProof();
        },
        verify: (_) {
          verify(
            () => analytics.logEvent(
              name: 'verify_proof_rejected',
              parameters: {
                'platform': 'discord',
                'reason': 'discord_bot_no_access',
              },
            ),
          ).called(1);
        },
      );

      blocTest<VerifyConnectCubit, VerifyConnectState>(
        'names an absent code rather than dropping the event',
        setUp: () {
          when(
            () => repository.verifyClaim(any()),
          ).thenAnswer((_) async => _result(verified: false));
        },
        build: () => build(_github),
        act: (cubit) async {
          cubit
            ..identityChanged('octocat')
            ..proofChanged('abc');
          await cubit.submitProof();
        },
        verify: (_) {
          verify(
            () => analytics.logEvent(
              name: 'verify_proof_rejected',
              parameters: {'platform': 'github', 'reason': 'none'},
            ),
          ).called(1);
        },
      );

      blocTest<VerifyConnectCubit, VerifyConnectState>(
        'publishes the claim once the verifier confirms it',
        build: () => build(_github),
        act: (cubit) async {
          cubit
            ..identityChanged('octocat')
            ..proofChanged('https://gist.github.com/octocat/abc');
          await cubit.submitProof();
        },
        verify: (cubit) {
          expect(cubit.state.status, equals(VerifyConnectStatus.linked));
          final claim =
              verify(
                    () => repository.publishClaim(captureAny()),
                  ).captured.single
                  as IdentityClaim;
          expect(claim.platform, equals('github'));
          expect(claim.identity, equals('octocat'));
          // The pasted link is split into the id the verifier looks up.
          expect(claim.proof, equals('abc'));
          // Handed back so the dashboard can render it straight away.
          expect(cubit.state.linkedClaim, equals(claim));
        },
      );

      blocTest<VerifyConnectCubit, VerifyConnectState>(
        'publishes nothing when the proof does not check out',
        build: () => build(_github),
        setUp: () {
          when(
            () => repository.verifyClaim(any()),
          ).thenAnswer((_) async => _result(verified: false));
        },
        act: (cubit) async {
          cubit
            ..identityChanged('octocat')
            ..proofChanged('https://gist.github.com/octocat/abc');
          await cubit.submitProof();
        },
        verify: (cubit) {
          expect(cubit.state.error, equals(VerifyConnectError.proofRejected));
          expect(cubit.state.status, equals(VerifyConnectStatus.editing));
          verifyNever(() => repository.publishClaim(any()));
        },
      );

      blocTest<VerifyConnectCubit, VerifyConnectState>(
        'reports an unreachable verifier separately from a rejection',
        build: () => build(_github),
        setUp: () {
          when(
            () => repository.verifyClaim(any()),
          ).thenThrow(const VerifierNetworkException('offline'));
        },
        act: (cubit) async {
          cubit
            ..identityChanged('octocat')
            ..proofChanged('abc');
          await cubit.submitProof();
        },
        verify: (cubit) {
          expect(
            cubit.state.error,
            equals(VerifyConnectError.verifierUnreachable),
          );
        },
        errors: () => [isA<VerifierNetworkException>()],
      );

      blocTest<VerifyConnectCubit, VerifyConnectState>(
        'surfaces a publish that no relay accepted',
        build: () => build(_github),
        setUp: () {
          when(() => repository.publishClaim(any())).thenThrow(
            const IdentityClaimPublishException('no relay confirmed'),
          );
        },
        act: (cubit) async {
          cubit
            ..identityChanged('octocat')
            ..proofChanged('abc');
          await cubit.submitProof();
        },
        verify: (cubit) {
          expect(cubit.state.error, equals(VerifyConnectError.publishFailed));
          expect(cubit.state.status, equals(VerifyConnectStatus.editing));
        },
        errors: () => [isA<IdentityClaimPublishException>()],
      );

      blocTest<VerifyConnectCubit, VerifyConnectState>(
        'separates an unreadable link list from a failed publish',
        build: () => build(_github),
        setUp: () {
          when(
            () => repository.publishClaim(any()),
          ).thenThrow(const IdentityClaimReadException('relays went quiet'));
        },
        act: (cubit) async {
          cubit
            ..identityChanged('octocat')
            ..proofChanged('abc');
          await cubit.submitProof();
        },
        verify: (cubit) {
          expect(cubit.state.error, equals(VerifyConnectError.linksUnreadable));
        },
        errors: () => [isA<IdentityClaimReadException>()],
      );

      blocTest<VerifyConnectCubit, VerifyConnectState>(
        'does nothing without an account name',
        build: () => build(_github),
        act: (cubit) async {
          cubit.proofChanged('abc');
          await cubit.submitProof();
        },
        verify: (_) {
          verifyNever(() => repository.verifyClaim(any()));
        },
      );

      blocTest<VerifyConnectCubit, VerifyConnectState>(
        'sends the id from a pasted post link, not the link',
        build: () => build(_github),
        act: (cubit) async {
          cubit.proofChanged('https://gist.github.com/octocat/abc123');
          await cubit.submitProof();
        },
        verify: (_) {
          final claim =
              verify(() => repository.verifyClaim(captureAny())).captured.single
                  as IdentityClaim;
          expect(claim.identity, equals('octocat'));
          expect(claim.proof, equals('abc123'));
        },
      );

      blocTest<VerifyConnectCubit, VerifyConnectState>(
        'says why a private telegram link cannot work, before asking',
        build: () => build(_telegram),
        act: (cubit) async {
          cubit.proofChanged('https://t.me/c/2812345678/42');
          // The button stays live so pressing it is what explains the problem.
          expect(cubit.state.canSubmitProof, isTrue);
          await cubit.submitProof();
        },
        verify: (cubit) {
          expect(
            cubit.state.error,
            equals(VerifyConnectError.telegramNotPublic),
          );
          verifyNever(() => repository.verifyClaim(any()));
        },
      );

      blocTest<VerifyConnectCubit, VerifyConnectState>(
        'accepts an empty proof for bluesky, which resolves it itself',
        build: () => build(_bluesky),
        act: (cubit) async {
          cubit.identityChanged('alice.bsky.social');
          await cubit.submitProof();
        },
        verify: (_) {
          verify(() => repository.verifyClaim(any())).called(1);
        },
      );

      test(
        'returns quietly when closed before verification completes',
        () async {
          final verified = Completer<VerificationResult>();
          when(() => repository.verifyClaim(any())).thenAnswer(
            (_) => verified.future,
          );
          final cubit = build(_github)
            ..identityChanged('octocat')
            ..proofChanged('https://gist.github.com/octocat/abc');

          final submit = cubit.submitProof();
          await Future<void>.delayed(Duration.zero);
          await cubit.close();
          verified.complete(_result(verified: true));

          await submit;
          verifyNever(() => repository.publishClaim(any()));
        },
      );

      test('returns quietly when closed before publishing completes', () async {
        final published = Completer<List<List<String>>>();
        when(() => repository.publishClaim(any())).thenAnswer(
          (_) => published.future,
        );
        final cubit = build(_github)
          ..identityChanged('octocat')
          ..proofChanged('https://gist.github.com/octocat/abc');

        final submit = cubit.submitProof();
        await Future<void>.delayed(Duration.zero);
        await cubit.close();
        published.complete(const []);

        await submit;
      });
    });

    group('connectWithOAuth', () {
      blocTest<VerifyConnectCubit, VerifyConnectState>(
        'never opens a browser when the flow is not configured',
        build: () => build(_twitter),
        setUp: () {
          when(
            () => repository.resolveOAuthLaunchUri(
              platform: any(named: 'platform'),
              pubkey: any(named: 'pubkey'),
              returnUrl: any(named: 'returnUrl'),
              handle: any(named: 'handle'),
            ),
          ).thenAnswer((_) async => null);
        },
        act: (cubit) => cubit.connectWithOAuth(),
        verify: (cubit) {
          expect(
            cubit.state.error,
            equals(VerifyConnectError.oauthUnavailable),
          );
          expect(launched, isEmpty);
          expect(cubit.state.status, equals(VerifyConnectStatus.editing));
        },
      );

      blocTest<VerifyConnectCubit, VerifyConnectState>(
        'returns to editing when resolving the OAuth URL throws',
        build: () => build(_twitter),
        setUp: () {
          when(
            () => repository.resolveOAuthLaunchUri(
              platform: any(named: 'platform'),
              pubkey: any(named: 'pubkey'),
              returnUrl: any(named: 'returnUrl'),
              handle: any(named: 'handle'),
            ),
          ).thenThrow(const FormatException('bad start URL'));
        },
        act: (cubit) => cubit.connectWithOAuth(),
        verify: (cubit) {
          expect(cubit.state.error, equals(VerifyConnectError.oauthFailed));
          expect(cubit.state.status, equals(VerifyConnectStatus.editing));
          expect(launched, isEmpty);
        },
        errors: () => [isA<FormatException>()],
      );

      blocTest<VerifyConnectCubit, VerifyConnectState>(
        'publishes the account the provider confirmed',
        build: () => build(_twitter),
        act: (cubit) => cubit.connectWithOAuth(),
        verify: (cubit) {
          expect(cubit.state.status, equals(VerifyConnectStatus.linked));
          final claim =
              verify(
                    () => repository.publishClaim(captureAny()),
                  ).captured.single
                  as IdentityClaim;
          expect(claim.identity, equals('jack'));
          expect(claim.proof, equals(IdentityClaim.oauthProof));
          expect(launched, hasLength(1));
          expect(cubit.state.linkedClaim, equals(claim));
        },
      );

      blocTest<VerifyConnectCubit, VerifyConnectState>(
        'returns to the form without an error when dismissed',
        build: () => build(_twitter),
        setUp: () => callback = null,
        act: (cubit) => cubit.connectWithOAuth(),
        verify: (cubit) {
          expect(cubit.state.status, equals(VerifyConnectStatus.editing));
          expect(cubit.state.error, isNull);
          verifyNever(() => repository.publishClaim(any()));
        },
      );

      blocTest<VerifyConnectCubit, VerifyConnectState>(
        'treats a denied callback as a failure',
        build: () => build(_twitter),
        setUp: () => callback = Uri.parse(
          '$_returnUrl?oauth_error=Verification%20failed',
        ),
        act: (cubit) => cubit.connectWithOAuth(),
        verify: (cubit) {
          expect(cubit.state.error, equals(VerifyConnectError.oauthFailed));
          verifyNever(() => repository.publishClaim(any()));
        },
      );

      blocTest<VerifyConnectCubit, VerifyConnectState>(
        'keeps an expected provider refusal out of Bloc errors',
        build: () => build(_twitter),
        setUp: () => callback = Uri.parse(
          '$_returnUrl?oauth_error=Verification%20failed',
        ),
        act: (cubit) => cubit.connectWithOAuth(),
        verify: (cubit) {
          expect(cubit.state.error, equals(VerifyConnectError.oauthFailed));
        },
        // Free-form verifier refusals are expected domain outcomes. They are
        // warning logs, not Bloc errors, so they cannot be misclassified as
        // reportable StateErrors by DivineBlocObserver.
        errors: () => const [],
      );

      blocTest<VerifyConnectCubit, VerifyConnectState>(
        'refuses a success that names no account',
        build: () => build(_twitter),
        setUp: () => callback = Uri.parse(
          '$_returnUrl?oauth_verified=true&platform=twitter&identity=',
        ),
        act: (cubit) => cubit.connectWithOAuth(),
        verify: (cubit) {
          expect(cubit.state.error, equals(VerifyConnectError.oauthFailed));
          verifyNever(() => repository.publishClaim(any()));
        },
      );

      blocTest<VerifyConnectCubit, VerifyConnectState>(
        'asks for the handle before starting bluesky',
        build: () => build(_bluesky),
        act: (cubit) => cubit.connectWithOAuth(),
        verify: (cubit) {
          expect(cubit.state.error, equals(VerifyConnectError.handleRequired));
          expect(launched, isEmpty);
        },
      );

      blocTest<VerifyConnectCubit, VerifyConnectState>(
        'passes the bluesky handle to the start URL, and starts once',
        build: () => build(_bluesky),
        setUp: () => callback = Uri.parse(
          '$_returnUrl?oauth_verified=true&platform=bluesky'
          '&identity=alice.bsky.social',
        ),
        act: (cubit) async {
          cubit.identityChanged('alice.bsky.social');
          await cubit.connectWithOAuth();
        },
        verify: (_) {
          // Bluesky's start resolves the PDS and pushes a PAR to it, so the
          // browser has to open on the resolved provider URL rather than on
          // the start endpoint a second time.
          verify(
            () => repository.resolveOAuthLaunchUri(
              platform: 'bluesky',
              pubkey: _pubkey,
              returnUrl: _returnUrl,
              handle: 'alice.bsky.social',
            ),
          ).called(1);
          expect(
            launched,
            equals([Uri.parse('https://provider.example/authorize?state=s')]),
          );
        },
      );

      blocTest<VerifyConnectCubit, VerifyConnectState>(
        'reports a browser session that threw',
        build: () => VerifyConnectCubit(
          repository: repository,
          pubkey: _pubkey,
          platform: _twitter,
          oauthReturnUrl: _returnUrl,
          analytics: analytics,
          launchOAuth: (_) async => throw const FormatException('bad callback'),
        ),
        act: (cubit) => cubit.connectWithOAuth(),
        verify: (cubit) {
          expect(cubit.state.error, equals(VerifyConnectError.oauthFailed));
        },
        errors: () => [isA<FormatException>()],
      );

      test('returns quietly when closed before the browser returns', () async {
        final browser = Completer<Uri?>();
        final cubit = VerifyConnectCubit(
          repository: repository,
          pubkey: _pubkey,
          platform: _twitter,
          oauthReturnUrl: _returnUrl,
          analytics: analytics,
          launchOAuth: (uri) {
            launched.add(uri);
            return browser.future;
          },
        );

        final connect = cubit.connectWithOAuth();
        await Future<void>.delayed(Duration.zero);
        await cubit.close();
        browser.complete(callback);

        await connect;
        verifyNever(() => repository.publishClaim(any()));
      });
    });

    group('needsIdentityInput', () {
      test('stays out of the way when the link carries the account', () {
        final cubit = build(_telegram);
        addTearDown(cubit.close);

        // Nothing pasted yet: the link field is the only thing to fill in.
        expect(cubit.state.needsIdentityInput, isFalse);

        cubit.proofChanged('https://t.me/testdivine/2');
        expect(cubit.state.needsIdentityInput, isFalse);
        expect(cubit.state.normalizedInput.identity, equals('testdivine'));
      });

      test('appears when the pasted text is not a link we can read', () {
        final cubit = build(_telegram);
        addTearDown(cubit.close);

        cubit.proofChanged('some nonsense');

        expect(cubit.state.needsIdentityInput, isTrue);
      });

      test('stays visible after the user starts typing the account', () {
        final cubit = build(_telegram);
        addTearDown(cubit.close);

        cubit
          ..proofChanged('some nonsense')
          ..identityChanged('testdivine');

        expect(cubit.state.needsIdentityInput, isTrue);
        expect(cubit.state.canSubmitProof, isTrue);
      });

      test('always asks where the link cannot carry the account', () {
        for (final platform in [_discord, _youtube, _bluesky]) {
          final cubit = build(platform);
          addTearDown(cubit.close);

          expect(
            cubit.state.needsIdentityInput,
            isTrue,
            reason: '${platform.key} links do not name the account',
          );
        }
      });
    });

    test('trims whitespace off the inputs', () {
      final cubit = build(_github);
      addTearDown(cubit.close);

      cubit
        ..identityChanged('  octocat ')
        ..proofChanged('  abc ');

      expect(cubit.state.identity, equals('octocat'));
      expect(cubit.state.proof, equals('abc'));
    });
  });
}
