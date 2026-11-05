// ABOUTME: Tests that the importer's unsigned Kind 1063 events read back through
// ABOUTME: AudioEvent as a credited, reusable library sound.

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' show AudioEvent;
import 'package:nostr_sdk/event.dart';

import '../../../tools/sound_import/import_state.dart';
import '../../../tools/sound_import/incompetech.dart';
import '../../../tools/sound_import/sound_candidate.dart';
import '../../../tools/sound_import/sound_event_builder.dart';

const _pubkey =
    'c4a39f1291291d452405cd8ddd798c4a29a3858c52cd0d843f1f6852cf17682e';
const _sha = 'fdb1cc265820255c12cb912710d8d2c54a6a573da7f97f5ce38e9d85bf5af0e7';

const _trackPage =
    'https://incompetech.com/music/royalty-free/index.html?isrc=USUAN1200014';
const _cc0Url = 'https://creativecommons.org/publicdomain/zero/1.0/';

SoundCandidate _musicCandidate() => incompetechCandidates([
  {
    'title': 'Loping Sting',
    'filename': 'Loping Sting.mp3',
    'feel': 'Humorous, Bouncy',
    'instruments': 'Tuba, Piano',
    'isrc': 'USUAN1200014',
    'description': 'A short sting.',
  },
]).single;

ImportRecord _prepared({List<String> changes = const []}) => ImportRecord(
  status: ImportStatus.prepared,
  outputSha256: _sha,
  outputBytes: 105860,
  durationSeconds: 4.302063,
  changes: changes,
);

AudioEvent _parse(Map<String, Object?> unsigned) => AudioEvent.fromNostrEvent(
  Event(
    _pubkey,
    unsigned['kind']! as int,
    [
      for (final tag in unsigned['tags']! as List<List<String>>) tag,
    ],
    unsigned['content']! as String,
  ),
);

void main() {
  group('buildUnsignedSoundEvent', () {
    test('reads back as a reusable sound with the full credit', () {
      final candidate = _musicCandidate();
      final sound = _parse(
        buildUnsignedSoundEvent(
          candidate: candidate,
          record: _prepared(),
          blossomBase: 'https://media.example/',
          createdAt: 1700000000,
          pubkey: _pubkey,
        ),
      );

      expect(sound.url, equals('https://media.example/$_sha'));
      expect(sound.mimeType, equals('audio/mp4'));
      expect(sound.sha256, equals(_sha));
      expect(sound.fileSize, equals(105860));
      expect(sound.duration, closeTo(4.302, 0.0005));
      expect(sound.title, equals('Loping Sting'));
      expect(sound.creatorName, equals('Kevin MacLeod (incompetech.com)'));
      expect(sound.creatorUrl, equals('https://incompetech.com'));
      expect(sound.licenseName, equals('CC BY 4.0'));
      expect(
        sound.licenseUrl,
        equals('https://creativecommons.org/licenses/by/4.0/'),
      );
      expect(sound.source, equals(candidate.sourcePage));
      expect(sound.allowsReuse, isTrue);
      expect(
        sound.publicTags,
        equals(['music', 'humorous', 'bouncy', 'tuba', 'piano']),
      );
    });

    test('is neither a video sound nor a shipped Divine sound', () {
      final event = buildUnsignedSoundEvent(
        candidate: _musicCandidate(),
        record: _prepared(),
        blossomBase: 'https://media.example',
        createdAt: 1700000000,
      );
      final sound = _parse(event);

      expect(sound.sourceVideoReference, isNull);
      expect(sound.divineSoundId, isNull);
      expect(event['pubkey'], isEmpty);
    });

    test('carries the ISRC as a NIP-73 external content id', () {
      final tags =
          buildUnsignedSoundEvent(
                candidate: _musicCandidate(),
                record: _prepared(),
                blossomBase: 'https://media.example',
                createdAt: 1700000000,
              )['tags']!
              as List<List<String>>;

      expect(tags, contains(equals(['i', 'isrc:USUAN1200014'])));
      expect(tags, contains(equals(['k', 'isrc'])));
      expect(tags, contains(equals(['summary', 'A short sting.'])));
    });

    test('gives speech no kind tag', () {
      const speech = SoundCandidate(
        id: 'cc0:kenney_voiceoverfighter/Audio/you_win.ogg',
        downloadUrl: 'https://example.com/you_win.ogg',
        sourcePage: 'https://example.com/you_win',
        title: 'You Win',
        kind: SoundKind.speech,
        creatorName: 'Kenney',
        creatorUrl: 'https://kenney.nl',
        license: SoundLicense.cc0,
        tags: ['voice'],
      );
      final sound = _parse(
        buildUnsignedSoundEvent(
          candidate: speech,
          record: _prepared(),
          blossomBase: 'https://media.example',
          createdAt: 1700000000,
          pubkey: _pubkey,
        ),
      );

      expect(sound.publicTags, equals(['voice']));
    });

    test('refuses a candidate that was not prepared', () {
      expect(
        () => buildUnsignedSoundEvent(
          candidate: _musicCandidate(),
          record: ImportRecord(status: ImportStatus.rejected, reason: 'silent'),
          blossomBase: 'https://media.example',
          createdAt: 1700000000,
        ),
        throwsStateError,
      );
    });
  });

  group('soundCreditContent', () {
    test("quotes the creator's own credit and says what was edited", () {
      expect(
        soundCreditContent(
          _musicCandidate(),
          changes: const ['edge silence trimmed', 'loudness normalized'],
        ),
        equals(
          '"Loping Sting" Kevin MacLeod (incompetech.com)\n'
          'Licensed under Creative Commons: By Attribution 4.0 License\n'
          'https://creativecommons.org/licenses/by/4.0/\n'
          'Source: $_trackPage\n'
          'Edited: edge silence trimmed, loudness normalized',
        ),
      );
    });

    test('builds a generic credit and leaves out an empty edit line', () {
      const effect = SoundCandidate(
        id: 'cc0:kenney_casinoaudio/Audio/chipsHandle5.ogg',
        downloadUrl: 'https://example.com/chipsHandle5.ogg',
        sourcePage: 'https://example.com/chipsHandle5',
        title: 'Chips Handle 5',
        kind: SoundKind.sfx,
        creatorName: 'Kenney',
        creatorUrl: 'https://kenney.nl',
        license: SoundLicense.cc0,
      );

      expect(
        soundCreditContent(effect, changes: const []),
        equals(
          'Chips Handle 5\n'
          'Created by Kenney\n'
          'License: CC0 1.0 ($_cc0Url)\n'
          'Source: https://example.com/chipsHandle5',
        ),
      );
    });
  });
}
