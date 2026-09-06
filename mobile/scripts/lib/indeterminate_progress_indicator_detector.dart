// ABOUTME: Finds raw indeterminate Material progress indicators in production Dart.
// ABOUTME: Backs the zero-tolerance reduced-motion guard for UI quiescence.

import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

const _rawIndicators = {'CircularProgressIndicator', 'LinearProgressIndicator'};

class IndeterminateProgressIndicatorSite {
  const IndeterminateProgressIndicatorSite({
    required this.line,
    required this.widget,
  });

  final int line;
  final String widget;
}

List<IndeterminateProgressIndicatorSite>
findIndeterminateProgressIndicatorsInSource(String source) {
  final ParseStringResult parsed;
  try {
    parsed = parseString(
      content: source,
      featureSet: FeatureSet.latestLanguageVersion(),
      throwIfDiagnostics: false,
    );
  } on Object {
    return const [];
  }

  final visitor = _IndicatorVisitor(parsed.lineInfo);
  parsed.unit.accept(visitor);
  return visitor.sites;
}

class _IndicatorVisitor extends RecursiveAstVisitor<void> {
  _IndicatorVisitor(this._lineInfo);

  final LineInfo _lineInfo;
  final List<IndeterminateProgressIndicatorSite> sites = [];

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    _check(
      node.constructorName.type.name.lexeme,
      node.argumentList,
      node.offset,
    );
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final widget = node.methodName.name == 'adaptive'
        ? _lastIdentifierName(node.target) ?? node.methodName.name
        : node.methodName.name;
    _check(widget, node.argumentList, node.offset);
    super.visitMethodInvocation(node);
  }

  void _check(String widget, ArgumentList arguments, int offset) {
    if (!_rawIndicators.contains(widget)) return;

    Expression? value;
    var hasValue = false;
    for (final argument in arguments.arguments) {
      if (argument is NamedExpression && argument.name.label.name == 'value') {
        hasValue = true;
        value = argument.expression;
        break;
      }
    }
    if (hasValue && value is! NullLiteral) return;

    sites.add(
      IndeterminateProgressIndicatorSite(
        line: _lineInfo.getLocation(offset).lineNumber,
        widget: widget,
      ),
    );
  }
}

bool shouldScanProgressIndicatorFile(String path) {
  final normalized = path.replaceAll(r'\', '/');
  final segments = normalized
      .split('/')
      .where((segment) => segment.isNotEmpty)
      .toSet();
  if (!normalized.endsWith('.dart')) return false;
  if (segments.contains('test') ||
      segments.contains('integration_test') ||
      normalized.contains('/.dart_tool/') ||
      normalized.contains('/build/')) {
    return false;
  }
  return !normalized.endsWith('.g.dart') &&
      !normalized.endsWith('.freezed.dart') &&
      !normalized.endsWith('.mocks.dart');
}

String? _lastIdentifierName(Expression? expression) {
  return switch (expression) {
    SimpleIdentifier(:final name) => name,
    PrefixedIdentifier(:final identifier) => identifier.name,
    PropertyAccess(:final propertyName) => propertyName.name,
    _ => null,
  };
}

void main(List<String> args) {
  final scanDirs = <String>[];
  var pathPrefix = '';
  var detail = false;

  for (var index = 0; index < args.length; index++) {
    switch (args[index]) {
      case '--path-prefix':
        if (++index >= args.length) _usage();
        pathPrefix = args[index];
      case '--detail':
        detail = true;
      default:
        if (args[index].startsWith('--')) _usage();
        scanDirs.add(args[index]);
    }
  }
  if (scanDirs.isEmpty) _usage();

  final details = <String>[];
  for (final scanDir in scanDirs) {
    final directory = Directory(scanDir);
    if (!directory.existsSync()) {
      stderr.writeln(
        'indeterminate_progress_indicator_detector: no such dir: $scanDir',
      );
      exit(2);
    }
    final files =
        directory
            .listSync(recursive: true, followLinks: false)
            .whereType<File>()
            .where((file) => shouldScanProgressIndicatorFile(file.path))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));

    for (final file in files) {
      var relative = file.path;
      if (pathPrefix.isNotEmpty && relative.startsWith(pathPrefix)) {
        relative = relative.substring(pathPrefix.length);
      }
      relative = relative.replaceFirst(RegExp('^/'), '');
      for (final site in findIndeterminateProgressIndicatorsInSource(
        file.readAsStringSync(),
      )) {
        details.add('$relative:${site.line}  ${site.widget}');
      }
    }
  }

  details.sort();
  if (detail || details.isNotEmpty) details.forEach(stdout.writeln);
  if (details.isNotEmpty) exitCode = 1;
}

Never _usage() {
  stderr.writeln(
    'usage: indeterminate_progress_indicator_detector.dart <scan-dir>... '
    '[--path-prefix <dir>] [--detail]',
  );
  exit(2);
}
