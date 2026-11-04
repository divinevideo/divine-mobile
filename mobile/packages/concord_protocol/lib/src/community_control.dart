// MPL-2.0
import 'dart:convert';

import 'package:concord_protocol/src/derivations.dart';

final _hex = RegExp(r'^[0-9a-f]{64}$', caseSensitive: false);
final _decimal = RegExp(r'^(0|[1-9][0-9]*)$');

class ConcordCitation {
  const ConcordCitation(this.entityId, this.version, this.hash);

  /// Reads the first CORD `vac` authority citation in [tags], or null when it
  /// is absent or malformed. A version beyond `int` range can never match a
  /// held head, so it reads as no citation instead of throwing.
  static ConcordCitation? fromTags(Iterable<List<Object?>> tags) {
    final tag = tags.where((t) => t.length >= 4 && t[0] == 'vac').firstOrNull;
    if (tag == null) return null;
    final [_, entity, version, hash, ...] = tag;
    if (entity is! String ||
        version is! String ||
        hash is! String ||
        !_hex.hasMatch(entity) ||
        !_decimal.hasMatch(version) ||
        !_hex.hasMatch(hash)) {
      return null;
    }
    final parsed = int.tryParse(version);
    if (parsed == null) return null;
    return ConcordCitation(entity.toLowerCase(), parsed, hash.toLowerCase());
  }

  final String entityId;
  final int version;
  final String hash;
}

/// Parsed only after stream, plaintext seal and rumor verification.
class ConcordEdition {
  ConcordEdition._({
    required this.author,
    required this.vsk,
    required this.entityId,
    required this.version,
    required this.content,
    required this.hash,
    required this.rumorId,
    required this.createdAt,
    this.previous,
    this.citation,
  });

  factory ConcordEdition.parse(Map<String, dynamic> opened) {
    if (opened['kind'] != 3308 || opened['sealKind'] != 20014) {
      throw const FormatException('Invalid control edition seal');
    }
    final tags = (opened['tags'] as List)
        .map((t) => (t as List).cast<String>())
        .toList();
    for (final name in ['vsk', 'eid', 'ev', 'ep', 'vac']) {
      if (tags.where((t) => t.isNotEmpty && t[0] == name).length > 1) {
        throw const FormatException('Duplicate control edition machinery');
      }
    }
    List<String>? tag(String n) =>
        tags.where((t) => t.isNotEmpty && t[0] == n).firstOrNull;
    String? value(String n) => tag(n)?.elementAtOrNull(1);
    String hashTag(String n) {
      final v = value(n);
      if (v == null || !_hex.hasMatch(v)) throw FormatException('Invalid $n');
      return v.toLowerCase();
    }

    final eid = hashTag('eid');
    final ev = value('ev');
    final vsk = value('vsk');
    if (ev == null || !_decimal.hasMatch(ev) || vsk == null) {
      throw const FormatException('Invalid edition version');
    }
    final version = int.parse(ev);
    final previous = value('ep') == null ? null : hashTag('ep');
    final citation = ConcordCitation.fromTags(tags);
    final content = opened['content'] as String;
    return ConcordEdition._(
      author: opened['author'] as String,
      vsk: vsk,
      entityId: eid,
      version: version,
      previous: previous,
      content: content,
      hash: editionHash(eid, version, previous, content),
      rumorId: opened['rumorId'] as String,
      createdAt: opened['createdAt'] as int,
      citation: citation,
    );
  }

  final String author;
  final String vsk;
  final String entityId;
  final String content;
  final String hash;
  final String rumorId;
  final int version;
  final int createdAt;
  final String? previous;
  final ConcordCitation? citation;
  dynamic get json => jsonDecode(content);
}

class ConcordRole {
  ConcordRole(this.id, this.position, this.permissions);
  final String id;
  final int position;
  final BigInt permissions;
}

class ConcordChannel {
  ConcordChannel(
    this.id,
    this.name,
    this.metadata, {
    required this.isPrivate,
    required this.deleted,
  });
  final String id;
  final String name;
  final bool isPrivate;
  final bool deleted;
  final Map<String, dynamic> metadata;
}

