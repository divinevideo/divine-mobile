// ABOUTME: Shipped identities Divine treats as its own: the pinned accounts a
// ABOUTME: protected minor (13-15) may DM (#176), and the team pubkeys that carry
// ABOUTME: the profile checkmark. Pinned accounts keep NIP-05 as a revocation
// ABOUTME: lever; checkmark-only entries are release-gated.

import 'package:openvine/models/moderation_presentation.dart';

export 'package:openvine/models/moderation_presentation.dart';

/// One pinned official account. `pubkeyHex` is the shipped identity; `nip05` is
/// the canonical identifier whose live resolution must still map back to
/// `pubkeyHex` for the account to count as reachable (revocation lever).
class OfficialAccount {
  final String pubkeyHex;
  final String nip05;
  final String role;

  /// Whether a protected minor may exchange DMs with this account. A pinned
  /// account that is not `minorContactable` is still official but off-limits to
  /// minors (leaves room for the #178 parent-approved-allowlist shape).
  final bool minorContactable;

  const OfficialAccount({
    required this.pubkeyHex,
    required this.nip05,
    required this.role,
    required this.minorContactable,
  });
}

/// Values [OfficialAccount.role] can take. Named so no caller has to spell the
/// role as a bare string to pick an account out of [kPinnedOfficialAccounts].
abstract class OfficialAccountRole {
  static const String hq = 'hq';
  static const String moderation = 'moderation';
}

/// The Divine HQ pubkey — the pinned identity below and the HQ entry in
/// [kDivineTeamPubkeys].
///
/// Single-sourced for the same reason as [kModerationPubkeyHex]: a second copy
/// would let the checkmark and the protected-minor pin drift onto different
/// keys.
const String kHqPubkeyHex =
    'c4a39f1291291d452405cd8ddd798c4a29a3858c52cd0d843f1f6852cf17682e';

/// Divine HQ's pinned identity.
const OfficialAccount kHqAccount = OfficialAccount(
  pubkeyHex: kHqPubkeyHex,
  nip05: '_@divinehq.divine.video',
  role: OfficialAccountRole.hq,
  minorContactable: false,
);

/// The current Divine moderation pubkey — the report target, the pinned support
/// row's destination, and `ModerationLabelService`'s NIP-05 fallback.
///
/// Single-sourced here rather than re-declared per consumer: the pinned support
/// row and the protected-minor gate must anchor on the SAME key, or the row can
/// point somewhere the gate would not approve.
const String kModerationPubkeyHex =
    '8fd5eb6d8f362163bc00a5ab6b4a3167dbf32d00ec4efdbcf43b3c9514433b7e';

/// Canonical NIP-05 identifier for [kModerationPubkeyHex]. Live resolution must
/// still map back to that pubkey for the account to count as reachable.
const String kModerationNip05 = 'moderation@divine.video';

/// The Divine moderation account's pinned identity.
const OfficialAccount kModerationAccount = OfficialAccount(
  pubkeyHex: kModerationPubkeyHex,
  nip05: kModerationNip05,
  role: OfficialAccountRole.moderation,
  minorContactable: true,
);

/// The pinned child-contactable set (verified live 2026-07-07). Additions are
/// release-gated by design — this is a child-contact list, and requiring an app
/// release to add a key is the accepted friction that makes the pin an
/// attacker-addition barrier. Each entry pins its OWN canonical identifier form
/// (HQ uses a subdomain origin, moderation the classic form).
const List<OfficialAccount> kPinnedOfficialAccounts = [
  kHqAccount,
  kModerationAccount,
];

