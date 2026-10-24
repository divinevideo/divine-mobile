import 'dart:convert';
import 'package:db_client/db_client.dart';

/// Persistence boundary; merging and protocol behavior remain in the engine.
abstract interface class AccountStateStorage {
  Future<String?> read();
  Future<void> write(String value);
}

/// Structured durable records; only changed fields/sources are rewritten.
class DriftAccountStateStorage implements AccountStateStorage {
  DriftAccountStateStorage(
    this.dao, {
    required this.owner,
    required this.namespace,
  });
  final AccountSyncDao dao;
  final String owner;
  final String namespace;
  @override
  Future<String?> read() async {
    final rows = await dao.readState(owner, namespace);
    if (rows.isEmpty) return null;
    return jsonEncode({
      'version': 1,
      'pending': rows.any(
        (row) =>
            row.section == 'meta' &&
            row.recordKey == 'pending' &&
            row.value == 'true',
      ),
      'fieldTags': {
        for (final row in rows)
          if (row.section == 'fieldTags') row.recordKey: jsonDecode(row.value),
      },
      'entries': {
        for (final row in rows)
          if (row.section == 'entries') row.recordKey: jsonDecode(row.value),
      },
      'events': [
        for (final row in rows)
          if (row.section == 'events') jsonDecode(row.value),
      ],
    });
  }

  @override
  Future<void> write(String value) async {
    final state = jsonDecode(value) as Map<String, dynamic>;
    await dao.writeState(owner, namespace, {
      'meta': {'pending': jsonEncode(state['pending'])},
      'fieldTags': {
        for (final entry
            in ((state['fieldTags'] as Map<String, dynamic>?) ?? {}).entries)
          entry.key: jsonEncode(entry.value),
      },
      'entries': {
        for (final entry in (state['entries'] as Map<String, dynamic>).entries)
          entry.key: jsonEncode(entry.value),
      },
      'events': {
        for (final event
            in (state['events'] as List).cast<Map<String, dynamic>>())
          event['id'] as String: jsonEncode(event),
      },
    });
  }
}
