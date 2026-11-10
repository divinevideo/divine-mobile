// ABOUTME: Owner-private secure snapshots bridge list-cache account cleanup.
// ABOUTME: Verifies writes and consumes only the exact restored archive revision.

import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:models/models.dart';
import 'package:uuid/uuid.dart';

/// A payload-free failure; private archived data never enters error text.
class CuratedListDraftArchiveException implements Exception {
  const CuratedListDraftArchiveException();
}

/// One account's retained pending lists, bound to a unique archive revision.
class CuratedListDraftArchiveSnapshot {
  CuratedListDraftArchiveSnapshot({
    required this.owner,
    required this.revision,
    required List<CuratedList> lists,
  }) : lists = List.unmodifiable(lists);

  final String owner;
  final String revision;
  final List<CuratedList> lists;
}

/// Account cleanup and restoration share this injected private storage port.
abstract interface class CuratedListDraftArchive {
  Future<CuratedListDraftArchiveSnapshot?> readOwner(String owner);
  Future<void> replaceOwner(String owner, List<CuratedList> lists);
  Future<bool> consumeOwner(String owner, String revision);
  Future<void> removeOwner(String owner);
}

/// Uses the app's platform-encrypted storage without asking a Nostr signer.
class SecureCuratedListDraftArchive implements CuratedListDraftArchive {
  SecureCuratedListDraftArchive(this._storage);

  final FlutterSecureStorage _storage;

  /// Secure-storage namespace, retained on ordinary logout/account switching.
  static const storagePrefix = 'curated_list_draft_archive_v1:';
  static const _quarantinePrefix = 'curated_list_draft_quarantine_v1:';

  // Service restoration and account cleanup use separate archive instances.
  // Serialize their mutations for each owner across those instances.
  static final _ownerTails = <String, Future<void>>{};

  Future<T> _exclusive<T>(String owner, Future<T> Function() operation) async {
    storageKey(owner);
    final previous = _ownerTails[owner] ?? Future<void>.value();
    final completed = Completer<void>();
    final tail = completed.future;
    _ownerTails[owner] = tail;
    await previous;
    try {
      return await operation();
    } on Object {
      throw const CuratedListDraftArchiveException();
    } finally {
      completed.complete();
      if (identical(_ownerTails[owner], tail)) {
        final _ = _ownerTails.remove(owner);
      }
    }
  }

  static String _ownerQuarantinePrefix(String owner) {
    storageKey(owner);
    return '$_quarantinePrefix$owner:';
  }

  static String storageKey(String owner) {
    if (!NostrHexUtils.isValidPubkey(owner)) {
      throw const CuratedListDraftArchiveException();
    }
    return '$storagePrefix$owner';
  }

  static void _validateRows(String owner, List<CuratedList> lists) {
    final coordinates = <String>{};
    for (final list in lists) {
      final draft = list.localEditDraft;
      if (list.pubkey != owner ||
          !coordinates.add(list.authorScopedId) ||
          (draft != null &&
              (draft.baseline.authorScopedId != list.authorScopedId ||
                  draft.desired.authorScopedId != list.authorScopedId))) {
        throw const CuratedListDraftArchiveException();
      }
    }
  }

  static CuratedListDraftArchiveSnapshot _decode(String owner, String raw) {
    try {
      final value = jsonDecode(raw) as Map<String, dynamic>;
      final revision = value['revision'] as String;
      if (value.length != 4 ||
          value['version'] != 1 ||
          value['owner'] != owner ||
          revision.isEmpty) {
        throw const CuratedListDraftArchiveException();
      }
      final rows = (value['lists'] as List)
          .map((row) => CuratedList.fromJson(row as Map<String, dynamic>))
          .toList();
      _validateRows(owner, rows);
      return CuratedListDraftArchiveSnapshot(
        owner: owner,
        revision: revision,
        lists: rows,
      );
    } on Object {
      throw const CuratedListDraftArchiveException();
    }
  }

