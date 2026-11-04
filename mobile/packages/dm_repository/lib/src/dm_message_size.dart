// ABOUTME: Size ceiling for a NIP-17 rumor, derived from the NIP-44 u16 length
// ABOUTME: prefix and the double encryption NIP-17 performs.

/// How large a NIP-17 rumor may serialize to before the send is refused.
///
/// ## Where the hard ceiling comes from
///
/// NIP-44 v2 defines two length-prefix forms, but this client writes only the
/// 2-byte `u16` (see `NIP44V2.pad`), so it cannot encrypt a plaintext of
/// 65,536 bytes or more. NIP-17 then encrypts **twice**: the seal encrypts the
/// rumor, and the gift wrap encrypts the whole seal *event JSON*, whose
/// `content` is the seal's base64 payload. Base64 costs 4/3, so the outer
/// encrypt meets the u16 wall long before the inner one does.
///
/// Measured against the production wrap builder rather than derived: a rumor
/// serializing to 40,969 bytes wraps, 40,970 throws, and that boundary is
/// **invariant in the rumor's size** — it lands identically with 0, 50 or 200
/// extra `p` tags (#7331).
///
/// ## Why the bound is on the rumor, not on the message body
///
/// The NIP-44 plaintext is `jsonEncode(rumor)`, not the body: tags count. The
/// content ceiling therefore moves with the tag set — 40,682 bytes for a 1:1
/// send, but 26,082 with 200 recipients — while the rumor ceiling does not.
/// Bounding the rumor is both the correct quantity and the one that needs no
/// per-shape adjustment, so a group send, a reply with an `e` tag, and a
/// future tag addition are all covered without changing this number.
///
/// The remaining 969 bytes of headroom cover rounding rather than growth:
/// the guard measures the exact rumor that is handed to the wrap builder, and
/// nothing adds tags between the two.
///
/// ## Not every inbox relay stores a rumor this large
///
/// nos.lol, one of the app's default DM inbox relays
/// (`IndexerRelayConfig.dmInboxTaggedRelays`), refuses the gift wrap once the
/// rumor passes about 28.7 KB. That costs one stored copy, not delivery, so
/// this bound deliberately stays at the NIP-44 ceiling (#10317).
const int maxDmRumorBytes = 40000;
