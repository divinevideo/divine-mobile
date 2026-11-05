// ABOUTME: Tests for SoundLibraryService - loads and searches bundled sounds
// ABOUTME: Validates manifest loading, search, and custom sound import functionality

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/services/sound_library_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SoundLibraryService', () {
    test('parseManifest creates sounds from JSON', () {
      const manifestJson = '''
      {
        "sounds": [
          {
            "id": "sound_001",
            "title": "What Are Those",
            "assetPath": "assets/sounds/what_are_those.mp3",
            "durationMs": 3000,
            "tags": ["meme", "shoes"]
          },
          {
            "id": "sound_002",
            "title": "Road Work Ahead",
            "assetPath": "assets/sounds/road_work.mp3",
            "durationMs": 4000,
            "artist": "Drew Gooden",
            "tags": ["meme", "driving"]
          }
        ]
      }
      ''';

      final sounds = SoundLibraryService.parseManifest(manifestJson);

      expect(sounds.length, equals(2));
      expect(sounds[0].title, equals('What Are Those'));
      expect(sounds[1].artist, equals('Drew Gooden'));
    });

    test(
      'real manifest includes the bundled public domain short audio',
      () async {
        final manifestFile = File('assets/sounds/sounds_manifest.json');
        final sounds = SoundLibraryService.parseManifest(
          await manifestFile.readAsString(),
        );

        final sound = sounds.singleWhere(
          (s) => s.id == 'new_zealand_state_highway_73',
        );

        expect(sound.title, equals('New Zealand Road State Highway 73'));
        expect(
          sound.assetPath,
          equals('assets/sounds/new-zealand-state-highway-73.mp3'),
        );
        expect(sound.duration.inMilliseconds, greaterThan(0));
        expect(sound.license, equals('Public Domain'));
        expect(
          sound.sourceUrl,
          equals('https://www.youtube.com/shorts/kcEM8xNVyiU'),
        );
        expect(sound.tags, containsAll(<String>['default', 'short']));
      },
    );

    test('real manifest includes Wednesday My Dudes bundled clip', () async {
      final manifestFile = File('assets/sounds/sounds_manifest.json');
      final sounds = SoundLibraryService.parseManifest(
        await manifestFile.readAsString(),
      );

      final sound = sounds.singleWhere((s) => s.id == 'wednesday');

      expect(sound.title, equals('Wednesday My Dudes'));
      expect(sound.assetPath, equals('assets/sounds/wednesday.mp3'));
      expect(sound.duration.inMilliseconds, equals(6269));
    });

    test(
      'real manifest includes sound-bot clips with bundled assets',
      () async {
        final manifestFile = File('assets/sounds/sounds_manifest.json');
        final pubspecFile = File('pubspec.yaml');
        final sounds = SoundLibraryService.parseManifest(
          await manifestFile.readAsString(),
        );

        final soundBotSounds = sounds
            .where((sound) => sound.id.startsWith('soundbot_'))
            .toList();

        expect(soundBotSounds, hasLength(36));

        for (final sound in soundBotSounds) {
          expect(
            File(sound.assetPath).existsSync(),
            isTrue,
            reason: '${sound.id} should reference a bundled sound asset',
          );
          expect(sound.tags, contains('soundbot'));
          expect(sound.duration.inMilliseconds, greaterThan(0));
        }

        expect(
          await pubspecFile.readAsString(),
          contains('- assets/sounds/sound-bot/'),
        );
      },
    );

    test('legacy bundled sounds remain loadable for saved drafts', () async {
      // Drafts persist asset URLs, so removing a sound from the picker must
      // not remove the file an existing draft needs when it renders.
      const legacyAssetNames = [
        'sad_violin_sound_effect_hd_shorts_sounde_15_xO-y4s.mp3',
        'use_headphones_png_for_reels_shorts_vira_06_aTR9TI.mp3',
        'use_headphones_png_for_reels_shorts_vira_15_aTR9TI.mp3',
      ];

      for (final name in legacyAssetNames) {
        final assetPath = 'assets/sounds/sound-bot/$name';
        final bytes = await rootBundle.load(assetPath);
        expect(bytes.lengthInBytes, greaterThan(0), reason: assetPath);
      }
    });

    test('real manifest bundles no silent MP3 sounds', () async {
      final manifestFile = File('assets/sounds/sounds_manifest.json');
      final sounds = SoundLibraryService.parseManifest(
        await manifestFile.readAsString(),
      );

      final mp3Sounds = sounds
          .where((sound) => sound.assetPath.endsWith('.mp3'))
          .toList();
      expect(mp3Sounds, isNotEmpty);

      final silentSoundIds = [
        for (final sound in mp3Sounds)
          if (!_mp3HasCodedAudio(File(sound.assetPath).readAsBytesSync()))
            sound.id,
      ];

      expect(
        silentSoundIds,
        isEmpty,
        reason: 'these bundled sounds decode to pure digital silence',
      );
    });

    test('searchSounds filters by query', () {
      final sounds = [
        VineSound(
          id: 'sound_001',
          title: 'What Are Those',
          assetPath: 'assets/sounds/what.mp3',
          duration: const Duration(seconds: 3),
          tags: ['shoes'],
        ),
        VineSound(
          id: 'sound_002',
          title: 'Road Work Ahead',
          assetPath: 'assets/sounds/road.mp3',
          duration: const Duration(seconds: 4),
          tags: ['driving'],
        ),
      ];

      final results = SoundLibraryService.searchSounds(sounds, 'road');

      expect(results.length, equals(1));
      expect(results[0].id, equals('sound_002'));
    });

    test('searchSounds returns all when query empty', () {
      final sounds = [
        VineSound(
          id: 'sound_001',
          title: 'Sound 1',
          assetPath: 'assets/sounds/1.mp3',
          duration: const Duration(seconds: 3),
        ),
        VineSound(
          id: 'sound_002',
          title: 'Sound 2',
          assetPath: 'assets/sounds/2.mp3',
          duration: const Duration(seconds: 4),
        ),
      ];

      final results = SoundLibraryService.searchSounds(sounds, '');

      expect(results.length, equals(2));
    });
  });

  group('Custom Sound Import', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('addCustomSound adds sound to library', () async {
      final service = SoundLibraryService();

      final customSound = VineSound(
        id: 'custom_001',
        title: 'My Custom Sound',
        assetPath: '/path/to/custom/sound.mp3',
        duration: const Duration(seconds: 5),
        artist: 'User Upload',
        tags: ['custom'],
      );

      await service.addCustomSound(customSound);

      expect(service.sounds.any((s) => s.id == 'custom_001'), isTrue);
      expect(
        service.getSoundById('custom_001')?.title,
        equals('My Custom Sound'),
      );
    });

    test('addCustomSound persists custom sounds', () async {
      final service = SoundLibraryService();

      final customSound = VineSound(
        id: 'custom_002',
        title: 'Persisted Sound',
        assetPath: '/path/to/sound.mp3',
        duration: const Duration(seconds: 3),
      );

      await service.addCustomSound(customSound);

      // Create new service instance and load
      final newService = SoundLibraryService();
      await newService.loadCustomSounds();

      expect(newService.customSounds.any((s) => s.id == 'custom_002'), isTrue);
    });

    test('removeCustomSound removes sound from library', () async {
      final service = SoundLibraryService();

      final customSound = VineSound(
        id: 'custom_003',
        title: 'To Be Removed',
        assetPath: '/path/to/sound.mp3',
        duration: const Duration(seconds: 2),
      );

      await service.addCustomSound(customSound);
      expect(service.sounds.any((s) => s.id == 'custom_003'), isTrue);

      await service.removeCustomSound('custom_003');
      expect(service.sounds.any((s) => s.id == 'custom_003'), isFalse);
    });

    test('custom sounds appear in search results', () async {
      final service = SoundLibraryService();

      final customSound = VineSound(
        id: 'custom_004',
        title: 'Unique Audio Track',
        assetPath: '/path/to/sound.mp3',
        duration: const Duration(seconds: 4),
        tags: ['special'],
      );

      await service.addCustomSound(customSound);

      final results = service.search('unique');
      expect(results.any((s) => s.id == 'custom_004'), isTrue);
    });

    test('customSounds getter returns only custom sounds', () async {
      final service = SoundLibraryService();

      final customSound = VineSound(
        id: 'custom_005',
        title: 'Custom Only',
        assetPath: '/path/to/sound.mp3',
        duration: const Duration(seconds: 3),
      );

      await service.addCustomSound(customSound);

      expect(service.customSounds.length, equals(1));
      expect(service.customSounds.first.id, equals('custom_005'));
    });

    test(
      'reloadCustomSounds drops custom sounds no longer in storage',
      () async {
        final service = SoundLibraryService();
        await service.addCustomSound(
          VineSound(
            id: 'custom_006',
            title: 'Departing Sound',
            assetPath: '/path/to/sound.mp3',
            duration: const Duration(seconds: 2),
          ),
        );
        expect(service.customSounds, hasLength(1));

        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(SoundLibraryService.customSoundsStorageKey);
        await service.reloadCustomSounds();

        expect(service.customSounds, isEmpty);
      },
    );
  });
}

