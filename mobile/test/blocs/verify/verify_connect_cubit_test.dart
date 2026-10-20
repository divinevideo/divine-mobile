// ABOUTME: Tests linking one platform — proof post and OAuth — and that a
// ABOUTME: claim is published only once the verifier has confirmed it.

import 'dart:async';
import 'dart:math';

import 'package:analytics/analytics.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart' hide VerificationResult;
import 'package:openvine/blocs/verify/verify_connect_cubit.dart';
import 'package:openvine/observability/crash_reporter.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:unified_logger/unified_logger.dart';

class _MockIdentityClaimsRepository extends Mock
    implements IdentityClaimsRepository {}

class _MockAnalyticsEventSink extends Mock implements AnalyticsEventSink {}

class _MockSignedIdentityClaim extends Mock implements SignedIdentityClaim {}

/// A source whose every byte is zero, so the start secret is 'A' x 43.
class _ZeroRandom implements Random {
  @override
  int nextInt(int max) => 0;

  @override
  double nextDouble() => 0;

  @override
  bool nextBool() => false;
}

class _RecordingCrashReporter implements CrashReporter {
  final recordedErrors = <Object>[];

  @override
  void log(String message) {}

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stackTrace, {
    String? reason,
  }) async {
    recordedErrors.add(error);
  }

  @override
  Future<void> setCustomKey(String key, Object value) async {}
}

/// Hands every error the cubit reports to [onReported], closed or not:
/// `addError` itself never checks.
class _ErrorRecordingCubit extends VerifyConnectCubit {
  _ErrorRecordingCubit({
    required super.repository,
    required super.pubkey,
    required super.platform,
    required super.launchOAuth,
    required super.oauthReturnUrl,
    required super.analytics,
    required this.onReported,
  });

  final void Function(Object error) onReported;

