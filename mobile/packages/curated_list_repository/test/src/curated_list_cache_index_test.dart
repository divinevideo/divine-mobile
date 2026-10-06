import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:models/models.dart';
import 'package:test/test.dart';

void main() {
  group(CuratedListCacheIndex, () {
    final owner = 'a' * 64;
    final author = 'b' * 64;
    final third = 'c' * 64;
    CuratedList list(String? pubkey, {String id = 'shared'}) => CuratedList(
      id: id,
      name: 'List',
      pubkey: pubkey,
      videoEventIds: const [],
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    test('coordinates stay separate while unscoped IDs prefer the owner', () {
      final foreign = list(author);
      final owned = list(owner);
      final index = CuratedListCacheIndex([foreign, owned], ownerPubkey: owner);
      expect(index.find('shared'), owned);
      expect(index.find(foreign.authorScopedId), foreign);
      expect(index.find('$third:shared'), isNull);
      expect(index.findOwned('shared'), owned);
      expect(index.indexOf('shared'), 1);
      expect(index.indexOf('missing'), -1);
    });

    test('missing coordinates cannot resolve a literal colliding d-tag', () {
      final literal = list(owner, id: '$third:shared:part');
      final index = CuratedListCacheIndex([literal], ownerPubkey: owner);
      expect(index.find('$third:shared:part'), isNull);
      expect(index.indexOf('$third:shared:part'), -1);
      expect(index.find(literal.authorScopedId), literal);
      expect(index.findOwned(literal.id), literal);
    });

    test('unpublished records and legacy foreign IDs remain readable', () {
      final unpublished = list(null);
      final foreign = list(author, id: 'other');
      final index = CuratedListCacheIndex([
        unpublished,
        foreign,
      ], ownerPubkey: owner);
      expect(index.find('shared'), unpublished);
      expect(index.find('other'), foreign);
      expect(index.findOwned('other'), isNull);
    });

    test('scoped and legacy subscription aliases never cross authors', () {
      final foreign = list(author);
      final owned = list(owner);
      final index = CuratedListCacheIndex([foreign, owned], ownerPubkey: owner);
      expect(
        index.subscriptionId(foreign.authorScopedId, {foreign.authorScopedId}),
        foreign.authorScopedId,
      );
      expect(
        index.subscriptionId('shared', {owned.authorScopedId}),
        owned.authorScopedId,
      );
      expect(index.subscriptionId(owned.authorScopedId, {'shared'}), 'shared');
      expect(
        index.subscriptionId(foreign.authorScopedId, {'shared'}),
        foreign.authorScopedId,
      );
      expect(index.subscriptionId('missing', {}), 'missing');
    });
  });
}
