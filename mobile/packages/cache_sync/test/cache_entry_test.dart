import 'package:cache_sync/cache_sync.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(CacheEntry, () {
    group('equality', () {
      test('is equal when payload and staleness match', () {
        const a = CacheEntry(payload: 'p', isStale: true);
        const b = CacheEntry(payload: 'p', isStale: true);

        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('differs when staleness differs', () {
        const fresh = CacheEntry(payload: 'p', isStale: false);
        const stale = CacheEntry(payload: 'p', isStale: true);

        expect(fresh, isNot(equals(stale)));
      });

      test('differs when payload differs', () {
        const a = CacheEntry(payload: 'a', isStale: false);
        const b = CacheEntry(payload: 'b', isStale: false);

        expect(a, isNot(equals(b)));
      });
    });

    test('toString names the staleness and payload', () {
      const entry = CacheEntry(payload: 'p', isStale: true);

      expect(entry.toString(), equals('CacheEntry(isStale: true, payload: p)'));
    });
  });
}
