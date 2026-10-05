import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:models/models.dart';
import 'package:test/test.dart';

void main() {
  const owner =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const foreign =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
  const plaintext =
      'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
  const prior =
      'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
  final origin = DateTime.utc(2026, 10, 5);
  CuratedList row({
    required String name,
    required bool public,
    int seconds = 0,
    bool collaborative = false,
    String? eventId,
    List<String> ids = const [],
    List<String> pending = const [],
  }) => CuratedList(
    id: 'same',
    name: name,
    pubkey: owner,
    createdAt: origin,
    updatedAt: origin.add(Duration(seconds: seconds)),
    isPublic: public,
    isCollaborative: collaborative,
    allowedCollaborators: const [foreign],
    nostrEventId: eventId,
    videoEventIds: ids,
    pendingPlaintextEventIds: pending,
  );

  for (final relayNewer in [false, true]) {
    test(
      'private union keeps unique items in preferred source order '
      'with relayNewer=$relayNewer',
      () {
        final local = row(
          name: 'Local',
          public: false,
          ids: ['first', 'shared'],
          pending: [prior],
        );
        final relay = row(
          name: 'Relay',
          public: true,
          seconds: relayNewer ? 1 : -1,
          collaborative: true,
          eventId: plaintext,
          ids: ['shared', 'last'],
        );
        final merged = CuratedListConverter.mergeUnpublished(
          local,
          relay,
          mergedAt: origin.add(const Duration(seconds: 2)),
        );
        expect(merged.name, relayNewer ? 'Relay' : 'Local');
        expect(
          merged.videoEventIds,
          relayNewer
              ? ['shared', 'last', 'first']
              : ['first', 'shared', 'last'],
        );
        expect(merged.createdAt, local.createdAt);
        expect(merged.updatedAt, origin.add(const Duration(seconds: 2)));
        expect(merged.isPublic, isFalse);
        expect(merged.isCollaborative, isFalse);
        expect(merged.allowedCollaborators, isEmpty);
        expect(merged.nostrEventId, isNull);
        expect(merged.pendingPlaintextEventIds, [prior, plaintext]);
      },
    );
  }

  test(
    'public/public union retains collaborators and never queues the public copy for deletion',
    () {
      final merged = CuratedListConverter.mergeUnpublished(
        row(name: 'Local', public: true, collaborative: true),
        row(name: 'Relay', public: true, eventId: plaintext),
        mergedAt: origin,
      );
      expect(merged.isPublic, isTrue);
      expect(merged.isCollaborative, isTrue);
      expect(merged.allowedCollaborators, [foreign]);
      expect(merged.pendingPlaintextEventIds, isEmpty);
    },
  );

  test(
    'private/private union does not queue a sealed event or alter inactive collaborator data',
    () {
      final merged = CuratedListConverter.mergeUnpublished(
        row(name: 'Local', public: false),
        row(name: 'Relay', public: false, eventId: plaintext),
        mergedAt: origin,
      );
      expect(merged.isPublic, isFalse);
      expect(merged.isCollaborative, isFalse);
      expect(merged.allowedCollaborators, [foreign]);
      expect(merged.pendingPlaintextEventIds, isEmpty);
    },
  );

  test(
    'a decoded public source without an identity cannot invent a deletion ID',
    () {
      final merged = CuratedListConverter.mergeUnpublished(
        row(name: 'Local', public: false),
        row(name: 'Relay', public: true),
        mergedAt: origin,
      );
      expect(merged.pendingPlaintextEventIds, isEmpty);
    },
  );

  test(
    'index ownership rejects absent, empty, foreign and unattributed owners',
    () {
      final local = row(name: 'Local', public: true);
      final items = [
        local,
        local.copyWith(id: 'foreign', pubkey: foreign),
        CuratedList(
          id: 'legacy',
          name: 'Legacy',
          videoEventIds: const [],
          createdAt: origin,
          updatedAt: origin,
        ),
      ];
      final index = CuratedListCacheIndex(items, ownerPubkey: owner);
      expect(index.isOwned('same'), isTrue);
      expect(index.isOwned(local.authorScopedId), isTrue);
      expect(index.isOwned('foreign'), isFalse);
      expect(index.isOwned('legacy'), isFalse);
      expect(index.isOwned('absent'), isFalse);
      expect(
        CuratedListCacheIndex(items, ownerPubkey: null).isOwned('same'),
        isFalse,
      );
      expect(
        CuratedListCacheIndex(items, ownerPubkey: '').isOwned('same'),
        isFalse,
      );
    },
  );
}