/// The Divine team and Divine's own accounts, by pubkey. Drives the profile
/// checkmark.
///
/// Pubkey-keyed, never by NIP-05 handle: a handle is a name
/// `divine-name-server` hands out and can reassign, so a handle rule moves the
/// checkmark to whoever claims that name next.
///
/// Distinct from `AppConstants.divineTeamPubkeys`, which grants kind-30005
/// curation authority. Being on the team and curating official lists are
/// different permissions; folding them into one list would mean every new
/// curator silently gained a checkmark.
const Set<String> kDivineTeamPubkeys = {
  // Rabble
  'd95aa8fc0eff8e488952495b8064991d27fb96ed8652f12cdedc5a4e8b5ae540',
  // Liz
  '0edc2f474484769bc9bf6d471d180e4e280b0bcd719b6da791001beb730cff1b',
  // Daniel
  '89ef92b9ebe6dc1e4ea398f6477f227e95429627b0a33dc89b640e137b256be5',
  // Alex
  '04c106a7b7b1ac0a26f0e2ad22aaa2cfc3263bb7749a165545689282d1975c23',
  // Sebastian
  '295dbec79ee785496f703c9648f246665d46839c1d5f582c0342b4583da5ccb4',
  // Meylis
  '9be8bd90d818407bcf574d11b1c57f104fd53f40fa767abc4a631ee2694b43a3',
  // Matt
  '9cfa7d570af5dde1d79b476ac2c8b543b1970065d5488f4d86faf3c34c167e31',
  // Martin
  '076c979382b90f5d3a2b21f95e1ee86b6033f14c92e79b7fad3fe1f1073f4886',
  // Susan
  '1f0fa01371871502efbbb45f933ea07251265c940de279301dba3af4ccda085b',
  // Charlie
  'a7e9d5d90b17fad6e4526ce58f0af997b8c14826ecbdbc2c3955e6e258f4000c',
  // Kate
  'fb42392125a2c80acf3cd6ac30db8a2cdf9d44ef63865a95fded2f6a2186d44d',
  // Alice
  'fc7031a810ce4b02b6195a7e477cfe3d08c0386038bd45b4431f82d9b3f5ffb0',
  // Lauren
  '4e61fa221df35d3975d1c6abefa1dce1bd3beef3ce99b3b2883f5fe7467ca0ef',
  // Aleysha
  'ae35ec87e49f3ca2c92a0bbb40c507ae4a6a8e01de29eb9518bc941ed285f943',
  // Divine HQ
  kHqPubkeyHex,
};

/// Whether anyone could still sign as a retired moderation key.
///
/// Recorded per register entry because the client trusts a retired key
/// differently depending on it: a protected minor may read a retired key's
/// thread only while nobody can sign a new message as that key. States follow
/// the moderation-key retirement procedure in `support-trust-safety`.
enum RetiredKeyCustody {
  /// Lost before any custody decision; no known holder.
  unrecovered,

  /// Deliberately deleted from every store.
  destroyed,

  /// Kept in the team's vault; whoever can read that entry can sign.
  archived,

  /// May be held outside the team, whatever became of the team's copy.
  compromised;

  /// Whether someone could still sign a new event as the key.
  bool get canStillSign => switch (this) {
    RetiredKeyCustody.unrecovered || RetiredKeyCustody.destroyed => false,
    RetiredKeyCustody.archived || RetiredKeyCustody.compromised => true,
  };
}

/// One entry in the retired moderation key register.
class RetiredModerationKey {
  const RetiredModerationKey({required this.pubkeyHex, required this.custody});

  /// The retired identity, lowercase hex.
  final String pubkeyHex;

  /// Who, if anyone, can still sign as [pubkeyHex].
  final RetiredKeyCustody custody;
}

/// Moderation keys the account has rotated away from.
///
/// A DM thread opened before a rotation stays keyed on the old pubkey. Those
/// threads are deliberately NOT folded into the pinned support row: the row
/// routes on its own participants all the way to `sendMessage`, so adopting one
/// would address replies to a key nobody reads. They stay in whichever list
/// they arrived in, keeping their history reachable, and #6416 gave them the
/// identity and the closed composer that make that safe — see
/// [isRetiredModerationAccount].
///
/// Never a send target — messages always go to the current pin above. Used for
/// recognising the account's thread ([isModerationAccount], the safety
/// predicate), for choosing its name and avatar by custody
/// ([moderationPresentationOf]), for refusing outbound sends
/// ([isRetiredModerationAccount]), for the `ModerationLabelService`
/// subscription migration, for the custody-aware protected-minor read
/// (`OfficialAccountsService.isReadableByProtectedMinor`), and for refusing a
/// retired key as the moderation identity (`ModerationPubkeyResolver`).
///
/// Every entry carries its rotation date and what performed it below — which
/// may be no commit at all. The register of what each key was, the roles it
/// held, and what a rotation has to do is
/// `mobile/docs/RETIRED_MODERATION_KEYS.md` — read it before adding one.
const List<RetiredModerationKey> kRetiredModerationKeys = [
  // Retired 2026-03-12 by an operational secret rotation, after the service
  // and the clients drifted onto different keys — a mismatch, not a
  // compromise. Also held Funnelcake's RELAY_PUBKEY and one ADMIN_PUBKEYS
  // entry, plus the NIP-32 labeler role `ModerationLabelService` migrates
  // away. No PR performed the rotation, so both usual citations are merge
  // dates for something else: divinevideo/divine-moderation-service#31
  // (2026-03-15) is the cleanup after it, and divinevideo/divine-mobile#2321
  // (2026-03-20) is this client catching up eight days late.
  //
  // Private key UNRECOVERED — no known holder (2026-08-31 support call,
  // confirmed on #7851). Not an open question: gift wraps are encrypted to
  // the recipient, so messages sent here are unreadable by anyone forever,
  // and the closed composer is permanent for this key rather than pending a
  // custody answer. See mobile/docs/RETIRED_MODERATION_KEYS.md#key-custody.
  RetiredModerationKey(
    pubkeyHex:
        '121b915baba659cbe59626a8afaf83b01dc42354dfecaad9d465d51bb5715d72',
    custody: RetiredKeyCustody.unrecovered,
  ),
];

