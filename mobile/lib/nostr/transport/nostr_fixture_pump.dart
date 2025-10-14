// ABOUTME: Loads NDJSON fixture files and injects messages into transport
// ABOUTME: Enables deterministic testing with pre-recorded relay data

import 'dart:convert';
import 'package:openvine/nostr/transport/in_memory_transport.dart';

/// Pumps NDJSON fixture data into an InMemoryNostrTransport
class NostrFixturePump {
  NostrFixturePump(this.transport);

  final InMemoryNostrTransport transport;

  /// Load and inject NDJSON fixture from string content
  void pumpFromString(String ndjsonContent) {
    final lines = ndjsonContent.split('\n');

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // Validate JSON format
      dynamic parsed;
      try {
        parsed = jsonDecode(trimmed);
      } catch (e) {
        throw FormatException('Invalid JSON in fixture: $trimmed');
      }

      // Validate Nostr message format (must be array)
      if (parsed is! List) {
        throw FormatException(
          'Invalid Nostr message format (expected array): $trimmed',
        );
      }

      // Inject into transport
      transport.injectFromRelay(trimmed);
    }
  }
}
