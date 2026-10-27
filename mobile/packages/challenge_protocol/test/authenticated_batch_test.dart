import 'dart:convert';

import 'package:challenge_protocol/challenge_protocol.dart';
import 'package:test/test.dart';

import 'fixture_loader.dart';
import 'synthetic.dart';

void main() {
  group('AuthenticatedChallengeBatch.verify', () {
    final organizer = SyntheticSigner();
    final creator = SyntheticSigner();
    final definition = definitionOf(organizer.definition());
    final video = NostrEvent.fromJson(
      creator.sign(
        kind: 34236,
        tags: [
          ['d', 'video'],
        ],
      ),
    );
    final entry = entryOf(creator.template(buildEntry(definition, video, 150)));

    test(
      'retention authenticates IDs, keeps original bytes and deduplicates',
      () {
        final raw = '  ${jsonEncode(definition.event.toJson())}\n';
        final forged = {...definition.event.toJson(), 'content': 'forged'};
        final batch = AuthenticatedChallengeBatch.verify([
          jsonEncode(forged),
          raw,
          raw,
          jsonEncode(creator.sign(kind: 1)),
          jsonEncode(organizer.definition(identifier: 'elsewhere')),
        ], definition.coordinate);
        expect(batch.records, [raw]);
        expect(batch.events.single.id, definition.event.id);
        expect(batch.invalidInput, isFalse);
        expect(() => batch.records.add('junk'), throwsUnsupportedError);
      },
    );

    test(
      'malformed JSON is unavailable but cannot become retained authority',
      () {
        final batch = AuthenticatedChallengeBatch.verify([
          '{',
          '[]',
          'null',
        ], definition.coordinate);
        expect(batch.invalidInput, isTrue);
        expect(batch.records, isEmpty);
        expect(
          () => AuthenticatedChallengeBatch.verify([], 'invalid'),
          throwsA(isA<ContractError>()),
        );
      },
    );

    for (final oversized in [false, true]) {
      test(
        'authenticated newest invalid revision survives retention '
        'oversized=$oversized',
        () {
          final replacement = oversized
              ? organizer.definition(createdAt: 170, content: 'x' * 66000)
              : organizer.sign(
                  createdAt: 170,
                  tags: [
                    ['d', definition.identifier],
                  ],
                );
          final raw = jsonEncode(replacement);
          final batch = AuthenticatedChallengeBatch.verify([
            jsonEncode(definition.event.toJson()),
            raw,
          ], definition.coordinate);
          expect(batch.records, [raw]);
          expect(
            reduceChallenge(
              batch.events,
              definition.coordinate,
              180,
              (_) => true,
            ).state,
            'unavailable',
          );
        },
      );
    }

    test('entry and withdrawal retain embedded policy dependencies', () {
      final withdrawal = creator.template(
        buildWithdrawal(definition, entry, 170),
      );
      final batch = AuthenticatedChallengeBatch.verify([
        jsonEncode(entry.event.toJson()),
        jsonEncode(withdrawal),
        jsonEncode(creator.sign(kind: 1111)),
        jsonEncode(
          creator.template(
            buildEntry(
              definitionOf(organizer.definition(identifier: 'elsewhere')),
              video,
              150,
            ),
          ),
        ),
      ], definition.coordinate);
      expect(batch.records, hasLength(2));
      expect(
        batch.policyEvents.map((event) => event.id),
        containsAll([
          entry.event.id,
          video.id,
          definition.event.id,
          withdrawal['id'],
        ]),
      );
    });
    test(
      'result retains its exact historical definition policy dependency',
      () {
        final scenarios =
            fixture('scenarios.json')['scenarios']! as List<Object?>;
        final scenario = scenarios.cast<Map<String, Object?>>().firstWhere(
          (s) => (s['events']! as List<Object?>).any(
            (event) => parseChallengeEvent(event).value is ChallengeResult,
          ),
        );
        final result = (scenario['events']! as List<Object?>)
            .map((event) => parseChallengeEvent(event).value)
            .whereType<ChallengeResult>()
            .first;
        final batch = AuthenticatedChallengeBatch.verify([
          jsonEncode(result.event.toJson()),
        ], result.coordinate);
        expect(
          batch.policyEvents.map((event) => event.id),
          containsAll([result.event.id, result.definition.event.id]),
        );
      },
    );
  });
}
