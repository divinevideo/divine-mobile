// ABOUTME: Pins that no app analyzer config suppresses the two future lints.
// ABOUTME: Replaces the nested-config check the retired #9118 ratchet ran.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

const _futureLints = ['discarded_futures', 'unawaited_futures'];

/// The app's root config plus every nested one the analyzer applies to an
/// analyzed tree, as paths relative to `mobile/`.
List<String> _appAnalyzerConfigs() => [
  'analysis_options.yaml',
  for (final tree in ['lib', 'test', 'integration_test', 'tools'])
    if (Directory(tree).existsSync())
      ...Directory(tree)
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => p.basename(file.path) == 'analysis_options.yaml')
          .map((file) => p.normalize(file.path)),
];

/// Every way [config] turns off one of [_futureLints].
List<String> _suppressedFutureLints(String config) {
  final yaml = loadYaml(config);
  final analyzer = yaml is YamlMap ? yaml['analyzer'] : null;
  final errors = analyzer is YamlMap ? analyzer['errors'] : null;
  final linter = yaml is YamlMap ? yaml['linter'] : null;
  final rules = linter is YamlMap ? linter['rules'] : null;
  return [
    for (final lint in _futureLints) ...[
      if (errors is YamlMap && errors[lint] == 'ignore')
        'analyzer.errors.$lint',
      if (rules is YamlMap && rules[lint] == false) 'linter.rules.$lint',
    ],
  ];
}

void main() {
  group('app analyzer configs', () {
    test('never suppress discarded_futures or unawaited_futures', () {
      final configs = _appAnalyzerConfigs();
      expect(
        configs,
        containsAll(['analysis_options.yaml', 'test/analysis_options.yaml']),
      );

      final offenders = {
        for (final path in configs)
          if (_suppressedFutureLints(File(path).readAsStringSync())
              case final suppressed when suppressed.isNotEmpty)
            path: suppressed,
      };

      expect(offenders, isEmpty);
    });
  });

  group('_suppressedFutureLints', () {
    test('reports a rule ignored under analyzer errors', () {
      expect(
        _suppressedFutureLints('''
analyzer:
  errors:
    discarded_futures: ignore
'''),
        equals(['analyzer.errors.discarded_futures']),
      );
    });

    test('reports a rule switched off under linter rules', () {
      expect(
        _suppressedFutureLints('''
linter:
  rules:
    unawaited_futures: false
'''),
        equals(['linter.rules.unawaited_futures']),
      );
    });

    test('does not report a rule raised to a stricter severity', () {
      expect(
        _suppressedFutureLints('''
analyzer:
  errors:
    discarded_futures: error
linter:
  rules:
    unawaited_futures: true
'''),
        isEmpty,
      );
    });
  });
}
