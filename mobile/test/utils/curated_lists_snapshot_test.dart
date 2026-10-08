// ABOUTME: Verifies complete immutable thumbnail-selection snapshots.
// ABOUTME: Covers serialization fidelity, nested mutation and ordered equality.

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/utils/curated_lists_snapshot.dart';

const _owner =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _event =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

CuratedList _list(String id) => CuratedList(
  id: id,
  name: 'Full list',
  pubkey: _owner,
  description: 'Description',
  imageUrl: 'https://example.com/cover.jpg',
  videoEventIds: List.of(const [_event]),
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime(2026, 2),
  isPublic: false,
  nostrEventId: _event,
  pendingRepublish: true,
  tags: List.of(const ['tag']),
  isCollaborative: true,
  allowedCollaborators: List.of(const [_owner]),
  thumbnailEventId: _event,
  thumbnailUrls: List.of(const ['https://example.com/thumbnail.jpg']),
  playOrder: PlayOrder.reverse,
);

class _WithNestedMetadata extends CuratedList {
  _WithNestedMetadata(this.metadata)
    : super(
        id: 'nested',
        name: 'Nested metadata',
        videoEventIds: const [],
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );

  final Map<String, dynamic> metadata;

  @override
  Map<String, dynamic> toJson() => {...super.toJson(), ...metadata};
}

void main() {
  group(CuratedListsSnapshot, () {
    test(
      'new nested serialized fields are captured without a field allowlist',
      () {
        final collaborators = [_owner];
        final pendingIds = [_event];
        final visibility = <String, dynamic>{
          'isPublic': false,
          'allowedCollaborators': collaborators,
          'relayAccepted': true,
        };
        final original = _WithNestedMetadata({
          'pendingVisibility': visibility,
          'pendingPlaintextEventIds': pendingIds,
        });
        final snapshot = CuratedListsSnapshot([original]);
        final hash = snapshot.hashCode;
        final equal = CuratedListsSnapshot([
          _WithNestedMetadata(const {
            'pendingVisibility': {
              'isPublic': false,
              'allowedCollaborators': [_owner],
              'relayAccepted': true,
            },
            'pendingPlaintextEventIds': [_event],
          }),
        ]);
        collaborators.clear();
        pendingIds.clear();
        visibility['relayAccepted'] = false;
        expect(snapshot, equal);
        expect(snapshot.hashCode, hash);
        expect(snapshot, isNot(CuratedListsSnapshot([original])));
      },
    );
    test('serialization roundtrip preserves every model property', () {
      final original = _list('one');
      final restored = CuratedListsSnapshot([original]).lists.single;
      expect(restored, original);
      expect(restored.props, original.props);
      expect(restored.toJson(), original.toJson());
    });

    test('all input lists are deeply captured rather than shared', () {
      final original = _list('one');
      final snapshot = CuratedListsSnapshot([original]);
      final unchanged = CuratedListsSnapshot([_list('one')]);
      final hash = snapshot.hashCode;
      original.videoEventIds.clear();
      original.tags.clear();
      original.allowedCollaborators.clear();
      original.thumbnailUrls.clear();
      expect(snapshot, unchanged);
      expect(snapshot.hashCode, hash);
      expect(snapshot, isNot(CuratedListsSnapshot([original])));
      expect(snapshot.lists.single, _list('one'));
    });

    test('restored arrays cannot mutate the captured selection', () {
      final snapshot = CuratedListsSnapshot([_list('one')]);
      snapshot.lists.single.videoEventIds.clear();
      snapshot.lists.single.tags.clear();
      expect(snapshot.lists.single, _list('one'));
      expect(() => snapshot.lists.clear(), throwsUnsupportedError);
    });

    test(
      'row order, full metadata and equal reconstructed models compare correctly',
      () {
        final one = _list('one');
        final two = _list('two');
        final snapshot = CuratedListsSnapshot([one, two]);
        final same = CuratedListsSnapshot([
          CuratedList.fromJson(one.toJson()),
          CuratedList.fromJson(two.toJson()),
        ]);
        expect(snapshot, same);
        expect(snapshot.hashCode, same.hashCode);
        expect(snapshot, isNot(CuratedListsSnapshot([two, one])));
        expect(
          snapshot,
          isNot(CuratedListsSnapshot([one.copyWith(name: 'Renamed'), two])),
        );
      },
    );
  });
}
