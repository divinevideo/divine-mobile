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

    group('cache queries', () {
      final video = 'd' * 64;
      final owned = list(owner).copyWith(
        nostrEventId: 'e' * 64,
        name: 'Sea otters',
        description: 'Rocks and shells',
        tags: const ['nature', 'ocean'],
        videoEventIds: [video],
      );
      final foreign = list(author).copyWith(
        nostrEventId: 'f' * 64,
        name: 'Ocean walks',
        tags: const ['walks', 'nature'],
        videoEventIds: [video],
      );
      final private = list(owner, id: 'private').copyWith(
        isPublic: false,
        nostrEventId: '1' * 64,
        name: 'Secret sea otters',
        description: 'Hidden rocks',
        tags: const ['secret', 'nature'],
        videoEventIds: [video],
      );
      final local = list(null, id: 'draft').copyWith(isPublic: false);
      final index = CuratedListCacheIndex(
        [foreign, owned, private, local],
        ownerPubkey: owner,
      );

      test(
        'public discovery excludes private names, descriptions and tags',
        () {
          expect(index.publicListsByTag('NATURE'), [foreign, owned]);
          expect(index.publicListsByTag('SECRET'), isEmpty);
          expect(index.publicTags, ['nature', 'ocean', 'walks']);
          expect(index.searchPublic('SEA OTTERS'), [owned]);
          expect(index.searchPublic('ROCKS'), [owned]);
          expect(index.searchPublic('WALKS'), [foreign]);
          expect(index.searchPublic('secret'), isEmpty);
          expect(index.searchPublic('   '), isEmpty);
          // Preserve the existing typed-query contract: only case folds.
          expect(index.searchPublic(' sea otters '), isEmpty);
        },
      );

      test('membership preserves both authors and private owned records', () {
        expect(index.containingVideo(video), [foreign, owned, private]);
        expect(index.containingVideo('2' * 64), isEmpty);
      });

      test(
        'owned query uses the supplied authenticated account and drafts',
        () {
          expect(index.unpublishedOrOwnedBy(owner), [owned, private, local]);
          expect(index.unpublishedOrOwnedBy(author), [foreign, local]);
          expect(index.unpublishedOrOwnedBy(null), [local]);
          expect(index.isOwnedBy(owned.authorScopedId, owner), isTrue);
          expect(index.isOwnedBy(foreign.authorScopedId, owner), isFalse);
          expect(index.isOwnedBy('missing', owner), isFalse);
          expect(index.isOwnedBy('private', null), isFalse);
          expect(index.isOwnedBy('private', ''), isFalse);
          expect(index.isOwnedBy('draft', owner), isFalse);
        },
      );

      test('collaboration resolves the full coordinate and retains policy', () {
        final collaborative = foreign.copyWith(
          isCollaborative: true,
          allowedCollaborators: [third],
        );
        final collaborators = CuratedListCacheIndex(
          [collaborative, owned],
          ownerPubkey: owner,
        );
        expect(collaborators.canCollaborate('missing', owner), isFalse);
        expect(
          collaborators.canCollaborate(owned.authorScopedId, owner),
          isTrue,
        );
        expect(
          collaborators.canCollaborate(collaborative.authorScopedId, third),
          isTrue,
        );
        expect(
          collaborators.canCollaborate(owned.authorScopedId, third),
          isFalse,
        );
        expect(
          collaborators.canCollaborate(collaborative.authorScopedId, author),
          isFalse,
        );
      });

      test('same-millisecond local IDs cannot replace any cached author', () {
        final now = DateTime.utc(2026);
        final first = 'list_${now.millisecondsSinceEpoch}';
        final collisions = CuratedListCacheIndex(
          [
            list(owner, id: first),
            list(author, id: '${first}_1'),
            list(null, id: '${first}_2'),
          ],
          ownerPubkey: owner,
        );
        expect(collisions.nextLocalId(now), '${first}_3');
        expect(index.nextLocalId(now), first);
      });
    });
  });
}
