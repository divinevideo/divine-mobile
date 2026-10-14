// ABOUTME: Tests for ClipsLibraryEvent classes
// ABOUTME: Verifies equality and props for all event types

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/clips_library/clips_library_bloc.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

void main() {
  group('ClipsLibraryEvent', () {
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

    group(ClipsLibraryLoadRequested, () {
      test('supports value equality', () {
        expect(
          const ClipsLibraryLoadRequested(),
          equals(const ClipsLibraryLoadRequested()),
        );
      });

      test('supports value equality with preSelectedIds', () {
        expect(
          const ClipsLibraryLoadRequested(preSelectedIds: {'a', 'b'}),
          equals(const ClipsLibraryLoadRequested(preSelectedIds: {'a', 'b'})),
        );
      });

      test('different preSelectedIds are not equal', () {
        expect(
          const ClipsLibraryLoadRequested(preSelectedIds: {'a'}),
          isNot(equals(const ClipsLibraryLoadRequested(preSelectedIds: {'b'}))),
        );
      });

      test('props contains preSelectedIds', () {
        const event = ClipsLibraryLoadRequested(preSelectedIds: {'x'});
        expect(event.props, [
          const {'x'},
          const <String>{},
        ]);
      });

      test('default preSelectedIds is empty', () {
        expect(const ClipsLibraryLoadRequested().preSelectedIds, isEmpty);
      });
    });

    group(ClipsLibraryToggleSelection, () {
      test('supports value equality', () {
        expect(
          ClipsLibraryToggleSelection(clip1),
          equals(ClipsLibraryToggleSelection(clip1)),
        );
      });

      test('different clips are not equal', () {
        expect(
          ClipsLibraryToggleSelection(clip1),
          isNot(equals(ClipsLibraryToggleSelection(clip2))),
        );
      });

      test('props contains clip', () {
        expect(ClipsLibraryToggleSelection(clip1).props, [clip1]);
      });
    });

    group(ClipsLibraryClearSelection, () {
      test('supports value equality', () {
        expect(
          const ClipsLibraryClearSelection(),
          equals(const ClipsLibraryClearSelection()),
        );
      });

      test('props are empty', () {
        expect(const ClipsLibraryClearSelection().props, isEmpty);
      });
    });

    group(ClipsLibraryDeleteSelected, () {
      test('supports value equality', () {
        expect(
          const ClipsLibraryDeleteSelected(),
          equals(const ClipsLibraryDeleteSelected()),
        );
      });

      test('props are empty', () {
        expect(const ClipsLibraryDeleteSelected().props, isEmpty);
      });
    });

    group(ClipsLibraryDeleteClip, () {
      test('supports value equality', () {
        expect(
          ClipsLibraryDeleteClip(clip1),
          equals(ClipsLibraryDeleteClip(clip1)),
        );
      });

      test('different clips are not equal', () {
        expect(
          ClipsLibraryDeleteClip(clip1),
          isNot(equals(ClipsLibraryDeleteClip(clip2))),
        );
      });

      test('props contains clip', () {
        expect(ClipsLibraryDeleteClip(clip1).props, [clip1]);
      });
    });
  });
}
