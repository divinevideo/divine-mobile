import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/c2pa_debris_janitor.dart';
import 'package:path/path.dart' as p;

void main() {
  group(C2paDebrisJanitor, () {
    late Directory tempDir;
    late DateTime now;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('c2pa_debris_janitor_');
      now = DateTime(2026, 8, 18, 12);
    });

    tearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    File writeFile(
      String name, {
      required Duration age,
      List<int> bytes = const [],
    }) {
      final file = File(p.join(tempDir.path, name))..writeAsBytesSync(bytes);
      file.setLastModifiedSync(now.subtract(age));
      return file;
    }

    test('deletes only empty C2PA output older than the cutoff', () {
      final stale = writeFile(
        'c2pa_signed_1786964993571.mp4',
        age: C2paDebrisJanitor.staleDebrisAge + const Duration(seconds: 1),
      );
      final atCutoff = writeFile(
        'c2pa_signed_1786964993572.mp4',
        age: C2paDebrisJanitor.staleDebrisAge,
      );
      final fresh = writeFile(
        'c2pa_signed_1786964993573.mp4',
        age: C2paDebrisJanitor.staleDebrisAge - const Duration(seconds: 1),
      );
      final nonEmpty = writeFile(
        'c2pa_signed_1786964993574.mp4',
        age: C2paDebrisJanitor.staleDebrisAge + const Duration(seconds: 1),
        bytes: const [1],
      );

      C2paDebrisJanitor.deleteStaleDebris(tempDir, now: now);

      expect(stale.existsSync(), isFalse);
      expect(atCutoff.existsSync(), isTrue);
      expect(fresh.existsSync(), isTrue);
      expect(nonEmpty.existsSync(), isTrue);
    });

    test('preserves recordings and other derived media', () {
      final protected =
          [
                'VID_20260814_113531.mp4',
                'VID_1786700133469.mp4',
                'trimmed_1.mp4',
                'merged_1.mp4',
                'watermarked_1.mp4',
                'normalized_1.mp4',
                '1786964993571.mp4',
                'C2PA_SIGNED_1.mp4',
                'c2pa_signed.mp4',
                'c2pa_signed_abc.mp4',
                'pre_c2pa_signed_1.mp4',
                'c2pa_signed_1.mov',
                'c2pa_signed_1786964993575.mp4.tmp',
                'c2pa_signed_1786964993576.mp4.bak',
              ]
              .map(
                (name) => writeFile(
                  name,
                  age:
                      C2paDebrisJanitor.staleDebrisAge +
                      const Duration(seconds: 1),
                ),
              )
              .toList();
      final matchingDirectory = Directory(
        p.join(tempDir.path, 'c2pa_signed_2.mp4'),
      )..createSync();

      C2paDebrisJanitor.deleteStaleDebris(tempDir, now: now);

      for (final file in protected) {
        expect(file.existsSync(), isTrue, reason: p.basename(file.path));
      }
      expect(matchingDirectory.existsSync(), isTrue);
    });

    test('deletes stale unsigned originals beside their signed copy', () {
      final stale =
          C2paDebrisJanitor.staleDebrisAge + const Duration(minutes: 1);
      final signedNames = [
        'VID_20260614_113531.mp4',
        'divine_1786700133469.mp4',
        'VID_1786700133470.MOV',
      ];
      final signed = [
        for (final name in signedNames)
          writeFile(name, age: stale, bytes: [1, 2]),
      ];
      final twins = [
        for (final name in signedNames)
          writeFile('$name.old', age: stale, bytes: [1, 2]),
      ];

      C2paDebrisJanitor.deleteStaleDebris(tempDir, now: now);

      for (final twin in twins) {
        expect(twin.existsSync(), isFalse, reason: p.basename(twin.path));
      }
      for (final file in signed) {
        expect(file.existsSync(), isTrue, reason: p.basename(file.path));
      }
    });

    test('keeps an unsigned original whose signed copy is missing or '
        'empty', () {
      // Up to 1.0.19 a failure between the two renames left the `.old` file
      // as the only copy of the recording.
      final stale =
          C2paDebrisJanitor.staleDebrisAge + const Duration(minutes: 1);
      final stranded = writeFile(
        'VID_20260614_113532.mp4.old',
        age: stale,
        bytes: [1, 2],
      );
      writeFile('VID_20260614_113533.mp4', age: stale);
      final besideEmpty = writeFile(
        'VID_20260614_113533.mp4.old',
        age: stale,
        bytes: [1, 2],
      );

      C2paDebrisJanitor.deleteStaleDebris(tempDir, now: now);

      expect(stranded.existsSync(), isTrue);
      expect(besideEmpty.existsSync(), isTrue);
    });

    test('keeps fresh unsigned originals and other .old files', () {
      final stale =
          C2paDebrisJanitor.staleDebrisAge + const Duration(minutes: 1);
      writeFile('VID_1786964993571.mp4', age: stale, bytes: [1]);
      final kept = [
        writeFile(
          'VID_1786964993571.mp4.old',
          age: C2paDebrisJanitor.staleDebrisAge,
          bytes: [1],
        ),
        writeFile('flutter.db.old', age: stale, bytes: [1]),
        writeFile('settings.json.old', age: stale, bytes: [1]),
        writeFile('VID_1.mp4.old.tmp', age: stale, bytes: [1]),
        writeFile('VID_1.old', age: stale, bytes: [1]),
        writeFile('.mp4.old', age: stale, bytes: [1]),
      ];

      C2paDebrisJanitor.deleteStaleDebris(tempDir, now: now);

      for (final file in kept) {
        expect(file.existsSync(), isTrue, reason: p.basename(file.path));
      }
    });

    test('does not recurse into subdirectories', () {
      final nestedDirectory = Directory(p.join(tempDir.path, 'nested'))
        ..createSync();
      final nested = File(
        p.join(nestedDirectory.path, 'c2pa_signed_1786964993571.mp4'),
      )..writeAsBytesSync(const []);
      nested.setLastModifiedSync(
        now.subtract(
          C2paDebrisJanitor.staleDebrisAge + const Duration(seconds: 1),
        ),
      );

      C2paDebrisJanitor.deleteStaleDebris(tempDir, now: now);

      expect(nested.existsSync(), isTrue);
    });

    test('does not follow or delete symlinked debris', () {
      final target = writeFile(
        'link_target.bin',
        age: C2paDebrisJanitor.staleDebrisAge + const Duration(seconds: 1),
      );
      final link = Link(p.join(tempDir.path, 'c2pa_signed_1786964993571.mp4'))
        ..createSync(target.path);

      C2paDebrisJanitor.deleteStaleDebris(tempDir, now: now);

      expect(link.existsSync(), isTrue);
      expect(target.existsSync(), isTrue);
    });

    test('missing and invalid directories do not throw', () {
      final missing = Directory(p.join(tempDir.path, 'missing'));
      final regularFile = File(p.join(tempDir.path, 'not_a_directory'))
        ..writeAsBytesSync(const []);

      expect(
        () => C2paDebrisJanitor.deleteStaleDebris(missing, now: now),
        returnsNormally,
      );
      expect(
        () => C2paDebrisJanitor.deleteStaleDebris(
          Directory(regularFile.path),
          now: now,
        ),
        returnsNormally,
      );
    });
  });
}