  @override
  void onError(Object error, StackTrace stackTrace) {
    onReported(error);
    super.onError(error, stackTrace);
  }
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

const _tiktok = VerifierPlatform(
  key: 'tiktok',
  label: 'TikTok',
  supported: true,
);
const _mastodon = VerifierPlatform(
  key: 'mastodon',
  label: 'Mastodon',
  supported: true,
);

VerificationResult _result({
  required bool verified,
  String platform = 'github',
  String identity = 'octocat',
  String? code,
  String? canonicalProof,
  String? canonicalIdentity,
}) => VerificationResult(
  platform: platform,
  identity: identity,
  verified: verified,
  checkedAt: 1,
  cached: false,
  code: code,
  canonicalProof: canonicalProof,
  canonicalIdentity: canonicalIdentity,
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
      registerFallbackValue(_MockSignedIdentityClaim());
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
      when(
        () => repository.publishClaim(
          any(),
          replacingIdentity: any(named: 'replacingIdentity'),
        ),
      ).thenAnswer((_) async => []);
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
      Future<void> Function(Duration)? wait,
    }) => VerifyConnectCubit(
      repository: repository,
      pubkey: _pubkey,
      platform: platform,
      oauthReturnUrl: _returnUrl,
      analytics: analytics,
      random: random ?? Random(1),
      wait: wait ?? (_) async {},
      launchOAuth:
          launchOAuth ??
          (uri) async {
            launched.add(uri);
            return answer(Uri.parse(startedReturnUrl!));
          },
    );

    // The claim published, and the identity it was told to replace.
    (IdentityClaim, String?) published() {
      final captured = verify(
        () => repository.publishClaim(
          captureAny(),
          replacingIdentity: captureAny(named: 'replacingIdentity'),
        ),
      ).captured;
      return (captured[0] as IdentityClaim, captured[1] as String?);
    }

    group('loadPlatform', () {
      // What the screen starts from when no platform list was loaded: sign-in
      // hidden until the verifier says.
      const twitterStandIn = VerifierPlatform(
        key: 'twitter',
        label: 'twitter',
        supported: true,
        oauth: false,
      );
      // What the repository answers when the verifier can't be asked: the
      // app's own list decides.
      const twitterFallback = VerifierPlatform(
        key: 'twitter',
        label: 'twitter',
        supported: true,
      );
      const twitterOff = VerifierPlatform(
        key: 'twitter',
        label: 'Twitter / X',
        supported: true,
        oauth: false,
      );

      blocTest<VerifyConnectCubit, VerifyConnectState>(
        "takes the repository's answer for the platform",
        setUp: () => when(() => repository.platform('bluesky')).thenAnswer(
          (_) async => const VerifierPlatform(
            key: 'bluesky',
            label: 'Bluesky',
            supported: true,
            oauth: true,
          ),
        ),
        build: () => build(
          const VerifierPlatform(
            key: 'bluesky',
            label: 'bluesky',
            supported: true,
            oauth: false,
          ),
        ),
        act: (cubit) => cubit.loadPlatform(),
        expect: () => [
          isA<VerifyConnectState>()
              .having((s) => s.platform.oauth, 'oauth', isTrue)
              .having((s) => s.supportsOAuth, 'supportsOAuth', isTrue),
        ],
      );

      blocTest<VerifyConnectCubit, VerifyConnectState>(
        'keeps sign-in hidden when the verifier has it off',
        setUp: () => when(
          () => repository.platform('twitter'),
        ).thenAnswer((_) async => twitterOff),
        build: () => build(twitterStandIn),
        act: (cubit) => cubit.loadPlatform(),
        // Pins the answer itself: the stand-in is already "off", so checking
        // only the flag would pass with the answer ignored.
        expect: () => [
          isA<VerifyConnectState>()
              .having((s) => s.platform, 'platform', twitterOff)
              .having((s) => s.supportsOAuth, 'supportsOAuth', isFalse),
        ],
      );

      test('keeps what was typed while the answer arrives', () async {
        final answer = Completer<VerifierPlatform>();
        when(
          () => repository.platform('twitter'),
        ).thenAnswer((_) => answer.future);
        final cubit = build(twitterStandIn);
        addTearDown(cubit.close);

        final loading = cubit.loadPlatform();
        cubit.proofChanged('https://x.com/jack/status/1');
        answer.complete(twitterFallback);
        await loading;

        expect(cubit.state.proof, equals('https://x.com/jack/status/1'));
        expect(cubit.state.supportsOAuth, isTrue);
      });

      test('ignores an answer that arrives after the screen closed', () async {
        final answer = Completer<VerifierPlatform>();
        when(
          () => repository.platform('twitter'),
        ).thenAnswer((_) => answer.future);
        final cubit = build(twitterStandIn);

        final loading = cubit.loadPlatform();
        await cubit.close();
        answer.complete(twitterFallback);

        await expectLater(loading, completes);
      });

      group('while an attempt is under way', () {
        // The platform the screen opened with: sign-in on, from an answer a
        // refresh then turns off.
        const twitterOn = VerifierPlatform(
          key: 'twitter',
          label: 'Twitter / X',
          supported: true,
          oauth: true,
        );

        test('keeps sign-in on while the browser is open, so its return '
            'can still be approved', () async {
          final verifierAnswer = Completer<VerifierPlatform>();
          when(
            () => repository.platform('twitter'),
          ).thenAnswer((_) => verifierAnswer.future);
          final browser = Completer<Uri?>();
          final cubit = build(twitterOn, launchOAuth: (_) => browser.future);
          addTearDown(cubit.close);

          final loading = cubit.loadPlatform();
          final signIn = cubit.connectWithOAuth();
          await pumpEventQueue();
          expect(cubit.state.status, VerifyConnectStatus.authorizing);

          verifierAnswer.complete(twitterOff);
          await loading;
          expect(cubit.state.platform, equals(twitterOn));

          browser.complete(answer(Uri.parse(startedReturnUrl!)));
          await signIn;
          expect(cubit.state.status, VerifyConnectStatus.awaitingApproval);
          expect(cubit.state.platform, equals(twitterOn));
          expect(cubit.state.supportsOAuth, isTrue);
        });

        blocTest<VerifyConnectCubit, VerifyConnectState>(
          'keeps sign-in on while the returned account waits for approval',
          setUp: () => when(
            () => repository.platform('twitter'),
          ).thenAnswer((_) async => twitterOff),
          build: () => build(twitterOn),
          act: (cubit) async {
            await cubit.connectWithOAuth();
            await cubit.loadPlatform();
          },
          skip: 2,
          expect: () => const <VerifyConnectState>[],
          verify: (cubit) {
            expect(cubit.state.status, VerifyConnectStatus.awaitingApproval);
            expect(cubit.state.platform, equals(twitterOn));
          },
        );

        test('still takes the answer while a proof post is checked', () async {
          // No sign-in to protect, and a rejected proof comes back to a form
          // that should follow the newest answer.
          final verdict = Completer<VerificationResult>();
          when(
            () => repository.verifyClaim(any()),
          ).thenAnswer((_) => verdict.future);
          when(
            () => repository.platform('twitter'),
          ).thenAnswer((_) async => twitterOff);
          final cubit = build(twitterOn);
          addTearDown(cubit.close);

          cubit.proofChanged('https://x.com/jack/status/1');
          final checking = cubit.submitProof();
          expect(cubit.state.status, VerifyConnectStatus.verifying);
          await cubit.loadPlatform();
          verdict.complete(_result(verified: false, platform: 'twitter'));
          await checking;

          expect(cubit.state.platform, equals(twitterOff));
        });
      });

      // Plain tests rather than blocTest: blocTest counts an error thrown out
      // of act as reported, which is the very thing these rule out.
      group('when the answer cannot be read', () {
        late Completer<VerifierPlatform> verifierAnswer;
        late List<Object> reported;

        setUp(() {
          verifierAnswer = Completer<VerifierPlatform>();
          when(
            () => repository.platform('twitter'),
          ).thenAnswer((_) => verifierAnswer.future);
          reported = [];
        });

        _ErrorRecordingCubit buildRecording() => _ErrorRecordingCubit(
          repository: repository,
          pubkey: _pubkey,
          platform: twitterStandIn,
          oauthReturnUrl: _returnUrl,
          analytics: analytics,
          launchOAuth: (_) async => null,
          onReported: reported.add,
        );

        for (final error in <Object>[
          const FormatException('not json'),
          TypeError(),
        ]) {
          test('keeps the platform it opened with and reports the '
              '${error.runtimeType}', () async {
            final cubit = buildRecording();
            addTearDown(cubit.close);

            final loading = cubit.loadPlatform();
            verifierAnswer.completeError(error);

            await expectLater(loading, completes);
            expect(cubit.state.platform, equals(twitterStandIn));
            expect(reported, equals([same(error)]));
          });

          test('reports nothing for a ${error.runtimeType} that arrives '
              'after the screen closed', () async {
            final cubit = buildRecording();

            final loading = cubit.loadPlatform();
            await cubit.close();
            verifierAnswer.completeError(error);

            await expectLater(loading, completes);
            expect(reported, isEmpty);
          });
        }
      });
    });

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

      group('when the verifier could not check', () {
        setUp(() {
          when(() => repository.verifyClaim(any())).thenAnswer(
            (_) async =>
                _result(verified: false, code: 'temporarily_unavailable'),
          );
        });

        Future<void> submit(VerifyConnectCubit cubit) async {
          cubit
            ..identityChanged('octocat')
            ..proofChanged('abc');
          await cubit.submitProof();
        }

        // Not a rejection: the proof may be fine, so "try again" is the right
        // next step, not "fix your post".
        blocTest<VerifyConnectCubit, VerifyConnectState>(
          'asks the person to try again',
          build: () => build(_github),
          act: submit,
          verify: (cubit) {
            expect(cubit.state.error, VerifyConnectError.verifierUnreachable);
          },
        );

        blocTest<VerifyConnectCubit, VerifyConnectState>(
          'counts it as its own outcome, not as a rejection',
          build: () => build(_github),
          act: submit,
          verify: (_) {
            verify(
              () => analytics.logEvent(
                name: 'verify_proof_unavailable',
                parameters: {'platform': 'github'},
              ),
            ).called(1);
            verifyNever(
              () => analytics.logEvent(
                name: 'verify_proof_rejected',
                parameters: any(named: 'parameters'),
              ),
            );
          },
        );

        blocTest<VerifyConnectCubit, VerifyConnectState>(
          'logs it as "could not check", not as a rejection',
          setUp: () => LogCaptureService().clearAllLogs(),
          // The capture buffer is process-global and the merged test run
          // shares one isolate, so the line must not outlive this test.
          tearDown: () => LogCaptureService().clearAllLogs(),
          build: () => build(_github),
          act: submit,
          verify: (_) {
            final logged = LogCaptureService()
                .getRecentLogs()
                .map((entry) => entry.message)
                .join('\n');
            expect(logged, contains('Verifier could not check github:octocat'));
            expect(logged, isNot(contains('Verifier rejected')));
          },
        );
      });

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

      group('when analytics cannot record the outcome', () {
        setUp(() {
          when(
            () => analytics.logEvent(
              name: any(named: 'name'),
              parameters: any(named: 'parameters'),
            ),
          ).thenAnswer((_) async => throw StateError('analytics is down'));
        });

        blocTest<VerifyConnectCubit, VerifyConnectState>(
          'still shows the rejection',
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
          verify: (cubit) {
            expect(cubit.state.error, VerifyConnectError.discordBotNoAccess);
          },
        );

        blocTest<VerifyConnectCubit, VerifyConnectState>(
          'still asks the person to try again when the verifier could not '
          'check',
          setUp: () {
            when(() => repository.verifyClaim(any())).thenAnswer(
              (_) async =>
                  _result(verified: false, code: 'temporarily_unavailable'),
            );
          },
          build: () => build(_github),
          act: (cubit) async {
            cubit
              ..identityChanged('octocat')
              ..proofChanged('abc');
            await cubit.submitProof();
          },
          verify: (cubit) {
            expect(cubit.state.error, VerifyConnectError.verifierUnreachable);
          },
        );

        group('crash reporting', () {
          late CrashReporter originalReporter;
          late _RecordingCrashReporter reporter;

          setUp(() {
            originalReporter = detachedFailureReporter;
            reporter = _RecordingCrashReporter();
            detachedFailureReporter = reporter;
            when(() => repository.verifyClaim(any())).thenAnswer(
              (_) async =>
                  _result(verified: false, code: 'discord_bot_no_access'),
            );
          });

          tearDown(() => detachedFailureReporter = originalReporter);

          Future<void> submit(VerifyConnectCubit cubit) async {
            cubit
              ..identityChanged('alice')
              ..proofChanged('https://discord.com/channels/1/2/3');
            await cubit.submitProof();
            await pumpEventQueue();
          }

          // A StateError is a broken invariant in the analytics code, not an
          // outage, so it has to reach crash reporting rather than only the
          // log (.claude/rules/error_handling.md, "Detached work").
          blocTest<VerifyConnectCubit, VerifyConnectState>(
            'reports a broken invariant',
            build: () => build(_discord),
            act: submit,
            verify: (_) {
              expect(reporter.recordedErrors, hasLength(1));
              expect(
                (reporter.recordedErrors.single as Reportable<Object>).unwrap(),
                isA<StateError>(),
              );
            },
          );

          blocTest<VerifyConnectCubit, VerifyConnectState>(
            'does not report an operational failure',
            setUp: () {
              when(
                () => analytics.logEvent(
                  name: any(named: 'name'),
                  parameters: any(named: 'parameters'),
                ),
              ).thenAnswer((_) async => throw Exception('offline'));
            },
            build: () => build(_discord),
            act: submit,
            verify: (_) {
              expect(reporter.recordedErrors, isEmpty);
            },
          );
        });
      });

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
        'publishes the post number the verifier returns, not the pasted link',
        setUp: () {
          when(() => repository.verifyClaim(any())).thenAnswer(
            (_) async => _result(
              verified: true,
              platform: 'tiktok',
              identity: 'alice',
              canonicalProof: '7123456789012345678',
            ),
          );
        },
        build: () => build(_tiktok),
        act: (cubit) async {
          cubit
            ..identityChanged('alice')
            ..proofChanged('https://vm.tiktok.com/ZMabc123/');
          await cubit.submitProof();
        },
        verify: (cubit) {
          // The verifier is asked about the link as pasted.
          final checked =
              verify(
                    () => repository.verifyClaim(captureAny()),
                  ).captured.single
                  as IdentityClaim;
          expect(checked.proof, equals('https://vm.tiktok.com/ZMabc123/'));

          final (claim, replacing) = published();
          // The account is the one sent, so there is no other form to drop.
          expect(replacing, isNull);
          expect(claim.pubkey, equals(_pubkey));
          expect(claim.platform, equals('tiktok'));
          expect(claim.identity, equals('alice'));
          expect(claim.proof, equals('7123456789012345678'));
          expect(cubit.state.linkedClaim, equals(claim));
        },
      );

      blocTest<VerifyConnectCubit, VerifyConnectState>(
        'publishes the account the verifier tidied, not the one typed',
        setUp: () {
          when(() => repository.verifyClaim(any())).thenAnswer(
            (_) async => _result(
              verified: true,
              platform: 'mastodon',
              identity: '@alice@mastodon.example',
              canonicalIdentity: 'mastodon.example/@alice',
            ),
          );
        },
        build: () => build(_mastodon),
        act: (cubit) async {
          cubit
            ..identityChanged('@alice@mastodon.example')
            ..proofChanged('110123');
          await cubit.submitProof();
        },
        verify: (cubit) {
          final (claim, replacing) = published();
          // A tag saved earlier under the form typed is replaced too.
          expect(replacing, equals('@alice@mastodon.example'));
          expect(claim.pubkey, equals(_pubkey));
          expect(claim.platform, equals('mastodon'));
          expect(claim.identity, equals('mastodon.example/@alice'));
          expect(claim.proof, equals('110123'));
          expect(cubit.state.identity, equals('mastodon.example/@alice'));
        },
      );

      // Claims that fail the server's text rules are dropped whenever the
      // identity event is read, so publishing one would leave a tag nobody
      // sees.
      blocTest<VerifyConnectCubit, VerifyConnectState>(
        'publishes the pasted proof when the returned one is not valid',
        setUp: () {
          when(() => repository.verifyClaim(any())).thenAnswer(
            (_) async => _result(
              verified: true,
              platform: 'tiktok',
              identity: 'alice',
              canonicalProof: '7123|456',
            ),
          );
        },
        build: () => build(_tiktok),
        act: (cubit) async {
          cubit
            ..identityChanged('alice')
            ..proofChanged('https://vm.tiktok.com/ZMabc123/');
          await cubit.submitProof();
        },
        verify: (cubit) {
          final claim =
              verify(
                    () => repository.publishClaim(captureAny()),
                  ).captured.single
                  as IdentityClaim;
          expect(claim.identity, equals('alice'));
          expect(claim.proof, equals('https://vm.tiktok.com/ZMabc123/'));
        },
      );

      blocTest<VerifyConnectCubit, VerifyConnectState>(
        'publishes the typed account when the returned one is not valid',
        setUp: () {
          when(() => repository.verifyClaim(any())).thenAnswer(
            (_) async => _result(
              verified: true,
              platform: 'mastodon',
              identity: '@alice@mastodon.example',
              canonicalIdentity: 'mastodon.example/@al|ice',
            ),
          );
        },
        build: () => build(_mastodon),
        act: (cubit) async {
          cubit
            ..identityChanged('@alice@mastodon.example')
            ..proofChanged('110123');
          await cubit.submitProof();
        },
        verify: (cubit) {
          final claim =
              verify(
                    () => repository.publishClaim(captureAny()),
                  ).captured.single
                  as IdentityClaim;
          expect(claim.identity, equals('@alice@mastodon.example'));
          expect(claim.proof, equals('110123'));
        },
      );

      // The returned values describe one confirmed claim, so a valid account
      // is not mixed with the proof as sent.
      blocTest<VerifyConnectCubit, VerifyConnectState>(
        'publishes the whole claim as sent when one returned value is not valid',
        setUp: () {
          when(() => repository.verifyClaim(any())).thenAnswer(
            (_) async => _result(
              verified: true,
              platform: 'mastodon',
              identity: '@alice@mastodon.example',
              canonicalIdentity: 'mastodon.example/@alice',
              canonicalProof: '110|123',
            ),
          );
        },
        build: () => build(_mastodon),
        act: (cubit) async {
          cubit
            ..identityChanged('@alice@mastodon.example')
            ..proofChanged('110123');
          await cubit.submitProof();
        },
        verify: (cubit) {
          final (claim, replacing) = published();
          // The claim as sent replaces only itself.
          expect(replacing, isNull);
          expect(claim.identity, equals('@alice@mastodon.example'));
          expect(claim.proof, equals('110123'));
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
        'says a verified link the signer declined was not signed',
        build: () => build(_github),
        setUp: () {
          when(() => repository.publishClaim(any())).thenThrow(
            const IdentityClaimNotSignedException(
              'Could not sign the identity event',
            ),
          );
        },
        act: (cubit) async {
          cubit
            ..identityChanged('octocat')
            ..proofChanged('abc');
          await cubit.submitProof();
        },
        verify: (cubit) {
          expect(cubit.state.error, equals(VerifyConnectError.notSigned));
          expect(cubit.state.status, equals(VerifyConnectStatus.editing));
        },
        // The signer reports its own faults; a decline is the person's
        // choice, so neither is filed again here (#9340).
        errors: () => const [],
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

    group('approveSignIn', () {
      late SignedIdentityClaim signed;
      const confirmed = SignInConfirmation(
        platform: 'twitter',
        identity: 'jack',
      );
      // The binding for start secret 'A' x 43 (an all-zero source) and code
      // 'C' x 43, worked out with Node's crypto by the shared rule whose test
      // vector signin_confirmation_test.dart pins.
      const zeroSecretBinding = 'F8UKdZkRqEKITNU-P3wPqQDvlfkyRzqqbNJ4htvVaSI';

      When<Future<SignInConfirmation>> whenConfirm() => when(
        () => repository.confirmSignIn(
          code: any(named: 'code'),
          startSecret: any(named: 'startSecret'),
          signed: any(named: 'signed'),
        ),
      );

      void expectConfirmCalls(int times) => verify(
        () => repository.confirmSignIn(
          code: any(named: 'code'),
          startSecret: any(named: 'startSecret'),
          signed: signed,
        ),
      ).called(times);

      setUp(() {
        signed = _MockSignedIdentityClaim();
        when(
          () => repository.signClaim(
            any(),
            confirmBinding: any(named: 'confirmBinding'),
          ),
        ).thenAnswer((_) async => signed);
        whenConfirm().thenAnswer((_) async => confirmed);
        when(
          () => repository.publishSignedClaim(any()),
        ).thenAnswer((_) async => []);
      });

      Future<VerifyConnectCubit> waiting({
        Future<void> Function(Duration)? wait,
      }) async {
        final cubit = build(_twitter, random: _ZeroRandom(), wait: wait);
        await cubit.connectWithOAuth();
        expect(cubit.state.status, VerifyConnectStatus.awaitingApproval);
        return cubit;
      }

      test(
        'signs with the bound value, confirms, then publishes the same event',
        () async {
          final cubit = await waiting();
          await cubit.approveSignIn();
          final binding = verify(
            () => repository.signClaim(
              captureAny(),
              confirmBinding: captureAny(named: 'confirmBinding'),
            ),
          ).captured;
          expect((binding[0] as IdentityClaim).identity, 'jack');
          expect(
            binding[1],
            SignInSecrets.confirmBindingFor('C' * 43, startedCheck!),
          );
          expect(binding[1], zeroSecretBinding);
          verifyInOrder([
            () => repository.confirmSignIn(
              code: 'C' * 43,
              startSecret: any(named: 'startSecret'),
              signed: signed,
            ),
            () => repository.publishSignedClaim(signed),
          ]);
          expect(cubit.state.status, VerifyConnectStatus.linked);
          expect(cubit.state.linkedClaim?.identity, 'jack');
          // Linked, so no account is left waiting to approve, as on the proof
          // path.
          expect(cubit.state.signedInAccount, isNull);

          // The sign-in is used up, so approving again publishes nothing more.
          await cubit.approveSignIn();
          verifyNever(() => repository.publishSignedClaim(any()));
          await cubit.close();
        },
      );

      test('confirms with the secret whose hash the start sent', () async {
        final cubit = await waiting();
        await cubit.approveSignIn();
        final sent = verify(
          () => repository.confirmSignIn(
            code: any(named: 'code'),
            startSecret: captureAny(named: 'startSecret'),
            signed: any(named: 'signed'),
          ),
        ).captured;
        expect(
          SignInSecrets.startCheckFor(sent.single as String),
          startedCheck,
        );
        expect(sent.single, 'A' * 43);
        await cubit.close();
      });

      test(
        'tries again while the verifier has not seen the sign-in yet, with the same signed event',
        () async {
          var calls = 0;
          whenConfirm().thenAnswer((_) async {
            calls++;
            if (calls < 3) {
              throw SignInConfirmException(404, SignInRefusal.notFound);
            }
            return confirmed;
          });
          final cubit = await waiting();
          await cubit.approveSignIn();
          expectConfirmCalls(3);
          verify(
            () => repository.signClaim(
              any(),
              confirmBinding: any(named: 'confirmBinding'),
            ),
          ).called(1);
          expect(cubit.state.status, VerifyConnectStatus.linked);
          await cubit.close();
        },
      );

      test('stops waiting to try again once closed', () {
        fakeAsync((async) {
          whenConfirm().thenThrow(
            SignInConfirmException(404, SignInRefusal.notFound),
          );
          // No wait passed in, so the cubit's own is the one closed.
          final cubit = VerifyConnectCubit(
            repository: repository,
            pubkey: _pubkey,
            platform: _twitter,
            oauthReturnUrl: _returnUrl,
            analytics: analytics,
            random: _ZeroRandom(),
            launchOAuth: (_) async => answer(Uri.parse(startedReturnUrl!)),
          );
          unawaited(cubit.connectWithOAuth());
          async.flushMicrotasks();
          expect(cubit.state.status, VerifyConnectStatus.awaitingApproval);

          var finished = false;
          unawaited(cubit.approveSignIn().then((_) => finished = true));
          async.flushMicrotasks();
          expectConfirmCalls(1);

          unawaited(cubit.close());
          async.flushMicrotasks();

          // Done at once, without the two seconds passing.
          expect(finished, isTrue);
          async.elapse(const Duration(seconds: 10));
          verifyNever(() => repository.publishSignedClaim(any()));
          verifyNever(
            () => repository.confirmSignIn(
              code: any(named: 'code'),
              startSecret: any(named: 'startSecret'),
              signed: any(named: 'signed'),
            ),
          );
        });
      });

      test('waits two seconds between tries', () async {
        final waits = <Duration>[];
        whenConfirm().thenThrow(
          SignInConfirmException(404, SignInRefusal.notFound),
        );
        final cubit = await waiting(wait: (delay) async => waits.add(delay));
        await cubit.approveSignIn();
        expect(waits, List.filled(4, const Duration(seconds: 2)));
        await cubit.close();
      });

      for (final (name, failure) in <(String, Object)>[
        ('a server error', const VerifierApiException(503, 'returned 503')),
        ('a plain 500', const VerifierApiException(500, 'returned 500')),
        ('a network failure', const VerifierNetworkException('lost')),
        ('a timeout', const VerifierTimeoutException('slow')),
      ]) {
        test('tries again after $name, with the same signed event', () async {
          var calls = 0;
          whenConfirm().thenAnswer((_) async {
            calls++;
            if (calls < 3) throw failure;
            return confirmed;
          });
          final cubit = await waiting();
          await cubit.approveSignIn();
          expectConfirmCalls(3);
          expect(cubit.state.status, VerifyConnectStatus.linked);
          await cubit.close();
        });
      }

      test('does not try again after an answer below 500', () async {
        whenConfirm().thenThrow(
          const VerifierApiException(499, 'returned 499'),
        );
        final cubit = await waiting();
        await cubit.approveSignIn();
        expectConfirmCalls(1);
        expect(cubit.state.status, VerifyConnectStatus.awaitingApproval);
        expect(cubit.state.error, VerifyConnectError.verifierUnreachable);
        await cubit.close();
      });

      test('stops trying again once about ten seconds have passed', () async {
        var now = DateTime.utc(2026, 10, 14);
        await withClock(Clock(() => now), () async {
          // Each answer takes a second to arrive.
          whenConfirm().thenAnswer((_) async {
            now = now.add(const Duration(seconds: 1));
            throw SignInConfirmException(404, SignInRefusal.notFound);
          });
          final cubit = await waiting(
            wait: (delay) async => now = now.add(delay),
          );
          await cubit.approveSignIn();
          // Tries at 0, 3, 6 and 9 seconds; a fifth would start at 12.
          expectConfirmCalls(4);
          verifyNever(() => repository.publishSignedClaim(any()));
          expect(cubit.state.error, VerifyConnectError.signInNotConfirmed);
          await cubit.close();
        });
      });

      test(
        'a request that times out is not tried again past ten seconds',
        () async {
          var now = DateTime.utc(2026, 10, 14);
          await withClock(Clock(() => now), () async {
            whenConfirm().thenAnswer((_) async {
              now = now.add(const Duration(seconds: 10));
              throw const VerifierTimeoutException('slow');
            });
            final cubit = await waiting(
              wait: (delay) async => now = now.add(delay),
            );
            await cubit.approveSignIn();
            expectConfirmCalls(1);
            expect(cubit.state.status, VerifyConnectStatus.awaitingApproval);
            expect(cubit.state.error, VerifyConnectError.verifierUnreachable);
            await cubit.close();
          });
        },
      );

      test(
        'gives up after about ten seconds of not found, without publishing',
        () async {
          whenConfirm().thenThrow(
            SignInConfirmException(404, SignInRefusal.notFound),
          );
          final cubit = await waiting();
          await cubit.approveSignIn();
          expectConfirmCalls(5);
          verifyNever(() => repository.publishSignedClaim(any()));
          expect(cubit.state.error, VerifyConnectError.signInNotConfirmed);
          expect(cubit.state.status, VerifyConnectStatus.editing);
          expect(cubit.state.signedInAccount, isNull);
          await cubit.close();
        },
      );

      test(
        'keeps the approval after about ten seconds of server errors',
        () async {
          whenConfirm().thenThrow(
            const VerifierApiException(503, 'returned 503'),
          );
          final cubit = await waiting();
          await cubit.approveSignIn();
          expectConfirmCalls(5);
          verifyNever(() => repository.publishSignedClaim(any()));
          expect(cubit.state.status, VerifyConnectStatus.awaitingApproval);
          expect(cubit.state.error, VerifyConnectError.verifierUnreachable);
          expect(cubit.state.signedInAccount, 'jack');
          await cubit.close();
        },
      );

      test(
        'a final refusal is not retried, nothing is published, and the account is forgotten',
        () async {
          whenConfirm().thenThrow(
            SignInConfirmException(401, SignInRefusal.notYours),
          );
          final cubit = await waiting();
          await cubit.approveSignIn();
          expectConfirmCalls(1);
          verifyNever(() => repository.publishSignedClaim(any()));
          expect(cubit.state.error, VerifyConnectError.signInNotConfirmed);
          expect(cubit.state.status, VerifyConnectStatus.editing);
          expect(cubit.state.signedInAccount, isNull);

          // The refusal ended the sign-in, so approving again does nothing.
          await cubit.approveSignIn();
          verify(
            () => repository.signClaim(
              any(),
              confirmBinding: any(named: 'confirmBinding'),
            ),
          ).called(1);
          verifyNever(
            () => repository.confirmSignIn(
              code: any(named: 'code'),
              startSecret: any(named: 'startSecret'),
              signed: any(named: 'signed'),
            ),
          );
          await cubit.close();
        },
      );

      test(
        'a rate-limited confirmation is not retried and keeps the approval',
        () async {
          whenConfirm().thenThrow(
            SignInConfirmException(429, SignInRefusal.other),
          );
          final cubit = await waiting();
          await cubit.approveSignIn();
          expectConfirmCalls(1);
          verifyNever(() => repository.publishSignedClaim(any()));
          expect(cubit.state.status, VerifyConnectStatus.awaitingApproval);
          expect(cubit.state.error, VerifyConnectError.verifierUnreachable);
          await cubit.close();
        },
      );

      test(
        'a success that does not name the account is not retried or published',
        () async {
          whenConfirm().thenThrow(
            const VerifierApiException(200, 'no account named'),
          );
          final cubit = await waiting();
          await cubit.approveSignIn();
          expectConfirmCalls(1);
          verifyNever(() => repository.publishSignedClaim(any()));
          expect(cubit.state.status, VerifyConnectStatus.awaitingApproval);
          expect(cubit.state.error, VerifyConnectError.verifierUnreachable);
          await cubit.close();
        },
      );

      for (final (name, confirmation) in <(String, SignInConfirmation)>[
        (
          'another platform',
          const SignInConfirmation(platform: 'youtube', identity: 'jack'),
        ),
        (
          'another account',
          const SignInConfirmation(platform: 'twitter', identity: 'mallory'),
        ),
      ]) {
        test(
          'a success naming $name ends the sign-in without publishing',
          () async {
            await LogCaptureService().clearAllLogs();
            whenConfirm().thenAnswer((_) async => confirmation);
            final cubit = await waiting();
            await cubit.approveSignIn();
            expectConfirmCalls(1);
            verifyNever(() => repository.publishSignedClaim(any()));
            expect(cubit.state.status, VerifyConnectStatus.editing);
            expect(cubit.state.error, VerifyConnectError.signInNotConfirmed);
            expect(cubit.state.signedInAccount, isNull);
            final logged = LogCaptureService()
                .getRecentLogs()
                .map((entry) => entry.message)
                .join('\n');
            expect(
              logged,
              contains('Verifier confirmed another account for the twitter'),
            );
            expect(logged, isNot(contains(confirmation.identity)));

            // A resend gets the same answer, so nothing is left to approve.
            await cubit.approveSignIn();
            verify(
              () => repository.signClaim(
                any(),
                confirmBinding: any(named: 'confirmBinding'),
              ),
            ).called(1);
            verifyNever(
              () => repository.confirmSignIn(
                code: any(named: 'code'),
                startSecret: any(named: 'startSecret'),
                signed: any(named: 'signed'),
              ),
            );
            await cubit.close();
          },
        );
      }

      test('counts a success naming the account in other capitals', () async {
        whenConfirm().thenAnswer(
          (_) async =>
              const SignInConfirmation(platform: 'twitter', identity: 'JACK'),
        );
        final cubit = await waiting();
        await cubit.approveSignIn();
        verify(() => repository.publishSignedClaim(signed)).called(1);
        expect(cubit.state.status, VerifyConnectStatus.linked);
        await cubit.close();
      });

      test(
        'after a lost answer, approving again resends the identical signed event',
        () async {
          var calls = 0;
          whenConfirm().thenAnswer((_) async {
            calls++;
            if (calls <= 5) throw const VerifierNetworkException('lost');
            return confirmed;
          });
          final cubit = await waiting();
          await cubit.approveSignIn();
          expect(cubit.state.status, VerifyConnectStatus.awaitingApproval);
          expect(cubit.state.error, VerifyConnectError.verifierUnreachable);
          await cubit.approveSignIn();
          verify(
            () => repository.signClaim(
              any(),
              confirmBinding: any(named: 'confirmBinding'),
            ),
          ).called(1);
          expectConfirmCalls(6);
          expect(cubit.state.status, VerifyConnectStatus.linked);
          await cubit.close();
        },
      );

      test(
        'when publishing fails after confirming, trying again publishes without confirming again',
        () async {
          var publishes = 0;
          when(() => repository.publishSignedClaim(any())).thenAnswer((
            _,
          ) async {
            publishes++;
            if (publishes == 1) {
              throw const IdentityClaimPublishException('no relay');
            }
            return [];
          });
          final cubit = await waiting();
          await cubit.approveSignIn();
          expect(cubit.state.error, VerifyConnectError.publishFailed);
          expect(cubit.state.status, VerifyConnectStatus.awaitingApproval);
          await cubit.approveSignIn();
          expectConfirmCalls(1);
          expect(cubit.state.status, VerifyConnectStatus.linked);
          await cubit.close();
        },
      );

      blocTest<VerifyConnectCubit, VerifyConnectState>(
        'when the signer declines, says it was not signed and keeps the approval',
        setUp: () =>
            when(
              () => repository.signClaim(
                any(),
                confirmBinding: any(named: 'confirmBinding'),
              ),
            ).thenThrow(
              const IdentityClaimNotSignedException(
                'Could not sign the identity event',
              ),
            ),
        build: () => build(_twitter, random: _ZeroRandom()),
        act: (cubit) async {
          await cubit.connectWithOAuth();
          await cubit.approveSignIn();
        },
        verify: (cubit) {
          expect(cubit.state.status, VerifyConnectStatus.awaitingApproval);
          expect(cubit.state.error, VerifyConnectError.notSigned);
          expect(cubit.state.signedInAccount, 'jack');
          verifyNever(
            () => repository.confirmSignIn(
              code: any(named: 'code'),
              startSecret: any(named: 'startSecret'),
              signed: any(named: 'signed'),
            ),
          );
        },
        // The signer reports its own faults; a decline is the person's
        // choice, so neither is filed again here (#9340).
        errors: () => const [],
      );

      test(
        'when the current links cannot be read, the approval stays and says so',
        () async {
          when(
            () => repository.signClaim(
              any(),
              confirmBinding: any(named: 'confirmBinding'),
            ),
          ).thenThrow(const IdentityClaimReadException('no relay answered'));
          final cubit = await waiting();
          await cubit.approveSignIn();
          expect(cubit.state.status, VerifyConnectStatus.awaitingApproval);
          expect(cubit.state.error, VerifyConnectError.linksUnreadable);
          await cubit.close();
        },
      );

      test(
        'links no proof post while a signed sign-in waits, so approving again cannot drop it',
        () async {
          whenConfirm().thenThrow(const VerifierNetworkException('lost'));
          final cubit = await waiting();
          await cubit.approveSignIn();
          expect(cubit.state.status, VerifyConnectStatus.awaitingApproval);
          cubit
            ..identityChanged('jack')
            ..proofChanged('1234567890');
          expect(cubit.state.canSubmitProof, isTrue);
          await cubit.submitProof();
          verifyNever(() => repository.verifyClaim(any()));
          verifyNever(() => repository.publishClaim(any()));
          await cubit.close();
        },
      );

      test(
        'ignores cancel while approving, and finishes the link it started',
        () async {
          final confirming = Completer<SignInConfirmation>();
          whenConfirm().thenAnswer((_) => confirming.future);
          final cubit = await waiting();
          final approving = cubit.approveSignIn();
          await pumpEventQueue();
          cubit.cancelSignIn();
          expect(cubit.state.status, VerifyConnectStatus.publishing);
          expect(cubit.state.signedInAccount, 'jack');
          confirming.complete(confirmed);
          await approving;
          verify(() => repository.publishSignedClaim(signed)).called(1);
          expect(cubit.state.status, VerifyConnectStatus.linked);
          await cubit.close();
        },
      );

      test(
        'ignores a new sign-in while approving, and finishes the link it started',
        () async {
          final confirming = Completer<SignInConfirmation>();
          whenConfirm().thenAnswer((_) => confirming.future);
          final cubit = await waiting();
          final approving = cubit.approveSignIn();
          await pumpEventQueue();
          await cubit.connectWithOAuth();
          confirming.complete(confirmed);
          await approving;
          verify(
            () => repository.startSignIn(
              platform: any(named: 'platform'),
              pubkey: any(named: 'pubkey'),
              returnUrl: any(named: 'returnUrl'),
              startCheck: any(named: 'startCheck'),
              handle: any(named: 'handle'),
            ),
          ).called(1);
          verify(() => repository.publishSignedClaim(signed)).called(1);
          expect(cubit.state.status, VerifyConnectStatus.linked);
          expect(cubit.state.linkedClaim?.identity, 'jack');
          await cubit.close();
        },
      );

      test(
        'a proof link made while a sign-in waits ends the sign-in',
        () async {
          final cubit = await waiting();
          cubit
            ..identityChanged('jack')
            ..proofChanged('1234567890');
          await cubit.submitProof();
          expect(cubit.state.status, VerifyConnectStatus.linked);
          expect(cubit.state.signedInAccount, isNull);
          await cubit.approveSignIn();
          verifyNever(
            () => repository.signClaim(
              any(),
              confirmBinding: any(named: 'confirmBinding'),
            ),
          );
          await cubit.close();
        },
      );

      test('a second tap while approving signs nothing more', () async {
        final signing = Completer<SignedIdentityClaim>();
        when(
          () => repository.signClaim(
            any(),
            confirmBinding: any(named: 'confirmBinding'),
          ),
        ).thenAnswer((_) => signing.future);
        final cubit = await waiting();
        final first = cubit.approveSignIn();
        final second = cubit.approveSignIn();
        signing.complete(signed);
        await Future.wait([first, second]);
        verify(
          () => repository.signClaim(
            any(),
            confirmBinding: any(named: 'confirmBinding'),
          ),
        ).called(1);
        expect(cubit.state.status, VerifyConnectStatus.linked);
        await cubit.close();
      });

      test(
        'a proof post refused while a sign-in waits also ends the sign-in',
        () async {
          when(
            () => repository.verifyClaim(any()),
          ).thenAnswer((_) async => _result(verified: false));
          final cubit = await waiting();
          cubit
            ..identityChanged('jack')
            ..proofChanged('1234567890');
          await cubit.submitProof();
          expect(cubit.state.status, VerifyConnectStatus.editing);
          expect(cubit.state.signedInAccount, isNull);
          await cubit.approveSignIn();
          verifyNever(
            () => repository.signClaim(
              any(),
              confirmBinding: any(named: 'confirmBinding'),
            ),
          );
          await cubit.close();
        },
      );

      test('publishes nothing when closed while signing', () async {
        final signing = Completer<SignedIdentityClaim>();
        when(
          () => repository.signClaim(
            any(),
            confirmBinding: any(named: 'confirmBinding'),
          ),
        ).thenAnswer((_) => signing.future);
        final cubit = await waiting();
        final approving = cubit.approveSignIn();
        await pumpEventQueue();
        await cubit.close();
        signing.complete(signed);
        await approving;
        verifyNever(
          () => repository.confirmSignIn(
            code: any(named: 'code'),
            startSecret: any(named: 'startSecret'),
            signed: any(named: 'signed'),
          ),
        );
        verifyNever(() => repository.publishSignedClaim(any()));
      });

      test('publishes nothing when closed while confirming', () async {
        final confirming = Completer<SignInConfirmation>();
        whenConfirm().thenAnswer((_) => confirming.future);
        final cubit = await waiting();
        final approving = cubit.approveSignIn();
        await pumpEventQueue();
        await cubit.close();
        confirming.complete(confirmed);
        await approving;
        expectConfirmCalls(1);
        verifyNever(() => repository.publishSignedClaim(any()));
      });

      test('stays quiet when closed while publishing', () async {
        final publishing = Completer<List<List<String>>>();
        when(
          () => repository.publishSignedClaim(any()),
        ).thenAnswer((_) => publishing.future);
        final cubit = await waiting();
        final approving = cubit.approveSignIn();
        await pumpEventQueue();
        await cubit.close();
        publishing.complete([]);
        // Emitting after close throws, which would fail this await.
        await expectLater(approving, completes);
        expect(cubit.state.status, VerifyConnectStatus.publishing);
      });

      test(
        'publishes nothing when closed while waiting to try again',
        () async {
          final retry = Completer<void>();
          whenConfirm().thenThrow(
            SignInConfirmException(404, SignInRefusal.notFound),
          );
          final cubit = await waiting(wait: (_) => retry.future);
          final approving = cubit.approveSignIn();
          await pumpEventQueue();
          await cubit.close();
          retry.complete();
          await approving;
          expectConfirmCalls(1);
          verifyNever(() => repository.publishSignedClaim(any()));
        },
      );

      test(
        'logs a refused confirmation by platform and reason, never the code, secret or binding',
        () async {
          await LogCaptureService().clearAllLogs();
          whenConfirm().thenThrow(
            SignInConfirmException(401, SignInRefusal.notYours),
          );
          final cubit = await waiting();
          await cubit.approveSignIn();
          final logged = LogCaptureService()
              .getRecentLogs()
              .map((entry) => entry.message)
              .join('\n');
          expect(logged, contains('twitter sign-in (notYours)'));
          for (final secret in [
            'C' * 43,
            'A' * 43,
            zeroSecretBinding,
            startedCheck!,
          ]) {
            expect(logged, isNot(contains(secret)));
          }
          await cubit.close();
        },
      );

      test(
        'cancelSignIn forgets the sign-in and goes back to editing',
        () async {
          final cubit = await waiting();
          cubit.cancelSignIn();
          expect(cubit.state.status, VerifyConnectStatus.editing);
          expect(cubit.state.signedInAccount, isNull);
          await cubit.approveSignIn();
          verifyNever(
            () => repository.signClaim(
              any(),
              confirmBinding: any(named: 'confirmBinding'),
            ),
          );
          await cubit.close();
        },
      );
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
