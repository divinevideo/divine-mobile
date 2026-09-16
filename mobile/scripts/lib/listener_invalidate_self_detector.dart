// ABOUTME: Finds addListener callbacks that rebuild their own Riverpod provider.
// ABOUTME: This prevents listener accumulation and lost version-counter updates.

import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

class ListenerInvalidateSelfSite {
  const ListenerInvalidateSelfSite({required this.line, required this.snippet});

  final int line;
  final String snippet;
}

List<ListenerInvalidateSelfSite> findListenerInvalidateSelfSitesInSource(
  String source,
) {
  final ParseStringResult parsed = parseString(
    content: source,
    featureSet: FeatureSet.latestLanguageVersion(),
    throwIfDiagnostics: false,
  );
  final functions = _SameFileFunctions(parsed.unit);
  final visitor = _ListenerVisitor(parsed.lineInfo, functions);
  parsed.unit.accept(visitor);
  return visitor.sites;
}

class _ListenerVisitor extends RecursiveAstVisitor<void> {
  _ListenerVisitor(this._lineInfo, this._functions);

  final LineInfo _lineInfo;
  final _SameFileFunctions _functions;
  final List<ListenerInvalidateSelfSite> sites = [];

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'addListener' &&
        node.argumentList.arguments.isNotEmpty) {
      final argument = node.argumentList.arguments.first;
      final callback = argument is NamedExpression
          ? argument.expression
          : argument;
      final finder = _InvalidateSelfFinder(_functions);
      if (callback is FunctionExpression) {
        callback.body.accept(finder);
      } else if (callback is SimpleIdentifier) {
        finder.follow(callback.name, callback);
      } else if (callback is PrefixedIdentifier) {
        finder.follow(callback.identifier.name, callback);
      } else if (callback is PropertyAccess) {
        finder.follow(callback.propertyName.name, callback);
      }
      if (finder.found) {
        sites.add(
          ListenerInvalidateSelfSite(
            line: _lineInfo.getLocation(node.offset).lineNumber,
            snippet: node.toString().replaceAll(RegExp(r'\s+'), ' '),
          ),
        );
      }
    }
    super.visitMethodInvocation(node);
  }
}

class _InvalidateSelfFinder extends RecursiveAstVisitor<void> {
  _InvalidateSelfFinder(this._functions, [Set<FunctionBody>? active])
    : _active = active ?? <FunctionBody>{};

  final _SameFileFunctions _functions;
  final Set<FunctionBody> _active;
  bool found = false;

  void follow(String name, AstNode callSite) {
    final body = _functions.resolve(name, callSite);
    if (body == null || !_active.add(body)) return;
    body.accept(this);
    _active.remove(body);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'invalidateSelf') {
      if (_isRefReceiver(_receiverOf(node))) found = true;
    } else if (!found && node.target == null) {
      follow(node.methodName.name, node);
    }
    super.visitMethodInvocation(node);
  }
}

/// The receiver `invalidateSelf()` was called on.
///
/// A cascade section carries no target of its own, so `ref..invalidateSelf()`
/// has to read the receiver off the enclosing [CascadeExpression].
Expression? _receiverOf(MethodInvocation node) {
  if (node.target != null) return node.target;
  final parent = node.parent;
  return parent is CascadeExpression ? parent.target : null;
}

/// Whether [receiver] names a Riverpod `Ref`.
///
/// Both spellings this repository uses count: the `ref` parameter a provider
/// body receives, and the `_ref` field a helper class holds (`_LiveDeps` in
/// `lib/providers/list_providers.dart`, `feed_repository_impl.dart`). A
/// trailing-identifier match also covers `this.ref` and `this._ref`.
bool _isRefReceiver(Expression? receiver) {
  final name = switch (receiver) {
    SimpleIdentifier(:final name) => name,
    PrefixedIdentifier(:final identifier) => identifier.name,
    PropertyAccess(:final propertyName) => propertyName.name,
    _ => null,
  };
  return name == 'ref' || name == '_ref';
}

class _SameFileFunctions {
  _SameFileFunctions(CompilationUnit unit) {
    unit.accept(_FunctionCollector(_byName));
  }

