// ABOUTME: Tests for the Maestro copy-drift guard.
// ABOUTME: Verifies extraction, drift, regen refusal, base erosion, and rendered bindings.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Drives `scripts/check_maestro_copy_drift.sh` against an isolated synthetic
/// mobile tree so the detector behavior from #6978 is pinned without touching
/// the real Maestro baseline.
void main() {
  group('maestro copy-drift guard', () {
    late Directory tmp;
    late Directory mobile;
    late File script;
    late File arb;
    late File manifest;

    File flow(String relative) => File('${mobile.path}/e2e/maestro/$relative');

    void writeArb(Map<String, String> values) {
      arb
        ..createSync(recursive: true)
        ..writeAsStringSync(
          '${const JsonEncoder.withIndent('  ').convert(values)}\n',
        );
    }

    void writeFlow(String relative, String body) {
      final file = flow(relative);
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(body);
    }

    void writeManifest(String body) {
      manifest
        ..createSync(recursive: true)
        ..writeAsStringSync(body);
    }

    void writeDart(String relative, String body) {
      final file = File('${mobile.path}/lib/$relative');
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(body);
    }

    ProcessResult run({
      bool update = false,
      bool acceptRemovals = false,
      String? baseRef,
      bool allowNoBase = true,
    }) {
      final environment = <String, String>{};
      if (update) environment['UPDATE_BASELINE'] = '1';
      if (acceptRemovals) environment['ACCEPT_REMOVALS'] = '1';
      if (baseRef != null) environment['MAESTRO_COPY_DRIFT_BASE_REF'] = baseRef;
      if (allowNoBase) environment['MAESTRO_COPY_DRIFT_ALLOW_NO_BASE'] = '1';

      return Process.runSync(
        'bash',
        [script.path],
        workingDirectory: mobile.parent.path,
        environment: environment,
      );
    }

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('maestro_copy_drift_test');
      mobile = Directory('${tmp.path}/mobile')..createSync(recursive: true);
      Directory('${mobile.path}/e2e/maestro').createSync(recursive: true);
      Directory('${mobile.path}/scripts').createSync(recursive: true);
      script = File(
        'scripts/check_maestro_copy_drift.sh',
      ).absolute.copySync('${mobile.path}/scripts/check_maestro_copy_drift.sh');
      arb = File('${mobile.path}/lib/l10n/app_en.arb');
      manifest = File(
        '${mobile.path}/scripts/baseline/maestro_copy_manifest.txt',
      );
    });

    tearDown(() {
      try {
        tmp.deleteSync(recursive: true);
      } on PathNotFoundException {
        // Another cleanup may remove the temp tree between exists and delete.
      }
    });

    test('passes and reports the binding denominator for a clean manifest', () {
      writeArb({'settingsTitle': 'Settings'});
      writeFlow('asserts/menu.yaml', '- assertVisible: Settings\n');
      writeManifest('settingsTitle\te2e/maestro/asserts/menu.yaml\n');

      final res = run();

      expect(res.exitCode, 0, reason: res.stderr.toString());
      expect(
        res.stdout,
        contains('1 bindings verified (of 1 asserted literals extracted)'),
      );
    });

    test('extracts each copy line from a literal block scalar', () {
      writeArb({
        'settingsTitle': 'Settings',
        'settingsSubtitle': 'Choose your preferences',
      });
      writeFlow(
        'asserts/menu.yaml',
        '- assertVisible: |-\n'
            '    Settings\n'
            '    Choose your preferences\n',
      );
      writeManifest('# generated below\n');

      final res = run(update: true);

      expect(res.exitCode, 0, reason: res.stderr.toString());
      expect(
        manifest.readAsStringSync(),
        allOf(
          contains('settingsTitle\te2e/maestro/asserts/menu.yaml'),
          contains('settingsSubtitle\te2e/maestro/asserts/menu.yaml'),
        ),
      );
    });

    test('extracts each copy line from a folded block scalar', () {
      writeArb({
        'settingsTitle': 'Settings',
        'settingsSubtitle': 'Choose your preferences',
      });
      writeFlow(
        'asserts/menu.yaml',
        '- tapOn: >-\n'
            '    Settings\n'
            '    Choose your preferences\n',
      );
      writeManifest('# generated below\n');

      final res = run(update: true);

      expect(res.exitCode, 0, reason: res.stderr.toString());
      expect(
        manifest.readAsStringSync(),
        allOf(
          contains('settingsTitle\te2e/maestro/asserts/menu.yaml'),
          contains('settingsSubtitle\te2e/maestro/asserts/menu.yaml'),
        ),
      );
    });

    test('extracts block scalars with keep and indentation indicators', () {
      writeArb({
        'settingsTitle': 'Settings',
        'settingsSubtitle': 'Choose your preferences',
      });
      writeFlow(
        'asserts/menu.yaml',
        '- assertVisible: |+\n'
            '    Settings\n'
            '- assertVisible: >2-\n'
            '  Choose your preferences\n',
      );
      writeManifest('# generated below\n');

      final res = run(update: true);

      expect(res.exitCode, 0, reason: res.stderr.toString());
      expect(
        manifest.readAsStringSync(),
        allOf(
          contains('settingsTitle\te2e/maestro/asserts/menu.yaml'),
          contains('settingsSubtitle\te2e/maestro/asserts/menu.yaml'),
        ),
      );
    });

    test('binds a multi-line ARB value within a block scalar', () {
      writeArb({
        'keyExplanation': 'First paragraph.\n\nSecond paragraph. Third line.',
      });
      writeFlow(
        'asserts/keys.yaml',
        '- assertVisible: |-\n'
            '    Heading\n'
            '    First paragraph.\n'
            '\n'
            '    Second paragraph.\n'
            '    Third line.\n',
      );
      writeManifest('# generated below\n');

      final regen = run(update: true);
      final check = run();

      expect(regen.exitCode, 0, reason: regen.stderr.toString());
      expect(check.exitCode, 0, reason: check.stderr.toString());
      expect(
        manifest.readAsStringSync(),
        contains('keyExplanation\te2e/maestro/asserts/keys.yaml'),
      );
    });

    test('does not bind multi-line copy embedded within a block line', () {
      writeArb({'findPeople': 'Find\npeople'});
      writeFlow(
        'asserts/people.yaml',
        '- assertVisible: |-\n'
            '    Find people to follow now\n',
      );
      writeManifest('# generated below\n');

      final regen = run(update: true);

      expect(regen.exitCode, 0, reason: regen.stderr.toString());
      expect(manifest.readAsStringSync(), isNot(contains('findPeople')));
    });

    test('does not bind regex or interpolated block-scalar lines', () {
      writeArb({'settingsTitle': 'Settings', 'privacyTitle': 'Privacy'});
      writeFlow(
        'asserts/menu.yaml',
        '- assertVisible: |-\n'
            '    Settings\n'
            r'    ${ACCOUNT_NAME}'
            '\n'
            '    Privacy.*\n',
      );
      writeManifest('# generated below\n');

      final regen = run(update: true);
      final check = run();

      expect(regen.exitCode, 0, reason: regen.stderr.toString());
      expect(check.exitCode, 0, reason: check.stderr.toString());
      expect(
        check.stdout,
        contains('1 bindings verified (of 2 asserted literals extracted)'),
      );
      expect(manifest.readAsStringSync(), isNot(contains('privacyTitle')));
    });

    test('preserves hash-prefixed copy inside a block scalar', () {
      writeArb({'hashtagTitle': '#vine'});
      writeFlow(
        'asserts/hashtag.yaml',
        '- assertVisible: |-\n'
            '    #vine\n',
      );
      writeManifest('# generated below\n');

      final regen = run(update: true);
      final check = run();

      expect(regen.exitCode, 0, reason: regen.stderr.toString());
      expect(check.exitCode, 0, reason: check.stderr.toString());
      expect(
        manifest.readAsStringSync(),
        contains('hashtagTitle\te2e/maestro/asserts/hashtag.yaml'),
      );
    });

    test('fails when ARB-backed flow copy is unregistered', () {
      writeArb({'settingsTitle': 'Settings', 'privacyTitle': 'Privacy'});
      writeFlow(
        'asserts/menu.yaml',
        '- assertVisible: Settings\n'
            '- assertVisible: Privacy\n',
      );
      writeManifest('settingsTitle\te2e/maestro/asserts/menu.yaml\n');

      final res = run();

      expect(res.exitCode, 1);
      expect(res.stderr, contains('UNREGISTERED'));
      expect(res.stderr, contains('Privacy'));
    });

    test('regen prefers live Dart references for duplicate ARB values', () {
      writeArb({
        'libraryClipSelectionTitle': 'Clips',
        'libraryTabClips': 'Clips',
      });
      writeDart(
        'screens/library_screen.dart',
        'final label = context.l10n.libraryTabClips;\n',
      );
      writeFlow('asserts/library.yaml', '- assertVisible: Clips\n');
      writeManifest('# generated below\n');

      final res = run(update: true);

      expect(res.exitCode, 0, reason: res.stderr.toString());
      expect(
        manifest.readAsStringSync(),
        contains('libraryTabClips\te2e/maestro/asserts/library.yaml'),
      );
      expect(
        manifest.readAsStringSync(),
        isNot(contains('libraryClipSelectionTitle')),
      );
    });

    test('regen preserves a reviewed duplicate-value binding', () {
      writeArb({'categoryGallerySortNew': 'New', 'exploreTabNew': 'New'});
      writeDart(
        'screens/category_gallery.dart',
        'final label = context.l10n.categoryGallerySortNew;\n',
      );
      writeDart(
        'screens/explore.dart',
        'final label = context.l10n.exploreTabNew;\n',
      );
      writeFlow('asserts/explore.yaml', '- assertVisible: New\n');
      writeManifest(
        'exploreTabNew\te2e/maestro/asserts/explore.yaml\tbound:New\n',
      );

      final res = run(update: true);

      expect(res.exitCode, 0, reason: res.stderr.toString());
      expect(
        manifest.readAsStringSync(),
        contains('exploreTabNew\te2e/maestro/asserts/explore.yaml'),
      );
      expect(manifest.readAsStringSync(), isNot(contains('categoryGallery')));
    });

    test('fails when ARB copy changes under a bound flow', () {
      writeArb({'settingsTitle': 'Preferences'});
      writeFlow('asserts/menu.yaml', '- assertVisible: Settings\n');
      writeManifest('settingsTitle\te2e/maestro/asserts/menu.yaml\n');

      final res = run();

      expect(res.exitCode, 1);
      expect(
        res.stderr,
        contains('DRIFT: copy changed under the Maestro suite'),
      );
      expect(res.stderr, contains('Update the flow to the current copy first'));
    });

    test('regen refuses to erase a binding while key and flow still exist', () {
      writeArb({'settingsTitle': 'Preferences'});
      writeFlow('asserts/menu.yaml', '- assertVisible: Settings\n');
      writeManifest('settingsTitle\te2e/maestro/asserts/menu.yaml\n');

      final res = run(update: true);

      expect(res.exitCode, 1);
      expect(res.stderr, contains('regen refused'));
      expect(
        manifest.readAsStringSync(),
        'settingsTitle\te2e/maestro/asserts/menu.yaml\n',
      );
    });

    test('ACCEPT_REMOVALS makes an intentional vanished binding explicit', () {
      writeArb({'settingsTitle': 'Preferences'});
      writeFlow('asserts/menu.yaml', '- assertVisible: Settings\n');
      writeManifest('settingsTitle\te2e/maestro/asserts/menu.yaml\n');

      final res = run(update: true, acceptRemovals: true);

      expect(res.exitCode, 0, reason: res.stderr.toString());
      expect(res.stdout, contains('WARNING: 1 binding(s) removed'));
      expect(
        manifest.readAsLinesSync().where(
          (line) => line.isNotEmpty && !line.startsWith('#'),
        ),
        isEmpty,
      );
    });

    test('commented-out copy does not satisfy a binding', () {
      writeArb({'settingsTitle': 'Settings'});
      writeFlow('asserts/menu.yaml', '# - assertVisible: Settings\n');
      writeManifest('settingsTitle\te2e/maestro/asserts/menu.yaml\n');

      final res = run();

      expect(res.exitCode, 1);
      expect(
        res.stderr,
        contains('DRIFT: copy changed under the Maestro suite'),
      );
    });

    test('rendered ICU bindings are carried through regeneration', () {
      writeArb({'profileVideoThumbnailLabel': 'Video thumbnail {number}'});
      writeFlow('tests/searchTags.yaml', '- tapOn: Video thumbnail 1\n');
      writeManifest(
        'profileVideoThumbnailLabel\te2e/maestro/tests/searchTags.yaml'
        '\trendered:Video thumbnail 1\n',
      );

      final res = run(update: true);

      expect(res.exitCode, 0, reason: res.stderr.toString());
      expect(res.stdout, contains('1 hand-maintained'));
      expect(
        manifest.readAsStringSync(),
        contains(
          'profileVideoThumbnailLabel\te2e/maestro/tests/searchTags.yaml'
          '\trendered:Video thumbnail 1',
        ),
      );
    });

    test('renamed ARB key does not excuse a vanished binding', () {
      writeArb({'authConnectSigner': 'Link a signer application'});
      writeFlow(
        'asserts/menu.yaml',
        '- assertVisible: Connect with a signer app\n',
      );
      writeManifest(
        'authConnectSignerApp\te2e/maestro/asserts/menu.yaml'
        '\tbound:Connect with a signer app\n',
      );

      final res = run(update: true);

      expect(res.exitCode, 1);
      expect(res.stderr, contains('regen refused'));
      expect(res.stderr, contains('key no longer exists'));
      expect(manifest.readAsStringSync(), contains('authConnectSignerApp'));
    });

    test('pure rename with unchanged value re-binds without a refusal', () {
      writeArb({'authConnectSigner': 'Connect with a signer app'});
      writeFlow(
        'asserts/menu.yaml',
        '- assertVisible: Connect with a signer app\n',
      );
      writeManifest(
        'authConnectSignerApp\te2e/maestro/asserts/menu.yaml'
        '\tbound:Connect with a signer app\n',
      );

      final res = run(update: true);

      expect(res.exitCode, 0, reason: res.stderr.toString());
      expect(res.stdout, contains('1 added, 1 removed'));
      expect(
        manifest.readAsStringSync(),
        contains('authConnectSigner\te2e/maestro/asserts/menu.yaml'),
      );
    });

    test('rendered bindings fail when the ARB template changes', () {
      writeArb({'profileVideoThumbnailLabel': 'Clip {number}'});
      writeFlow('tests/searchTags.yaml', '- tapOn: Video thumbnail 1\n');
      writeManifest(
        'profileVideoThumbnailLabel\te2e/maestro/tests/searchTags.yaml'
        '\trendered:Video thumbnail 1\n',
      );

      final res = run();

      expect(res.exitCode, 1);
      expect(res.stderr, contains('ARB template'));
      expect(res.stderr, contains('Clip {number}'));
    });

    test('base-ref ratchet fails when a branch erodes a base binding', () {
      writeArb({'settingsTitle': 'Preferences'});
      writeFlow('asserts/menu.yaml', '- assertVisible: Settings\n');
      writeManifest('settingsTitle\te2e/maestro/asserts/menu.yaml\n');

      expect(
        Process.runSync('git', [
          'init',
          '-b',
          'main',
        ], workingDirectory: tmp.path).exitCode,
        0,
      );
      expect(
        Process.runSync('git', [
          'add',
          '.',
        ], workingDirectory: tmp.path).exitCode,
        0,
      );
      expect(
        Process.runSync('git', [
          '-c',
          'user.name=test',
          '-c',
          'user.email=test@example.com',
          'commit',
          '-m',
          'base',
        ], workingDirectory: tmp.path).exitCode,
        0,
      );
      expect(
        Process.runSync('git', [
          'switch',
          '-c',
          'branch',
        ], workingDirectory: tmp.path).exitCode,
        0,
      );

      writeManifest('# branch regenerated the binding away\n');

      final res = run(baseRef: 'main', allowNoBase: false);

      expect(res.exitCode, 1);
      expect(res.stderr, contains('ERODED'));
    });

    test('fails closed when the base ref cannot be loaded', () {
      writeArb({'settingsTitle': 'Settings'});
      writeFlow('asserts/menu.yaml', '- assertVisible: Settings\n');
      writeManifest('settingsTitle\te2e/maestro/asserts/menu.yaml\n');

      final res = run(baseRef: 'refs/heads/does-not-exist', allowNoBase: false);

      expect(res.exitCode, 1);
      expect(res.stderr, contains('could not load the manifest'));
      expect(res.stderr, contains('failing closed'));
    });

    test('extracts a visible: scalar under extendedWaitUntil', () {
      writeArb({'videoUnlike': 'Unlike video'});
      writeFlow(
        'asserts/liked.yaml',
        '- extendedWaitUntil:\n'
            '    visible: Unlike video\n'
            '    timeout: 15000\n'
            '- extendedWaitUntil:\n'
            '    visible:\n'
            '      id: like_button\n'
            '    timeout: 15000\n',
      );
      writeManifest('# generated below\n');

      final regen = run(update: true);
      final check = run();

      expect(regen.exitCode, 0, reason: regen.stderr.toString());
      expect(
        manifest.readAsStringSync(),
        contains('videoUnlike\te2e/maestro/asserts/liked.yaml'),
      );
      expect(check.exitCode, 0, reason: check.stderr.toString());
      expect(
        check.stdout,
        contains('1 bindings verified (of 1 asserted literals extracted)'),
      );
    });

    test('extracts a visible: scalar under runFlow.when', () {
      writeArb({
        'nostrInfoWhySix': 'Why six seconds?',
        'nostrInfoGotIt': 'Got it!',
      });
      writeFlow(
        'utils/openRecorder.yaml',
        '- runFlow:\n'
            '    when:\n'
            '      visible: "Why six seconds?"\n'
            '    commands:\n'
            '      - tapOn: "Got it!"\n',
      );
      writeManifest('# generated below\n');

      final res = run(update: true);

      expect(res.exitCode, 0, reason: res.stderr.toString());
      expect(
        manifest.readAsStringSync(),
        allOf(
          contains('nostrInfoWhySix\te2e/maestro/utils/openRecorder.yaml'),
          contains('nostrInfoGotIt\te2e/maestro/utils/openRecorder.yaml'),
        ),
      );
    });

    test('extracts a notVisible: scalar', () {
      writeArb({'feedLoading': 'Loading...'});
      writeFlow(
        'asserts/drained.yaml',
        '- extendedWaitUntil:\n'
            '    notVisible: Loading...\n'
            '    timeout: 5000\n',
      );
      writeManifest('# generated below\n');

      final res = run(update: true);

      expect(res.exitCode, 0, reason: res.stderr.toString());
      expect(
        manifest.readAsStringSync(),
        contains('feedLoading\te2e/maestro/asserts/drained.yaml'),
      );
    });

    test('binds copy that contains a colon and no space', () {
      writeArb({'deleteWarningLabel': 'Warning:'});
      writeFlow('asserts/delete.yaml', '- assertVisible: "Warning:"\n');
      writeManifest('# generated below\n');

      final res = run(update: true);

      expect(res.exitCode, 0, reason: res.stderr.toString());
      expect(
        manifest.readAsStringSync(),
        contains('deleteWarningLabel\te2e/maestro/asserts/delete.yaml'),
      );
    });

    test('fails when ARB copy is shortened under a bound flow', () {
      writeArb({'authConnectSignerApp': 'Connect with a signer'});
      writeFlow(
        'asserts/signIn.yaml',
        '- assertVisible: Connect with a signer app\n',
      );
      writeManifest(
        'authConnectSignerApp\te2e/maestro/asserts/signIn.yaml'
        '\tbound:Connect with a signer app\n',
      );

      final res = run();

      expect(res.exitCode, 1);
      expect(
        res.stderr,
        contains('DRIFT: copy changed under the Maestro suite'),
      );
    });

    test('rendered bindings fail when the flow asserts a longer string', () {
      writeArb({'profileVideoThumbnailLabel': 'Video thumbnail {number}'});
      writeFlow('tests/searchTags.yaml', '- tapOn: Video thumbnail 12\n');
      writeManifest(
        'profileVideoThumbnailLabel\te2e/maestro/tests/searchTags.yaml'
        '\trendered:Video thumbnail 1\n',
      );

      final res = run();

      expect(res.exitCode, 1);
      expect(res.stderr, contains('rendered string'));
    });
  });
}
