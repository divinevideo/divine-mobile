// ABOUTME: Separates unreadable recovery archives from live permission evidence.
// ABOUTME: Normalizes only after durable preservation; unresolved scopes stay held.

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:models/models.dart';
import 'package:openvine/services/curated_lists/curated_list_recovery_record.dart';
import 'package:openvine/services/curated_lists/curated_list_session_coordinator.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum CuratedListRecoveryReadStatus { absent, healthy, corrupt }

class CuratedListRecoveryException implements Exception {
  const CuratedListRecoveryException();

  @override
  String toString() => 'Curated-list recovery needs repair';
}

class _CuratedListRecoveryPreservationRefused
    extends CuratedListRecoveryException {
  const _CuratedListRecoveryPreservationRefused();
}

class CuratedListRecoveryRead {
  const CuratedListRecoveryRead({
    required this.records,
    required this.status,
    this.raw,
    this.corruptCoordinates = const {},
    this.ownerWide = false,
  });

  final Map<String, CuratedListRecoveryRecord> records;
  final CuratedListRecoveryReadStatus status;
  final String? raw;
  final Set<String> corruptCoordinates;
  final bool ownerWide;
}

class CuratedListLegacyRead {
  const CuratedListLegacyRead(this.rows, {this.raw, this.corrupt = false});

  final List<CuratedList> rows;
  final String? raw;
  final bool corrupt;
}

abstract final class CuratedListRecoveryStorage {
  static const quarantinePrefix = 'curated_list_recovery_quarantine_v1:';
  static const generationPrefix = 'curated_list_recovery_generation_v1:';
  static const sharedQuarantineKey =
      'curated_list_recovery_shared_quarantine_v1';

  /// Unknown-owner bytes never become the incoming account's private records.
  static const List<String> deviceScopedPrefsKeys = [sharedQuarantineKey];

  static String quarantineKey(String owner) => '$quarantinePrefix$owner';
  static String generationKey(String owner) => '$generationPrefix$owner';

  static String _raw(Object encoded) =>
      encoded is String ? encoded : jsonEncode(encoded);

  static CuratedListLegacyRead legacyRead(SharedPreferences prefs) {
    final encoded = prefs.get('curated_lists');
    if (encoded == null) return const CuratedListLegacyRead([]);
    final rows = <CuratedList>[];
    var corrupt = false;
    try {
      for (final row in jsonDecode(encoded as String) as List) {
        try {
          rows.add(CuratedList.fromJson(row as Map<String, dynamic>));
        } on Object {
          corrupt = true;
        }
      }
    } on Object {
      corrupt = true;
    }
    return CuratedListLegacyRead(
      rows,
      raw: corrupt ? _raw(encoded) : null,
      corrupt: corrupt,
    );
  }

  static List<CuratedList> legacyRows(SharedPreferences prefs) =>
      legacyRead(prefs).rows;

  static bool legacyNeedsRepair(SharedPreferences prefs) {
    final source = legacyRead(prefs);
    final marker = prefs.get('current_user_pubkey_hex');
    final validOwner = RegExp(r'^[0-9a-fA-F]{64}$');
    final unknown = source.rows.any((row) {
      if (row.pendingPlaintextEventIds.isEmpty &&
          !row.hasPendingPermissionRecovery) {
        return false;
      }
      final owner = row.pubkey ?? (marker is String ? marker : null);
      return owner == null || !validOwner.hasMatch(owner);
    });
    return repairHeld(prefs) ||
        source.corrupt ||
        unknown ||
        _held(prefs, sharedQuarantineKey);
  }

  static bool repairHeld(SharedPreferences prefs) {
    final sessions = CuratedListSessionCoordinator.forPreferences(prefs);
    return sessions.recoveryRepairInProgress ||
        sessions.recoveryReadbackUnknown;
  }

  static Future<T> holdRepair<T>(
    SharedPreferences prefs,
    Future<T> Function() repair,
  ) =>
      CuratedListSessionCoordinator.forPreferences(prefs)
          .holdRecoveryRepair(repair);

  static Future<void> refreshEvidence(SharedPreferences prefs) async {
    final sessions = CuratedListSessionCoordinator.forPreferences(prefs);
    if (!sessions.recoveryReadbackUnknown) return;
    try {
      await prefs.reload();
      sessions.acknowledgeRecoveryReadback();
    } on Object {
      throw const CuratedListRecoveryException();
    }
  }

