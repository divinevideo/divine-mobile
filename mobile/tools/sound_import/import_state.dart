// ABOUTME: What the importer has done to each candidate so far, saved after every
// ABOUTME: step so an interrupted run resumes where it stopped.

import 'dart:convert';
import 'dart:io';

/// Where one candidate stands.
enum ImportStatus {
  /// Encoded and ready to upload.
  prepared,

  /// Not usable, such as silent; never retried.
  rejected,

  /// Byte-identical to another candidate's source; that one is imported.
  duplicate,

  /// Failed for a reason a later run may not hit, such as the network.
  failed,
}

/// The importer's record of one candidate.
class ImportRecord {
  ImportRecord({
    required this.status,
    this.sourceSha256,
    this.outputSha256,
    this.outputBytes,
    this.durationSeconds,
    this.gainDb,
    this.changes = const [],
    this.reason,
    this.duplicateOf,
    List<String>? uploadedTo,
    this.publishedEventId,
  }) : uploadedTo = uploadedTo ?? [];

  factory ImportRecord.fromJson(Map<String, dynamic> json) => ImportRecord(
    status: ImportStatus.values.byName(json['status'] as String),
    sourceSha256: json['sourceSha256'] as String?,
    outputSha256: json['outputSha256'] as String?,
    outputBytes: json['outputBytes'] as int?,
    durationSeconds: (json['durationSeconds'] as num?)?.toDouble(),
    gainDb: (json['gainDb'] as num?)?.toDouble(),
    changes: (json['changes'] as List<dynamic>? ?? const []).cast<String>(),
    reason: json['reason'] as String?,
    duplicateOf: json['duplicateOf'] as String?,
    uploadedTo: (json['uploadedTo'] as List<dynamic>? ?? const [])
        .cast<String>()
        .toList(),
    publishedEventId: json['publishedEventId'] as String?,
  );

  ImportStatus status;
  String? sourceSha256;

  /// SHA-256 of the encoded file, which is also its Blossom address.
  String? outputSha256;
  int? outputBytes;
  double? durationSeconds;
  double? gainDb;

  /// What preparing changed, as the credit names it.
  List<String> changes;
  String? reason;
  String? duplicateOf;

  /// Blossom servers that hold the encoded file.
  final List<String> uploadedTo;

  /// The signed Kind 1063 once a maintainer published it.
  String? publishedEventId;

  Map<String, dynamic> toJson() => {
    'status': status.name,
    'sourceSha256': ?sourceSha256,
    'outputSha256': ?outputSha256,
    'outputBytes': ?outputBytes,
    'durationSeconds': ?durationSeconds,
    'gainDb': ?gainDb,
    if (changes.isNotEmpty) 'changes': changes,
    'reason': ?reason,
    'duplicateOf': ?duplicateOf,
    if (uploadedTo.isNotEmpty) 'uploadedTo': uploadedTo,
    'publishedEventId': ?publishedEventId,
  };
}

/// Every candidate's record, keyed by candidate id.
class ImportState {
  ImportState(this._file, this.records);

  /// The state in [file], or an empty one when it does not exist yet.
  factory ImportState.load(File file) {
    if (!file.existsSync()) return ImportState(file, {});
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    return ImportState(file, {
      for (final MapEntry(:key, :value) in json.entries)
        key: ImportRecord.fromJson(value as Map<String, dynamic>),
    });
  }

  final File _file;
  final Map<String, ImportRecord> records;

  /// The candidate already prepared from a source with [sourceSha256].
  String? preparedFromSource(String sourceSha256) {
    for (final MapEntry(:key, :value) in records.entries) {
      if (value.status == ImportStatus.prepared &&
          value.sourceSha256 == sourceSha256) {
        return key;
      }
    }
    return null;
  }

  /// Writes the state through a temporary file, so a crash mid-write never
  /// leaves a truncated state behind.
  void save() {
    final temporary = File('${_file.path}.tmp');
    temporary.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        for (final key in records.keys.toList()..sort())
          key: records[key]!.toJson(),
      }),
    );
    temporary.renameSync(_file.path);
  }
}
