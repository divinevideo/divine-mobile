// ABOUTME: Tests for RemixConsentRepository — reads a creator's account-wide
// ABOUTME: remix block from their fresh kind 0 and fails closed on any doubt.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/repositories/remix_consent_repository.dart';
import 'package:profile_repository/profile_repository.dart';

class _MockProfileRepository extends Mock implements ProfileRepository {}

void main() {
  group(RemixConsentRepository, () {
    const authorPubkey =
        'b1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';
    const otherPubkey =
        'c1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';

    late _MockProfileRepository profileRepository;
    late RemixConsentRepository repository;

    UserProfile profileWith(
      Map<String, dynamic> rawData, {
      String pubkey = authorPubkey,
    }) => UserProfile(
      pubkey: pubkey,
      rawData: rawData,
      createdAt: DateTime.utc(2026),
      eventId: 'e' * 64,
    );

    void stubRead(Future<FreshProfileRead> Function() answer) {
      when(
        () => profileRepository.readFreshProfile(
          pubkey: authorPubkey,
          requireRawKind0: true,
        ),
      ).thenAnswer((_) => answer());
    }

    void stubFresh(Future<UserProfile?> Function() answer) =>
        stubRead(() async => (profile: await answer(), conclusive: true));

    setUp(() {
      profileRepository = _MockProfileRepository();
      repository = RemixConsentRepository(
        profileRepository: profileRepository,
      );
    });

    group('consentFor', () {
      test('is blocked when the kind 0 carries a JSON false', () async {
        stubFresh(
          () async => profileWith(const {divineAllowVideoReuseKey: false}),
        );

        expect(
          await repository.consentFor(authorPubkey),
          RemixConsent.blocked,
        );
      });

      test('is allowed when the key is absent', () async {
        stubFresh(() async => profileWith(const {'name': 'alice'}));

        expect(
          await repository.consentFor(authorPubkey),
          RemixConsent.allowed,
        );
      });

      test('is allowed when the key is true', () async {
        stubFresh(
          () async => profileWith(const {divineAllowVideoReuseKey: true}),
        );

        expect(
          await repository.consentFor(authorPubkey),
          RemixConsent.allowed,
        );
      });

      test('reads the strict raw kind 0, not a cached projection', () async {
        stubFresh(() async => profileWith(const {}));

        await repository.consentFor(authorPubkey);

        verify(
          () => profileRepository.readFreshProfile(
            pubkey: authorPubkey,
            requireRawKind0: true,
          ),
        ).called(1);
      });

      test('is unknown when the fetch throws', () async {
        stubFresh(() async => throw Exception('relay down'));

        expect(
          await repository.consentFor(authorPubkey),
          RemixConsent.unknown,
        );
      });

      test('is allowed when the author confirmably has no kind 0', () async {
        stubRead(() async => (profile: null, conclusive: true));

        expect(
          await repository.consentFor(authorPubkey),
          RemixConsent.allowed,
        );
      });

      test('is unknown when the kind 0 read is inconclusive', () async {
        stubRead(() async => (profile: null, conclusive: false));

        expect(
          await repository.consentFor(authorPubkey),
          RemixConsent.unknown,
        );
      });

      test('is unknown when the profile belongs to someone else', () async {
        stubFresh(() async => profileWith(const {}, pubkey: otherPubkey));

        expect(
          await repository.consentFor(authorPubkey),
          RemixConsent.unknown,
        );
      });
    });
  });
}
