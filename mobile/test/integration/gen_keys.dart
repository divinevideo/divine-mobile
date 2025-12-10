// ABOUTME: Temporary script to generate Nostr keypair for testing
// ABOUTME: Run with: dart test/integration/gen_keys.dart

import 'package:nostr_sdk/nostr_sdk.dart';

void main() {
  final keys = Keys.generate();
  print('=== Throwaway Nostr Test Keys ===');
  print('Private key (nsec): ${keys.secretKey().toBech32()}');
  print('Private key (hex): ${keys.secretKey().toHex()}');
  print('Public key (npub): ${keys.publicKey().toBech32()}');
  print('Public key (hex): ${keys.publicKey().toHex()}');
}
