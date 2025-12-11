// ABOUTME: Temporary script to generate Nostr keypair for testing
// ABOUTME: Run with: dart test/integration/gen_keys.dart

import 'package:nostr_key_manager/nostr_key_manager.dart';

void main() {
  final keyPair = Keychain.generate();
  print('=== Throwaway Nostr Test Keys ===');
  print('Private key (hex): ${keyPair.private}');
  print('Public key (hex): ${keyPair.public}');
}
