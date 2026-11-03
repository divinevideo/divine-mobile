// ABOUTME: Pins what the draft load and save log lines say a draft's shown
// ABOUTME: step holds: layer kinds, clip features and sounds

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' show AspectRatio, AudioEvent;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/utils/editor_state_contents.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show EditorVideo;

DivineVideoClip _clip(
  String id, {
  double? playbackSpeed,
  bool reversed = false,
  bool isFreezeFrame = false,
}) => DivineVideoClip(
  id: id,
  video: EditorVideo.file('/path/to/$id.mp4'),
  duration: const Duration(seconds: 6),
  recordedAt: DateTime(2026, 11, 3),
  targetAspectRatio: AspectRatio.vertical,
  originalAspectRatio: 9 / 16,
  playbackSpeed: playbackSpeed,
  reversed: reversed,
  isFreezeFrame: isFreezeFrame,
);

Map<String, dynamic> _sound(
  String id, {
  required double seconds,
  bool noiseReduction = false,
  bool ducks = false,
}) => AudioEvent.fromLocalImport(
  id: id,
  filePath: '/path/to/$id.m4a',
  createdAt: 1793700000,
  title: id,
  mimeType: 'audio/mp4',
  duration: seconds,
).copyWith(noiseReduction: noiseReduction, ducksUnderVoiceOver: ducks).toJson();

void main() {
  group(EditorStateContents, () {
    group('of', () {
      test('counts the kinds of the shown layers only', () {
        final contents = EditorStateContents.of(
          history: {
            'position': 1,
            'references': {
              'clip_layer': {
                'id': 'clip_layer',
                'type': 'widget',
                'exportConfigs': {
                  'meta': {'kind': 'divine.detachedClip'},
                },
              },
            },
            'history': [
              {
                'layers': [
                  {'id': 'gone', 'type': 'text'},
                ],
              },
              {
                'layers': [
                  {'id': 'clip_layer', 'x': 4},
                  {
                    'id': 'sticker',
                    'type': 'widget',
                    'meta': {'networkUrl': 'https://example.com/s.png'},
                  },
                  {
                    'id': 'cue',
                    'type': 'text',
                    'meta': {'divineCaptionCue': true},
                  },
                  {'id': 'drawing', 'type': 'paint'},
                ],
              },
            ],
          },
          clips: const [],
        );

        expect(
          contents.layerKinds,
          equals({'detachedClip': 1, 'sticker': 1, 'caption': 1, 'paint': 1}),
        );
      });

      test('counts masked layers and their keyframes', () {
        final contents = EditorStateContents.of(
          history: {
            'position': 0,
            'history': [
              {
                'layers': [
                  {
                    'id': 'tracked',
                    'type': 'text',
                    'mask': {'shape': 'circle'},
                    'keyframes': [
                      for (var i = 0; i < 90; i++) {'timeMs': i * 33},
                    ],
                  },
                  {
                    'id': 'plain',
                    'type': 'text',
                    'keyframes': [
                      {'timeMs': 0},
                    ],
                  },
                ],
              },
            ],
          },
          clips: const [],
        );

        expect(contents.maskedLayers, equals(1));
        expect(contents.layerKeyframes, equals(91));
      });

      test('counts the timeline features of the clips', () {
        final contents = EditorStateContents.of(
          history: const {},
          clips: [
            _clip('a', playbackSpeed: 1.5),
            _clip('b', playbackSpeed: 1, reversed: true),
            _clip('c', isFreezeFrame: true),
          ],
        );

        expect(
          contents.clipFeatures,
          equals({'speed': 1, 'reversed': 1, 'freeze': 1}),
        );
      });

      test('counts the sounds of the shown step and their features', () {
        final contents = EditorStateContents.of(
          history: {
            'position': 0,
            'history': [
              {
                'meta': {
                  'audio': [
                    _sound('music', seconds: 60.4, ducks: true),
                    _sound(
                      '${AudioEvent.voiceOverIdPrefix}_1',
                      seconds: 30,
                      noiseReduction: true,
                    ),
                    _sound('${AudioEvent.voiceOverIdPrefix}_2', seconds: 30),
                  ],
                },
              },
            ],
          },
          clips: const [],
        );

        expect(contents.audioTracks, equals(3));
        expect(contents.voiceOvers, equals(2));
        expect(contents.audioSourceSeconds, equals(120));
        expect(
          contents.audioFeatures,
          equals({'ducking': 1, 'denoised': 1}),
        );
      });

      test('leaves out a sound it cannot read', () {
        final contents = EditorStateContents.of(
          history: {
            'position': 0,
            'history': [
              {
                'meta': {
                  'audio': [
                    _sound('music', seconds: 10),
                    {'id': 'broken'},
                  ],
                },
              },
            ],
          },
          clips: const [],
        );

        expect(contents.audioTracks, equals(1));
      });
    });

    group('toString', () {
      test('reads as one log fragment, most frequent kind first', () {
        const contents = EditorStateContents(
          layerKinds: {'text': 1, 'sticker': 3},
          maskedLayers: 1,
          layerKeyframes: 240,
          clipFeatures: {'speed': 1},
          audioTracks: 21,
          voiceOvers: 20,
          audioSourceSeconds: 612,
          audioFeatures: {'denoised': 10, 'ducking': 1},
          captions: 3,
          effects: 2,
        );

        expect(
          contents.toString(),
          equals(
            'layer kinds sticker 3, text 1; masked layers 1; '
            'layer keyframes 240; clip speed 1; '
            'audio 21 (voice-over 20, 612 s source, denoised 10, ducking 1); '
            'captions 3; effects 2',
          ),
        );
      });

      test('says nothing for an empty draft', () {
        expect(const EditorStateContents().toString(), isEmpty);
      });
    });
  });
}
