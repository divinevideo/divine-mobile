import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:test/test.dart';

void main() {
  group(SoundSearchResponse, () {
    group('fromJson', () {
      test('reads the sounds in the order the server ranked them', () {
        final response = SoundSearchResponse.fromJson(const {
          'data': [
            {'id': 'best', 'usage_count': 4},
            {'id': 'next', 'usage_count': 9},
          ],
          'pagination': {'next_cursor': 'abc', 'has_more': true},
        });

        expect(response.sounds.map((sound) => sound.id), ['best', 'next']);
        expect(response.sounds.map((sound) => sound.usageCount), [4, 9]);
      });

      test('keeps the next cursor while the server has more', () {
        final response = SoundSearchResponse.fromJson(const {
          'data': <Object>[],
          'pagination': {'next_cursor': 'abc', 'has_more': true},
        });

        expect(response.nextCursor, 'abc');
        expect(response.hasMore, isTrue);
      });

      test('ends the results when the server has no more', () {
        final response = SoundSearchResponse.fromJson(const {
          'data': [
            {'id': 'last'},
          ],
          'pagination': {'next_cursor': 'abc', 'has_more': false},
        });

        expect(response.nextCursor, isNull);
        expect(response.hasMore, isFalse);
      });

      test('ends the results when more are promised without a cursor', () {
        for (final pagination in const [
          {'has_more': true},
          {'next_cursor': '', 'has_more': true},
        ]) {
          final response = SoundSearchResponse.fromJson({
            'data': const <Object>[],
            'pagination': pagination,
          });

          expect(response.hasMore, isFalse, reason: '$pagination');
        }
      });

      test('ends the results without a pagination object', () {
        final response = SoundSearchResponse.fromJson(const {
          'data': <Object>[],
        });

        expect(response.hasMore, isFalse);
      });

      test('skips entries that are not objects', () {
        final response = SoundSearchResponse.fromJson(const {
          'data': [
            'stray',
            {'id': 'kept'},
          ],
        });

        expect(response.sounds.map((sound) => sound.id), ['kept']);
      });

      test('throws a FormatException without a data list', () {
        expect(
          () => SoundSearchResponse.fromJson(const {'data': 'nope'}),
          throwsFormatException,
        );
      });
    });
  });
}
