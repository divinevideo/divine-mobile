// ABOUTME: Lists missing intl cardinal categories per ARB plural block (#7755).
// ABOUTME: Each gap has its own identity so fixing one cannot hide a new gap.

import 'dart:convert';
import 'dart:io';

import 'package:intl/intl.dart';
// intl exposes supported plural locales only through its generated rule data.
import 'package:intl/src/plural_rules.dart' as rules;
import 'package:yaml/yaml.dart';

/// Probes the pinned runtime rules, without intl's explicit-number overrides.
///
/// This covers the current locales, including million-valued `many` and
/// decimal-only categories. It is a sample audit, not an exhaustive CLDR proof.
Set<String> requiredPluralCategories(String locale) {
  final verified = Intl.verifiedLocale(
    Intl.canonicalizedLocale(locale),
    rules.localeHasPluralRules,
    onFailure: (value) =>
        throw FormatException('Unsupported plural locale: $value'),
  );
  final categories = <String>{'other'};
  void probe(num count, {int? precision}) {
    categories.add(
      Intl.pluralLogic<String>(
        count,
        locale: verified,
        precision: precision,
        useExplicitNumberCases: false,
        zero: 'zero',
        one: 'one',
        two: 'two',
        few: 'few',
        many: 'many',
        other: 'other',
      ),
    );
  }

  for (var n = 0; n <= 1000; n++) {
    probe(n);
    probe(n / 10, precision: 1);
    probe(n / 100, precision: 2);
  }
  probe(1000000);
  probe(2000000);
  return categories;
}

/// Returns locale/message/block/category identities, including nested blocks.
List<String> findMissingPluralCategories(
  Map<String, dynamic> arb, {
  required String locale,
  bool useEscaping = false,
}) {
  final required = requiredPluralCategories(locale);
  final gaps = <String>[];
  for (final entry in arb.entries) {
    if (entry.key.startsWith('@') || entry.value is! String) continue;
    final parser = _MessageParser(
      entry.value as String,
      useEscaping: useEscaping,
    );
    try {
      for (final block in parser.parse()) {
        for (final category in required.difference(block.categories)) {
          gaps.add('$locale/${entry.key}/${block.path}/$category');
        }
      }
    } on FormatException catch (error) {
      throw FormatException('$locale/${entry.key}: ${error.message}');
    }
  }
  return gaps..sort();
}

class _PluralBlock {
  _PluralBlock(this.path, this.categories);
  final String path;
  final Set<String> categories;
}

class _MessageParser {
  _MessageParser(this.message, {required this.useEscaping});
  final String message;
  final bool useEscaping;
  int cursor = 0;
  final blocks = <_PluralBlock>[];
  static final _argument = RegExp(r'\s*([a-zA-Z_][a-zA-Z_0-9]*)\s*');
  static final _arm = RegExp(r'\s*(=\d+|[a-zA-Z_][a-zA-Z_0-9]*)\s*\{');

  List<_PluralBlock> parse() {
    _scan('', nested: false);
    return blocks;
  }

  void _scan(String parent, {required bool nested}) {
    final occurrences = <String, int>{};
    while (cursor < message.length) {
      if (useEscaping && message[cursor] == "'") {
        _quoted();
      } else if (message[cursor] == '}') {
        if (!nested) throw const FormatException('Unexpected closing brace');
        cursor++;
        return;
      } else if (message[cursor] == '{') {
        cursor++;
        final name = _token();
        if (_consume('}')) continue;
        if (!_consume(',')) throw const FormatException('Invalid ICU argument');
        final type = _token();
        if ((type != 'plural' && type != 'select') || !_consume(',')) {
          throw FormatException('Unsupported ICU selector: $type');
        }
        final occurrence = (occurrences[name] ?? 0) + 1;
        occurrences[name] = occurrence;
        final path = '${parent.isEmpty ? '' : '$parent/'}$name:$occurrence';
        final categories = <String>{};
        if (type == 'plural') blocks.add(_PluralBlock(path, categories));
        var hasOther = false;
        while (!_consume('}')) {
          final match = _arm.matchAsPrefix(message, cursor);
          if (match == null) {
            throw const FormatException('Invalid ICU arm');
          }
          final arm = match.group(1)!;
          var branch = arm;
          cursor = match.end;
          if (type == 'plural') {
            final category = switch (arm) {
              '=0' => 'zero',
              '=1' => 'one',
              '=2' => 'two',
              _ => arm,
            };
            branch = category;
            if (!const {
              'zero',
              'one',
              'two',
              'few',
              'many',
              'other',
            }.contains(category)) {
              throw FormatException('Unsupported plural category: $arm');
            }
            if (!categories.add(category)) {
              throw FormatException('Duplicate plural category: $category');
            }
          }
          hasOther = hasOther || arm == 'other';
          _scan('$path/$branch', nested: true);
        }
        if (!hasOther) {
          throw const FormatException('ICU selector requires other');
        }
      } else {
        cursor++;
      }
    }
    if (nested) throw const FormatException('Unclosed ICU arm');
  }

  String _token() {
    final match = _argument.matchAsPrefix(message, cursor);
    if (match == null) throw const FormatException('Invalid ICU token');
    cursor = match.end;
    return match.group(1)!;
  }

  bool _consume(String token) {
    while (cursor < message.length && message[cursor].trim().isEmpty) {
      cursor++;
    }
    if (!message.startsWith(token, cursor)) return false;
    cursor += token.length;
    return true;
  }

  void _quoted() {
    cursor++;
    if (message.startsWith("'", cursor)) {
      cursor++;
      return;
    }
    while (cursor < message.length) {
      if (message[cursor++] != "'") continue;
      if (message.startsWith("'", cursor)) {
        cursor++;
      } else {
        return;
      }
    }
    throw const FormatException('Unclosed ICU quote');
  }
}

void main(List<String> args) {
  try {
    final directory = Directory(args.isEmpty ? 'lib/l10n' : args.single);
    final config = loadYaml(File('l10n.yaml').readAsStringSync()) as YamlMap;
    final useEscaping = config['use-escaping'] == true;
    final files =
        directory
            .listSync()
            .whereType<File>()
            .where(
              (file) =>
                  RegExp(r'app_[^/]+\.arb$')
                      .hasMatch(file.uri.pathSegments.last),
            )
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    if (files.isEmpty) throw const FormatException('No app_*.arb files found');
    final gaps = <String>[];
    for (final file in files) {
      final locale = RegExp(r'app_(.+)\.arb$')
          .firstMatch(file.uri.pathSegments.last)!
          .group(1)!;
      final arb = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      if (arb['@@locale'] != null &&
          Intl.canonicalizedLocale(arb['@@locale'] as String) !=
              Intl.canonicalizedLocale(locale)) {
        throw FormatException('Locale metadata disagrees with ${file.path}');
      }
      gaps.addAll(
        findMissingPluralCategories(
          arb,
          locale: locale,
          useEscaping: useEscaping,
        ),
      );
    }
    gaps.sort();
    gaps.forEach(stdout.writeln);
  } on Object catch (error) {
    stderr.writeln('plural_category_detector: $error');
    exitCode = 2;
  }
}
