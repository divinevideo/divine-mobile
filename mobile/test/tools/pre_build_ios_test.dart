// ABOUTME: Tests for mobile/pre_build_ios.sh, the Runner scheme's pre-action.
// ABOUTME: Pins that it syncs CocoaPods without ever invoking Flutter.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Drives `pre_build_ios.sh` against a sandboxed copy of the project layout.
///
/// The shared Runner scheme runs this script as a pre-action of every Xcode
/// build. Any Flutter command it runs there re-injects plugins, which rewrites
/// `ios/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage/
/// Package.swift` at Flutter's default iOS floor. Nothing on the
/// Xcode-driven build path raises that floor back to the project's 16.0, so
/// the build then fails with "requires minimum platform version 16.0 ... but
/// this target supports an older version" for every plugin with a higher floor. The
/// script must therefore never invoke `flutter`; that property is pinned here.
void main() {
  group('pre_build_ios.sh', () {
    late Directory sandbox;
    late String scriptPath;
    late Directory stubBin;
    late Directory stubLogs;

    File stubLog(String tool) => File(p.join(stubLogs.path, '$tool.log'));

    File swiftPackageManifest() => File(
      p.join(
        sandbox.path,
        'ios/Flutter/ephemeral/Packages/'
        'FlutterGeneratedPluginSwiftPackage/Package.swift',
      ),
    );

    /// Installs a `tool` shim on the sandboxed PATH that records its argv.
    void installStub(String tool) {
      final stub = File(p.join(stubBin.path, tool))
        ..writeAsStringSync(
          '#!/bin/sh\n'
          'printf \'%s\\n\' "\$*" >> "\$STUB_LOG_DIR/$tool.log"\n',
        );
      final chmod = Process.runSync('chmod', ['+x', stub.path]);
      expect(chmod.exitCode, 0, reason: chmod.stderr.toString());
    }

    void writeFile(String relativePath, DateTime modified) {
      File(p.join(sandbox.path, relativePath))
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('# $relativePath\n')
        ..setLastModifiedSync(modified);
    }

    ProcessResult runScript() {
      return Process.runSync(
        'bash',
        [scriptPath],
        workingDirectory: sandbox.path,
        environment: {
          'PATH': '${stubBin.path}:/usr/bin:/bin',
          'HOME': p.join(sandbox.path, 'home'),
          'STUB_LOG_DIR': stubLogs.path,
        },
        includeParentEnvironment: false,
      );
    }

    void expectSuccess(ProcessResult result) {
      expect(
        result.exitCode,
        0,
        reason: 'stdout:\n${result.stdout}\nstderr:\n${result.stderr}',
      );
      final flutterLog = stubLog('flutter');
      final invocations = flutterLog.existsSync()
          ? flutterLog.readAsStringSync()
          : '';
      expect(
        flutterLog.existsSync(),
        isFalse,
        reason: 'flutter was invoked with: $invocations',
      );
    }

    setUp(() {
      sandbox = Directory.systemTemp.createTempSync('pre_build_ios_');
      final realScript = File(
        p.join(Directory.current.path, 'pre_build_ios.sh'),
      );
      expect(
        realScript.existsSync(),
        isTrue,
        reason: 'mobile/pre_build_ios.sh must exist',
      );
      scriptPath = p.join(sandbox.path, 'pre_build_ios.sh');
      File(scriptPath).writeAsStringSync(
        realScript
            .readAsStringSync()
            .replaceAll('/opt/homebrew/bin/pod', '/nonexistent/homebrew/pod')
            .replaceAll('/usr/local/bin/pod', '/nonexistent/local/pod'),
      );
      final helperSource = File(
        p.join(
          Directory.current.path,
          'scripts/ensure_ios_swift_package_floor.rb',
        ),
      );
      final helperDestination = File(
        p.join(sandbox.path, 'scripts/ensure_ios_swift_package_floor.rb'),
      )..parent.createSync(recursive: true);
      helperDestination.writeAsStringSync(helperSource.readAsStringSync());
      stubBin = Directory(p.join(sandbox.path, 'bin'))..createSync();
      stubLogs = Directory(p.join(sandbox.path, 'logs'))..createSync();
      Directory(p.join(sandbox.path, 'home')).createSync();
      installStub('flutter');
      installStub('pod');
    });

    tearDown(() {
      sandbox.deleteSync(recursive: true);
    });

    test(
      'never invokes flutter, which could reset the Swift package floor',
      () {
        final now = DateTime.now();
        writeFile('ios/Podfile.lock', now.subtract(const Duration(hours: 1)));
        writeFile('ios/Pods/Manifest.lock', now);

        expectSuccess(runScript());

        expect(stubLog('flutter').existsSync(), isFalse);
      },
    );

    test('skips pod install when Pods/Manifest.lock is as new as '
        'Podfile.lock', () {
      final now = DateTime.now();
      writeFile('ios/Podfile.lock', now);
      writeFile('ios/Pods/Manifest.lock', now);

      final result = runScript();

      expectSuccess(result);
      expect(stubLog('pod').existsSync(), isFalse);
      expect(result.stdout, contains('CocoaPods dependencies are up to date'));
    });

    test('runs pod install when Podfile.lock is newer than '
        'Pods/Manifest.lock', () {
      final now = DateTime.now();
      writeFile(
        'ios/Pods/Manifest.lock',
        now.subtract(const Duration(hours: 1)),
      );
      writeFile('ios/Podfile.lock', now);

      expectSuccess(runScript());

      expect(stubLog('pod').readAsStringSync(), contains('install'));
    });

    test('runs pod install when Pods has never been installed', () {
      writeFile('ios/Podfile.lock', DateTime.now());

      expectSuccess(runScript());

      expect(stubLog('pod').readAsStringSync(), contains('install'));
    });

    test(
      'raises Flutter 3.47 generated Swift package floor without Flutter',
      () {
        final now = DateTime.now();
        writeFile('ios/Podfile.lock', now);
        writeFile('ios/Pods/Manifest.lock', now);
        swiftPackageManifest()
          ..parent.createSync(recursive: true)
          ..writeAsStringSync(
            'let package = Package(\n'
            '    name: "FlutterGeneratedPluginSwiftPackage",\n'
            '    platforms: [\n'
            '        .iOS("15.0")\n'
            '    ]\n'
            ')\n',
          );

        expectSuccess(runScript());
        expectSuccess(runScript());

        expect(
          swiftPackageManifest().readAsStringSync(),
          contains('.iOS("16.0")'),
        );
        expect(
          swiftPackageManifest().readAsStringSync(),
          isNot(contains('.iOS("15.0")')),
        );
      },
    );

    test('accepts a generated Swift package floor newer than iOS 16', () {
      final now = DateTime.now();
      writeFile('ios/Podfile.lock', now);
      writeFile('ios/Pods/Manifest.lock', now);
      swiftPackageManifest()
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(
          'let package = Package(\n'
          '    name: "FlutterGeneratedPluginSwiftPackage",\n'
          '    platforms: [\n'
          '        .iOS("17.0")\n'
          '    ]\n'
          ')\n',
        );

      expectSuccess(runScript());

      expect(
        swiftPackageManifest().readAsStringSync(),
        contains('.iOS("17.0")'),
      );
    });

    test('finds CocoaPods installed only through rbenv', () {
      stubLog('pod').parent.createSync(recursive: true);
      File(p.join(stubBin.path, 'pod')).deleteSync();
      final rbenvBin = Directory(p.join(sandbox.path, 'home/.rbenv/bin'))
        ..createSync(recursive: true);
      final rbenvShims = Directory(p.join(sandbox.path, 'home/.rbenv/shims'))
        ..createSync(recursive: true);
      final rbenv = File(p.join(rbenvBin.path, 'rbenv'))
        ..writeAsStringSync('#!/bin/sh\n');
      final rbenvChmod = Process.runSync('chmod', ['+x', rbenv.path]);
      expect(rbenvChmod.exitCode, 0, reason: rbenvChmod.stderr.toString());
      final pod = File(p.join(rbenvShims.path, 'pod'))
        ..writeAsStringSync(
          '#!/bin/sh\n'
          'printf \'%s\\n\' "\$*" >> "\$STUB_LOG_DIR/pod.log"\n',
        );
      final podChmod = Process.runSync('chmod', ['+x', pod.path]);
      expect(podChmod.exitCode, 0, reason: podChmod.stderr.toString());
      writeFile('ios/Podfile.lock', DateTime.now());

      expectSuccess(runScript());

      expect(stubLog('pod').readAsStringSync(), contains('install'));
    });

    test('fails clearly when CocoaPods is unavailable', () {
      File(p.join(stubBin.path, 'pod')).deleteSync();
      Directory(p.join(sandbox.path, 'ios')).createSync();

      final result = runScript();

      expect(result.exitCode, 1);
      expect(
        '${result.stdout}${result.stderr}',
        contains('CocoaPods not found'),
      );
      expect(stubLog('flutter').existsSync(), isFalse);
    });
  });
}
