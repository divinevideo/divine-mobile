// ABOUTME: Service for sending encrypted NIP-17 (gift-wrapped) private messages
// ABOUTME: Handles three-layer encryption
// ABOUTME: (kind 14 rumor → kind 13 seal → kind 1059 gift wrap)
// ABOUTME: Works with any NostrSigner (local keys, Keycast RPC, Amber, etc.)

import 'dart:async';

import 'package:dm_repository/src/compute.dart';
import 'package:dm_repository/src/dm_batch_send_budget.dart';
import 'package:dm_repository/src/dm_send_budget.dart';
import 'package:dm_repository/src/dm_send_policy.dart';
import 'package:dm_repository/src/gift_wrap_build_worker.dart';
import 'package:meta/meta.dart';
import 'package:models/models.dart'
    show NIP17BlockedSendDisposition, NIP17SendResult;
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/event_kind.dart';
import 'package:nostr_sdk/nip19/pubkey_for_logs.dart';
import 'package:nostr_sdk/nip59/gift_wrap_batch_wrap.dart';
import 'package:nostr_sdk/nip59/gift_wrap_util.dart';
import 'package:nostr_sdk/nostr.dart';
import 'package:nostr_sdk/relay/relay.dart';
import 'package:nostr_sdk/signer/isolate_decrypt_signer.dart';
import 'package:nostr_sdk/signer/nostr_signer.dart';
import 'package:nostr_sdk/signer/signer_failure.dart';
import 'package:unified_logger/unified_logger.dart';

/// Builds a NIP-59 gift-wrapped event for [recipientPubkey] from
/// [rumorEvent], using [nostr] for signing. Returns `null` when the
/// underlying SDK declines to produce one (e.g. an internal encryption
/// step yields a null result without throwing).
///
/// Defaults to [GiftWrapUtil.getGiftWrapEvent]; injectable for tests
/// so the `null`-return branch in [NIP17MessageService] can be
/// exercised without conjuring valid gift-wrapped events by hand.
@internal
typedef GiftWrapBuilder =
    Future<Event?> Function(
      Nostr nostr,
      Event rumorEvent,
      String recipientPubkey,
    );

/// Builds NIP-17 gift wraps off the main isolate for local-key signers.
///
/// Defaults to running [buildGiftWrapBatch] in a [compute] isolate; injectable
/// for tests so the offload branch can be exercised inline without spawning a
/// real isolate.
@internal
typedef IsolateGiftWrapBatchBuilder =
    Future<List<BuiltGiftWrapResult>> Function(BuildGiftWrapRequest request);

/// Reports whether the device currently has no network connectivity.
///
/// Injected by the app layer (wired to `connectivity_plus`). Lets `sendRumor`
/// distinguish a genuine offline send — which must surface as a hard failure
/// (a red "Not delivered" bubble that re-drives on reconnect) — from a soft
/// "frame written, OK lost" send on a live network. Without it, an offline send
/// whose relay socket is still stale-`connected` (airplane mode is not detected
/// synchronously) buffers the frame to a dead socket, the recipient OK never
/// arrives, and the send is misclassified as soft-unconfirmed — so the bubble
/// keeps looking sent instead of turning red. See #6046.
///
/// Defaults to always-online (`false`) so callers and tests that do not wire
/// connectivity in keep their prior classification behavior.
typedef OfflineProbe = Future<bool> Function();

/// Body marker Keycast returns (with HTTP 403) only for the verified_minor DM
/// containment gate. Suspended accounts return "Account restricted" and token
/// failures are 401 with their own refresh path, so matching this exact marker
/// terminalizes a policy refusal while leaving transient errors retryable.
/// Mirrors `MINOR_DM_DENIED_MSG` in divinevideo/keycast.
const _minorDmPolicyDenialMarker = 'Operation denied by policy';

/// Service for sending encrypted private messages using NIP-17 gift wrapping.
///
/// Accepts any [NostrSigner] implementation, supporting both local key
/// signing and remote signing (e.g. Keycast RPC, Amber).
class NIP17MessageService {
  /// Creates a [NIP17MessageService] with the given dependencies.
  NIP17MessageService({
    required NostrSigner signer,
    required String senderPublicKey,
    required NostrClient nostrService,
    DmSendPolicy? sendPolicy,
    OfflineProbe? isOffline,
    @visibleForTesting GiftWrapBuilder? giftWrapBuilder,
    @visibleForTesting IsolateGiftWrapBatchBuilder? isolateGiftWrapBatchBuilder,
  }) : _signer = signer,
       _senderPublicKey = senderPublicKey,
       _nostrService = nostrService,
       _sendPolicy = sendPolicy ?? allowAllDmSendPolicy,
       _isOffline = isOffline ?? _alwaysOnline,
       _giftWrapBuilder = giftWrapBuilder ?? GiftWrapUtil.getGiftWrapEvent,
       _isolateGiftWrapBatchBuilder =
           isolateGiftWrapBatchBuilder ?? _computeGiftWrapBatch;

  final NostrSigner _signer;
  final String _senderPublicKey;
  final NostrClient _nostrService;
  final DmSendPolicy _sendPolicy;
  final OfflineProbe _isOffline;
  final GiftWrapBuilder _giftWrapBuilder;
  final IsolateGiftWrapBatchBuilder _isolateGiftWrapBatchBuilder;

  /// Default connectivity probe: assumes the device is online. Kept as a
  /// static tear-off so the constructor's default captures no instance state.
  static Future<bool> _alwaysOnline() async => false;

  /// Default off-main-isolate builder: runs [buildGiftWrapBatch] in a
  /// [compute] isolate. Kept as a static tear-off so the constructor's
  /// default does not capture instance state.
  static Future<List<BuiltGiftWrapResult>> _computeGiftWrapBatch(
    BuildGiftWrapRequest request,
  ) => compute(buildGiftWrapBatch, request);

  /// Whether the injected [DmSendPolicy] permits delivering to
  /// [recipientPubkey]. Exposed so `DmRepository` can gate BEFORE enqueue
  /// (avoid storing a doomed intent) and enforce group all-or-nothing before
  /// any per-recipient send. The per-send gate in [sendRumor] remains the
  /// authoritative choke point (covers the drain replay); this is the earlier,
  /// cheaper check.
  Future<bool> canSendTo(String recipientPubkey) async =>
      await _sendPolicy(recipientPubkey) == DmSendPolicyDecision.allowed;

