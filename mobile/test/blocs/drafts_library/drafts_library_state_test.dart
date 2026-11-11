// ABOUTME: Tests for DraftsLibraryState classes
// ABOUTME: Verifies equality and props for all state types

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/drafts_library/drafts_library_bloc.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/models/draft_summary.dart';

void main() {
  group('DraftsLibraryState', () {
    DraftSummary createDraft({String? id}) {
      return DraftSummary.fromDraft(
        DivineVideoDraft(
          id: id ?? 'draft-${DateTime.now().millisecondsSinceEpoch}',
          clips: const [],
          title: 'Test Draft',
          description: 'Test Description',
          hashtags: const {},
          selectedApproach: 'default',
          createdAt: DateTime(2026),
          lastModified: DateTime(2026),
          publishStatus: PublishStatus.draft,
          publishAttempts: 0,
        ),
      );
    }

    group(DraftsLibraryInitial, () {
      test('supports value equality', () {
        expect(
          const DraftsLibraryInitial(),
          equals(const DraftsLibraryInitial()),
        );
      });

      test('props are empty', () {
        expect(const DraftsLibraryInitial().props, isEmpty);
      });
    });

    group(DraftsLibraryLoading, () {
      test('supports value equality', () {
        expect(
          const DraftsLibraryLoading(),
          equals(const DraftsLibraryLoading()),
        );
      });

      test('props are empty', () {
        expect(const DraftsLibraryLoading().props, isEmpty);
      });
    });

    group(DraftsLibraryLoaded, () {
      test('supports value equality', () {
        final draft = createDraft(id: 'draft1');
        expect(
          DraftsLibraryLoaded(drafts: [draft]),
          equals(DraftsLibraryLoaded(drafts: [draft])),
        );
      });

      test('empty lists are equal', () {
        expect(
          const DraftsLibraryLoaded(drafts: []),
          equals(const DraftsLibraryLoaded(drafts: [])),
        );
      });

      test('different drafts are not equal', () {
        expect(
          DraftsLibraryLoaded(drafts: [createDraft(id: 'draft1')]),
          isNot(
            equals(DraftsLibraryLoaded(drafts: [createDraft(id: 'draft2')])),
          ),
        );
      });

      test('props contains drafts', () {
        final drafts = [createDraft(id: 'draft1')];
        expect(DraftsLibraryLoaded(drafts: drafts).props, [drafts]);
      });
    });

    group(DraftsLibraryDraftDuplicated, () {
      test('supports value equality', () {
        final draft = createDraft(id: 'draft1');
        expect(
          DraftsLibraryDraftDuplicated(drafts: [draft]),
          equals(DraftsLibraryDraftDuplicated(drafts: [draft])),
        );
      });

      test('props contains drafts', () {
        final drafts = [createDraft(id: 'draft1')];
        expect(DraftsLibraryDraftDuplicated(drafts: drafts).props, [drafts]);
      });
    });

    group(DraftsLibraryDuplicateFailed, () {
      test('supports value equality', () {
        final draft = createDraft(id: 'draft1');
        expect(
          DraftsLibraryDuplicateFailed(drafts: [draft]),
          equals(DraftsLibraryDuplicateFailed(drafts: [draft])),
        );
      });

      test('props contains drafts', () {
        final drafts = [createDraft(id: 'draft1')];
        expect(DraftsLibraryDuplicateFailed(drafts: drafts).props, [drafts]);
      });
    });

    group(DraftsLibraryDraftDeleted, () {
      test('supports value equality', () {
        final draft = createDraft(id: 'draft1');
        expect(
          DraftsLibraryDraftDeleted(drafts: [draft]),
          equals(DraftsLibraryDraftDeleted(drafts: [draft])),
        );
      });

      test('props contains drafts', () {
        final drafts = [createDraft(id: 'draft1')];
        expect(DraftsLibraryDraftDeleted(drafts: drafts).props, [drafts]);
      });
    });

    group(DraftsLibraryDeleteFailed, () {
      test('supports value equality', () {
        final draft = createDraft(id: 'draft1');
        expect(
          DraftsLibraryDeleteFailed(drafts: [draft]),
          equals(DraftsLibraryDeleteFailed(drafts: [draft])),
        );
      });

      test('props contains drafts', () {
        final drafts = [createDraft(id: 'draft1')];
        expect(DraftsLibraryDeleteFailed(drafts: drafts).props, [drafts]);
      });
    });

    group(DraftsLibraryError, () {
      test('supports value equality', () {
        expect(const DraftsLibraryError(), equals(const DraftsLibraryError()));
      });

      test('props matches base state', () {
        expect(const DraftsLibraryError().props, isEmpty);
      });
    });
  });
}
