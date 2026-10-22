// ABOUTME: Retains genuine unreadable relay revisions independently of retry intents.
// ABOUTME: Holds only their coordinate until complete decoding and cache reconciliation.

import 'dart:convert';

import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/services/curated_list_relay_gateway.dart';
import 'package:openvine/services/curated_lists/curated_list_recovery_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ObservedRevision {
  _ObservedRevision(this.key, this.event, {this.persisted = false});

  final String key;
  final Event? event;
  bool persisted;
  bool decoded = false;
  bool reconciled = false;
  Future<bool>? writing;
}

/// Incoming evidence never grants an outbound retry or permission change.
///
/// Registration is synchronous, before external decryption or storage awaits.
/// Raw owner-signed events survive restart; neither an empty read nor an older
/// revision can remove them. The owner supplies its existing write/session queue.
class CuratedListRelayEvidence {
  CuratedListRelayEvidence({
    required SharedPreferences preferences,
    required String? Function() currentOwner,
    required bool Function() isCurrentSession,
    required Future<bool> Function(Future<bool> Function()) runCurrent,
    required Future<bool> Function(Future<bool> Function()) runEvidence,
  }) : _prefs = preferences,
       _currentOwner = currentOwner,
       _isCurrentSession = isCurrentSession,
       _runCurrent = runCurrent,
       _runEvidence = runEvidence {
    _refreshRetained();
  }

  /// Owner-qualified evidence survives ordinary sign-out and account switches.
  /// Destructive account cleanup must verify removal through [removeOwner].
  static const storagePrefix = 'curated_list_relay_evidence_v1:';

  static String storageKey(String owner, String dTag) =>
      '$storagePrefix$owner:${base64Url.encode(utf8.encode(dTag))}';

  final SharedPreferences _prefs;
  final String? Function() _currentOwner;
  final bool Function() _isCurrentSession;
  final Future<bool> Function(Future<bool> Function()) _runCurrent;
  final Future<bool> Function(Future<bool> Function()) _runEvidence;
  final _observed = <String, _ObservedRevision>{};
  final _decodedRaw = <String, ({Object? raw, Event? event})>{};
  final _unknownCoordinates = <String>{};
  bool _unknownOwnerEvidence = false;

  static bool _older(Event incoming, Event existing) =>
      incoming.id != existing.id &&
      (incoming.createdAt < existing.createdAt ||
          (incoming.createdAt == existing.createdAt &&
              incoming.id.compareTo(existing.id) > 0));

  static String? _dTag(Event event) {
    final tags = event.tags.where((tag) => tag.isNotEmpty && tag[0] == 'd');
    return tags.length == 1 && tags.single.length == 2 ? tags.single[1] : null;
  }

  static bool _authentic(Event event, String owner) =>
      event.pubkey == owner &&
      event.kind == 30005 &&
      _dTag(event) != null &&
      _dTag(event) != defaultListId &&
      event.isValid &&
      event.isSigned;

  static Event _copy(Event event) => Event.fromJson(
    jsonDecode(jsonEncode(event.toJson())) as Map<String, dynamic>,
  );

  String _generation(String owner) {
    final keys = CuratedListRecoveryStorage.ownerKeys(
      _prefs,
      CuratedListRecoveryStorage.generationPrefix,
      owner,
    ).toList()..sort();
    final values = <String, int?>{};
    for (final key in keys) {
      final value = _prefs.get(key);
      if (value != null && (value is! int || value < 0)) {
        throw const CuratedListRecoveryException();
      }
      values[key] = value as int?;
    }
    return jsonEncode(values);
  }

  static Event? _decode(Object? raw) {
    try {
      if (raw is! String) return null;
      final envelope = jsonDecode(raw) as Map<String, dynamic>;
      if (envelope.length != 2 || envelope['version'] != 1) return null;
      final value = envelope['event'] as Map<String, dynamic>;
      if (value.length != 7) return null;
      final event = Event.fromJson(value);
      return _authentic(event, event.pubkey) ? event : null;
    } on Object {
      return null;
    }
  }

  static ({String owner, String dTag})? _coordinate(String key) {
    try {
      final parts = key.substring(storagePrefix.length).split(':');
      if (parts.length != 2 || !RegExp(r'^[0-9a-f]{64}$').hasMatch(parts[0])) {
        return null;
      }
      final dTag = utf8.decode(base64Url.decode(parts[1]));
      if (storageKey(parts[0], dTag) != key) return null;
      return (owner: parts[0], dTag: dTag);
    } on Object {
      return null;
    }
  }

  static String? _keyOwner(String key) {
    final owner = key.substring(storagePrefix.length).split(':').first;
    return RegExp(r'^[0-9a-f]{64}$').hasMatch(owner) ? owner : null;
  }

