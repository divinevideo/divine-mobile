// ABOUTME: Tests which files of the CC0 sound collection become import candidates
// ABOUTME: and with which credit, kind and title.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../../tools/sound_import/cc0_packs.dart';
import '../../../tools/sound_import/sound_candidate.dart';

const _commit = 'f2b6264f9ab89fabc266914c3654685d68c5a39b';

RepositoryFile _file(String path, {String? blobSha}) =>
    RepositoryFile(path: path, blobSha: blobSha ?? path, size: 1000);

List<String> _ids(List<SoundCandidate> candidates) => [
  for (final candidate in candidates) candidate.id,
];

void main() {
  group('loadCc0Catalog', () {
    test('never applies verified pack rules to moving main', () async {
      final requests = <String>[];
      final client = MockClient((request) async {
        requests.add(request.url.toString());
        if (request.url.path.endsWith('/commits/main')) {
          return http.Response(jsonEncode({'sha': 'f' * 40}), 200);
        }
        final pinned = request.url.path.contains('/$_commit');
        return http.Response(
          jsonEncode({
            'tree': [
              {
                'type': 'blob',
                'path': pinned
                    ? 'kenney_casinoaudio/Audio/chipsHandle5.ogg'
                    : 'kenney_unverified_future/audio.wav',
                'sha': 'e' * 40,
                'size': 10,
              },
            ],
          }),
          200,
        );
      });
      addTearDown(client.close);
      final candidates = await loadCc0Catalog(client);
      expect(requests, [
        'https://api.github.com/repos/$cc0Repository/git/trees/$_commit?recursive=1',
      ]);
      expect(_ids(candidates), [
        'cc0:kenney_casinoaudio/Audio/chipsHandle5.ogg',
      ]);
      expect(candidates.single.downloadUrl, contains('/$_commit/'));
      expect(candidates.single.sourcePage, contains('/$_commit/'));
    });
  });
  group('cc0Candidates', () {
    test('reads only packs whose licence was verified', () {
      final candidates = cc0Candidates([
        _file('kenney_casinoaudio/Audio/chipsHandle5.ogg'),
        _file('100-CC0-SFX/hit.ogg'),
        _file('angerdog/bark.wav'),
        _file('warfork-cc0/sounds/weapons/laser.ogg'),
      ], commit: _commit);

      expect(
        _ids(candidates),
        equals([
          'cc0:kenney_casinoaudio/Audio/chipsHandle5.ogg',
          'cc0:warfork-cc0/sounds/weapons/laser.ogg',
        ]),
      );
    });

    test('skips previews, macOS metadata, licence files and trailers', () {
      final candidates = cc0Candidates([
        _file('kenney_voiceoverpack/Preview (Male).ogg'),
        _file('MMRetroArcadeSoundsPack1_0_5/__MACOSX/wav/Beep1.wav'),
        _file('MMRetroArcadeSoundsPack1_0_5/Misc/wav/._Beep1.wav'),
        _file('kenney_casinoaudio/License.txt'),
        _file('warfork-cc0/sounds/trailer/cc0_download.wav'),
      ], commit: _commit);

      expect(candidates, isEmpty);
    });

    test('keeps the lossless copy of a recording shipped in three formats', () {
      final candidates = cc0Candidates([
        _file('MMRetroArcadeSoundsPack1_0_5/Explosions/ogg/Explosion1.ogg'),
        _file('MMRetroArcadeSoundsPack1_0_5/Explosions/wav/Explosion1.wav'),
        _file('MMRetroArcadeSoundsPack1_0_5/Explosions/m4a/Explosion1.m4a'),
      ], commit: _commit);

      expect(
        _ids(candidates),
        equals([
          'cc0:MMRetroArcadeSoundsPack1_0_5/Explosions/wav/Explosion1.wav',
        ]),
      );
    });

    test('keeps one of two byte-identical files', () {
      final candidates = cc0Candidates([
        _file('warfork-cc0/music/fvi-Chronos.ogg', blobSha: 'same'),
        _file('warfork-cc0/sounds/music/fvi-Chronos.ogg', blobSha: 'same'),
      ], commit: _commit);

      expect(candidates, hasLength(1));
    });

    test('decides music, effects and speech by pack and folder', () {
      final kinds = {
        for (final candidate in cc0Candidates([
          _file('kenney_musicjingles/Audio/Sax jingles/jingles_SAX15.ogg'),
          _file('kenney_voiceoverfighter/Audio/you_win.ogg'),
          _file('BB_2HTC Samples Vol 4/Loops/2023-08-23 Beachwalker - Go.wav'),
          _file('BB_2HTC Samples Vol 4/Drums/2023-08-02 Remain - Snare.wav'),
          _file('MMRetroArcadeSoundsPack1_0_5/Speech/wav/GameOver.wav'),
          _file('warfork-cc0/sounds/announcer/postmatch/game_over02.ogg'),
          _file('warfork-cc0/music/fvi-Arpent.ogg'),
        ], commit: _commit))
          candidate.title: candidate.kind,
      };

      expect(
        kinds,
        equals({
          'Jingles SAX 15': SoundKind.music,
          'You Win': SoundKind.speech,
          'Beachwalker - Go': SoundKind.music,
          'Remain - Snare': SoundKind.sfx,
          'Game Over': SoundKind.speech,
          'Game Over 2': SoundKind.speech,
          'Fvi - Arpent': SoundKind.music,
        }),
      );
    });

    test('credits the original author and pins the source to the commit', () {
      final candidate = cc0Candidates([
        _file("bb - Rubik's Cube (Feb 2021)/Big Cube - Twist 3.wav"),
      ], commit: _commit).single;

      expect(candidate.creatorName, equals('Ben Burnes'));
      expect(candidate.license, same(SoundLicense.cc0));
      expect(
        candidate.downloadUrl,
        equals(
          'https://raw.githubusercontent.com/$cc0Repository/$_commit/'
          "bb%20-%20Rubik's%20Cube%20(Feb%202021)/Big%20Cube%20-%20Twist%203.wav",
        ),
      );
      expect(
        candidate.sourcePage,
        startsWith('https://github.com/$cc0Repository/blob/$_commit/'),
      );
      expect(candidate.tags, equals(['foley']));
    });

    test('tags a sound with its pack and folders, not format folders', () {
      final candidate = cc0Candidates([
        _file('MMRetroArcadeSoundsPack1_0_5/Guns/wav/SciFiGun5.wav'),
      ], commit: _commit).single;

      expect(candidate.tags, equals(['retro', 'arcade', '8bit', 'guns']));
    });
  });
}
