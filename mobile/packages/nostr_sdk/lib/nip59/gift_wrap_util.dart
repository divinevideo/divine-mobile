import 'dart:convert';
import 'dart:developer';
import 'dart:math' as math;

import '../client_utils/keys.dart';
import '../event.dart';
import '../event_kind.dart';
import '../nip19/pubkey_for_logs.dart';
import '../nip44/nip44_v2.dart';
import '../nostr.dart';

/// Verifies one gift-wrap-layer event's integrity and signature: it recomputes
/// the event id (sha256, [Event.isValid]) and verifies the Schnorr signature
/// ([Event.isSigned]). This is the single shared definition of "this gift-wrap
/// part is well-formed and authentically signed", used by
/// [GiftWrapUtil.getRumorEvent] (inline and via an injected
/// [GiftWrapPartVerifier]) and by the off-isolate DM history-drain verifier.
///
/// Pure (no I/O, no private key), so it is safe to run inside an isolate.
bool verifyGiftWrapPart(Event event) => event.isValid && event.isSigned;

/// [verifyGiftWrapPart] over an [Event.toJson] map, so the check can cross an
/// isolate boundary. Returns `false` for malformed JSON rather than throwing.
bool verifyGiftWrapPartJson(Map<String, dynamic> eventJson) {
  try {
    return verifyGiftWrapPart(Event.fromJson(eventJson));
  } on Object {
    return false;
  }
}

/// Asynchronously verifies a single gift-wrap-layer [Event]. Injected into
/// [GiftWrapUtil.getRumorEvent] so the (CPU-bound, pure-Dart) id + Schnorr
/// verification can be moved off the main isolate on the high-volume remote-
/// signer history drain — where the decrypt itself must stay on the main
/// isolate (a remote signer cannot cross a `SendPort`). When omitted,
/// `getRumorEvent` verifies inline on the calling isolate, unchanged.
typedef GiftWrapPartVerifier = Future<bool> Function(Event event);

/// Largest plaintext accepted at either NIP-17 decrypt layer.
///
/// Divine's production relay advertises a 100 KiB event-content ceiling, so
/// a 1 MiB NIP-44 plaintext cannot arrive through it. 128 KiB keeps generous
/// interoperability headroom for other relays while bounding the JSON and DM
/// body handed to parsing, persistence, and repeated Flutter layout (#7331).
const int maxNip17ReceivePlaintextBytes = 128 * 1024;

bool _plaintextFits(String plaintext, int maxBytes) =>
    utf8.encode(plaintext).length <= maxBytes;

/// Rebuilds an unsigned NIP-59 rumor from its plaintext JSON using the
/// authenticated seal pubkey as author.
///
/// NIP-59 leaves the inner rumor unsigned, so its claimed `id` and `pubkey`
/// are not authenticated and may be absent. Read only the fields that define
/// the canonical event body, and let [Event] derive the id from those fields.
Event rebuildUnsignedRumorFromJson(
  Map<String, dynamic> rumorJson, {
  required String authenticatedPubkey,
}) {
  final tags = (rumorJson['tags'] as List<dynamic>)
      .map((tag) => (tag as List<dynamic>).map((e) => e as String).toList())
      .toList();
  return Event(
    authenticatedPubkey,
    rumorJson['kind'] as int,
    tags,
    rumorJson['content'] as String,
    createdAt: rumorJson['created_at'] as int,
  );
}

class GiftWrapUtil {
  static final math.Random _secureRandom = math.Random.secure();

  /// Two days in seconds — the NIP-17 upper bound for created_at jitter.
  static const int _maxBackdateSeconds = 60 * 60 * 24 * 2;

  /// Returns wall-clock now shifted into the past by a CSPRNG offset of
  /// 0..2 days. Call once per layer (seal, gift wrap) so each gets an
  /// independent offset, per NIP-17/NIP-59 metadata-protection guidance.
  ///
  /// Deliberately based on NOW, not the rumor's `created_at`: a retry
  /// re-wraps the SAME rumor hours or days after the original attempt, and
  /// a wrap stamped relative to the old rumor time lands before recipients'
  /// `since` subscription cursors (they never see the retry) and outside
  /// relay recency windows (the retry is rejected outright). The unsigned
  /// inner rumor keeps the canonical send time.
  static int _randomizedPastTimestamp() =>
      DateTime.now().millisecondsSinceEpoch ~/ 1000 -
      _secureRandom.nextInt(_maxBackdateSeconds);