  Event? _storedEvent(String key) {
    final raw = _prefs.get(key);
    final previous = _decodedRaw[key];
    if (previous != null && previous.raw == raw) return previous.event;
    final event = _decode(raw);
    _decodedRaw[key] = (raw: raw, event: event);
    return event;
  }

  void _refreshRetained() {
    final owner = _currentOwner();
    if (owner == null) return;
    final keys = _prefs
        .getKeys()
        .where(
          (key) => key.startsWith(storagePrefix),
        )
        .toSet();
    _decodedRaw.removeWhere((key, _) => !keys.contains(key));
    for (final key in keys) {
      final event = _storedEvent(key);
      // A verified payload proves its coordinate independently of the physical
      // namespace. Keep that original location; a label cannot transfer owner.
      if (event != null) {
        if (event.pubkey != owner) continue;
        final coordinateKey = storageKey(owner, _dTag(event)!);
        final previous = _observed[coordinateKey];
        if (previous == null ||
            (previous.event != null &&
                previous.event!.id != event.id &&
                !_older(event, previous.event!))) {
          _observed[coordinateKey] = _ObservedRevision(
            coordinateKey,
            event,
            persisted: true,
          );
        }
        continue;
      }
      final keyOwner = _keyOwner(key);
      if (keyOwner == null) {
        _unknownOwnerEvidence = true;
        continue;
      }
      if (keyOwner != owner) continue;
      final coordinate = _coordinate(key);
      if (coordinate == null) {
        _unknownCoordinates.add(owner);
        continue;
      }
      _observed[key] = _ObservedRevision(key, null, persisted: true);
    }
  }

  /// Starts the hold before its first await. Invalid/foreign headers cannot hold it.
  Future<bool> observe(Event incoming) {
    final owner = _currentOwner();
    if (!_isCurrentSession() || owner == null || !_authentic(incoming, owner)) {
      return Future.value(true);
    }
    _refreshRetained();
    final key = storageKey(owner, _dTag(incoming)!);
    final previous = _observed[key];
    if (previous != null) {
      final event = previous.event;
      if (event == null) return Future.value(false);
      if (_older(incoming, event)) return Future.value(false);
      if (incoming.id == event.id) {
        if (previous.persisted || previous.reconciled) {
          return Future.value(true);
        }
        return previous.writing ??= _persist(previous, owner);
      }
    }
    final record = _ObservedRevision(key, _copy(incoming));
    _observed[key] = record;
    return record.writing = _persist(record, owner);
  }

  Future<bool> _persist(_ObservedRevision record, String owner) async {
    try {
      final generation = _generation(owner);
      // A captured owner-signed source may outlive the viewing session. It
      // cannot outlive destructive cleanup's generation or grant live rights.
      return await _runEvidence(() async {
        _refreshRetained();
        if (_generation(owner) != generation ||
            (!CuratedListConverter.isEncryptedItemPayload(
                  record.event!.content,
                ) &&
                (!_isCurrentSession() || _currentOwner() != owner)) ||
            !identical(_observed[record.key], record)) {
          return false;
        }
        final raw = _prefs.get(record.key);
        if (raw != null) {
          final stored = _storedEvent(record.key);
          if (stored == null ||
              stored.pubkey != owner ||
              _dTag(stored) != _dTag(record.event!)) {
            return false;
          }
          if (_older(record.event!, stored)) {
            _observed[record.key] = _ObservedRevision(
              record.key,
              stored,
              persisted: true,
            );
            return false;
          }
        }
        final encoded = jsonEncode({
          'version': 1,
          'event': record.event!.toJson(),
        });
        final saved = await CuratedListRecoveryStorage.writeVerified(
          _prefs,
          record.key,
          encoded,
        );
        if (!saved ||
            _generation(owner) != generation ||
            !identical(_observed[record.key], record)) {
          return false;
        }
        _decodedRaw[record.key] = (raw: encoded, event: record.event);
        record.persisted = true;
        return true;
      });
    } on Object {
      return false;
    } finally {
      record.writing = null;
    }
  }

