import 'package:models/models.dart';
import 'package:test/test.dart';

void main() {
  group(CuratedList, () {
    final now = DateTime(2025, 6, 15);
    final later = DateTime(2025, 6, 16);

    CuratedList createSubject({
      String id = 'test-list-id',
      String name = 'Test List',
      String? pubkey =
          'abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890',
      String? description = 'A test list',
      String? imageUrl,
      List<String> videoEventIds = const [
        'aabbccdd11223344aabbccdd11223344aabbccdd11223344aabbccdd11223344',
        '34236:pubkey123:my-vine',
      ],
      DateTime? createdAt,
      DateTime? updatedAt,
      bool isPublic = true,
      String? nostrEventId,
      bool pendingRepublish = false,
      List<String> tags = const ['test'],
      bool isCollaborative = false,
      List<String> allowedCollaborators = const [],
      String? thumbnailEventId,
      PlayOrder playOrder = PlayOrder.chronological,
    }) {
      return CuratedList(
        id: id,
        name: name,
        pubkey: pubkey,
        description: description,
        imageUrl: imageUrl,
        videoEventIds: videoEventIds,
        createdAt: createdAt ?? now,
        updatedAt: updatedAt ?? now,
        isPublic: isPublic,
        nostrEventId: nostrEventId,
        pendingRepublish: pendingRepublish,
        tags: tags,
        isCollaborative: isCollaborative,
        allowedCollaborators: allowedCollaborators,
        thumbnailEventId: thumbnailEventId,
        playOrder: playOrder,
      );
    }

    test('can be instantiated with required fields', () {
      final list = CuratedList(
        id: 'id',
        name: 'name',
        videoEventIds: const [],
        createdAt: now,
        updatedAt: now,
      );
      expect(list.id, equals('id'));
      expect(list.name, equals('name'));
      expect(list.videoEventIds, isEmpty);
      expect(list.isPublic, isTrue);
      expect(list.pendingRepublish, isFalse);
      expect(list.playOrder, equals(PlayOrder.chronological));
      expect(list.isCollaborative, isFalse);
      expect(list.tags, isEmpty);
      expect(list.allowedCollaborators, isEmpty);
    });

    test('supports value equality', () {
      final list1 = createSubject();
      final list2 = createSubject();
      expect(list1, equals(list2));
    });

    test('supports value inequality', () {
      final list1 = createSubject(name: 'List A');
      final list2 = createSubject(name: 'List B');
      expect(list1, isNot(equals(list2)));
    });

    group('authorScopedId', () {
      test('tells same-named lists from different authors apart', () {
        final now = DateTime(2026);
        CuratedList list(String? pubkey) => CuratedList(
          id: 'my_vine_list',
          name: 'My List',
          videoEventIds: const [],
          createdAt: now,
          updatedAt: now,
          pubkey: pubkey,
        );

        expect(
          list('a' * 64).authorScopedId,
          isNot(equals(list('b' * 64).authorScopedId)),
        );
        expect(
          list('a' * 64).authorScopedId,
          equals('${'a' * 64}:my_vine_list'),
        );
        expect(list(null).authorScopedId, equals(':my_vine_list'));
      });
    });

    group('hasVideos', () {
      test('is true when the list references a video', () {
        expect(createSubject().hasVideos, isTrue);
      });

      test('is false when the list references no videos', () {
        expect(createSubject(videoEventIds: const []).hasVideos, isFalse);
      });
    });

    group('copyWith', () {
      test('returns same instance when no fields changed', () {
        final list = createSubject();
        expect(list.copyWith(), equals(list));
      });

      test('replaces name', () {
        final list = createSubject(name: 'Original');
        final copied = list.copyWith(name: 'Updated');
        expect(copied.name, equals('Updated'));
        expect(copied.id, equals(list.id));
      });

      test('replaces videoEventIds', () {
        final list = createSubject();
        final newIds = ['new-id-1', 'new-id-2'];
        final copied = list.copyWith(videoEventIds: newIds);
        expect(copied.videoEventIds, equals(newIds));
        expect(copied.name, equals(list.name));
      });

      test('replaces playOrder', () {
        final list = createSubject();
        final copied = list.copyWith(playOrder: PlayOrder.shuffle);
        expect(copied.playOrder, equals(PlayOrder.shuffle));
      });

      test('replaces updatedAt', () {
        final list = createSubject();
        final copied = list.copyWith(updatedAt: later);
        expect(copied.updatedAt, equals(later));
        expect(copied.createdAt, equals(list.createdAt));
      });

      test('keeps nostrEventId when it is not passed', () {
        final list = createSubject(nostrEventId: 'event-123');
        expect(
          list.copyWith(name: 'Renamed').nostrEventId,
          equals('event-123'),
        );
      });

      test('nulls description when clearDescription is set', () {
        final list = createSubject(description: 'Original');
        final copied = list.copyWith(clearDescription: true);
        expect(copied.description, isNull);
        expect(copied.name, equals(list.name));
      });

      test('nulls nostrEventId when clearNostrEventId is set', () {
        final list = createSubject(nostrEventId: 'event-123');
        final copied = list.copyWith(clearNostrEventId: true);
        expect(copied.nostrEventId, isNull);
        expect(copied.name, equals(list.name));
      });

      test('replaces pendingRepublish', () {
        final list = createSubject();
        final copied = list.copyWith(pendingRepublish: true);
        expect(copied.pendingRepublish, isTrue);
        expect(copied.name, equals(list.name));
      });
    });

    group('toJson', () {
      test('serializes all fields', () {
        final list = createSubject(
          nostrEventId: 'event-123',
          pendingRepublish: true,
          imageUrl: 'https://example.com/image.jpg',
          thumbnailEventId: 'thumb-456',
          isCollaborative: true,
          allowedCollaborators: ['collab-pubkey'],
          playOrder: PlayOrder.shuffle,
        );
        final json = list.toJson();

        expect(json['id'], equals('test-list-id'));
        expect(json['name'], equals('Test List'));
        expect(json['pubkey'], equals(list.pubkey));
        expect(json['description'], equals('A test list'));
        expect(json['imageUrl'], equals('https://example.com/image.jpg'));
        expect(json['videoEventIds'], hasLength(2));
        expect(json['isPublic'], isTrue);
        expect(json['nostrEventId'], equals('event-123'));
        expect(json['pendingRepublish'], isTrue);
        expect(json['tags'], equals(['test']));
        expect(json['isCollaborative'], isTrue);
        expect(json['allowedCollaborators'], equals(['collab-pubkey']));
        expect(json['thumbnailEventId'], equals('thumb-456'));
        expect(json['playOrder'], equals('shuffle'));
      });

      test('serializes DateTime as ISO 8601', () {
        final list = createSubject();
        final json = list.toJson();
        expect(json['createdAt'], equals(now.toIso8601String()));
        expect(json['updatedAt'], equals(now.toIso8601String()));
      });
    });

    group('fromJson', () {
      test('deserializes all fields', () {
        final original = createSubject(
          nostrEventId: 'event-123',
          imageUrl: 'https://example.com/image.jpg',
          isCollaborative: true,
          playOrder: PlayOrder.reverse,
        );
        final json = original.toJson();
        final deserialized = CuratedList.fromJson(json);

        expect(deserialized, equals(original));
      });

      test('handles missing optional fields with defaults', () {
        final json = <String, dynamic>{
          'id': 'minimal',
          'name': 'Minimal List',
          'createdAt': now.toIso8601String(),
          'updatedAt': now.toIso8601String(),
        };
        final list = CuratedList.fromJson(json);

        expect(list.id, equals('minimal'));
        expect(list.videoEventIds, isEmpty);
        expect(list.isPublic, isTrue);
        expect(list.pendingRepublish, isFalse);
        expect(list.isCollaborative, isFalse);
        expect(list.tags, isEmpty);
        expect(list.allowedCollaborators, isEmpty);
        expect(list.playOrder, equals(PlayOrder.chronological));
      });

      test('roundtrips through toJson/fromJson', () {
        final original = createSubject();
        final roundtripped = CuratedList.fromJson(original.toJson());
        expect(roundtripped, equals(original));
      });
    });

    group('UTF-16 well-formedness', () {
      // The headless flutter_tester does not throw on a lone surrogate — only
      // the real engine does — so this asserts the model value rather than a
      // rendered widget.
      test('replaces lone surrogates in name and description', () {
        final list = createSubject(
          name: 'Skate${String.fromCharCode(0xD83D)} picks',
          description: 'best of${String.fromCharCode(0xDE00)} 2025',
        );

        expect(list.name, equals('Skate� picks'));
        expect(list.description, equals('best of� 2025'));
      });

      test('keeps well-formed name and description identical', () {
        const name = 'Skate \u{1F600} picks';

        expect(createSubject(name: name).name, same(name));
        expect(createSubject(description: null).description, isNull);
      });
    });
  });

  group(PlayOrder, () {
    group('value', () {
      test('serializes all enum values', () {
        expect(PlayOrder.chronological.value, equals('chronological'));
        expect(PlayOrder.reverse.value, equals('reverse'));
        expect(PlayOrder.manual.value, equals('manual'));
        expect(PlayOrder.shuffle.value, equals('shuffle'));
      });
    });

    group('fromString', () {
      test('deserializes all enum values', () {
        expect(
          PlayOrderExtension.fromString('chronological'),
          equals(PlayOrder.chronological),
        );
        expect(
          PlayOrderExtension.fromString('reverse'),
          equals(PlayOrder.reverse),
        );
        expect(
          PlayOrderExtension.fromString('manual'),
          equals(PlayOrder.manual),
        );
        expect(
          PlayOrderExtension.fromString('shuffle'),
          equals(PlayOrder.shuffle),
        );
      });

      test('defaults to chronological for unknown values', () {
        expect(
          PlayOrderExtension.fromString('unknown'),
          equals(PlayOrder.chronological),
        );
        expect(
          PlayOrderExtension.fromString(''),
          equals(PlayOrder.chronological),
        );
      });
    });

    test('roundtrips through value/fromString', () {
      for (final order in PlayOrder.values) {
        expect(PlayOrderExtension.fromString(order.value), equals(order));
      }
    });
  });
}