/// Layer III bitrates in kbit/s by bitrate index; MPEG-2 and 2.5 share one.
const _mpeg1Bitrates = [
  0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, //
];
const _mpeg2Bitrates = [
  0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160, //
];

/// Sample rates in Hz by MPEG version bits, then sample-rate index.
const _sampleRates = {
  3: [44100, 48000, 32000],
  2: [22050, 24000, 16000],
  0: [11025, 12000, 8000],
};

/// Whether any MPEG Layer III frame in [bytes] carries coded audio.
///
/// A granule whose `part2_3_length` is zero holds no scale factors and no
/// Huffman data, so it decodes to zero samples. A file in which every
/// granule is empty plays nothing but digital silence.
bool _mp3HasCodedAudio(Uint8List bytes) {
  var offset = 0;
  if (bytes.length >= 10 && String.fromCharCodes(bytes, 0, 3) == 'ID3') {
    final tagSize =
        (bytes[6] << 21) | (bytes[7] << 14) | (bytes[8] << 7) | bytes[9];
    final hasFooter = bytes[5] & 0x10 != 0;
    offset = 10 + tagSize + (hasFooter ? 10 : 0);
  }

  while (offset + 4 <= bytes.length) {
    final header =
        (bytes[offset] << 24) |
        (bytes[offset + 1] << 16) |
        (bytes[offset + 2] << 8) |
        bytes[offset + 3];
    final version = (header >> 19) & 3;
    final layer = (header >> 17) & 3;
    final bitrateIndex = (header >> 12) & 15;
    final sampleRateIndex = (header >> 10) & 3;
    final isValidLayerThree =
        header >> 21 == 0x7FF &&
        version != 1 &&
        layer == 1 &&
        bitrateIndex != 0 &&
        bitrateIndex != 15 &&
        sampleRateIndex != 3;
    if (!isValidLayerThree) {
      offset++;
      continue;
    }

    final isMpeg1 = version == 3;
    final bitrate =
        (isMpeg1 ? _mpeg1Bitrates : _mpeg2Bitrates)[bitrateIndex] * 1000;
    final sampleRate = _sampleRates[version]![sampleRateIndex];
    final padding = (header >> 9) & 1;
    final frameLength = (isMpeg1 ? 144 : 72) * bitrate ~/ sampleRate + padding;
    if (offset + frameLength > bytes.length) return false;

    final isMono = (header >> 6) & 3 == 3;
    final channels = isMono ? 1 : 2;
    final hasCrc = (header >> 16) & 1 == 0;
    var bit = (offset + 4 + (hasCrc ? 2 : 0)) * 8;
    if (isMpeg1) {
      bit += 9 + (isMono ? 5 : 3) + 4 * channels;
    } else {
      bit += 8 + (isMono ? 1 : 2);
    }

    // Each granule of each channel opens with its 12-bit part2_3_length.
    final blockCount = (isMpeg1 ? 2 : 1) * channels;
    final blockBits = isMpeg1 ? 59 : 63;
    for (var block = 0; block < blockCount; block++) {
      if (_readBits(bytes, bit, 12) > 0) return true;
      bit += blockBits;
    }
    offset += frameLength;
  }
  return false;
}

int _readBits(Uint8List bytes, int bitOffset, int count) {
  var value = 0;
  for (var i = bitOffset; i < bitOffset + count; i++) {
    value = (value << 1) | ((bytes[i >> 3] >> (7 - (i & 7))) & 1);
  }
  return value;
}
