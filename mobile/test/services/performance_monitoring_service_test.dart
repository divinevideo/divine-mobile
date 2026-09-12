// ABOUTME: Tests for Firebase Performance Monitoring service
// ABOUTME: Verifies trace creation, metrics, attributes, and the native and
// ABOUTME: Dart switches that keep developer builds out of the dataset

import 'dart:io';

import 'package:app_update_repository/app_update_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/performance_monitoring_service.dart';

/// The value `FIREBASE_PERFORMANCE_COLLECTION_DEACTIVATED` resolves to in the
/// xcconfig at [path], or `null` when it is never assigned.
///
/// Skips `//` comment lines and takes the last assignment, as xcconfig does.
String? _deactivationSetting(String path) {
  final assignment = RegExp(
    r'^\s*FIREBASE_PERFORMANCE_COLLECTION_DEACTIVATED\s*=\s*(\S+)\s*$',
  );

  String? value;
  for (final line in File(path).readAsLinesSync()) {
    if (line.trimLeft().startsWith('//')) continue;
    final match = assignment.firstMatch(line);
    if (match != null) value = match.group(1);
  }
  return value;
}

void main() {
  group('PerformanceMonitoringService.collectionEnabled', () {
    test('stays off outside release builds', () {
      // Premise: the test runner is not a release build, so this asserts the
      // same branch a developer's `flutter run` takes.
      expect(kReleaseMode, isFalse, reason: 'tests must run in non-release');

      // #7123: collection was enabled unconditionally, so developer devices
      // reported into the production dataset alongside real users. Local
      // builds were 9.5% of the 1.0.19 `_app_start` sample at a p50 of 919 ms
      // against ~100 ms for the same phone on a store build — enough to
      // manufacture a release-over-release regression that the release code
      // did not contain.
      expect(PerformanceMonitoringService.collectionEnabled, isFalse);
    });
  });

  group('PerformanceMonitoringService.distributedBuildsOnly', () {
    test('holds, so a local release build does not report', () {
      // #7302: `kReleaseMode` cannot tell `flutter run --release` on a
      // developer's phone from a store build. Four such devices put 449 rows
      // under the pubspec build number in the month after #7158 shipped.
      expect(PerformanceMonitoringService.distributedBuildsOnly, isTrue);
    });
  });

  group('PerformanceMonitoringService.isDistributedBuild', () {
    test('accepts any build that carries the Shorebird engine', () {
      // Every Play, App Store and TestFlight artifact comes out of
      // `shorebird release`, whatever installer the OS reports for it.
      for (final source in InstallSource.values) {
        expect(
          PerformanceMonitoringService.isDistributedBuild(
            shorebirdAvailable: true,
            installSource: source,
          ),
          isTrue,
          reason: source.name,
        );
      }
    });

    test('accepts a Zapstore install without the engine', () {
      // Zapstore ships the split APKs Codemagic builds with plain
      // `flutter build`, so the installer package is the only signal.
      expect(
        PerformanceMonitoringService.isDistributedBuild(
          shorebirdAvailable: false,
          installSource: InstallSource.zapstore,
        ),
        isTrue,
      );
    });

    test('rejects a build with neither signal', () {
      // A local `flutter build` reports sideload on Android and, installed
      // through Xcode, a sandbox receipt on iOS — so neither store-looking
      // installer is enough on its own.
      for (final source in InstallSource.values) {
        if (source == InstallSource.zapstore) continue;
        expect(
          PerformanceMonitoringService.isDistributedBuild(
            shorebirdAvailable: false,
            installSource: source,
          ),
          isFalse,
          reason: source.name,
        );
      }
    });
  });

  group('native performance collection config', () {
    // The Dart gate above cannot suppress `_app_start` — that trace is
    // captured natively before Dart runs — so these switches are what actually
    // keep developer builds out of the dataset. They are also the fragile
    // half: `Debug.xcconfig` and `Release.xcconfig` are Flutter template files
    // that a scaffolding repair overwrites without saying so.
    final deactivatesCollection = RegExp(
      r'<meta-data\b'
      r'(?=[^>]*\bandroid:name\s*=\s*'
      '"firebase_performance_collection_deactivated")'
      r'(?=[^>]*\bandroid:value\s*=\s*"true")'
      r'[^>]*/\s*>',
    );

    for (final buildType in ['debug', 'profile']) {
      test('deactivates collection in the Android $buildType manifest', () {
        final manifest = File(
          'android/app/src/$buildType/AndroidManifest.xml',
        ).readAsStringSync();
        final applicationBlock = RegExp(
          r'<application\b[\s\S]*?</application>',
        ).firstMatch(manifest);

        expect(
          applicationBlock,
          isNotNull,
          reason: 'meta-data is only read inside an <application> block.',
        );
        expect(applicationBlock!.group(0), matches(deactivatesCollection));
      });
    }

    test('leaves the Android release manifest reporting', () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();

      expect(deactivatesCollection.hasMatch(manifest), isFalse);
    });

    test('reads the iOS switch from the build setting', () {
      final plist = File('ios/Runner/Info.plist').readAsStringSync();

      expect(
        plist,
        matches(
          RegExp(
            r'<key>\s*firebase_performance_collection_deactivated\s*</key>\s*'
            r'<string>\s*\$\(FIREBASE_PERFORMANCE_COLLECTION_DEACTIVATED\)\s*'
            '</string>',
          ),
        ),
      );
    });

    test('sets that build setting per iOS configuration', () {
      expect(_deactivationSetting('ios/Flutter/Debug.xcconfig'), 'YES');
      expect(_deactivationSetting('ios/Flutter/Profile.xcconfig'), 'YES');
      expect(_deactivationSetting('ios/Flutter/Release.xcconfig'), 'NO');
    });

    test('wires the iOS Profile configuration to Profile.xcconfig', () {
      // Without this, Profile falls through to Release.xcconfig and inherits
      // FIREBASE_PERFORMANCE_COLLECTION_DEACTIVATED=NO, so `_app_start` still
      // reports from the first launch of an iOS profile build.
      final pbxproj = File(
        'ios/Runner.xcodeproj/project.pbxproj',
      ).readAsStringSync();

      expect(
        pbxproj,
        contains('path = Flutter/Profile.xcconfig'),
        reason: 'Profile.xcconfig must be a project file reference.',
      );
      expect(
        RegExp(
          r'249021D4217E4FDB00AE95B9 /\* Profile \*/ = \{'
          r'[\s\S]*?'
          r'baseConfigurationReference = [0-9A-F]+ /\* Profile\.xcconfig \*/;',
        ).hasMatch(pbxproj),
        isTrue,
        reason: 'Runner target Profile configuration must point at Profile.xcconfig.',
      );
    });
  });

  group('PerformanceMonitoringService', () {
    late PerformanceMonitoringService service;

    setUp(() {
      service = PerformanceMonitoringService();
    });

    test('isEnabled stays false while Firebase is unavailable', () async {
      // The flag gates the instrumented HTTP client (#7122): it must only
      // turn true once Firebase Performance actually came up, never merely
      // because initialize() was called and swallowed a failure.
      expect(service.isEnabled, isFalse);

      await service.initialize(distributedBuild: true);

      expect(service.isEnabled, isFalse);
    });

    test(
      'startOperationTrace returns a handle that tags and stops cleanly',
      () async {
        await service.initialize(distributedBuild: true);

        final trace = service.startOperationTrace('test_operation');

        // Tagging and stopping the handle must be safe even when Firebase
        // isn't configured (the uninitialised path returns a no-op handle).
        trace
          ..putAttribute('outcome', 'success')
          ..setMetric('phase_ms', 120);
        await expectLater(trace.stop(), completes);
      },
    );
  });

  group(NoOpPerformanceTraceMonitor, () {
    test('startOperationTrace hands out a no-op trace handle', () async {
      const monitor = NoOpPerformanceTraceMonitor();

      final trace = monitor.startOperationTrace('test_operation');
      trace
        ..putAttribute('outcome', 'success')
        ..setMetric('phase_ms', 120);

      await expectLater(trace.stop(), completes);
    });
  });
}
