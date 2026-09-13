// ABOUTME: Tests NIP-05 cache persistence, batching, and status transitions.
// ABOUTME: Injects validation so tests are deterministic and network-free.

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/nip05_verification_service.dart';

void main() {
  group(Nip05VerificationService, () {
    late AppDatabase database;
    late Nip05VerificationsDao dao;

    setUp(() {
      database = AppDatabase.test(NativeDatabase.memory());
      dao = database.nip05VerificationsDao;
    });

    tearDown(() => database.close());

    test('returns none without a claimed identifier', () async {
      final service = Nip05VerificationService(dao);
      addTearDown(service.dispose);

      expect(
        await service.getVerificationStatus('a' * 64, null),
        Nip05VerificationStatus.none,
      );
      expect(
        await service.getVerificationStatus('a' * 64, ''),
        Nip05VerificationStatus.none,
      );
    });

    test('loads a valid persisted status into memory', () async {
      final pubkey = 'b' * 64;
      await dao.upsertVerification(
        pubkey: pubkey,
        nip05: 'alice@example.com',
        status: 'verified',
      );
      final service = Nip05VerificationService(dao);
      addTearDown(service.dispose);

      final status = await service.getVerificationStatus(
        pubkey,
        'alice@example.com',
      );

      expect(status, Nip05VerificationStatus.verified);
      expect(service.getCachedStatus(pubkey), status);
    });

    test('batches and deduplicates verification for one pubkey', () async {
      final pubkey = 'c' * 64;
      var validations = 0;
      final service = Nip05VerificationService(
        dao,
        validator: (nip05, candidate) async {
          validations += 1;
          expect(nip05, 'alice@example.com');
          expect(candidate, pubkey);
          return true;
        },
        batchDebounceDuration: Duration.zero,
      );
      addTearDown(service.dispose);

      final first = service.getVerificationStatus(pubkey, 'alice@example.com');
      final second = service.getVerificationStatus(pubkey, 'alice@example.com');
      await pumpEventQueue();
      expect(
        service.getCachedStatus(pubkey),
        anyOf(
          Nip05VerificationStatus.pending,
          Nip05VerificationStatus.verified,
        ),
      );

      expect(await first, Nip05VerificationStatus.verified);
      expect(await second, Nip05VerificationStatus.verified);
      expect(validations, 1);
    });

    test(
      'persists a failed validation for the next service instance',
      () async {
        final pubkey = 'd' * 64;
        final service = Nip05VerificationService(
          dao,
          validator: (_, _) async => false,
          batchDebounceDuration: Duration.zero,
        );
        addTearDown(service.dispose);

        final result = await service.getVerificationStatus(
          pubkey,
          'alice@example.com',
        );

        expect(result, Nip05VerificationStatus.failed);
        expect(
          await dao.getValidVerification(pubkey),
          isA<Nip05VerificationRow>().having(
            (row) => row.status,
            'status',
            'failed',
          ),
        );
      },
    );

    test('clearAll removes memory and persistent cache', () async {
      final pubkey = 'e' * 64;
      await dao.upsertVerification(
        pubkey: pubkey,
        nip05: 'alice@example.com',
        status: 'error',
      );
      final service = Nip05VerificationService(dao);
      addTearDown(service.dispose);
      await service.preloadFromCache([pubkey]);
      expect(service.getCachedStatus(pubkey), Nip05VerificationStatus.error);

      await service.clearAll();

      expect(service.getCachedStatus(pubkey), isNull);
      expect(await dao.getVerification(pubkey), isNull);
    });
  });
}
