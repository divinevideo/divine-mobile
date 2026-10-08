// ABOUTME: Attributes damaged cache rows without trusting their other fields.
// ABOUTME: Redacts all proven owner copies and retains unknown recovery bytes.

part of 'curated_list_recovery_storage.dart';

class _SharedRecoveryScope {
  final owners = <String>{};
  bool unknown = false;

  void include(_SharedRecoveryScope other) {
    owners.addAll(other.owners);
    unknown |= other.unknown;
  }

  bool holds(String? owner) =>
      unknown || (owner == null ? owners.isNotEmpty : owners.contains(owner));
}

String? _provenRecoveryOwner(Object? value) =>
    value is String && NostrHexUtils.isValidPubkey(value)
    ? value.toLowerCase()
    : null;

String? _provenRowOwner(Map<dynamic, dynamic> row) {
  final owner = _provenRecoveryOwner(row['pubkey']);
  if (owner == null) return null;
  for (final label in ['ownerPubkey', 'authorPubkey']) {
    if (row.containsKey(label) && _provenRecoveryOwner(row[label]) != owner) {
      return null;
    }
  }
  return owner;
}

class _SharedRecoveryVerdict {
  const _SharedRecoveryVerdict(
    this.live,
    this.marker,
    this.archive,
    this.scope,
  );

  final Object? live;
  final Object? marker;
  final Object? archive;
  final _SharedRecoveryScope scope;
}

const _archiveFields = {
  'version',
  'rawBuckets',
  'recordBackups',
  'records',
  'originalLiveValue',
  'normalized',
  'needsRepair',
  'ownerWide',
  'unresolvedCoordinates',
  'aliasRepairRequired',
};

/// A valid pubkey remains ownership evidence even if a date/title is invalid.
/// An absent owner on a damaged row is never guessed from the active account.
_SharedRecoveryScope _sharedRecoveryScope(
  Object? encoded, {
  int depth = 0,
  String? legacyOwner,
}) {
  final scope = _SharedRecoveryScope();
  if (encoded == null) return scope;
  if (depth > 16) return scope..unknown = true;
  Object? decoded = encoded;
  if (decoded is String) {
    try {
      decoded = jsonDecode(decoded);
    } on Object {
      return scope..unknown = true;
    }
  }
  if (decoded is List) {
    for (final value in decoded) {
      final owner = value is Map ? _provenRowOwner(value) : null;
      var damaged = false;
      var unknownPending = false;
      try {
        final row = CuratedList.fromJson(value as Map<String, dynamic>);
        unknownPending =
            owner == null &&
            (row.pubkey != null || legacyOwner == null) &&
            (row.pendingPlaintextEventIds.isNotEmpty ||
                row.hasPendingPermissionRecovery);
      } on Object {
        damaged = true;
      }
      if (!damaged && !unknownPending) continue;
      if (owner == null) {
        scope.unknown = true;
      } else {
        scope.owners.add(owner);
      }
    }
    return scope;
  }
  if (decoded is Map<String, dynamic> && decoded['version'] == 2) {
    if (decoded['needsRepair'] == false) return scope;
    // A crash before the normalization marker cannot optimistically unhold an
    // unrelated owner while live storage may still have unpreserved evidence.
    if (decoded['normalized'] != true ||
        decoded.keys.any((key) => !_archiveFields.contains(key))) {
      scope.unknown = true;
    }
    for (final field in ['rawBuckets', 'recordBackups']) {
      final buckets = decoded[field];
      if (buckets is! List) {
        if (buckets != null) scope.unknown = true;
        continue;
      }
      for (final bucket in buckets) {
        scope.include(_sharedRecoveryScope(bucket, depth: depth + 1));
      }
    }
    scope.include(
      _sharedRecoveryScope(decoded['originalLiveValue'], depth: depth + 1),
    );
    final staged = decoded['records'];
    if (staged is! Map || staged.isNotEmpty) scope.unknown = true;
    final unresolved = decoded['unresolvedCoordinates'];
    if (unresolved != null && (unresolved is! List || unresolved.isNotEmpty)) {
      scope.unknown = true;
    }
    final rawBuckets = decoded['rawBuckets'];
    final recordBackups = decoded['recordBackups'];
    if ((rawBuckets is! List || rawBuckets.isEmpty) &&
        (recordBackups is! List || recordBackups.isEmpty) &&
        decoded['originalLiveValue'] == null) {
      scope.unknown = true;
    }
    return scope;
  }
  // Empty journal backups contain no permission work. A non-empty unscoped
  // journal cannot prove an owner, even when its contents decode successfully.
  if (decoded is Map && decoded.isEmpty) return scope;
  return scope..unknown = true;
}

class _SharedRecoveryRedaction {
  const _SharedRecoveryRedaction(
    this.value, {
    this.changed = false,
    this.unknown = false,
  });

  final Object? value;
  final bool changed;
  final bool unknown;
}

/// Rewrites only recognized containers. Opaque strings and other-account row
/// values remain intact; inability to prove their owner prevents completion.
_SharedRecoveryRedaction _redactSharedRecovery(
  Object? encoded,
  String owner, {
  int depth = 0,
}) {
  if (encoded == null) return const _SharedRecoveryRedaction(null);
  if (depth > 16) return _SharedRecoveryRedaction(encoded, unknown: true);
  Object? decoded = encoded;
  final wasString = decoded is String;
  if (wasString) {
    try {
      decoded = jsonDecode(decoded);
    } on Object {
      return _SharedRecoveryRedaction(encoded, unknown: true);
    }
  }
  var changed = false;
  var unknown = false;
  Object? result = decoded;
  if (decoded is List) {
    final retained = <Object?>[];
    for (final row in decoded) {
      final rowOwner = row is Map ? _provenRowOwner(row) : null;
      if (rowOwner == owner) {
        changed = true;
      } else {
        retained.add(row);
        unknown |= rowOwner == null;
      }
    }
    result = retained;
  } else if (decoded is Map<String, dynamic> && decoded['version'] == 2) {
    final archive = Map<String, dynamic>.of(decoded);
    unknown |= decoded.keys.any((key) => !_archiveFields.contains(key));
    for (final field in ['rawBuckets', 'recordBackups']) {
      final buckets = decoded[field];
      if (buckets == null) continue;
      if (buckets is! List) {
        unknown = true;
        continue;
      }
      final retained = <Object?>[];
      for (final bucket in buckets) {
        final redacted = _redactSharedRecovery(bucket, owner, depth: depth + 1);
        retained.add(redacted.value);
        changed |= redacted.changed;
        unknown |= redacted.unknown;
      }
      archive[field] = retained;
    }
    final original = _redactSharedRecovery(
      decoded['originalLiveValue'],
      owner,
      depth: depth + 1,
    );
    archive['originalLiveValue'] = original.value;
    changed |= original.changed;
    unknown |= original.unknown;
    final staged = decoded['records'];
    unknown |= staged is! Map || staged.isNotEmpty;
    // Shared staged coordinates have no ownership proof in the v2 contract.
    // Preserve them; never infer that a coordinate matches a removed row.
    final coordinates = decoded['unresolvedCoordinates'];
    unknown |=
        coordinates != null && (coordinates is! List || coordinates.isNotEmpty);
    result = archive;
  } else if (decoded is! Map || decoded.isNotEmpty) {
    unknown = true;
  }
  return _SharedRecoveryRedaction(
    changed ? (wasString ? jsonEncode(result) : result) : encoded,
    changed: changed,
    unknown: unknown,
  );
}