  /// Unwraps a NIP-17 gift wrap (kind 1059) → seal (kind 13) → rumor and
  /// returns the inner rumor, or `null` if any layer fails.
  ///
  /// The two id + Schnorr verifications (outer wrap and seal) are run via
  /// [verifyPart] when provided, so a caller can move that CPU-bound work off
  /// the main isolate (the remote-signer history drain does this). When
  /// [verifyPart] is `null` they run inline on the calling isolate, unchanged.
  /// The two `nip44Decrypt` calls always stay on the calling isolate — a remote
  /// signer's RPC/IPC cannot cross a `SendPort`.
  static Future<Event?> getRumorEvent(
    Nostr nostr,
    Event e, {
    GiftWrapPartVerifier? verifyPart,
    int maxPlaintextSize = maxNip17ReceivePlaintextBytes,
  }) async {
    // C16/NIP-44: validate the outer gift wrap (kind 1059) signature before
    // decrypting. Defense-in-depth — Divine relays already verify, but an
    // untrusted relay or local cache could serve a forged/tampered wrap.
    final outerValid = verifyPart != null
        ? await verifyPart(e)
        : verifyGiftWrapPart(e);
    if (!outerValid) {
      log('GiftWrap outer event invalid or unsigned, id: ${e.id}');
      return null;
    }

    var rumorText = await nostr.nostrSigner.nip44Decrypt(e.pubkey, e.content);
    if (rumorText == null) {
      return null;
    }
    if (!_plaintextFits(rumorText, maxPlaintextSize)) {
      log('GiftWrap seal plaintext exceeds the receive limit, id: ${e.id}');
      return null;
    }

    var rumorJson = jsonDecode(rumorText);
    var rumorEvent = Event.fromJson(rumorJson);

    // C16/NIP-44: validate the seal (kind 13). Unlike the outer wrap, the seal
    // is NIP-44-encrypted so no relay can ever verify it — this is the sole
    // cryptographic anchor of sender identity, so it is always enforced.
    final sealValid = verifyPart != null
        ? await verifyPart(rumorEvent)
        : verifyGiftWrapPart(rumorEvent);
    if (!sealValid) {
      log(
        "GiftWrap rumorEvent sign check result fail, id: ${e.id}, from: ${pubkeyForLogs(e.pubkey)}",
      );
      return null;
    }

    var sourceText = await nostr.nostrSigner.nip44Decrypt(
      rumorEvent.pubkey,
      rumorEvent.content,
    );
    if (sourceText == null) {
      return null;
    }
    if (!_plaintextFits(sourceText, maxPlaintextSize)) {
      log('GiftWrap rumor plaintext exceeds the receive limit, id: ${e.id}');
      return null;
    }

    final jsonObj = jsonDecode(sourceText) as Map<String, dynamic>;
    final claimedPubkey = jsonObj['pubkey'];

    // The inner rumor is intentionally NOT signature-checked: NIP-59 requires
    // it to be unsigned, and its claimed authorship is never trusted for
    // identity — the seal pubkey (authenticated above) is authoritative below.

    // NIP-17 sender verification: the seal's pubkey should match the rumor's
    // pubkey. When they differ, the rumor's claimed author is unverified while
    // the seal's pubkey IS cryptographically authenticated (it's signed).
    // Some Nostr clients in the wild produce mismatched pubkeys. Rather than
    // rejecting the message entirely, we accept it but attribute it to the
    // seal's authenticated pubkey to prevent impersonation.
    if (claimedPubkey is String && rumorEvent.pubkey != claimedPubkey) {
      log(
        'GiftWrap sender pubkey mismatch: seal=${pubkeyForLogs(rumorEvent.pubkey)} '
        'rumor=${pubkeyForLogs(claimedPubkey)}. Using seal pubkey as authoritative sender.',
      );
    }

    // Rebuild unconditionally through the Event constructor so BOTH
    // unauthenticated fields are handled at one seam: the pubkey becomes the
    // seal's (authenticated) one, and the id is DERIVED rather than trusted.
    //
    // Because the rumor is unsigned, nothing binds its claimed `id` to its
    // body — yet that id becomes the `direct_messages` primary key and the
    // reaction upsert key, so a sender who claims an id already in use can
    // silently overwrite another user's row. The constructor recomputes the
    // canonical NIP-01 id from the rumor's own fields; for a well-formed
    // sender it equals the claimed id, so there is no observable divergence,
    // and for a non-canonical one the recompute is the more correct choice.
    // DmRepository._rumorFromSlot already builds rumors exactly this way.
    // The rebuilt rumor is unsigned, per NIP-59.
    return rebuildUnsignedRumorFromJson(
      jsonObj,
      authenticatedPubkey: rumorEvent.pubkey,
    );
  }

