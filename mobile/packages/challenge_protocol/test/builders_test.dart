import 'dart:convert';

import 'package:challenge_protocol/challenge_protocol.dart';
import 'package:test/test.dart';

import 'synthetic.dart';

void main() {
  late SyntheticSigner organizer;
  late SyntheticSigner creator;
  late ChallengeDefinition definition;
  late NostrEvent video;
  setUpAll(() {
    organizer = SyntheticSigner();
    creator = SyntheticSigner();
    definition = definitionOf(organizer.definition());
    video = NostrEvent.fromJson(
      creator.sign(
        kind: 34236,
        tags: [
          ['d', 'synthetic:video'],
        ],
        content: 'Synthetic video.',
      ),
    );
  });

  test('entry signs exact parent, author and snapshots', () {
    final template = buildEntry(definition, video, 150);
    expect(template.kind, 1111);
    expect(template.createdAt, 150);
    expect(template.content, startsWith('nostr:note1'));
    expect(template.tags, [
      ['t', 'divine-challenge'],
      ['challenge', '1', 'entry'],
      ['A', definition.coordinate],
      ['K', '31923'],
      ['P', organizer.pubkey],
      ['a', definition.coordinate],
      ['k', '31923'],
      ['p', organizer.pubkey],
      ['e', definition.event.id],
      ['q', video.id],
      ['challenge_snapshot', jsonEncode(definition.event.toJson())],
      ['video_snapshot', jsonEncode(video.toJson())],
    ]);
    final parsed = parseChallengeEvent(creator.template(template));
    expect(parsed.ok, isTrue);
    final entry = parsed.value! as ChallengeEntry;
    expect(entry.video.id, video.id);
    expect(entry.videoIdentity, '34236:${creator.pubkey}:synthetic:video');
    expect(entry.definition.event.id, definition.event.id);
    expect(parseChallengeEvent(organizer.template(template)).code, 'author');
  });

  test('withdrawal targets exact entry and requires entrant signature', () {
    final entry = entryOf(creator.template(buildEntry(definition, video, 150)));
    final template = buildWithdrawal(definition, entry, 210);
    expect(template.content, 'Withdrawing my entry.');
    expect(template.tags, [
      ['t', 'divine-challenge'],
      ['challenge', '1', 'withdraw'],
      ['A', definition.coordinate],
      ['K', '31923'],
      ['P', organizer.pubkey],
      ['e', entry.event.id],
      ['k', '1111'],
      ['p', creator.pubkey],
    ]);
    expect(
      parseChallengeEvent(creator.template(template)).value,
      isA<ChallengeWithdrawal>(),
    );
    expect(parseChallengeEvent(organizer.template(template)).code, 'parent');
  });

  test('entry window is inclusive start and exclusive end', () {
    expect(buildEntry(definition, video, 100).createdAt, 100);
    expect(buildEntry(definition, video, 199).createdAt, 199);
    for (final time in [99, 200, -1, 9007199254740992]) {
      expect(
        () => buildEntry(definition, video, time),
        throwsA(isA<ContractError>().having((e) => e.code, 'code', 'time')),
      );
    }
  });

  test('wire and templates make deep copies and expose no mutable tags', () {
    final source = creator.sign(
      kind: 21,
      tags: [
        ['title', 'Original'],
      ],
    );
    final value = NostrEvent.fromJson(source);
    (source['tags']! as List<List<String>>)[0][1] = 'Changed';
    expect(value.tags[0][1], 'Original');
    expect(() => value.tags[0][1] = 'Changed', throwsUnsupportedError);
    expect(() => value.tags.add(['new']), throwsUnsupportedError);
    final json = value.toJson();
    (json['tags']! as List<List<String>>)[0][1] = 'Changed';
    expect(value.tags[0][1], 'Original');
    final template = buildEntry(definition, value, 150);
    expect(() => template.tags[0][1] = 'Changed', throwsUnsupportedError);
    (template.toJson()['tags']! as List<List<String>>)[0][1] = 'Changed';
    expect(template.tags[0][1], 'divine-challenge');
  });

  test('builders reparse signed source rather than forged domain fields', () {
    final forged = ChallengeDefinition(
      event: definition.event,
      coordinate: 'forged',
      identifier: 'forged',
      title: 'forged',
      start: 0,
      end: 900,
      timeZone: 'forged',
      endTimeZone: 'forged',
      relays: ['forged'],
      status: 'cancelled',
    );
    final template = buildEntry(forged, video, 150);
    expect(template.tags, contains(equals(['A', definition.coordinate])));
    final entry = entryOf(creator.template(template));
    final fake = ChallengeEntry(
      event: entry.event,
      coordinate: 'forged',
      definition: forged,
      video: definition.event,
      videoIdentity: 'forged',
    );
    expect(
      buildWithdrawal(forged, fake, 210).tags,
      contains(equals(['e', entry.event.id])),
    );
    final broken = NostrEvent(
      id: video.id,
      pubkey: video.pubkey,
      sig: video.sig,
      createdAt: video.createdAt,
      kind: video.kind,
      content: 'tampered',
      tags: video.tags,
    );
    expect(
      () => buildEntry(forged, broken, 150),
      throwsA(isA<ContractError>().having((e) => e.code, 'code', 'signature')),
    );
  });

  test('withdrawal rejects foreign and malformed signed entries', () {
    final entry = entryOf(creator.template(buildEntry(definition, video, 150)));
    final other = definitionOf(organizer.definition(identifier: 'other'));
    expect(
      () => buildWithdrawal(other, entry, 250),
      throwsA(isA<ContractError>().having((e) => e.code, 'code', 'entry')),
    );
    final invalid = ChallengeEntry(
      event: video,
      coordinate: definition.coordinate,
      definition: definition,
      video: video,
      videoIdentity: video.id,
    );
    expect(
      () => buildWithdrawal(definition, invalid, 250),
      throwsA(isA<ContractError>().having((e) => e.code, 'code', 'entry')),
    );
    expect(
      () => buildWithdrawal(definition, entry, 9007199254740992),
      throwsA(isA<ContractError>().having((e) => e.code, 'code', 'time')),
    );
  });

  for (final kind in [21, 22, 34235, 34236]) {
    test('supports signed video kind $kind', () {
      final source = NostrEvent.fromJson(
        creator.sign(
          kind: kind,
          tags: [
            ['d', 'id'],
          ],
        ),
      );
      expect(
        parseChallengeEvent(
          creator.template(buildEntry(definition, source, 150)),
        ).ok,
        isTrue,
      );
    });
  }
  test('rejects wrong video kinds and ambiguous addressable identifiers', () {
    for (final source in [
      creator.sign(kind: 1),
      creator.sign(kind: 34236),
      creator.sign(
        kind: 34236,
        tags: [
          ['d', ''],
        ],
      ),
      creator.sign(
        kind: 34236,
        tags: [
          ['d', 'a'],
          ['d', 'b'],
        ],
      ),
    ]) {
      expect(
        () => buildEntry(definition, NostrEvent.fromJson(source), 150),
        throwsA(isA<ContractError>().having((e) => e.code, 'code', 'video')),
      );
    }
  });

  test('signed record budget includes escaped snapshot strings', () {
    final large = NostrEvent.fromJson(
      creator.sign(kind: 21, content: '"' * 18000),
    );
    expect(
      () => buildEntry(definition, large, 150),
      throwsA(isA<ContractError>().having((e) => e.code, 'code', 'size')),
    );
  });
}
