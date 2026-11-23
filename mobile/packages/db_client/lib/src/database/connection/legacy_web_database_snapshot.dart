// ABOUTME: Decodes the original Drift web SQLite snapshot for worker import.

import 'dart:convert';
import 'dart:typed_data';

/// Restores data serialized by Drift's legacy web backend.
///
/// That backend stored the database as Latin-1 and read the separate schema
/// version before falling back to the SQLite header. Modern Drift reads only
/// the header, whose big-endian `user_version` field starts at byte 60.
Uint8List decodeLegacyWebDatabaseSnapshot(String snapshot, String? version) {
  final bytes = latin1.encode(snapshot);
  final schemaVersion = int.tryParse(version ?? '');
  if (schemaVersion != null && bytes.length >= 100) {
    ByteData.sublistView(bytes).setUint32(60, schemaVersion);
  }
  return bytes;
}
