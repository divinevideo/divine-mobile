// ABOUTME: Tests for the VerificationResult model — JSON parsing.

import 'package:test/test.dart';
import 'package:verifier_client/verifier_client.dart';

void main() {
  group(VerificationResult, () {
    test('parses a verified result from JSON', () {
      final json = <String, dynamic>{
        'platform': 'github',
        'identity': 'octocat',
        'verified': true,
        'checked_at': 1700000000,
        'cached': true,
      };
      final result = VerificationResult.fromJson(json);
      expect(result.verified, isTrue);
      expect(result.platform, equals('github'));
      expect(result.identity, equals('octocat'));
      expect(result.cached, isTrue);
      expect(result.checkedAt, equals(1700000000));
      expect(result.error, isNull);
    });

    test('parses a failed result from JSON', () {
      final json = <String, dynamic>{
        'platform': 'twitter',
        'identity': 'fake',
        'verified': false,
        'error': 'proof not found',
        'checked_at': 1700000000,
        'cached': false,
      };
      final result = VerificationResult.fromJson(json);
      expect(result.verified, isFalse);
      expect(result.error, equals('proof not found'));
    });

    test('defaults cached to false when missing', () {
      final json = <String, dynamic>{
        'platform': 'github',
        'identity': 'octocat',
        'verified': true,
        'checked_at': 1700000000,
      };
      final result = VerificationResult.fromJson(json);
      expect(result.cached, isFalse);
    });

    group('code', () {
      test('parses the verifier rejection code when one is sent', () {
        final result = VerificationResult.fromJson(const {
          'platform': 'discord',
          'identity': 'alice',
          'verified': false,
          'checked_at': 1,
          'cached': false,
          'error': 'Message not found — check the message link or ID',
          'code': 'discord_message_not_found',
        });

        expect(result.code, 'discord_message_not_found');
      });

      test('is null when the verifier omits it', () {
        final result = VerificationResult.fromJson(const {
          'platform': 'discord',
          'identity': 'alice',
          'verified': false,
          'checked_at': 1,
          'cached': false,
        });

        expect(result.code, isNull);
      });

      test('is part of equality, so a changed reason is a changed result', () {
        VerificationResult withCode(String? code) => VerificationResult(
          platform: 'discord',
          identity: 'alice',
          verified: false,
          checkedAt: 1,
          cached: false,
          code: code,
        );

        expect(
          withCode('discord_bot_no_access'),
          withCode('discord_bot_no_access'),
        );
        expect(
          withCode('discord_bot_no_access'),
          isNot(withCode('discord_message_not_found')),
        );
      });
    });

    group('clean values', () {
      test('parses the clean proof and account the verifier sends', () {
        final result = VerificationResult.fromJson(const {
          'platform': 'tiktok',
          'identity': 'alice',
          'verified': true,
          'checked_at': 1,
          'cached': false,
          'canonical_proof': '7123456789012345678',
          'canonical_identity': 'alice_2',
        });

        expect(result.canonicalProof, '7123456789012345678');
        expect(result.canonicalIdentity, 'alice_2');
      });

      test('are null when the verifier omits them', () {
        final result = VerificationResult.fromJson(const {
          'platform': 'tiktok',
          'identity': 'alice',
          'verified': true,
          'checked_at': 1,
          'cached': false,
        });

        expect(result.canonicalProof, isNull);
        expect(result.canonicalIdentity, isNull);
      });

      test('treat an empty value as absent, so nothing publishes it', () {
        final result = VerificationResult.fromJson(const {
          'platform': 'tiktok',
          'identity': 'alice',
          'verified': true,
          'checked_at': 1,
          'cached': false,
          'canonical_proof': '',
          'canonical_identity': '',
        });

        expect(result.canonicalProof, isNull);
        expect(result.canonicalIdentity, isNull);
      });

      // A malformed field must not fail the parse: one bad result in a batch
      // would otherwise fail loading every claim.
      for (final (kind, wrong) in <(String, Object)>[
        ('number', 7123456789),
        ('map', <String, dynamic>{}),
      ]) {
        test('ignore a canonical_proof that is a $kind', () {
          final result = VerificationResult.fromJson({
            'platform': 'tiktok',
            'identity': 'alice',
            'verified': true,
            'checked_at': 1,
            'cached': false,
            'canonical_proof': wrong,
          });

          expect(result.canonicalProof, isNull);
        });

        test('ignore a canonical_identity that is a $kind', () {
          final result = VerificationResult.fromJson({
            'platform': 'tiktok',
            'identity': 'alice',
            'verified': true,
            'checked_at': 1,
            'cached': false,
            'canonical_identity': wrong,
          });

          expect(result.canonicalIdentity, isNull);
        });
      }

      test('are part of equality', () {
        VerificationResult withClean({String? proof, String? identity}) =>
            VerificationResult(
              platform: 'tiktok',
              identity: 'alice',
              verified: true,
              checkedAt: 1,
              cached: false,
              canonicalProof: proof,
              canonicalIdentity: identity,
            );

        expect(withClean(proof: '1'), isNot(withClean(proof: '2')));
        expect(withClean(identity: 'a'), isNot(withClean(identity: 'b')));
      });
    });
  });
}