  /// Builds a single NIP-17 gift wrap for [receiverPublicKey] from
  /// [rumorEvent].
  ///
  /// Routes through a [compute] isolate when the signer can safely expose its
  /// private key bytes (local-key signers), keeping the CPU-bound pure-Dart
  /// secp256k1 work off the UI isolate. Remote signers (Amber, Keycast RPC,
  /// NIP-46) cannot cross a `SendPort`, so they fall back to the
  /// on-main-isolate [_giftWrapBuilder] — already async RPC/IPC, not a block.
  ///
  /// A thrown isolate error falls back to the main-isolate builder, mirroring
  /// the receive-side decrypt offload in DmRepository. A returned failed slot
  /// is deterministic local crypto and is not rebuilt. See #5391 and #8534.
  Future<Event?> _buildWrap({
    required Nostr nostr,
    required Event rumorEvent,
    required String receiverPublicKey,
  }) async {
    final signer = _signer;
    if (signer is IsolateDecryptSigner && signer.canDecryptInIsolate) {
      try {
        final hex = signer.withPrivateKeyHex((k) => k);
        final results = await _isolateGiftWrapBatchBuilder(
          BuildGiftWrapRequest(
            privateKeyHex: hex,
            rumorJson: rumorEvent.toJson(),
            receiverPublicKeys: [receiverPublicKey],
          ),
        );
        final result = results.single;
        if (result.isSuccess) {
          return Event.fromJson(result.giftWrap!);
        }
        Log.warning(
          'Isolate gift-wrap build returned failure for rumor '
          '${rumorEvent.id}: ${result.error}; not rebuilding on the main '
          'isolate because it would repeat the same local crypto',
          category: LogCategory.system,
        );
        return null;
      } on Object catch (e, stackTrace) {
        Log.error(
          'Isolate gift-wrap build threw for rumor ${rumorEvent.id}: $e',
          category: LogCategory.system,
          error: e,
          stackTrace: stackTrace,
        );
        // Fall through to the main-isolate builder below.
      }
    }
    return _giftWrapBuilder(nostr, rumorEvent, receiverPublicKey);
  }

  /// Rumor kinds keycast's `nip17_wrap_batch` accepts. NIP-17 also blesses
  /// kind-7 reactions and wrapped kind-5 deletes, and this service sends both,
  /// but the server rejects them at request level ("Rumor kind must be 14 or
  /// 15"). Probing anyway would burn a round trip per reaction to learn the
  /// same answer every time.
  static const Set<int> _serverWrapBatchKinds = {
    EventKind.privateDirectMessage,
    EventKind.fileMessage,
  };

  /// Latched when the signer's backend turns out not to expose
  /// `nip17_wrap_batch`, so later sends in this session stop probing an absent
  /// verb. Set ONLY on an explicit "unsupported" answer — a transient error
  /// leaves it clear, because one blip is not evidence the verb is gone.
  bool _serverWrapBatchUnsupported = false;

  /// Builds the recipient and self-addressed gift wraps in a single isolate
  /// hop for local-key signers (one [compute] spawn covers both receivers,
  /// halving the spawn cost vs two separate [_buildWrap] calls), or — for a
  /// remote signer whose backend supports it — in a single `nip17_wrap_batch`
  /// round trip.
  ///
  /// Returns `(recipientWrap, selfWrap?)`. When no batch path applies — or a
  /// batch attempt is abandoned (it threw, returned the wrong slot count, or
  /// the server path declined) — only the recipient wrap is built here and
  /// `selfWrap` is `null`; [_publishSelfWrap] then builds the self-wrap
  /// lazily after the recipient publish confirms delivery (avoids an extra
  /// signing round-trip on publish failure).
  ///
  /// One case returns a `null` recipient wrap rather than rebuilding: the
  /// local-isolate batch reporting a failed *recipient* slot. That failure is
  /// deterministic local crypto, so the caller terminalises the send instead
  /// of spending a rebuild that would fail the same way. See the comment at
  /// that branch, and #8534.
  ///
  /// Security: `withPrivateKeyHex((k) => k)` copies the raw private-key hex
  /// out of its scoped callback so it can be serialised across the [compute]
  /// isolate boundary. This matches the receive-side pattern in
  /// `DmRepository._decryptRumor`. The key is already in the main-isolate
  /// heap; the threat model for this copy is identical to the attacker who
  /// can already read the heap. The isolate is short-lived and the key does
  /// not persist beyond the call.
  Future<(Event?, Event?)> _buildBothWraps({
    required Nostr nostr,
    required Event rumorEvent,
    required String recipientPubkey,
  }) async {
    final signer = _signer;
    if (signer is IsolateDecryptSigner && signer.canDecryptInIsolate) {
      try {
        final hex = signer.withPrivateKeyHex((k) => k);
        final results = await _isolateGiftWrapBatchBuilder(
          BuildGiftWrapRequest(
            privateKeyHex: hex,
            rumorJson: rumorEvent.toJson(),
            receiverPublicKeys: [recipientPubkey, _senderPublicKey],
          ),
        );
        if (results.length == 2) {
          final r = results[0];
          final s = results[1];
          if (!r.isSuccess) {
            // Local slot failures are deterministic: both builders derive the
            // same NIP-44 key from the same recipient pubkey, so rebuilding
            // repeats the failure. Server slot failures may be transient.
            Log.warning(
              'Batch gift-wrap: recipient slot failed (${r.error}); '
              'the send fails — rebuilding on the main isolate would run the '
              'same ECDH against the same recipient key and fail identically',
              category: LogCategory.system,
            );
          }
          if (!s.isSuccess) {
            Log.debug(
              'Batch gift-wrap: self-wrap slot failed (${s.error}); '
              '_publishSelfWrap will rebuild on the main isolate',
              category: LogCategory.system,
            );
          }
          return (
            r.isSuccess ? Event.fromJson(r.giftWrap!) : null,
            s.isSuccess ? Event.fromJson(s.giftWrap!) : null,
          );
        }
        Log.debug(
          'Batch gift-wrap returned unexpected result count '
          '(${results.length}); falling back to main-isolate builder',
          category: LogCategory.system,
        );
      } on Object catch (e, stackTrace) {
        Log.error(
          'Batch gift-wrap build threw for rumor ${rumorEvent.id}: $e; '
          'falling back to main-isolate builder',
          category: LogCategory.system,
          error: e,
          stackTrace: stackTrace,
        );
      }
    } else if (signer case final GiftWrapBatchWrapper wrapper
        when !_serverWrapBatchUnsupported &&
            _serverWrapBatchKinds.contains(rumorEvent.kind)) {
      // Remote signer whose backend builds NIP-59 wraps server-side: one round
      // trip returns both wraps, replacing the four (`nip44Encrypt` +
      // `signEvent`, per wrap) this path otherwise spends. See #7090.
      //
      // Deliberately in the `else` arm, never before the isolate check: when a
      // local-key signer's isolate hop is abandoned (it threw, or returned the
      // wrong slot count) it still falls through to [_buildWrap], which signs
      // in-process at zero round trips — reaching for the network there would
      // be a regression, not a speed-up. A failed recipient *slot* does not
      // reach here at all; it ends the send above (#8534).
      final wraps = await _buildBothWrapsOnServer(
        wrapper: wrapper,
        rumorEvent: rumorEvent,
        recipientPubkey: recipientPubkey,
      );
      if (wraps != null) return wraps;
    }
    // No batch path applied, or one was abandoned before producing slots:
    // build only the recipient wrap. The self-wrap is built lazily by
    // _publishSelfWrap after the recipient publish confirms delivery — avoids
    // an extra signing round-trip for remote signers when the publish fails.
    return (
      await _buildWrap(
        nostr: nostr,
        rumorEvent: rumorEvent,
        receiverPublicKey: recipientPubkey,
      ),
      null,
    );
  }