  static CuratedListRecoveryRead read(SharedPreferences prefs, String key) {
    final encoded = prefs.get(key);
    if (encoded == null) {
      return const CuratedListRecoveryRead(
        records: {},
        status: CuratedListRecoveryReadStatus.absent,
      );
    }
    return _decode(_raw(encoded));
  }

  static CuratedListRecoveryRead _decode(String encoded) {
    final records = <String, CuratedListRecoveryRecord>{};
    final corruptCoordinates = <String>{};
    var ownerWide = false;
    try {
      final decoded = jsonDecode(encoded) as Map<String, dynamic>;
      for (final entry in decoded.entries) {
        try {
          records[entry.key] = CuratedListRecoveryRecord.fromJson(
            entry.value as Map<String, dynamic>,
          );
        } on Object {
          corruptCoordinates.add(entry.key);
        }
      }
    } on Object {
      ownerWide = true;
    }
    final corrupt = ownerWide || corruptCoordinates.isNotEmpty;
    return CuratedListRecoveryRead(
      records: records,
      status: corrupt
          ? CuratedListRecoveryReadStatus.corrupt
          : CuratedListRecoveryReadStatus.healthy,
      raw: corrupt ? encoded : null,
      corruptCoordinates: corruptCoordinates,
      ownerWide: ownerWide,
    );
  }

  static Map<String, dynamic>? _archive(SharedPreferences prefs, String key) {
    final encoded = prefs.get(key);
    if (encoded == null) return null;
    try {
      final decoded = jsonDecode(encoded as String) as Map<String, dynamic>;
      if (decoded['version'] != null && decoded['version'] != 2) {
        throw const CuratedListRecoveryException();
      }
      List<String>.from(decoded['rawBuckets'] as List);
      List<String>.from(decoded['recordBackups'] as List? ?? const []);
      List<String>.from(decoded['unresolvedCoordinates'] as List? ?? const []);
      if (decoded['normalized'] != null && decoded['normalized'] is! bool ||
          decoded['needsRepair'] != null && decoded['needsRepair'] is! bool) {
        throw const CuratedListRecoveryException();
      }
      final staged = _decode(jsonEncode(decoded['records']));
      if (staged.status != CuratedListRecoveryReadStatus.healthy) {
        throw const CuratedListRecoveryException();
      }
      return decoded;
    } on Object {
      throw const CuratedListRecoveryException();
    }
  }

  static bool _held(SharedPreferences prefs, String key) {
    if (!prefs.containsKey(key)) return false;
    try {
      return _archive(prefs, key)?['needsRepair'] != false;
    } on CuratedListRecoveryException {
      return true;
    }
  }

  /// Staging records are live only until normalization commits. Afterwards
  /// archives are evidence for audited repair, never a source of new ACKs.
  static Map<String, CuratedListRecoveryRecord> preservedRecords(
    SharedPreferences prefs,
    String owner, {
    String? liveKey,
  }) {
    final saved = _archive(prefs, quarantineKey(owner));
    if (saved == null || saved['normalized'] == true) return {};
    // A crash can occur after the live write but before the final marker.
    // Once a readable live journal differs from its pre-write value, it is
    // authoritative, including ACKs that arrived after that write.
    if (saved['version'] == 2 &&
        liveKey != null &&
        read(prefs, liveKey).status == CuratedListRecoveryReadStatus.healthy &&
        prefs.get(liveKey) != saved['originalLiveValue']) {
      return {};
    }
    return _decode(jsonEncode(saved['records'])).records;
  }

  static bool needsRepair(SharedPreferences prefs, String key, String owner) =>
      repairHeld(prefs) ||
      read(prefs, key).status == CuratedListRecoveryReadStatus.corrupt ||
      _held(prefs, quarantineKey(owner));

