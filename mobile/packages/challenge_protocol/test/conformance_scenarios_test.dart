import 'package:challenge_protocol/challenge_protocol.dart';
import 'package:test/test.dart';

import 'fixture_loader.dart';

void main() {
  final data = fixture('scenarios.json');
  final scenarios = data['scenarios']! as List<Object?>;
  test('complete versioned replay corpus', () {
    expect(data['version'], 1);
    expect(scenarios, hasLength(22));
  });
  for (final item in scenarios) {
    final s = item! as Map<String, Object?>;
    for (final reverse in [false, true]) {
      test('${s['name']} reversed=$reverse', () {
        final events = s['events']! as List<Object?>;
        final hidden = s['hiddenIds']! as List<Object?>;
        final view = reduceChallenge(
          reverse ? events.reversed.toList() : events,
          s['coordinate']! as String,
          s['now']! as int,
          (e) => !hidden.contains(e.id),
        );
        expect({
          'state': view.state,
          'entryIds': view.entries.map((e) => e.event.id).toList(),
          'resultId': view.currentResult?.result.event.id,
          'pending': view.pending,
          'unavailableWinnerIds':
              view.currentResult?.winners
                  .where((w) => !w.available)
                  .map((w) => w.entryId)
                  .toList() ??
              <String>[],
        }, s['expected']);
      });
    }
  }
}