  /// One `nip17_wrap_batch` round trip building the recipient wrap and the
  /// NIP-17 self copy from the same rumor.
  ///
  /// Returns `null` when the caller must fall back to the per-wrap path:
  /// the backend does not expose the verb (latched so later sends skip the
  /// probe), the call failed transiently, the response was misshapen, or the
  /// recipient's own slot failed. A self-slot failure is NOT a fallback — the
  /// recipient wrap is still good, and `_publishSelfWrap` rebuilds the self
  /// copy exactly as it does for a signer with no batch support at all.
  Future<(Event?, Event?)?> _buildBothWrapsOnServer({
    required GiftWrapBatchWrapper wrapper,
    required Event rumorEvent,
    required String recipientPubkey,
  }) async {
    final List<GiftWrapSlot>? slots;
    try {
      slots = await wrapper.nip17WrapBatch(rumorEvent.toJson(), [
        recipientPubkey,
        _senderPublicKey,
      ]);
    } on Object catch (e) {
      // Transient: a 5xx, an expired token, a timeout, or the verified_minor
      // policy refusal. Fall back for THIS send without latching — the
      // fallback's own nip44Encrypt re-hits a policy refusal and sendRumor
      // terminalizes it as `blocked`, and a blip must not cost the rest of the
      // session its fast path.
      Log.warning(
        'Server gift-wrap batch failed for rumor ${rumorEvent.id}: $e; '
        'falling back to the per-wrap signing path',
        category: LogCategory.system,
      );
      return null;
    }

    if (slots == null) {
      // Older backend without the verb: stop probing it this session.
      _serverWrapBatchUnsupported = true;
      return null;
    }
    if (slots.length != 2) {
      Log.warning(
        'Server gift-wrap batch returned ${slots.length} slots for 2 '
        'recipients; falling back to the per-wrap signing path',
        category: LogCategory.system,
      );
      return null;
    }

    final recipientSlot = slots[0];
    final selfSlot = slots[1];
    if (!recipientSlot.isSuccess) {
      Log.warning(
        'Server gift-wrap batch: recipient slot failed '
        '(${recipientSlot.error}); falling back to the per-wrap signing path',
        category: LogCategory.system,
      );
      return null;
    }
    if (!selfSlot.isSuccess) {
      Log.debug(
        'Server gift-wrap batch: self-wrap slot failed (${selfSlot.error}); '
        '_publishSelfWrap will rebuild it',
        category: LogCategory.system,
      );
    }

    final recipientWrap = _serverWrapFromSlot(
      slot: recipientSlot,
      expectedRecipientPubkey: recipientPubkey,
      slotName: 'recipient',
    );
    if (recipientWrap == null) return null;

    final Event? selfWrap;
    if (selfSlot.isSuccess) {
      selfWrap = _serverWrapFromSlot(
        slot: selfSlot,
        expectedRecipientPubkey: _senderPublicKey,
        slotName: 'self',
      );
    } else {
      selfWrap = null;
    }
    return (recipientWrap, selfWrap);
  }

  Event? _serverWrapFromSlot({
    required GiftWrapSlot slot,
    required String expectedRecipientPubkey,
    required String slotName,
  }) {
    try {
      final event = Event.fromJson(slot.giftWrap!);
      final addressedToExpectedRecipient = event.tags.any(
        (tag) =>
            tag.length >= 2 &&
            tag[0] == 'p' &&
            tag[1] == expectedRecipientPubkey,
      );
      if (event.kind == EventKind.giftWrap &&
          addressedToExpectedRecipient &&
          verifyGiftWrapPart(event)) {
        return event;
      }
      Log.warning(
        'Server gift-wrap batch returned an invalid $slotName wrap; '
        'falling back to the per-wrap signing path',
        category: LogCategory.system,
      );
      return null;
    } on Object catch (e) {
      // A slot that parsed as JSON but is not a usable event. Never publish a
      // half-understood wrap; take the path that builds one we control.
      Log.warning(
        'Server gift-wrap batch returned an unusable $slotName event: $e; '
        'falling back to the per-wrap signing path',
        category: LogCategory.system,
      );
      return null;
    }
  }

  /// Build the unsigned NIP-17 rumor event for a 1:1 send.
  ///
  /// Pure construction — does not touch relays or the signer. Exposed
  /// separately from [sendRumor] so the repository can persist the
  /// rumor (or its serialized JSON) into the durable outgoing-DM queue
  /// **before** publishing, keyed by the rumor's id. Without this split
  /// a publish that succeeds with the recipient relay but the app
  /// crashes before [sendPrivateMessage] returns leaves no local
  /// trace of the in-flight send.
  ///
  /// Parameters:
  /// - [recipientPubkey]: Recipient's public key (hex format)
  /// - [content]: Message content (text for kind 14, file URL for kind 15)
  /// - [eventKind]: The rumor event kind (14 = text, 15 = file)
  /// - [additionalTags]: Optional tags to include in the rumor event
  /// - [createdAt]: Optional canonical event timestamp
  Event buildRumor({
    required String recipientPubkey,
    required String content,
    int eventKind = EventKind.privateDirectMessage,
    List<List<String>> additionalTags = const [],
    int? createdAt,
  }) {
    final rumorTags = <List<String>>[
      ['p', recipientPubkey],
      ...additionalTags,
    ];

    return Event(
      _senderPublicKey,
      eventKind,
      rumorTags,
      content,
      createdAt: createdAt,
    );
  }