/// Pubkeys of [kRetiredModerationKeys], in register order. Derived so the
/// register stays the single source of what is retired.
final List<String> kLegacyModerationPubkeys = List.unmodifiable([
  for (final key in kRetiredModerationKeys) key.pubkeyHex,
]);

/// Whether [pubkeyHex] is a Divine moderation account's thread, current or
/// retired, whatever the retired key's custody.
///
/// This is the SAFETY question: "is this the moderation team's thread, so the
/// destructive request action is withheld and the thread cannot be removed".
/// It stays true for every retired key because those protections must not
/// depend on who might hold the key. It is not a presentation question: do not
/// use it to choose Divine's name or wordmark — [moderationPresentationOf]
/// does that, and withdraws the official look from a key someone could still
/// sign as (#9963).
///
/// Callers that need a *send target* must use [kModerationPubkeyHex] instead —
/// this answers "is this the moderation team", not "where do replies go".
///
/// Keyed on the pubkey alone, with no freshness gate: a message a retired key
/// signs today is treated exactly like one predating the rotation. See
/// `mobile/docs/RETIRED_MODERATION_KEYS.md`.
bool isModerationAccount(String pubkeyHex) =>
    pubkeyHex == kModerationPubkeyHex ||
    kLegacyModerationPubkeys.contains(pubkeyHex);

/// Which presentation [pubkeyHex] gets: official branding follows recorded
/// custody (#9963).
///
/// [retiredKeys] defaults to the shipped register. It is a parameter so the
/// UI can read it through a provider and tests can supply every custody state;
/// custody is compiled into the app, so a change reaches users only with the
/// build that lists it.
ModerationPresentation moderationPresentationOf(
  String pubkeyHex, {
  List<RetiredModerationKey> retiredKeys = kRetiredModerationKeys,
}) {
  if (pubkeyHex == kModerationPubkeyHex) return ModerationPresentation.official;
  for (final key in retiredKeys) {
    if (key.pubkeyHex == pubkeyHex) {
      return key.custody.canStillSign
          ? ModerationPresentation.former
          : ModerationPresentation.official;
    }
  }
  return ModerationPresentation.ordinary;
}

/// Whether [pubkeyHex] is a moderation account the team has rotated away from.
///
/// Nothing reads a retired key: `divine-moderation-service`'s DM reader
/// subscribes to exactly one pubkey, derived from its current signing key. A
/// message addressed here is accepted by the relay and read by nobody, so the
/// DM surface refuses the send and closes the composer instead of reporting a
/// success. Keyed on set membership rather than one literal so the next
/// rotation inherits the behaviour.
///
/// The reader is only the reversible half of that. The entry currently in
/// [kLegacyModerationPubkeys] has no known private-key holder, and a gift wrap
/// is encrypted to its recipient — so pointing a reader at it would deliver
/// ciphertext nobody can open. Do not reopen this on the theory that the
/// service could grow a watched set. A future retired key may differ, which
/// is why each [kRetiredModerationKeys] entry records its own custody in
/// code — mirrored in `mobile/docs/RETIRED_MODERATION_KEYS.md`'s register.
bool isRetiredModerationAccount(String pubkeyHex) =>
    kLegacyModerationPubkeys.contains(pubkeyHex);
