// ABOUTME: Separates unreadable recovery archives from live permission evidence.
// ABOUTME: Normalizes only after durable preservation; unresolved scopes stay held.

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:models/models.dart';
import 'package:openvine/services/curated_lists/curated_list_recovery_record.dart';
import 'package:openvine/services/curated_lists/curated_list_session_coordinator.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'curated_list_recovery_shared_archive.dart';

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

  static String quarantineKey(String owner) =>
      '$quarantinePrefix${owner.toLowerCase()}';
  static String generationKey(String owner) =>
      '$generationPrefix${owner.toLowerCase()}';

  static Set<String> ownerKeys(
    SharedPreferences prefs,
    String prefix,
    String owner,
  ) {
    final normalized = _provenRecoveryOwner(owner);
    if (normalized == null) return {'$prefix$owner'};
    return {
      '$prefix$normalized',
      for (final key in prefs.getKeys())
        if (key.startsWith(prefix) &&
            _provenRecoveryOwner(key.substring(prefix.length)) == normalized)
          key,
    };
  }

  static String _raw(Object encoded) =>
      encoded is String ? encoded : jsonEncode(encoded);

  static CuratedListLegacyRead legacyRead(
    SharedPreferences prefs, {
    String storageKey = 'curated_lists',
  }) {
    final encoded = prefs.get(storageKey);
    if (encoded == null) return const CuratedListLegacyRead([]);
    final rows = <CuratedList>[];
    var corrupt = false;
    try {
      for (final row in jsonDecode(encoded as String) as List) {
        try {
          final fields = row as Map<String, dynamic>;
          final list = CuratedList.fromJson(fields);
          final owner = _provenRecoveryOwner(list.pubkey);
          if (owner != null && _provenRowOwner(fields) == null ||
              list.pubkey == null && _hasExplicitRecoveryOwnerLabels(fields)) {
            corrupt = true;
            continue;
          }
          rows.add(owner == null ? list : list.copyWith(pubkey: owner));
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

  static final _legacyVerdicts = Expando<_SharedRecoveryVerdict>();

  static bool legacyNeedsRepair(SharedPreferences prefs, {String? owner}) {
    // Session/readback flags are deliberately outside the content cache.
    if (repairHeld(prefs)) return true;
    final live = prefs.get('curated_lists');
    final marker = prefs.get('current_user_pubkey_hex');
    final archived = prefs.get(sharedQuarantineKey);
    var verdict = _legacyVerdicts[prefs];
    if (verdict == null ||
        verdict.live != live ||
        verdict.marker != marker ||
        verdict.archive != archived) {
      final scope = _sharedRecoveryScope(
        live,
        legacyOwner: _provenRecoveryOwner(marker),
      );
      if (archived != null) {
        try {
          scope.include(
            _sharedRecoveryScope(_archive(prefs, sharedQuarantineKey)),
          );
        } on CuratedListRecoveryException {
          scope.unknown = true;
        }
      }
      verdict = _SharedRecoveryVerdict(live, marker, archived, scope);
      _legacyVerdicts[prefs] = verdict;
    }
    return verdict.scope.holds(_provenRecoveryOwner(owner));
  }

  /// Under cleanup's exclusive queue, remove every provable retained copy.
  /// Opaque evidence is preserved and reports incomplete deletion explicitly.
  static Future<void> removeOwnerFromSharedEvidence(
    SharedPreferences prefs,
    String owner,
  ) async {
    if (!prefs.containsKey('curated_lists') &&
        !prefs.containsKey(sharedQuarantineKey)) {
      return;
    }
    final normalized = _provenRecoveryOwner(owner);
    if (normalized == null) throw const CuratedListRecoveryException();
    var incomplete = false;
    await holdRepair(prefs, () async {
      for (final key in ['curated_lists', sharedQuarantineKey]) {
        if (!prefs.containsKey(key)) continue;
        final redacted = _redactSharedRecovery(prefs.get(key), normalized);
        incomplete |= redacted.unknown;
        if (redacted.changed &&
            !await writeVerified(prefs, key, redacted.value! as String)) {
          throw const CuratedListRecoveryException();
        }
      }
    });
    if (incomplete) throw const CuratedListRecoveryException();
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
          decoded['needsRepair'] != null && decoded['needsRepair'] is! bool ||
          decoded['aliasRepairRequired'] != null &&
              decoded['aliasRepairRequired'] is! bool) {
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
    String? archiveKey,
  }) {
    final saved = _archive(prefs, archiveKey ?? quarantineKey(owner));
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
      ownerKeys(
        prefs,
        quarantinePrefix,
        owner,
      ).any((alias) => _held(prefs, alias));

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
    bool? aliasRepairRequired;
    try {
      final archive = _archive(prefs, quarantineKey(owner));
      if (archive?['normalized'] == false &&
          readResult.status == CuratedListRecoveryReadStatus.healthy) {
        aliasRepairRequired = archive?['aliasRepairRequired'] as bool?;
      }
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
      envelope.remove('aliasRepairRequired');
      if (aliasRepairRequired != null) {
        envelope['needsRepair'] = aliasRepairRequired;
      }
      if (!await writeVerified(
        prefs,
        quarantineKey(owner),
        jsonEncode(envelope),
      )) {
        throw const CuratedListRecoveryException();
      }
    });
  }

  /// Migrates prior case-variant keys with backup/readback before removal.
  /// No normalization may replay the alias again after a later live ACK.
  static Future<void> normalizeOwnerAliases(
    SharedPreferences prefs,
    String livePrefix,
    String owner,
    Map<String, CuratedListRecoveryRecord> records,
  ) async {
    final canonicalLive = '$livePrefix${owner.toLowerCase()}';
    final canonicalArchive = quarantineKey(owner);
    final aliases = {
      ...ownerKeys(
        prefs,
        livePrefix,
        owner,
      ).where((key) => key != canonicalLive && prefs.containsKey(key)),
      ...ownerKeys(
        prefs,
        quarantinePrefix,
        owner,
      ).where((key) => key != canonicalArchive && prefs.containsKey(key)),
    };
    if (aliases.isEmpty) return;
    var requiresRepair =
        read(prefs, canonicalLive).status ==
        CuratedListRecoveryReadStatus.corrupt;
    try {
      final saved = _archive(prefs, canonicalArchive);
      requiresRepair |=
          saved?['aliasRepairRequired'] as bool? ??
          _held(prefs, canonicalArchive);
    } on CuratedListRecoveryException {
      requiresRepair = true;
    }
    await holdRepair(prefs, () async {
      var ownerWide = false;
      final unresolved = <String>{};
      final originalLiveValue = prefs.get(canonicalLive);
      Map<String, dynamic>? envelope;
      for (final key in aliases) {
        if (key.startsWith(livePrefix)) {
          final source = read(prefs, key);
          requiresRepair |=
              source.status == CuratedListRecoveryReadStatus.corrupt;
          ownerWide |= source.ownerWide;
          unresolved.addAll(source.corruptCoordinates);
        } else {
          requiresRepair |= _held(prefs, key);
          try {
            final source = _archive(prefs, key)!;
            ownerWide |= source['ownerWide'] == true;
            unresolved.addAll(
              List<String>.from(
                source['unresolvedCoordinates'] as List? ?? const [],
              ),
            );
          } on CuratedListRecoveryException {
            ownerWide = true;
          }
        }
        envelope = await _preserveArchive(
          prefs,
          canonicalArchive,
          records: records,
          raw: _raw(prefs.get(key)!),
          unresolvedCoordinates: unresolved,
          ownerWide: ownerWide,
          originalLiveValue: originalLiveValue,
        );
      }
      envelope!['aliasRepairRequired'] = requiresRepair;
      if (!await writeVerified(prefs, canonicalArchive, jsonEncode(envelope))) {
        throw const CuratedListRecoveryException();
      }
      if (!await writeVerified(
        prefs,
        canonicalLive,
        jsonEncode(envelope['records']),
      )) {
        throw const CuratedListRecoveryException();
      }
      for (final key in aliases) {
        if (!await removeVerified(prefs, key)) {
          throw const CuratedListRecoveryException();
        }
      }
      envelope['normalized'] = true;
      envelope['needsRepair'] = requiresRepair;
      envelope.remove('aliasRepairRequired');
      if (!await writeVerified(prefs, canonicalArchive, jsonEncode(envelope))) {
        throw const CuratedListRecoveryException();
      }
    });
  }

  /// Preserves exact mixed-cache bytes before replacing invalid live rows.
  /// Raw-row ownership determines which accounts retain a publication hold.
  static Future<void> normalizeLegacy(
    SharedPreferences prefs, {
    String? legacyOwner,
  }) async {
    final original = legacyRead(prefs);
    final unknownSource = _sharedRecoveryScope(
      prefs.get('curated_lists'),
      legacyOwner: _provenRecoveryOwner(legacyOwner),
    ).unknown;
    final unknownRows = original.rows.where((row) {
      if (row.pendingPlaintextEventIds.isEmpty &&
          !row.hasPendingPermissionRecovery) {
        return false;
      }
      final owner = row.pubkey ?? legacyOwner;
      return !NostrHexUtils.isValidPubkey(owner);
    }).toSet();
    var incompleteArchive = false;
    try {
      final archive = _archive(prefs, sharedQuarantineKey);
      incompleteArchive = archive != null && archive['normalized'] != true;
    } on CuratedListRecoveryException {
      incompleteArchive = true;
    }
    if (!original.corrupt &&
        !unknownSource &&
        unknownRows.isEmpty &&
        !incompleteArchive) {
      return;
    }
    await holdRepair(prefs, () async {
      final envelope = await _preserveArchive(
        prefs,
        sharedQuarantineKey,
        records: {},
        raw:
            original.raw ??
            (unknownRows.isEmpty && !unknownSource
                ? null
                : _raw(prefs.get('curated_lists')!)),
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
    return verifyValue(prefs, key, value);
  }

  static Future<bool> removeVerified(
    SharedPreferences prefs,
    String key,
  ) async {
    if (!await persist(prefs, () => prefs.remove(key))) return false;
    return verifyValue(prefs, key, null);
  }

  /// Readback is mandatory before claiming erasure or a generation fence.
  static Future<bool> verifyValue(
    SharedPreferences prefs,
    String key,
    Object? expected,
  ) async {
    try {
      await prefs.reload();
    } on Object {
      CuratedListSessionCoordinator.forPreferences(prefs)
          .markRecoveryReadbackUnknown();
      throw const CuratedListRecoveryException();
    }
    return expected == null
        ? !prefs.containsKey(key)
        : prefs.get(key) == expected;
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