  /// Build the ONE unsigned NIP-17 rumor a group send wraps for every
  /// recipient.
  ///
  /// **Invariant: one byte-identical rumor per group send.** NIP-59 states it
  /// outright — "If a `rumor` is intended for more than one party […] a single
  /// `rumor` may be wrapped and addressed for each recipient individually"
  /// (`59.md:108`) — and NIP-17 assumes it: "The set of `pubkey` + `p` tags
  /// defines a chat room" (`17.md:17`), a set, unordered.
  ///
  /// [buildRumor] prepends `['p', recipientPubkey]`, so calling it once per
  /// recipient produced N rumors carrying the same p-tag SET rotated into a
  /// different ORDER. A NIP-01 id hashes the tags *array*, so the rotation
  /// alone forked the id — and a retraction, which can name only one, then
  /// reached only one participant (#8188).
  ///
  /// Recipients are sorted so the id does not depend on the caller's argument
  /// order. The receiving recipient is included, as `17.md:118-132` shows;
  /// the sender is not (matching Amethyst — the convention is split across
  /// clients and both are tolerated, since every client keys a room on the
  /// participant set).
  ///
  /// Callers must not vary any tag element per recipient. A per-recipient
  /// relay hint inside a `p` tag would re-fork the id even with canonical
  /// ordering; NIP-17 puts hints on the gift wrap's own `p` tag instead.
  Event buildGroupRumor({
    required List<String> recipientPubkeys,
    required String content,
    int eventKind = EventKind.privateDirectMessage,
    List<List<String>> additionalTags = const [],
    int? createdAt,
  }) {
    final ordered = [...recipientPubkeys]..sort();
    return Event(
      _senderPublicKey,
      eventKind,
      <List<String>>[
        for (final pubkey in ordered) ['p', pubkey],
        ...additionalTags,
      ],
      content,
      createdAt: createdAt,
    );
  }

  /// OK-confirmation window for the recipient wrap when [sendRumor] runs
  /// with `awaitRecipientOk: true` (reaction sends and message sends). Kept
  /// well under the caller's outer publish cap so the confirmation resolves
  /// with headroom for the subsequent self-wrap before that timeout fires.
  static const Duration _recipientOkConfirmTimeout =
      DmSendBudget.recipientOkConfirm;

  /// Hard bound on the self-wrap publish. `publishEvent` is frame-accept
  /// with no timeout of its own, so a stalled socket would otherwise hang
  /// the send's tail past the caller's outer cap and misclassify a
  /// recipient-confirmed send as retryable-pending.
  static const Duration _selfWrapPublishTimeout = DmSendBudget.selfWrapPublish;

