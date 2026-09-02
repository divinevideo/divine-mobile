// ABOUTME: Guards ICU plural arms against hardcoding a literal number.
// ABOUTME: A hardcoded digit renders the WRONG count wherever the arm can fire
// ABOUTME: for a value other than that digit (fr/am/pt at n=0, fil at most n).

import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart' as intl;
import 'package:openvine/l10n/generated/app_localizations.dart';

/// Categories that `Intl.pluralLogic` resolves by exact value before consulting
/// the CLDR rule, and the value each one matches.
///
/// `gen-l10n` compiles ARB `=0`/`=1`/`=2` down to the `zero:`/`one:`/`two:`
/// arguments, so the ARB spelling of an arm does not change its behaviour —
/// only which argument it lands in.
const _exactValueArms = <String, String>{
  '=0': '0',
  'zero': '0',
  '=2': '2',
  'two': '2',
};

void main() {
  group('ICU plural arms', () {
    final arbFiles =
        Directory('lib/l10n')
            .listSync()
            .whereType<File>()
            .where((file) => file.path.endsWith('.arb'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));

    test('never hardcode a number in an arm that can fire for other counts', () {
      final offenders = <String>[];

      for (final file in arbFiles) {
        final locale = _localeOf(file);
        // Derived, not hardcoded: ask intl itself which counts reach `one` in
        // this locale. French/Amharic/Portuguese `one` covers {0, 1}; Filipino
        // `one` covers most integers. Anywhere else it is exactly {1}.
        final oneIsExact = _countsSelectingOne(locale).every((n) => n == 1);

        final arb = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        for (final entry in arb.entries) {
          if (entry.key.startsWith('@')) continue;
          final value = entry.value;
          if (value is! String) continue;

          for (final arm in _pluralArms(value)) {
            if (!_armHardcodesUnsafeNumber(arm, oneIsExact: oneIsExact)) {
              continue;
            }
            offenders.add(
              '${file.path} :: ${entry.key} :: ${arm.category}{${arm.text}}',
            );
          }
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'These ICU plural arms hardcode a number but can be selected for a '
            'different count, so they render a false number. Interpolate the '
            'placeholder instead — e.g. one{1 personne} -> one{{count} personne}.\n'
            '${offenders.join('\n')}',
      );
    });

    test(
      'flags a hardcoded digit even when the count placeholder is also present',
      () {
        // Presence of {count} does not make a literal safe: fil one fires for
        // most integers, so one{1 of {count}} still shows a false leading 1.
        expect(
          _armHardcodesUnsafeNumber(
            const _PluralArm('count', 'one', '1 of {count}'),
            oneIsExact: false,
          ),
          isTrue,
        );
        expect(
          _armHardcodesUnsafeNumber(
            const _PluralArm('count', 'one', '{count} personne'),
            oneIsExact: false,
          ),
          isFalse,
        );
        // Exact-one locales may keep a lone literal 1, but not other digits.
        expect(
          _armHardcodesUnsafeNumber(
            const _PluralArm('count', 'one', '1 item'),
            oneIsExact: true,
          ),
          isFalse,
        );
        expect(
          _armHardcodesUnsafeNumber(
            const _PluralArm('count', 'one', '2 items'),
            oneIsExact: true,
          ),
          isTrue,
        );
      },
    );

    test(
      'render the real count in every locale whose `one` is not exactly 1',
      () {
        // Regression pins for the four locales that were shipping wrong numbers.
        // fr/am/pt selected `one` at n=0; fil selects `one` for most integers.
        const cases = <String, List<int>>{
          'fr': [0, 2, 22],
          'am': [0, 2, 22],
          'pt': [0, 2, 22],
          'fil': [0, 2, 5, 22, 100],
        };

        for (final entry in cases.entries) {
          final l10n = lookupAppLocalizations(Locale(entry.key));
          for (final count in entry.value) {
            expect(
              l10n.listVideoCount(count),
              contains('$count'),
              reason:
                  '${entry.key}: listVideoCount($count) must show $count, not a '
                  'hardcoded 1 — got "${l10n.listVideoCount(count)}"',
            );
            expect(
              l10n.notificationsBadgeUnread(count),
              contains('$count'),
              reason:
                  '${entry.key}: notificationsBadgeUnread($count) must show '
                  '$count — got "${l10n.notificationsBadgeUnread(count)}"',
            );
          }
        }
      },
    );
  });
}

String _localeOf(File file) {
  final name = file.uri.pathSegments.last; // app_<locale>.arb
  return name.substring('app_'.length, name.length - '.arb'.length);
}

/// The counts in 0..200 for which [locale] selects the `one` arm, given the
/// common `one` + `other` arm set. Probing the real [intl.Intl.pluralLogic]
/// keeps this test correct when the bundled CLDR data changes.
Iterable<int> _countsSelectingOne(String locale) sync* {
  for (var n = 0; n <= 200; n++) {
    final selected = intl.Intl.pluralLogic<String>(
      n,
      locale: locale,
      one: 'one',
      other: 'other',
    );
    if (selected == 'one') yield n;
  }
}

class _PluralArm {
  const _PluralArm(this.variable, this.category, this.text);

  /// The plural argument the enclosing block switches on, e.g. `count`.
  final String variable;
  final String category;
  final String text;
}

/// Whether [arm] hardcodes a digit that can disagree with the selected count.
///
/// Interpolating `{variable}` alone is safe. A literal digit is only safe when
/// the arm is value-exact (`=0`/`zero`/`=2`/`two`, or `=1`/`one` in a locale
/// whose `one` fires only at n=1) and every digit token matches that value.
/// A mixed arm like `one{1 of {count}}` is unsafe wherever `one` is not exact.
bool _armHardcodesUnsafeNumber(_PluralArm arm, {required bool oneIsExact}) {
  if (!RegExp(r'\d').hasMatch(arm.text)) return false;

  final digits = RegExp(
    r'\d+',
  ).allMatches(arm.text).map((m) => m[0]!).toList();

  final exact = _exactValueArms[arm.category];
  if (exact != null && digits.every((digit) => digit == exact)) {
    return false;
  }
  if ((arm.category == '=1' || arm.category == 'one') &&
      oneIsExact &&
      digits.every((digit) => digit == '1')) {
    return false;
  }
  return true;
}

/// Splits *every* `{name, plural, ...}` block of [value] into its arms.
///
/// One string can carry several blocks — `settingsUnsavedDraftsMessage` has up
/// to four — so stopping at the first would leave the rest unguarded.
Iterable<_PluralArm> _pluralArms(String value) sync* {
  final armHead = RegExp(r'^\s*(=\d+|zero|one|two|few|many|other)\s*\{');

  for (final header in RegExp(
    r'\{\s*(\w+)\s*,\s*plural\s*,',
  ).allMatches(value)) {
    final variable = header.group(1)!;
    final body = value.substring(header.end);
    var cursor = 0;
    while (cursor < body.length) {
      final head = armHead.firstMatch(body.substring(cursor));
      if (head == null) break;

      var index = cursor + head.end;
      final start = index;
      var depth = 1;
      while (index < body.length && depth > 0) {
        if (body[index] == '{') {
          depth++;
        } else if (body[index] == '}') {
          depth--;
        }
        index++;
      }
      yield _PluralArm(
        variable,
        head.group(1)!,
        body.substring(start, index - 1),
      );
      cursor = index;
    }
  }
}
