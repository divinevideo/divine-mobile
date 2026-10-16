// ABOUTME: Account-specific durable sound request checkpoints in Drift.
// ABOUTME: Stores domain records separately and commits transitions atomically.
import 'dart:convert';

import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';

class SoundRequestDriftStore implements SoundRequestStore {
  SoundRequestDriftStore(this._dao);
  final SoundRequestStateDao _dao;

  @override
  Future<SoundRequestSnapshot> read(String ownerPubkey) async {
    final rows = await _dao.readAccount(ownerPubkey);
    final json = <String, dynamic>{
      'requests': <String, dynamic>{},
      'audioByVideo': <String, dynamic>{},
      'jobs': <String, dynamic>{},
      'metadataBaselineByVideo': <String, dynamic>{},
      'approvedVideos': <String>[],
      'metadataPublishedVideos': <String>[],
    };
    for (final row in rows) {
      switch (row.section) {
        case 'requests':
        case 'audioByVideo':
        case 'jobs':
        case 'metadataBaselineByVideo':
          (json[row.section] as Map<String, dynamic>)[row.recordKey] =
              jsonDecode(row.value);
        case 'approvedVideos':
        case 'metadataPublishedVideos':
          (json[row.section] as List).add(row.recordKey);
        default:
          throw const FormatException('Unknown sound request state section');
      }
    }
    return SoundRequestSnapshot.fromJson(json);
  }

  @override
  Future<void> write(String ownerPubkey, SoundRequestSnapshot snapshot) =>
      _dao.writeAccount(ownerPubkey, {
        for (final entry in snapshot.toJson().entries)
          entry.key: switch (entry.value) {
            final Map<String, dynamic> records => {
              for (final record in records.entries)
                record.key: jsonEncode(record.value),
            },
            final List records => {
              for (final record in records) record as String: 'true',
            },
            _ => throw const FormatException('Invalid sound request state'),
          },
      });
}
