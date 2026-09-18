// ABOUTME: Finds perpetual animations that never consult reduced motion.
// ABOUTME: Covers skeleton shimmer and repeating AnimationControllers.

import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

import 'reduced_motion_checks.dart';

/// The shared helper every `Skeletonizer` must take its effect from.
const _skeletonEffectHelper = 'vineSkeletonEffectOf';

/// A perpetual animation with no reduced-motion gate.
class ReducedMotionGatingSite {
  const ReducedMotionGatingSite({required this.line, required this.kind});

  final int line;

  /// `skeletonizer` or `repeat`.
  final String kind;
}

/// Finds ungated perpetual animations in [source].
///
/// Throws if [source] cannot be parsed. A guard that answers "zero" because it
/// could not read a file is worse than one that fails loudly, so the caller
/// reports the path and exits rather than swallowing it.
List<ReducedMotionGatingSite> findReducedMotionGatingViolations(String source) {
  final parsed = parseString(
    content: source,
    featureSet: FeatureSet.latestLanguageVersion(),
    throwIfDiagnostics: false,
  );
  final visitor = _GatingVisitor(parsed.lineInfo);
  parsed.unit.accept(visitor);
  return visitor.sites..sort((a, b) => a.line.compareTo(b.line));
}

class _GatingVisitor extends RecursiveAstVisitor<void> {
  _GatingVisitor(this._lineInfo);

  final LineInfo _lineInfo;
  final List<ReducedMotionGatingSite> sites = [];

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    // Unresolved, `Skeletonizer.zone()` parses as a prefixed type named
    // `zone`, because the leading identifier is equally a class or an import
    // prefix -- the same trap the indicator guard documents for `.adaptive`.
    final type = node.constructorName.type;
    _checkSkeletonizer(type.name.lexeme, node.argumentList, node.offset);
    final importPrefix = type.importPrefix?.name.lexeme;
    if (importPrefix != null) {
      _checkSkeletonizer(importPrefix, node.argumentList, node.offset);
    }
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'repeat' && !_isGatedByReducedMotion(node)) {
      sites.add(_site(node.offset, 'repeat'));
    }
    // Without `const` or `new` in unresolved source, `Skeletonizer(...)` is a
    // method invocation rather than an instance creation, and `.zone()` puts
    // the class name on the target. Checking only the creation form is how a
    // Skeletonizer guard silently passes every call site in the app.
    _checkSkeletonizer(node.methodName.name, node.argumentList, node.offset);
    final target = _lastIdentifierName(node.target);
    if (target != null) {
      _checkSkeletonizer(target, node.argumentList, node.offset);
    }
    super.visitMethodInvocation(node);
  }

  void _checkSkeletonizer(String name, ArgumentList arguments, int offset) {
    if (name != 'Skeletonizer') return;
    for (final argument in arguments.arguments) {
      if (argument is! NamedExpression) continue;
      if (argument.name.label.name != 'effect') continue;
      if (_isSkeletonEffectHelper(argument.expression)) return;
      break;
    }
    sites.add(_site(offset, 'skeletonizer'));
  }

  ReducedMotionGatingSite _site(int offset, String kind) =>
      ReducedMotionGatingSite(
        line: _lineInfo.getLocation(offset).lineNumber,
        kind: kind,
      );
}

/// Whether [node] sits on a branch that only runs when motion is allowed.
///
/// Three shapes count, and the codebase writes all three: the else branch of
/// `if (reduceMotion)`, the then branch of `if (!reduceMotion)` (including
/// compound conditions such as `isPlaying && !reduceMotion`), and any
/// statement after an `if (reduceMotion) { ...; return; }` early exit.
///
/// The walk stops at the enclosing function body: a gate in some other
/// function cannot govern this call, and a closure is its own body.
bool _isGatedByReducedMotion(AstNode node) {
  AstNode? child = node;
  var current = node.parent;
  while (current != null) {
    if (current is IfStatement) {
      final polarity = reducedMotionPolarity(current.expression);
      if (polarity != null) {
        if (identical(child, current.thenStatement) && !polarity) return true;
        if (identical(child, current.elseStatement) && polarity) return true;
      }
    }
    if (current is Block &&
        child is Statement &&
        _hasPrecedingReducedMotionExit(current, child)) {
      return true;
    }
    if (current is FunctionBody) return false;
    child = current;
    current = current.parent;
  }
  return false;
}

/// Whether a statement before [child] returns early when motion is reduced.
bool _hasPrecedingReducedMotionExit(Block block, Statement child) {
  for (final statement in block.statements) {
    if (identical(statement, child)) return false;
    if (statement is! IfStatement) continue;
    if (reducedMotionPolarity(statement.expression) != true) continue;
    if (_alwaysExits(statement.thenStatement)) return true;
  }
  return false;
}

bool _alwaysExits(Statement statement) {
  if (statement is ReturnStatement) return true;
  if (statement is Block && statement.statements.isNotEmpty) {
    return _alwaysExits(statement.statements.last);
  }
  return false;
}

String? _lastIdentifierName(Expression? expression) {
  return switch (expression) {
    SimpleIdentifier(:final name) => name,
    PrefixedIdentifier(:final identifier) => identifier.name,
    PropertyAccess(:final propertyName) => propertyName.name,
    _ => null,
  };
}

/// Whether [expression] is the shared helper call itself, not merely a mention.
bool _isSkeletonEffectHelper(Expression expression) {
  var current = expression;
  while (current is ParenthesizedExpression) {
    current = current.expression;
  }
  return current is MethodInvocation &&
      current.methodName.name == _skeletonEffectHelper;
}

/// Whether [path] is production Dart this guard should read.
bool shouldScanReducedMotionFile(String path) {
  final normalized = path.replaceAll(r'\', '/');
  if (!normalized.endsWith('.dart')) return false;
  final segments = normalized
      .split('/')
      .where((segment) => segment.isNotEmpty)
      .toSet();
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
      stderr.writeln('reduced_motion_gating_detector: no such dir: $scanDir');
      exit(2);
    }
    final files =
        directory
            .listSync(recursive: true, followLinks: false)
            .whereType<File>()
            .where((file) => shouldScanReducedMotionFile(file.path))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));

    for (final file in files) {
      var relative = file.path;
      if (pathPrefix.isNotEmpty && relative.startsWith(pathPrefix)) {
        relative = relative.substring(pathPrefix.length);
      }
      relative = relative.replaceFirst(RegExp('^/'), '');

      final List<ReducedMotionGatingSite> found;
      try {
        found = findReducedMotionGatingViolations(file.readAsStringSync());
      } on Object catch (error) {
        // Never let an unreadable file look like a clean one.
        stderr.writeln('reduced_motion_gating_detector: $relative: $error');
        exit(2);
      }
      for (final site in found) {
        details.add('$relative:${site.line}  ${site.kind}');
      }
    }
  }

  details.sort();
  if (detail || details.isNotEmpty) details.forEach(stdout.writeln);
  if (details.isNotEmpty) exitCode = 1;
}

Never _usage() {
  stderr.writeln(
    'usage: reduced_motion_gating_detector.dart <scan-dir>... '
    '[--path-prefix <dir>] [--detail]',
  );
  exit(2);
}
