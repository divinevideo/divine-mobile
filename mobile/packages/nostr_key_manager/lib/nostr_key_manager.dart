/// Secure Nostr key management with hardware-backed persistence.
///
/// This package provides secure key management with hardware-backed storage.
///
/// For key validation and encoding, use nostr_sdk's utilities:
/// - `keyIsValid()` from `nostr_sdk/client_utils/keys.dart` for validation
/// - `Nip19` class from `nostr_sdk/nip19/nip19.dart` for encoding/decoding
library;

export 'src/nostr_key_manager.dart';
export 'src/nsec_bunker_client.dart';
export 'src/platform_secure_storage.dart';
export 'src/secure_key_container.dart';
export 'src/secure_key_storage.dart';
