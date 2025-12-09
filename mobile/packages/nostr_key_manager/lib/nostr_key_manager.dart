/// Secure Nostr key management with hardware-backed persistence.
///
/// This package provides:
/// - [NostrKeyManager]: Main key management class for generating, importing,
///   and exporting Nostr keys
/// - [SecureKeyStorageService]: Hardware-backed secure storage for keys
/// - [SecureKeyContainer]: Memory-safe container for cryptographic keys
/// - [NsecBunkerClient]: NIP-46 remote signer client for web platforms
/// - [NostrEncoding]: Utilities for encoding/decoding Nostr keys (npub/nsec)
library nostr_key_manager;

export 'src/nostr_encoding.dart';
export 'src/nostr_key_manager.dart';
export 'src/nsec_bunker_client.dart';
export 'src/platform_secure_storage.dart';
export 'src/secure_key_container.dart';
export 'src/secure_key_storage_service.dart';