  /// Wrap and publish a pre-built [rumorEvent] to the recipient and to
  /// ourselves (self-addressed gift wrap for cross-device recovery).
  ///
  /// When [awaitRecipientOk] is `true`, the recipient wrap publish requires
  /// the relay's NIP-20 `OK true` before it counts as landed, instead of the
  /// default frame-accept. A bare frame-accept is a false positive on a flaky
  /// single relay — it reports success even though the relay never stored the
  /// event — so both reaction and message sends opt in to confirmation and
  /// lean on their durable retry queues to re-drive a soft, unconfirmed
  /// outcome. The default (`false`) frame-accept path is retained for callers
  /// with no confirmation need.
  ///
  /// Self-wrap failure is intentionally non-fatal — the message has
  /// already been delivered to the recipient at that point, and
  /// blocking the success result on the self-wrap would cause the
  /// repository to mark a successfully-delivered message as failed and
  /// retry the recipient publish, double-delivering. A future revision
  /// (PR #3910) will surface the self-wrap outcome separately so the
  /// repository can mark each wrap status independently.
  ///
  /// [targetRelays] routes the RECIPIENT's wrap; [selfWrapTargetRelays] routes
  /// the sender's own copy, and the two are deliberately separate because they
  /// address different people. `null` on either keeps that wrap on the default
  /// pool. The self-copy's destination is the sender's own kind-10050 DM inbox
  /// unioned with the pool — a bare pool publish never reached the inbox relays
  /// the sender advertises to everyone else, so their own replies were missing
  /// from any client reading that inbox (#7328). `DmRepository` resolves the
  /// union; see `DmRepository._selfWrapTargetRelays`.
  ///
  /// [selfWrapOnSoftUnconfirmed] controls whether the self-addressed wrap is
  /// still published when the recipient publish ends soft-unconfirmed (frame
  /// written, no OK). Reactions keep the default `true` — a lost OK may mean
  /// the recipient already has the reaction, and their retry service owns
  /// the follow-up (#5977). Durable message sends pass `false`: their queue
  /// re-drives the FULL send until the recipient wrap confirms (publishing
  /// both wraps on success), so a soft self-wrap buys no durability — but if
  /// it lands, its round-trip through the receive pipeline persists the
  /// message as a plain sent row, seeding a sent-looking bubble for a
  /// message the recipient may never have received (#6046). Non-queued callers
  /// that also pass `false` are choosing a hard no-self-wrap confirmation
  /// contract: soft-unconfirmed recipient publishes return retryable failure
  /// and the caller owns any fallback behavior.
  ///
  /// [recipientWrapBuildTimeout] bounds the recipient-wrap build, defaulting to
  /// [DmBatchSendBudget.recipientWrapBuild] for callers whose durable retry
  /// queue
  /// can keep a pre-publish timeout pending and re-drive it. Passing `null`
  /// leaves recipient-wrap construction uncapped; only callers with no outer
  /// cap and no retry row should do that, because a slow human-gated signer
  /// approval is otherwise indistinguishable from a hung signer.
  ///
  /// [selfWrapBuildTimeout] bounds the self-wrap build, defaulting to the
  /// tight [DmSendBudget.selfWrapBuild] for callers that protect the full
  /// publish with an outer cap. Durable message sends use
  /// `DmRepository._sendRumorWithTimeout`; reactions keep their existing 15s
  /// `_publishTimeout`, which can fire before these internal build bounds.
  ///
  /// Passing `null` leaves self-wrap construction uncapped, the same null
  /// semantics [recipientWrapBuildTimeout] carries. Only callers with no outer
  /// cap and no durable row should do that. A self-wrap build timeout is
  /// reported as `selfWrapPublished: false`, and the arm that is supposed to
  /// finish it out of band — `DmRepository.recoverSelfWrap` — requires an
  /// `outgoing_dms` row that those callers never create, so any bound there
  /// costs the sender their cross-device copy permanently and silently.
  /// [sendPrivateMessage] is that caller, reached by
  /// `DmRepository.sendFileMessage` and the bug-report send.
  @useResult
  Future<NIP17SendResult> sendRumor({
    required Event rumorEvent,
    required String recipientPubkey,
    List<String>? targetRelays,
    List<String>? selfWrapTargetRelays,
    bool awaitRecipientOk = false,
    bool selfWrapOnSoftUnconfirmed = true,
    Duration? recipientWrapBuildTimeout = DmBatchSendBudget.recipientWrapBuild,
    Duration? selfWrapBuildTimeout = DmSendBudget.selfWrapBuild,
  }) async {
    final recipientWrapBound = recipientWrapBuildTimeout;
    final selfWrapBound = selfWrapBuildTimeout;
    try {
      // Send gate (#176): the lowest recipient-delivering primitive, so every
      // publisher — direct send, group fan-out, drain replay, reactions,
      // file — is covered at one seam. The injected policy decides which
      // recipients are refused. Checked before any wrap build or publish, so a
      // blocked send leaks no metadata to relays and performs no signing work.
      // Bounded: the resolver behind this has its own Dio connect/receive
      // bound, but nothing here enforced it, so a wedged resolver spent the
      // publish backstop instead (#7091). Fail CLOSED to temporarily-blocked:
      // this is a safety gate, and a retryable refusal is the safe reading of
      // "we could not determine whether this recipient is permitted".
      DmSendPolicyDecision policyDecision;
      try {
        policyDecision = await _sendPolicy(
          recipientPubkey,
        ).timeout(DmSendBudget.sendPolicyCheck);
      } on TimeoutException {
        Log.warning(
          'NIP-17 send policy check exceeded '
          '${DmSendBudget.sendPolicyCheck.inSeconds}s; treating as '
          'temporarily blocked',
          category: LogCategory.system,
        );
        policyDecision = DmSendPolicyDecision.temporarilyBlocked;
      }
      if (policyDecision != DmSendPolicyDecision.allowed) {
        Log.info(
          'NIP-17 send blocked by policy for recipient',
          category: LogCategory.system,
        );
        if (policyDecision == DmSendPolicyDecision.temporarilyBlocked) {
          return const NIP17SendResult.failure(
            'temporarily blocked: protected-minor status unresolved',
          );
        }
        return NIP17SendResult.blocked(
          'blocked: recipient not permitted by send policy',
          disposition:
              policyDecision == DmSendPolicyDecision.terminallyBlockedRetain
              ? NIP17BlockedSendDisposition.retain
              : NIP17BlockedSendDisposition.discard,
        );
      }

      // Fail fast when the device has no connectivity. A publish while offline
      // only buffers the frame to a relay socket still stale-`connected`
      // (airplane mode is not detected synchronously — the WebSocket flips to
      // disconnected only on an async OS close or the heartbeat idle timeout),
      // so the OK-confirm path below would misread it as a soft "frame written,
      // OK lost" send and keep the bubble looking sent. With no connectivity
      // the send definitively did not happen: return a hard failure so the
      // durable queue marks the row failed (red bubble) and the reconnect sweep
      // re-drives it. See #6046.
      if (await _isOfflineSafely()) {
        Log.info(
          'NIP-17 send skipped: device reports no connectivity',
          category: LogCategory.system,
        );
        return const NIP17SendResult.failure(
          'Message not sent: device offline',
        );
      }

      Log.info(
        'Sending NIP-17 encrypted message to recipient',
        category: LogCategory.system,
      );

      // Create a minimal Nostr instance for GiftWrapUtil.
      // Uses the injected signer (works with local or remote signing). The
      // signer stays the source of truth for the seal pubkey (it MUST match
      // the signing key, NIP-59). Every signer the app injects answers this
      // from a field — the send path receives a `NostrIdentity`, and NIP-46's
      // returns `info.userPubkey`. `KeycastRpc.getPublicKey` IS an uncached
      // RPC, but it sits behind that identity rather than on this path.
      final nostr = Nostr(
        _signer,
        [], // Empty filters - not using for subscriptions
        _dummyRelayGenerator, // Dummy relay generator - not using relays
      );
      // Bounded: every signer the app injects answers getPublicKey from a
      // field (the send path receives a NostrIdentity), so this cannot fail a
      // refresh a shipped signer would have completed. It ran inside the
      // publish backstop with no bound of its own (#7091).
      try {
        await nostr.refreshPublicKey().timeout(
          DmSendBudget.signerPubkeyRefresh,
        );
      } on TimeoutException {
        Log.warning(
          'Signer pubkey refresh exceeded '
          '${DmSendBudget.signerPubkeyRefresh.inSeconds}s',
          category: LogCategory.system,
        );
        return const NIP17SendResult.failure(
          'Signer did not answer in time',
          retryablePending: true,
        );
      }

      Log.debug(
        'Wrapping kind ${rumorEvent.kind} rumor event',
        category: LogCategory.system,
      );

      // Build recipient and self-addressed gift wraps. For local-key signers
      // both are built in one isolate hop (half the spawn cost vs two separate
      // calls); for remote signers the self-wrap is deferred to
      // _publishSelfWrap after the recipient publish confirms delivery.
      // Bounded: the wrap build is 2 remote signer round trips, and no signer
      // interface exposes a per-call timeout — the transport's own bound is
      // whatever that signer chose. Keycast is 20s/op; Amber's NIP-55 intent
      // path for `nip44Encrypt` and `signEvent` is human-gated and unbounded; a
      // bunker can be unbounded too. Without a bound here the chain can outrun
      // the caller's publish backstop, which then fires AFTER the recipient
      // publish has already landed and misclassifies a delivered message
      // (#6586). Timing out before any publish leaves nothing delivered, so the
      // durable queue can safely keep it retryable.
      var recipientWrapBuildTimedOut = false;
      final recipientWrapBuild = _buildBothWraps(
        nostr: nostr,
        rumorEvent: rumorEvent,
        recipientPubkey: recipientPubkey,
      );
      final (
        giftWrapEvent,
        prebuiltSelfWrap,
      ) = await (recipientWrapBound == null
          ? recipientWrapBuild
          : recipientWrapBuild.timeout(
              recipientWrapBound,
              onTimeout: () {
                recipientWrapBuildTimedOut = true;
                return (null, null);
              },
            ));

      if (giftWrapEvent == null) {
        return NIP17SendResult.failure(
          recipientWrapBuildTimedOut
              ? 'Recipient gift wrap build timed out after '
                    '${recipientWrapBound!.inSeconds}s'
              : 'Failed to create gift wrap event',
          retryablePending: recipientWrapBuildTimedOut,
        );
      }

      Log.debug(
        'Created recipient gift wrap with ephemeral key: '
        '${pubkeyForLogs(giftWrapEvent.pubkey)}',
        category: LogCategory.system,
      );

      // Publish the recipient's gift wrap. Route it to the recipient's
      // NIP-17 kind-10050 DM inbox relays when known (so non-diVine users
      // who only read their own inbox relays actually receive it); fall
      // back to the default pool otherwise. The no-targetRelays call shape
      // is kept identical to preserve existing behavior.
      if (awaitRecipientOk) {
        // OK-confirm path (reactions): require the relay's NIP-20 OK before
        // reporting delivery, but keep this device's own durability
        // independent of it.
        final outcome = (targetRelays != null && targetRelays.isNotEmpty)
            ? await _nostrService.publishEventAwaitOk(
                giftWrapEvent,
                targetRelays: targetRelays,
                timeout: _recipientOkConfirmTimeout,
              )
            : await _nostrService.publishEventAwaitOk(
                giftWrapEvent,
                timeout: _recipientOkConfirmTimeout,
              );

        // Classify the outcome BEFORE deciding on the self-wrap. Three cases:
        //  * explicit OK-false → hard rejection: the recipient definitely did
        //    not get it.
        //  * nothing reached any relay (offline) → the send definitively did
        //    not happen.
        //  * frame written to a relay but no OK within the window →
        //    inconclusive soft-unconfirmed; it may already be delivered.
        final rejected = outcome.rejectedBy.isNotEmpty;
        final reachedNoRelay =
            outcome.acceptedBy.isEmpty &&
            outcome.rejectedBy.isEmpty &&
            outcome.noResponseFrom.isEmpty;
        final softUnconfirmed = !rejected && !reachedNoRelay;

        // Kind-aware noun for logs and error strings: this path serves both
        // reaction (kind 7) and message (kind 14/15) sends, and a log that
        // says "reaction" for a text message misdirects field debugging.
        // A wrapped kind-5 is a DELETION of something, and which noun it takes
        // depends on what it deletes — a reaction removal and a message
        // delete-for-everyone both arrive here as kind 5. NIP-09's `k` tag
        // names the deleted kind, and both builders set it
        // (`DmReactionsRepository._durablyDeleteReaction` writes 7,
        // `DmRepository._driveDeleteForEveryone` writes the row's message
        // kind), so read it rather than guessing. Without this a reaction
        // removal logs as "message" and sends field debugging to the wrong
        // send path.
        final deletesReaction =
            rumorEvent.kind == EventKind.eventDeletion &&
            rumorEvent.tags.any(
              (tag) =>
                  tag.length >= 2 &&
                  tag[0] == 'k' &&
                  tag[1] == '${EventKind.reaction}',
            );
        final isReaction =
            rumorEvent.kind == EventKind.reaction || deletesReaction;
        final rumorNoun = isReaction ? 'reaction' : 'message';
        final rumorNounCapitalized = isReaction ? 'Reaction' : 'Message';

        // Publish the self-addressed wrap ONLY when the recipient confirmed
        // OR the send is soft-unconfirmed AND the caller opted in
        // ([selfWrapOnSoftUnconfirmed] — reactions only; see the doc above
        // for why message sends opt out). On a hard rejection or an offline
        // no-relay-reached the recipient definitely did not get it, so a
        // self-wrap would surface a phantom rumor on the sender's other
        // devices / reinstall (ingested via persistIncoming as a plain
        // `received` row with no retry metadata). The self-wrap is p-tagged
        // to the sender only, so publishing it on a soft-unconfirmed send
        // never double-delivers to the counterparty.
        // Short-circuit `&&`: when the gate is false the self-wrap publish is
        // never awaited, so it is skipped entirely on rejected / reachedNoRelay.
        final selfWrapPublished =
            (outcome.confirmed ||
                (softUnconfirmed && selfWrapOnSoftUnconfirmed)) &&
            await _publishSelfWrap(
              nostr: nostr,
              rumorEvent: rumorEvent,
              wrapBuildTimeout: selfWrapBound,
              prebuiltSelfWrap: prebuiltSelfWrap,
              targetRelays: selfWrapTargetRelays,
            );

        if (outcome.confirmed) {
          Log.info(
            'Successfully published NIP-17 $rumorNoun '
            '(selfWrapPublished=$selfWrapPublished)',
            category: LogCategory.system,
          );
          return NIP17SendResult.success(
            rumorEventId: rumorEvent.id,
            messageEventId: giftWrapEvent.id,
            recipientPubkey: recipientPubkey,
            selfWrapPublished: selfWrapPublished,
          );
        }

        // Not confirmed. The caller's chip + retry follow from the sub-case:
        //  * rejected → mark failed (terminal-ish; failed rows skip the sweep's
        //    in-flight min-age guard so they re-drive immediately).
        //  * reachedNoRelay (offline) → mark failed so the sweep re-drives it
        //    the instant connectivity returns.
        //  * softUnconfirmed → keep a dim, sweep-retryable 'pending' chip
        //    (a lost OK is not proof of loss).
        final String errorMsg;
        if (rejected) {
          errorMsg =
              '$rumorNounCapitalized rejected by relay: ${outcome.summary}';
        } else if (reachedNoRelay) {
          errorMsg = '$rumorNounCapitalized not sent: no relay reached';
        } else {
          errorMsg =
              '$rumorNounCapitalized recipient OK unconfirmed: '
              '${outcome.summary}';
        }
        Log.warning(
          'NIP-17 $rumorNoun recipient publish unconfirmed '
          '(rumor=${rumorEvent.id}, '
          'recipient=${pubkeyForLogs(recipientPubkey)}, '
          '${outcome.summary}); selfWrapPublished=$selfWrapPublished',
          category: LogCategory.system,
        );
        return NIP17SendResult.failure(
          errorMsg,
          retryablePending: softUnconfirmed,
        );
      }

      // Frame-accept path (messages): a WebSocket-accepted frame counts as
      // sent, and the self-wrap runs only after the recipient publish lands.
      final sentEvent = (targetRelays != null && targetRelays.isNotEmpty)
          ? await _nostrService.publishEvent(
              giftWrapEvent,
              targetRelays: targetRelays,
            )
          : await _nostrService.publishEvent(giftWrapEvent);

      if (sentEvent is! PublishSuccess) {
        const errorMsg = 'Message publish failed to relays';
        Log.error(
          '$errorMsg (rumor=${rumorEvent.id}, '
          'recipient=${pubkeyForLogs(recipientPubkey)})',
          category: LogCategory.system,
        );
        return const NIP17SendResult.failure(errorMsg);
      }

      // NIP-17: publish a self-addressed gift wrap so our own sent
      // messages are recoverable from relays after reinstall or data
      // loss. The recipient already received the message at this
      // point, so a self-wrap failure must never bubble up — the
      // helper catches everything and reports the per-wrap status
      // separately. Re-publishing the recipient wrap would
      // double-deliver, so the recovery path uses [publishSelfWrap]
      // to retry only the missing self-wrap.
      final selfWrapPublished = await _publishSelfWrap(
        nostr: nostr,
        rumorEvent: rumorEvent,
        wrapBuildTimeout: selfWrapBound,
        prebuiltSelfWrap: prebuiltSelfWrap,
        targetRelays: selfWrapTargetRelays,
      );

      Log.info(
        'Successfully published NIP-17 message '
        '(selfWrapPublished=$selfWrapPublished)',
        category: LogCategory.system,
      );
      return NIP17SendResult.success(
        rumorEventId: rumorEvent.id,
        messageEventId: giftWrapEvent.id,
        recipientPubkey: recipientPubkey,
        selfWrapPublished: selfWrapPublished,
      );
    } on Object catch (e, stackTrace) {
      Log.error(
        'Failed to send NIP-17 message '
        '(rumor=${rumorEvent.id}, '
        'recipient=${pubkeyForLogs(recipientPubkey)}): $e',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
      if (e.toString().contains(_minorDmPolicyDenialMarker)) {
        // Keycast's server-side verified_minor gate refused to sign or encrypt
        // this DM. That is a permanent policy decision, not a transient error,
        // so terminalize it (blocked) rather than returning a retryable failure
        // the drain would re-attempt until maxRetries and Resend would
        // deterministically re-fail. The blocked → terminal drain path already
        // exists (#6028); this routes the server refusal into it.
        return const NIP17SendResult.blocked(
          'blocked: recipient not permitted by send policy',
        );
      }
      if (e is TransientSignerFailure) {
        // The signer gave up instead of signing — a remote signer that bounds
        // itself and answers with an error rather than making us wait it out
        // (Keycast's 504). Classified exactly like the wrap-build
        // `.timeout(recipientWrapBound)` above, because it is the same event
        // seen from the other side of the wire: nothing was signed, so nothing
        // was published, so the durable queue can safely re-drive it.
        //
        // Without this the same slow signer produced two opposite outcomes —
        // a dim retryable chip when the client's patience ran out first, a red
        // hard failure when the server's did (#7092). Which one the user got
        // turned on a race between two bounds neither layer documented to the
        // other.
        //
        // Safe to call retryable here because every signer round trip inside
        // this `try` runs *before* the recipient publish: `refreshPublicKey`
        // and `_buildBothWraps`. Everything after it — `_publishSelfWrap` —
        // catches its own errors and reports status by return value, so no
        // post-delivery failure can reach this handler and re-drive a message
        // the recipient already has.
        return NIP17SendResult.failure(
          'Failed to send message: $e',
          retryablePending: true,
        );
      }
      return NIP17SendResult.failure('Failed to send message: $e');
    }
  }

  /// Runs the injected connectivity probe, defaulting to online on any error so
  /// a flaky probe never blocks a send that might otherwise succeed.
  Future<bool> _isOfflineSafely() async {
    try {
      // Bounded as well as guarded: `connectivity_plus`' checkConnectivity is
      // a platform-channel round trip, and a wedged channel is a hang, not a
      // throw — which is why the catch below could never cover it (#7091).
      return await _isOffline().timeout(DmSendBudget.connectivityProbe);
    } on TimeoutException {
      Log.warning(
        'Offline probe exceeded ${DmSendBudget.connectivityProbe.inSeconds}s; '
        'assuming online',
        category: LogCategory.system,
      );
      return false;
    } on Object catch (e) {
      Log.warning(
        'Offline probe failed; assuming online: $e',
        category: LogCategory.system,
      );
      return false;
    }
  }

  /// Publish only the sender self-addressed gift wrap for an
  /// already-sent [rumorEvent].
  ///
  /// Used by the recovery path when a previous [sendRumor] delivered
  /// to the recipient (the recipient kind 1059 wrap landed) but the
  /// self-addressed wrap did not. Re-running [sendRumor] would publish
  /// the recipient wrap a second time and double-deliver, so the
  /// recovery path goes through this method instead. Receiver-side
  /// dedup keys on the rumor event id, so callers must pass the same
  /// rumor that was published originally — rebuilding it from the
  /// queue's `rumor_event_json` preserves the id, minting a fresh
  /// rumor would not.
  ///
  /// Returns [NIP17SendResult.success] on a successful self-wrap
  /// publish (the `messageEventId` slot carries the rumor id since no
  /// new recipient-wrap event id is produced on this path) or
  /// [NIP17SendResult.failure] when the self-wrap could not be built
  /// or did not reach a relay.
  @useResult
  Future<NIP17SendResult> publishSelfWrap({
    required Event rumorEvent,
    List<String>? targetRelays,
  }) async {
    try {
      // Same fail-fast as sendRumor: a frame buffered to a stale-`connected`
      // socket while offline would count as PublishSuccess and mark the
      // self-wrap `sent` even though it never left the device.
      if (await _isOfflineSafely()) {
        Log.info(
          'Self-wrap recovery skipped: device reports no connectivity',
          category: LogCategory.system,
        );
        return const NIP17SendResult.failure(
          'Self-wrap not sent: device offline',
        );
      }

      Log.info(
        'Publishing self-addressed NIP-17 gift wrap for rumor recovery',
        category: LogCategory.system,
      );

      final nostr = Nostr(_signer, [], _dummyRelayGenerator);
      await nostr.refreshPublicKey();

      final published = await _publishSelfWrap(
        nostr: nostr,
        rumorEvent: rumorEvent,
        wrapBuildTimeout: DmSendBudget.selfWrapUncappedBuild,
        targetRelays: targetRelays,
      );
      if (!published) {
        return const NIP17SendResult.failure('Self-wrap publish failed');
      }
      return NIP17SendResult.success(
        rumorEventId: rumorEvent.id,
        messageEventId: rumorEvent.id,
        recipientPubkey: _senderPublicKey,
      );
    } on Object catch (e, stackTrace) {
      Log.error(
        'Failed to publish self-wrap recovery: $e',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
      return NIP17SendResult.failure('Failed to publish self-wrap: $e');
    }
  }

  /// Build and publish the sender self-addressed gift wrap for
  /// [rumorEvent]. Returns `true` when the wrap reached at least one
  /// relay.
  ///
  /// When [prebuiltSelfWrap] is non-null (supplied by [_buildBothWraps] on
  /// the local-key-signer path), the build step is skipped and the prebuilt
  /// event is published directly. Otherwise the wrap is built via
  /// [_buildWrap] on the main isolate.
  ///
  /// Catches every error — used by both the happy-path send (where the
  /// recipient has already received the message and an exception must
  /// not crash the result) and the recovery path (where an exception
  /// is just another failure mode the caller surfaces).
  Future<bool> _publishSelfWrap({
    required Nostr nostr,
    required Event rumorEvent,
    required Duration? wrapBuildTimeout,
    Event? prebuiltSelfWrap,
    List<String>? targetRelays,
  }) async {
    try {
      // Bounded: letting these 2 remote round trips run unbounded is what
      // pushed a delivered send past the caller's backstop and got it
      // misclassified as unconfirmed (#6586). Timing out returns false, which
      // the caller reports as `selfWrapPublished: false` — the durable row
      // survives and the retry sweep's recoverSelfWrap arm finishes it out of
      // band (#4124).
      //
      // The bound is the caller's, because the callers are not paying for the
      // same thing: inside a send it is the tight
      // [DmSendBudget.selfWrapBuild] that keeps the chain under the backstop,
      // while recovery runs with no outer cap and uses the wider
      // [DmSendBudget.selfWrapUncappedBuild] — bounding recovery at the tight
      // one would fail rebuilds against the same slow signer that left the
      // self-wrap outstanding.
      //
      // A `null` bound means uncapped, for callers that own no `outgoing_dms`
      // row: recoverSelfWrap needs one, so for them the "durable row survives
      // and recovery finishes it" contract above does not hold and any bound
      // loses the cross-device copy outright.
      final Event? selfWrapEvent;
      if (prebuiltSelfWrap != null) {
        selfWrapEvent = prebuiltSelfWrap;
      } else {
        final build = _buildWrap(
          nostr: nostr,
          rumorEvent: rumorEvent,
          receiverPublicKey: _senderPublicKey,
        );
        selfWrapEvent = wrapBuildTimeout == null
            ? await build
            : await build.timeout(wrapBuildTimeout, onTimeout: () => null);
      }
      if (selfWrapEvent == null) {
        Log.warning(
          'Self-wrap creation returned null — the sender will not see '
          'this message on other devices or after a reinstall.',
          category: LogCategory.system,
        );
        return false;
      }
      // Bounded: publishEvent is frame-accept with no timeout of its own, so
      // a stalled socket would hang the send's tail past the caller's outer
      // cap and misclassify a recipient-confirmed send as retryable-pending.
      // try/on rather than onTimeout: the future's reified type can be a
      // PublishResult subtype, which an onTimeout closure cannot satisfy.
      // Naming relays here is what carries the self-copy to the sender's own
      // kind-10050 DM inbox; `null` keeps the historic plain-pool publish.
      // #7328.
      final destination = (targetRelays != null && targetRelays.isNotEmpty)
          ? targetRelays
          : null;
      PublishResult published;
      try {
        published =
            await (destination == null
                    ? _nostrService.publishEvent(selfWrapEvent)
                    : _nostrService.publishEvent(
                        selfWrapEvent,
                        targetRelays: destination,
                      ))
                .timeout(_selfWrapPublishTimeout);
      } on TimeoutException {
        published = const PublishFailed();
      }
      // Name the destination on both outcomes. Reporting only a bare
      // success/failure is what let a self-copy that never reached the
      // sender's advertised inbox read as delivered (#7328), and support
      // cannot tell those apart from the event id alone.
      final destinationForLog = destination?.join(', ') ?? 'default pool';
      if (published is! PublishSuccess) {
        Log.warning(
          'Self-wrap publish failed — the sender will not see this '
          'message on other devices or after a reinstall '
          '(event=${selfWrapEvent.id}, relays=$destinationForLog)',
          category: LogCategory.system,
        );
        return false;
      }
      Log.info(
        'Self-wrap published (event=${selfWrapEvent.id}, '
        'relays=$destinationForLog)',
        category: LogCategory.system,
      );
      return true;
    } on Object catch (e) {
      Log.error(
        'Self-wrap failed (non-fatal): the sender will not see this '
        'message on other devices or after a reinstall: $e',
        category: LogCategory.system,
      );
      return false;
    }
  }

  /// Build a kind-[eventKind] rumor with [content] + [tags] and publish it as
  /// a **self-addressed** NIP-59 gift wrap (never to a counterparty) to the
  /// default pool. Returns `true` when the wrap reached at least one relay.
  ///
  /// Used for the DM read-state cursor marker (#4977): a kind-30078
  /// application-data rumor whose `content` is the read map. The gift-wrap seal
  /// (kind 13) NIP-44-encrypts it to the user's own key, so the read map is
  /// never world-readable on the (unauthenticated) relay. Self-wrap failure is
  /// non-fatal — a missed marker just means read state is restored on the next
  /// publish.
  Future<bool> publishSelfApplicationMarker({
    required String content,
    required List<List<String>> tags,
    int eventKind = EventKind.appSpecificData,
  }) async {
    try {
      final nostr = Nostr(_signer, [], _dummyRelayGenerator);
      await nostr.refreshPublicKey();
      final rumor = Event(_senderPublicKey, eventKind, tags, content);
      final selfWrapEvent = await _buildWrap(
        nostr: nostr,
        rumorEvent: rumor,
        receiverPublicKey: _senderPublicKey,
      ).timeout(DmSendBudget.selfWrapUncappedBuild, onTimeout: () => null);
      if (selfWrapEvent == null) return false;
      final published = await _nostrService.publishEvent(selfWrapEvent);
      return published is PublishSuccess;
    } on Object catch (e, stackTrace) {
      Log.error(
        'DM read-marker self-wrap failed (non-fatal): $e',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Convenience wrapper that builds a rumor and sends it in one call.
  ///
  /// Existing callers (group sends, file sends, NIP-04 fallback wiring)
  /// keep working unchanged. New callers that need to enqueue a durable
  /// queue row keyed by the rumor's id should call [buildRumor] +
  /// [sendRumor] directly so the queue insert happens between the two.
  @useResult
  Future<NIP17SendResult> sendPrivateMessage({
    required String recipientPubkey,
    required String content,
    int eventKind = EventKind.privateDirectMessage,
    List<List<String>> additionalTags = const [],
    List<String>? targetRelays,
    List<String>? selfWrapTargetRelays,
    bool awaitRecipientOk = false,
    bool selfWrapOnSoftUnconfirmed = true,
  }) async {
    final rumor = buildRumor(
      recipientPubkey: recipientPubkey,
      content: content,
      eventKind: eventKind,
      additionalTags: additionalTags,
    );
    return sendRumor(
      rumorEvent: rumor,
      recipientPubkey: recipientPubkey,
      targetRelays: targetRelays,
      selfWrapTargetRelays: selfWrapTargetRelays,
      awaitRecipientOk: awaitRecipientOk,
      selfWrapOnSoftUnconfirmed: selfWrapOnSoftUnconfirmed,
      // No caller of this method owns an outgoing_dms row, so a bounded
      // pre-publish Amber approval would return retryablePending with nowhere
      // to retry from. Preserve the pre-PR uncapped recipient-build contract.
      recipientWrapBuildTimeout: null,
      // Same reasoning on the self-wrap: with no outgoing_dms row there is no
      // recoverSelfWrap arm to finish a timed-out build, so any bound here
      // silently costs the sender their cross-device copy for good.
      selfWrapBuildTimeout: null,
    );
  }

  /// Dummy relay generator - we don't use relays in this Nostr instance
  /// Only needed for Nostr constructor, but not actually called
  Relay _dummyRelayGenerator(String url) {
    throw UnimplementedError(
      'Relay generation not needed for signing-only Nostr instance',
    );
  }
}
