import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:models/models.dart';
import 'package:test/test.dart';

void main() {
  group('picker evidence inspection', () {
    final owner = 'a' * 64;
    CuratedList row(String name) => CuratedList(
      id: 'list',
      name: name,
      pubkey: owner,
      videoEventIds: const [],
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

    test(
      'a changed list observation does not retire a refused overlay',
      () async {
        final writer = CuratedListCacheWriteCoordinator();
        final baseline = [row('Saved')];
        final attempted = [row('Refused')];
        final result = await writer.saveListsWithResult(
          baseline: baseline,
          current: attempted,
          cacheKey: 'lists',
          read: () => baseline,
          write: (_) async => false,
        );
        expect(result.succeeded, isFalse);
        expect(
          writer.inspectAcknowledgedLists(
            cacheKey: 'lists',
            observed: [row('Other observation')],
          ),
          [row('Other observation')],
        );
        expect(
          writer.inspectAcknowledgedLists(
            cacheKey: 'lists',
            observed: attempted,
          ),
          baseline,
        );
        expect(
          () => writer
              .inspectAcknowledgedLists(
                cacheKey: 'lists',
                observed: baseline,
              )
              .clear(),
          throwsUnsupportedError,
        );
      },
    );

    test(
      'a changed follow observation does not retire a refused overlay',
      () async {
        final writer = CuratedListCacheWriteCoordinator();
        const baseline = {'saved'};
        const attempted = {'saved', 'refused'};
        final result = await writer.saveSubscriptionsWithResult(
          baseline: baseline,
          current: attempted,
          cacheKey: 'follows',
          read: () => baseline,
          write: (_) async => false,
        );
        expect(result.succeeded, isFalse);
        expect(
          writer.inspectAcknowledgedSubscriptions(
            cacheKey: 'follows',
            observed: const {'other'},
          ),
          const {'other'},
        );
        expect(
          writer.inspectAcknowledgedSubscriptions(
            cacheKey: 'follows',
            observed: attempted,
          ),
          baseline,
        );
        expect(
          () => writer
              .inspectAcknowledgedSubscriptions(
                cacheKey: 'follows',
                observed: baseline,
              )
              .clear(),
          throwsUnsupportedError,
        );
      },
    );
  });
}
