// ABOUTME: Tests how a sound credit is laid out and which bar levels its
// ABOUTME: equalizer shows at a moment of the video.

import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_editor/info_sticker.dart';
import 'package:openvine/models/video_editor/social_sticker.dart';
import 'package:openvine/utils/audio_band_energies.dart';
import 'package:openvine/utils/sound_credit_paint.dart';

const _credit = SocialStickerData(
  kind: SocialStickerKind.soundCredit,
  soundTitle: 'Song',
  soundArtist: 'Artist',
);

void main() {
  group('soundCreditSize', () {
    test('grows a short credit to fit a player', () {
      final note = soundCreditSize(_credit);
      final player = soundCreditSize(
        _credit.copyWith(soundDesign: SocialStickerSoundDesign.player),
      );

      expect(player.width, greaterThan(note.width));
      expect(player.height, greaterThan(note.height));
    });

    test('leaves out the artist line of a sound without an artist', () {
      const untitledArtist = SocialStickerData(
        kind: SocialStickerKind.soundCredit,
        soundTitle: 'Song',
      );

      expect(
        soundCreditSize(untitledArtist).height,
        lessThan(soundCreditSize(_credit).height),
      );
    });
  });

  group('paintSoundCredit', () {
    int linesPainted(InfoStickerStyle style, {required bool overFrames}) {
      final canvas = _LineCountingCanvas();
      paintSoundCredit(
        canvas,
        const Size(400, 160),
        data: _credit.copyWith(style: style),
        overFrames: overFrames,
      );
      return canvas.lines;
    }

    test('leaves the artist to the frames over a see-through pill', () {
      expect(linesPainted(InfoStickerStyle.dark, overFrames: false), 2);
      expect(linesPainted(InfoStickerStyle.dark, overFrames: true), 1);
    });

    test('draws the artist again over a solid pill', () {
      expect(linesPainted(InfoStickerStyle.brand, overFrames: true), 2);
    });
  });

  group('soundCreditLevelsAt', () {
    test('reads the row of bar levels at a moment', () {
      const bars = soundCreditEqualizerBars;
      final levels = Float32List(bars * 3);
      for (var row = 0; row < 3; row++) {
        levels.fillRange(row * bars, row * bars + bars, row / 2);
      }

      final atSecondRow = soundCreditLevelsAt(
        levels,
        const Duration(microseconds: 1000000 ~/ audioBandFrameRate + 1),
      );

      expect(atSecondRow, everyElement(0.5));
    });

    test('gives no levels without any to read', () {
      expect(soundCreditLevelsAt(null, Duration.zero), isNull);
    });
  });
}

/// Counts the lines of text painted on it and ignores everything else.
class _LineCountingCanvas implements Canvas {
  int lines = 0;

  @override
  void drawParagraph(Paragraph paragraph, Offset offset) => lines++;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
