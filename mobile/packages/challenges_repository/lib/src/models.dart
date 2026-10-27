part of '../challenges_repository.dart';

/// Current verified state with explicit observation coverage.
final class ChallengeRead {
  /// Creates a read assessment.
  const ChallengeRead({required this.view, required this.observation});

  /// Only a complete indexed set without unresolved dependencies has a count.
  int? get completeEntryCount =>
      !observation.retentionLimited &&
          observation.source == ReadSource.indexedApi &&
          observation.completeness == ReadCompleteness.complete &&
          view.state != 'unavailable' &&
          view.pending.isEmpty
      ? view.entries.length
      : null;

  /// Signature-verified deterministic replay; policy still applies currently.
  final ChallengeView view;

  /// Source completion and indexing watermark.
  final RawChallengeRead observation;
}

/// Resource limits applied before parsing untrusted or persisted JSON.
final class ReadLimits {
  /// Defaults deliberately allow a malformed oversized definition to be
  /// retained and invalidate old rules, while bounding the whole replay.
  const ReadLimits({
    this.maxRecords = 512,
    this.maxRecordBytes = 128 * 1024,
    this.maxBytes = 4 * 1024 * 1024,
  });

  /// Maximum retained records per coordinate.
  final int maxRecords;

  /// Maximum bytes per raw envelope.
  final int maxRecordBytes;

  /// Maximum total replay bytes.
  final int maxBytes;

  /// Checks UTF-8 lengths before any JSON parsing.
  bool accepts(List<String> records) {
    if (records.length > maxRecords) return false;
    var bytes = 0;
    for (final record in records) {
      // Each UTF-16 unit requires at least one UTF-8 byte, except surrogate
      // pairs, which still require more bytes than units.
      if (record.length > maxRecordBytes) return false;
      final length = utf8.encode(record).length;
      if (length > maxRecordBytes) return false;
      bytes += length;
      if (bytes > maxBytes) return false;
    }
    return true;
  }
}
