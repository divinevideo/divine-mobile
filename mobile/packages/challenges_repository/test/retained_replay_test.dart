import 'dart:convert';

import 'package:challenges_repository/challenges_repository.dart';
import 'package:test/test.dart';

import 'protocol_fixture_file.dart';
import 'repository_test.dart' show FakeSource, MemoryStore;

void main() {
  final fixture = jsonDecode(
    fixtureFile('v1/scenarios.json').readAsStringSync(),
  ) as Map<String, Object?>;
  group('retained dependency replay', () {
    for (final scenario
        in (fixture['scenarios']! as List<Object?>)
            .cast<Map<String, Object?>>()) {
      for (final reverse in [false, true]) {
        test('${scenario['name']} reverse=$reverse', () async {
          final events = (scenario['events']! as List<Object?>)
              .map(jsonEncode)
              .toList();
          final coordinate = scenario['coordinate']! as String;
          final hidden = scenario['hiddenIds']! as List<Object?>;
          final source = FakeSource([]);
          final store = MemoryStore();
          ChallengesRepository repository() => ChallengesRepository(
            source: source.read,
            store: store,
            clock: () => scenario['now']! as int,
            isVisible: (event) => !hidden.contains(event.id),
          );
          final writer = repository();
          for (final event in reverse ? events.reversed : events) {
            source.records = [event];
            await writer.refresh(coordinate);
          }
          // A fresh instance must reduce retained dependencies and current
          // policy, not a mutable previously cached projection.
          source.records = [];
          final view = (await repository().refresh(coordinate)).view;
          expect({
            'state': view.state,
            'entryIds': view.entries.map((entry) => entry.event.id).toList(),
            'resultId': view.currentResult?.result.event.id,
            'pending': view.pending,
            'unavailableWinnerIds':
                view.currentResult?.winners
                    .where((winner) => !winner.available)
                    .map((winner) => winner.entryId)
                    .toList() ??
                <String>[],
          }, scenario['expected']);
        });
      }
    }
  });
}
