import 'package:models/models.dart';
import 'package:test/test.dart';

void main() {
  group(BulkVideoStatsEntry, () {
    group('constructor', () {
      test('creates instance with required fields', () {
        const entry = BulkVideoStatsEntry(
          eventId: 'abc123',
          reactions: 10,
          comments: 5,
          reposts: 2,
        );

        expect(entry.eventId, equals('abc123'));
        expect(entry.reactions, equals(10));
        expect(entry.comments, equals(5));
        expect(entry.reposts, equals(2));
        expect(entry.loops, isNull);
        expect(entry.views, isNull);
      });

      test('creates instance with all fields', () {
        const entry = BulkVideoStatsEntry(
          eventId: 'abc123',
          reactions: 10,
          comments: 5,
          reposts: 2,
          loops: 1000,
          views: 500,
        );

        expect(entry.loops, equals(1000));
        expect(entry.views, equals(500));
      });
    });

    group('fromJson', () {
      test('parses with event_id key', () {
        final entry = BulkVideoStatsEntry.fromJson(const {
          'event_id': 'abc123',
          'reactions': 10,
          'comments': 5,
          'reposts': 2,
        });

        expect(entry.eventId, equals('abc123'));
        expect(entry.reactions, equals(10));
      });

      test('parses with id key as fallback', () {
        final entry = BulkVideoStatsEntry.fromJson(const {
          'id': 'abc123',
          'reactions': 10,
          'comments': 5,
          'reposts': 2,
        });

        expect(entry.eventId, equals('abc123'));
      });

      test('finds likes under various keys', () {
        final entry = BulkVideoStatsEntry.fromJson(const {
          'event_id': 'test',
          'likes': 42,
          'comments': 0,
          'reposts': 0,
        });

        expect(entry.reactions, equals(42));
      });

      test('finds likes under total_likes', () {
        final entry = BulkVideoStatsEntry.fromJson(const {
          'event_id': 'test',
          'total_likes': 42,
        });

        expect(entry.reactions, equals(42));
      });

      test('finds comments under comment_count', () {
        final entry = BulkVideoStatsEntry.fromJson(const {
          'event_id': 'test',
          'comment_count': 15,
        });

        expect(entry.comments, equals(15));
      });

      test('finds loops under various keys', () {
        final entry = BulkVideoStatsEntry.fromJson(const {
          'event_id': 'test',
          'total_loops': 5000,
        });

        expect(entry.loops, equals(5000));
      });

      test('keeps live loops and archival embedded_loops separate', () {
        // Real bulk-stats payload shape for a classic Vine: `loops` is a
        // live computed value while `embedded_loops` is the Vine-era count.
        final entry = BulkVideoStatsEntry.fromJson(const {
          'event_id': 'test',
          'views': 3020,
          'reactions': 387,
          'comments': 10,
          'reposts': 42,
          'loops': 1538.46,
          'embedded_loops': 142678928,
        });

        expect(entry.loops, equals(1538));
        expect(entry.embeddedLoops, equals(142678928));
      });

      test('embedded_loops does not fill live loops', () {
        final entry = BulkVideoStatsEntry.fromJson(const {
          'event_id': 'test',
          'embedded_loops': 142678928,
        });

        expect(entry.loops, isNull);
        expect(entry.embeddedLoops, equals(142678928));
      });

      test('keeps total views separate from unique viewers', () {
        final entry = BulkVideoStatsEntry.fromJson(const {
          'event_id': 'video',
          'views': 120,
          'unique_viewers': 45,
        });

        expect(entry.views, 120);
        expect(entry.uniqueViewers, 45);
      });

      test('does not treat unique viewers as total views', () {
        final entry = BulkVideoStatsEntry.fromJson(const {
          'event_id': 'video',
          'unique_viewers': 45,
        });

        expect(entry.views, isNull);
        expect(entry.uniqueViewers, 45);
      });

      test('finds views under view_count', () {
        final entry = BulkVideoStatsEntry.fromJson(const {
          'event_id': 'test',
          'view_count': 200,
        });

        expect(entry.views, equals(200));
      });

      test('handles string values with commas', () {
        final entry = BulkVideoStatsEntry.fromJson(const {
          'event_id': 'test',
          'reactions': '1,000',
          'loops': '5,000',
        });

        expect(entry.reactions, equals(1000));
        expect(entry.loops, equals(5000));
      });

      test('handles nested stats', () {
        final entry = BulkVideoStatsEntry.fromJson(const {
          'event_id': 'test',
          'stats': {'reactions': 10, 'comments': 5, 'loops': 100},
        });

        expect(entry.reactions, equals(10));
        expect(entry.comments, equals(5));
        expect(entry.loops, equals(100));
      });

      test('normalizes invalid engagement counters to zero', () {
        final entry = BulkVideoStatsEntry.fromJson(const {
          'event_id': 'test',
          'stats': {
            'reactions': -1,
            'comments': '9223372036854775807',
            'reposts': '18446744073709551615',
          },
        });

        expect(entry.reactions, equals(0));
        expect(entry.comments, equals(0));
        expect(entry.reposts, equals(0));
      });

      test('falls through invalid top-level engagement counters', () {
        final entry = BulkVideoStatsEntry.fromJson(const {
          'event_id': 'test',
          'comments': '',
          'stats': {'comments': 5},
        });

        expect(entry.comments, equals(5));
      });

      test('top-level zero wins over nested non-zero engagement counts', () {
        final entry = BulkVideoStatsEntry.fromJson(const {
          'event_id': 'test',
          'comments': 0,
          'stats': {'comments': 5},
        });

        expect(entry.comments, equals(0));
      });

      test('defaults to 0 when no matching key found', () {
        final entry = BulkVideoStatsEntry.fromJson(const {'event_id': 'test'});

        expect(entry.reactions, equals(0));
        expect(entry.comments, equals(0));
        expect(entry.reposts, equals(0));
        expect(entry.loops, isNull);
        expect(entry.views, isNull);
      });

      test('handles empty JSON', () {
        final entry = BulkVideoStatsEntry.fromJson(const <String, dynamic>{});

        expect(entry.eventId, isEmpty);
        expect(entry.reactions, equals(0));
      });
    });

    group('equality', () {
      test('two entries with same eventId are equal', () {
        const a = BulkVideoStatsEntry(
          eventId: 'abc',
          reactions: 1,
          comments: 0,
          reposts: 0,
        );
        const b = BulkVideoStatsEntry(
          eventId: 'abc',
          reactions: 99,
          comments: 99,
          reposts: 99,
        );

        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('two entries with different eventIds are not equal', () {
        const a = BulkVideoStatsEntry(
          eventId: 'abc',
          reactions: 1,
          comments: 0,
          reposts: 0,
        );
        const b = BulkVideoStatsEntry(
          eventId: 'def',
          reactions: 1,
          comments: 0,
          reposts: 0,
        );

        expect(a, isNot(equals(b)));
      });
    });

    group('cross-contamination guards', () {
      test(
        'does not pick up engagement counts from deeply nested objects',
        () {
          // A fresh video entry may arrive with deeply-nested sibling sections
          // (e.g. a vine_archive block or an event sub-object) that contain
          // non-zero engagement values from unrelated data. The parser must
          // not assign those values to the current video's engagement counters.
          final entry = BulkVideoStatsEntry.fromJson(const {
            'event_id': 'abc123',
            // Top-level engagement keys are absent / zero for a fresh upload.
            'reactions': 0,
            'comments': 0,
            'reposts': 0,
            // Deep nested object that has its own engagement data.
            'vine_archive': {
              'event': {
                'likes': 1547,
                'comments': 320,
                'reposts': 88,
              },
            },
          });

          expect(
            entry.reactions,
            equals(0),
            reason: 'vine_archive.event.likes must not leak into reactions',
          );
          expect(
            entry.comments,
            equals(0),
            reason: 'vine_archive.event.comments must not leak into comments',
          );
          expect(
            entry.reposts,
            equals(0),
            reason: 'vine_archive.event.reposts must not leak into reposts',
          );
        },
      );

      test(
        'does not pick up engagement counts from sibling stats in same payload',
        () {
          // If the API includes a sibling stats block for a different context
          // (e.g. trending stats or author stats) that contains non-zero
          // engagement values, those must not be attributed to this video.
          final entry = BulkVideoStatsEntry.fromJson(const {
            'event_id': 'abc123',
            // No direct engagement keys on this entry.
            'author_stats': {
              'reactions': 9999,
              'total_likes': 50000,
            },
          });

          expect(
            entry.reactions,
            equals(0),
            reason: 'author_stats.reactions must not leak into video reactions',
          );
        },
      );

      test('still reads reactions from allowed stats sub-object', () {
        // The fix must preserve reading from the explicit "stats" sub-object,
        // which is the documented one-level nesting the API can return.
        final entry = BulkVideoStatsEntry.fromJson(const {
          'event_id': 'abc123',
          'stats': {'reactions': 42, 'comments': 7, 'reposts': 3},
        });

        expect(entry.reactions, equals(42));
        expect(entry.comments, equals(7));
        expect(entry.reposts, equals(3));
      });
    });

    group('toString', () {
      test('returns readable representation', () {
        const entry = BulkVideoStatsEntry(
          eventId: 'abc123',
          reactions: 10,
          comments: 5,
          reposts: 2,
        );

        expect(
          entry.toString(),
          equals(
            'BulkVideoStatsEntry(eventId: abc123, '
            'reactions: 10, comments: 5)',
          ),
        );
      });
    });
  });
}
