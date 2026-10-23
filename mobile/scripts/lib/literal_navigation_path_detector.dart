// ABOUTME: Finds navigation calls in app Dart code that pass a literal path.
// ABOUTME: Backs the zero-tolerance guard that keeps locations on RoutePaths.

import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

/// Calls whose first positional argument is a location: go_router's own, and
/// the app helpers that forward theirs to it.
const navigationMethods = {
  'go',
  'push',
  'pushReplacement',
  'replace',
  'pushWithVideoPause',
  'pushDetached',
  '_push',
};

class LiteralNavigationPathSite {
  const LiteralNavigationPathSite({
    required this.line,
    required this.method,
    required this.location,
  });

  final int line;
  final String method;

  /// The location argument as written, quotes included.
  final String location;
}

List<LiteralNavigationPathSite> findLiteralNavigationPathsInSource(
  String source,
) {
  // Deliberately not wrapped in a try/catch: source this cannot parse must not
  // come back as zero sites, because zero is the whole claim this guard makes.
  // `main` names the file and exits 2 instead.
  final parsed = parseString(
    content: source,
    featureSet: FeatureSet.latestLanguageVersion(),
    throwIfDiagnostics: false,
  );

  final visitor = _NavigationVisitor(parsed.lineInfo);
  parsed.unit.accept(visitor);
  return visitor.sites;
}

class _NavigationVisitor extends RecursiveAstVisitor<void> {
  _NavigationVisitor(this._lineInfo);

  final LineInfo _lineInfo;
  final List<LiteralNavigationPathSite> sites = [];

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final method = node.methodName.name;
    final location = switch (method) {
      'safePop' => _namedArgument(node.argumentList, 'fallback'),
      _ when navigationMethods.contains(method) => _firstPositional(
        node.argumentList,
      ),
      _ => null,
    };
    if (location != null && _isLiteralPath(location)) {
      sites.add(
        LiteralNavigationPathSite(
          line: _lineInfo.getLocation(node.offset).lineNumber,
          method: method,
          location: location.toSource(),
        ),
      );
    }
    super.visitMethodInvocation(node);
  }
}

Expression? _namedArgument(ArgumentList arguments, String name) {
  for (final argument in arguments.arguments) {
    if (argument is NamedExpression && argument.name.label.name == name) {
      return argument.expression;
    }
  }
  return null;
}

Expression? _firstPositional(ArgumentList arguments) {
  for (final argument in arguments.arguments) {
    if (argument is! NamedExpression) return argument;
  }
  return null;
}

/// Whether [expression] is a string that starts with `/` as written, so the
/// location cannot follow its route when the route changes.
bool _isLiteralPath(Expression expression) {
  return switch (expression) {
    SimpleStringLiteral(:final value) => value.startsWith('/'),
    StringInterpolation(:final firstString) => firstString.value.startsWith(
      '/',
    ),
    AdjacentStrings(:final strings) => _isLiteralPath(strings.first),
    ParenthesizedExpression(:final expression) => _isLiteralPath(expression),
    BinaryExpression(:final operator, :final leftOperand)
        when operator.lexeme == '+' =>
      _isLiteralPath(leftOperand),
    _ => false,
  };
}

bool shouldScanNavigationFile(String path) {
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
      stderr.writeln('literal_navigation_path_detector: no such dir: $scanDir');
      exit(2);
    }
    final files =
        directory
            .listSync(recursive: true, followLinks: false)
            .whereType<File>()
            .where((file) => shouldScanNavigationFile(file.path))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));

    for (final file in files) {
      var relative = file.path;
      if (pathPrefix.isNotEmpty && relative.startsWith(pathPrefix)) {
        relative = relative.substring(pathPrefix.length);
      }
      relative = relative.replaceFirst(RegExp('^/'), '');
      final List<LiteralNavigationPathSite> found;
      try {
        found = findLiteralNavigationPathsInSource(file.readAsStringSync());
      } on Object catch (error) {
        // Never let an unreadable file look like a clean one.
        stderr.writeln('literal_navigation_path_detector: $relative: $error');
        exit(2);
      }
      for (final site in found) {
        details.add('$relative:${site.line}  ${site.method}(${site.location})');
      }
    }
  }

  details.sort();
  if (detail || details.isNotEmpty) details.forEach(stdout.writeln);
  if (details.isNotEmpty) exitCode = 1;
}

Never _usage() {
  stderr.writeln(
    'usage: literal_navigation_path_detector.dart <scan-dir>... '
    '[--path-prefix <dir>] [--detail]',
  );
  exit(2);
}
