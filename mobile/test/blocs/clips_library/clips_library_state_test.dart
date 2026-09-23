// ABOUTME: Tests for ClipsLibraryState and related classes
// ABOUTME: Verifies equality, copyWith, and helper properties

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/clips_library/clips_library_bloc.dart';
import 'package:openvine/models/clip_category.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/stop_motion_clip_frame.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

void main() {
  group(ClipsLibraryState, () {
    final clip1 = DivineVideoClip(
      id: 'clip1',
      video: EditorVideo.file('/path/to/clip1.mp4'),
      thumbnailPath: '/path/to/thumb1.jpg',
      duration: const Duration(seconds: 5),
      recordedAt: DateTime(2026),
      targetAspectRatio: .vertical,
      originalAspectRatio: 9 / 16,
    );

    final clip2 = DivineVideoClip(
      id: 'clip2',
      video: EditorVideo.file('/path/to/clip2.mp4'),
      thumbnailPath: '/path/to/thumb2.jpg',
      duration: const Duration(seconds: 3),
      recordedAt: DateTime(2026),
      targetAspectRatio: .vertical,
      originalAspectRatio: 9 / 16,
    );

    test('supports value equality', () {
      expect(const ClipsLibraryState(), equals(const ClipsLibraryState()));
    });

    test('initial state has correct defaults', () {
      const state = ClipsLibraryState();
      expect(state.status, ClipsLibraryStatus.initial);
      expect(state.clips, isEmpty);
      expect(state.selectedClipIds, isEmpty);
      expect(state.selectedDuration, Duration.zero);
      expect(state.lastGallerySaveResult, isNull);
      expect(state.lastDeletedCount, isNull);
    });

    group('helper getters', () {
      test('isLoading returns true when loading', () {
        const state = ClipsLibraryState(status: ClipsLibraryStatus.loading);
        expect(state.isLoading, isTrue);
        expect(state.isDeleting, isFalse);
        expect(state.isSavingToGallery, isFalse);
      });

      test('isDeleting returns true when deleting', () {
        const state = ClipsLibraryState(status: ClipsLibraryStatus.deleting);
        expect(state.isDeleting, isTrue);
        expect(state.isLoading, isFalse);
        expect(state.isSavingToGallery, isFalse);
      });

      test('isSavingToGallery returns true when saving', () {
        const state = ClipsLibraryState(
          status: ClipsLibraryStatus.savingToGallery,
        );
        expect(state.isSavingToGallery, isTrue);
        expect(state.isLoading, isFalse);
        expect(state.isDeleting, isFalse);
      });
    });

    group('copyWith', () {
      test('returns same state when no parameters', () {
        final state = ClipsLibraryState(
          status: ClipsLibraryStatus.loaded,
          clips: [clip1],
          selectedClipIds: const {'clip1'},
          selectedDuration: const Duration(seconds: 5),
        );

        expect(state.copyWith(), equals(state));
      });

      test('updates status', () {
        const state = ClipsLibraryState();
        final updated = state.copyWith(status: ClipsLibraryStatus.loading);
        expect(updated.status, ClipsLibraryStatus.loading);
      });

      test('updates clips', () {
        const state = ClipsLibraryState();
        final updated = state.copyWith(clips: [clip1]);
        expect(updated.clips, [clip1]);
      });

      test('updates selectedClipIds', () {
        const state = ClipsLibraryState();
        final updated = state.copyWith(selectedClipIds: const {'clip1'});
        expect(updated.selectedClipIds, {'clip1'});
      });

      test('updates selectedDuration', () {
        const state = ClipsLibraryState();
        final updated = state.copyWith(
          selectedDuration: const Duration(seconds: 10),
        );
        expect(updated.selectedDuration, const Duration(seconds: 10));
      });

      test(
        'clears gallery save result when clearGallerySaveResult is true',
        () {
          const state = ClipsLibraryState(
            lastGallerySaveResult: GallerySaveResultSuccess(
              successCount: 1,
              failureCount: 0,
            ),
          );
          final updated = state.copyWith(clearGallerySaveResult: true);
          expect(updated.lastGallerySaveResult, isNull);
        },
      );

      test('clears deleted count when clearDeletedCount is true', () {
        const state = ClipsLibraryState(lastDeletedCount: 5);
        final updated = state.copyWith(clearDeletedCount: true);
        expect(updated.lastDeletedCount, isNull);
      });
    });

    group('selectedClips', () {
      test('returns empty list when nothing selected', () {
        final state = ClipsLibraryState(
          status: ClipsLibraryStatus.loaded,
          clips: [clip1, clip2],
        );
        expect(state.selectedClips, isEmpty);
      });

      test('returns clips in selection order', () {
        // clip2 is selected first, then clip1
        final state = ClipsLibraryState(
          status: ClipsLibraryStatus.loaded,
          clips: [clip1, clip2],
          selectedClipIds: const {'clip2', 'clip1'},
        );
        expect(state.selectedClips, equals([clip2, clip1]));
      });

      test('skips IDs that have no matching clip', () {
        final state = ClipsLibraryState(
          status: ClipsLibraryStatus.loaded,
          clips: [clip1],
          selectedClipIds: const {'clip1', 'missing'},
        );
        expect(state.selectedClips, equals([clip1]));
      });
    });

    group('visibleSelectedClipIds', () {
      final archivedClip = DivineVideoClip(
        id: 'archived',
        video: EditorVideo.file('/path/to/archived.mp4'),
        duration: const Duration(seconds: 4),
        recordedAt: DateTime(2026),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
        archivedAt: DateTime(2026, 3, 6),
      );
      final filedClip = DivineVideoClip(
        id: 'filed',
        video: EditorVideo.file('/path/to/filed.mp4'),
        duration: const Duration(seconds: 4),
        recordedAt: DateTime(2026),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
        categoryId: 'cat-travel',
      );

      test('drops the ids the active filter hides', () {
        final state = ClipsLibraryState(
          status: ClipsLibraryStatus.loaded,
          clips: [clip1, filedClip, archivedClip],
          selectedClipIds: const {'clip1', 'filed', 'archived'},
          filter: const ClipLibraryCategoryFilter('cat-travel'),
        );

        expect(state.visibleSelectedClipIds, {'filed'});
      });

      test('keeps every unarchived selection under All', () {
        final state = ClipsLibraryState(
          status: ClipsLibraryStatus.loaded,
          clips: [clip1, filedClip, archivedClip],
          selectedClipIds: const {'clip1', 'filed', 'archived'},
        );

        expect(state.visibleSelectedClipIds, {'clip1', 'filed'});
      });

      test('is empty in the trash, where the grid shows no active clip', () {
        final state = ClipsLibraryState(
          status: ClipsLibraryStatus.loaded,
          clips: [clip1],
          selectedClipIds: const {'clip1'},
          filter: const ClipLibraryTrashFilter(),
        );

        expect(state.visibleSelectedClipIds, isEmpty);
      });
    });

    group('selectedIsStopMotion', () {
      final smClip = DivineVideoClip(
        id: 'sm1',
        stopMotionFrames: const [
          StopMotionClipFrame(
            path: '/frames/f0.jpg',
            duration: Duration(milliseconds: 83),
          ),
        ],
        thumbnailPath: '/frames/f0.jpg',
        duration: const Duration(seconds: 1),
        recordedAt: DateTime(2026),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );

      test('is null when nothing is selected', () {
        final state = ClipsLibraryState(
          status: ClipsLibraryStatus.loaded,
          clips: [clip1, smClip],
        );
        expect(state.selectedIsStopMotion, isNull);
      });

      test('is false when a normal video clip is selected', () {
        final state = ClipsLibraryState(
          status: ClipsLibraryStatus.loaded,
          clips: [clip1, smClip],
          selectedClipIds: const {'clip1'},
        );
        expect(state.selectedIsStopMotion, isFalse);
      });

      test('is true when a stop-motion clip is selected', () {
        final state = ClipsLibraryState(
          status: ClipsLibraryStatus.loaded,
          clips: [clip1, smClip],
          selectedClipIds: const {'sm1'},
        );
        expect(state.selectedIsStopMotion, isTrue);
      });

      test('is null whichever type is selected when mixing is allowed', () {
        // The grid and the toggle guard both read this to disable the other
        // type; with nothing to match, neither disables anything.
        final state = ClipsLibraryState(
          status: ClipsLibraryStatus.loaded,
          clips: [clip1, smClip],
          selectedClipIds: const {'sm1'},
          allowsMixedClipTypes: true,
        );
        expect(state.selectedIsStopMotion, isNull);
        expect(state.stopMotionTypeOf(const {'sm1'}), isTrue);
      });
    });

    test('props are correct', () {
      final state = ClipsLibraryState(
        status: ClipsLibraryStatus.loaded,
        clips: [clip1],
        selectedClipIds: const {'clip1'},
        selectedDuration: const Duration(seconds: 5),
        lastGallerySaveResult: const GallerySaveResultSuccess(
          successCount: 1,
          failureCount: 0,
        ),
        lastDeletedCount: 1,
      );

      expect(state.props, [
        ClipsLibraryStatus.loaded,
        [clip1],
        const <DivineVideoClip>[],
        const <DivineVideoClip>[],
        {'clip1'},
        const <String>{},
        const <String>{},
        const Duration(seconds: 5),
        ClipSort.newestCreation,
        ClipGridColumns.initial,
        false,
        false,
        const GallerySaveResultSuccess(successCount: 1, failureCount: 0),
        1,
        const <String>{},
        const <ClipCategory>[],
        const ClipLibraryAllFilter(),
        null,
        null,
        false,
      ]);
    });
  });

  group('GallerySaveResult', () {
    group(GallerySaveResultSuccess, () {
      test('supports value equality', () {
        expect(
          const GallerySaveResultSuccess(successCount: 1, failureCount: 0),
          equals(
            const GallerySaveResultSuccess(successCount: 1, failureCount: 0),
          ),
        );
      });

      test('props are correct', () {
        const result = GallerySaveResultSuccess(
          successCount: 2,
          failureCount: 1,
        );
        expect(result.props, [2, 1]);
      });
    });

    group(GallerySaveResultPermissionDenied, () {
      test('supports value equality', () {
        expect(
          const GallerySaveResultPermissionDenied(),
          equals(const GallerySaveResultPermissionDenied()),
        );
      });

      test('props are empty', () {
        expect(const GallerySaveResultPermissionDenied().props, isEmpty);
      });
    });

    group(GallerySaveResultError, () {
      test('supports value equality regardless of cause', () {
        expect(
          const GallerySaveResultError(),
          equals(const GallerySaveResultError()),
        );
      });

      test('props are empty', () {
        expect(const GallerySaveResultError().props, isEmpty);
      });
    });
  });

  group(ClipsLibraryStatus, () {
    test('has all expected values', () {
      expect(
        ClipsLibraryStatus.values,
        containsAll([
          ClipsLibraryStatus.initial,
          ClipsLibraryStatus.loading,
          ClipsLibraryStatus.loaded,
          ClipsLibraryStatus.deleting,
          ClipsLibraryStatus.savingToGallery,
          ClipsLibraryStatus.error,
        ]),
      );
    });
  });

  group(LibraryClipTypeFilter, () {
    final videoClip = DivineVideoClip(
      id: 'v',
      video: EditorVideo.file('/v.mp4'),
      duration: const Duration(seconds: 2),
      recordedAt: DateTime(2026),
      targetAspectRatio: .vertical,
      originalAspectRatio: 9 / 16,
    );
    final stopMotionClip = DivineVideoClip(
      id: 'sm',
      stopMotionFrames: const [
        StopMotionClipFrame(
          path: '/frames/f0.jpg',
          duration: Duration(milliseconds: 83),
        ),
      ],
      duration: const Duration(seconds: 1),
      recordedAt: DateTime(2026),
      targetAspectRatio: .vertical,
      originalAspectRatio: 9 / 16,
    );

    test('fromQuery round-trips the non-default values', () {
      expect(
        LibraryClipTypeFilter.fromQuery(
          LibraryClipTypeFilter.stopMotion.queryValue,
        ),
        LibraryClipTypeFilter.stopMotion,
      );
      expect(
        LibraryClipTypeFilter.fromQuery(LibraryClipTypeFilter.video.queryValue),
        LibraryClipTypeFilter.video,
      );
    });

    test('fromQuery defaults to all for null or unknown', () {
      expect(LibraryClipTypeFilter.fromQuery(null), LibraryClipTypeFilter.all);
      expect(
        LibraryClipTypeFilter.fromQuery('bogus'),
        LibraryClipTypeFilter.all,
      );
    });

    test('all has no query value', () {
      expect(LibraryClipTypeFilter.all.queryValue, isNull);
    });

    test('matches respects clip type', () {
      expect(LibraryClipTypeFilter.all.matches(videoClip), isTrue);
      expect(LibraryClipTypeFilter.all.matches(stopMotionClip), isTrue);
      expect(LibraryClipTypeFilter.stopMotion.matches(stopMotionClip), isTrue);
      expect(LibraryClipTypeFilter.stopMotion.matches(videoClip), isFalse);
      expect(LibraryClipTypeFilter.video.matches(videoClip), isTrue);
      expect(LibraryClipTypeFilter.video.matches(stopMotionClip), isFalse);
    });
  });

  group(ClipLibraryCategoryFilter, () {
    final archivedAndFiled = DivineVideoClip(
      id: 'archived-and-filed',
      video: EditorVideo.file('/path/to/archived.mp4'),
      duration: const Duration(seconds: 4),
      recordedAt: DateTime(2026),
      targetAspectRatio: .vertical,
      originalAspectRatio: 9 / 16,
      categoryId: 'cat-travel',
      archivedAt: DateTime(2026, 3, 6),
    );

    test('shows an archived clip that stayed filed under the category', () {
      expect(
        const ClipLibraryCategoryFilter('cat-travel').admits(archivedAndFiled),
        isTrue,
      );
    });

    test('All still hides that clip, which is what archiving is for', () {
      expect(const ClipLibraryAllFilter().admits(archivedAndFiled), isFalse);
    });
  });
}
