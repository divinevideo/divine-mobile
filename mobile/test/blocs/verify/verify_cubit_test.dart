// ABOUTME: Tests the verify dashboard cubit — loading links with verdicts,
// ABOUTME: degrading when the verifier is down, and unlinking.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/verify/verify_cubit.dart';
import 'package:profile_repository/profile_repository.dart';

class _MockIdentityClaimsRepository extends Mock
    implements IdentityClaimsRepository {}

const _pubkey =
    '1111111111111111111111111111111111111111111111111111111111111111';

const _github = IdentityClaim(
  pubkey: _pubkey,
  platform: 'github',
  identity: 'octocat',
  proof: 'abc',
);
const _twitter = IdentityClaim(
  pubkey: _pubkey,
  platform: 'twitter',
  identity: 'jack',
  proof: IdentityClaim.oauthProof,
);

const _platforms = [
  VerifierPlatform(key: 'github', label: 'GitHub', supported: true),
  VerifierPlatform(key: 'twitter', label: 'Twitter / X', supported: true),
  VerifierPlatform(key: 'mastodon', label: 'Mastodon', supported: true),
];

/// The verifier's own `/platforms` order, which carries no display meaning.
const _allPlatformsInVerifierOrder = [
  VerifierPlatform(key: 'github', label: 'GitHub', supported: true),
  VerifierPlatform(key: 'twitter', label: 'Twitter / X', supported: true),
  VerifierPlatform(key: 'mastodon', label: 'Mastodon', supported: true),
  VerifierPlatform(key: 'telegram', label: 'Telegram', supported: true),
  VerifierPlatform(key: 'bluesky', label: 'Bluesky', supported: true),
  VerifierPlatform(key: 'discord', label: 'Discord', supported: true),
  VerifierPlatform(key: 'tiktok', label: 'TikTok', supported: true),
];

