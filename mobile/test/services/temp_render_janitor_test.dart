import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/temp_render_janitor.dart';

void main() {
  group(TempRenderJanitor, () {
    late Directory tempDir;
    late DateTime now;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('temp_render_janitor_');
      now = DateTime(2026, 8, 14, 12);
    });

    tearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    File writeFile(String name, {required Duration age}) {
      final file = File('${tempDir.path}/$name')..writeAsBytesSync([1, 2, 3]);
      file.setLastModifiedSync(now.subtract(age));
      return file;
    }

    test('matches all clearable temp render names', () {
      expect(TempRenderJanitor.isTempRenderName('watermarked_1.mp4'), isTrue);
      expect(TempRenderJanitor.isTempRenderName('merged_1.mp4'), isTrue);
      expect(TempRenderJanitor.isTempRenderName('merged_audio_1.wav'), isTrue);
      // The rest of what the editor writes to the temporary directory, which
      // only the repair wipe used to reach (#7641).
      expect(TempRenderJanitor.isTempRenderName('trimmed_1.mp4'), isTrue);
      expect(TempRenderJanitor.isTempRenderName('cropped_1.mp4'), isTrue);
      expect(TempRenderJanitor.isTempRenderName('normalized_0_1.mp4'), isTrue);
      expect(TempRenderJanitor.isTempRenderName('speed_1.mp4'), isTrue);
      expect(
        TempRenderJanitor.isTempRenderName('extracted_audio_1.wav'),
        isTrue,
      );
      expect(TempRenderJanitor.isTempRenderName('strip_clip_1_0.jpg'), isTrue);
      expect(TempRenderJanitor.isTempRenderName('merged_audio_1.mp4'), isFalse);
      expect(TempRenderJanitor.isTempRenderName('unrelated.mp4'), isFalse);
      expect(TempRenderJanitor.isTempRenderName('merged_1.wav'), isFalse);
      expect(TempRenderJanitor.isTempRenderName('trimmed_1.wav'), isFalse);
    });

    test('names every scratch directory the editor and player write', () {
      expect(TempRenderDirectories.all, [
        'speed_clips',
        'divine_player_assets',
        'divine_player_memory',
        'divine_player_audio_assets',
        'divine_player_audio_memory',
      ]);
    });

    test(
      'sweeps stale matching renders and keeps fresh or protected files',
      () {
        final stale = writeFile(
          'merged_1.mp4',
          age: TempRenderJanitor.staleRenderAge + const Duration(minutes: 1),
        );
        final fresh = writeFile(
          'merged_2.mp4',
          age: TempRenderJanitor.staleRenderAge - const Duration(minutes: 1),
        );
        final protected = writeFile(
          'merged_3.mp4',
          age: TempRenderJanitor.staleRenderAge + const Duration(minutes: 1),
        );
        final unrelated = writeFile(
          'other.mp4',
          age: TempRenderJanitor.staleRenderAge + const Duration(minutes: 1),
        );

        TempRenderJanitor.deleteStaleTempRenders(
          tempDir,
          patterns: const [TempRenderPatterns.mergedVideo],
          protectedPaths: {protected.path},
          now: now,
        );

        expect(stale.existsSync(), isFalse);
        expect(fresh.existsSync(), isTrue);
        expect(protected.existsSync(), isTrue);
        expect(unrelated.existsSync(), isTrue);
      },
    );
  });
}