class ConcordControlState {
  ConcordControlState({required this.communityId, required this.owner});
  final String communityId;
  final String owner;
  String? name;
  final channels = <String, ConcordChannel>{};
  final roles = <String, ConcordRole>{};
  final grants = <String, List<String>>{};
  final heads = <String, ConcordEdition>{};
  final banned = <String>{};
  final liveInviteLinks = <String>{};
  final incomplete = <String>{};
  bool dissolved = false;

  Iterable<ConcordChannel> get publicChannels =>
      channels.values.where((c) => !c.isPrivate && !c.deleted);
  Iterable<ConcordRole> rolesOf(String member) =>
      (grants[member] ?? const <String>[])
          .map((id) => roles[id])
          .whereType<ConcordRole>();
  int rank(String member) => member == owner
      ? -1
      : rolesOf(
          member,
        ).fold(9007199254740991, (v, r) => v < r.position ? v : r.position);
  bool permits(String member, int bit) =>
      member == owner ||
      rolesOf(member).fold(BigInt.zero, (p, r) => p | r.permissions) &
              BigInt.from(bit) ==
          BigInt.from(bit);
  bool outranks(String actor, int targetPosition) =>
      actor == owner || rank(actor) < targetPosition;
  bool canActOnMember(String actor, String target, int bit) =>
      target != owner &&
      permits(actor, bit) &&
      (actor == owner || rank(actor) < rank(target));
  bool canManageMessages(String actor) =>
      !banned.contains(actor) && permits(actor, 1 << 5);
  bool citationSatisfied(String actor, ConcordCitation? citation) {
    if (actor == owner) return true;
    if (citation == null ||
        citation.entityId != grantLocator(communityId, actor)) {
      return false;
    }
    final held = heads[citation.entityId];
    return held != null &&
        (held.version > citation.version ||
            held.version == citation.version && held.hash == citation.hash);
  }
}

/// Mirrors concord-core's chain-first candidates, retaining unauthorized-head
/// fallback. Floors bind both version and hash; an equal-version fork cannot
/// silently replace already accepted authority.
List<ConcordEdition> _candidates(
  List<ConcordEdition> list,
  ConcordEdition? floor,
  bool snapshot,
  Set<String> incomplete,
) {
  final editions = {for (final e in list) e.rumorId: e}.values.toList()
    ..sort(
      (a, b) => a.version != b.version
          ? a.version.compareTo(b.version)
          : a.rumorId.compareTo(b.rumorId),
    );
  final eligible = editions
      .where((e) => floor == null || e.version >= floor.version)
      .toList();
  if (eligible.isEmpty) {
    if (floor != null) incomplete.add(floor.entityId);
    return [];
  }
  ConcordEdition? head;
  var gap = false;
  if (snapshot) {
    head = eligible.reduce(
      (a, b) =>
          b.version > a.version ||
              b.version == a.version && b.rumorId.compareTo(a.rumorId) < 0
          ? b
          : a,
    );
  } else {
    final firstVersion = eligible.first.version;
    final base = eligible.where((e) => e.version == firstVersion).toList();
    final anchor = base
        .where(
          (e) => floor == null
              ? e.version == 1 && e.previous == null
              : e.version == floor.version && e.hash == floor.hash ||
                    e.version == floor.version + 1 && e.previous == floor.hash,
        )
        .firstOrNull;
    gap = anchor == null;
    head = anchor ?? base.first;
    final versions = eligible.map((e) => e.version).toSet().toList()..sort();
    for (final version in versions.skip(1)) {
      final next = eligible
          .where(
            (e) =>
                e.version == version &&
                version == head!.version + 1 &&
                e.previous == head.hash,
          )
          .firstOrNull;
      if (next == null) {
        gap = true;
        break;
      }
      head = next;
    }
  }
  if (gap &&
      (floor != null || eligible.any((e) => e.version > head!.version))) {
    incomplete.add(eligible.first.entityId);
  }
  final heldGap = gap && floor != null;
  final rest =
      eligible
          .where(
            (e) =>
                !heldGap || e.version == floor.version && e.hash == floor.hash,
          )
          .toList()
        ..sort(
          (a, b) => a.version != b.version
              ? b.version.compareTo(a.version)
              : a.rumorId.compareTo(b.rumorId),
        );
  return [
    if (head != null && !heldGap) head,
    ...rest.where((e) => heldGap || e.rumorId != head?.rumorId),
  ];
}

