// ABOUTME: Pins category discovery, nested ICU parsing, and per-gap ratcheting.
// ABOUTME: Prevents fixed gaps from concealing new omissions (#7755).

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ignore: avoid_relative_lib_imports, this CLI script lives outside lib/.
import '../../scripts/lib/plural_category_detector.dart';

void main() {
  group('requiredPluralCategories', () {
    test('uses locale rules without inventing explicit zero or two', () {
      expect(requiredPluralCategories('en'), {'one', 'other'});
      expect(requiredPluralCategories('ar'), {
        'zero',
        'one',
        'two',
        'few',
        'many',
        'other',
      });
      expect(requiredPluralCategories('tr'), {'one', 'other'});
    });

    test('includes million-valued and decimal-only categories', () {
      expect(requiredPluralCategories('fr'), {'one', 'many', 'other'});
      expect(requiredPluralCategories('cs'), {'one', 'few', 'many', 'other'});
    });

    test('normalizes regional locales and rejects unsupported locales', () {
      expect(requiredPluralCategories('pt-PT'), {'one', 'many', 'other'});
      expect(() => requiredPluralCategories('zz'), throwsFormatException);
    });
  });

  group('findMissingPluralCategories', () {
    List<String> gaps(
      String value, {
      String locale = 'en',
      bool escaping = false,
    }) => findMissingPluralCategories(
      {'message': value},
      locale: locale,
      useEscaping: escaping,
    );

    test('treats exact zero, one and two as generated category arguments', () {
      expect(gaps('{n, plural, =1{single} other{{n} things}}'), isEmpty);
      expect(
        gaps(
          '{n, plural, =0{none} =1{single} =2{pair} other{more}}',
          locale: 'ar',
        ),
        [
          'ar/message/n:1/few',
          'ar/message/n:1/many',
        ],
      );
    });

    test('tracks every sibling plural block independently', () {
      expect(gaps('{n, plural, other{x}} {n, plural, other{y}}'), [
        'en/message/n:1/one',
        'en/message/n:2/one',
      ]);
    });

    test(
      'keeps nested block identities stable across exact-number aliases',
      () {
        expect(
          gaps('{n, plural, =1{{m, plural, other{x}}} other{x}}'),
          gaps('{n, plural, one{{m, plural, other{x}}} other{x}}'),
        );
      },
    );

    test('finds plurals inside selects and selects inside plural arms', () {
      expect(
        gaps(
          '{gender, select, male{{n, plural, other{x}}} other{ '
          '{n, plural, one{x} other{{kind, select, other{{m, plural, other{y}}}}}}}}',
        ),
        [
          'en/message/gender:1/male/n:1/one',
          'en/message/gender:1/other/n:1/other/kind:1/other/m:1/one',
        ],
      );
    });

    test(
      'keeps missing categories separate even when their count is equal',
      () {
        final first = gaps(
          '{n, plural, zero{x} one{x} two{x} few{x} many{x} other{x}}',
          locale: 'ar',
        );
        expect(first, isEmpty);
        final noZero = gaps(
          '{n, plural, one{x} two{x} few{x} many{x} other{x}}',
          locale: 'ar',
        );
        final noTwo = gaps(
          '{n, plural, zero{x} one{x} few{x} many{x} other{x}}',
          locale: 'ar',
        );
        expect(noZero, ['ar/message/n:1/zero']);
        expect(noTwo, ['ar/message/n:1/two']);
      },
    );

    test(
      'reports invariant wording rather than guessing grammar exemptions',
      () {
        expect(gaps('{n, plural, =0{Badges} other{Badges ({n})}}'), [
          'en/message/n:1/one',
        ]);
        expect(gaps('Flat text {n}'), isEmpty);
      },
    );

    test('honors opt-in ICU quotes and leaves ordinary apostrophes alone', () {
      expect(gaps("'{n, plural, other{quoted}}'", escaping: true), isEmpty);
      expect(gaps("It's {n, plural, =1{one} other{many}}"), isEmpty);
      expect(gaps("''{n, plural, other{many}}", escaping: true), [
        'en/message/n:1/one',
      ]);
    });

    test('rejects malformed, unsupported and duplicate plural arms', () {
      for (final value in [
        '{n, plural, other{x}',
        '{n, plural, one{x}}',
        '{n, plural, =3{x} other{x}}',
        '{n, plural, one{x} =1{x} other{x}}',
      ]) {
        expect(() => gaps(value), throwsFormatException, reason: value);
      }
    });
  });

  group('plural_category_detector CLI', () {
    late Directory tmp;
    late String script;
    late String packageConfig;

    void writeArb(String locale, Map<String, dynamic> arb) {
      File('${tmp.path}/arb/app_$locale.arb')
          .writeAsStringSync(jsonEncode(arb));
    }

    ProcessResult run() => Process.runSync(
      'dart',
      ['--packages=$packageConfig', script, 'arb'],
      workingDirectory: tmp.path,
    );

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('plural_category_cli_test');
      Directory('${tmp.path}/arb').createSync();
      File('${tmp.path}/l10n.yaml').writeAsStringSync('use-escaping: false\n');
      script = File('scripts/lib/plural_category_detector.dart').absolute.path;
      packageConfig = File('.dart_tool/package_config.json').absolute.path;
    });

    tearDown(() => tmp.deleteSync(recursive: true));

    test('emits sorted gap identities for valid ARB files', () {
      writeArb('en', {'message': '{n, plural, other{things}}'});
      final result = run();
      expect(result.exitCode, 0, reason: result.stderr.toString());
      expect(result.stdout, 'en/message/n:1/one\n');
    });

    test('malformed later input emits no partial gap list', () {
      writeArb('ar', {'message': '{n, plural, other{things}}'});
      writeArb('en', {'message': '{n, plural, other{unclosed}'});
      final result = run();
      expect(result.exitCode, 2);
      expect(result.stdout, isEmpty);
      expect(result.stderr, contains('en/message:'));
    });

    test('rejects an empty directory and mismatched locale metadata', () {
      expect(run().exitCode, 2);
      writeArb('en', {'@@locale': 'ar', 'message': 'text'});
      final result = run();
      expect(result.exitCode, 2);
      expect(result.stderr, contains('Locale metadata disagrees'));
    });
  });

  group('check_plural_category_floor', () {
    late Directory tmp;
    late File current;
    late File baseline;
    late String script;

    ProcessResult run({bool update = false, bool detectorFails = false}) =>
        Process.runSync(
          'bash',
          [script],
          environment: {
            'PATH': '${tmp.path}/bin:${Platform.environment['PATH']}',
            'PLURAL_TEST_CURRENT': current.path,
            'PLURAL_TEST_EXIT': detectorFails ? '2' : '0',
            'PLURAL_CATEGORY_BASELINE_BASE_REF': 'basemain',
            'UPDATE_BASELINE': update ? '1' : '0',
          },
        );

    void write(List<String> gaps) =>
        current.writeAsStringSync('${gaps.join('\n')}\n');

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('plural_category_floor_test');
      for (final path in [
        'bin',
        'mobile/scripts/lib',
        'mobile/scripts/baseline',
      ]) {
        Directory('${tmp.path}/$path').createSync(recursive: true);
      }
      for (final path in [
        'check_plural_category_floor.sh',
        'lib/list_ratchet.sh',
      ]) {
        File('scripts/$path').copySync('${tmp.path}/mobile/scripts/$path');
      }
      script = '${tmp.path}/mobile/scripts/check_plural_category_floor.sh';
      current = File('${tmp.path}/current');
      baseline = File(
        '${tmp.path}/mobile/scripts/baseline/plural_category_gaps.txt',
      );
      final dart = File('${tmp.path}/bin/dart')
        ..writeAsStringSync(
          '#!/usr/bin/env bash\ncat "\$PLURAL_TEST_CURRENT"\nexit "\$PLURAL_TEST_EXIT"\n',
        );
      expect(Process.runSync('chmod', ['+x', dart.path]).exitCode, 0);
      baseline.writeAsStringSync(
        'ar/message/n:1/zero # intentional: probe reason\n',
      );
      write(['ar/message/n:1/zero']);
      for (final args in [
        ['init', '--initial-branch=basemain'],
        ['add', '.'],
        ['commit', '-m', 'seed'],
      ]) {
        final result = Process.runSync('git', [
          '-c',
          'user.name=probe',
          '-c',
          'user.email=probe@example.com',
          '-c',
          'core.hooksPath=/dev/null',
          ...args,
        ], workingDirectory: tmp.path);
        expect(result.exitCode, 0, reason: result.stderr.toString());
      }
    });

    tearDown(() => tmp.deleteSync(recursive: true));

    test('accepts the unchanged baseline', () {
      final result = run();
      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    });

    test('rejects category swaps even after regenerating the baseline', () {
      write(['ar/message/n:1/two']);
      expect(run().exitCode, 1);
      expect(run(update: true).exitCode, 0);
      final result = run();
      expect(result.exitCode, 1);
      expect(result.stdout, contains('baseline GREW'));
    });

    test('requires shrinking fixed gaps and preserves reasons on update', () {
      expect(run(update: true).exitCode, 0);
      expect(
        baseline.readAsStringSync(),
        contains('# intentional: probe reason'),
      );
      write([]);
      expect(run().exitCode, 1);
      expect(run(update: true).exitCode, 0);
      expect(run().exitCode, 0);
    });

    test('detector failure cannot erase the baseline', () {
      final before = baseline.readAsStringSync();
      expect(run(update: true, detectorFails: true).exitCode, isNonZero);
      expect(baseline.readAsStringSync(), before);
    });
  });
}
