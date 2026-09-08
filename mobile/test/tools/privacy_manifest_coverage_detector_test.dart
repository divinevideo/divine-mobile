// ABOUTME: Pins the iOS required-reason API privacy-manifest coverage guard.
// ABOUTME: Holds the PHAsset-vs-FileAttributeKey line that stops over-declaring.

import 'dart:io';

import 'package:test/test.dart';

/// Pins `scripts/lib/privacy_manifest_coverage.py` (#8803).
///
/// The detector's value is entirely in what it does *not* flag. Apple's
/// required-reason `creationDate` is `FileAttributeKey.creationDate`, not
/// `PHAsset.creationDate`, and `LibProofMode/Classes/MediaItem.swift` uses both
/// kinds within forty lines of each other. A detector that matched the bare
/// accessor would push an author into declaring a reason the code never
/// exercises -- and Apple permits use only for declared reasons, so an unused
/// declaration is inaccurate rather than cautious. These tests hold that line.
void main() {
  final script = File('scripts/lib/privacy_manifest_coverage.py').absolute.path;

  /// Builds a throwaway `mobile/`-shaped tree and runs the detector over it.
  ({int exitCode, String output}) run({
    required Directory root,
    List<String> args = const [],
  }) {
    final result = Process.runSync('python3', [
      script,
      '--mobile',
      root.path,
      ...args,
    ]);
    return (
      exitCode: result.exitCode,
      output: '${result.stdout}${result.stderr}',
    );
  }

  Directory makeTree({
    required String swift,
    String? objectiveC,
    String? manifest,
    String? selectedSubspec,
    String podspec =
        "s.resource_bundles = {'p' => ['Resources/PrivacyInfo.xcprivacy']}",
  }) {
    final root = Directory.systemTemp.createTempSync('privacy_manifest_test');
    addTearDown(() => root.deleteSync(recursive: true));
    final pkg = Directory('${root.path}/packages/sample/ios')
      ..createSync(recursive: true);
    Directory('${pkg.path}/Classes').createSync(recursive: true);
    File('${pkg.path}/Classes/Sample.swift').writeAsStringSync(swift);
    if (objectiveC != null) {
      File('${pkg.path}/Classes/Sample.m').writeAsStringSync(objectiveC);
    }
    File('${pkg.path}/sample.podspec').writeAsStringSync(podspec);
    Directory('${root.path}/ios/Runner').createSync(recursive: true);
    if (selectedSubspec != null) {
      File('${root.path}/ios/Podfile').writeAsStringSync(
        "pod 'sample/$selectedSubspec', :path => '../packages/sample/ios'\n",
      );
    }
    if (manifest != null) {
      Directory('${pkg.path}/Resources').createSync(recursive: true);
      File(
        '${pkg.path}/Resources/PrivacyInfo.xcprivacy',
      ).writeAsStringSync(manifest);
    }
    return root;
  }

  String manifestFor(String category, String reason) =>
      '''
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>NSPrivacyAccessedAPITypes</key>
	<array>
		<dict>
			<key>NSPrivacyAccessedAPIType</key>
			<string>$category</string>
			<key>NSPrivacyAccessedAPITypeReasons</key>
			<array><string>$reason</string></array>
		</dict>
	</array>
</dict>
</plist>
''';

  group('privacy_manifest_coverage detector', () {
    group('undeclared required-reason API', () {
      test('fails when a used category has no manifest at all', () {
        final root = makeTree(
          swift: 'let t = ProcessInfo.processInfo.systemUptime\n',
        );
        final result = run(root: root);

        expect(result.exitCode, equals(1));
        expect(
          result.output,
          contains('NSPrivacyAccessedAPICategorySystemBootTime'),
        );
        expect(result.output, contains('NO manifest'));
      });

      test('fails when the manifest omits the category that is used', () {
        final root = makeTree(
          swift: 'let d = UserDefaults.standard\n',
          manifest: manifestFor(
            'NSPrivacyAccessedAPICategorySystemBootTime',
            '35F9.1',
          ),
        );
        final result = run(root: root);

        expect(result.exitCode, equals(1));
        expect(result.output, contains('does not declare it'));
      });

      test('passes when the used category is declared', () {
        final root = makeTree(
          swift: 'let t = ProcessInfo.processInfo.systemUptime\n',
          manifest: manifestFor(
            'NSPrivacyAccessedAPICategorySystemBootTime',
            '35F9.1',
          ),
        );
        final result = run(root: root);

        expect(result.exitCode, equals(0), reason: result.output);
      });
    });

    group('false-positive guards', () {
      test('does not fail on a bare PHAsset-style .creationDate accessor', () {
        final root = makeTree(
          swift:
              'self.modified = asset.modificationDate\n'
              'let c = asset.creationDate\n',
        );
        final result = run(root: root);

        // Reported for a human to judge, never fatal: PHAsset metadata carries
        // no declaration duty, and over-declaring is itself inaccurate.
        expect(result.exitCode, equals(0), reason: result.output);
        expect(result.output, contains('review required'));
      });

      test('does fail on the unambiguous URLResourceKey form', () {
        final root = makeTree(
          swift:
              'let a = try '
              'url.resourceValues(forKeys: [.contentModificationDateKey])\n',
        );
        final result = run(root: root);

        expect(result.exitCode, equals(1));
        expect(
          result.output,
          contains('NSPrivacyAccessedAPICategoryFileTimestamp'),
        );
      });

      test('detects Objective-C timestamp and disk-space constants', () {
        final root = makeTree(
          swift: '',
          objectiveC:
              'id timestamp = NSURLContentModificationDateKey;\n'
              'id capacity = NSURLVolumeTotalCapacityKey;\n',
        );
        final result = run(root: root);

        expect(result.exitCode, equals(1));
        expect(
          result.output,
          contains('NSPrivacyAccessedAPICategoryFileTimestamp'),
        );
        expect(
          result.output,
          contains('NSPrivacyAccessedAPICategoryDiskSpace'),
        );
      });

      test(
        'reports cross-category getattrlist calls without forcing either',
        () {
          final root = makeTree(
            swift: 'getattrlist(path, &attributes, &buffer, size, 0)\n',
          );
          final result = run(root: root);

          expect(result.exitCode, equals(0), reason: result.output);
          expect(
            result.output,
            contains('possible NSPrivacyAccessedAPICategoryFileTimestamp use'),
          );
          expect(
            result.output,
            contains('possible NSPrivacyAccessedAPICategoryDiskSpace use'),
          );
        },
      );

      test('ignores an API named only in a comment or string literal', () {
        final root = makeTree(
          swift:
              '// bridges launch config through UserDefaults\n'
              'let message = "statfs failed"\n'
              '/* systemUptime is not called here */\n',
        );
        final result = run(root: root);

        expect(result.exitCode, equals(0), reason: result.output);
      });

      test('does not let a URL string hide an API later on the line', () {
        final root = makeTree(
          swift:
              'log("https://example.com"); '
              'let t = ProcessInfo.processInfo.systemUptime\n',
        );
        final result = run(root: root);

        expect(result.exitCode, equals(1));
        expect(
          result.output,
          contains('NSPrivacyAccessedAPICategorySystemBootTime'),
        );
      });

      test('ignores a call that only compiles into DEBUG builds', () {
        final root = makeTree(
          swift:
              '#if DEBUG\n'
              '  let d = UserDefaults.standard\n'
              '#endif\n',
        );
        final result = run(root: root);

        expect(result.exitCode, equals(0), reason: result.output);
      });

      test('still counts the Release branch of a DEBUG conditional', () {
        final root = makeTree(
          swift:
              '#if DEBUG\n'
              '  let a = 1\n'
              '#else\n'
              '  let d = UserDefaults.standard\n'
              '#endif\n',
        );
        final result = run(root: root);

        expect(result.exitCode, equals(1));
        expect(
          result.output,
          contains('NSPrivacyAccessedAPICategoryUserDefaults'),
        );
      });
    });

    group('manifest validity', () {
      test('rejects a reason code that is not valid for its category', () {
        final root = makeTree(
          swift: 'let t = ProcessInfo.processInfo.systemUptime\n',
          // CA92.1 is a UserDefaults reason, not a SystemBootTime one.
          manifest: manifestFor(
            'NSPrivacyAccessedAPICategorySystemBootTime',
            'CA92.1',
          ),
        );
        final result = run(root: root);

        expect(result.exitCode, equals(1));
        expect(result.output, contains('invalid reason code'));
      });

      test('rejects an unknown API category string', () {
        final root = makeTree(
          swift: 'let t = ProcessInfo.processInfo.systemUptime\n',
          manifest: manifestFor('NSPrivacyAccessedAPICategoryMadeUp', '35F9.1'),
        );
        final result = run(root: root);

        expect(result.exitCode, equals(1));
        expect(result.output, contains('unknown API category'));
      });

      test('rejects an app manifest missing from Copy Bundle Resources', () {
        final root = Directory.systemTemp.createTempSync('privacy_app_test');
        addTearDown(() => root.deleteSync(recursive: true));
        Directory('${root.path}/ios/Runner').createSync(recursive: true);
        Directory(
          '${root.path}/ios/Runner.xcodeproj',
        ).createSync(recursive: true);
        File('${root.path}/ios/Runner/PrivacyInfo.xcprivacy').writeAsStringSync(
          manifestFor('NSPrivacyAccessedAPICategoryUserDefaults', 'CA92.1'),
        );
        // A project that never lists the manifest: it ships nothing.
        File(
          '${root.path}/ios/Runner.xcodeproj/project.pbxproj',
        ).writeAsStringSync('// objectVersion = 54;\n');

        final result = run(root: root);

        expect(result.exitCode, equals(1));
        expect(result.output, contains('Copy Bundle Resources'));
      });

      test('rejects an app manifest that is only an Xcode file reference', () {
        final root = Directory.systemTemp.createTempSync('privacy_app_test');
        addTearDown(() => root.deleteSync(recursive: true));
        Directory('${root.path}/ios/Runner').createSync(recursive: true);
        Directory(
          '${root.path}/ios/Runner.xcodeproj',
        ).createSync(recursive: true);
        File('${root.path}/ios/Runner/PrivacyInfo.xcprivacy').writeAsStringSync(
          manifestFor('NSPrivacyAccessedAPICategoryUserDefaults', 'CA92.1'),
        );
        File(
          '${root.path}/ios/Runner.xcodeproj/project.pbxproj',
        ).writeAsStringSync('''
/* Begin PBXFileReference section */
ABC123 /* PrivacyInfo.xcprivacy */ = {isa = PBXFileReference; path = PrivacyInfo.xcprivacy; sourceTree = "<group>"; };
/* End PBXFileReference section */
''');

        final result = run(root: root);

        expect(result.exitCode, equals(1));
        expect(result.output, contains('Copy Bundle Resources'));
      });

      test('rejects a manifest the podspec never bundles', () {
        final root = makeTree(
          swift: 'let t = ProcessInfo.processInfo.systemUptime\n',
          manifest: manifestFor(
            'NSPrivacyAccessedAPICategorySystemBootTime',
            '35F9.1',
          ),
          podspec: "s.source_files = 'Classes/**/*'",
        );
        final result = run(root: root);

        expect(result.exitCode, equals(1));
        expect(result.output, contains('never reaches the archive'));
      });

      test('rejects a manifest mentioned only in a podspec comment', () {
        final root = makeTree(
          swift: 'let t = ProcessInfo.processInfo.systemUptime\n',
          manifest: manifestFor(
            'NSPrivacyAccessedAPICategorySystemBootTime',
            '35F9.1',
          ),
          podspec:
              '# TODO: add Resources/PrivacyInfo.xcprivacy to resource_bundles\n'
              "s.source_files = 'Classes/**/*'",
        );
        final result = run(root: root);

        expect(result.exitCode, equals(1));
        expect(result.output, contains('never reaches the archive'));
      });

      for (final quote in ["'", '"']) {
        test('rejects root-only bundling with $quote-quoted subspec', () {
          final root = makeTree(
            swift: 'let t = ProcessInfo.processInfo.systemUptime\n',
            manifest: manifestFor(
              'NSPrivacyAccessedAPICategorySystemBootTime',
              '35F9.1',
            ),
            podspec:
                "s.resource_bundles = {'p' => "
                "['Resources/PrivacyInfo.xcprivacy']}\n"
                "s.subspec 'PrivacyProtected' do |ss|\n"
                "  ss.source_files = 'Classes/**/*'\n"
                'end\n',
          );
          File('${root.path}/ios/Podfile').writeAsStringSync(
            '  pod ${quote}sample/PrivacyProtected$quote, '
            ":path => '../packages/sample/ios'\n",
          );
          final result = run(root: root);

          expect(result.exitCode, equals(1));
          expect(result.output, contains('never reaches the archive'));
        });
      }

      test('ignores a commented-out Podfile subspec selection', () {
        final root = makeTree(
          swift: 'let t = ProcessInfo.processInfo.systemUptime\n',
          manifest: manifestFor(
            'NSPrivacyAccessedAPICategorySystemBootTime',
            '35F9.1',
          ),
        );
        File('${root.path}/ios/Podfile').writeAsStringSync(
          "# pod 'sample/Unused'\n"
          "pod 'sample', :path => '../packages/sample/ios'\n",
        );

        final result = run(root: root);

        expect(result.exitCode, equals(0), reason: result.output);
      });

      test('accepts a manifest bundled by the selected subspec', () {
        final root = makeTree(
          swift: 'let t = ProcessInfo.processInfo.systemUptime\n',
          manifest: manifestFor(
            'NSPrivacyAccessedAPICategorySystemBootTime',
            '35F9.1',
          ),
          selectedSubspec: 'PrivacyProtected',
          podspec:
              "s.subspec 'PrivacyProtected' do |ss|\n"
              "  ss.resource_bundles = {'p' => "
              "['Resources/PrivacyInfo.xcprivacy']}\n"
              'end\n',
        );
        final result = run(root: root);

        expect(result.exitCode, equals(0), reason: result.output);
      });
    });

    test('archive mode requires the quick-actions privacy bundle', () {
      final root = Directory.systemTemp.createTempSync('privacy_archive_test');
      addTearDown(() => root.deleteSync(recursive: true));
      final app = Directory('${root.path}/Runner.app')..createSync();
      final plist = manifestFor(
        'NSPrivacyAccessedAPICategorySystemBootTime',
        '35F9.1',
      );
      for (final path in [
        'PrivacyInfo.xcprivacy',
        'divine_camera_privacy.bundle/PrivacyInfo.xcprivacy',
        'LibProofMode_privacy.bundle/PrivacyInfo.xcprivacy',
      ]) {
        final file = File('${app.path}/$path');
        file.parent.createSync(recursive: true);
        file.writeAsStringSync(plist);
      }

      final result = run(root: root, args: ['--archive', app.path]);

      expect(result.exitCode, equals(1));
      expect(result.output, contains('divine_quick_actions'));
    });
  });
}