  @override
  Future<CuratedListDraftArchiveSnapshot?> readOwner(String owner) async {
    try {
      final raw = await _storage.read(key: storageKey(owner));
      if (raw == null) return null;
      try {
        return _decode(owner, raw);
      } on CuratedListDraftArchiveException {
        // Only decoding failures enter quarantine. Storage outages must retain
        // the source and remain retryable rather than look like absent drafts.
        return await _exclusive(owner, () => _readOwner(owner));
      }
    } on Object {
      throw const CuratedListDraftArchiveException();
    }
  }

  /// Called under the owner mutation queue; rechecks after a stale initial read.
  Future<CuratedListDraftArchiveSnapshot?> _readOwner(String owner) async {
    final key = storageKey(owner);
    while (true) {
      final raw = await _storage.read(key: key);
      if (raw == null) return null;
      try {
        return _decode(owner, raw);
      } on CuratedListDraftArchiveException {
        // One immutable encrypted slot per distinct unreadable revision. The
        // slot owner scopes evidence; fields inside the bytes grant no rights.
        var backupKey =
            '${_ownerQuarantinePrefix(owner)}${sha256.convert(utf8.encode(raw))}';
        var backup = await _storage.read(key: backupKey);
        if (backup != null && backup != raw) {
          // Preserve a damaged earlier backup too. A fresh immutable slot lets
          // preservation retry after a previous write failed verification.
          backupKey = '$backupKey:${const Uuid().v4()}';
          backup = await _storage.read(key: backupKey);
        }
        if (backup == null) {
          await _storage.write(key: backupKey, value: raw);
        } else if (backup != raw) {
          throw const CuratedListDraftArchiveException();
        }
        if (await _storage.read(key: backupKey) != raw) {
          throw const CuratedListDraftArchiveException();
        }
        // Another archive instance cannot mutate this owner while queued.
        // Also refuse to retire a source changed outside this queue.
        if (await _storage.read(key: key) != raw) continue;
        await _deleteVerified(key);
        return null;
      }
    }
  }

  @override
  Future<void> replaceOwner(String owner, List<CuratedList> lists) =>
      _exclusive(owner, () async {
        _validateRows(owner, lists);
        await _readOwner(owner);
        final key = storageKey(owner);
        if (lists.isEmpty) return _deleteVerified(key);
        final encoded = jsonEncode({
          'version': 1,
          'owner': owner,
          'revision': const Uuid().v4(),
          'lists': lists.map((list) => list.toJson()).toList(),
        });
        await _storage.write(key: key, value: encoded);
        if (await _storage.read(key: key) != encoded) {
          throw const CuratedListDraftArchiveException();
        }
      });

  @override
  Future<bool> consumeOwner(String owner, String revision) =>
      _exclusive(owner, () async {
        final current = await _readOwner(owner);
        if (current == null) return true;
        if (current.revision != revision) return false;
        // Consuming usable drafts never destroys quarantined recovery bytes.
        await _deleteVerified(storageKey(owner));
        return true;
      });

  Future<void> _deleteVerified(String key) async {
    await _storage.delete(key: key);
    if (await _storage.read(key: key) != null) {
      throw const CuratedListDraftArchiveException();
    }
  }

  @override
  Future<void> removeOwner(String owner) => _exclusive(owner, () async {
    // Only explicit account destruction removes this owner's quarantine.
    // Enumerate first so a storage read failure cannot start partial erasure.
    final prefix = _ownerQuarantinePrefix(owner);
    final keys = (await _storage.readAll()).keys
        .where((key) => key.startsWith(prefix))
        .toList();
    await _deleteVerified(storageKey(owner));
    for (final key in keys) {
      await _deleteVerified(key);
    }
    if ((await _storage.readAll()).keys.any((key) => key.startsWith(prefix))) {
      throw const CuratedListDraftArchiveException();
    }
  });
}
