// ABOUTME: Tests linking one platform — proof post and OAuth — and that a
// ABOUTME: claim is published only once the verifier has confirmed it.

import 'dart:async';
import 'dart:math';

import 'package:analytics/analytics.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart' hide VerificationResult;
import 'package:openvine/blocs/verify/verify_connect_cubit.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:unified_logger/unified_logger.dart';

class _MockIdentityClaimsRepository extends Mock
    implements IdentityClaimsRepository {}

class _MockAnalyticsEventSink extends Mock implements AnalyticsEventSink {}

/// A source whose every byte is zero, so the start secret is 'A' x 43.
class _ZeroRandom implements Random {
  @override
  int nextInt(int max) => 0;

  @override
  double nextDouble() => 0;

  @override
  bool nextBool() => false;
}

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
    late String? startedReturnUrl;
    late String? startedCheck;
    // What the verifier sends back; the default echoes this sign-in's id.
    late Uri? Function(Uri returnUrl) answer;

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
      startedReturnUrl = null;
      startedCheck = null;
      answer = (returnUrl) => returnUrl.replace(
        queryParameters: {
          ...returnUrl.queryParameters,
          'platform': 'twitter',
          'identity': 'jack',
          'oauth_confirm': 'C' * 43,
        },
      );
      when(
        () => repository.verifyClaim(any()),
      ).thenAnswer((_) async => _result(verified: true));
      when(() => repository.publishClaim(any())).thenAnswer((_) async => []);
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
        startedCheck = invocation.namedArguments[#startCheck] as String;
        return Uri.parse('https://provider.example/authorize?state=s');
      });
    });

    VerifyConnectCubit build(
      VerifierPlatform platform, {
      VerifyOAuthLauncher? launchOAuth,
      Random? random,
    }) => VerifyConnectCubit(
      repository: repository,
      pubkey: _pubkey,
      platform: platform,
      oauthReturnUrl: _returnUrl,
      analytics: analytics,
      random: random ?? Random(1),
      wait: (_) async {},
      launchOAuth:
          launchOAuth ??
          (uri) async {
            launched.add(uri);
            return answer(Uri.parse(startedReturnUrl!));
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
          await pumpEventQueue();
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
        await pumpEventQueue();
        await cubit.close();
        published.complete(const []);

        await submit;
      });
    });

    group('connectWithOAuth', () {
      blocTest<VerifyConnectCubit, VerifyConnectState>(
        'starts with a start check and a sign-in id, then waits for approval naming the account',
        build: () => build(_twitter, random: _ZeroRandom()),
        act: (cubit) => cubit.connectWithOAuth(),
        verify: (cubit) {
          expect(cubit.state.status, VerifyConnectStatus.awaitingApproval);
          expect(cubit.state.signedInAccount, 'jack');
          expect(
            startedReturnUrl,
            matches(
              RegExp(
                r'^https://divine\.video/app/callback\?signin=[0-9a-f]{32}$',
              ),
            ),
          );
          // The secret from an all-zero source is 'A' x 43. The start sends
          // its hash, never the secret itself.
          expect(startedCheck, SignInSecrets.startCheckFor('A' * 43));
          expect(startedCheck, isNot('A' * 43));
          expect(
            launched,
            equals([Uri.parse('https://provider.example/authorize?state=s')]),
          );
          verifyNever(
            () => repository.signClaim(
              any(),
              confirmBinding: any(named: 'confirmBinding'),
            ),
          );
          verifyNever(() => repository.publishClaim(any()));
        },
      );

      blocTest<VerifyConnectCubit, VerifyConnectState>(
        'refuses a return whose sign-in id is not this one, and signs nothing',
        build: () => build(_twitter),
        setUp: () => answer = (returnUrl) => Uri.parse(
          '$_returnUrl?signin=${'0' * 32}&platform=twitter&identity=mallory'
          '&oauth_confirm=${'C' * 43}',
        ),
        act: (cubit) => cubit.connectWithOAuth(),
        verify: (cubit) {
          expect(cubit.state.error, VerifyConnectError.oauthFailed);
          expect(cubit.state.status, VerifyConnectStatus.editing);
          expect(cubit.state.signedInAccount, isNull);
          verifyNever(
            () => repository.signClaim(
              any(),
              confirmBinding: any(named: 'confirmBinding'),
            ),
          );
        },
      );

      blocTest<VerifyConnectCubit, VerifyConnectState>(
        'refuses a return for another platform',
        build: () => build(_twitter),
        setUp: () => answer = (returnUrl) => returnUrl.replace(
          queryParameters: {
            ...returnUrl.queryParameters,
            'platform': 'youtube',
            'identity': 'jack',
            'oauth_confirm': 'C' * 43,
          },
        ),
        act: (cubit) => cubit.connectWithOAuth(),
        verify: (cubit) =>
            expect(cubit.state.error, VerifyConnectError.oauthFailed),
      );

      blocTest<VerifyConnectCubit, VerifyConnectState>(
        'refuses a Bluesky return for a handle other than the one typed',
        build: () => build(_bluesky),
        seed: () => const VerifyConnectState(
          platform: _bluesky,
          identity: '@Alice.bsky.social ',
        ),
        setUp: () => answer = (returnUrl) => returnUrl.replace(
          queryParameters: {
            ...returnUrl.queryParameters,
            'platform': 'bluesky',
            'identity': 'mallory.bsky.social',
            'oauth_confirm': 'C' * 43,
          },
        ),
        act: (cubit) => cubit.connectWithOAuth(),
        verify: (cubit) =>
            expect(cubit.state.error, VerifyConnectError.oauthFailed),
      );

      blocTest<VerifyConnectCubit, VerifyConnectState>(
        'accepts the typed Bluesky handle written with @, spaces or capitals, and starts with it bare',
        build: () => build(_bluesky),
        seed: () => const VerifyConnectState(
          platform: _bluesky,
          identity: '@Alice.bsky.social ',
        ),
        setUp: () => answer = (returnUrl) => returnUrl.replace(
          queryParameters: {
            ...returnUrl.queryParameters,
            'platform': 'bluesky',
            'identity': 'alice.bsky.social',
            'oauth_confirm': 'C' * 43,
          },
        ),
        act: (cubit) => cubit.connectWithOAuth(),
        verify: (cubit) {
          expect(cubit.state.status, VerifyConnectStatus.awaitingApproval);
          verify(
            () => repository.startSignIn(
              platform: 'bluesky',
              pubkey: _pubkey,
              returnUrl: any(named: 'returnUrl'),
              startCheck: any(named: 'startCheck'),
              handle: 'Alice.bsky.social',
            ),
          ).called(1);
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
        'treats a return without a code as not confirmed, and publishes nothing',
        build: () => build(_twitter),
        setUp: () => answer = (returnUrl) => returnUrl.replace(
          queryParameters: {
            ...returnUrl.queryParameters,
            'platform': 'twitter',
            'identity': 'jack',
            'oauth_verified': 'true',
          },
        ),
        act: (cubit) => cubit.connectWithOAuth(),
        verify: (cubit) {
          expect(cubit.state.error, VerifyConnectError.signInNotConfirmed);
          verifyNever(() => repository.publishClaim(any()));
        },
      );

      blocTest<VerifyConnectCubit, VerifyConnectState>(
        'treats an empty code as not confirmed',
        build: () => build(_twitter),
        setUp: () => answer = (returnUrl) => returnUrl.replace(
          queryParameters: {
            ...returnUrl.queryParameters,
            'platform': 'twitter',
            'identity': 'jack',
            'oauth_confirm': '',
          },
        ),
        act: (cubit) => cubit.connectWithOAuth(),
        verify: (cubit) {
          expect(cubit.state.error, VerifyConnectError.signInNotConfirmed);
          expect(cubit.state.signedInAccount, isNull);
        },
      );

      blocTest<VerifyConnectCubit, VerifyConnectState>(
        'refuses a return that names no account',
        build: () => build(_twitter),
        setUp: () => answer = (returnUrl) => returnUrl.replace(
          queryParameters: {
            ...returnUrl.queryParameters,
            'platform': 'twitter',
            'identity': '',
            'oauth_confirm': 'C' * 43,
          },
        ),
        act: (cubit) => cubit.connectWithOAuth(),
        verify: (cubit) {
          expect(cubit.state.error, equals(VerifyConnectError.oauthFailed));
          expect(cubit.state.signedInAccount, isNull);
        },
      );

      blocTest<VerifyConnectCubit, VerifyConnectState>(
        'treats a refused sign-in as a failure, kept out of Bloc errors',
        build: () => build(_twitter),
        setUp: () => answer = (returnUrl) => returnUrl.replace(
          queryParameters: {
            ...returnUrl.queryParameters,
            'oauth_error': 'cancelled or declined at Twitter',
          },
        ),
        act: (cubit) => cubit.connectWithOAuth(),
        verify: (cubit) {
          expect(cubit.state.error, equals(VerifyConnectError.oauthFailed));
          expect(cubit.state.signedInAccount, isNull);
        },
        // Verifier refusals are expected domain outcomes. They are warning
        // logs, not Bloc errors, so they cannot be misclassified as
        // reportable StateErrors by DivineBlocObserver.
        errors: () => const [],
      );

      blocTest<VerifyConnectCubit, VerifyConnectState>(
        'goes back to editing when the person closes the sign-in',
        build: () => build(_twitter),
        setUp: () => answer = (_) => null,
        act: (cubit) => cubit.connectWithOAuth(),
        verify: (cubit) {
          expect(cubit.state.status, VerifyConnectStatus.editing);
          expect(cubit.state.error, isNull);
        },
      );

      test(
        'starting again forgets the account the last sign-in named',
        () async {
          final cubit = build(_twitter);
          await cubit.connectWithOAuth();
          expect(cubit.state.signedInAccount, 'jack');

          answer = (_) => null;
          await cubit.connectWithOAuth();

          expect(cubit.state.status, VerifyConnectStatus.editing);
          expect(cubit.state.signedInAccount, isNull);
          await cubit.close();
        },
      );

      blocTest<VerifyConnectCubit, VerifyConnectState>(
        'never opens a browser when sign-in is not set up',
        build: () => build(_twitter),
        setUp: () => when(
          () => repository.startSignIn(
            platform: any(named: 'platform'),
            pubkey: any(named: 'pubkey'),
            returnUrl: any(named: 'returnUrl'),
            startCheck: any(named: 'startCheck'),
            handle: any(named: 'handle'),
          ),
        ).thenAnswer((_) async => null),
        act: (cubit) => cubit.connectWithOAuth(),
        verify: (cubit) {
          expect(cubit.state.error, VerifyConnectError.oauthUnavailable);
          expect(launched, isEmpty);
        },
      );

      blocTest<VerifyConnectCubit, VerifyConnectState>(
        'says the verifier is unreachable when the start request cannot get through',
        build: () => build(_twitter),
        setUp: () => when(
          () => repository.startSignIn(
            platform: any(named: 'platform'),
            pubkey: any(named: 'pubkey'),
            returnUrl: any(named: 'returnUrl'),
            startCheck: any(named: 'startCheck'),
            handle: any(named: 'handle'),
          ),
        ).thenThrow(const VerifierNetworkException('down')),
        act: (cubit) => cubit.connectWithOAuth(),
        verify: (cubit) {
          expect(cubit.state.error, VerifyConnectError.verifierUnreachable);
          expect(launched, isEmpty);
        },
        errors: () => [isA<VerifierNetworkException>()],
      );

      blocTest<VerifyConnectCubit, VerifyConnectState>(
        'says the verifier is unreachable when the start request times out',
        build: () => build(_twitter),
        setUp: () => when(
          () => repository.startSignIn(
            platform: any(named: 'platform'),
            pubkey: any(named: 'pubkey'),
            returnUrl: any(named: 'returnUrl'),
            startCheck: any(named: 'startCheck'),
            handle: any(named: 'handle'),
          ),
        ).thenThrow(const VerifierTimeoutException('slow')),
        act: (cubit) => cubit.connectWithOAuth(),
        verify: (cubit) {
          expect(cubit.state.error, VerifyConnectError.verifierUnreachable);
          expect(launched, isEmpty);
        },
        errors: () => [isA<VerifierTimeoutException>()],
      );

      blocTest<VerifyConnectCubit, VerifyConnectState>(
        'returns to editing when the start request is refused',
        build: () => build(_twitter),
        setUp: () => when(
          () => repository.startSignIn(
            platform: any(named: 'platform'),
            pubkey: any(named: 'pubkey'),
            returnUrl: any(named: 'returnUrl'),
            startCheck: any(named: 'startCheck'),
            handle: any(named: 'handle'),
          ),
        ).thenThrow(const VerifierApiException(400, 'bad return_url')),
        act: (cubit) => cubit.connectWithOAuth(),
        verify: (cubit) {
          expect(cubit.state.error, equals(VerifyConnectError.oauthFailed));
          expect(cubit.state.status, equals(VerifyConnectStatus.editing));
          expect(launched, isEmpty);
        },
        errors: () => [isA<VerifierApiException>()],
      );

      blocTest<VerifyConnectCubit, VerifyConnectState>(
        'reports a browser session that threw',
        build: () => build(
          _twitter,
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
        final cubit = build(
          _twitter,
          launchOAuth: (uri) {
            launched.add(uri);
            return browser.future;
          },
        );

        final connect = cubit.connectWithOAuth();
        await pumpEventQueue();
        await cubit.close();
        browser.complete(answer(Uri.parse(startedReturnUrl!)));

        await connect;
        expect(cubit.state.status, VerifyConnectStatus.authorizing);
      });

      test(
        'logs a refused sign-in by platform and a fixed reason, not the text the return carried',
        () async {
          await LogCaptureService().clearAllLogs();
          final cubit = build(_twitter);
          answer = (returnUrl) => returnUrl.replace(
            queryParameters: {
              ...returnUrl.queryParameters,
              'oauth_error': 'cancelled or declined at Twitter',
            },
          );
          await cubit.connectWithOAuth();
          final logged = LogCaptureService()
              .getRecentLogs()
              .map((entry) => entry.message)
              .join('\n');
          expect(
            logged,
            contains('Verifier sign-in for twitter did not complete: refused'),
          );
          expect(logged, isNot(contains('cancelled or declined')));
          await cubit.close();
        },
      );

      test('never logs the return address or the code', () async {
        // Same capture other cubit tests read (divine_auth_cubit_test.dart).
        await LogCaptureService().clearAllLogs();
        final cubit = build(_twitter);
        answer = (returnUrl) => Uri.parse(
          '$_returnUrl?signin=${'0' * 32}&platform=twitter&identity=x'
          '&oauth_confirm=${'C' * 43}',
        );
        await cubit.connectWithOAuth();
        final logged = LogCaptureService()
            .getRecentLogs()
            .map((entry) => entry.message)
            .join('\n');
        expect(logged, contains('did not match the twitter sign-in'));
        expect(logged, isNot(contains('C' * 43)));
        expect(logged, isNot(contains('signin=')));
        await cubit.close();
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
