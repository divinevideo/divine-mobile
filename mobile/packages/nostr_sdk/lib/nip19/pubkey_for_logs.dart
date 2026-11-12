// ABOUTME: Renders a pubkey as its full npub plus the full hex, for logs.
// ABOUTME: Never truncates, never throws — safe to call inside any log sink.

import 'package:nostr_sdk/client_utils/keys.dart';
import 'package:nostr_sdk/nip19/nip19.dart';

/// Redaction marker for a secret handed to a log sink.
const _redacted = '<redacted>';

/// Bech32 prefixes that carry signing material.
const _secretPrefixes = <String>['nsec1', 'ncryptsec1'];

/// [pubkey] rendered as its full npub followed by its full hex, for
/// log/debug sinks. Accepts either encoding.
///
/// Hex is what greps against relay logs and backend rows; npub is what a
/// person pastes into a client. A support log needs both, so neither is
/// dropped and neither is shortened — see the Nostr rule in AGENTS.md and the
/// guard in `scripts/check_nostr_id_log_truncation.sh`.
///
/// Returns [whenNull] for `null` — the default reads `<null>`; pass the
/// call site's own wording when the absence itself is diagnostic, such as a
/// record that predates the field. Returns a marker for the empty string, and
/// returns anything
/// that is neither an encodable 32-byte hex key nor a decodable npub — a short
/// hex, a garbage string off a relay — unchanged and whole. These call sites
/// sit inside `Log.error` handlers holding remote-supplied input, so a
/// formatter that threw would turn a diagnostic line into a crash.
///
/// An `nsec` or `ncryptsec` is redacted rather than rendered. Truncation is not
/// a security control, so the whole value is dropped: a secret must not reach a
/// log sink at all. Reaching this branch means a caller has a bug, but the
/// formatter is the last place to stop it.
String pubkeyForLogs(String? pubkey, {String whenNull = '<null>'}) {
  if (pubkey == null) return whenNull;
  if (pubkey.isEmpty) return '<empty>';
  // Bech32 is case-insensitive, and a link can carry the key behind `nostr:`
  // or stray text. No public id contains these: bech32 data has no `1` and
  // hex has no `n` or `s`.
  final lower = pubkey.toLowerCase();
  if (_secretPrefixes.any(lower.contains)) return _redacted;
  if (keyIsValid(pubkey)) {
    try {
      return '${Nip19.encodePubKey(pubkey)} ($pubkey)';
    } on Object {
      return pubkey;
    }
  }
  if (Nip19.isPubkey(pubkey)) {
    try {
      // Nip19.decode swallows its own failures and returns '', so the
      // validity check is what rejects a malformed npub. The catch stays for
      // the day that swallowing is fixed — this function must not throw.
      final hex = Nip19.decode(pubkey);
      if (keyIsValid(hex)) return '$pubkey ($hex)';
    } on Object {
      return pubkey;
    }
  }
  return pubkey;
}
