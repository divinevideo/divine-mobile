import 'package:models/models.dart';
import 'package:test/test.dart';

void main() {
  group(UserList, () {
    final now = DateTime(2024, 6, 15);
    final userList = UserList(
      id: 'test_list',
      name: 'Test List',
      description: 'A test list',
      imageUrl: 'https://example.com/image.png',
      pubkeys: const ['pubkey1', 'pubkey2'],
      createdAt: now,
      updatedAt: now,
      nostrEventId: 'event123',
    );

    group('constructor', () {
      test('creates instance with required parameters', () {
        final list = UserList(
          id: 'id',
          name: 'name',
          pubkeys: const ['pk1'],
          createdAt: now,
          updatedAt: now,
        );
        expect(list.id, equals('id'));
        expect(list.name, equals('name'));
        expect(list.pubkeys, equals(['pk1']));
        expect(list.isPublic, isTrue);
        expect(list.isEditable, isTrue);
        expect(list.description, isNull);
        expect(list.imageUrl, isNull);
        expect(list.nostrEventId, isNull);
      });
    });

    group('fromJson', () {
      test('creates instance from JSON map', () {
        final json = userList.toJson();
        final result = UserList.fromJson(json);

        expect(result.id, equals('test_list'));
        expect(result.name, equals('Test List'));
        expect(result.description, equals('A test list'));
        expect(result.imageUrl, equals('https://example.com/image.png'));
        expect(result.pubkeys, equals(['pubkey1', 'pubkey2']));
        expect(result.createdAt, equals(now));
        expect(result.updatedAt, equals(now));
        expect(result.isPublic, isTrue);
        expect(result.nostrEventId, equals('event123'));
        expect(result.isEditable, isTrue);
      });

      test('handles missing optional fields', () {
        final json = <String, dynamic>{
          'id': 'id',
          'name': 'name',
          'createdAt': now.toIso8601String(),
          'updatedAt': now.toIso8601String(),
        };
        final result = UserList.fromJson(json);

        expect(result.pubkeys, isEmpty);
        expect(result.description, isNull);
        expect(result.imageUrl, isNull);
        expect(result.isPublic, isTrue);
        expect(result.nostrEventId, isNull);
        expect(result.isEditable, isTrue);
      });
    });

    group('toJson', () {
      test('serializes all fields to JSON', () {
        final json = userList.toJson();

        expect(json['id'], equals('test_list'));
        expect(json['name'], equals('Test List'));
        expect(json['description'], equals('A test list'));
        expect(json['imageUrl'], equals('https://example.com/image.png'));
        expect(json['pubkeys'], equals(['pubkey1', 'pubkey2']));
        expect(json['isPublic'], isTrue);
        expect(json['nostrEventId'], equals('event123'));
        expect(json['isEditable'], isTrue);
      });
    });

    group('copyWith', () {
      test('returns copy with updated name', () {
        final copy = userList.copyWith(name: 'Updated');
        expect(copy.name, equals('Updated'));
        expect(copy.id, equals(userList.id));
        expect(copy.pubkeys, equals(userList.pubkeys));
      });

      test('returns copy with updated pubkeys', () {
        final copy = userList.copyWith(pubkeys: ['pk3']);
        expect(copy.pubkeys, equals(['pk3']));
        expect(copy.name, equals(userList.name));
      });

      test('returns identical copy when no arguments', () {
        final copy = userList.copyWith();
        expect(copy, equals(userList));
      });

      test('keeps the description when none is given', () {
        final described = userList.copyWith(description: 'The crew');
        expect(described.description, equals('The crew'));

        expect(described.copyWith(name: 'Renamed').description, 'The crew');
      });

      test('drops the description with clearDescription', () {
        final described = userList.copyWith(description: 'The crew');
        expect(described.description, isNotNull);

        expect(described.copyWith(clearDescription: true).description, isNull);
      });

      test('refuses a description alongside clearDescription', () {
        expect(
          () => userList.copyWith(description: 'x', clearDescription: true),
          throwsArgumentError,
        );
      });
    });

    group('Equatable', () {
      test('instances with same props are equal', () {
        final a = UserList(
          id: 'id',
          name: 'name',
          pubkeys: const [],
          createdAt: now,
          updatedAt: now,
        );
        final b = UserList(
          id: 'id',
          name: 'name',
          pubkeys: const [],
          createdAt: now,
          updatedAt: now,
        );
        expect(a, equals(b));
      });

      test('instances with different props are not equal', () {
        final a = UserList(
          id: 'id1',
          name: 'name',
          pubkeys: const [],
          createdAt: now,
          updatedAt: now,
        );
        final b = UserList(
          id: 'id2',
          name: 'name',
          pubkeys: const [],
          createdAt: now,
          updatedAt: now,
        );
        expect(a, isNot(equals(b)));
      });
    });

    group('UTF-16 well-formedness', () {
      // The headless flutter_tester does not throw on a lone surrogate — only
      // the real engine does — so this asserts the model value rather than a
      // rendered widget.
      test('replaces lone surrogates in name and description', () {
        final list = UserList(
          id: 'id',
          name: 'Friends${String.fromCharCode(0xD83D)}',
          description: 'people I${String.fromCharCode(0xDE00)} follow',
          pubkeys: const [],
          createdAt: now,
          updatedAt: now,
        );

        expect(list.name, equals('Friends�'));
        expect(list.description, equals('people I� follow'));
      });

      test('keeps a well-formed name identical', () {
        const name = 'Friends \u{1F600}';
        final list = UserList(
          id: 'id',
          name: name,
          pubkeys: const [],
          createdAt: now,
          updatedAt: now,
        );

        expect(list.name, same(name));
        expect(list.description, isNull);
      });
    });
  });
}
