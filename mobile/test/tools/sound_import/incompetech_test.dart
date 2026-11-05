// ABOUTME: Tests the mapping of incompetech's track list to import candidates.

import 'package:flutter_test/flutter_test.dart';

import '../../../tools/sound_import/incompetech.dart';
import '../../../tools/sound_import/sound_candidate.dart';

Map<String, Object?> _piece({
  String title = 'The Britons',
  String filename = 'The Britons.mp3',
  String isrc = 'USUAN2600004',
  String feel = 'Ren Faire, Medieval',
  String instruments = 'Lute, Recorder, Drums, Flute, Guitar',
  String description = 'Tavern music like from the olden days.',
}) => {
  'title': title,
  'filename': filename,
  'feel': feel,
  'instruments': instruments,
  'isrc': isrc,
  'description': description,
};

void main() {
  group('incompetechCandidates', () {
    test('credits Kevin MacLeod under CC BY 4.0', () {
      final candidate = incompetechCandidates([_piece()]).single;

      expect(candidate.id, equals('incompetech:USUAN2600004'));
      expect(candidate.kind, equals(SoundKind.music));
      expect(candidate.creatorName, equals('Kevin MacLeod (incompetech.com)'));
      expect(candidate.license, same(SoundLicense.ccBy4));
      expect(candidate.isrc, equals('USUAN2600004'));
      expect(
        candidate.creditLines,
        equals([
          '"The Britons" Kevin MacLeod (incompetech.com)',
          'Licensed under Creative Commons: By Attribution 4.0 License',
          'https://creativecommons.org/licenses/by/4.0/',
        ]),
      );
    });

    test('links the file and the track page', () {
      final candidate = incompetechCandidates([_piece()]).single;

      expect(
        candidate.downloadUrl,
        equals(
          'https://incompetech.com/music/royalty-free/mp3-royaltyfree/'
          'The%20Britons.mp3',
        ),
      );
      expect(
        candidate.sourcePage,
        equals(
          'https://incompetech.com/music/royalty-free/index.html'
          '?isrc=USUAN2600004',
        ),
      );
    });

    test('tags feel first, then instruments, at most five', () {
      final candidate = incompetechCandidates([_piece()]).single;

      expect(
        candidate.tags,
        equals(['renfaire', 'medieval', 'lute', 'recorder', 'drums']),
      );
    });

    test('leaves out entries without an ISRC and repeated ISRCs', () {
      final candidates = incompetechCandidates([
        _piece(isrc: ''),
        _piece(title: 'First'),
        _piece(title: 'Second'),
      ]);

      expect(candidates.map((candidate) => candidate.title), equals(['First']));
    });

    test('survives a round trip through the catalog file', () {
      final candidate = incompetechCandidates([_piece()]).single;
      final restored = SoundCandidate.fromJson(candidate.toJson());

      expect(restored.toJson(), equals(candidate.toJson()));
    });
  });

  group('SoundLicense.fromUrl', () {
    test('refuses a licence the importer was not reviewed for', () {
      expect(
        () => SoundLicense.fromUrl(
          'https://creativecommons.org/licenses/by-nc/4.0/',
        ),
        throwsFormatException,
      );
    });
  });
}
