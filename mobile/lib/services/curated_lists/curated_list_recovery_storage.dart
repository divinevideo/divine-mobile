// ABOUTME: Reads recovery evidence without discarding malformed sibling rows.
// ABOUTME: Preserves unreadable bytes before account caches may be cleared.

import 'dart:convert';

import 'package:openvine/services/curated_lists/curated_list_recovery_record.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether a recovery bucket is absent, usable, or needs explicit repair.
enum CuratedListRecoveryReadStatus { absent, healthy, corrupt }

/// Recovery cannot safely infer permissions from unreadable stored evidence.
class CuratedListRecoveryException implements Exception {
  const CuratedListRecoveryException();

  @override
  String toString() => 'Curated-list recovery needs repair';
}

/// Healthy records remain available even when another row cannot be decoded.
class CuratedListRecoveryRead {
  const CuratedListRecoveryRead({
    required this.records,
    required this.status,
    this.raw,
  });

  final Map<String, CuratedListRecoveryRecord> records;
  final CuratedListRecoveryReadStatus status;
  final String? raw;
}

/// Owner-scoped journal storage with a durable raw-data quarantine.
abstract final class CuratedListRecoveryStorage {
  static const quarantinePrefix = 'curated_list_recovery_quarantine_v1:';
  static const generationPrefix = 'curated_list_recovery_generation_v1:';

  static String quarantineKey(String owner) => '$quarantinePrefix$owner';
  static String generationKey(String owner) => '$generationPrefix$owner';

  static CuratedListRecoveryRead read(
    SharedPreferences prefs,
    String key,
  ) {
    final encoded = prefs.get(key);
    if (encoded == null) {
      return const CuratedListRecoveryRead(
        records: {},
        status: CuratedListRecoveryReadStatus.absent,
      );
    }
    final records = <String, CuratedListRecoveryRecord>{};
    var corrupt = false;
    try {
      final decoded = jsonDecode(encoded as String) as Map<String, dynamic>;
      for (final entry in decoded.entries) {
        try {
          records[entry.key] = CuratedListRecoveryRecord.fromJson(
            entry.value as Map<String, dynamic>,
          );
        } on Object {
          corrupt = true;
        }
      }
    } on Object {
      corrupt = true;
    }
    return CuratedListRecoveryRead(
      records: records,
      status: corrupt
          ? CuratedListRecoveryReadStatus.corrupt
          : CuratedListRecoveryReadStatus.healthy,
      raw: corrupt ? (encoded is String ? encoded : jsonEncode(encoded)) : null,
    );
  }

  static Map<String, dynamic>? _quarantine(
    SharedPreferences prefs,
    String owner,
  ) {
    try {
      final value = prefs.getString(quarantineKey(owner));
      if (value == null) return null;
      final decoded = jsonDecode(value) as Map<String, dynamic>;
      List<String>.from(decoded['rawBuckets'] as List);
      final records = decoded['records'] as Map<String, dynamic>;
      for (final row in records.values) {
        CuratedListRecoveryRecord.fromJson(row as Map<String, dynamic>);
      }
      return decoded;
    } on Object {
      throw const CuratedListRecoveryException();
    }
  }

  static Map<String, CuratedListRecoveryRecord> preservedRecords(
    SharedPreferences prefs,
    String owner,
  ) {
    final saved = _quarantine(prefs, owner);
    if (saved == null) return {};
    return {
      for (final entry in (saved['records'] as Map<String, dynamic>).entries)
        entry.key: CuratedListRecoveryRecord.fromJson(
          entry.value as Map<String, dynamic>,
        ),
    };
  }

  static bool needsRepair(SharedPreferences prefs, String key, String owner) =>
      read(prefs, key).status == CuratedListRecoveryReadStatus.corrupt ||
      prefs.containsKey(quarantineKey(owner));

  /// Preserves raw bytes and all decoded/pending evidence without replacing it.
  static Future<bool> preserve(
    SharedPreferences prefs,
    String key,
    String owner,
    Map<String, CuratedListRecoveryRecord> records,
  ) async {
    final previous = _quarantine(prefs, owner);
    final original = read(prefs, key);
    final raw = <String>{
      ...List<String>.from(previous?['rawBuckets'] as List? ?? const []),
      if (original.raw != null) original.raw!,
    };
    final envelope = jsonEncode({
      'rawBuckets': raw.toList(growable: false),
      'records': {
        for (final entry in records.entries) entry.key: entry.value.toJson(),
      },
    });
    return persist(
      prefs,
      () => prefs.setString(quarantineKey(owner), envelope),
    );
  }

  /// Rejected or throwing preferences must not retain their optimistic value.
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
        throw const CuratedListRecoveryException();
      }
      throw const CuratedListRecoveryException();
    }
  }
}