  static Future<Map<String, dynamic>> _preserveArchive(
    SharedPreferences prefs,
    String archiveKey, {
    required Map<String, CuratedListRecoveryRecord> records,
    String? raw,
    Set<String> unresolvedCoordinates = const {},
    bool ownerWide = false,
    Object? originalLiveValue,
  }) async {
    Map<String, dynamic>? previous;
    String? unreadableArchive;
    var holdsWholeOwner = ownerWide;
    try {
      previous = _archive(prefs, archiveKey);
    } on CuratedListRecoveryException {
      unreadableArchive = _raw(prefs.get(archiveKey)!);
      holdsWholeOwner = true;
    }
    final envelope = <String, dynamic>{
      'version': 2,
      'rawBuckets': <String>{
        ...List<String>.from(previous?['rawBuckets'] as List? ?? const []),
        ?raw,
        ?unreadableArchive,
      }.toList(growable: false),
      'recordBackups': <String>{
        ...List<String>.from(previous?['recordBackups'] as List? ?? const []),
        if (previous != null) jsonEncode(previous['records']),
      }.toList(growable: false),
      'records': {for (final e in records.entries) e.key: e.value.toJson()},
      'originalLiveValue': originalLiveValue,
      'normalized': false,
      'needsRepair': true,
      'ownerWide':
          holdsWholeOwner ||
          previous?['needsRepair'] != false && previous?['ownerWide'] == true,
      'unresolvedCoordinates': <String>{
        ...List<String>.from(
          previous?['needsRepair'] == false
              ? const []
              : previous?['unresolvedCoordinates'] as List? ?? const [],
        ),
        ...unresolvedCoordinates,
      }.toList(growable: false),
    };
    if (!await writeVerified(prefs, archiveKey, jsonEncode(envelope))) {
      throw const _CuratedListRecoveryPreservationRefused();
    }
    return envelope;
  }

  /// Preserves current evidence without erasing any earlier raw backup.
  static Future<bool> preserve(
    SharedPreferences prefs,
    String key,
    String owner,
    Map<String, CuratedListRecoveryRecord> records,
  ) async {
    final original = read(prefs, key);
    try {
      await _preserveArchive(
        prefs,
        quarantineKey(owner),
        records: records,
        raw: original.raw,
        unresolvedCoordinates: original.corruptCoordinates,
        ownerWide: original.ownerWide,
        originalLiveValue: prefs.get(key),
      );
      return true;
    } on _CuratedListRecoveryPreservationRefused {
      return false;
    }
  }

  /// Called under the shared exclusive queue: backup/readback, valid live
  /// journal, then the normalization marker. Publication holds remain intact.
  static Future<void> normalize(
    SharedPreferences prefs,
    String key,
    String owner,
    Map<String, CuratedListRecoveryRecord> records,
  ) async {
    final readResult = read(prefs, key);
    try {
      final archive = _archive(prefs, quarantineKey(owner));
      if (readResult.status != CuratedListRecoveryReadStatus.corrupt &&
          (archive == null || archive['normalized'] == true)) {
        return;
      }
    } on CuratedListRecoveryException {
      // Preserve the unreadable archive itself rather than overwriting it.
    }
    await holdRepair(prefs, () async {
      final envelope = await _preserveArchive(
        prefs,
        quarantineKey(owner),
        records: records,
        raw: readResult.raw,
        unresolvedCoordinates: readResult.corruptCoordinates,
        ownerWide: readResult.ownerWide,
        originalLiveValue: prefs.get(key),
      );
      if (!await writeVerified(prefs, key, jsonEncode(envelope['records']))) {
        throw const CuratedListRecoveryException();
      }
      envelope['normalized'] = true;
      if (!await writeVerified(
        prefs,
        quarantineKey(owner),
        jsonEncode(envelope),
      )) {
        throw const CuratedListRecoveryException();
      }
    });
  }

  /// A malformed shared row has no provable owner. Archive its original bytes
  /// at device scope before replacing the active cache with validated rows.
  static Future<void> normalizeLegacy(
    SharedPreferences prefs, {
    String? legacyOwner,
  }) async {
    final original = legacyRead(prefs);
    final validOwner = RegExp(r'^[0-9a-fA-F]{64}$');
    final unknownRows = original.rows.where((row) {
      if (row.pendingPlaintextEventIds.isEmpty &&
          !row.hasPendingPermissionRecovery) {
        return false;
      }
      final owner = row.pubkey ?? legacyOwner;
      return owner == null || !validOwner.hasMatch(owner);
    }).toSet();
    var incompleteArchive = false;
    try {
      final archive = _archive(prefs, sharedQuarantineKey);
      incompleteArchive = archive != null && archive['normalized'] != true;
    } on CuratedListRecoveryException {
      incompleteArchive = true;
    }
    if (!original.corrupt && unknownRows.isEmpty && !incompleteArchive) return;
    await holdRepair(prefs, () async {
      final envelope = await _preserveArchive(
        prefs,
        sharedQuarantineKey,
        records: {},
        raw:
            original.raw ??
            (unknownRows.isEmpty ? null : _raw(prefs.get('curated_lists')!)),
        ownerWide: true,
        originalLiveValue: prefs.get('curated_lists'),
      );
      if (!await writeVerified(
        prefs,
        'curated_lists',
        jsonEncode(
          original.rows
              .where((row) => !unknownRows.contains(row))
              .map((row) => row.toJson())
              .toList(),
        ),
      )) {
        throw const CuratedListRecoveryException();
      }
      envelope['normalized'] = true;
      if (!await writeVerified(
        prefs,
        sharedQuarantineKey,
        jsonEncode(envelope),
      )) {
        throw const CuratedListRecoveryException();
      }
    });
  }

