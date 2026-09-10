// ABOUTME: Tests documents-relative persistence of draft-local audio paths
// ABOUTME: Covers portable rewrite, resolution, and healing of stale paths

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/utils/draft_audio_path_resolver.dart';

const _oldDocs = '/var/mobile/Containers/Data/Application/OLD-UUID/Documents';
const _newDocs = '/var/mobile/Containers/Data/Application/NEW-UUID/Documents';

Map<String, dynamic> _audioJson(String url, {String id = 'local_import_1'}) => {
  'id': id,
  'pubkey': 'local_import',
  'createdAt': 1700000000,
  'url': url,
};

String _singleAudioUrl(Map<String, dynamic> json) =>
    (((json['meta']! as Map)['audio']! as List).single as Map)['url'] as String;

void main() {
  group('toPortableAudioPath', () {
    test('strips the container prefix from an imported audio path', () {
      expect(
        toPortableAudioPath('$_oldDocs/draft_audio_imports/draft_1/song.m4a'),
        'draft_audio_imports/draft_1/song.m4a',
      );
    });

    test('strips the container prefix from a voice-over recording', () {
      expect(
        toPortableAudioPath('$_oldDocs/voice_over_recordings/take_3.m4a'),
        'voice_over_recordings/take_3.m4a',
      );
    });

    test('leaves an already portable path untouched', () {
      expect(
        toPortableAudioPath('draft_audio_imports/draft_1/song.m4a'),
        'draft_audio_imports/draft_1/song.m4a',
      );
    });

    test('strips the container prefix from extracted clip audio', () {
      expect(
        toPortableAudioPath('$_oldDocs/extracted_clip_audio/take.wav'),
        'extracted_clip_audio/take.wav',
      );
    });

    test('leaves a path outside a known audio directory untouched', () {
      expect(toPortableAudioPath('$_oldDocs/clip.mp4'), '$_oldDocs/clip.mp4');
      expect(toPortableAudioPath(''), '');
    });

    test('ignores a bare audio directory with no file below it', () {
      expect(
        toPortableAudioPath('$_oldDocs/draft_audio_imports'),
        '$_oldDocs/draft_audio_imports',
      );
    });
  });

  group('resolveAudioPath', () {
    test('roots a portable path at the current documents directory', () {
      expect(
        resolveAudioPath('library_audio_imports/song.m4a', _newDocs),
        '$_newDocs/library_audio_imports/song.m4a',
      );
    });

    test('rebases a retired draft-import path onto library storage', () {
      // `migrateDraftOwnedAudioImports` moved the file; a path persisted
      // before that still names the old root, and the tail below it — the
      // basename audio reclaim matches on — is preserved (#8024).
      expect(
        resolveAudioPath('draft_audio_imports/draft_1/song.m4a', _newDocs),
        '$_newDocs/library_audio_imports/draft_1/song.m4a',
      );
    });

    test('rebases an absolute pre-move path onto library storage', () {
      expect(
        resolveAudioPath(
          '$_oldDocs/draft_audio_imports/d1/song.m4a',
          _newDocs,
        ),
        '$_newDocs/library_audio_imports/d1/song.m4a',
      );
    });

    test('leaves the other audio roots where they are', () {
      expect(
        resolveAudioPath('extracted_clip_audio/clip.m4a', _newDocs),
        '$_newDocs/extracted_clip_audio/clip.m4a',
      );
    });

    test('heals an absolute path from a previous container', () {
      expect(
        resolveAudioPath(
          '$_oldDocs/voice_over_recordings/take_3.m4a',
          _newDocs,
        ),
        '$_newDocs/voice_over_recordings/take_3.m4a',
      );
    });

    test('leaves a path outside a known audio directory untouched', () {
      expect(
        resolveAudioPath('https://blossom.example/audio.aac', _newDocs),
        'https://blossom.example/audio.aac',
      );
    });
  });

  group('audio path rewriting in persisted maps', () {
    test('rewrites audio nested in editor state history', () {
      final history = <String, dynamic>{
        'version': '1.0.0',
        'history': [
          {
            'meta': {
              'audio': [
                _audioJson('$_oldDocs/draft_audio_imports/d1/song.m4a'),
                _audioJson(
                  '$_oldDocs/voice_over_recordings/take.m4a',
                  id: 'local_import_2',
                ),
              ],
            },
          },
        ],
      };

      final portable = toPortableAudioPaths(history);
      final audio =
          ((portable['history'] as List).first as Map)['meta']
              as Map<String, dynamic>;
      expect(
        (audio['audio'] as List).map((e) => (e as Map)['url']),
        ['draft_audio_imports/d1/song.m4a', 'voice_over_recordings/take.m4a'],
      );

      final resolved = resolveAudioPaths(portable, _newDocs);
      final resolvedAudio =
          ((resolved['history'] as List).first as Map)['meta']
              as Map<String, dynamic>;
      expect(
        (resolvedAudio['audio'] as List).map((e) => (e as Map)['url']),
        [
          '$_newDocs/library_audio_imports/d1/song.m4a',
          '$_newDocs/voice_over_recordings/take.m4a',
        ],
      );
    });

    test('rewrites audio nested in editor editing parameters', () {
      final parameters = <String, dynamic>{
        'meta': {
          'audio': [_audioJson('$_oldDocs/draft_audio_imports/d1/song.m4a')],
        },
      };

      final resolved = resolveAudioPaths(
        toPortableAudioPaths(parameters),
        _newDocs,
      );
      final audio = ((resolved['meta'] as Map)['audio'] as List).first as Map;
      expect(audio['url'], '$_newDocs/library_audio_imports/d1/song.m4a');
    });

    test('rewrites a bare audio event map', () {
      final portable = toPortableAudioPaths(
        _audioJson('$_oldDocs/draft_audio_imports/d1/song.m4a'),
      );
      expect(portable['url'], 'draft_audio_imports/d1/song.m4a');
    });

    test('leaves published and bundled sounds untouched', () {
      final json = <String, dynamic>{
        'meta': {
          'audio': [
            _audioJson('https://blossom.example/a.aac', id: 'nostr-event-id'),
            _audioJson('asset://sounds/beat.mp3', id: 'bundled_beat'),
          ],
        },
      };
      expect(identical(toPortableAudioPaths(json), json), isTrue);
      expect(identical(resolveAudioPaths(json, _newDocs), json), isTrue);
    });

    test('leaves a remote sound whose url contains an audio root', () {
      // The id gate is the only thing protecting this: the url carries a
      // voice_over_recordings segment, so without the local-import check it
      // would be truncated on save and rebased under the documents directory
      // on load, turning a remote url into a dangling local path.
      const remoteUrl = 'https://cdn.example/voice_over_recordings/take.m4a';
      final json = <String, dynamic>{
        'meta': {
          'audio': [_audioJson(remoteUrl, id: 'nostr-event-id')],
        },
      };

      expect(_singleAudioUrl(toPortableAudioPaths(json)), remoteUrl);
      expect(_singleAudioUrl(resolveAudioPaths(json, _newDocs)), remoteUrl);
    });

    test("rewrites audio extracted from one of the draft's own clips", () {
      // Extracted audio carries its own id marker rather than the import one,
      // so it is only reached if the gate covers both. Its file used to live
      // in the temporary directory, where an app update or an iOS purge takes
      // it regardless of how the path is stored.
      final json = <String, dynamic>{
        'meta': {
          'audio': [
            _audioJson(
              '$_oldDocs/extracted_clip_audio/extracted_audio_1.wav',
              id: 'local_extracted_1',
            ),
          ],
        },
      };

      final portable = toPortableAudioPaths(json);
      expect(
        _singleAudioUrl(portable),
        'extracted_clip_audio/extracted_audio_1.wav',
      );
      expect(
        _singleAudioUrl(resolveAudioPaths(portable, _newDocs)),
        '$_newDocs/extracted_clip_audio/extracted_audio_1.wav',
      );
    });

    test('returns the same instance when nothing needs rewriting', () {
      final json = <String, dynamic>{
        'meta': {
          'audio': [_audioJson('draft_audio_imports/d1/song.m4a')],
        },
      };
      expect(identical(toPortableAudioPaths(json), json), isTrue);
    });

    test('honors useOriginalPath', () {
      final json = _audioJson('draft_audio_imports/d1/song.m4a');
      expect(
        resolveAudioPaths(json, _newDocs, useOriginalPath: true)['url'],
        'draft_audio_imports/d1/song.m4a',
      );
    });

    test('skips malformed audio entries without throwing', () {
      final json = <String, dynamic>{
        'meta': {
          'audio': [
            {'id': 'local_import_1'},
            {'id': 'local_import_2', 'url': 42},
            'not-a-map',
          ],
        },
      };
      expect(() => toPortableAudioPaths(json), returnsNormally);
      expect(identical(toPortableAudioPaths(json), json), isTrue);
    });
  });

  group('isDraftLocalAudioPath', () {
    test('accepts a file under each audio root', () {
      expect(
        isDraftLocalAudioPath('$_newDocs/draft_audio_imports/d1/song.m4a'),
        isTrue,
      );
      expect(
        isDraftLocalAudioPath('$_newDocs/voice_over_recordings/take_1.m4a'),
        isTrue,
      );
      expect(
        isDraftLocalAudioPath('$_newDocs/extracted_clip_audio/clip_1.m4a'),
        isTrue,
      );
      expect(isDraftLocalAudioPath('draft_audio_imports/d1/song.m4a'), isTrue);
    });

    test('rejects a path outside the audio roots', () {
      expect(isDraftLocalAudioPath('$_newDocs/picker_cache/song.m4a'), isFalse);
      expect(isDraftLocalAudioPath('$_newDocs/song.m4a'), isFalse);
      expect(isDraftLocalAudioPath(''), isFalse);
    });

    test('rejects the audio root directory itself', () {
      expect(isDraftLocalAudioPath('$_newDocs/draft_audio_imports'), isFalse);
    });

    test('rejects a path that escapes the root with ..', () {
      expect(
        isDraftLocalAudioPath('$_newDocs/draft_audio_imports/../../etc/x'),
        isFalse,
      );
      expect(
        isDraftLocalAudioPath('$_newDocs/voice_over_recordings/../secret.key'),
        isFalse,
      );
    });
  });
}
