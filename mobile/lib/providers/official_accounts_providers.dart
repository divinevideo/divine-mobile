// ABOUTME: Riverpod providers for the protected-minor DM restriction (#176):
// ABOUTME: the discriminated NIP-05 resolver, the pin ∩ NIP-05 gate service, and
// ABOUTME: the DmSendPolicy that NIP17MessageService consults on every send.

import 'package:dm_repository/dm_repository.dart'
    show DmSendPolicy, DmSendPolicyDecision;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:openvine/blocs/dm/conversation_list/protected_minor_inbox_gate.dart';
import 'package:openvine/blocs/dm/conversation_list/protected_minor_inbox_gate_impl.dart';
import 'package:openvine/config/official_accounts.dart';
import 'package:openvine/providers/protected_minor_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/nip05_resolver.dart';
import 'package:openvine/services/official_accounts_service.dart';

/// The discriminated NIP-05 resolver (its own Dio with timeouts).
final nip05ResolverProvider = Provider<Nip05Resolver>((ref) => Nip05Resolver());

/// The pin ∩ NIP-05 gate for whether a protected minor may DM a given pubkey.
final officialAccountsServiceProvider = Provider<OfficialAccountsService>((
  ref,
) {
  return OfficialAccountsService(
    resolver: ref.watch(nip05ResolverProvider),
    prefs: ref.watch(sharedPreferencesProvider),
  );
});

/// The retired moderation key register the DM surfaces present peers against.
///
/// The shipped register is a compile-time const, so this never changes at
/// runtime; it is a provider so tests can supply every custody state and
/// exercise real widgets against them.
final retiredModerationKeysProvider = Provider<List<RetiredModerationKey>>(
  (ref) => kRetiredModerationKeys,
);

/// The resolver behind [moderationPresentationProvider], for code that is not a
/// widget (a BLoC matching on the rendered name is handed this at creation).
final moderationPresentationResolverProvider =
    Provider<ModerationPresentationResolver>((ref) {
      final retiredKeys = ref.watch(retiredModerationKeysProvider);
      return (pubkeyHex) =>
          moderationPresentationOf(pubkeyHex, retiredKeys: retiredKeys);
    });

/// How the DM surfaces present [pubkeyHex]: Divine's official name and
/// wordmark, a neutral "former moderation account", or an ordinary account.
///
/// Official branding follows recorded custody (#9963). Presentation only: the
/// safety behaviours (closed composer, withheld decline action, removal
/// policy) read [isModerationAccount] / [isRetiredModerationAccount], which do
/// not depend on custody.
final ProviderFamily<ModerationPresentation, String>
moderationPresentationProvider = Provider.autoDispose
    .family<ModerationPresentation, String>((ref, pubkeyHex) {
      return ref.watch(moderationPresentationResolverProvider)(pubkeyHex);
    });

/// The outbound-DM policy injected into [NIP17MessageService] (#176, #6416).
///
/// Two rules, in order:
///
/// A retired moderation identity is refused for everyone. Nothing reads those
/// keys, so a send there is accepted by the relay and reported as delivered
/// while reaching nobody — worst on an enforcement thread whose own copy
/// invites a reply. Terminal rather than temporary: a retired recipient can
/// never become deliverable, so the cold-start drain retains the sender's row
/// in a non-retryable state. The refusal is checked ahead of the restriction
/// branch because it applies to adults too: a protected minor may still read
/// a retired-key thread, only while nobody can sign as the key
/// ([OfficialAccountsService.isReadableByProtectedMinor]), and the send is
/// refused either way.
///
/// Otherwise, keys off [isDmRestrictedProvider]: an account is restricted
/// only when it is confirmed as a protected minor, by a trusted live
/// protected verdict or the persisted last-known protected value. An account
/// with no confirmed protected status is not restricted, including while the
/// status is unknown or loading. A restricted user may only send to an
/// account currently approved by [OfficialAccountsService] (pin ∩ live
/// NIP-05). Reads state at call time (send-time) so the decision is fresh: a
/// mid-session approval or revocation takes effect on the next send without
/// rebuilding. A send to any other recipient is blocked.
final dmSendPolicyProvider = Provider<DmSendPolicy>((ref) {
  return (String recipientPubkey) async {
    if (isRetiredModerationAccount(recipientPubkey)) {
      return DmSendPolicyDecision.terminallyBlockedRetain;
    }
    if (!ref.read(isDmRestrictedProvider)) {
      return DmSendPolicyDecision.allowed;
    }
    final approved = await ref
        .read(officialAccountsServiceProvider)
        .isApprovedMinorDmRecipient(recipientPubkey);
    if (approved) return DmSendPolicyDecision.allowed;
    return ref.read(hasConfirmedDmRestrictionProvider)
        ? DmSendPolicyDecision.terminallyBlockedDiscard
        : DmSendPolicyDecision.temporarilyBlocked;
  };
});

/// Inbound DM filter for ConversationListBloc (#176). Reads the DM-restriction
/// status live (send/receive-time) and shares the single officials service, so
/// its receive-time revalidation + verdict-change stream stay consistent.
///
/// A flip of the restriction itself (mid-session approval/revocation via
/// `refreshMinorAccountState`, dev toggle) is pushed into the gate's `changes`
/// stream by [DmRestrictionGateSync] (always mounted at the app shell), so the
/// inbox list AND the unread badge re-filter immediately instead of waiting
/// for the next DM event. The push lives in a widget rather than a provider
/// `ref.listen` because an inactive provider's listener is paused (Riverpod 3
/// activity semantics) — the badge needs the tick while no DM surface is
/// mounted.
final protectedMinorInboxGateProvider = Provider<ProtectedMinorInboxGate>((
  ref,
) {
  final gate = ProtectedMinorInboxGateImpl(
    isRestricted: () => ref.read(isDmRestrictedProvider),
    officials: ref.read(officialAccountsServiceProvider),
  );
  ref.onDispose(gate.dispose);
  return gate;
});
