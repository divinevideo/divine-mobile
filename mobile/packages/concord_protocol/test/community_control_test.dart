import 'dart:convert';
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
}
