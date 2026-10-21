import 'dart:async';

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/nip05_verification_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/services/nip05_verification_service.dart';

void main() {
  const pubkey =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const firstClaim = Nip05Claim(pubkey: pubkey, nip05: '_@alice.divine.video');
  const secondClaim = Nip05Claim(pubkey: pubkey, nip05: '_@bob.divine.video');
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.test(NativeDatabase.memory());
  });
  tearDown(() => database.close());

  group('NIP-05 claim verification', () {
    test(
      'a changed claim stays unverified until its own validation finishes',
      () async {
        final secondValidation = Completer<bool>();
        final service = Nip05VerificationService(
          database.nip05VerificationsDao,
          validator: (nip05, _) async =>
              nip05 == firstClaim.nip05 ? true : secondValidation.future,
          batchDebounceDuration: Duration.zero,
        );
        addTearDown(service.dispose);
        final container = ProviderContainer(
          overrides: [
            nip05VerificationServiceProvider.overrideWithValue(service),
          ],
        );
        addTearDown(container.dispose);

        expect(
          await container.read(
            nip05ClaimVerificationProvider(firstClaim).future,
          ),
          Nip05VerificationStatus.verified,
        );
        final second = container.read(
          nip05ClaimVerificationProvider(secondClaim).future,
        );
        await pumpEventQueue();
        expect(
          container.read(nip05ClaimVerificationProvider(secondClaim)).isLoading,
          isTrue,
        );
        expect(
          service.getCachedStatus(pubkey, secondClaim.nip05),
          Nip05VerificationStatus.pending,
        );

        secondValidation.complete(false);
        expect(await second, Nip05VerificationStatus.failed);
      },
    );

    test('profile verification rechecks a changed kind-0 claim', () async {
      final claims = StreamController<UserProfile?>();
      addTearDown(claims.close);
      final validatedClaims = <String>[];
      final service = Nip05VerificationService(
        database.nip05VerificationsDao,
        validator: (nip05, _) async {
          validatedClaims.add(nip05);
          return nip05 == firstClaim.nip05;
        },
        batchDebounceDuration: Duration.zero,
      );
      addTearDown(service.dispose);
      final container = ProviderContainer(
        overrides: [
          nip05VerificationServiceProvider.overrideWithValue(service),
          userProfileReactiveProvider(pubkey)
              .overrideWith((ref) => claims.stream),
        ],
      );
      addTearDown(container.dispose);
      container.listen(nip05VerificationProvider(pubkey), (_, _) {});

      UserProfile profileFor(Nip05Claim claim) => UserProfile(
        pubkey: pubkey,
        nip05: claim.nip05,
        rawData: const {},
        createdAt: DateTime(2026),
        eventId: (claim == firstClaim ? 'c' : 'd') * 64,
      );

      claims.add(profileFor(firstClaim));
      await pumpEventQueue();
      expect(
        await container.read(nip05VerificationProvider(pubkey).future),
        Nip05VerificationStatus.verified,
      );

      claims.add(profileFor(secondClaim));
      await pumpEventQueue();
      expect(
        await container.read(nip05VerificationProvider(pubkey).future),
        Nip05VerificationStatus.failed,
      );
      expect(validatedClaims, [firstClaim.nip05, secondClaim.nip05]);
    });
  });
}
