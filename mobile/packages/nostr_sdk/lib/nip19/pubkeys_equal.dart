// ABOUTME: Compares hexadecimal Nostr pubkeys in their canonical form.
// ABOUTME: Keeps case-insensitive identity checks consistent across packages.

/// Whether two hexadecimal Nostr pubkeys identify the same key.
///
/// Hex is case-insensitive. This comparison deliberately does not validate
/// either value so callers can use it after their own boundary validation.
bool pubkeysEqual(String first, String second) =>
    first.toLowerCase() == second.toLowerCase();

/// Whether [pubkeys] contains more than one case-insensitive identity.
bool containsDistinctPubkeys(Iterable<String> pubkeys) {
  final iterator = pubkeys.iterator;
  if (!iterator.moveNext()) return false;
  final first = iterator.current;
  while (iterator.moveNext()) {
    if (!pubkeysEqual(iterator.current, first)) return true;
  }
  return false;
}
