import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/router/routes/route_extras.dart';

void main() {
  group('extraAs', () {
    test('returns the value when it already is the requested type', () {
      const extra = CuratedListRouteExtra(listName: 'Favourites');

      expect(extraAs<CuratedListRouteExtra>(extra), same(extra));
    });

    test('returns null for a restored Map instead of throwing (the route '
        'restoration / deep-link crash)', () {
      // After restoration or a deep link GoRouter hands `extra` back as a
      // plain Map<String, dynamic>, not the typed object. A raw `as` cast
      // throws here (Crashlytics 5b96bfc6… / efec8882…); the guard must
      // return null so the route falls back gracefully.
      final restored = <String, dynamic>{
        'listName': 'Favourites',
        'videoIds': <String>['a', 'b'],
      };

      expect(extraAs<CuratedListRouteExtra>(restored), isNull);
    });

    test('reads a restored Map when the caller asks for a Map', () {
      final restored = <String, dynamic>{
        'displayName': 'Ada',
        'avatarUrl': null,
      };

      final map = extraAs<Map<String, dynamic>>(restored);

      expect(map, same(restored));
      expect(map?['displayName'] as String?, 'Ada');
      expect(map?['avatarUrl'] as String?, isNull);
    });

    test('returns null for a scalar-type mismatch', () {
      expect(extraAs<String>(<String, dynamic>{'a': 1}), isNull);
      expect(extraAs<String>('hint'), 'hint');
    });

    test('returns null for a null payload', () {
      expect(extraAs<CuratedListRouteExtra>(null), isNull);
    });

    test('keeps the discovered record on a typed list extra', () {
      final list = CuratedList(
        id: 'skate',
        name: 'Skate',
        pubkey: 'a' * 64,
        videoEventIds: const ['v1'],
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      final extra = CuratedListRouteExtra(listName: list.name, list: list);

      expect(extraAs<CuratedListRouteExtra>(extra)?.list, same(list));
    });
  });

  group('restored map values', () {
    test('reads typed values from restored dynamic maps', () {
      final restored = <String, dynamic>{
        'displayName': 'Ada',
        'avatarUrl': 42,
        'fromLibrary': true,
      };

      expect(extraValue<String>(restored, 'displayName'), 'Ada');
      expect(extraValue<String>(restored, 'avatarUrl'), isNull);
      expect(extraValue<bool>(restored, 'fromLibrary'), isTrue);
      expect(extraValue<String>(null, 'displayName'), isNull);
    });

    test('reads typed values from restored object maps', () {
      final restored = <Object?, Object?>{
        'displayName': 'Ada',
        'avatarUrl': 42,
        'fromLibrary': true,
      };

      expect(extraValue<String>(restored, 'displayName'), 'Ada');
      expect(extraValue<String>(restored, 'avatarUrl'), isNull);
      expect(extraValue<bool>(restored, 'fromLibrary'), isTrue);
    });

    test('ignores malformed or missing values', () {
      expect(
        extraValue<bool>(<String, dynamic>{
          'fromLibrary': 'true',
        }, 'fromLibrary'),
        isNull,
      );
      expect(
        extraValue<bool>(const <String, dynamic>{}, 'fromLibrary'),
        isNull,
      );
    });
  });
}
