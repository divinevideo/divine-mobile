// ABOUTME: Tests for OfficialAccountsService (#176) — pin ∩ NIP-05 with graded
// ABOUTME: revocation, 1h TTL, 5-min absence recheck, and persistent last-known.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/config/official_accounts.dart';
import 'package:openvine/services/nip05_resolver.dart';
import 'package:openvine/services/official_accounts_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockResolver extends Mock implements Nip05Resolver {}

void main() {
  const modHex =
      '8fd5eb6d8f362163bc00a5ab6b4a3167dbf32d00ec4efdbcf43b3c9514433b7e';
  const strangerHex =
      'deadbeef00000000000000000000000000000000000000000000000000000000';
  const attackerHex =
      '1111111111111111111111111111111111111111111111111111111111111111';

  late _MockResolver resolver;
  late SharedPreferences prefs;
  DateTime clock = DateTime(2026, 7, 7, 12);

  setUp(() async {
    resolver = _MockResolver();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    clock = DateTime(2026, 7, 7, 12);
  });

  OfficialAccountsService build({
    List<OfficialAccount>? accounts,
    List<RetiredModerationKey>? retiredKeys,
  }) => OfficialAccountsService(
    resolver: resolver,
    prefs: prefs,
    now: () => clock,
    accounts: accounts,
    retiredKeys: retiredKeys,
  );

  const modNip05 = 'moderation@divine.video';

  group('isReadableByProtectedMinor', () {
    // #7850. `DmRepository`'s removal policy protects a retired-key moderation
    // thread, because `isModerationAccount` counts retired keys. The minor
    // gate approved pinned accounts only, so that same thread was stripped
    // from the inbox, from Message Requests and from the blocked slice —
    // undeletable and unreadable at once.
    final retiredModHex = kLegacyModerationPubkeys.first;

    test('reads a retired moderation thread the send gate still refuses', () {
      final svc = build();

      expect(svc.isReadableByProtectedMinor(retiredModHex), isTrue);
      // The send gate is deliberately untouched: a retired key is readable but
      // never reachable, and the composer stays closed for it independently.
      expect(svc.isApprovedMinorDmRecipientSync(retiredModHex), isFalse);
      expect(svc.isPinnedMinorContactable(retiredModHex), isFalse);
    });

    test('still refuses a stranger', () {
      final svc = build();

      expect(svc.isReadableByProtectedMinor(strangerHex), isFalse);
      expect(svc.isReadableByProtectedMinor(attackerHex), isFalse);
    });

    test('still reads the current moderation account', () {
      final svc = build();

      expect(svc.isReadableByProtectedMinor(modHex), isTrue);
    });

    test('normalizes hex the same way the pin does', () {
      final svc = build();

      expect(
        svc.isReadableByProtectedMinor('  ${retiredModHex.toUpperCase()}  '),
        isTrue,
      );
    });

    // support-trust-safety retirement procedure, step 10: the widening rests
    // on nobody being able to sign as the key.
    for (final custody in [
      RetiredKeyCustody.unrecovered,
      RetiredKeyCustody.destroyed,
    ]) {
      test('reads a retired thread nobody can sign into ($custody)', () {
        final svc = build(
          retiredKeys: [
            RetiredModerationKey(pubkeyHex: strangerHex, custody: custody),
          ],
        );

        expect(svc.isReadableByProtectedMinor(strangerHex), isTrue);
      });
    }

    for (final custody in [
      RetiredKeyCustody.archived,
      RetiredKeyCustody.compromised,
    ]) {
      test('hides a retired thread someone can still sign into ($custody)', () {
        final svc = build(
          retiredKeys: [
            RetiredModerationKey(pubkeyHex: strangerHex, custody: custody),
          ],
        );

        expect(svc.isReadableByProtectedMinor(strangerHex), isFalse);
      });
    }
  });

  group('isApprovedMinorDmRecipient', () {
    test('unpinned pubkey is never an approved recipient', () async {
      final svc = build();
      expect(svc.isPinnedMinorContactable(strangerHex), isFalse);
      expect(svc.isApprovedMinorDmRecipientSync(strangerHex), isFalse);
      expect(await svc.isApprovedMinorDmRecipient(strangerHex), isFalse);
      verifyNever(() => resolver.resolve(any(), any()));
    });

    test(
      'pinned but not minorContactable is rejected without a network call',
      () async {
        final svc = build(
          accounts: const [
            OfficialAccount(
              pubkeyHex: modHex,
              nip05: modNip05,
              role: 'moderation',
              minorContactable: false,
            ),
          ],
        );
        expect(svc.isPinnedMinorContactable(modHex), isFalse);
        expect(await svc.isApprovedMinorDmRecipient(modHex), isFalse);
        verifyNever(() => resolver.resolve(any(), any()));
      },
    );

    test('Divine HQ is not an approved minor DM recipient', () async {
      final svc = build();

      expect(svc.isPinnedMinorContactable(kHqPubkeyHex), isFalse);
      expect(await svc.isApprovedMinorDmRecipient(kHqPubkeyHex), isFalse);
      verifyNever(() => resolver.resolve(any(), any()));
    });

    test('pinned + NIP-05 matches -> approved', () async {
      when(
        () => resolver.resolve(modNip05, modHex),
      ).thenAnswer((_) async => const Nip05Resolution.matched(modHex));

      final svc = build();
      expect(await svc.isApprovedMinorDmRecipient(modHex), isTrue);
    });

    test(
      'pinned but NIP-05 resolves to a DIFFERENT key -> dropped immediately and persisted',
      () async {
        when(() => resolver.resolve(modNip05, modHex)).thenAnswer(
          (_) async => const Nip05Resolution.differentKey(attackerHex),
        );

        final svc = build();
        expect(await svc.isApprovedMinorDmRecipient(modHex), isFalse);
        // persisted revoked: the sync hot path now rejects without re-resolving
        expect(svc.isApprovedMinorDmRecipientSync(modHex), isFalse);
      },
    );

    test('a single absence never drops (keeps last-known approved)', () async {
      when(
        () => resolver.resolve(modNip05, modHex),
      ).thenAnswer((_) async => const Nip05Resolution.absent());

      final svc = build();
      expect(await svc.isApprovedMinorDmRecipient(modHex), isTrue);
      expect(svc.isApprovedMinorDmRecipientSync(modHex), isTrue);
    });

    test(
      'absence within the recheck window does not re-resolve or drop',
      () async {
        when(
          () => resolver.resolve(modNip05, modHex),
        ).thenAnswer((_) async => const Nip05Resolution.absent());

        final svc = build();
        expect(await svc.isApprovedMinorDmRecipient(modHex), isTrue);
        clock = clock.add(const Duration(minutes: 2));
        expect(await svc.isApprovedMinorDmRecipient(modHex), isTrue);
        verify(() => resolver.resolve(modNip05, modHex)).called(1);
      },
    );

    test(
      'a confirming absence after the recheck window drops and persists',
      () async {
        when(
          () => resolver.resolve(modNip05, modHex),
        ).thenAnswer((_) async => const Nip05Resolution.absent());

        final svc = build();
        expect(await svc.isApprovedMinorDmRecipient(modHex), isTrue);
        clock = clock.add(const Duration(minutes: 6));
        expect(await svc.isApprovedMinorDmRecipient(modHex), isFalse);
        expect(svc.isApprovedMinorDmRecipientSync(modHex), isFalse);
      },
    );

    test('absence recovers if a later resolution matches again', () async {
      final answers = <Nip05Resolution>[
        const Nip05Resolution.absent(),
        const Nip05Resolution.matched(modHex),
      ];
      var i = 0;
      when(
        () => resolver.resolve(modNip05, modHex),
      ).thenAnswer((_) async => answers[i++]);

      final svc = build();
      expect(await svc.isApprovedMinorDmRecipient(modHex), isTrue);
      clock = clock.add(const Duration(minutes: 6));
      expect(await svc.isApprovedMinorDmRecipient(modHex), isTrue);
      expect(svc.isApprovedMinorDmRecipientSync(modHex), isTrue);
    });

    test('networkError keeps a previously revoked verdict', () async {
      final answers = <Nip05Resolution>[
        const Nip05Resolution.differentKey(attackerHex),
        const Nip05Resolution.networkError(),
      ];
      var i = 0;
      when(
        () => resolver.resolve(modNip05, modHex),
      ).thenAnswer((_) async => answers[i++]);

      final svc = build();
      expect(await svc.isApprovedMinorDmRecipient(modHex), isFalse);
      clock = clock.add(const Duration(hours: 2));
      expect(await svc.isApprovedMinorDmRecipient(modHex), isFalse);
    });

    test(
      'networkError with no record defaults to pin-trusted and retries',
      () async {
        when(
          () => resolver.resolve(modNip05, modHex),
        ).thenAnswer((_) async => const Nip05Resolution.networkError());

        final svc = build();
        expect(await svc.isApprovedMinorDmRecipient(modHex), isTrue);
        // nothing cached -> the next call resolves again rather than trusting a non-answer
        expect(await svc.isApprovedMinorDmRecipient(modHex), isTrue);
        verify(() => resolver.resolve(modNip05, modHex)).called(2);
      },
    );

    test('a fresh verdict is reused without re-resolving (TTL)', () async {
      when(
        () => resolver.resolve(modNip05, modHex),
      ).thenAnswer((_) async => const Nip05Resolution.matched(modHex));

      final svc = build();
      expect(await svc.isApprovedMinorDmRecipient(modHex), isTrue);
      clock = clock.add(const Duration(minutes: 30));
      expect(await svc.isApprovedMinorDmRecipient(modHex), isTrue);
      verify(() => resolver.resolve(modNip05, modHex)).called(1);
    });

    test(
      'a stale verdict triggers a fresh resolution (send-time freshness)',
      () async {
        when(
          () => resolver.resolve(modNip05, modHex),
        ).thenAnswer((_) async => const Nip05Resolution.matched(modHex));

        final svc = build();
        expect(await svc.isApprovedMinorDmRecipient(modHex), isTrue);
        clock = clock.add(const Duration(hours: 2));
        expect(await svc.isApprovedMinorDmRecipient(modHex), isTrue);
        verify(() => resolver.resolve(modNip05, modHex)).called(2);
      },
    );

    test(
      'moderation account is approved by the shipped policy',
      () async {
        when(
          () => resolver.resolve('moderation@divine.video', modHex),
        ).thenAnswer((_) async => const Nip05Resolution.matched(modHex));

        final svc = build();
        expect(svc.isPinnedMinorContactable(modHex), isTrue);
        expect(await svc.isApprovedMinorDmRecipient(modHex), isTrue);
      },
    );

    test(
      'caller hex is normalized (mixed-case + surrounding whitespace)',
      () async {
        when(
          () => resolver.resolve(modNip05, modHex),
        ).thenAnswer((_) async => const Nip05Resolution.matched(modHex));

        final svc = build();
        final messy = '  ${modHex.toUpperCase()}\n';
        expect(svc.isPinnedMinorContactable(messy), isTrue);
        expect(await svc.isApprovedMinorDmRecipient(messy), isTrue);
      },
    );

    test(
      'empty or whitespace hex is rejected without a network call',
      () async {
        final svc = build();
        expect(await svc.isApprovedMinorDmRecipient('   '), isFalse);
        expect(await svc.isApprovedMinorDmRecipient(''), isFalse);
        verifyNever(() => resolver.resolve(any(), any()));
      },
    );

    test(
      'a revoked account re-approves when a later resolution matches again',
      () async {
        final answers = <Nip05Resolution>[
          const Nip05Resolution.differentKey(attackerHex),
          const Nip05Resolution.matched(modHex),
        ];
        var i = 0;
        when(
          () => resolver.resolve(modNip05, modHex),
        ).thenAnswer((_) async => answers[i++]);

        final svc = build();
        expect(await svc.isApprovedMinorDmRecipient(modHex), isFalse);
        clock = clock.add(const Duration(hours: 2));
        expect(await svc.isApprovedMinorDmRecipient(modHex), isTrue);
        expect(svc.isApprovedMinorDmRecipientSync(modHex), isTrue);
      },
    );

    test(
      'a networkError between absences does not reset the confirming-recheck clock',
      () async {
        final answers = <Nip05Resolution>[
          const Nip05Resolution.absent(),
          const Nip05Resolution.networkError(),
          const Nip05Resolution.absent(),
        ];
        var i = 0;
        when(
          () => resolver.resolve(modNip05, modHex),
        ).thenAnswer((_) async => answers[i++]);

        final svc = build();
        expect(
          await svc.isApprovedMinorDmRecipient(modHex),
          isTrue,
        ); // absence #1
        clock = clock.add(const Duration(minutes: 6));
        expect(
          await svc.isApprovedMinorDmRecipient(modHex),
          isTrue,
        ); // networkError
        clock = clock.add(const Duration(minutes: 1));
        // firstAbsentAt preserved from #1, so this confirming absence (>5m later) drops
        expect(await svc.isApprovedMinorDmRecipient(modHex), isFalse);
      },
    );
  });

  group('onVerdictChanged', () {
    test('onVerdictChanged fires when a verdict flips to revoked', () async {
      when(() => resolver.resolve(modNip05, modHex)).thenAnswer(
        (_) async => const Nip05Resolution.differentKey(attackerHex),
      );
      final svc = build();
      addTearDown(svc.dispose);
      final fired = <void>[];
      final sub = svc.onVerdictChanged.listen(fired.add);
      addTearDown(sub.cancel);

      await svc.isApprovedMinorDmRecipient(modHex);
      await pumpEventQueue();

      expect(fired, hasLength(1));
    });

    test(
      'onVerdictChanged does not fire when a resolution confirms the verdict',
      () async {
        when(
          () => resolver.resolve(modNip05, modHex),
        ).thenAnswer((_) async => const Nip05Resolution.matched(modHex));
        final svc = build();
        addTearDown(svc.dispose);
        final fired = <void>[];
        final sub = svc.onVerdictChanged.listen(fired.add);
        addTearDown(sub.cancel);

        // matched == the pin-trusted default (approved), so no observable flip.
        await svc.isApprovedMinorDmRecipient(modHex);
        await pumpEventQueue();

        expect(fired, isEmpty);
      },
    );
  });
}
