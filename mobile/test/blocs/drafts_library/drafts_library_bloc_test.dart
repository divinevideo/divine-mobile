// ABOUTME: Tests for DraftsLibraryBloc - managing draft video projects
// ABOUTME: Tests loading and deletion of drafts

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' show AspectRatio;
import 'package:openvine/blocs/drafts_library/drafts_library_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

class _MockDraftStorageService extends Mock implements DraftStorageService {}

void main() {
  group(DraftsLibraryBloc, () {
    late _MockDraftStorageService mockDraftStorageService;

    DivineVideoDraft createDraft({
      String? id,
      PublishStatus publishStatus = PublishStatus.draft,
      DateTime? lastModified,
      List<DivineVideoClip> clips = const [],
    }) {
      return DivineVideoDraft(
        id: id ?? 'draft-${DateTime.now().millisecondsSinceEpoch}',
        clips: clips,
        title: 'Test Draft',
        description: 'Test Description',
        hashtags: const {},
        selectedApproach: 'default',
        createdAt: DateTime(2026),
        lastModified: lastModified ?? DateTime(2026),
        publishStatus: publishStatus,
        publishAttempts: 0,
      );
    }

    setUp(() {
      mockDraftStorageService = _MockDraftStorageService();
    });

    DraftsLibraryBloc createBloc() =>
        DraftsLibraryBloc(draftStorageService: mockDraftStorageService);

    test('initial state is $DraftsLibraryInitial', () {
      final bloc = createBloc();
      expect(bloc.state, const DraftsLibraryInitial());
      bloc.close();
    });

    group('DraftsLibraryLoadRequested', () {
      blocTest<DraftsLibraryBloc, DraftsLibraryState>(
        'emits [loading, loaded] with drafts from service',
        setUp: () {
          when(() => mockDraftStorageService.getAllDrafts()).thenAnswer(
            (_) async => [createDraft(id: 'draft1'), createDraft(id: 'draft2')],
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(const DraftsLibraryLoadRequested()),
        expect: () => [
          const DraftsLibraryLoading(),
          isA<DraftsLibraryLoaded>().having(
            (s) => s.drafts.length,
            'drafts.length',
            2,
          ),
        ],
      );

      blocTest<DraftsLibraryBloc, DraftsLibraryState>(
        'filters out autosave drafts',
        setUp: () {
          when(() => mockDraftStorageService.getAllDrafts()).thenAnswer(
            (_) async => [
              createDraft(id: 'draft1'),
              createDraft(id: VideoEditorConstants.autoSaveId),
            ],
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(const DraftsLibraryLoadRequested()),
        expect: () => [
          const DraftsLibraryLoading(),
          isA<DraftsLibraryLoaded>()
              .having((s) => s.drafts.length, 'drafts.length', 1)
              .having((s) => s.drafts.first.id, 'first draft id', 'draft1'),
        ],
      );

      blocTest<DraftsLibraryBloc, DraftsLibraryState>(
        'includes autosave draft when it has clips',
        setUp: () {
          when(() => mockDraftStorageService.getAllDrafts()).thenAnswer(
            (_) async => [
              createDraft(id: 'draft1'),
              createDraft(
                id: VideoEditorConstants.autoSaveId,
                clips: [
                  DivineVideoClip(
                    id: 'clip1',
                    video: EditorVideo.file('/path/to/video.mp4'),
                    duration: const Duration(seconds: 5),
                    recordedAt: DateTime(2026),
                    targetAspectRatio: AspectRatio.vertical,
                    originalAspectRatio: 9 / 16,
                  ),
                ],
              ),
            ],
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(const DraftsLibraryLoadRequested()),
        expect: () => [
          const DraftsLibraryLoading(),
          isA<DraftsLibraryLoaded>().having(
            (s) => s.drafts.length,
            'drafts.length',
            2,
          ),
        ],
      );

      blocTest<DraftsLibraryBloc, DraftsLibraryState>(
        'drops the autosave draft with clips when includeAutosaveDraft is off',
        setUp: () {
          when(() => mockDraftStorageService.getAllDrafts()).thenAnswer(
            (_) async => [
              createDraft(id: 'draft1'),
              createDraft(
                id: VideoEditorConstants.autoSaveId,
                clips: [
                  DivineVideoClip(
                    id: 'clip1',
                    video: EditorVideo.file('/path/to/video.mp4'),
                    duration: const Duration(seconds: 5),
                    recordedAt: DateTime(2026),
                    targetAspectRatio: AspectRatio.vertical,
                    originalAspectRatio: 9 / 16,
                  ),
                ],
              ),
            ],
          );
        },
        build: () => DraftsLibraryBloc(
          draftStorageService: mockDraftStorageService,
          includeAutosaveDraft: false,
        ),
        act: (bloc) => bloc.add(const DraftsLibraryLoadRequested()),
        expect: () => [
          const DraftsLibraryLoading(),
          isA<DraftsLibraryLoaded>().having(
            (s) => s.drafts.map((d) => d.id),
            'draft ids',
            ['draft1'],
          ),
        ],
      );

      blocTest<DraftsLibraryBloc, DraftsLibraryState>(
        'filters out published drafts',
        setUp: () {
          when(() => mockDraftStorageService.getAllDrafts()).thenAnswer(
            (_) async => [
              createDraft(id: 'draft1'),
              createDraft(id: 'draft2', publishStatus: PublishStatus.published),
            ],
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(const DraftsLibraryLoadRequested()),
        expect: () => [
          const DraftsLibraryLoading(),
          isA<DraftsLibraryLoaded>()
              .having((s) => s.drafts.length, 'drafts.length', 1)
              .having((s) => s.drafts.first.id, 'first draft id', 'draft1'),
        ],
      );

      blocTest<DraftsLibraryBloc, DraftsLibraryState>(
        'filters out publishing drafts',
        setUp: () {
          when(() => mockDraftStorageService.getAllDrafts()).thenAnswer(
            (_) async => [
              createDraft(id: 'draft1'),
              createDraft(
                id: 'draft2',
                publishStatus: PublishStatus.publishing,
              ),
            ],
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(const DraftsLibraryLoadRequested()),
        expect: () => [
          const DraftsLibraryLoading(),
          isA<DraftsLibraryLoaded>()
              .having((s) => s.drafts.length, 'drafts.length', 1)
              .having((s) => s.drafts.first.id, 'first draft id', 'draft1'),
        ],
      );

      blocTest<DraftsLibraryBloc, DraftsLibraryState>(
        'filters out scheduled drafts, which the Scheduled tab lists',
        setUp: () {
          when(() => mockDraftStorageService.getAllDrafts()).thenAnswer(
            (_) async => [
              createDraft(id: 'draft1'),
              createDraft(
                id: 'draft2',
                publishStatus: PublishStatus.scheduled,
              ),
            ],
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(const DraftsLibraryLoadRequested()),
        expect: () => [
          const DraftsLibraryLoading(),
          isA<DraftsLibraryLoaded>()
              .having((s) => s.drafts.length, 'drafts.length', 1)
              .having((s) => s.drafts.first.id, 'first draft id', 'draft1'),
        ],
      );

      blocTest<DraftsLibraryBloc, DraftsLibraryState>(
        'sorts drafts by lastModified descending',
        setUp: () {
          when(() => mockDraftStorageService.getAllDrafts()).thenAnswer(
            (_) async => [
              createDraft(id: 'older', lastModified: DateTime(2026)),
              createDraft(id: 'newer', lastModified: DateTime(2026, 2)),
            ],
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(const DraftsLibraryLoadRequested()),
        expect: () => [
          const DraftsLibraryLoading(),
          isA<DraftsLibraryLoaded>()
              .having((s) => s.drafts.length, 'drafts.length', 2)
              .having((s) => s.drafts.first.id, 'first (newest)', 'newer')
              .having((s) => s.drafts.last.id, 'last (oldest)', 'older'),
        ],
      );

      blocTest<DraftsLibraryBloc, DraftsLibraryState>(
        'emits [loading, loaded] with empty list when no drafts',
        setUp: () {
          when(
            () => mockDraftStorageService.getAllDrafts(),
          ).thenAnswer((_) async => []);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const DraftsLibraryLoadRequested()),
        expect: () => [
          const DraftsLibraryLoading(),
          const DraftsLibraryLoaded(drafts: []),
        ],
      );

      blocTest<DraftsLibraryBloc, DraftsLibraryState>(
        'emits [loading, error] when service throws',
        setUp: () {
          when(
            () => mockDraftStorageService.getAllDrafts(),
          ).thenThrow(Exception('Load failed'));
        },
        build: createBloc,
        act: (bloc) => bloc.add(const DraftsLibraryLoadRequested()),
        errors: () => [isA<Exception>()],
        expect: () => [
          const DraftsLibraryLoading(),
          const DraftsLibraryError(),
        ],
      );
    });

    group('DraftsLibraryDuplicateRequested', () {
      setUpAll(() {
        registerFallbackValue(createDraft());
      });

      blocTest<DraftsLibraryBloc, DraftsLibraryState>(
        'does nothing when not in loaded state',
        build: createBloc,
        act: (bloc) =>
            bloc.add(const DraftsLibraryDuplicateRequested('draft1')),
        expect: () => [],
      );

      blocTest<DraftsLibraryBloc, DraftsLibraryState>(
        'does nothing when the draft id is not in the list',
        seed: () => DraftsLibraryLoaded(drafts: [createDraft(id: 'draft1')]),
        build: createBloc,
        act: (bloc) =>
            bloc.add(const DraftsLibraryDuplicateRequested('missing')),
        expect: () => [],
      );

      blocTest<DraftsLibraryBloc, DraftsLibraryState>(
        'duplicates the draft, saves it, and updates the list',
        setUp: () {
          when(
            () => mockDraftStorageService.saveDraft(any()),
          ).thenAnswer((_) async {});
        },
        seed: () => DraftsLibraryLoaded(drafts: [createDraft(id: 'draft1')]),
        build: createBloc,
        act: (bloc) => bloc.add(
          const DraftsLibraryDuplicateRequested('draft1', newTitle: 'Copy'),
        ),
        expect: () => [
          isA<DraftsLibraryDraftDuplicated>().having(
            (s) => s.drafts.length,
            'drafts.length',
            2,
          ),
          isA<DraftsLibraryLoaded>().having(
            (s) => s.drafts.length,
            'drafts.length',
            2,
          ),
        ],
        verify: (_) {
          final saved =
              verify(
                    () => mockDraftStorageService.saveDraft(captureAny()),
                  ).captured.single
                  as DivineVideoDraft;
          expect(saved.id, isNot('draft1'));
          expect(saved.title, 'Copy');
          expect(saved.publishStatus, PublishStatus.draft);
        },
      );

      blocTest<DraftsLibraryBloc, DraftsLibraryState>(
        'emits failure result when save fails',
        setUp: () {
          when(
            () => mockDraftStorageService.saveDraft(any()),
          ).thenThrow(Exception('Save failed'));
        },
        seed: () => DraftsLibraryLoaded(drafts: [createDraft(id: 'draft1')]),
        build: createBloc,
        act: (bloc) =>
            bloc.add(const DraftsLibraryDuplicateRequested('draft1')),
        errors: () => [isA<Exception>()],
        expect: () => [
          isA<DraftsLibraryDuplicateFailed>().having(
            (s) => s.drafts.length,
            'drafts.length',
            1,
          ),
          isA<DraftsLibraryLoaded>().having(
            (s) => s.drafts.length,
            'drafts.length',
            1,
          ),
        ],
      );
    });

    group('DraftsLibraryDeleteRequested', () {
      blocTest<DraftsLibraryBloc, DraftsLibraryState>(
        'does nothing when not in loaded state',
        build: createBloc,
        // Initial state is DraftsLibraryInitial
        act: (bloc) => bloc.add(const DraftsLibraryDeleteRequested('draft1')),
        expect: () => [],
      );

      blocTest<DraftsLibraryBloc, DraftsLibraryState>(
        'deletes draft and updates list with success result',
        setUp: () {
          when(
            () => mockDraftStorageService.deleteDraft('draft1'),
          ).thenAnswer((_) async {});
        },
        seed: () => DraftsLibraryLoaded(
          drafts: [
            createDraft(id: 'draft1'),
            createDraft(id: 'draft2'),
          ],
        ),
        build: createBloc,
        act: (bloc) => bloc.add(const DraftsLibraryDeleteRequested('draft1')),
        expect: () => [
          isA<DraftsLibraryDraftDeleted>()
              .having((s) => s.drafts.length, 'drafts.length', 1)
              .having((s) => s.drafts.first.id, 'remaining draft', 'draft2'),
          isA<DraftsLibraryLoaded>()
              .having((s) => s.drafts.length, 'drafts.length', 1)
              .having((s) => s.drafts.first.id, 'remaining draft', 'draft2'),
        ],
        verify: (_) {
          verify(() => mockDraftStorageService.deleteDraft('draft1')).called(1);
        },
      );

      blocTest<DraftsLibraryBloc, DraftsLibraryState>(
        'emits failure result when deletion fails',
        setUp: () {
          when(
            () => mockDraftStorageService.deleteDraft(any()),
          ).thenThrow(Exception('Delete failed'));
        },
        seed: () => DraftsLibraryLoaded(drafts: [createDraft(id: 'draft1')]),
        build: createBloc,
        act: (bloc) => bloc.add(const DraftsLibraryDeleteRequested('draft1')),
        errors: () => [isA<Exception>()],
        expect: () => [
          isA<DraftsLibraryDeleteFailed>().having(
            (s) => s.drafts.length,
            'drafts.length',
            1,
          ),
          isA<DraftsLibraryLoaded>().having(
            (s) => s.drafts.length,
            'drafts.length',
            1,
          ),
        ],
      );
    });
  });
}
