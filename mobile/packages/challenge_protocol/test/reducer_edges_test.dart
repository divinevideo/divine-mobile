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
          ['d', 'video'],
        ],
      ),
    );
  });

  test('oversized authenticated newest definition cannot reopen old rules', () {
    final newer = organizer.definition(
      createdAt: 180,
      extra: [
        ['opaque', 'a' * 66000],
      ],
    );
    expect(parseChallengeEvent(newer).code, 'size');
    for (final events in [
      [definition.event, newer],
      [newer, definition.event],
    ]) {
      final view = reduceChallenge(
        events,
        definition.coordinate,
        190,
        (_) => true,
      );
      expect(view.state, 'unavailable');
      expect(view.definition, isNull);
    }
  });

  test('unmarked authenticated newest revision cannot reopen old rules', () {
    final newer = organizer.sign(
      createdAt: 180,
      tags: [
        ['d', definition.identifier],
      ],
    );
    expect(
      reduceChallenge(
        [definition.event, newer],
        definition.coordinate,
        190,
        (_) => true,
      ).state,
      'unavailable',
    );
    newer['content'] = 'tampered';
    expect(
      reduceChallenge(
        [definition.event, newer],
        definition.coordinate,
        190,
        (_) => true,
      ).state,
      'open',
    );
  });

  test('definition ties choose lower full event ID independent of order', () {
    final a = definitionOf(organizer.definition(title: 'Synthetic A'));
    final b = definitionOf(organizer.definition(title: 'Synthetic B'));
    final expected = a.event.id.compareTo(b.event.id) < 0 ? a : b;
    for (final events in [
      [a.event, b.event],
      [b.event, a.event],
    ]) {
      expect(
        reduceChallenge(
          events,
          a.coordinate,
          150,
          (_) => true,
        ).definition!.event.id,
        expected.event.id,
      );
    }
  });

  test('current visibility cannot promote a later signed video revision', () {
    final first = entryOf(creator.template(buildEntry(definition, video, 140)));
    final editedVideo = NostrEvent.fromJson(
      creator.sign(
        kind: 34236,
        createdAt: 141,
        content: 'Edited',
        tags: [
          ['d', 'video'],
        ],
      ),
    );
    final second = entryOf(
      creator.template(buildEntry(definition, editedVideo, 150)),
    );
    for (final events in [
      [definition.event, first.event, second.event],
      [second.event, first.event, definition.event],
    ]) {
      final hidden = reduceChallenge(
        events,
        definition.coordinate,
        170,
        (e) => e.id != video.id,
      );
      expect(hidden.entries, isEmpty);
      final shown = reduceChallenge(
        events,
        definition.coordinate,
        170,
        (_) => true,
      );
      expect(shown.entries.single.video.id, video.id);
    }
  });

  test(
    'withdrawal remains effective when hidden and later re-entry is selected',
    () {
      final first = entryOf(
        creator.template(buildEntry(definition, video, 140)),
      );
      final second = entryOf(
        creator.template(buildEntry(definition, video, 150)),
      );
      final withdrawal = creator.template(
        buildWithdrawal(definition, first, 160),
      );
      for (final events in [
        [definition.event, first.event, second.event, withdrawal],
        [withdrawal, second.event, first.event, definition.event],
      ]) {
        final view = reduceChallenge(
          events,
          definition.coordinate,
          170,
          (e) => e.id != withdrawal['id'],
        );
        expect(view.entries.single.event.id, second.event.id);
        expect(view.entries.clear, throwsUnsupportedError);
        expect(() => view.pending.add('x'), throwsUnsupportedError);
      }
    },
  );

  test('rules changes are exposed without replacing submitted snapshots', () {
    final entry = entryOf(creator.template(buildEntry(definition, video, 150)));
    final updated = definitionOf(
      organizer.definition(createdAt: 160, title: 'Updated rules'),
    );
    final view = reduceChallenge(
      [definition.event, updated.event, entry.event],
      definition.coordinate,
      170,
      (_) => true,
    );
    expect(view.entries.single.rulesChanged, isTrue);
    expect(view.entries.single.definition.event.id, definition.event.id);
    expect(view.entries.single.coordinate, definition.coordinate);
    expect(view.entries.single.videoIdentity, '34236:${creator.pubkey}:video');
  });

  test('invalid coordinates and unsafe clock cannot produce a projection', () {
    expect(
      () => reduceChallenge([], '31923:short:id', 150, (_) => true),
      throwsA(isA<ContractError>().having((e) => e.code, 'code', 'coordinate')),
    );
    for (final now in [-1, 9007199254740992]) {
      expect(
        () => reduceChallenge([], definition.coordinate, now, (_) => true),
        throwsA(isA<ContractError>().having((e) => e.code, 'code', 'time')),
      );
    }
  });
}