/// CORD-04 owner-rooted control fold. The owner comes exclusively from the
/// community commitment checked when accepting membership material.
ConcordControlState foldCommunityControl(
  List<ConcordEdition> editions, {
  required String communityId,
  required String owner,
  Map<String, ConcordEdition> priorHeads = const {},
  Set<String> snapshotIds = const {},
}) {
  final first = _foldOnce(
    editions,
    communityId,
    owner,
    priorHeads,
    snapshotIds,
  );
  if (!editions.any((e) => first.banned.contains(e.author))) return first;
  final clean = _foldOnce(
    editions.where((e) => !first.banned.contains(e.author)).toList(),
    communityId,
    owner,
    priorHeads,
    snapshotIds,
  );
  clean.incomplete
    ..clear()
    ..addAll(first.incomplete);
  clean.banned
    ..clear()
    ..addAll(first.banned);
  return clean;
}

ConcordControlState _foldOnce(
  List<ConcordEdition> editions,
  String cid,
  String owner,
  Map<String, ConcordEdition> prior,
  Set<String> snapshotIds,
) {
  final state = ConcordControlState(communityId: cid, owner: owner);
  final groups = <String, Map<String, List<ConcordEdition>>>{};
  for (final e in editions) {
    groups
        .putIfAbsent(e.vsk, () => {})
        .putIfAbsent(e.entityId, () => [])
        .add(e);
  }
  Map<String, List<ConcordEdition>> candidates(String vsk) => {
    for (final entry in (groups[vsk] ?? {}).entries)
      entry.key: _candidates(
        entry.value,
        prior[entry.key],
        entry.value.any((e) => snapshotIds.contains(e.rumorId)),
        state.incomplete,
      ),
  };
  bool cited(ConcordEdition e) => state.citationSatisfied(e.author, e.citation);
  int authorityFirst(ConcordEdition a, ConcordEdition b) {
    final rank = state.rank(a.author).compareTo(state.rank(b.author));
    return rank != 0 ? rank : a.rumorId.compareTo(b.rumorId);
  }

  List<List<ConcordEdition>> versionGroups(List<ConcordEdition> list) {
    final byVersion = <int, List<ConcordEdition>>{};
    for (final e in list) {
      byVersion.putIfAbsent(e.version, () => []).add(e);
    }
    final keys = byVersion.keys.toList()..sort();
    return [for (final k in keys) byVersion[k]!..sort(authorityFirst)];
  }

  ConcordEdition? pick(
    List<ConcordEdition> list,
    bool Function(ConcordEdition) gate,
  ) {
    ConcordEdition? best;
    for (final e in list) {
      if (!gate(e)) continue;
      if (best == null) {
        best = e;
        continue;
      }
      if (e.version != best.version) break;
      if (state.rank(e.author) < state.rank(best.author)) best = e;
    }
    if (best != null) state.heads[best.entityId] = best;
    return best;
  }

  dynamic json(ConcordEdition e) {
    try {
      return e.json;
    } on Object {
      return null;
    }
  }

  ConcordRole? roleOf(ConcordEdition e) {
    final j = json(e);
    if (j is! Map ||
        j['role_id'] is! String ||
        !_hex.hasMatch(j['role_id'] as String) ||
        (j['role_id'] as String).toLowerCase() != e.entityId ||
        j['position'] is! int ||
        (j['position'] as int) < 1 ||
        utf8.encode(j['name'] is String ? j['name'] as String : '').length >
            64) {
      return null;
    }
    final p = j['permissions'];
    BigInt? permissions;
    if (p is String && RegExp(r'^\d+$').hasMatch(p)) {
      permissions = BigInt.parse(p);
    }
    // concord-core reads a JSON number as a double before truncating; an
    // int-saturating truncate would grant every bit to an oversized value.
    if (p is num && p.isFinite) permissions = BigInt.from(p.toDouble());
    if (permissions == null) return null;
    return ConcordRole(e.entityId, j['position'] as int, permissions);
  }

  (String, List<String>)? grantOf(ConcordEdition e) {
    final j = json(e);
    if (j is! Map ||
        j['member'] is! String ||
        !_hex.hasMatch(j['member'] as String)) {
      return null;
    }
    final member = (j['member'] as String).toLowerCase();
    if (grantLocator(cid, member) != e.entityId) return null;
    return (
      member,
      j['role_ids'] is List
          ? (j['role_ids'] as List).whereType<String>().take(64).toList()
          : [],
    );
  }

  final roleCandidates = {
    for (final entry in candidates('1').entries)
      entry.key: entry.value.where((e) => roleOf(e) != null).toList(),
  }..removeWhere((k, v) => v.isEmpty);
  final grantCandidates = {
    for (final entry in candidates('3').entries)
      entry.key: entry.value.where((e) => grantOf(e) != null).toList(),
  }..removeWhere((k, v) => v.isEmpty);
  final roleIds = roleCandidates.keys.toList()..sort();
  final grantIds = grantCandidates.keys.toList()..sort();
  final grantOfMember = {
    for (final entry in grantCandidates.entries)
      grantOf(entry.value.first)!.$1: entry.key,
  };
  final settledRoles = <String>{};
  final settledGrants = <String>{};
  var rolesFrozen = false;
  var ranksFrozen = false;
  var changed = true;
  bool rankPending(String author, [String? self]) =>
      author != owner &&
      grantOfMember[author] != null &&
      grantOfMember[author] != self &&
      !settledGrants.contains(grantOfMember[author]);
  while (changed) {
    changed = false;
    for (final eid in roleIds) {
      if (settledRoles.contains(eid)) continue;
      final list = roleCandidates[eid]!;
      if (!ranksFrozen && list.any((e) => rankPending(e.author))) continue;
      final admissible = <ConcordEdition>{};
      int? standing;
      for (final group in versionGroups(list)) {
        for (final e in group) {
          final role = roleOf(e)!;
          if (!(e.author == owner ||
                  state.permits(e.author, 1) &&
                      state.outranks(e.author, role.position)) ||
              !(e.author == owner ||
                  standing == null ||
                  state.outranks(e.author, standing)) ||
              !cited(e)) {
            continue;
          }
          admissible.add(e);
          standing = role.position;
          break;
        }
      }
      final winner = list.where(admissible.contains).firstOrNull;
      if (winner == null) continue;
      state.roles[eid] = roleOf(winner)!;
      state.heads[eid] = winner;
      settledRoles.add(eid);
      changed = true;
    }
    for (final eid in grantIds) {
      if (settledGrants.contains(eid)) continue;
      final list = grantCandidates[eid]!;
      if (!rolesFrozen &&
          list.any(
            (e) => grantOf(e)!.$2.any(
              (id) =>
                  roleCandidates.containsKey(id) && !settledRoles.contains(id),
            ),
          )) {
        continue;
      }
      if (!ranksFrozen && list.any((e) => rankPending(e.author, eid))) continue;
      final admissible = <ConcordEdition>{};
      int? standing;
      for (final group in versionGroups(list)) {
        for (final e in group) {
          final grant = grantOf(e)!;
          final positions = grant.$2
              .map((id) => state.roles[id]?.position)
              .whereType<int>()
              .toList();
          final allowed =
              e.author == owner ||
              positions.length == grant.$2.length &&
                  state.permits(e.author, 1) &&
                  positions.every((p) => state.outranks(e.author, p)) &&
                  (standing == null || state.outranks(e.author, standing));
          if (!allowed || !cited(e)) continue;
          admissible.add(e);
          standing = positions.isEmpty
              ? null
              : positions.reduce((a, b) => a < b ? a : b);
          break;
        }
      }
      final winner = list.where(admissible.contains).firstOrNull;
      if (winner == null) continue;
      final grant = grantOf(winner)!;
      state.grants[grant.$1] = grant.$2;
      state.heads[eid] = winner;
      settledGrants.add(eid);
      changed = true;
    }
    if (!changed && !rolesFrozen) {
      rolesFrozen = true;
      changed = true;
    } else if (!changed && !ranksFrozen) {
      ranksFrozen = true;
      changed = true;
    }
  }
  final capped = state.roles.keys.toList()..sort();
  capped.skip(100).forEach(state.roles.remove);
  final metadata = pick(candidates('0')[cid] ?? [], (e) {
    final j = json(e);
    return state.permits(e.author, 4) &&
        cited(e) &&
        j is Map &&
        j['name'] is String &&
        utf8.encode(j['name'] as String).length <= 64 &&
        (j['description'] == null ||
            j['description'] is String &&
                utf8.encode(j['description'] as String).length <= 10000);
  });
  if (metadata != null) state.name = (json(metadata) as Map)['name'] as String;
  for (final entry in candidates('2').entries) {
    bool gate(ConcordEdition e) {
      final j = json(e);
      return state.permits(e.author, 2) &&
          cited(e) &&
          j is Map &&
          j['name'] is String &&
          (j['name'] as String).isNotEmpty &&
          utf8.encode(j['name'] as String).length <= 64;
    }

    final head = pick(entry.value, gate);
    if (head == null) continue;
    final j = Map<String, dynamic>.from(json(head) as Map);
    final deleted = entry.value.any(
      (e) => gate(e) && (json(e) as Map)['deleted'] == true,
    );
    state.channels[entry.key] = ConcordChannel(
      entry.key,
      j['name'] as String,
      j,
      isPrivate: j['private'] == true,
      deleted: deleted,
    );
  }
  final bans = candidates('4')[banlistLocator(cid)] ?? [];
  final admissibleBans = <ConcordEdition>{};
  final standingAt = <ConcordEdition, Set<String>>{};
  var standingBans = <String>{};
  List<String>? named(ConcordEdition e) {
    final j = json(e);
    return j is List
        ? j
              .whereType<String>()
              .where(_hex.hasMatch)
              .map((s) => s.toLowerCase())
              .toList()
        : null;
  }

  for (final group in versionGroups(bans)) {
    for (final e in group) {
      if (!state.permits(e.author, 16) ||
          !cited(e) ||
          named(e) == null ||
          standingBans.contains(e.author)) {
        continue;
      }
      final next =
          named(
              e,
            )!.where((pk) => state.canActOnMember(e.author, pk, 16)).toSet()
            ..addAll(
              standingBans.where(
                (pk) => !state.canActOnMember(e.author, pk, 16),
              ),
            );
      standingBans = next;
      standingAt[e] = next;
      admissibleBans.add(e);
      break;
    }
  }
  final banHead = pick(bans, admissibleBans.contains);
  if (banHead != null) state.banned.addAll(standingAt[banHead]!);
  for (final entry in candidates('8').entries) {
    final head = pick(
      entry.value,
      (e) =>
          entry.key ==
              bytesToHex(
                hkdfSeed(
                  hexToBytes(cid),
                  'concord/invite-links',
                  hexToBytes(e.author),
                ),
              ) &&
          state.permits(e.author, 64) &&
          cited(e) &&
          json(e) is List,
    );
    if (head != null) {
      state.liveInviteLinks.addAll(
        (json(head) as List)
            .whereType<String>()
            .where(_hex.hasMatch)
            .map((s) => s.toLowerCase()),
      );
    }
  }
  for (final eid in prior.keys) {
    if (!editions.any((e) => e.entityId == eid)) state.incomplete.add(eid);
  }
  return state;
}
