// ABOUTME: Tests for IdentityClaimsRepository — parseClaims, resolveClaims,
// ABOUTME: and the persistent verified-claims cache (#3936).

import 'package:db_client/db_client.dart' hide Filter;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart' hide VerificationResult;
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart' show Event, Filter, PublishOutcome;
import 'package:profile_repository/profile_repository.dart';

class _MockVerifierClient extends Mock implements VerifierClient {}

class _MockIdentityVerificationsDao extends Mock
    implements IdentityVerificationsDao {}

class _MockNostrClient extends Mock implements NostrClient {}

class _MockIdentityEventsDao extends Mock implements IdentityEventsDao {}

const _pubkey =
    '1111111111111111111111111111111111111111111111111111111111111111';

int _nowSeconds() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

IdentityVerificationRow _row({
  required String claimsJson,
  required int checkedAtFloor,
}) {
  return IdentityVerificationRow(
    pubkey: _pubkey,
    verifiedClaimsJson: claimsJson,
    checkedAtFloor: checkedAtFloor,
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(<IdentityClaim>[]);
  });

  group('IdentityClaimsRepository.parseClaims', () {
    test('extracts well-formed i tags', () {
      final tags = [
        ['i', 'github:octocat', 'abc'],
        ['i', 'twitter:elon', 'def'],
      ];
      final claims = IdentityClaimsRepository.parseClaims(_pubkey, tags);
      expect(claims, hasLength(2));
      expect(claims.first.platform, equals('github'));
      expect(claims.first.identity, equals('octocat'));
      expect(claims.first.proof, equals('abc'));
    });

    test('skips tags whose name is not "i"', () {
      final tags = [
        ['p', 'somepubkey'],
        ['i', 'github:octocat', 'abc'],
      ];
      expect(IdentityClaimsRepository.parseClaims(_pubkey, tags), hasLength(1));
    });

    test('skips i tags without a platform:identity prefix', () {
      final tags = [
        ['i', 'no_colon_here', 'abc'],
        ['i', '', 'abc'],
        ['i', ':no_platform', 'abc'],
        ['i', 'no_identity:', 'abc'],
      ];
      expect(IdentityClaimsRepository.parseClaims(_pubkey, tags), isEmpty);
    });

    test('skips i tags missing a proof', () {
      final tags = [
        ['i', 'github:octocat'],
      ];
      expect(IdentityClaimsRepository.parseClaims(_pubkey, tags), isEmpty);
    });

    test('skips i tags whose claims fail the verifier contract', () {
      final longIdentity = List.filled(
        IdentityClaim.maxServerTextLength + 1,
        'a',
      ).join();
      final tags = [
        ['i', 'github:bad"identity', 'abc'],
        ['i', 'github:bad<identity', 'abc'],
        ['i', 'github:bad${String.fromCharCode(1)}identity', 'abc'],
        ['i', 'github:$longIdentity', 'abc'],
        ['i', 'github:octocat', 'bad>proof'],
      ];
      expect(IdentityClaimsRepository.parseClaims(_pubkey, tags), isEmpty);
    });

    test('skips unsupported verifier platforms', () {
      final tags = [
        ['i', 'reddit:octocat', 'abc'],
        ['i', 'github:octocat', 'abc'],
      ];
      final claims = IdentityClaimsRepository.parseClaims(_pubkey, tags);
      expect(claims, hasLength(1));
      expect(claims.single.platform, equals('github'));
    });

    test('keeps bluesky claims with blank proof', () {
      final tags = [
        ['i', 'bluesky:octocat.bsky.social', ''],
      ];
      final claims = IdentityClaimsRepository.parseClaims(_pubkey, tags);
      expect(claims, hasLength(1));
      expect(claims.single.platform, equals('bluesky'));
      expect(claims.single.proof, isEmpty);
    });

    test('skips empty tag entries', () {
      final tags = [
        <String>[],
        ['i', 'github:octocat', 'abc'],
      ];
      expect(IdentityClaimsRepository.parseClaims(_pubkey, tags), hasLength(1));
    });

    test('dedupes by case-insensitive platform:identity, keeping first', () {
      final tags = [
        ['i', 'github:Octocat', 'first'],
        ['i', 'github:octocat', 'second'],
      ];
      final claims = IdentityClaimsRepository.parseClaims(_pubkey, tags);
      expect(claims, hasLength(1));
      expect(claims.single.proof, equals('first'));
    });

    test('caps the result at 10 to match server MAX_BATCH_SIZE', () {
      final tags = List<List<String>>.generate(
        15,
        (i) => ['i', 'github:user$i', 'p$i'],
      );
      final claims = IdentityClaimsRepository.parseClaims(_pubkey, tags);
      expect(claims, hasLength(10));
    });

    test('caps at 10 valid claims after verifier-contract filtering', () {
      final tags = [
        ['i', 'github:bad"identity', 'bad>proof'],
        ...List<List<String>>.generate(
          10,
          (i) => ['i', 'github:user$i', 'p$i'],
        ),
      ];
      final claims = IdentityClaimsRepository.parseClaims(_pubkey, tags);
      expect(claims, hasLength(10));
      expect(claims.map((claim) => claim.identity), contains('user9'));
    });

    test('does not let an invalid duplicate block a valid claim', () {
      final tags = [
        ['i', 'github:octocat', 'bad>proof'],
        ['i', 'github:octocat', 'abc'],
      ];
      final claims = IdentityClaimsRepository.parseClaims(_pubkey, tags);
      expect(claims, hasLength(1));
      expect(claims.single.proof, equals('abc'));
    });

    test('attaches the pubkey to each claim', () {
      final tags = [
        ['i', 'github:octocat', 'abc'],
      ];
      expect(
        IdentityClaimsRepository.parseClaims(_pubkey, tags).single.pubkey,
        equals(_pubkey),
      );
    });
  });

  group('IdentityClaimsRepository.resolveClaims (verify path)', () {
    late _MockVerifierClient client;
    late IdentityClaimsRepository repo;

    setUp(() {
      client = _MockVerifierClient();
      repo = IdentityClaimsRepository(verifierClient: client);
    });

    // A null cache forces the verify path (no snapshot to skip against).
    test('returns only claims the verifier confirmed', () async {
      when(() => client.verifyBatch(any())).thenAnswer(
        (_) async => const [
          VerificationResult(
            platform: 'github',
            identity: 'octocat',
            verified: true,
            checkedAt: 1,
            cached: true,
          ),
          VerificationResult(
            platform: 'twitter',
            identity: 'fake',
            verified: false,
            checkedAt: 1,
            cached: false,
          ),
        ],
      );
      final result = await repo.resolveClaims(
        pubkey: _pubkey,
        freshTags: [
          ['i', 'github:octocat', 'a'],
          ['i', 'twitter:fake', 'b'],
        ],
        cached: null,
      );
      expect(result, hasLength(1));
      expect(result.single.platform, equals('github'));
    });

    test('sends only verifier-valid claims to the verifier', () async {
      when(() => client.verifyBatch(any())).thenAnswer(
        (_) async => const [
          VerificationResult(
            platform: 'github',
            identity: 'octocat',
            verified: true,
            checkedAt: 1,
            cached: false,
          ),
        ],
      );

      final result = await repo.resolveClaims(
        pubkey: _pubkey,
        freshTags: const [
          [
            'i',
            'bluesky:Verifying my account on nostr My Public Key: "npub1"',
            '',
          ],
          ['i', 'github:octocat', 'abc'],
        ],
        cached: null,
      );

      expect(result, hasLength(1));
      final sent = verify(() => client.verifyBatch(captureAny())).captured;
      final claims = sent.single as List<IdentityClaim>;
      expect(claims, hasLength(1));
      expect(claims.single.platform, equals('github'));
      expect(claims.single.identity, equals('octocat'));
    });

    test(
      'returns empty and skips the verifier when there are no i tags',
      () async {
        final result = await repo.resolveClaims(
          pubkey: _pubkey,
          freshTags: const [
            ['p', 'someone'],
          ],
          cached: null,
        );
        expect(result, isEmpty);
        verifyNever(() => client.verifyBatch(any()));
      },
    );

    test('case-insensitively matches verifier results to claims', () async {
      // Verifier returns lowercase platform/identity even if claim used
      // mixed case.
      when(() => client.verifyBatch(any())).thenAnswer(
        (_) async => const [
          VerificationResult(
            platform: 'github',
            identity: 'octocat',
            verified: true,
            checkedAt: 1,
            cached: true,
          ),
        ],
      );
      final result = await repo.resolveClaims(
        pubkey: _pubkey,
        freshTags: [
          ['i', 'github:Octocat', 'a'],
        ],
        cached: null,
      );
      expect(result, hasLength(1));
      expect(result.single.platform, equals('github'));
      expect(result.single.identity, equals('Octocat'));
    });

    test('propagates VerifierApiException', () async {
      when(
        () => client.verifyBatch(any()),
      ).thenThrow(const VerifierApiException(500, 'boom'));
      await expectLater(
        () => repo.resolveClaims(
          pubkey: _pubkey,
          freshTags: [
            ['i', 'github:octocat', 'abc'],
          ],
          cached: null,
        ),
        throwsA(isA<VerifierApiException>()),
      );
    });
  });

  group('IdentityClaimsRepository.resolveClaims (SWR decision)', () {
    late _MockVerifierClient client;
    late IdentityClaimsRepository repo;

    const octocatClaim = IdentityClaim(
      pubkey: _pubkey,
      platform: 'github',
      identity: 'octocat',
      proof: 'a',
    );

    setUp(() {
      client = _MockVerifierClient();
      repo = IdentityClaimsRepository(verifierClient: client);
    });

    test(
      'skips the verifier when a fresh snapshot covers every current claim',
      () async {
        final result = await repo.resolveClaims(
          pubkey: _pubkey,
          freshTags: [
            ['i', 'github:octocat', 'a'],
          ],
          cached: const CachedVerifiedClaims(
            claims: [octocatClaim],
            isFresh: true,
          ),
        );
        expect(result, equals([octocatClaim]));
        verifyNever(() => client.verifyBatch(any()));
      },
    );

    test('re-verifies when the snapshot is stale', () async {
      when(() => client.verifyBatch(any())).thenAnswer(
        (_) async => const [
          VerificationResult(
            platform: 'github',
            identity: 'octocat',
            verified: true,
            checkedAt: 1,
            cached: false,
          ),
        ],
      );
      final result = await repo.resolveClaims(
        pubkey: _pubkey,
        freshTags: [
          ['i', 'github:octocat', 'a'],
        ],
        cached: const CachedVerifiedClaims(
          claims: [octocatClaim],
          isFresh: false,
        ),
      );
      expect(result, equals([octocatClaim]));
      verify(() => client.verifyBatch(any())).called(1);
    });

    test(
      're-verifies when a fresh snapshot does not cover a new claim',
      () async {
        when(() => client.verifyBatch(any())).thenAnswer(
          (_) async => const [
            VerificationResult(
              platform: 'github',
              identity: 'octocat',
              verified: true,
              checkedAt: 1,
              cached: false,
            ),
            VerificationResult(
              platform: 'telegram',
              identity: 'octo',
              verified: true,
              checkedAt: 1,
              cached: false,
            ),
          ],
        );
        final result = await repo.resolveClaims(
          pubkey: _pubkey,
          freshTags: [
            ['i', 'github:octocat', 'a'],
            ['i', 'telegram:octo', 'b'],
          ],
          cached: const CachedVerifiedClaims(
            claims: [octocatClaim],
            isFresh: true,
          ),
        );
        expect(result, hasLength(2));
        verify(() => client.verifyBatch(any())).called(1);
      },
    );
  });

  group('IdentityClaimsRepository.cachedVerifiedClaims', () {
    late _MockVerifierClient client;
    late _MockIdentityVerificationsDao dao;
    late IdentityClaimsRepository repo;

    const snapshotJson =
        '[{"platform":"github","identity":"octocat","proof":"a"}]';

    setUp(() {
      client = _MockVerifierClient();
      dao = _MockIdentityVerificationsDao();
      repo = IdentityClaimsRepository(
        verifierClient: client,
        identityVerificationsDao: dao,
      );
    });

    test('returns null when no DAO is wired', () async {
      final bare = IdentityClaimsRepository(verifierClient: client);
      expect(
        await bare.cachedVerifiedClaims(pubkey: _pubkey, tags: const []),
        isNull,
      );
    });

    test('returns null when no snapshot row exists', () async {
      when(() => dao.getVerification(_pubkey)).thenAnswer((_) async => null);
      expect(
        await repo.cachedVerifiedClaims(pubkey: _pubkey, tags: const []),
        isNull,
      );
    });

    test('returns null when the stored snapshot is corrupt', () async {
      when(() => dao.getVerification(_pubkey)).thenAnswer(
        (_) async => _row(claimsJson: 'not json', checkedAtFloor: 1),
      );
      expect(
        await repo.cachedVerifiedClaims(pubkey: _pubkey, tags: const []),
        isNull,
      );
    });

    test('returns null when the snapshot is valid JSON of the wrong shape '
        '(TypeError, not just Exception)', () async {
      // A JSON object instead of a list, and a list of the wrong element
      // shape, both throw TypeError on the decode casts — the decoder must
      // still degrade to null rather than let an Error escape.
      for (final malformed in const [
        '{"platform":"github"}',
        '[{"platform":123,"identity":"octocat","proof":"a"}]',
      ]) {
        when(() => dao.getVerification(_pubkey)).thenAnswer(
          (_) async => _row(claimsJson: malformed, checkedAtFloor: 1),
        );
        expect(
          await repo.cachedVerifiedClaims(
            pubkey: _pubkey,
            tags: [
              ['i', 'github:octocat', 'a'],
            ],
          ),
          isNull,
          reason: 'wrong-shape snapshot "$malformed" should decode to null',
        );
      }
    });

    test('intersects current claims with the snapshot — case-insensitive '
        'platform/identity, exact proof', () async {
      when(() => dao.getVerification(_pubkey)).thenAnswer(
        (_) async =>
            _row(claimsJson: snapshotJson, checkedAtFloor: _nowSeconds()),
      );
      final cached = await repo.cachedVerifiedClaims(
        pubkey: _pubkey,
        tags: [
          ['i', 'github:Octocat', 'a'],
          ['i', 'twitter:unverified', 'b'],
        ],
      );
      expect(cached, isNotNull);
      expect(cached!.claims, hasLength(1));
      expect(cached.claims.single.platform, equals('github'));
      expect(cached.isFresh, isTrue);
    });

    test('a rotated proof misses the snapshot', () async {
      when(() => dao.getVerification(_pubkey)).thenAnswer(
        (_) async =>
            _row(claimsJson: snapshotJson, checkedAtFloor: _nowSeconds()),
      );
      final cached = await repo.cachedVerifiedClaims(
        pubkey: _pubkey,
        tags: [
          ['i', 'github:octocat', 'rotated-proof'],
        ],
      );
      expect(cached!.claims, isEmpty);
    });

    test('is stale once checkedAtFloor is older than the 24h TTL', () async {
      when(() => dao.getVerification(_pubkey)).thenAnswer(
        (_) async => _row(
          claimsJson: snapshotJson,
          checkedAtFloor: _nowSeconds() - 25 * 3600,
        ),
      );
      final cached = await repo.cachedVerifiedClaims(
        pubkey: _pubkey,
        tags: [
          ['i', 'github:octocat', 'a'],
        ],
      );
      expect(cached!.claims, hasLength(1));
      expect(cached.isFresh, isFalse);
    });
  });

  group('IdentityClaimsRepository.resolveClaims persistence', () {
    late _MockVerifierClient client;
    late _MockIdentityVerificationsDao dao;
    late IdentityClaimsRepository repo;

    setUp(() {
      client = _MockVerifierClient();
      dao = _MockIdentityVerificationsDao();
      repo = IdentityClaimsRepository(
        verifierClient: client,
        identityVerificationsDao: dao,
      );
      when(
        () => dao.upsertVerification(
          pubkey: any(named: 'pubkey'),
          verifiedClaimsJson: any(named: 'verifiedClaimsJson'),
          checkedAtFloor: any(named: 'checkedAtFloor'),
        ),
      ).thenAnswer((_) async {});
      when(() => dao.deleteVerification(any())).thenAnswer((_) async => 1);
      when(() => dao.getVerification(any())).thenAnswer((_) async => null);
    });

    test(
      'persists verified tuples with the minimum checked_at as floor',
      () async {
        when(() => client.verifyBatch(any())).thenAnswer(
          (_) async => const [
            VerificationResult(
              platform: 'github',
              identity: 'octocat',
              verified: true,
              checkedAt: 500,
              cached: true,
            ),
            VerificationResult(
              platform: 'telegram',
              identity: 'octo',
              verified: true,
              checkedAt: 300,
              cached: false,
            ),
            VerificationResult(
              platform: 'twitter',
              identity: 'fake',
              verified: false,
              checkedAt: 900,
              cached: false,
              error: 'Post not found',
            ),
          ],
        );

        await repo.resolveClaims(
          pubkey: _pubkey,
          freshTags: [
            ['i', 'github:octocat', 'a'],
            ['i', 'telegram:octo', 'b'],
            ['i', 'twitter:fake', 'c'],
          ],
          cached: null,
        );

        final captured =
            verify(
                  () => dao.upsertVerification(
                    pubkey: _pubkey,
                    verifiedClaimsJson: captureAny(named: 'verifiedClaimsJson'),
                    checkedAtFloor: 300,
                  ),
                ).captured.single
                as String;
        expect(captured, contains('"github"'));
        expect(captured, contains('"telegram"'));
        expect(captured, isNot(contains('"twitter"')));
        verifyNever(() => dao.deleteVerification(any()));
      },
    );

    test('deletes the snapshot when the verifier confirms none', () async {
      when(() => client.verifyBatch(any())).thenAnswer(
        (_) async => const [
          VerificationResult(
            platform: 'github',
            identity: 'octocat',
            verified: false,
            checkedAt: 500,
            cached: false,
            error: 'Gist not found',
          ),
        ],
      );

      await repo.resolveClaims(
        pubkey: _pubkey,
        freshTags: [
          ['i', 'github:octocat', 'a'],
        ],
        cached: null,
      );

      verify(() => dao.deleteVerification(_pubkey)).called(1);
      verifyNever(
        () => dao.upsertVerification(
          pubkey: any(named: 'pubkey'),
          verifiedClaimsJson: any(named: 'verifiedClaimsJson'),
          checkedAtFloor: any(named: 'checkedAtFloor'),
        ),
      );
    });

    test(
      'leaves the snapshot untouched when any result is rate-limited',
      () async {
        when(() => client.verifyBatch(any())).thenAnswer(
          (_) async => const [
            VerificationResult(
              platform: 'github',
              identity: 'octocat',
              verified: true,
              checkedAt: 500,
              cached: true,
            ),
            VerificationResult(
              platform: 'twitter',
              identity: 'octo',
              verified: false,
              checkedAt: 900,
              cached: false,
              error: 'Rate limit exceeded for this pubkey',
            ),
          ],
        );

        final result = await repo.resolveClaims(
          pubkey: _pubkey,
          freshTags: [
            ['i', 'github:octocat', 'a'],
            ['i', 'twitter:octo', 'b'],
          ],
          cached: null,
        );

        expect(result, hasLength(1));
        verifyNever(
          () => dao.upsertVerification(
            pubkey: any(named: 'pubkey'),
            verifiedClaimsJson: any(named: 'verifiedClaimsJson'),
            checkedAtFloor: any(named: 'checkedAtFloor'),
          ),
        );
        verifyNever(() => dao.deleteVerification(any()));
      },
    );

    test('leaves the snapshot untouched when every result is rate-limited '
        '(zero verified must not trigger the delete path)', () async {
      // The rate-limit guard must be checked BEFORE the zero-verified
      // delete: an all-rate-limited burst has no verified claims, so
      // reordering the guards would wipe a good snapshot here.
      when(() => client.verifyBatch(any())).thenAnswer(
        (_) async => const [
          VerificationResult(
            platform: 'github',
            identity: 'octocat',
            verified: false,
            checkedAt: 900,
            cached: false,
            error: 'Rate limit exceeded for this pubkey',
          ),
          VerificationResult(
            platform: 'twitter',
            identity: 'octo',
            verified: false,
            checkedAt: 900,
            cached: false,
            error: 'Rate limit exceeded for this platform',
          ),
        ],
      );

      final result = await repo.resolveClaims(
        pubkey: _pubkey,
        freshTags: [
          ['i', 'github:octocat', 'a'],
          ['i', 'twitter:octo', 'b'],
        ],
        cached: null,
      );

      expect(result, isEmpty);
      verifyNever(() => dao.deleteVerification(any()));
      verifyNever(
        () => dao.upsertVerification(
          pubkey: any(named: 'pubkey'),
          verifiedClaimsJson: any(named: 'verifiedClaimsJson'),
          checkedAtFloor: any(named: 'checkedAtFloor'),
        ),
      );
    });

    test(
      'returns cached current claims when stale revalidation is rate-limited',
      () async {
        const cachedOctocatClaim = IdentityClaim(
          pubkey: _pubkey,
          platform: 'github',
          identity: 'octocat',
          proof: 'a',
        );
        const removedCachedClaim = IdentityClaim(
          pubkey: _pubkey,
          platform: 'twitter',
          identity: 'old',
          proof: 'removed-proof',
        );
        when(() => client.verifyBatch(any())).thenAnswer(
          (_) async => const [
            VerificationResult(
              platform: 'github',
              identity: 'octocat',
              verified: false,
              checkedAt: 900,
              cached: false,
              error: 'Rate limit exceeded for this pubkey',
            ),
          ],
        );

        final result = await repo.resolveClaims(
          pubkey: _pubkey,
          freshTags: [
            ['i', 'github:octocat', 'a'],
          ],
          cached: const CachedVerifiedClaims(
            claims: [cachedOctocatClaim, removedCachedClaim],
            isFresh: false,
          ),
        );

        expect(result, equals([cachedOctocatClaim]));
        verifyNever(() => dao.deleteVerification(any()));
        verifyNever(
          () => dao.upsertVerification(
            pubkey: any(named: 'pubkey'),
            verifiedClaimsJson: any(named: 'verifiedClaimsJson'),
            checkedAtFloor: any(named: 'checkedAtFloor'),
          ),
        );
      },
    );

    test('preserves rendered claims when rate-limited with no usable snapshot '
        '(#6176 review)', () async {
      const renderedClaim = IdentityClaim(
        pubkey: _pubkey,
        platform: 'github',
        identity: 'octocat',
        proof: 'a',
      );
      when(() => client.verifyBatch(any())).thenAnswer(
        (_) async => const [
          VerificationResult(
            platform: 'github',
            identity: 'octocat',
            verified: false,
            checkedAt: 900,
            cached: false,
            error: 'Rate limit exceeded for this pubkey',
          ),
        ],
      );

      final result = await repo.resolveClaims(
        pubkey: _pubkey,
        freshTags: [
          ['i', 'github:octocat', 'a'],
        ],
        cached: null,
        renderedClaims: const [renderedClaim],
      );

      expect(result, equals([renderedClaim]));
      verifyNever(() => dao.deleteVerification(any()));
      verifyNever(
        () => dao.upsertVerification(
          pubkey: any(named: 'pubkey'),
          verifiedClaimsJson: any(named: 'verifiedClaimsJson'),
          checkedAtFloor: any(named: 'checkedAtFloor'),
        ),
      );
    });

    test('preserves rendered claims when rate-limited with an empty snapshot '
        'intersection', () async {
      const renderedClaim = IdentityClaim(
        pubkey: _pubkey,
        platform: 'github',
        identity: 'octocat',
        proof: 'a',
      );
      when(() => client.verifyBatch(any())).thenAnswer(
        (_) async => const [
          VerificationResult(
            platform: 'github',
            identity: 'octocat',
            verified: false,
            checkedAt: 900,
            cached: false,
            error: 'Rate limit exceeded for this pubkey',
          ),
        ],
      );

      final result = await repo.resolveClaims(
        pubkey: _pubkey,
        freshTags: [
          ['i', 'github:octocat', 'a'],
        ],
        cached: const CachedVerifiedClaims(claims: [], isFresh: false),
        renderedClaims: const [renderedClaim],
      );

      expect(result, equals([renderedClaim]));
    });

    test('drops rendered claims no longer present in the fresh tags even when '
        'rate-limited', () async {
      const removedRenderedClaim = IdentityClaim(
        pubkey: _pubkey,
        platform: 'twitter',
        identity: 'old',
        proof: 'removed-proof',
      );
      when(() => client.verifyBatch(any())).thenAnswer(
        (_) async => const [
          VerificationResult(
            platform: 'github',
            identity: 'octocat',
            verified: false,
            checkedAt: 900,
            cached: false,
            error: 'Rate limit exceeded for this pubkey',
          ),
        ],
      );

      final result = await repo.resolveClaims(
        pubkey: _pubkey,
        freshTags: [
          ['i', 'github:octocat', 'a'],
        ],
        cached: null,
        renderedClaims: const [removedRenderedClaim],
      );

      expect(result, isEmpty);
    });

    test('clears rendered claims when the verifier returns a confirmed '
        'negative (non-rate-limited)', () async {
      const renderedClaim = IdentityClaim(
        pubkey: _pubkey,
        platform: 'github',
        identity: 'octocat',
        proof: 'a',
      );
      when(() => client.verifyBatch(any())).thenAnswer(
        (_) async => const [
          VerificationResult(
            platform: 'github',
            identity: 'octocat',
            verified: false,
            checkedAt: 900,
            cached: false,
            error: 'Gist not found',
          ),
        ],
      );

      final result = await repo.resolveClaims(
        pubkey: _pubkey,
        freshTags: [
          ['i', 'github:octocat', 'a'],
        ],
        cached: null,
        renderedClaims: const [renderedClaim],
      );

      expect(result, isEmpty);
      verify(() => dao.deleteVerification(_pubkey)).called(1);
    });

    test('preserves a rendered claim across proof rotation and casing drift '
        'when rate-limited (identity-granular matching)', () async {
      const renderedClaim = IdentityClaim(
        pubkey: _pubkey,
        platform: 'github',
        identity: 'octocat',
        proof: 'old-proof',
      );
      when(() => client.verifyBatch(any())).thenAnswer(
        (_) async => const [
          VerificationResult(
            platform: 'GitHub',
            identity: 'Octocat',
            verified: false,
            checkedAt: 900,
            cached: false,
            error: 'Rate limit exceeded for this pubkey',
          ),
        ],
      );

      final result = await repo.resolveClaims(
        pubkey: _pubkey,
        freshTags: [
          ['i', 'github:Octocat', 'new-proof'],
        ],
        cached: null,
        renderedClaims: const [renderedClaim],
      );

      // The verifier judges platform:identity, not proof strings — an
      // inconclusive (rate-limited) verdict on a rotated proof must not
      // drop the previously verified identity's chip.
      expect(result, hasLength(1));
      expect(result.single.proof, equals('new-proof'));
    });

    test('drops a claim whose own result is a confirmed negative inside a '
        'rate-limited batch', () async {
      const githubClaim = IdentityClaim(
        pubkey: _pubkey,
        platform: 'github',
        identity: 'octocat',
        proof: 'a',
      );
      const twitterClaim = IdentityClaim(
        pubkey: _pubkey,
        platform: 'twitter',
        identity: 'octo',
        proof: 'b',
      );
      when(() => client.verifyBatch(any())).thenAnswer(
        (_) async => const [
          VerificationResult(
            platform: 'github',
            identity: 'octocat',
            verified: false,
            checkedAt: 900,
            cached: false,
            error: 'Rate limit exceeded for this platform',
          ),
          VerificationResult(
            platform: 'twitter',
            identity: 'octo',
            verified: false,
            checkedAt: 900,
            cached: false,
            error: 'Tweet not found',
          ),
        ],
      );

      final result = await repo.resolveClaims(
        pubkey: _pubkey,
        freshTags: [
          ['i', 'github:octocat', 'a'],
          ['i', 'twitter:octo', 'b'],
        ],
        cached: null,
        renderedClaims: const [githubClaim, twitterClaim],
      );

      // github's own result is rate-limited (inconclusive) → preserved;
      // twitter's own result is a confirmed negative → dropped even
      // though the batch as a whole is rate-limited.
      expect(result, equals([githubClaim]));
      verifyNever(() => dao.deleteVerification(any()));
      verifyNever(
        () => dao.upsertVerification(
          pubkey: any(named: 'pubkey'),
          verifiedClaimsJson: any(named: 'verifiedClaimsJson'),
          checkedAtFloor: any(named: 'checkedAtFloor'),
        ),
      );
    });

    group(
      'confirmed-negative snapshot pruning during a rate-limited batch',
      () {
        const mixedResults = [
          VerificationResult(
            platform: 'github',
            identity: 'octocat',
            verified: false,
            checkedAt: 900,
            cached: false,
            error: 'Rate limit exceeded for this platform',
          ),
          VerificationResult(
            platform: 'twitter',
            identity: 'octo',
            verified: false,
            checkedAt: 900,
            cached: false,
            error: 'Tweet not found',
          ),
        ];
        const mixedTags = [
          ['i', 'github:octocat', 'a'],
          ['i', 'twitter:octo', 'b'],
        ];

        test('prunes the negated entry and keeps the rest', () async {
          when(
            () => client.verifyBatch(any()),
          ).thenAnswer((_) async => mixedResults);
          when(() => dao.getVerification(_pubkey)).thenAnswer(
            (_) async => _row(
              claimsJson:
                  '[{"platform":"github","identity":"octocat","proof":"a"},'
                  '{"platform":"Twitter","identity":"Octo","proof":"b"}]',
              checkedAtFloor: 500,
            ),
          );

          await repo.resolveClaims(
            pubkey: _pubkey,
            freshTags: mixedTags,
            cached: null,
          );

          // twitter:octo got a confirmed negative → pruned (matched
          // case-insensitively); github stays because its own result is
          // only rate-limited. checkedAtFloor is preserved as-is.
          verify(
            () => dao.upsertVerification(
              pubkey: _pubkey,
              verifiedClaimsJson:
                  '[{"platform":"github","identity":"octocat","proof":"a"}]',
              checkedAtFloor: 500,
            ),
          ).called(1);
          verifyNever(() => dao.deleteVerification(any()));
        });

        test('deletes the snapshot when every entry is negated', () async {
          when(
            () => client.verifyBatch(any()),
          ).thenAnswer((_) async => mixedResults);
          when(() => dao.getVerification(_pubkey)).thenAnswer(
            (_) async => _row(
              claimsJson:
                  '[{"platform":"twitter","identity":"octo","proof":"b"}]',
              checkedAtFloor: 500,
            ),
          );

          await repo.resolveClaims(
            pubkey: _pubkey,
            freshTags: mixedTags,
            cached: null,
          );

          verify(() => dao.deleteVerification(_pubkey)).called(1);
          verifyNever(
            () => dao.upsertVerification(
              pubkey: any(named: 'pubkey'),
              verifiedClaimsJson: any(named: 'verifiedClaimsJson'),
              checkedAtFloor: any(named: 'checkedAtFloor'),
            ),
          );
        });

        test('writes nothing when no snapshot entry is negated', () async {
          when(
            () => client.verifyBatch(any()),
          ).thenAnswer((_) async => mixedResults);
          when(() => dao.getVerification(_pubkey)).thenAnswer(
            (_) async => _row(
              claimsJson:
                  '[{"platform":"github","identity":"octocat","proof":"a"}]',
              checkedAtFloor: 500,
            ),
          );

          await repo.resolveClaims(
            pubkey: _pubkey,
            freshTags: mixedTags,
            cached: null,
          );

          verifyNever(() => dao.deleteVerification(any()));
          verifyNever(
            () => dao.upsertVerification(
              pubkey: any(named: 'pubkey'),
              verifiedClaimsJson: any(named: 'verifiedClaimsJson'),
              checkedAtFloor: any(named: 'checkedAtFloor'),
            ),
          );
        });

        test('leaves a malformed snapshot row alone', () async {
          when(
            () => client.verifyBatch(any()),
          ).thenAnswer((_) async => mixedResults);
          when(() => dao.getVerification(_pubkey)).thenAnswer(
            (_) async => _row(claimsJson: 'not json', checkedAtFloor: 500),
          );

          await repo.resolveClaims(
            pubkey: _pubkey,
            freshTags: mixedTags,
            cached: null,
          );

          verifyNever(() => dao.deleteVerification(any()));
          verifyNever(
            () => dao.upsertVerification(
              pubkey: any(named: 'pubkey'),
              verifiedClaimsJson: any(named: 'verifiedClaimsJson'),
              checkedAtFloor: any(named: 'checkedAtFloor'),
            ),
          );
        });
      },
    );
  });

  group('IdentityClaimsRepository write path', () {
    late _MockVerifierClient client;
    late _MockNostrClient nostrClient;
    late _MockIdentityEventsDao identityEventsDao;
    late _MockIdentityVerificationsDao verificationsDao;
    late IdentityClaimsRepository repo;
    late List<List<String>>? signedTags;
    late String? signedContent;
    late int? signedKind;
    late int? signedCreatedAt;
    late bool signerRefuses;

    setUpAll(() {
      registerFallbackValue(<Filter>[]);
      registerFallbackValue(_event(id: _eventId(1), kind: 10011));
    });

    setUp(() {
      client = _MockVerifierClient();
      nostrClient = _MockNostrClient();
      identityEventsDao = _MockIdentityEventsDao();
      verificationsDao = _MockIdentityVerificationsDao();
      signedTags = null;
      signedContent = null;
      signedKind = null;
      signedCreatedAt = null;
      signerRefuses = false;

      when(() => nostrClient.connectedRelays).thenReturn(const ['wss://a']);
      when(
        () => verificationsDao.getVerification(any()),
      ).thenAnswer((_) async => null);
      when(
        () => verificationsDao.deleteVerification(any()),
      ).thenAnswer((_) async => 1);
      when(
        () => verificationsDao.upsertVerification(
          pubkey: any(named: 'pubkey'),
          verifiedClaimsJson: any(named: 'verifiedClaimsJson'),
          checkedAtFloor: any(named: 'checkedAtFloor'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => nostrClient.retryDisconnectedRelays(),
      ).thenAnswer((_) async {});
      when(
        () => nostrClient.queryEventsDetailed(
          any(),
          useCache: any(named: 'useCache'),
          requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
        ),
      ).thenAnswer(
        (_) async => (events: <Event>[], timedOut: false, noRelays: false),
      );
      when(() => nostrClient.publishEventAwaitOk(any())).thenAnswer((
        invocation,
      ) async {
        final event = invocation.positionalArguments.single as Event;
        return PublishOutcome(
          eventId: event.id,
          acceptedBy: const ['wss://relay.divine.video'],
          rejectedBy: const {},
          noResponseFrom: const [],
        );
      });
      when(
        () => identityEventsDao.upsertEvent(
          pubkey: any(named: 'pubkey'),
          tagsJson: any(named: 'tagsJson'),
          sourceKind: any(named: 'sourceKind'),
          sourceCreatedAt: any(named: 'sourceCreatedAt'),
          sourceEventId: any(named: 'sourceEventId'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => identityEventsDao.getEvent(any()),
      ).thenAnswer((_) async => null);

      repo = IdentityClaimsRepository(
        verifierClient: client,
        nostrClient: nostrClient,
        identityEventsDao: identityEventsDao,
        identityVerificationsDao: verificationsDao,
        signEvent:
            ({
              required kind,
              required content,
              required tags,
              createdAt,
            }) async {
              signedKind = kind;
              signedTags = tags;
              signedContent = content;
              signedCreatedAt = createdAt;
              if (signerRefuses) return null;
              return _event(
                id: _eventId(2),
                kind: kind,
                tags: tags,
                content: content,
                createdAt: createdAt ?? 1500,
              );
            },
      );
    });

    void stubIdentityEvents(
      List<Event> events, {
      List<Event> kind0 = const [],
    }) {
      when(
        () => nostrClient.queryEventsDetailed(
          any(),
          useCache: any(named: 'useCache'),
          requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
        ),
      ).thenAnswer((invocation) async {
        final filters = invocation.positionalArguments.single as List<Filter>;
        final matched = filters.first.kinds?.single == 10011 ? events : kind0;
        return (events: matched, timedOut: false, noRelays: false);
      });
    }

    group('claimsWithVerdicts', () {
      setUp(() {
        stubIdentityEvents([
          _event(
            id: _eventId(10),
            kind: 10011,
            tags: [
              ['i', 'github:octocat', 'abc'],
              ['i', 'twitter:jack', 'oauth'],
            ],
          ),
        ]);
      });

      test('marks the claims the verifier confirmed', () async {
        when(() => client.verifyBatch(any())).thenAnswer(
          (_) async => const [
            VerificationResult(
              platform: 'github',
              identity: 'octocat',
              verified: true,
              checkedAt: 100,
              cached: false,
            ),
            VerificationResult(
              platform: 'twitter',
              identity: 'jack',
              verified: false,
              checkedAt: 100,
              cached: false,
            ),
          ],
        );

        final status = await repo.claimsWithVerdicts(_pubkey);

        expect(status.claims, hasLength(2));
        expect(status.verifierReachable, isTrue);
        expect(status.isVerified(status.claims.first), isTrue);
        expect(status.isVerified(status.claims.last), isFalse);
      });

      test('keeps the claims visible when the verifier is down', () async {
        when(
          () => client.verifyBatch(any()),
        ).thenThrow(const VerifierNetworkException('offline'));

        final status = await repo.claimsWithVerdicts(_pubkey);

        expect(status.claims, hasLength(2));
        expect(status.verifiedKeys, isEmpty);
        expect(status.verifierReachable, isFalse);
      });
    });

    group('verifyClaim', () {
      test('checks a single claim without touching the snapshot', () async {
        const claim = IdentityClaim(
          pubkey: _pubkey,
          platform: 'github',
          identity: 'octocat',
          proof: 'abc',
        );
        when(() => client.verifySingle(claim)).thenAnswer(
          (_) async => const VerificationResult(
            platform: 'github',
            identity: 'octocat',
            verified: true,
            checkedAt: 1,
            cached: false,
          ),
        );

        final result = await repo.verifyClaim(claim);

        expect(result.verified, isTrue);
      });
    });

    group('after the app comes back from a browser round trip', () {
      test(
        'reconnects before reading instead of failing the first try',
        () async {
          // The pool does not survive the OAuth hand-off; without this the
          // first attempt after returning always reported an unreadable list
          // and only the second worked.
          var connected = <String>[];
          when(() => nostrClient.connectedRelays).thenAnswer((_) => connected);
          when(() => nostrClient.retryDisconnectedRelays()).thenAnswer((
            _,
          ) async {
            connected = const ['wss://a'];
          });
          stubIdentityEvents([
            _event(
              id: _eventId(10),
              kind: 10011,
              tags: [
                ['i', 'github:octocat', 'abc'],
              ],
            ),
          ]);

          final tags = await repo.publishClaim(
            const IdentityClaim(
              pubkey: _pubkey,
              platform: 'twitter',
              identity: 'jack',
              proof: IdentityClaim.oauthProof,
            ),
          );

          verify(() => nostrClient.retryDisconnectedRelays()).called(1);
          expect(tags, hasLength(2));
        },
      );

      test('does not reconnect when the pool is already up', () async {
        await repo.publishClaim(
          const IdentityClaim(
            pubkey: _pubkey,
            platform: 'github',
            identity: 'octocat',
            proof: 'abc',
          ),
        );

        verifyNever(() => nostrClient.retryDisconnectedRelays());
      });
    });

    group('when no relay is connected', () {
      setUp(() {
        when(() => nostrClient.connectedRelays).thenReturn(const []);
      });

      test('refuses to write even with no local evidence at all', () async {
        // This is the case that lost data: a device with no snapshot yet has
        // nothing to appeal to, so the write must be refused on the
        // connectivity fact alone.
        when(
          () => identityEventsDao.getEvent(any()),
        ).thenAnswer((_) async => null);
        when(
          () => verificationsDao.getVerification(any()),
        ).thenAnswer((_) async => null);

        await expectLater(
          () => repo.publishClaim(
            const IdentityClaim(
              pubkey: _pubkey,
              platform: 'bluesky',
              identity: 'alice.bsky.social',
              proof: IdentityClaim.oauthProof,
            ),
          ),
          throwsA(isA<IdentityClaimReadException>()),
        );
        verifyNever(() => nostrClient.publishEventAwaitOk(any()));
      });

      test('still reads, so the screen is not blanked', () async {
        when(() => identityEventsDao.getEvent(any())).thenAnswer(
          (_) async => const IdentityEventRow(
            pubkey: _pubkey,
            tagsJson: '[["i","github:octocat","abc"]]',
            sourceKind: 10011,
          ),
        );
        when(
          () => client.verifyBatch(any()),
        ).thenThrow(const VerifierNetworkException('offline'));

        final status = await repo.claimsWithVerdicts(_pubkey);

        expect(status.claims.single.platform, equals('github'));
        expect(status.verifierReachable, isFalse);
      });
    });

    group('when the identity read does not settle (#6154)', () {
      // Divine's identity events live on relay.divine.video. A general-purpose
      // relay in the pool answering EOSE with nothing used to end the read
      // before that relay replied, and the kind-0 fallback — which every
      // profile has — then reported "no claims", blanking the chips with no
      // error and no log.
      setUp(() {
        when(() => client.verifyBatch(any())).thenAnswer(
          (_) async => const [
            VerificationResult(
              platform: 'github',
              identity: 'octocat',
              verified: true,
              checkedAt: 1,
              cached: false,
            ),
          ],
        );
      });

      void stubUnsettledIdentityRead({required List<Event> kind0}) {
        when(
          () => nostrClient.queryEventsDetailed(
            any(),
            useCache: any(named: 'useCache'),
            requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
          ),
        ).thenAnswer((invocation) async {
          final filters = invocation.positionalArguments.single as List<Filter>;
          final isIdentity = filters.first.kinds?.single == 10011;
          return (
            events: isIdentity ? <Event>[] : kind0,
            timedOut: isIdentity,
            noRelays: false,
          );
        });
      }

      test(
        'asks every relay to settle before trusting an empty answer',
        () async {
          stubIdentityEvents([
            _event(
              id: _eventId(10),
              kind: 10011,
              tags: [
                ['i', 'github:octocat', 'abc'],
              ],
            ),
          ]);

          await repo.claimsWithVerdicts(_pubkey);

          final captured = verify(
            () => nostrClient.queryEventsDetailed(
              any(),
              useCache: any(named: 'useCache'),
              requireAllRelaysSettled: captureAny(
                named: 'requireAllRelaysSettled',
              ),
            ),
          ).captured;
          expect(captured, isNotEmpty);
          expect(captured.every((v) => v == true), isTrue);
        },
      );

      test(
        'falls through to kind-0 when there is no snapshot to prefer',
        () async {
          stubUnsettledIdentityRead(
            kind0: [
              _event(
                id: _eventId(12),
                tags: [
                  ['i', 'github:octocat', 'abc'],
                ],
              ),
            ],
          );
          when(
            () => identityEventsDao.getEvent(any()),
          ).thenAnswer((_) async => null);

          final status = await repo.claimsWithVerdicts(_pubkey);

          expect(status.claims, hasLength(1));
          expect(status.claims.single.platform, equals('github'));
        },
      );

      test('refuses to publish over claims it could not read', () async {
        // The write path must not treat an unsettled read as an empty one:
        // publishing on it would replace the identity event with a set that
        // predates what this device has already seen — the silent unlink the
        // other read-failure branches already refuse.
        stubUnsettledIdentityRead(kind0: [_event(id: _eventId(13))]);
        when(() => identityEventsDao.getEvent(any())).thenAnswer(
          (_) async => const IdentityEventRow(
            pubkey: _pubkey,
            tagsJson: '[["i","github:octocat","abc"]]',
            sourceKind: 10011,
          ),
        );

        await expectLater(
          () => repo.publishClaim(
            const IdentityClaim(
              pubkey: _pubkey,
              platform: 'twitter',
              identity: 'someone',
              proof: '123',
            ),
          ),
          throwsA(isA<IdentityClaimReadException>()),
        );
        verifyNever(() => nostrClient.publishEventAwaitOk(any()));
      });

      test(
        'still links a kind-0-sourced profile when the read is unsettled',
        () async {
          // The snapshot here is what the kind-0 fallback itself wrote, not
          // evidence of a lagging kind-10011 read. Refusing on it would block a
          // legitimate first link for a pre-migration profile whenever a single
          // relay failed to settle.
          stubUnsettledIdentityRead(
            kind0: [
              _event(
                id: _eventId(14),
                tags: [
                  ['i', 'github:octocat', 'abc'],
                ],
              ),
            ],
          );
          when(() => identityEventsDao.getEvent(any())).thenAnswer(
            (_) async => const IdentityEventRow(
              pubkey: _pubkey,
              tagsJson: '[["i","github:octocat","abc"]]',
              sourceKind: 0,
            ),
          );

          await repo.publishClaim(
            const IdentityClaim(
              pubkey: _pubkey,
              platform: 'twitter',
              identity: 'someone',
              proof: '123',
            ),
          );

          verify(() => nostrClient.publishEventAwaitOk(any())).called(1);
        },
      );

      test('keeps the snapshot claims instead of reporting none', () async {
        stubUnsettledIdentityRead(kind0: [_event(id: _eventId(11))]);
        when(() => identityEventsDao.getEvent(any())).thenAnswer(
          (_) async => const IdentityEventRow(
            pubkey: _pubkey,
            tagsJson: '[["i","github:octocat","abc"]]',
            sourceKind: 10011,
          ),
        );

        final status = await repo.claimsWithVerdicts(_pubkey);

        expect(status.claims, hasLength(1));
        expect(status.claims.single.platform, equals('github'));
      });
    });

    group('when only the verdict snapshot remembers the claims', () {
      test('refuses to write over them', () async {
        when(
          () => identityEventsDao.getEvent(any()),
        ).thenAnswer((_) async => null);
        when(() => verificationsDao.getVerification(any())).thenAnswer(
          (_) async => _row(
            claimsJson:
                '[{"platform":"github","identity":"octocat","proof":"abc"}]',
            checkedAtFloor: 100,
          ),
        );

        await expectLater(
          () => repo.publishClaim(
            const IdentityClaim(
              pubkey: _pubkey,
              platform: 'bluesky',
              identity: 'alice.bsky.social',
              proof: IdentityClaim.oauthProof,
            ),
          ),
          throwsA(isA<IdentityClaimReadException>()),
        );
        verifyNever(() => nostrClient.publishEventAwaitOk(any()));
      });

      test('treats an unreadable verdict snapshot as no witness', () async {
        when(
          () => identityEventsDao.getEvent(any()),
        ).thenAnswer((_) async => null);
        when(
          () => verificationsDao.getVerification(any()),
        ).thenThrow(StateError('disk on fire'));

        final tags = await repo.publishClaim(
          const IdentityClaim(
            pubkey: _pubkey,
            platform: 'github',
            identity: 'octocat',
            proof: 'abc',
          ),
        );

        expect(tags, hasLength(1));
      });

      test('publishes for a profile no witness knows anything about', () async {
        when(
          () => identityEventsDao.getEvent(any()),
        ).thenAnswer((_) async => null);
        when(
          () => verificationsDao.getVerification(any()),
        ).thenAnswer((_) async => null);

        final tags = await repo.publishClaim(
          const IdentityClaim(
            pubkey: _pubkey,
            platform: 'github',
            identity: 'octocat',
            proof: 'abc',
          ),
        );

        expect(tags, hasLength(1));
      });
    });

    group('reading when relays go quiet', () {
      setUp(() {
        when(() => identityEventsDao.getEvent(_pubkey)).thenAnswer(
          (_) async => const IdentityEventRow(
            pubkey: _pubkey,
            tagsJson:
                '[["i","github:octocat","abc"],["i","telegram:chan","chan/2"]]',
            sourceKind: 10011,
          ),
        );
      });

      test('shows the last known links instead of an empty list', () async {
        // A list that empties itself on a relay hiccup reads as "my links are
        // gone", which is worse than showing a slightly stale set.
        when(
          () => client.verifyBatch(any()),
        ).thenThrow(const VerifierNetworkException('offline'));

        final status = await repo.claimsWithVerdicts(_pubkey);

        expect(
          status.claims.map((c) => c.platform),
          equals(['github', 'telegram']),
        );
        expect(status.verifierReachable, isFalse);
      });

      test('still refuses to write over them', () async {
        await expectLater(
          () => repo.publishClaim(
            const IdentityClaim(
              pubkey: _pubkey,
              platform: 'discord',
              identity: 'someone',
              proof: 'https://discord.com/channels/1/2/3',
            ),
          ),
          throwsA(isA<IdentityClaimReadException>()),
        );
        verifyNever(() => nostrClient.publishEventAwaitOk(any()));
      });
    });

    group('supportedPlatforms', () {
      test('drops platforms the verifier cannot check', () async {
        when(() => client.fetchPlatforms()).thenAnswer(
          (_) async => const [
            VerifierPlatform(key: 'github', label: 'GitHub', supported: true),
            VerifierPlatform(
              key: 'discord',
              label: 'Discord',
              supported: false,
            ),
          ],
        );

        final platforms = await repo.supportedPlatforms();

        expect(platforms.map((p) => p.key), equals(['github']));
      });
    });

    group('resolveOAuthLaunchUri', () {
      test('delegates to the verifier client', () async {
        when(
          () => client.resolveOAuthLaunchUri(
            platform: any(named: 'platform'),
            pubkey: any(named: 'pubkey'),
            returnUrl: any(named: 'returnUrl'),
            handle: any(named: 'handle'),
          ),
        ).thenAnswer(
          (_) async => Uri.parse('https://x.com/i/oauth2/authorize'),
        );

        expect(
          await repo.resolveOAuthLaunchUri(
            platform: 'twitter',
            pubkey: _pubkey,
            returnUrl: 'https://divine.video/app/callback',
          ),
          equals(Uri.parse('https://x.com/i/oauth2/authorize')),
        );
      });

      test('passes an unavailable platform through as null', () async {
        when(
          () => client.resolveOAuthLaunchUri(
            platform: any(named: 'platform'),
            pubkey: any(named: 'pubkey'),
            returnUrl: any(named: 'returnUrl'),
            handle: any(named: 'handle'),
          ),
        ).thenAnswer((_) async => null);

        expect(
          await repo.resolveOAuthLaunchUri(
            platform: 'twitter',
            pubkey: _pubkey,
            returnUrl: 'https://divine.video/app/callback',
          ),
          isNull,
        );
      });
    });

    group('publishClaim', () {
      test('appends the claim to the existing identity event', () async {
        stubIdentityEvents([
          _event(
            id: _eventId(10),
            kind: 10011,
            tags: [
              ['i', 'github:octocat', 'https://gist.github.com/octocat/abc'],
            ],
          ),
        ]);

        final tags = await repo.publishClaim(
          const IdentityClaim(
            pubkey: _pubkey,
            platform: 'twitter',
            identity: 'jack',
            proof: IdentityClaim.oauthProof,
          ),
        );

        expect(signedKind, equals(10011));
        expect(tags, hasLength(2));
        expect(
          tags.first,
          equals([
            'i',
            'github:octocat',
            'https://gist.github.com/octocat/abc',
          ]),
        );
        expect(tags.last, equals(['i', 'twitter:jack', 'oauth']));
        expect(signedTags, equals(tags));
      });

      test('replaces a claim for the same identity, ignoring case', () async {
        stubIdentityEvents([
          _event(
            id: _eventId(10),
            kind: 10011,
            tags: [
              ['i', 'Twitter:Jack', 'https://x.com/jack/status/1'],
              ['i', 'github:octocat', 'abc'],
            ],
          ),
        ]);

        final tags = await repo.publishClaim(
          const IdentityClaim(
            pubkey: _pubkey,
            platform: 'twitter',
            identity: 'jack',
            proof: 'https://x.com/jack/status/2',
          ),
        );

        expect(tags, hasLength(2));
        expect(tags.map((t) => t[1]), isNot(contains('Twitter:Jack')));
        expect(
          tags.last,
          equals(['i', 'twitter:jack', 'https://x.com/jack/status/2']),
        );
      });

      test('carries unknown-platform tags through untouched', () async {
        stubIdentityEvents([
          _event(
            id: _eventId(10),
            kind: 10011,
            tags: [
              ['i', 'facebook:someone', 'https://example.com/proof'],
            ],
          ),
        ]);

        final tags = await repo.publishClaim(
          const IdentityClaim(
            pubkey: _pubkey,
            platform: 'github',
            identity: 'octocat',
            proof: 'abc',
          ),
        );

        expect(
          tags.first,
          equals(['i', 'facebook:someone', 'https://example.com/proof']),
        );
      });

      test('carries non-identity tags and content through untouched', () async {
        stubIdentityEvents([
          _event(
            id: _eventId(10),
            kind: 10011,
            content: 'identity event notes',
            tags: [
              ['alt', 'NIP-39 identity claims'],
              ['client', 'some-client'],
              ['i', 'github:octocat', 'abc'],
            ],
          ),
        ]);

        final tags = await repo.publishClaim(
          const IdentityClaim(
            pubkey: _pubkey,
            platform: 'twitter',
            identity: 'jack',
            proof: IdentityClaim.oauthProof,
          ),
        );

        expect(
          tags,
          equals([
            ['i', 'github:octocat', 'abc'],
            ['i', 'twitter:jack', 'oauth'],
          ]),
        );
        expect(
          signedTags,
          equals([
            ['alt', 'NIP-39 identity claims'],
            ['client', 'some-client'],
            ['i', 'github:octocat', 'abc'],
            ['i', 'twitter:jack', 'oauth'],
          ]),
        );
        expect(signedContent, equals('identity event notes'));
      });

      test('carries kind-0 i tags forward on the first write', () async {
        stubIdentityEvents(
          const [],
          kind0: [
            _event(
              id: _eventId(11),
              tags: [
                ['i', 'mastodon:mastodon.social/@alice', 'https://m.social/1'],
                ['name', 'Alice'],
              ],
            ),
          ],
        );

        final tags = await repo.publishClaim(
          const IdentityClaim(
            pubkey: _pubkey,
            platform: 'github',
            identity: 'octocat',
            proof: 'abc',
          ),
        );

        expect(tags, hasLength(2));
        expect(tags.first[1], equals('mastodon:mastodon.social/@alice'));
      });

      test('refuses to publish when the read looks incomplete', () async {
        when(() => identityEventsDao.getEvent(_pubkey)).thenAnswer(
          (_) async => const IdentityEventRow(
            pubkey: _pubkey,
            tagsJson: '[["i","twitter:jack","oauth"]]',
            sourceKind: 10011,
          ),
        );

        await expectLater(
          () => repo.publishClaim(
            const IdentityClaim(
              pubkey: _pubkey,
              platform: 'github',
              identity: 'octocat',
              proof: 'abc',
            ),
          ),
          throwsA(isA<IdentityClaimReadException>()),
        );
        verifyNever(() => nostrClient.publishEventAwaitOk(any()));
      });

      test('publishes for a profile that genuinely has no claims', () async {
        when(
          () => identityEventsDao.getEvent(_pubkey),
        ).thenAnswer((_) async => null);

        final tags = await repo.publishClaim(
          const IdentityClaim(
            pubkey: _pubkey,
            platform: 'github',
            identity: 'octocat',
            proof: 'abc',
          ),
        );

        expect(tags, hasLength(1));
      });

      test('caches the tags a live read returned', () async {
        stubIdentityEvents([
          _event(
            id: _eventId(10),
            kind: 10011,
            tags: [
              ['i', 'github:octocat', 'abc'],
            ],
          ),
        ]);

        await repo.publishClaim(
          const IdentityClaim(
            pubkey: _pubkey,
            platform: 'twitter',
            identity: 'jack',
            proof: 'oauth',
          ),
        );

        // Once on the read, once after the publish.
        verify(
          () => identityEventsDao.upsertEvent(
            pubkey: _pubkey,
            tagsJson: any(named: 'tagsJson'),
            sourceKind: 10011,
            sourceCreatedAt: any(named: 'sourceCreatedAt'),
            sourceEventId: any(named: 'sourceEventId'),
          ),
        ).called(2);
      });

      test('stamps the cache with the event the tags came from', () async {
        stubIdentityEvents([
          _event(
            id: _eventId(10),
            kind: 10011,
            createdAt: 900,
            tags: [
              ['i', 'github:octocat', 'abc'],
            ],
          ),
        ]);

        await repo.publishClaim(
          const IdentityClaim(
            pubkey: _pubkey,
            platform: 'twitter',
            identity: 'jack',
            proof: 'oauth',
          ),
        );

        verify(
          () => identityEventsDao.upsertEvent(
            pubkey: _pubkey,
            tagsJson: any(named: 'tagsJson'),
            sourceKind: 10011,
            sourceCreatedAt: 900,
            sourceEventId: _eventId(10),
          ),
        ).called(1);
        verify(
          () => identityEventsDao.upsertEvent(
            pubkey: _pubkey,
            tagsJson: any(named: 'tagsJson'),
            sourceKind: 10011,
            sourceCreatedAt: signedCreatedAt,
            sourceEventId: _eventId(2),
          ),
        ).called(1);
      });

      test('starts from an empty list when no source event exists', () async {
        final tags = await repo.publishClaim(
          const IdentityClaim(
            pubkey: _pubkey,
            platform: 'github',
            identity: 'octocat',
            proof: 'abc',
          ),
        );

        expect(
          tags,
          equals([
            ['i', 'github:octocat', 'abc'],
          ]),
        );
      });

      test('builds on the newest identity event by created_at', () async {
        stubIdentityEvents([
          _event(
            id: _eventId(10),
            kind: 10011,
            createdAt: 100,
            tags: [
              ['i', 'github:old', 'abc'],
            ],
          ),
          _event(
            id: _eventId(11),
            kind: 10011,
            createdAt: 200,
            tags: [
              ['i', 'github:new', 'abc'],
            ],
          ),
        ]);

        final tags = await repo.publishClaim(
          const IdentityClaim(
            pubkey: _pubkey,
            platform: 'twitter',
            identity: 'jack',
            proof: 'oauth',
          ),
        );

        expect(tags.first[1], equals('github:new'));
      });

      test('breaks a same-second tie on the lowest event id', () async {
        stubIdentityEvents([
          _event(
            id: _eventId(20),
            kind: 10011,
            createdAt: 100,
            tags: [
              ['i', 'github:higher', 'abc'],
            ],
          ),
          _event(
            id: _eventId(10),
            kind: 10011,
            createdAt: 100,
            tags: [
              ['i', 'github:lower', 'abc'],
            ],
          ),
        ]);

        final tags = await repo.publishClaim(
          const IdentityClaim(
            pubkey: _pubkey,
            platform: 'twitter',
            identity: 'jack',
            proof: 'oauth',
          ),
        );

        expect(tags.first[1], equals('github:lower'));
      });

      test('caches the published tags for immediate rendering', () async {
        await repo.publishClaim(
          const IdentityClaim(
            pubkey: _pubkey,
            platform: 'github',
            identity: 'octocat',
            proof: 'abc',
          ),
        );

        verify(
          () => identityEventsDao.upsertEvent(
            pubkey: _pubkey,
            tagsJson: '[["i","github:octocat","abc"]]',
            sourceKind: 10011,
            sourceCreatedAt: any(named: 'sourceCreatedAt'),
            sourceEventId: any(named: 'sourceEventId'),
          ),
        ).called(1);
      });

      test('keeps a landed publish when the cache write fails', () async {
        when(
          () => identityEventsDao.upsertEvent(
            pubkey: any(named: 'pubkey'),
            tagsJson: any(named: 'tagsJson'),
            sourceKind: any(named: 'sourceKind'),
            sourceCreatedAt: any(named: 'sourceCreatedAt'),
            sourceEventId: any(named: 'sourceEventId'),
          ),
        ).thenThrow(StateError('disk on fire'));

        final tags = await repo.publishClaim(
          const IdentityClaim(
            pubkey: _pubkey,
            platform: 'github',
            identity: 'octocat',
            proof: 'abc',
          ),
        );

        expect(tags, hasLength(1));
      });

      test('throws when the signer refuses', () async {
        signerRefuses = true;

        await expectLater(
          () => repo.publishClaim(
            const IdentityClaim(
              pubkey: _pubkey,
              platform: 'github',
              identity: 'octocat',
              proof: 'abc',
            ),
          ),
          throwsA(isA<IdentityClaimPublishException>()),
        );
        verifyNever(() => nostrClient.publishEventAwaitOk(any()));
      });

      test('throws when no relay confirms the event', () async {
        when(() => nostrClient.publishEventAwaitOk(any())).thenAnswer((
          invocation,
        ) async {
          final event = invocation.positionalArguments.single as Event;
          return PublishOutcome(
            eventId: event.id,
            acceptedBy: const [],
            rejectedBy: const {'wss://relay.divine.video': 'blocked'},
            noResponseFrom: const [],
          );
        });

        await expectLater(
          () => repo.publishClaim(
            const IdentityClaim(
              pubkey: _pubkey,
              platform: 'github',
              identity: 'octocat',
              proof: 'abc',
            ),
          ),
          throwsA(isA<IdentityClaimPublishException>()),
        );
        verifyNever(
          () => identityEventsDao.upsertEvent(
            pubkey: any(named: 'pubkey'),
            tagsJson: any(named: 'tagsJson'),
            sourceKind: any(named: 'sourceKind'),
            sourceCreatedAt: any(named: 'sourceCreatedAt'),
            sourceEventId: any(named: 'sourceEventId'),
          ),
        );
      });
    });

    group('two links added in quick succession', () {
      test('keeps the first when the relay has not caught up', () async {
        // The relay confirms a write before it necessarily serves it back.
        // Reading the stale event and publishing it would drop the claim
        // added seconds earlier — which is exactly what happened on device.
        final staleEvent = _event(
          id: _eventId(10),
          kind: 10011,
          tags: [
            ['i', 'bluesky:alice.bsky.social', 'oauth'],
          ],
        );
        stubIdentityEvents([staleEvent]);

        final afterFirst = await repo.publishClaim(
          const IdentityClaim(
            pubkey: _pubkey,
            platform: 'github',
            identity: 'octocat',
            proof: 'abc',
          ),
        );
        expect(afterFirst, hasLength(2));

        // The relay still answers with the pre-github event.
        final afterSecond = await repo.publishClaim(
          const IdentityClaim(
            pubkey: _pubkey,
            platform: 'telegram',
            identity: 'chan',
            proof: 'chan/2',
          ),
        );

        expect(
          afterSecond.map((t) => t[1]),
          containsAll(<String>[
            'bluesky:alice.bsky.social',
            'github:octocat',
            'telegram:chan',
          ]),
        );
      });

      test('keeps the first when only the kind-0 fallback answers', () async {
        // Every profile has a kind-0 metadata event, so the fallback answers
        // even when the kind-10011 read does not — the lagging-read merge has
        // to run on that branch too, or the second link publishes a base that
        // predates the first and deletes it.
        stubIdentityEvents(const [], kind0: [_event(id: _eventId(11))]);

        await repo.publishClaim(
          const IdentityClaim(
            pubkey: _pubkey,
            platform: 'github',
            identity: 'octocat',
            proof: 'abc',
          ),
        );
        final afterSecond = await repo.publishClaim(
          const IdentityClaim(
            pubkey: _pubkey,
            platform: 'telegram',
            identity: 'chan',
            proof: 'chan/2',
          ),
        );

        expect(
          afterSecond.map((t) => t[1]),
          containsAll(<String>['github:octocat', 'telegram:chan']),
        );
      });

      test(
        'refuses when the kind-0 fallback is missing a known claim',
        () async {
          // The snapshot proves a kind-10011 claim exists that this read did
          // not carry, so the read is incomplete rather than authoritative.
          stubIdentityEvents(const [], kind0: [_event(id: _eventId(11))]);
          when(() => identityEventsDao.getEvent(_pubkey)).thenAnswer(
            (_) async => const IdentityEventRow(
              pubkey: _pubkey,
              tagsJson: '[["i","twitter:jack","oauth"]]',
              sourceKind: 10011,
            ),
          );

          await expectLater(
            () => repo.publishClaim(
              const IdentityClaim(
                pubkey: _pubkey,
                platform: 'github',
                identity: 'octocat',
                proof: 'abc',
              ),
            ),
            throwsA(isA<IdentityClaimReadException>()),
          );
          verifyNever(() => nostrClient.publishEventAwaitOk(any()));
        },
      );

      test('refuses a claimless kind-0 when verdicts are on record', () async {
        stubIdentityEvents(const [], kind0: [_event(id: _eventId(11))]);
        when(() => verificationsDao.getVerification(_pubkey)).thenAnswer(
          (_) async => _row(
            claimsJson:
                '[{"platform":"twitter","identity":"jack","proof":"oauth"}]',
            checkedAtFloor: 1,
          ),
        );

        await expectLater(
          () => repo.publishClaim(
            const IdentityClaim(
              pubkey: _pubkey,
              platform: 'github',
              identity: 'octocat',
              proof: 'abc',
            ),
          ),
          throwsA(isA<IdentityClaimReadException>()),
        );
        verifyNever(() => nostrClient.publishEventAwaitOk(any()));
      });

      test('does not resurrect a claim this device just removed', () async {
        stubIdentityEvents([
          _event(
            id: _eventId(10),
            kind: 10011,
            tags: [
              ['i', 'github:octocat', 'abc'],
              ['i', 'telegram:chan', 'chan/2'],
            ],
          ),
        ]);

        await repo.removeClaim(
          const IdentityClaim(
            pubkey: _pubkey,
            platform: 'telegram',
            identity: 'chan',
            proof: 'chan/2',
          ),
        );

        // Relay still serves the pre-removal event.
        final tags = await repo.publishClaim(
          const IdentityClaim(
            pubkey: _pubkey,
            platform: 'bluesky',
            identity: 'alice.bsky.social',
            proof: IdentityClaim.oauthProof,
          ),
        );

        expect(tags.map((t) => t[1]), isNot(contains('telegram:chan')));
      });

      test(
        'accepts a newer relay event missing this device published claim',
        () async {
          stubIdentityEvents([
            _event(
              id: _eventId(10),
              kind: 10011,
              createdAt: 100,
              tags: [
                ['i', 'bluesky:alice.bsky.social', 'oauth'],
              ],
            ),
          ]);

          await repo.publishClaim(
            const IdentityClaim(
              pubkey: _pubkey,
              platform: 'github',
              identity: 'octocat',
              proof: 'abc',
            ),
          );

          stubIdentityEvents([
            _event(
              id: _eventId(11),
              kind: 10011,
              createdAt: signedCreatedAt! + 1,
              tags: [
                ['i', 'bluesky:alice.bsky.social', 'oauth'],
              ],
            ),
          ]);

          final tags = await repo.publishClaim(
            const IdentityClaim(
              pubkey: _pubkey,
              platform: 'telegram',
              identity: 'chan',
              proof: 'chan/2',
            ),
          );

          expect(tags.map((t) => t[1]), isNot(contains('github:octocat')));
          expect(
            tags.map((t) => t[1]),
            containsAll(<String>['bluesky:alice.bsky.social', 'telegram:chan']),
          );
        },
      );

      test(
        'accepts a same-second relay event that wins the id tie-break',
        () async {
          stubIdentityEvents([
            _event(
              id: _eventId(10),
              kind: 10011,
              createdAt: 100,
              tags: [
                ['i', 'bluesky:alice.bsky.social', 'oauth'],
              ],
            ),
          ]);

          await repo.publishClaim(
            const IdentityClaim(
              pubkey: _pubkey,
              platform: 'github',
              identity: 'octocat',
              proof: 'abc',
            ),
          );

          // Same created_at as the event this device published, lower id: by
          // NIP-01 that event is the replaceable one, so the read is current
          // rather than lagging and there is nothing to re-add.
          stubIdentityEvents([
            _event(
              id: _eventId(1),
              kind: 10011,
              createdAt: signedCreatedAt!,
              tags: [
                ['i', 'bluesky:alice.bsky.social', 'oauth'],
              ],
            ),
          ]);

          final tags = await repo.publishClaim(
            const IdentityClaim(
              pubkey: _pubkey,
              platform: 'telegram',
              identity: 'chan',
              proof: 'chan/2',
            ),
          );

          expect(tags.map((t) => t[1]), isNot(contains('github:octocat')));
          expect(
            tags.map((t) => t[1]),
            containsAll(<String>['bluesky:alice.bsky.social', 'telegram:chan']),
          );
        },
      );

      test(
        'accepts a newer relay event carrying a claim removed here',
        () async {
          stubIdentityEvents([
            _event(
              id: _eventId(10),
              kind: 10011,
              createdAt: 100,
              tags: [
                ['i', 'github:octocat', 'abc'],
                ['i', 'telegram:chan', 'chan/2'],
              ],
            ),
          ]);

          await repo.removeClaim(
            const IdentityClaim(
              pubkey: _pubkey,
              platform: 'telegram',
              identity: 'chan',
              proof: 'chan/2',
            ),
          );

          stubIdentityEvents([
            _event(
              id: _eventId(11),
              kind: 10011,
              createdAt: signedCreatedAt! + 1,
              tags: [
                ['i', 'github:octocat', 'abc'],
                ['i', 'telegram:chan', 'new-proof'],
              ],
            ),
          ]);

          final tags = await repo.publishClaim(
            const IdentityClaim(
              pubkey: _pubkey,
              platform: 'bluesky',
              identity: 'alice.bsky.social',
              proof: IdentityClaim.oauthProof,
            ),
          );

          expect(tags.map((t) => t[1]), contains('telegram:chan'));
        },
      );
    });

    group('when the relay serves an older revision than the snapshot', () {
      // The window #7081 closes: across an app restart nothing published in
      // this session vouches for the claim, so only the coordinates the
      // snapshot carries can tell a lagging relay apart from a real unlink.
      void stubSnapshot({
        required int sourceCreatedAt,
        required String? sourceEventId,
        String tagsJson =
            '[["i","github:octocat","abc"],["i","twitter:jack","oauth"]]',
      }) {
        when(() => identityEventsDao.getEvent(_pubkey)).thenAnswer(
          (_) async => IdentityEventRow(
            pubkey: _pubkey,
            tagsJson: tagsJson,
            sourceKind: 10011,
            sourceCreatedAt: sourceCreatedAt,
            sourceEventId: sourceEventId,
          ),
        );
      }

      void stubRelayEvent({required int createdAt, required String id}) {
        stubIdentityEvents([
          _event(
            id: id,
            kind: 10011,
            createdAt: createdAt,
            tags: [
              ['i', 'github:octocat', 'abc'],
            ],
          ),
        ]);
      }

      test('refuses to publish on it', () async {
        stubRelayEvent(createdAt: 1000, id: _eventId(10));
        stubSnapshot(sourceCreatedAt: 2000, sourceEventId: _eventId(20));

        await expectLater(
          () => repo.publishClaim(
            const IdentityClaim(
              pubkey: _pubkey,
              platform: 'bluesky',
              identity: 'alice.bsky.social',
              proof: IdentityClaim.oauthProof,
            ),
          ),
          throwsA(isA<IdentityClaimReadException>()),
        );
        verifyNever(() => nostrClient.publishEventAwaitOk(any()));
      });

      test('refuses to unlink on it', () async {
        stubRelayEvent(createdAt: 1000, id: _eventId(10));
        stubSnapshot(sourceCreatedAt: 2000, sourceEventId: _eventId(20));

        await expectLater(
          () => repo.removeClaim(
            const IdentityClaim(
              pubkey: _pubkey,
              platform: 'github',
              identity: 'octocat',
              proof: 'abc',
            ),
          ),
          throwsA(isA<IdentityClaimReadException>()),
        );
        verifyNever(() => nostrClient.publishEventAwaitOk(any()));
      });

      test('refuses a same-second event that loses the id tie-break', () async {
        stubRelayEvent(createdAt: 2000, id: _eventId(30));
        stubSnapshot(sourceCreatedAt: 2000, sourceEventId: _eventId(20));

        await expectLater(
          () => repo.publishClaim(
            const IdentityClaim(
              pubkey: _pubkey,
              platform: 'bluesky',
              identity: 'alice.bsky.social',
              proof: IdentityClaim.oauthProof,
            ),
          ),
          throwsA(isA<IdentityClaimReadException>()),
        );
      });

      test(
        'does not overwrite the snapshot with it on the read path',
        () async {
          stubRelayEvent(createdAt: 1000, id: _eventId(10));
          stubSnapshot(sourceCreatedAt: 2000, sourceEventId: _eventId(20));
          when(
            () => client.verifyBatch(any()),
          ).thenThrow(const VerifierNetworkException('offline'));

          await repo.claimsWithVerdicts(_pubkey);

          // Caching it would erase the evidence the next write checks itself
          // against, turning the refusal above into a silent unlink.
          verifyNever(
            () => identityEventsDao.upsertEvent(
              pubkey: any(named: 'pubkey'),
              tagsJson: any(named: 'tagsJson'),
              sourceKind: any(named: 'sourceKind'),
              sourceCreatedAt: any(named: 'sourceCreatedAt'),
              sourceEventId: any(named: 'sourceEventId'),
            ),
          );
        },
      );
    });

    group('when the relay serves a revision the snapshot does not have', () {
      test(
        'publishes on it, so an unlink from another device stands',
        () async {
          // The other device replaced the event, so its read is newer — the
          // guard must never turn a real remote unlink into a permanent block.
          stubIdentityEvents([
            _event(
              id: _eventId(10),
              kind: 10011,
              createdAt: 3000,
              tags: [
                ['i', 'github:octocat', 'abc'],
              ],
            ),
          ]);
          when(() => identityEventsDao.getEvent(_pubkey)).thenAnswer(
            (_) async => IdentityEventRow(
              pubkey: _pubkey,
              tagsJson:
                  '[["i","github:octocat","abc"],["i","twitter:jack","oauth"]]',
              sourceKind: 10011,
              sourceCreatedAt: 2000,
              sourceEventId: _eventId(20),
            ),
          );

          final tags = await repo.publishClaim(
            const IdentityClaim(
              pubkey: _pubkey,
              platform: 'bluesky',
              identity: 'alice.bsky.social',
              proof: IdentityClaim.oauthProof,
            ),
          );

          expect(tags.map((t) => t[1]), isNot(contains('twitter:jack')));
          expect(
            tags.map((t) => t[1]),
            containsAll(<String>[
              'github:octocat',
              'bluesky:alice.bsky.social',
            ]),
          );
        },
      );

      test('publishes when the snapshot predates the source columns', () async {
        stubIdentityEvents([
          _event(
            id: _eventId(10),
            kind: 10011,
            tags: [
              ['i', 'github:octocat', 'abc'],
            ],
          ),
        ]);
        when(() => identityEventsDao.getEvent(_pubkey)).thenAnswer(
          (_) async => const IdentityEventRow(
            pubkey: _pubkey,
            tagsJson:
                '[["i","github:octocat","abc"],["i","twitter:jack","oauth"]]',
            sourceKind: 10011,
          ),
        );

        // A row written before #7081 has nothing to compare against.
        // Blocking every write until it is restamped would be worse than the
        // window it would close.
        final tags = await repo.publishClaim(
          const IdentityClaim(
            pubkey: _pubkey,
            platform: 'bluesky',
            identity: 'alice.bsky.social',
            proof: IdentityClaim.oauthProof,
          ),
        );

        expect(tags, hasLength(2));
      });

      test(
        'keeps working against a snapshot that tracks every write',
        () async {
          // The mocked DAO otherwise forgets, which is the one thing the real
          // one never does: a second link in the same session reads its own
          // stamp back, and the guard must recognise it rather than refuse.
          IdentityEventRow? stored;
          when(
            () => identityEventsDao.upsertEvent(
              pubkey: any(named: 'pubkey'),
              tagsJson: any(named: 'tagsJson'),
              sourceKind: any(named: 'sourceKind'),
              sourceCreatedAt: any(named: 'sourceCreatedAt'),
              sourceEventId: any(named: 'sourceEventId'),
            ),
          ).thenAnswer((invocation) async {
            final named = invocation.namedArguments;
            stored = IdentityEventRow(
              pubkey: named[#pubkey] as String,
              tagsJson: named[#tagsJson] as String,
              sourceKind: named[#sourceKind] as int,
              sourceCreatedAt: named[#sourceCreatedAt] as int?,
              sourceEventId: named[#sourceEventId] as String?,
            );
          });
          when(
            () => identityEventsDao.getEvent(_pubkey),
          ).thenAnswer((_) async => stored);
          stubIdentityEvents([
            _event(
              id: _eventId(10),
              kind: 10011,
              tags: [
                ['i', 'bluesky:alice.bsky.social', 'oauth'],
              ],
            ),
          ]);

          await repo.publishClaim(
            const IdentityClaim(
              pubkey: _pubkey,
              platform: 'github',
              identity: 'octocat',
              proof: 'abc',
            ),
          );
          // The relay still answers with the pre-github event.
          final afterSecond = await repo.publishClaim(
            const IdentityClaim(
              pubkey: _pubkey,
              platform: 'telegram',
              identity: 'chan',
              proof: 'chan/2',
            ),
          );

          expect(
            afterSecond.map((t) => t[1]),
            containsAll(<String>[
              'bluesky:alice.bsky.social',
              'github:octocat',
              'telegram:chan',
            ]),
          );
        },
      );
    });

    group('dating the replacement event', () {
      // created_at is whole seconds, so a second write inside the same second
      // ties — and NIP-01 breaks a tie by lowest id, which resolves against
      // the newer event half the time. Dating past the base removes the tie
      // rather than betting on it (#7081).
      test('dates the event one second past the one it replaces', () async {
        stubIdentityEvents([
          _event(id: _eventId(10), kind: 10011, createdAt: 9999999999),
        ]);

        await repo.publishClaim(
          const IdentityClaim(
            pubkey: _pubkey,
            platform: 'github',
            identity: 'octocat',
            proof: 'abc',
          ),
        );

        expect(signedCreatedAt, 10000000000);
      });

      test('keeps the signer clock when it is already past the base', () async {
        stubIdentityEvents([
          _event(id: _eventId(10), kind: 10011),
        ]);
        final before = DateTime.now().millisecondsSinceEpoch ~/ 1000;

        await repo.publishClaim(
          const IdentityClaim(
            pubkey: _pubkey,
            platform: 'github',
            identity: 'octocat',
            proof: 'abc',
          ),
        );

        final after = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        expect(signedCreatedAt, inInclusiveRange(before, after));
      });

      test('floors from the snapshot when only kind 0 came back', () async {
        // No kind-10011 event to date past, but the snapshot still carries
        // the newest coordinates this device has seen.
        stubIdentityEvents(
          const [],
          kind0: [
            _event(
              id: _eventId(11),
              tags: [
                ['i', 'github:octocat', 'abc'],
              ],
            ),
          ],
        );
        when(() => identityEventsDao.getEvent(_pubkey)).thenAnswer(
          (_) async => IdentityEventRow(
            pubkey: _pubkey,
            tagsJson: '[["i","github:octocat","abc"]]',
            sourceKind: 10011,
            sourceCreatedAt: 9999999999,
            sourceEventId: _eventId(20),
          ),
        );

        await repo.publishClaim(
          const IdentityClaim(
            pubkey: _pubkey,
            platform: 'twitter',
            identity: 'jack',
            proof: 'oauth',
          ),
        );

        expect(signedCreatedAt, 10000000000);
      });

      test('leaves the date to the signer when nothing to supersede', () async {
        await repo.publishClaim(
          const IdentityClaim(
            pubkey: _pubkey,
            platform: 'github',
            identity: 'octocat',
            proof: 'abc',
          ),
        );

        expect(signedCreatedAt, isNull);
      });

      test('does not strand the snapshot on a same-second write', () async {
        // The lock #7081 would otherwise reintroduce: a publish that ties the
        // base and loses the id tie-break is neither mirrored nor readable
        // back, so every later write is refused as stale forever.
        IdentityEventRow? stored;
        when(
          () => identityEventsDao.upsertEvent(
            pubkey: any(named: 'pubkey'),
            tagsJson: any(named: 'tagsJson'),
            sourceKind: any(named: 'sourceKind'),
            sourceCreatedAt: any(named: 'sourceCreatedAt'),
            sourceEventId: any(named: 'sourceEventId'),
          ),
        ).thenAnswer((invocation) async {
          final named = invocation.namedArguments;
          stored = IdentityEventRow(
            pubkey: named[#pubkey] as String,
            tagsJson: named[#tagsJson] as String,
            sourceKind: named[#sourceKind] as int,
            sourceCreatedAt: named[#sourceCreatedAt] as int?,
            sourceEventId: named[#sourceEventId] as String?,
          );
        });
        when(
          () => identityEventsDao.getEvent(_pubkey),
        ).thenAnswer((_) async => stored);
        // The base is dated past this device's clock, so without the floor
        // the signer would tie it — and the signed id (…02) loses the
        // tie-break against the base's (…01).
        stubIdentityEvents([
          _event(id: _eventId(1), kind: 10011, createdAt: 9999999999),
        ]);

        await repo.publishClaim(
          const IdentityClaim(
            pubkey: _pubkey,
            platform: 'github',
            identity: 'octocat',
            proof: 'abc',
          ),
        );

        // The published event outranks the base, so the mirror lands.
        expect(stored?.sourceCreatedAt, 10000000000);
        expect(stored?.sourceEventId, _eventId(2));
        expect(stored?.tagsJson, contains('github:octocat'));

        // A relay now serving that event is not read back as stale.
        stubIdentityEvents([
          _event(
            id: _eventId(2),
            kind: 10011,
            createdAt: 10000000000,
            tags: [
              ['i', 'github:octocat', 'abc'],
            ],
          ),
        ]);

        await expectLater(
          repo.publishClaim(
            const IdentityClaim(
              pubkey: _pubkey,
              platform: 'twitter',
              identity: 'jack',
              proof: 'oauth',
            ),
          ),
          completes,
        );
      });
    });

    group('removeClaim', () {
      test('drops the matching tag and publishes the rest', () async {
        stubIdentityEvents([
          _event(
            id: _eventId(10),
            kind: 10011,
            tags: [
              ['i', 'github:octocat', 'abc'],
              ['i', 'twitter:jack', 'oauth'],
            ],
          ),
        ]);

        final tags = await repo.removeClaim(
          const IdentityClaim(
            pubkey: _pubkey,
            platform: 'twitter',
            identity: 'jack',
            proof: 'ignored',
          ),
        );

        expect(
          tags,
          equals([
            ['i', 'github:octocat', 'abc'],
          ]),
        );
        verify(() => nostrClient.publishEventAwaitOk(any())).called(1);
      });

      test('revokes the verifier OAuth cache for an oauth link', () async {
        stubIdentityEvents([
          _event(
            id: _eventId(10),
            kind: 10011,
            tags: [
              ['i', 'twitter:jack', 'oauth'],
            ],
          ),
        ]);
        when(
          () => client.oauthRevokeUrl,
        ).thenReturn('https://verifier.example/auth/oauth/revoke');
        when(
          () => client.revokeOAuth(
            platform: any(named: 'platform'),
            identity: any(named: 'identity'),
            pubkey: any(named: 'pubkey'),
            nip98Event: any(named: 'nip98Event'),
          ),
        ).thenAnswer((_) async {});

        await repo.removeClaim(
          const IdentityClaim(
            pubkey: _pubkey,
            platform: 'twitter',
            identity: 'jack',
            proof: IdentityClaim.oauthProof,
          ),
        );

        expect(signedKind, equals(27235));
        expect(
          signedTags,
          equals([
            ['u', 'https://verifier.example/auth/oauth/revoke'],
            ['method', 'POST'],
          ]),
        );
        verify(
          () => client.revokeOAuth(
            platform: 'twitter',
            identity: 'jack',
            pubkey: _pubkey,
            nip98Event: any(named: 'nip98Event'),
          ),
        ).called(1);
      });

      test('keeps the unlink when the revoke is refused', () async {
        stubIdentityEvents([
          _event(
            id: _eventId(10),
            kind: 10011,
            tags: [
              ['i', 'twitter:jack', 'oauth'],
            ],
          ),
        ]);
        when(
          () => client.oauthRevokeUrl,
        ).thenReturn('https://verifier.example/auth/oauth/revoke');
        when(
          () => client.revokeOAuth(
            platform: any(named: 'platform'),
            identity: any(named: 'identity'),
            pubkey: any(named: 'pubkey'),
            nip98Event: any(named: 'nip98Event'),
          ),
        ).thenThrow(const VerifierApiException(401, 'nope'));

        final tags = await repo.removeClaim(
          const IdentityClaim(
            pubkey: _pubkey,
            platform: 'twitter',
            identity: 'jack',
            proof: IdentityClaim.oauthProof,
          ),
        );

        expect(tags, isEmpty);
      });

      test(
        'skips the revoke when the signer refuses the NIP-98 event',
        () async {
          stubIdentityEvents([
            _event(
              id: _eventId(10),
              kind: 10011,
              tags: [
                ['i', 'twitter:jack', 'oauth'],
              ],
            ),
          ]);
          when(
            () => client.oauthRevokeUrl,
          ).thenReturn('https://verifier.example/auth/oauth/revoke');
          var signCalls = 0;
          repo = IdentityClaimsRepository(
            verifierClient: client,
            nostrClient: nostrClient,
            identityEventsDao: identityEventsDao,
            signEvent:
                ({
                  required kind,
                  required content,
                  required tags,
                  createdAt,
                }) async {
                  signCalls++;
                  // Refuse only the NIP-98 event, so the unlink still lands.
                  if (kind == 27235) return null;
                  return _event(
                    id: _eventId(2),
                    kind: kind,
                    tags: tags,
                    createdAt: createdAt ?? 1000,
                  );
                },
          );

          await repo.removeClaim(
            const IdentityClaim(
              pubkey: _pubkey,
              platform: 'twitter',
              identity: 'jack',
              proof: IdentityClaim.oauthProof,
            ),
          );

          expect(signCalls, equals(2));
          verifyNever(
            () => client.revokeOAuth(
              platform: any(named: 'platform'),
              identity: any(named: 'identity'),
              pubkey: any(named: 'pubkey'),
              nip98Event: any(named: 'nip98Event'),
            ),
          );
        },
      );

      test('does not revoke for a proof-post link', () async {
        stubIdentityEvents([
          _event(
            id: _eventId(10),
            kind: 10011,
            tags: [
              ['i', 'github:octocat', 'abc'],
            ],
          ),
        ]);

        await repo.removeClaim(
          const IdentityClaim(
            pubkey: _pubkey,
            platform: 'github',
            identity: 'octocat',
            proof: 'abc',
          ),
        );

        verifyNever(
          () => client.revokeOAuth(
            platform: any(named: 'platform'),
            identity: any(named: 'identity'),
            pubkey: any(named: 'pubkey'),
            nip98Event: any(named: 'nip98Event'),
          ),
        );
      });

      test('does not revoke for an oauth-proofed non-OAuth platform', () async {
        stubIdentityEvents([
          _event(
            id: _eventId(10),
            kind: 10011,
            tags: [
              ['i', 'github:octocat', 'oauth'],
            ],
          ),
        ]);

        await repo.removeClaim(
          const IdentityClaim(
            pubkey: _pubkey,
            platform: 'github',
            identity: 'octocat',
            proof: IdentityClaim.oauthProof,
          ),
        );

        verifyNever(
          () => client.revokeOAuth(
            platform: any(named: 'platform'),
            identity: any(named: 'identity'),
            pubkey: any(named: 'pubkey'),
            nip98Event: any(named: 'nip98Event'),
          ),
        );
      });

      test('refuses to publish over links the read did not return', () async {
        // Relays answer with nothing while the local snapshot says otherwise:
        // republishing here would drop every other claim, and reporting
        // success would make the unlink look like it worked.
        when(() => identityEventsDao.getEvent(_pubkey)).thenAnswer(
          (_) async => const IdentityEventRow(
            pubkey: _pubkey,
            tagsJson: '[["i","github:octocat","abc"]]',
            sourceKind: 10011,
          ),
        );

        await expectLater(
          () => repo.removeClaim(
            const IdentityClaim(
              pubkey: _pubkey,
              platform: 'github',
              identity: 'octocat',
              proof: 'abc',
            ),
          ),
          throwsA(isA<IdentityClaimReadException>()),
        );
        verifyNever(() => nostrClient.publishEventAwaitOk(any()));
      });

      test('publishes nothing when the claim is not on the event', () async {
        stubIdentityEvents([
          _event(
            id: _eventId(10),
            kind: 10011,
            tags: [
              ['i', 'github:octocat', 'abc'],
            ],
          ),
        ]);

        final tags = await repo.removeClaim(
          const IdentityClaim(
            pubkey: _pubkey,
            platform: 'twitter',
            identity: 'jack',
            proof: 'ignored',
          ),
        );

        expect(tags, hasLength(1));
        verifyNever(() => nostrClient.publishEventAwaitOk(any()));
      });
    });

    group('without write dependencies', () {
      test('publishClaim throws StateError', () async {
        final readOnly = IdentityClaimsRepository(verifierClient: client);

        await expectLater(
          () => readOnly.publishClaim(
            const IdentityClaim(
              pubkey: _pubkey,
              platform: 'github',
              identity: 'octocat',
              proof: 'abc',
            ),
          ),
          throwsStateError,
        );
      });

      test('removeClaim throws StateError', () async {
        final readOnly = IdentityClaimsRepository(
          verifierClient: client,
          nostrClient: nostrClient,
        );

        await expectLater(
          () => readOnly.removeClaim(
            const IdentityClaim(
              pubkey: _pubkey,
              platform: 'github',
              identity: 'octocat',
              proof: 'abc',
            ),
          ),
          throwsStateError,
        );
      });
    });

    test('treats an unreadable snapshot as no snapshot', () {
      // A corrupt or unreadable local row must not become a reason to block
      // the write — the guard only fires on positive evidence of claims.
      when(
        () => identityEventsDao.getEvent(_pubkey),
      ).thenThrow(StateError('disk on fire'));

      return expectLater(
        repo.publishClaim(
          const IdentityClaim(
            pubkey: _pubkey,
            platform: 'github',
            identity: 'octocat',
            proof: 'abc',
          ),
        ),
        completion(hasLength(1)),
      );
    });

    test('treats a corrupt snapshot row as no snapshot', () {
      // Same reasoning as an unreadable one: tags nothing can decode are not
      // evidence that this profile has claims.
      when(() => identityEventsDao.getEvent(_pubkey)).thenAnswer(
        (_) async => const IdentityEventRow(
          pubkey: _pubkey,
          tagsJson: 'not json',
          sourceKind: 10011,
        ),
      );

      return expectLater(
        repo.publishClaim(
          const IdentityClaim(
            pubkey: _pubkey,
            platform: 'github',
            identity: 'octocat',
            proof: 'abc',
          ),
        ),
        completion(hasLength(1)),
      );
    });

    test('counts a kind-0 snapshot as evidence of claims too', () {
      // Where the tags were last seen does not change the fact that this
      // profile has some, and publishing over them loses them either way.
      when(() => identityEventsDao.getEvent(_pubkey)).thenAnswer(
        (_) async => const IdentityEventRow(
          pubkey: _pubkey,
          tagsJson: '[["i","github:octocat","abc"]]',
          sourceKind: 0,
        ),
      );

      return expectLater(
        repo.publishClaim(
          const IdentityClaim(
            pubkey: _pubkey,
            platform: 'twitter',
            identity: 'jack',
            proof: 'oauth',
          ),
        ),
        throwsA(isA<IdentityClaimReadException>()),
      );
    });

    test('IdentityClaimReadException carries its message', () {
      const exception = IdentityClaimReadException('relays went quiet');

      expect(exception.toString(), contains('relays went quiet'));
    });

    test('IdentityClaimPublishException carries its message', () {
      const exception = IdentityClaimPublishException('nope');

      expect(exception.toString(), contains('nope'));
    });
  });
}

String _eventId(int seed) => seed.toString().padLeft(64, '0');

Event _event({
  required String id,
  int kind = 0,
  List<List<String>> tags = const [],
  String content = '',
  int createdAt = 1000,
}) {
  return Event.fromJson({
    'id': id,
    'pubkey': _pubkey,
    'created_at': createdAt,
    'kind': kind,
    'tags': tags,
    'content': content,
    'sig': '',
  });
}
