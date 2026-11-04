import 'dart:convert';
import 'dart:io';
import 'package:concord_protocol/concord_protocol.dart';
import 'package:test/test.dart';

void main() {
  final owner = '11' * 32, member = '22' * 32, admin = '33' * 32;
  final cid = deriveCommunityId(owner, '44' * 32);
  final roleId = '55' * 32, channel = '66' * 32;
  var serial = 0;
  ConcordEdition edition(
    String author,
    String kind,
    String eid,
    Object content, {
    int version = 1,
    String? prev,
    ConcordEdition? grant,
    String? id,
  }) {
    final encoded = jsonEncode(content);
    final tags = <List<String>>[
      ['vsk', kind],
      ['eid', eid],
      ['ev', '$version'],
      if (prev != null) ['ep', prev],
      if (grant != null)
        ['vac', grant.entityId, '${grant.version}', grant.hash],
    ];
    return ConcordEdition.parse({
      'author': author,
      'kind': 3308,
      'sealKind': 20014,
      'content': encoded,
      'tags': tags,
      'rumorId': id ?? (++serial).toRadixString(16).padLeft(64, '0'),
      'createdAt': 1,
    });
  }

  test('forged role and grant cannot bootstrap their own authority', () {
    final role = edition(member, '1', roleId, {
      'role_id': roleId,
      'position': 1,
      'permissions': '63',
    });
    final grant = edition(member, '3', grantLocator(cid, member), {
      'member': member,
      'role_ids': [roleId],
    });
    final renamed = edition(member, '2', channel, {
      'name': 'forged',
    }, grant: grant);
    final state = foldCommunityControl(
      [renamed, grant, role],
      communityId: cid,
      owner: owner,
    );
    expect(state.roles, isEmpty);
    expect(state.grants, isEmpty);
    expect(state.channels, isEmpty);
  });
  test(
    'grant citation is required and revocation removes current authority',
    () {
      final role = edition(owner, '1', roleId, {
        'role_id': roleId,
        'position': 1,
        'permissions': '63',
      });
      final grant = edition(owner, '3', grantLocator(cid, admin), {
        'member': admin,
        'role_ids': [roleId],
      });
      final uncited = edition(admin, '2', channel, {'name': 'uncited'});
      expect(
        foldCommunityControl(
          [role, grant, uncited],
          communityId: cid,
          owner: owner,
        ).channels,
        isEmpty,
      );
      final cited = edition(admin, '2', channel, {
        'name': 'allowed',
      }, grant: grant);
      expect(
        foldCommunityControl(
          [role, grant, cited],
          communityId: cid,
          owner: owner,
        ).channels[channel]!.name,
        'allowed',
      );
      final revoke = edition(
        owner,
        '3',
        grant.entityId,
        {'member': admin, 'role_ids': []},
        version: 2,
        prev: grant.hash,
      );
      expect(
        foldCommunityControl(
          [role, grant, cited, revoke],
          communityId: cid,
          owner: owner,
        ).channels,
        isEmpty,
      );
    },
  );
  test('owner wins same-version fork regardless of grindable rumor id', () {
    final role = edition(owner, '1', roleId, {
      'role_id': roleId,
      'position': 1,
      'permissions': '63',
    });
    final grant = edition(owner, '3', grantLocator(cid, admin), {
      'member': admin,
      'role_ids': [roleId],
    });
    final honest = edition(owner, '2', channel, {
      'name': 'owner',
    }, id: 'ff' * 32);
    final fork = edition(
      admin,
      '2',
      channel,
      {'name': 'fork'},
      grant: grant,
      id: '00' * 32,
    );
    for (final list in [
      [role, grant, honest, fork],
      [fork, honest, grant, role],
    ]) {
      expect(
        foldCommunityControl(
          list,
          communityId: cid,
          owner: owner,
        ).channels[channel]!.name,
        'owner',
      );
    }
  });
  test(
    'missing predecessor reports incompleteness and held floor rejects fork',
    () {
      final first = edition(owner, '2', channel, {'name': 'first'});
      final missing = edition(
        owner,
        '2',
        channel,
        {'name': 'third'},
        version: 3,
        prev: 'aa' * 32,
      );
      final state = foldCommunityControl(
        [first, missing],
        communityId: cid,
        owner: owner,
      );
      expect(state.incomplete, {channel});
      expect(state.channels[channel]!.name, 'first');
      final forged = edition(owner, '2', channel, {'name': 'fork'});
      final held = foldCommunityControl(
        [forged, missing],
        communityId: cid,
        owner: owner,
        priorHeads: state.heads,
      );
      expect(held.channels, isEmpty);
      expect(held.incomplete, {channel});
    },
  );
  test('a low-ranked ban cannot target the owner or a higher-ranked admin', () {
    final adminRole = edition(owner, '1', roleId, {
      'role_id': roleId,
      'position': 1,
      'permissions': '63',
    });
    final modRoleId = '77' * 32;
    final modRole = edition(owner, '1', modRoleId, {
      'role_id': modRoleId,
      'position': 2,
      'permissions': '48',
    });
    final adminGrant = edition(owner, '3', grantLocator(cid, admin), {
      'member': admin,
      'role_ids': [roleId],
    });
    final modGrant = edition(owner, '3', grantLocator(cid, member), {
      'member': member,
      'role_ids': [modRoleId],
    });
    final ban = edition(member, '4', banlistLocator(cid), [
      owner,
      admin,
    ], grant: modGrant);
    final state = foldCommunityControl(
      [ban, modGrant, adminGrant, modRole, adminRole],
      communityId: cid,
      owner: owner,
    );
    expect(state.banned, isEmpty);
  });
  test(
    'fresh singleton dangling edition has no hidden-middle incompleteness',
    () {
      final only = edition(
        owner,
        '2',
        channel,
        {'name': 'compacted'},
        version: 3,
        prev: 'aa' * 32,
      );
      final state = foldCommunityControl(
        [only],
        communityId: cid,
        owner: owner,
      );
      expect(state.channels[channel]!.name, 'compacted');
      expect(state.incomplete, isEmpty);
    },
  );
  test(
    'current epoch snapshots bootstrap only entities actually rewrapped',
    () {
      final first = edition(owner, '2', channel, {'name': 'first'});
      final third = edition(
        owner,
        '2',
        channel,
        {'name': 'third'},
        version: 3,
        prev: 'aa' * 32,
      );
      final metadata = edition(
        owner,
        '0',
        cid,
        {'name': 'metadata'},
        version: 3,
        prev: 'bb' * 32,
      );
      final state = foldCommunityControl(
        [first, third, metadata],
        communityId: cid,
        owner: owner,
        snapshotIds: {metadata.rumorId},
      );
      expect(state.channels[channel]!.name, 'first');
      expect(state.incomplete, {channel});
      expect(state.name, 'metadata');
    },
  );

  test(
    'banned-author second pass preserves the first pass completeness result',
    () {
      final role = edition(owner, '1', roleId, {
        'role_id': roleId,
        'position': 1,
        'permissions': '63',
      });
      final grant = edition(owner, '3', grantLocator(cid, admin), {
        'member': admin,
        'role_ids': [roleId],
      });
      final room = edition(admin, '2', channel, {
        'name': 'removed authority',
      }, grant: grant);
      final ban = edition(owner, '4', banlistLocator(cid), [admin]);
      final state = foldCommunityControl(
        [role, grant, room, ban],
        communityId: cid,
        owner: owner,
        priorHeads: {channel: room},
      );
      expect(state.incomplete, isEmpty);
      expect(state.channels, isEmpty);
      expect(state.banned, {admin});
    },
  );
  test(
    'matches shared kernel projections for compacted, mixed and banned histories',
    () {
      final fixture =
          jsonDecode(
                File('test/fixtures/control-parity.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      for (final raw in fixture['cases'] as List) {
        final c = raw as Map<String, dynamic>;
        final editions = (c['opened'] as List)
            .map((e) => ConcordEdition.parse(e as Map<String, dynamic>))
            .toList();
        final prior = <String, ConcordEdition>{};
        for (final entry in (c['priorHeads'] as Map).entries) {
          prior[entry.key as String] = editions.firstWhere(
            (e) =>
                e.entityId == entry.key &&
                '${e.version}' == (entry.value as Map)['version'] &&
                e.hash == (entry.value as Map)['hash'],
          );
        }
        final state = foldCommunityControl(
          editions,
          communityId: fixture['communityId'] as String,
          owner: fixture['owner'] as String,
          priorHeads: prior,
          snapshotIds: (c['snapshotRumorIds'] as List).cast<String>().toSet(),
        );
        final actual = <String, dynamic>{
          'heads': {
            for (final entry in state.heads.entries)
              entry.key: {
                'version': '${entry.value.version}',
                'hash': entry.value.hash,
              },
          },
          'incomplete': state.incomplete.toList()..sort(),
          'banned': state.banned.toList()..sort(),
        };
        expect(actual, c['expected'], reason: c['name'] as String);
      }
    },
  );
}
