// ABOUTME: Tests which of the app's own sounds the importer publishes, and the
// ABOUTME: credit and shipped-sound id each one carries.

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' show AudioEvent;

import '../../../tools/sound_import/app_sounds.dart';
import '../../../tools/sound_import/sound_candidate.dart';

Map<String, dynamic> _entry({
  String id = 'freesound_yay',
  String? license = 'CC0',
  String? sourceUrl = 'https://freesound.org/people/Some_User/sounds/61691/',
  List<String> tags = const ['cheer', 'reaction', 'freesound'],
}) => {
  'id': id,
  'title': 'YAY!',
  'assetPath': 'assets/sounds/yay.mp3',
  'durationMs': 4762,
  'tags': tags,
  'license': ?license,
  'sourceUrl': ?sourceUrl,
};

void main() {
  group('appSoundCandidates', () {
    test('turns a licensed Freesound entry into a credited candidate', () {
      final candidate = appSoundCandidates({
        'sounds': [_entry()],
      }).single;

      expect(candidate.id, equals('app:freesound_yay'));
      expect(candidate.divineSoundId, equals('freesound_yay'));
      expect(candidate.title, equals('YAY!'));
      expect(candidate.creatorName, equals('Some_User'));
      expect(
        candidate.creatorUrl,
        equals('https://freesound.org/people/Some_User/'),
      );
      expect(
        candidate.sourcePage,
        equals('https://freesound.org/people/Some_User/sounds/61691/'),
      );
      expect(candidate.license, same(SoundLicense.cc0));
      expect(candidate.kind, equals(SoundKind.sfx));
      expect(candidate.tags, equals(['cheer', 'reaction']));
      expect(
        candidate.downloadUrl,
        equals(
          'https://raw.githubusercontent.com/divinevideo/divine-mobile/'
          '$appSoundsCommit/mobile/assets/sounds/yay.mp3',
        ),
      );
    });

    test('reads both Creative Commons Attribution versions', () {
      final candidates = appSoundCandidates({
        'sounds': [
          _entry(license: 'CC BY 4.0'),
          _entry(id: 'freesound_radio_announcement', license: 'CC BY 3.0'),
        ],
      });

      expect(candidates.map((candidate) => candidate.license), [
        SoundLicense.ccBy4,
        SoundLicense.ccBy3,
      ]);
    });

    test('leaves out sounds without a usable licence or Freesound page', () {
      final candidates = appSoundCandidates({
        'sounds': [
          _entry(id: 'unknown', license: 'unknown'),
          _entry(id: 'none', license: null),
          _entry(
            id: 'video',
            license: 'Public Domain',
            sourceUrl: 'https://www.youtube.com/shorts/example',
          ),
          _entry(id: 'no-page', sourceUrl: null),
          _entry(id: 'unchecked-cc-by', license: 'CC BY 4.0'),
          _entry(id: 'kept'),
        ],
      });

      expect(candidates.map((candidate) => candidate.divineSoundId), [
        'kept',
      ]);
    });

    test('files a sound as the app does: music when tagged so, else an '
        'effect', () {
      SoundKind kindOf(List<String> tags) => appSoundCandidates({
        'sounds': [_entry(tags: tags)],
      }).single.kind;

      expect(kindOf(['music', 'bossa nova']), equals(SoundKind.music));
      expect(kindOf(['acapella', 'singing']), equals(SoundKind.sfx));
      expect(kindOf(['announcement', 'voice']), equals(SoundKind.sfx));
      expect(kindOf(['radio', 'sfx']), equals(SoundKind.sfx));
    });

    test("credits a CC BY sound with the recording's own title", () {
      final candidate = appSoundCandidates({
        'sounds': [
          _entry(id: 'freesound_radio_announcement', license: 'CC BY 3.0'),
        ],
      }).single;

      expect(candidate.creditLines, [
        'Your no.1 talk, music and news radio.m4a',
        'Created by Some_User',
        'License: CC BY 3.0 (https://creativecommons.org/licenses/by/3.0/)',
      ]);
    });

    test('says when the app ships only an excerpt of the recording', () {
      final candidate = appSoundCandidates({
        'sounds': [
          _entry(id: 'freesound_elevator_music', license: 'CC BY 4.0'),
        ],
      }).single;

      // The line the app reads to say so on the sound's page.
      expect(candidate.creditLines, contains(AudioEvent.excerptLine));
    });

    test('gives a CC0 sound the generic credit', () {
      final candidate = appSoundCandidates({
        'sounds': [_entry()],
      }).single;

      expect(candidate.creditLines, isEmpty);
    });

    test('keeps the shipped-sound id and credit through the catalog file', () {
      final candidate = appSoundCandidates({
        'sounds': [
          _entry(id: 'freesound_radio_announcement', license: 'CC BY 3.0'),
        ],
      }).single;

      final restored = SoundCandidate.fromJson(candidate.toJson());

      expect(restored.divineSoundId, equals('freesound_radio_announcement'));
      expect(restored.license, same(SoundLicense.ccBy3));
      expect(restored.creditLines, equals(candidate.creditLines));
    });
  });
}