  final _byName = <String, List<_ScopedBody>>{};

  FunctionBody? resolve(String name, AstNode callSite) {
    final candidates = _byName[name];
    if (candidates == null) return null;
    final visible =
        candidates
            .where(
              (candidate) =>
                  candidate.scope == null ||
                  _isAncestor(candidate.scope!, callSite),
            )
            .toList()
          ..sort((a, b) => _depth(b.scope).compareTo(_depth(a.scope)));
    return visible.isEmpty ? null : visible.first.body;
  }

  static bool _isAncestor(AstNode ancestor, AstNode node) {
    for (AstNode? current = node; current != null; current = current.parent) {
      if (identical(current, ancestor)) return true;
    }
    return false;
  }

  static int _depth(AstNode? node) {
    var result = 0;
    for (var current = node; current != null; current = current.parent) {
      result++;
    }
    return result;
  }
}

class _ScopedBody {
  const _ScopedBody(this.body, this.scope);

  final FunctionBody body;
  final AstNode? scope;
}

class _FunctionCollector extends RecursiveAstVisitor<void> {
  _FunctionCollector(this.byName);

  final Map<String, List<_ScopedBody>> byName;

  void _add(String name, FunctionBody body, AstNode? scope) {
    byName.putIfAbsent(name, () => []).add(_ScopedBody(body, scope));
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    if (node.parent is CompilationUnit) {
      _add(node.name.lexeme, node.functionExpression.body, null);
    }
    super.visitFunctionDeclaration(node);
  }

  @override
  void visitFunctionDeclarationStatement(FunctionDeclarationStatement node) {
    final declaration = node.functionDeclaration;
    _add(
      declaration.name.lexeme,
      declaration.functionExpression.body,
      node.parent,
    );
    super.visitFunctionDeclarationStatement(node);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    _add(node.name.lexeme, node.body, node.parent);
    super.visitMethodDeclaration(node);
  }
}

bool _isGenerated(String path) =>
    path.endsWith('.g.dart') ||
    path.endsWith('.freezed.dart') ||
    path.endsWith('.gr.dart') ||
    path.endsWith('.mocks.dart') ||
    path.contains('/l10n/generated/');

void main(List<String> args) {
  var detail = false;
  var pathPrefix = '';
  final roots = <String>[];
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--detail':
        detail = true;
      case '--path-prefix':
        if (++i >= args.length) _usage();
        pathPrefix = args[i];
      default:
        if (args[i].startsWith('--')) _usage();
        roots.add(args[i]);
    }
  }
  if (roots.isEmpty) _usage();

  final counts = <String, int>{};
  final details = <String>[];
  for (final root in roots) {
    final directory = Directory(root);
    if (!directory.existsSync()) _usage('not a directory: $root');
    final files =
        directory
            .listSync(recursive: true, followLinks: false)
            .whereType<File>()
            .where(
              (file) => file.path.endsWith('.dart') && !_isGenerated(file.path),
            )
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    for (final file in files) {
      final sites = findListenerInvalidateSelfSitesInSource(
        file.readAsStringSync(),
      );
      if (sites.isEmpty) continue;
      var relative = file.path;
      if (pathPrefix.isNotEmpty && relative.startsWith(pathPrefix)) {
        relative = relative.substring(pathPrefix.length);
      }
      relative = relative.replaceFirst(RegExp('^/'), '');
      counts[relative] = (counts[relative] ?? 0) + sites.length;
      for (final site in sites) {
        details.add('$relative:${site.line}  ${site.snippet}');
      }
    }
  }
  if (detail) {
    (details..sort()).forEach(stdout.writeln);
  } else {
    for (final path in counts.keys.toList()..sort()) {
      stdout.writeln('$path\t${counts[path]}');
    }
  }
}

Never _usage([String? error]) {
  if (error != null) stderr.writeln(error);
  stderr.writeln(
    'usage: listener_invalidate_self_detector.dart <scan-dir>... '
    '[--path-prefix <dir>] [--detail]',
  );
  exit(2);
}
