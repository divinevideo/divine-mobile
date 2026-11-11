// ABOUTME: Patterns for Nostr private keys and the redaction the log sink
// ABOUTME: applies, so no log line can carry an nsec or ncryptsec (#10385).

/// Nostr private keys: bech32 `nsec` and NIP-49 `ncryptsec`, in any case.
///
/// An nsec carries the whole key in its first 52 data characters (the last
/// six are checksum), so a paste cut short of the checksum still matches.
///
/// Neither can match a public id: bech32 data has no `1` and hex has no `n`
/// or `s`, so `nsec1` and `ncryptsec1` never occur inside one.
final List<RegExp> nostrPrivateKeyPatterns = List.unmodifiable([
  RegExp('nsec1[a-z0-9]{52,}', caseSensitive: false),
  RegExp('ncryptsec1[a-z0-9]+', caseSensitive: false),
]);

/// Replacement for a redacted key.
const redactedNostrPrivateKey = '[REDACTED]';

// One scan that rules out almost every log line before the full patterns run.
final _mayCarryNostrPrivateKey = RegExp(
  'n(?:crypt)?sec1',
  caseSensitive: false,
);

/// [text] with every Nostr private key replaced by
/// [redactedNostrPrivateKey].
///
/// The log sink applies this to every line, so a key that reaches a `Log`
/// call through an untrusted value, such as a link, is never stored.
String redactNostrPrivateKeys(String text) {
  if (!_mayCarryNostrPrivateKey.hasMatch(text)) return text;
  var redacted = text;
  for (final pattern in nostrPrivateKeyPatterns) {
    redacted = redacted.replaceAll(pattern, redactedNostrPrivateKey);
  }
  return redacted;
}
