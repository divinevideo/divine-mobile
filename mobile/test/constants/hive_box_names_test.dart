// ABOUTME: Ties the Hive wipe policy to the real Hive box-open call sites.
// ABOUTME: A box that skips HiveBoxNames fails here instead of being wiped.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/constants/hive_box_names.dart';

/// `HiveBoxOpener.open<T>(arg`, `.openBox<T>(arg`, and their lazy variants,
/// capturing the first argument. The argument may sit on the next line, so
/// whitespace is skipped.
///
/// The receiver is intentionally broad: app-layer code can use `Hive.openBox`
/// directly, while packages receive injected open-box callbacks because they
/// cannot import app-owned [HiveBoxNames].
final _openBoxCall = RegExp(
  r'''(?:HiveBoxOpener\.open(?:Lazy)?|\.open(?:Lazy)?Box)(?:<[^>]*>)?\(\s*([A-Za-z_$][\w.]*|'[^']*'|"[^"]*")''',
);

/// A `static const`/`const` declaration and its initializer, e.g.
/// `static const String _boxName = HiveBoxNames.hashtagStats;`.
String? _initializerOf(String source, String identifier) => RegExp(
  'const\\s+(?:\\w+\\s+)?$identifier\\s*=\\s*([^;]+);',
).firstMatch(source)?.group(1)?.trim();

/// `static const notifications = 'notifications';` — the `all` set is skipped
/// because its initializer is not a quoted string.
final _boxNameDeclaration = RegExp(
  r'''static\s+const\s+(?:String\s+)?(\w+)\s*=\s*'([^']*)'\s*;''',
);

Iterable<File> _dartSources() sync* {
  for (final root in [Directory('lib'), Directory('packages')]) {
    if (!root.existsSync()) continue;
    for (final entity in root.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.contains('/test/')) continue;
      // This boundary must forward its caller's name into Hive. Its callers
      // remain covered here, and check_direct_hive_opens.sh makes this the
      // only production file allowed to invoke Hive directly (#9053).
      if (entity.path.endsWith('/services/hive_box_opener.dart')) continue;
      yield entity;
    }
  }
}

void main() {
  group(HiveBoxNames, () {
    test('openBox scanner includes injected HiveInterface receivers', () {
      const source = '''
class ProbeB {
  ProbeB(this._hive);
  final HiveInterface _hive;
  Future<Box<dynamic>> open() => _hive.openBox<dynamic>('draft_notes_v1');
}
''';

      expect(_openBoxCall.firstMatch(source)?.group(1), "'draft_notes_v1'");
    });

    test('openBox scanner includes HiveBoxOpener calls', () {
      const source = '''
Future<Box<dynamic>> open() =>
    HiveBoxOpener.open<dynamic>(HiveBoxNames.notifications);
''';

      expect(
        _openBoxCall.firstMatch(source)?.group(1),
        'HiveBoxNames.notifications',
      );
    });

    test('every declared box name is in HiveBoxNames.all', () {
      final source = File(
        'lib/constants/hive_box_names.dart',
      ).readAsStringSync();
      final declared = {
        for (final match in _boxNameDeclaration.allMatches(source))
          match.group(2)!,
      };

      expect(declared, isNotEmpty);
      expect(
        declared,
        unorderedEquals(HiveBoxNames.all),
        reason:
            'HiveBoxNames.all is what CacheRecoveryService classifies as '
            'disposable or durable, and what HiveStorageService migrates out '
            'of the legacy documents directory. A member missing from it is a '
            'box no wipe policy covers and no migration rescues.',
      );
    });

    test('every Hive box open names its box via HiveBoxNames', () {
      final offenders = <String>[];

      for (final file in _dartSources()) {
        final source = file.readAsStringSync();
        for (final call in _openBoxCall.allMatches(source)) {
          final argument = call.group(1)!;
          final resolved = argument.startsWith('HiveBoxNames.')
              ? argument
              : _initializerOf(source, argument);
          if (resolved != null && resolved.startsWith('HiveBoxNames.')) {
            continue;
          }
          offenders.add('${file.path}: Hive box open($argument)');
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'Every Hive box must be named from HiveBoxNames so the cache '
            'wipe policy classifies it. Add the name to HiveBoxNames and to '
            "CacheRecoveryService's disposable or durable set (#6919).",
      );
    });
  });
}
