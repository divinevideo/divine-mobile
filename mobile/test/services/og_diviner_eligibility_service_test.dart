// ABOUTME: Tests the compatibility service's signer-free profile read boundary.
// ABOUTME: Response reuse and request deduplication belong to the repository.

import 'package:mocktail/mocktail.dart';
import 'package:openvine/services/og_diviner_eligibility_service.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:test/test.dart';

class _Profiles extends Mock implements ProfileReader {}

void main() {
  const pubkey =
      'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789';

  group('isEligible', () {
    test('normalizes the public key before the repository read', () async {
      final profiles = _Profiles();
      when(() => profiles.isOgDiviner(pubkey)).thenAnswer((_) async => true);
      final service = OgDivinerEligibilityService(profiles: profiles);

      expect(await service.isEligible(' ${pubkey.toUpperCase()} '), isTrue);
      verify(() => profiles.isOgDiviner(pubkey)).called(1);
    });

    test('answers an empty key without a repository request', () async {
      final profiles = _Profiles();
      final service = OgDivinerEligibilityService(profiles: profiles);

      expect(await service.isEligible(''), isFalse);
      expect(await service.isEligible('   '), isFalse);
      verifyZeroInteractions(profiles);
    });

    test(
      'does not retain an answer independent of profile hydration',
      () async {
        final profiles = _Profiles();
        when(() => profiles.isOgDiviner(pubkey)).thenAnswer((_) async => true);
        final service = OgDivinerEligibilityService(profiles: profiles);
        expect(await service.isEligible(pubkey), isTrue);

        when(() => profiles.isOgDiviner(pubkey)).thenAnswer((_) async => false);
        expect(await service.isEligible(pubkey), isFalse);
      },
    );
  });
}
