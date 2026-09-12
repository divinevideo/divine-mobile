// ABOUTME: Tests for the l10n-delegate detector and its ceiling ratchet
// ABOUTME: (scripts/lib/l10n_delegate_detector.dart, #3613).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ignore: avoid_relative_lib_imports, scripts are outside lib/ and not importable through package:openvine.
import '../../scripts/lib/l10n_delegate_detector.dart';

/// Pins the detector semantics behind `check_l10n_delegates_ceiling.sh`.
///
/// Issue #3613 was filed off a grep, and the grep was wrong in both directions:
/// it counted `testMaterialApp` (whose name merely contains the substring
/// `MaterialApp`, and which does register the delegates), and it could not see
/// an unconfigured construction inside a file that mentioned
/// `localizationsDelegates` somewhere else. A detector that repeats either
/// mistake is worse than none — it would freeze a baseline of 31 non-problems
/// while letting real ones through.
void main() {
  group('l10n_delegate_detector', () {
    late Directory tmp;

    List<DelegatelessSite> scan(String source) {
      File('${tmp.path}/test/subject_test.dart').writeAsStringSync(source);
      return findDelegatelessSites(
        Directory('${tmp.path}/test'),
        pathPrefix: tmp.path,
      );
    }

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('l10n_delegate_test');
      Directory('${tmp.path}/test').createSync(recursive: true);
    });

    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    test('counts an unprefixed MaterialApp with no delegates', () {
      // The shape that a syntactic parse sees as a MethodInvocation rather than
      // an InstanceCreationExpression. Missing this made the detector report 30
      // of 157 real sites.
      final sites = scan('''
void main() {
  pumpWidget(
    MaterialApp(home: Foo()),
  );
}
''');

      expect(sites, hasLength(1));
      expect(sites.single.widget, 'MaterialApp');
      expect(sites.single.path, 'test/subject_test.dart');
      expect(sites.single.line, 3);
    });

    test('counts a const MaterialApp with no delegates', () {
      final sites = scan('''
void main() {
  pumpWidget(const MaterialApp(home: Foo()));
}
''');

      expect(sites, hasLength(1));
      expect(sites.single.line, 2);
    });

    test('does not count a MaterialApp that registers the delegates', () {
      final sites = scan('''
void main() {
  pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Foo(),
    ),
  );
}
''');

      expect(sites, isEmpty);
    });

    test('does not count a MaterialApp using appLocalizationsDelegates', () {
      final sites = scan('''
void main() {
  pumpWidget(
    MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Foo(),
    ),
  );
}
''');

      expect(sites, isEmpty);
    });

    test('counts a MaterialApp with delegates that omit AppLocalizations', () {
      final sites = scan('''
void main() {
  pumpWidget(
    MaterialApp(
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: Foo(),
    ),
  );
}
''');

      expect(sites, hasLength(1));
      expect(sites.single.line, 3);
    });

    test('counts a MaterialApp with an empty delegate list', () {
      final sites = scan('''
void main() {
  pumpWidget(
    MaterialApp(
      localizationsDelegates: const [],
      home: Foo(),
    ),
  );
}
''');

      expect(sites, hasLength(1));
      expect(sites.single.line, 3);
    });

    test('does not count testMaterialApp — the #3613 false positive', () {
      // 31 of the 39 files the issue named were only ever this.
      final sites = scan('''
void main() {
  pumpWidget(testMaterialApp(home: Foo()));
}
''');

      expect(sites, isEmpty);
    });

    test('does not count an identifier that merely ends in MaterialApp', () {
      final sites = scan('''
void main() {
  pumpWidget(MyMaterialApp(home: Foo()));
  pumpWidget(wrapInMaterialApp(Foo()));
}
''');

      expect(sites, isEmpty);
    });

    test('counts the unconfigured one in a file that also has a good one', () {
      // A file-level grep sees `localizationsDelegates` here and calls the file
      // clean, hiding the second construction entirely.
      final sites = scan('''
void main() {
  pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Foo(),
    ),
  );
  pumpWidget(
    MaterialApp(home: Bar()),
  );
}
''');

      expect(sites, hasLength(1));
      expect(sites.single.line, 9);
    });

    test('ignores the identifier inside comments and string literals', () {
      final sites = scan('''
// MaterialApp(home: Foo()) in a comment is not a construction.
/// Neither is MaterialApp( in a doc comment.
void main() {
  final s = 'MaterialApp(home: Foo())';
  print(s);
}
''');

      expect(sites, isEmpty);
    });

    test('counts CupertinoApp and WidgetsApp too', () {
      // Each owns its own Localizations scope, so each can break context.l10n
      // for its subtree independently of any ancestor.
      final sites = scan('''
void main() {
  pumpWidget(CupertinoApp(home: Foo()));
  pumpWidget(WidgetsApp(home: Bar()));
}
''');

      expect(sites.map((s) => s.widget), ['CupertinoApp', 'WidgetsApp']);
    });

    test('counts MaterialApp.router with no delegates', () {
      final sites = scan('''
void main() {
  pumpWidget(MaterialApp.router(routerConfig: router));
}
''');

      expect(sites, hasLength(1));
      expect(sites.single.widget, 'MaterialApp');
    });

    test('counts import-prefixed MaterialApp with no delegates', () {
      final sites = scan('''
import 'package:material_ui/material_ui.dart' as material;

void main() {
  pumpWidget(material.MaterialApp(home: Foo()));
}
''');

      expect(sites, hasLength(1));
      expect(sites.single.widget, 'MaterialApp');
      expect(sites.single.line, 4);
    });

    test('counts import-prefixed MaterialApp.router with no delegates', () {
      final sites = scan('''
import 'package:material_ui/material_ui.dart' as material;

void main() {
  pumpWidget(material.MaterialApp.router(routerConfig: router));
}
''');

      expect(sites, hasLength(1));
      expect(sites.single.widget, 'MaterialApp');
      expect(sites.single.line, 4);
    });

    test('does not count MaterialApp.router that registers delegates', () {
      final sites = scan('''
void main() {
  pumpWidget(
    MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: router,
    ),
  );
}
''');

      expect(sites, isEmpty);
    });

    test('counts a nested MaterialApp inside a configured outer one', () {
      final sites = scan('''
void main() {
  pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: MaterialApp(home: Foo()),
    ),
  );
}
''');

      expect(sites, hasLength(1));
      expect(sites.single.line, 5);
    });
  });
}