  static Future<Event?> getGiftWrapEvent(
    Nostr nostr,
    Event e,
    String receiverPublicKey,
  ) async {
    // C3/C7/NIP-17: randomize created_at on BOTH the seal and the gift wrap,
    // independently, up to two days into the past, using a CSPRNG — so a relay
    // observer cannot correlate the two layers by timestamp nor learn the true
    // send time. The canonical time stays on the (unsigned) inner rumor.
    final sealCreatedAt = _randomizedPastTimestamp();
    final giftEventCreatedAt = _randomizedPastTimestamp();
    var rumorEventMap = e.toJson();
    rumorEventMap.remove("sig");

    var sealEventContent = await nostr.nostrSigner.nip44Encrypt(
      receiverPublicKey,
      jsonEncode(rumorEventMap),
    );
    if (sealEventContent == null) {
      return null;
    }
    var sealEvent = Event(
      nostr.publicKey,
      EventKind.sealEventKind,
      [],
      sealEventContent,
      createdAt: sealCreatedAt,
    );
    await nostr.signEvent(sealEvent);

    // [Nostr.signEvent] is a no-op when the signer returns null, which is a
    // reachable outcome for every remote signer: an Amber user dismissing the
    // approval prompt, a NIP-46 bunker RPC timing out, a NIP-07 rejection.
    // Without this check the seal ships with an empty `sig`, the wrap around
    // it is signed with a valid ephemeral key so relays accept it, the send
    // reports as delivered — and every recipient drops it at the seal
    // signature check. Returning null routes the caller to a retryable
    // failure that keeps its durable queue row instead.
    if (sealEvent.sig.isEmpty) {
      log('GiftWrap seal was not signed; refusing to publish an unsigned DM.');
      return null;
    }

    var randomPrivateKey = generatePrivateKey();
    var randomPubkey = getPublicKey(randomPrivateKey);
    var randomKey = NIP44V2.shareSecret(randomPrivateKey, receiverPublicKey);
    var giftWrapEventContent = await NIP44V2.encrypt(
      jsonEncode(sealEvent.toJson()),
      randomKey,
    );
    var giftWrapEvent = Event(
      randomPubkey,
      EventKind.giftWrap,
      [
        ["p", receiverPublicKey],
      ],
      giftWrapEventContent,
      createdAt: giftEventCreatedAt,
    );
    giftWrapEvent.sign(randomPrivateKey);

    return giftWrapEvent;
  }
}

/// Isolate-safe NIP-59 gift-wrap build over a raw private key hex.
///
/// Functionally identical to [GiftWrapUtil.getGiftWrapEvent] for a local-key
/// sender, but takes the sender's private key hex directly instead of a
/// [Nostr]/signer object, so it can run inside a `compute()` isolate — a remote
/// signer's RPC/IPC handle cannot cross a `SendPort`, but a hex string can.
/// This is the send-side counterpart of the receive-side decrypt offload.
///
/// The seal's pubkey is DERIVED from [senderPrivateKeyHex] rather than passed
/// in: it must correspond to the signing key, or both the recipient's NIP-44
/// ECDH (which keys on the seal pubkey) and the seal's Schnorr verification
/// fail. [rumorJson] is the unsigned kind-14 rumor; its `sig` is stripped
/// before sealing, and receivers derive the rumor id after unwrap.
///
/// Returns the signed kind-1059 gift wrap. Pure (no I/O, no signer object),
/// so it is safe to run inside an isolate — the same crypto primitives already
/// run inside the receive-side decrypt isolate.
Future<Event?> buildGiftWrapFromHex({
  required String senderPrivateKeyHex,
  required Map<String, dynamic> rumorJson,
  required String receiverPublicKey,
}) async {
  final sealCreatedAt = GiftWrapUtil._randomizedPastTimestamp();
  final giftEventCreatedAt = GiftWrapUtil._randomizedPastTimestamp();

  final rumorEventMap = Map<String, dynamic>.from(rumorJson)..remove('sig');

  final senderPublicKey = getPublicKey(senderPrivateKeyHex);
  final sealKey = NIP44V2.shareSecret(senderPrivateKeyHex, receiverPublicKey);
  final sealEventContent = await NIP44V2.encrypt(
    jsonEncode(rumorEventMap),
    sealKey,
  );

  final sealEvent = Event(
    senderPublicKey,
    EventKind.sealEventKind,
    [],
    sealEventContent,
    createdAt: sealCreatedAt,
  );
  // No unsigned-seal guard is needed here: [Event.sign] only no-ops when the
  // key fails `keyIsValid`, and `getPublicKey` above rejects exactly those
  // keys by throwing first. The throw propagates to the caller as a failed
  // build, which is the same safe outcome. Pinned by a test.
  sealEvent.sign(senderPrivateKeyHex);

  final randomPrivateKey = generatePrivateKey();
  final randomPubkey = getPublicKey(randomPrivateKey);
  final randomKey = NIP44V2.shareSecret(randomPrivateKey, receiverPublicKey);
  final giftWrapEventContent = await NIP44V2.encrypt(
    jsonEncode(sealEvent.toJson()),
    randomKey,
  );
  final giftWrapEvent = Event(
    randomPubkey,
    EventKind.giftWrap,
    [
      ['p', receiverPublicKey],
    ],
    giftWrapEventContent,
    createdAt: giftEventCreatedAt,
  );
  giftWrapEvent.sign(randomPrivateKey);

  return giftWrapEvent;
}
