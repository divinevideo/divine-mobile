// ABOUTME: Tests loading the sticker emoji font: from the device once kept,
// ABOUTME: never from a download that is not the expected file.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openvine/utils/sticker_emoji_font.dart';

/// The size of the font as Google Fonts serves it.
const _fontLength = 24015012;

void main() {
  group('loadStickerEmojiFont', () {
    late Directory directory;
    late List<int> registered;
    late int requests;

    setUp(() {
      directory = Directory.systemTemp.createTempSync('sticker_emoji_font');
      registered = [];
      requests = 0;
    });

    tearDown(() {
      resetStickerEmojiFontForTesting();
      directory.deleteSync(recursive: true);
    });

    Future<bool> load(http.Response Function() respond) => loadStickerEmojiFont(
      client: MockClient((_) async {
        requests++;
        return respond();
      }),
      cacheDirectory: () async => directory,
      register: (bytes) async => registered.add(bytes.length),
    );

    test('loads the font kept on the device without downloading it', () async {
      File(
        '${directory.path}/'
        'a98676580777f4f555d83287fb6e515f7450a7eae58466cbd1f4fed32ee03aaa.ttf',
      ).writeAsBytesSync(Uint8List(_fontLength));

      final loaded = await load(() => http.Response('', 500));

      expect(loaded, isTrue);
      expect(stickerEmojiFontLoaded, isTrue);
      expect(registered, equals([_fontLength]));
      expect(requests, isZero);
    });

    test(
      'keeps nothing and loads nothing from a file that is not it',
      () async {
        final loaded = await load(
          () => http.Response.bytes(Uint8List(_fontLength), 200),
        );

        expect(loaded, isFalse);
        expect(stickerEmojiFontLoaded, isFalse);
        expect(registered, isEmpty);
        expect(directory.listSync(), isEmpty);
      },
    );

    test('does not repeat a failed download during the session', () async {
      expect(await load(() => http.Response('', 503)), isFalse);
      expect(await load(() => http.Response('', 503)), isFalse);

      expect(requests, equals(1));
    });
  });

  group('loadStickerEmojiFontFor', () {
    tearDown(resetStickerEmojiFontForTesting);

    test('loads the font only for a text with an emoji', () async {
      var loads = 0;
      debugLoadStickerEmojiFont = () async {
        loads++;
        return true;
      };

      await loadStickerEmojiFontFor(['summer', 'Café']);
      expect(loads, isZero);

      await loadStickerEmojiFontFor(['summer', 'party 🎉']);
      expect(loads, equals(1));
      expect(stickerEmojiFontLoaded, isTrue);
    });
  });
}
