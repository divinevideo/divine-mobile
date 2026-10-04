// ABOUTME: Tests the outbound DM send policy — the app-level composition
// ABOUTME: (retired-moderation refusal, then DM restriction ∩ approved
// ABOUTME: official) injected into NIP17MessageService as a DmSendPolicy.

import 'dart:async';

import 'package:dm_repository/dm_repository.dart' show DmSendPolicyDecision;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/config/official_accounts.dart';
import 'package:openvine/models/protected_minor_status.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/official_accounts_providers.dart';
import 'package:openvine/providers/protected_minor_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/official_accounts_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockOfficials extends Mock implements OfficialAccountsService {}

class _MockAuthService extends Mock implements AuthService {}

void main() {
  const strangerHex =
      'deadbeef00000000000000000000000000000000000000000000000000000000';

  late _MockOfficials officials;

  setUp(() {
    officials = _MockOfficials();
  });

  ProviderContainer containerWith({required bool isRestricted}) {
    final container = ProviderContainer(
      overrides: [
        isDmRestrictedProvider.overrideWithValue(isRestricted),
        hasConfirmedDmRestrictionProvider.overrideWithValue(isRestricted),
        officialAccountsServiceProvider.overrideWithValue(officials),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('dmSendPolicyProvider', () {
    test(
      'an unrestricted user may send to anyone; officials not consulted',
      () async {
        final container = containerWith(isRestricted: false);
        final policy = container.read(dmSendPolicyProvider);

        expect(await policy(strangerHex), DmSendPolicyDecision.allowed);
        verifyNever(() => officials.isApprovedMinorDmRecipient(any()));
      },
    );
  });

  // #6416. Nothing has read a retired moderation key since the rotation, so an
  // appeal typed into one of those threads was gift-wrapped, published, and
  // reported as delivered while reaching nobody. These four fail on `main`,
  // where the policy returns `allowed` for every non-restricted user.
  group('a retired moderation recipient', () {
    test('is terminally blocked for an unrestricted adult', () async {
      expect(kLegacyModerationPubkeys, isNotEmpty);
      final container = containerWith(isRestricted: false);
      final policy = container.read(dmSendPolicyProvider);

      for (final retired in kLegacyModerationPubkeys) {
        expect(
          await policy(retired),
          DmSendPolicyDecision.terminallyBlockedRetain,
          reason: 'retired key $retired must never be a send target',
        );
      }
    });

    // Run restricted so the assertion has something to catch: without the
    // retired check the restricted branch reaches the officials service, so
    // `verifyNever` here is only satisfied by short-circuiting first.
    test('short-circuits ahead of the officials service', () async {
      when(
        () => officials.isApprovedMinorDmRecipient(any()),
      ).thenAnswer((_) async => false);
      final container = containerWith(isRestricted: true);

      await container.read(dmSendPolicyProvider)(
        kLegacyModerationPubkeys.first,
      );

      verifyNever(() => officials.isApprovedMinorDmRecipient(any()));
    });

    test('stays blocked for a restricted minor', () async {
      when(
        () => officials.isApprovedMinorDmRecipient(any()),
      ).thenAnswer((_) async => true);
      final container = containerWith(isRestricted: true);

      final decision = await container.read(dmSendPolicyProvider)(
        kLegacyModerationPubkeys.first,
      );

      expect(
        decision,
        DmSendPolicyDecision.terminallyBlockedRetain,
        reason: 'a stubbed approval must not reopen a retired identity',
      );
    });
  });

  // The other half of the same predicate: closing the retired key must not
  // close the live support lane.
  group('dmSendPolicyProvider', () {
    test('the current moderation key stays sendable', () async {
      final container = containerWith(isRestricted: false);

      expect(
        await container.read(dmSendPolicyProvider)(kModerationPubkeyHex),
        DmSendPolicyDecision.allowed,
      );
    });

    test('a restricted user may send to an approved official', () async {
      when(
        () => officials.isApprovedMinorDmRecipient(kModerationPubkeyHex),
      ).thenAnswer((_) async => true);
      final container = containerWith(isRestricted: true);
      final policy = container.read(dmSendPolicyProvider);

      expect(
        await policy(kModerationPubkeyHex),
        DmSendPolicyDecision.allowed,
      );
    });

    test(
      'a restricted user may not send to a non-approved recipient',
      () async {
        when(
          () => officials.isApprovedMinorDmRecipient(strangerHex),
        ).thenAnswer((_) async => false);
        final container = containerWith(isRestricted: true);
        final policy = container.read(dmSendPolicyProvider);

        expect(
          await policy(strangerHex),
          DmSendPolicyDecision.terminallyBlockedDiscard,
        );
      },
    );

    test(
      'an unresolved status without a Greenlight designation allows DMs',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final authService = _MockAuthService();
        when(() => authService.currentPublicKeyHex).thenReturn('a' * 64);
        when(
          () => authService.authenticationSource,
        ).thenReturn(AuthenticationSource.divineOAuth);
        final container = ProviderContainer(
          overrides: [
            currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
            sharedPreferencesProvider.overrideWithValue(prefs),
            authServiceProvider.overrideWithValue(authService),
            // Keycast never answers (startup, outage, or missing token).
            protectedMinorStatusProvider.overrideWith(
              (ref) => Completer<ProtectedMinorStatus>().future,
            ),
            officialAccountsServiceProvider.overrideWithValue(officials),
          ],
        );
        addTearDown(container.dispose);
        final policy = container.read(dmSendPolicyProvider);

        expect(
          await policy(strangerHex),
          DmSendPolicyDecision.allowed,
          reason: 'no affirmative Greenlight designation exists',
        );
        verifyNever(() => officials.isApprovedMinorDmRecipient(any()));
      },
    );

    test(
      'unknown status does not manufacture a temporary policy block',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final authService = _MockAuthService();
        when(() => authService.currentPublicKeyHex).thenReturn('a' * 64);
        when(
          () => authService.authenticationSource,
        ).thenReturn(AuthenticationSource.divineOAuth);
        final container = ProviderContainer(
          overrides: [
            currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
            sharedPreferencesProvider.overrideWithValue(prefs),
            authServiceProvider.overrideWithValue(authService),
            protectedMinorStatusProvider.overrideWith(
              (ref) => Completer<ProtectedMinorStatus>().future,
            ),
            officialAccountsServiceProvider.overrideWithValue(officials),
          ],
        );
        addTearDown(container.dispose);

        final decision = await container.read(dmSendPolicyProvider)(
          strangerHex,
        );

        expect(decision, DmSendPolicyDecision.allowed);
        verifyNever(() => officials.isApprovedMinorDmRecipient(any()));
      },
    );
  });
}