void main() {
  group(VerifyCubit, () {
    late _MockIdentityClaimsRepository repository;

    setUpAll(() {
      registerFallbackValue(_github);
    });

    setUp(() {
      repository = _MockIdentityClaimsRepository();
      when(() => repository.supportedPlatforms()).thenAnswer(
        (_) async => _platforms,
      );
      when(() => repository.claimsWithVerdicts(any())).thenAnswer(
        (_) async => const IdentityClaimStatus(
          claims: [_github, _twitter],
          verifiedKeys: {'github:octocat'},
          verifierReachable: true,
        ),
      );
      when(() => repository.removeClaim(any())).thenAnswer((_) async => []);
    });

    VerifyCubit build() => VerifyCubit(repository: repository, pubkey: _pubkey);

    group('load', () {
      blocTest<VerifyCubit, VerifyState>(
        'emits the claims with their verdicts',
        build: build,
        act: (cubit) => cubit.load(),
        expect: () => [
          isA<VerifyState>().having(
            (s) => s.status,
            'status',
            VerifyStatus.loading,
          ),
          isA<VerifyState>()
              .having((s) => s.status, 'status', VerifyStatus.ready)
              .having((s) => s.claims, 'claims', [_github, _twitter])
              .having((s) => s.verifiedKeys, 'verifiedKeys', {
                'github:octocat',
              })
              .having((s) => s.platforms, 'platforms', _platforms),
        ],
      );

      blocTest<VerifyCubit, VerifyState>(
        'offers only the platforms that have no link yet',
        build: build,
        act: (cubit) => cubit.load(),
        verify: (cubit) {
          expect(
            cubit.state.linkablePlatforms.map((p) => p.key),
            equals(['mastodon']),
          );
        },
      );

      blocTest<VerifyCubit, VerifyState>(
        'lists one-tap platforms before the proof-post ones',
        build: build,
        setUp: () {
          when(() => repository.supportedPlatforms()).thenAnswer(
            (_) async => _allPlatformsInVerifierOrder,
          );
          when(() => repository.claimsWithVerdicts(any())).thenAnswer(
            (_) async => const IdentityClaimStatus(
              claims: [],
              verifiedKeys: {},
              verifierReachable: true,
            ),
          );
        },
        act: (cubit) => cubit.load(),
        verify: (cubit) {
          expect(
            cubit.state.linkablePlatforms.map((p) => p.key),
            equals([
              'twitter',
              'bluesky',
              'tiktok',
              'discord',
              'telegram',
              'mastodon',
              'github',
            ]),
          );
        },
      );

      blocTest<VerifyCubit, VerifyState>(
        'puts a platform the order does not name last, in arrival order',
        build: build,
        setUp: () {
          when(() => repository.supportedPlatforms()).thenAnswer(
            (_) async => const [
              VerifierPlatform(key: 'zeta', label: 'Zeta', supported: true),
              VerifierPlatform(key: 'github', label: 'GitHub', supported: true),
              VerifierPlatform(key: 'alpha', label: 'Alpha', supported: true),
            ],
          );
          when(() => repository.claimsWithVerdicts(any())).thenAnswer(
            (_) async => const IdentityClaimStatus(
              claims: [],
              verifiedKeys: {},
              verifierReachable: true,
            ),
          );
        },
        act: (cubit) => cubit.load(),
        verify: (cubit) {
          expect(
            cubit.state.linkablePlatforms.map((p) => p.key),
            equals(['github', 'zeta', 'alpha']),
          );
        },
      );

      blocTest<VerifyCubit, VerifyState>(
        'fails when the claims cannot be read',
        build: build,
        setUp: () {
          when(
            () => repository.claimsWithVerdicts(any()),
          ).thenThrow(StateError('no relays'));
        },
        act: (cubit) => cubit.load(),
        expect: () => [
          isA<VerifyState>().having(
            (s) => s.status,
            'status',
            VerifyStatus.loading,
          ),
          isA<VerifyState>()
              .having((s) => s.status, 'status', VerifyStatus.failure)
              .having((s) => s.error, 'error', VerifyError.load),
        ],
        errors: () => [isA<StateError>()],
      );

      blocTest<VerifyCubit, VerifyState>(
        'still lists the links when the platform list fails',
        build: build,
        setUp: () {
          when(
            () => repository.supportedPlatforms(),
          ).thenThrow(const VerifierNetworkException('offline'));
        },
        act: (cubit) => cubit.load(),
        verify: (cubit) {
          expect(cubit.state.status, equals(VerifyStatus.ready));
          expect(cubit.state.claims, hasLength(2));
          expect(cubit.state.platforms, isEmpty);
        },
        errors: () => [isA<VerifierNetworkException>()],
      );

      blocTest<VerifyCubit, VerifyState>(
        'ignores a second load while one is in flight',
        build: build,
        act: (cubit) async {
          final first = cubit.load();
          await cubit.load();
          await first;
        },
        verify: (_) {
          verify(() => repository.claimsWithVerdicts(any())).called(1);
        },
      );

      test(
        'returns quietly when closed before the claim read completes',
        () async {
          final claims = Completer<IdentityClaimStatus>();
          when(
            () => repository.claimsWithVerdicts(any()),
          ).thenAnswer((_) => claims.future);
          final cubit = build();

          final load = cubit.load();
          await pumpEventQueue();
          await cubit.close();
          claims.complete(
            const IdentityClaimStatus(
              claims: [_github],
              verifiedKeys: {'github:octocat'},
              verifierReachable: true,
            ),
          );

          await load;
        },
      );
    });

    group('claimLinked', () {
      blocTest<VerifyCubit, VerifyState>(
        'shows the new link without waiting on a relay reread',
        build: build,
        act: (cubit) async {
          await cubit.load();
          cubit.claimLinked(
            const IdentityClaim(
              pubkey: _pubkey,
              platform: 'mastodon',
              identity: 'alice',
              proof: 'https://mastodon.social/@alice/1',
            ),
          );
        },
        verify: (cubit) {
          expect(cubit.state.claims, hasLength(3));
          expect(cubit.state.claims.last.platform, equals('mastodon'));
          expect(cubit.state.isVerified(cubit.state.claims.last), isTrue);
          // Only the connect flow's own publish updates the list.
          verify(() => repository.claimsWithVerdicts(any())).called(1);
        },
      );

      blocTest<VerifyCubit, VerifyState>(
        'replaces a re-linked account rather than listing it twice',
        build: build,
        act: (cubit) async {
          await cubit.load();
          cubit.claimLinked(
            const IdentityClaim(
              pubkey: _pubkey,
              platform: 'github',
              identity: 'octocat',
              proof: 'newproof',
            ),
          );
        },
        verify: (cubit) {
          expect(cubit.state.claims, hasLength(2));
          expect(cubit.state.claims.last.proof, equals('newproof'));
        },
      );

      blocTest<VerifyCubit, VerifyState>(
        'drops the platform from the add list once it is linked',
        build: build,
        act: (cubit) async {
          await cubit.load();
          cubit.claimLinked(
            const IdentityClaim(
              pubkey: _pubkey,
              platform: 'mastodon',
              identity: 'alice',
              proof: 'p',
            ),
          );
        },
        verify: (cubit) {
          expect(cubit.state.linkablePlatforms, isEmpty);
        },
      );
    });

    group('removeClaim', () {
      blocTest<VerifyCubit, VerifyState>(
        'drops the row without waiting on a relay reread',
        build: build,
        act: (cubit) async {
          await cubit.load();
          await cubit.removeClaim(_twitter);
        },
        verify: (cubit) {
          expect(cubit.state.claims, equals([_github]));
          expect(cubit.state.removingKey, isNull);
        },
      );

      blocTest<VerifyCubit, VerifyState>(
        'drops the verdict along with the claim',
        build: build,
        act: (cubit) async {
          await cubit.load();
          await cubit.removeClaim(_github);
        },
        verify: (cubit) {
          expect(cubit.state.verifiedKeys, isEmpty);
        },
      );

      blocTest<VerifyCubit, VerifyState>(
        'keeps the row when the unlink does not land',
        build: build,
        setUp: () {
          when(() => repository.removeClaim(any())).thenThrow(
            const IdentityClaimPublishException('no relay confirmed'),
          );
        },
        act: (cubit) async {
          await cubit.load();
          await cubit.removeClaim(_twitter);
        },
        verify: (cubit) {
          expect(cubit.state.claims, hasLength(2));
          expect(cubit.state.error, equals(VerifyError.remove));
          expect(cubit.state.removingKey, isNull);
        },
        errors: () => [isA<IdentityClaimPublishException>()],
      );

      blocTest<VerifyCubit, VerifyState>(
        'separates an unreadable link list from a failed unlink',
        build: build,
        setUp: () {
          when(() => repository.removeClaim(any())).thenThrow(
            const IdentityClaimReadException('relays went quiet'),
          );
        },
        act: (cubit) async {
          await cubit.load();
          await cubit.removeClaim(_twitter);
        },
        verify: (cubit) {
          expect(cubit.state.error, equals(VerifyError.linksUnreadable));
          // The row stays: nothing was published, so nothing was unlinked.
          expect(cubit.state.claims, hasLength(2));
        },
        errors: () => [isA<IdentityClaimReadException>()],
      );

      blocTest<VerifyCubit, VerifyState>(
        'ignores a second unlink while one is in flight',
        build: build,
        act: (cubit) async {
          await cubit.load();
          final first = cubit.removeClaim(_github);
          await cubit.removeClaim(_twitter);
          await first;
        },
        verify: (_) {
          verify(() => repository.removeClaim(any())).called(1);
        },
      );

      test('returns quietly when closed before the unlink completes', () async {
        final removed = Completer<List<List<String>>>();
        when(() => repository.removeClaim(any())).thenAnswer(
          (_) => removed.future,
        );
        final cubit = build();
        addTearDown(() async {
          if (!cubit.isClosed) await cubit.close();
        });
        await cubit.load();

        final remove = cubit.removeClaim(_twitter);
        await pumpEventQueue();
        await cubit.close();
        removed.complete(const []);

        await remove;
      });
    });

    test('reports an unreachable verifier instead of "not verified"', () async {
      when(() => repository.claimsWithVerdicts(any())).thenAnswer(
        (_) async => const IdentityClaimStatus(
          claims: [_github],
          verifiedKeys: {},
          verifierReachable: false,
        ),
      );
      final cubit = build();
      addTearDown(cubit.close);

      await cubit.load();

      expect(cubit.state.verifierReachable, isFalse);
      expect(cubit.state.isVerified(_github), isFalse);
    });
  });
}
