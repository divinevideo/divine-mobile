// ABOUTME: Tests the clip proof pass-through in VideoEditorRenderService
// ABOUTME: Pins that every clip still reaches the combined proof unchanged

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/services/native_proofmode_service.dart';
import 'package:openvine/services/video_editor/video_editor_render_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

DivineVideoClip _createClip(int index, {String? proofManifestJson}) {
  return DivineVideoClip(
    id: 'clip-$index',
    video: EditorVideo.file('${Directory.systemTemp.path}/clip-$index.mp4'),
    duration: const Duration(seconds: 2),
    recordedAt: DateTime(2026, 6, 5, 12, index),
    targetAspectRatio: model.AspectRatio.vertical,
    originalAspectRatio: 9 / 16,
    proofManifestJson: proofManifestJson,
  );
}

void main() {
  group('VideoEditorRenderService.reproofRenderedClip', () {
    late List<List<DivineVideoClip>?> proofCallClips;

    setUp(() {
      proofCallClips = <List<DivineVideoClip>?>[];
      NativeProofModeService.proofFileOverride =
          (
            File videoFile, {
            required bool enableAdvancedCawgEmbedding,
            creatorBindingAssertion,
            cawgIdentityAssertion,
            verifiedIdentityBundle,
            clips,
            editorStateHistory,
          }) async {
            proofCallClips.add(clips);
            return const model.NativeProofData(videoHash: 'combined-hash');
          };
    });

    tearDown(() {
      NativeProofModeService.proofFileOverride = null;
    });

    test(
      'hands every clip to the combined proof without generating any',
      () async {
        // The clip-level backfill is switched off (#8798), so an unattested
        // clip must still travel to the combined call rather than triggering
        // a proof generation of its own.
        final clips = [
          _createClip(0, proofManifestJson: '{"videoHash":"clip-0-hash"}'),
          _createClip(1),
          _createClip(2),
        ];

        final result = await VideoEditorRenderService.reproofRenderedClip(
          clip: _createClip(9),
          clips: clips,
          editorStateHistory: const {'clips': 3},
        );

        expect(
          NativeProofModeService.clipLevelProofGenerationEnabled,
          isFalse,
          reason: 'this test pins the switched-off behaviour',
        );
        expect(
          proofCallClips,
          hasLength(1),
          reason: 'only the combined proof runs; no per-clip backfill',
        );
        expect(proofCallClips.single, hasLength(3));
        expect(
          proofCallClips.single!.map((c) => c.id),
          equals(['clip-0', 'clip-1', 'clip-2']),
        );
        expect(
          proofCallClips.single!.map((c) => c.proofManifestJson),
          equals(['{"videoHash":"clip-0-hash"}', null, null]),
          reason: 'clips are passed through untouched, gaps included',
        );
        expect(
          result,
          equals(
            jsonEncode(
              const model.NativeProofData(
                videoHash: 'combined-hash',
              ),
            ),
          ),
        );
      },
    );

    test(
      'returns null without proofing when the clip has no video file',
      () async {
        final result = await VideoEditorRenderService.reproofRenderedClip(
          clip: DivineVideoClip(
            id: 'no-file',
            video: EditorVideo.network('https://example.com/clip.mp4'),
            duration: const Duration(seconds: 2),
            recordedAt: DateTime(2026, 6, 5, 12),
            targetAspectRatio: model.AspectRatio.vertical,
            originalAspectRatio: 9 / 16,
          ),
          clips: [_createClip(0)],
          editorStateHistory: const {},
        );

        expect(result, isNull);
        expect(proofCallClips, isEmpty);
      },
    );

    test('returns null when the combined proof yields nothing', () async {
      NativeProofModeService.proofFileOverride =
          (
            File videoFile, {
            required bool enableAdvancedCawgEmbedding,
            creatorBindingAssertion,
            cawgIdentityAssertion,
            verifiedIdentityBundle,
            clips,
            editorStateHistory,
          }) async => null;

      final result = await VideoEditorRenderService.reproofRenderedClip(
        clip: _createClip(0),
        clips: [_createClip(0)],
        editorStateHistory: const {},
      );

      expect(result, isNull);
    });
  });
}