  /// No permissive decoder may silently drop unknown or malformed item records.
  bool decoded(Event event, UnsealedItemTags items) {
    final owner = _currentOwner();
    if (owner == null || !_authentic(event, owner)) {
      final id = CuratedListConverter.extractDTag(event);
      return id == null ||
          (_observed[storageKey(event.pubkey, id)]?.reconciled ?? true);
    }
    final record = _observed[storageKey(owner, _dTag(event)!)];
    if (record?.event?.id != event.id || record?.persisted != true) {
      return false;
    }
    if (items.status == UnsealItemTagsStatus.failed ||
        (items.status == UnsealItemTagsStatus.unsealed &&
            !items.hasCompleteItemSnapshot) ||
        (items.status == UnsealItemTagsStatus.notSealed &&
            CuratedListConverter.isEncryptedItemPayload(event.content))) {
      return false;
    }
    final tags = items.status == UnsealItemTagsStatus.unsealed
        ? items.tags
        : event.tags
              .where(
                (tag) => tag.isNotEmpty && (tag[0] == 'e' || tag[0] == 'a'),
              )
              .toList();
    if (tags == null ||
        tags.any(
          (tag) =>
              tag.length < 2 ||
              !((tag[0] == 'e' && RegExp(r'^[0-9a-f]{64}$').hasMatch(tag[1])) ||
                  (tag[0] == 'a' &&
                      RegExp(r'^(34235|34236):[0-9a-f]{64}:.+$')
                          .hasMatch(tag[1]))),
        ) ||
        CuratedListConverter.fromEvent(
              event,
              privateTags: items.tags,
              isPrivateEvent: items.status == UnsealItemTagsStatus.unsealed,
            ) ==
            null) {
      return false;
    }
    record!.decoded = true;
    return true;
  }

  /// Called only after the decoded snapshot was reconciled and saved successfully.
  Future<void> reconciled(List<Event> events) async {
    for (final event in events) {
      final owner = _currentOwner();
      if (owner == null || !_authentic(event, owner)) continue;
      _refreshRetained();
      final key = storageKey(owner, _dTag(event)!);
      final record = _observed[key];
      if (record?.event?.id != event.id || record?.decoded != true) continue;
      try {
        await _runCurrent(() async {
          if (!_isCurrentSession() ||
              _currentOwner() != owner ||
              !identical(_observed[key], record)) {
            return false;
          }
          await _prefs.reload();
          _refreshRetained();
          if (!_isCurrentSession() ||
              _currentOwner() != owner ||
              !identical(_observed[key], record)) {
            return false;
          }
          // Copies can have a corrupt namespace but a genuine signed owner and
          // d-tag. Remove only proven same-coordinate revisions no newer than
          // the one already decoded and durably reconciled by the caller.
          for (final physicalKey in _prefs.getKeys().where(
            (key) => key.startsWith(storagePrefix),
          )) {
            final stored = _storedEvent(physicalKey);
            if (stored == null ||
                stored.pubkey != owner ||
                _dTag(stored) != _dTag(event)) {
              continue;
            }
            if (_older(event, stored)) return false;
            final raw = _prefs.get(physicalKey);
            if (raw != _decodedRaw[physicalKey]?.raw ||
                !await CuratedListRecoveryStorage.removeVerified(
                  _prefs,
                  physicalKey,
                )) {
              return false;
            }
            _decodedRaw.remove(physicalKey);
            _refreshRetained();
            if (!_isCurrentSession() ||
                _currentOwner() != owner ||
                !identical(_observed[key], record)) {
              return false;
            }
          }
          record!.reconciled = true;
          return true;
        });
      } on Object {
        // The raw source and its hold remain; a later retry can verify storage.
      }
    }
  }

  bool allows(CuratedList list) {
    if (!_isCurrentSession()) return false;
    _refreshRetained();
    if (_unknownOwnerEvidence) return false;
    final owner = list.pubkey ?? _currentOwner();
    if (owner == null) return true;
    if (_unknownCoordinates.contains(owner)) return false;
    return _observed[storageKey(owner, list.id)]?.reconciled ?? true;
  }

  /// Returns only the captured raw source, never an inferred outgoing revision.
  Event? retainedFor(CuratedList list) {
    if (allows(list)) return null;
    final owner = list.pubkey ?? _currentOwner();
    final event = owner == null
        ? null
        : _observed[storageKey(owner, list.id)]?.event;
    return event == null ? null : _copy(event);
  }

  /// Run within the existing destructive-cleanup barrier. Never erase another
  /// owner's source or claim complete deletion when its owner cannot be verified.
  static Future<bool> removeOwner(SharedPreferences prefs, String owner) async {
    var complete = true;
    for (final key in prefs.getKeys().where(
      (key) => key.startsWith(storagePrefix),
    )) {
      final event = _decode(prefs.get(key));
      final keyOwner = _keyOwner(key);
      if (event != null && event.pubkey == owner) {
        if (!await CuratedListRecoveryStorage.removeVerified(prefs, key)) {
          complete = false;
        }
      } else if (event == null && (keyOwner == null || keyOwner == owner)) {
        complete = false;
      }
    }
    return complete;
  }
}