  /// Includes live evidence and generations: a late ACK makes old repair
  /// proposals stale even when the raw archive itself has not changed.
  static String repairSnapshot(SharedPreferences prefs, String owner) {
    final keys =
        prefs
            .getKeys()
            .where(
              (key) =>
                  key.startsWith('curated_list_recovery_') ||
                  key == 'curated_lists',
            )
            .toList()
          ..sort();
    return sha256
        .convert(
          utf8.encode(
            jsonEncode({
              'owner': owner,
              'values': {for (final key in keys) key: prefs.get(key)},
            }),
          ),
        )
        .toString();
  }

  /// A complete, independently verified reconstruction, never a public list
  /// payload or an empty relay result. The caller must audit the retained raw
  /// evidence; structural validation does not prove absent deletion requests.
  static Map<String, CuratedListRecoveryRecord> validateRepairRecords(
    String raw,
  ) {
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final readResult = _decode(raw);
    if (readResult.status != CuratedListRecoveryReadStatus.healthy ||
        readResult.records.isEmpty) {
      throw const CuratedListRecoveryException();
    }
    final id = RegExp(r'^[0-9a-f]{64}$');
    for (final entry in readResult.records.entries) {
      final record = entry.value;
      final json = decoded[entry.key] as Map<String, dynamic>;
      if (entry.key.isEmpty ||
          record.isEmpty ||
          record.plaintextEventIds.any((value) => !id.hasMatch(value)) ||
          record.acceptedEventId != null &&
              !id.hasMatch(record.acceptedEventId!) ||
          record.visibility?.allowedCollaborators.any(
                (value) => !id.hasMatch(value),
              ) ==
              true ||
          (record.acceptedEventId == null) != (record.acceptedAt == null) ||
          record.permissionEpoch < 0 ||
          json['visibility'] != null && record.visibility == null ||
          record.visibility != null && record.acceptedEventId == null) {
        throw const CuratedListRecoveryException();
      }
    }
    return readResult.records;
  }

  static Future<bool> markRepaired(SharedPreferences prefs, String key) async {
    final archive = _archive(prefs, key);
    if (archive == null) return false;
    archive['normalized'] = true;
    archive['needsRepair'] = false;
    archive['unresolvedCoordinates'] = <String>[];
    archive['ownerWide'] = false;
    return writeVerified(prefs, key, jsonEncode(archive));
  }

  static bool coversUnresolved(
    SharedPreferences prefs,
    String owner,
    Map<String, CuratedListRecoveryRecord> records,
  ) {
    final archive = _archive(prefs, quarantineKey(owner));
    if (archive == null ||
        archive['normalized'] != true ||
        archive['needsRepair'] == false) {
      return false;
    }
    return List<String>.from(
      archive['unresolvedCoordinates'] as List? ?? const [],
    ).every(records.containsKey);
  }

  static bool canRepairShared(SharedPreferences prefs) {
    try {
      final archive = _archive(prefs, sharedQuarantineKey);
      return archive?['normalized'] == true && archive?['needsRepair'] == true;
    } on CuratedListRecoveryException {
      return false;
    }
  }

  static Future<bool> writeVerified(
    SharedPreferences prefs,
    String key,
    String value,
  ) async {
    if (!await persist(prefs, () => prefs.setString(key, value))) return false;
    try {
      await prefs.reload();
    } on Object {
      CuratedListSessionCoordinator.forPreferences(prefs)
          .markRecoveryReadbackUnknown();
      throw const CuratedListRecoveryException();
    }
    return prefs.get(key) == value;
  }

  static Future<bool> persist(
    SharedPreferences prefs,
    Future<bool> Function() operation,
  ) async {
    try {
      final saved = await operation();
      if (!saved) await prefs.reload();
      return saved;
    } on Object {
      try {
        await prefs.reload();
      } on Object {
        CuratedListSessionCoordinator.forPreferences(prefs)
            .markRecoveryReadbackUnknown();
        throw const CuratedListRecoveryException();
      }
      throw const CuratedListRecoveryException();
    }
  }
}
