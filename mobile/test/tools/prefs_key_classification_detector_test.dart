// ABOUTME: Pins prefs_key_classification_detector's classification rules
// ABOUTME: so the #8314 guard cannot silently stop detecting a leak
//
// The detector is exercised through its CLI rather than imported, so these
// tests pin the contract CI actually invokes, argument handling included.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Runs the detector over a throwaway package tree and returns the keys it
/// reports as unclassified.
Future<List<String>> runDetector(Directory root) async {
  final detector = File(
    'scripts/lib/prefs_key_classification_detector.dart',
  ).absolute.path;
  final result = await Process.run('dart', [
    'run',
    detector,
    root.path,
  ], workingDirectory: Directory.current.path);
  if (result.exitCode != 0) {
    fail('detector failed: ${result.stderr}');
  }
  return (result.stdout as String)
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
}

void main() {
  group('prefs key classification detector', () {
    late Directory root;

    setUp(() {
      root = Directory.systemTemp.createTempSync('prefs_key_detector_');
    });

    tearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });

    void write(String name, String source) {
      File('${root.path}${Platform.pathSeparator}$name')
        ..createSync(recursive: true)
        ..writeAsStringSync(source);
    }

    /// A cleanup service whose sweep list is composed the way the real one is.
    void writeCleanupService({String entries = '', String prefixes = ''}) {
      write('user_data_cleanup_service.dart', '''
class UserDataCleanupService {
  static const List<String> userSpecificKeys = [$entries];
  static const List<String> ownerScopedLegacyKeys = [];
  static const List<String> identityChangePrefixes = [$prefixes];
  static const String legacyDraftOwnerKey = 'vine_drafts_owner_pubkey_hex';
}
''');
    }

    test('reports a stored key that no cleanup path clears', () async {
      writeCleanupService();
      write('leaky_service.dart', '''
class LeakyService {
  static const String key = 'leaky_key';
  Future<void> save(dynamic prefs) => prefs.setString(key, 'v');
}
''');

      expect(await runDetector(root), contains('leaky_key'));
    });

    test(
      'a key the sweep references through its constant is classified',
      () async {
        writeCleanupService(entries: 'SweptService.key');
        write('swept_service.dart', '''
class SweptService {
  static const String key = 'swept_key';
  Future<void> save(dynamic prefs) => prefs.setString(key, 'v');
}
''');

        expect(await runDetector(root), isNot(contains('swept_key')));
      },
    );

    test('a deviceScopedPrefsKeys declaration classifies a key', () async {
      writeCleanupService();
      write('device_service.dart', '''
class DeviceService {
  static const String key = 'device_key';
  static const List<String> deviceScopedPrefsKeys = [key];
  Future<void> save(dynamic prefs) => prefs.setString(key, 'v');
}
''');

      expect(await runDetector(root), isNot(contains('device_key')));
    });

    test('same-named constants resolve within their declaring class', () async {
      writeCleanupService();
      write('a_device_service.dart', '''
class DeviceService {
  static const String prefsKey = 'device_key';
  Future<void> save(dynamic prefs) => prefs.setString(prefsKey, 'v');
}
''');
      write('swept_service.dart', '''
class SweptService {
  static const String prefsKey = 'swept_key';
  Future<void> save(dynamic prefs) => prefs.setString(prefsKey, 'v');
}
''');

      expect(await runDetector(root), containsAll(['device_key', 'swept_key']));
    });

    test('multiple device-scoped declarations are additive', () async {
      writeCleanupService();
      write('a_device_service.dart', '''
class FirstDeviceService {
  static const String firstKey = 'first_device_key';
  static const List<String> deviceScopedPrefsKeys = [firstKey];
  Future<void> save(dynamic prefs) => prefs.setString(firstKey, 'v');
}
''');
      write('b_device_service.dart', '''
class SecondDeviceService {
  static const String secondKey = 'second_device_key';
  static const List<String> deviceScopedPrefsKeys = [secondKey];
  Future<void> save(dynamic prefs) => prefs.setString(secondKey, 'v');
}
''');

      expect(await runDetector(root), isEmpty);
    });

    test(
      'an interpolated key is not reported, because it embeds its owner',
      () async {
        writeCleanupService();
        write('scoped_service.dart', r'''
class ScopedService {
  Future<void> save(dynamic prefs, String pubkey) =>
      prefs.setString('sounds_$pubkey', 'v');
}
''');

        expect(await runDetector(root), isEmpty);
      },
    );

    test('a prefix-swept key is not reported', () async {
      writeCleanupService(prefixes: "'following_list_'");
      write('follow_service.dart', '''
class FollowService {
  static const String key = 'following_list_abc';
  Future<void> save(dynamic prefs) => prefs.setString(key, 'v');
}
''');

      expect(await runDetector(root), isNot(contains('following_list_abc')));
    });

    test(
      'a key named only in a comment, dartdoc or log string is not a store',
      () async {
        // This is why the detector is an AST and not a grep. All three of these
        // match a text search for the key and none of them stores anything.
        writeCleanupService();
        write('mentions_only.dart', '''
/// Mentions [ghost_key] in dartdoc.
class MentionsOnly {
  // TODO: store ghost_key one day
  Future<void> log(dynamic logger) => logger.info('ghost_key was not written');
}
''');

        expect(await runDetector(root), isEmpty);
      },
    );

    test('a spread of a list constant contributes its entries', () async {
      // `...TermsAcceptanceKeys.all` is how the real sweep clears the two
      // acceptance keys; dropping the spread would report both as unswept.
      writeCleanupService(entries: '...AcceptanceKeys.all');
      write('acceptance_keys.dart', '''
abstract final class AcceptanceKeys {
  static const String first = 'accept_first';
  static const String second = 'accept_second';
  static const List<String> all = [first, second];
}
''');
      write('acceptance_writer.dart', '''
class AcceptanceWriter {
  Future<void> save(dynamic prefs) async {
    await prefs.setBool(AcceptanceKeys.first, true);
    await prefs.setString(AcceptanceKeys.second, 'now');
  }
}
''');

      expect(await runDetector(root), isEmpty);
    });

    test('a read-only key is reported, not just a written one', () async {
      // The #6985 leak surfaced through a read: the value was applied to the
      // incoming account's feed by a getStringList in a different method from
      // the write.
      writeCleanupService();
      write('reader_service.dart', '''
class ReaderService {
  static const String key = 'read_only_key';
  Future<void> load(dynamic prefs) async => prefs.getStringList(key);
}
''');

      expect(await runDetector(root), contains('read_only_key'));
    });
  });
}
