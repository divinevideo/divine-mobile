// ABOUTME: Tests reading a poll's vote tally from the Funnelcake answer.

import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:test/test.dart';

void main() {
  group(PollVoteTally, () {
    group('fromJson', () {
      test('reads the votes of every answer and the voters', () {
        final tally = PollVoteTally.fromJson(const {
          'options': [
            {'id': '0', 'votes': 2},
            {'id': '1', 'votes': '5'},
            {'id': '2', 'votes': 1.0},
          ],
          'voters': 8,
        });

        expect(tally.votes, equals({'0': 2, '1': 5, '2': 1}));
        expect(tally.voters, equals(8));
      });

      test('skips answers without an id and reads odd counts as 0', () {
        final tally = PollVoteTally.fromJson(const {
          'options': [
            {'votes': 4},
            {'id': '0', 'votes': 'many'},
            {'id': '1'},
            'not an answer',
          ],
        });

        expect(tally.votes, equals({'0': 0, '1': 0}));
        expect(tally.voters, equals(0));
      });

      test('reads no answers when the list is missing', () {
        expect(PollVoteTally.fromJson(const {}).votes, isEmpty);
      });
    });
  });
}
