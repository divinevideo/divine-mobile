// ABOUTME: Owner-private secure snapshots bridge list-cache account cleanup.
// ABOUTME: Verifies writes and consumes only the exact restored archive revision.

import 'dart:convert';

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
      return raw == null ? null : _decode(owner, raw);
    } on Object {
      throw const CuratedListDraftArchiveException();
    }
  }

  @override
  Future<void> replaceOwner(String owner, List<CuratedList> lists) async {
    try {
      _validateRows(owner, lists);
      // An unknown older envelope is retained rather than overwritten.
      await readOwner(owner);
      if (lists.isEmpty) return removeOwner(owner);
      final encoded = jsonEncode({
        'version': 1,
        'owner': owner,
        'revision': const Uuid().v4(),
        'lists': lists.map((list) => list.toJson()).toList(),
      });
      final key = storageKey(owner);
      await _storage.write(key: key, value: encoded);
      if (await _storage.read(key: key) != encoded) {
        throw const CuratedListDraftArchiveException();
      }
    } on Object {
      throw const CuratedListDraftArchiveException();
    }
  }

  @override
  Future<bool> consumeOwner(String owner, String revision) async {
    final current = await readOwner(owner);
    if (current == null) return true;
    if (current.revision != revision) return false;
    await removeOwner(owner);
    return true;
  }

  @override
  Future<void> removeOwner(String owner) async {
    try {
      await readOwner(owner);
      final key = storageKey(owner);
      await _storage.delete(key: key);
      if (await _storage.read(key: key) != null) {
        throw const CuratedListDraftArchiveException();
      }
    } on Object {
      throw const CuratedListDraftArchiveException();
    }
  }
}
