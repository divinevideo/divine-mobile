// ABOUTME: Finds registered listeners that rebuild their own Riverpod provider.
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
    final argument = _registeredCallback(node);
    if (argument != null) {
      final callback = _unwrapCallback(
        argument is NamedExpression ? argument.expression : argument,
      );
      final finder = _InvalidateSelfFinder(_functions);
      if (callback is FunctionExpression) {
        callback.body.accept(finder);
      } else if (_isInvalidateSelfTearOff(callback)) {
        finder.found = true;
      } else if (callback is SimpleIdentifier) {
        finder.follow(callback.name, callback);
      } else if (callback is PropertyAccess &&
          callback.target is ThisExpression) {
        finder.follow(callback.propertyName.name, callback);
      }
      // A callback written `deps.onChange` (a PrefixedIdentifier) or `a.b.c`
      // (a PropertyAccess on another receiver) names an object the detector
      // cannot type. Following it by trailing name alone would instead
      // resolve a same-named method on the registering class — a false
      // positive on a zero floor — so those shapes are not followed.
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

/// The callback registered by the listener APIs used in production providers.
///
/// Most call `Listenable.addListener` directly. Providers that also need
/// automatic removal use the shared `listenForProviderLifetime` helper, whose
/// callback is its third argument.
Expression? _registeredCallback(MethodInvocation node) {
  final arguments = node.argumentList.arguments;
  return switch (node.methodName.name) {
    'addListener' when arguments.isNotEmpty => arguments.first,
    'listenForProviderLifetime' when arguments.length >= 3 => arguments[2],
    _ => null,
  };
}

class _InvalidateSelfFinder extends RecursiveAstVisitor<void> {
  _InvalidateSelfFinder(this._functions, [Set<FunctionBody>? active])
    : _active = active ?? <FunctionBody>{};

  final _SameFileFunctions _functions;
  final Set<FunctionBody> _active;
  bool found = false;

  void follow(String name, AstNode callSite) {
    for (final body in _functions.resolveAll(name, callSite)) {
      if (!_active.add(body)) continue;
      body.accept(this);
      _active.remove(body);
    }
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

/// Strips the wrappers that do not change which callback is registered, so a
/// `listener!`, `(listener)`, or `listener as VoidCallback` argument resolves
/// like the bare identifier it wraps.
Expression _unwrapCallback(Expression expression) {
  var current = expression;
  while (true) {
    final Expression next;
    if (current is ParenthesizedExpression) {
      next = current.expression;
    } else if (current is PostfixExpression && current.operator.lexeme == '!') {
      next = current.operand;
    } else if (current is AsExpression) {
      next = current.expression;
    } else {
      return current;
    }
    current = next;
  }
}

/// Whether the registered callback is `invalidateSelf` itself — a listener API
/// handed `ref.invalidateSelf`, `_ref.invalidateSelf`, or a `this.ref` form.
/// The listener *is* the provider rebuild, so there is no body to walk.
bool _isInvalidateSelfTearOff(Expression expression) => switch (expression) {
  PropertyAccess(:final propertyName, :final target) =>
    propertyName.name == 'invalidateSelf' && _isRefReceiver(target),
  PrefixedIdentifier(:final identifier, :final prefix) =>
    identifier.name == 'invalidateSelf' && _isRefReceiver(prefix),
  _ => false,
};

class _SameFileFunctions {
  _SameFileFunctions(CompilationUnit unit) {
    unit.accept(_FunctionCollector(_byName));
  }

  final _byName = <String, List<_ScopedBody>>{};

  /// Every body a callback named [name] can resolve to at the call site: the
  /// bindings at the deepest visible scope.
  ///
  /// Two bindings can share that scope — a field assigned in two methods, a
  /// variable reassigned in one block — and which one the program uses depends
  /// on execution order, which the detector cannot know. Walking all of them
  /// keeps a verdict from depending on method order.
  List<FunctionBody> resolveAll(String name, AstNode callSite) {
    final candidates = _byName[name];
    if (candidates == null) return const [];
    final visible = candidates
        .where(
          (candidate) =>
              candidate.scope == null ||
              _isAncestor(candidate.scope!, callSite),
        )
        .toList();
    if (visible.isEmpty) return const [];
    var deepest = 0;
    for (final candidate in visible) {
      final depth = _depth(candidate.scope);
      if (depth > deepest) deepest = depth;
    }
    return visible
        .where((candidate) => _depth(candidate.scope) == deepest)
        .map((candidate) => candidate.body)
        .toList();
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

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    final initializer = node.initializer;
    if (initializer is FunctionExpression) {
      _add(node.name.lexeme, initializer.body, _variableScope(node));
    }
    super.visitVariableDeclaration(node);
  }

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    final assigned = node.rightHandSide;
    if (node.operator.lexeme == '=' && assigned is FunctionExpression) {
      final name = _assignedName(node.leftHandSide);
      if (name != null) {
        _add(name, assigned.body, _assignmentScope(node, name));
      }
    }
    super.visitAssignmentExpression(node);
  }
}

/// Where a closure bound to a variable can be named from: the enclosing block
/// for a local, the enclosing class for a field, the whole file otherwise.
AstNode? _variableScope(VariableDeclaration node) {
  final declaration = node.parent?.parent;
  return switch (declaration) {
    VariableDeclarationStatement() => declaration.parent,
    FieldDeclaration() => declaration.parent,
    _ => null,
  };
}

/// The name a plain `name = ...` or `this.name = ...` assignment binds.
String? _assignedName(Expression expression) => switch (expression) {
  SimpleIdentifier(:final name) => name,
  PropertyAccess(target: ThisExpression(), :final propertyName) =>
    propertyName.name,
  _ => null,
};

/// Where a closure assigned to a variable or field can be named from.
///
/// An explicit `this.name = ...`, or a bare `name = ...` the enclosing class
/// declares as a field, is visible from every method of that class — the same
/// reach the declaration form (`late final ... name = ...`) already has — so
/// it takes the class as its scope unless an enclosing block declares `name`
/// as a local. Anything else keeps its nearest block or function body, so an
/// assignment made inside one method is not read as a binding for another.
AstNode? _assignmentScope(AssignmentExpression node, String name) {
  final classLike = _enclosingClassOrMixin(node);
  final lhs = node.leftHandSide;
  final explicitField = lhs is PropertyAccess && lhs.target is ThisExpression;
  if (classLike != null &&
      (explicitField || _declaresField(classLike, name)) &&
      !_enclosingScopeBindsLocal(node, name)) {
    return classLike;
  }
  for (
    AstNode? current = node.parent;
    current != null;
    current = current.parent
  ) {
    if (current is Block ||
        current is FunctionBody ||
        current is ClassDeclaration ||
        current is MixinDeclaration) {
      return current;
    }
  }
  return null;
}

AstNode? _enclosingClassOrMixin(AstNode node) {
  for (
    AstNode? current = node.parent;
    current != null;
    current = current.parent
  ) {
    if (current is ClassDeclaration || current is MixinDeclaration) {
      return current;
    }
  }
  return null;
}

ClassBody? _classLikeBody(AstNode node) => switch (node) {
  ClassDeclaration(:final body) => body,
  MixinDeclaration(:final body) => body,
  _ => null,
};

bool _declaresField(AstNode node, String name) {
  final body = _classLikeBody(node);
  if (body == null) return false;
  for (final member in body.members) {
    if (member is FieldDeclaration) {
      for (final variable in member.fields.variables) {
        if (variable.name.lexeme == name) return true;
      }
    }
  }
  return false;
}

/// Whether the assignment binds a local or a parameter rather than its class
/// or mixin field: an enclosing block that declares [name], or an enclosing
/// function whose parameters name it. The walk stops at the class or mixin,
/// where a field is the binding.
bool _enclosingScopeBindsLocal(AstNode node, String name) {
  for (
    AstNode? current = node.parent;
    current != null;
    current = current.parent
  ) {
    if (current is Block) {
      for (final statement in current.statements) {
        if (statement is VariableDeclarationStatement) {
          for (final variable in statement.variables.variables) {
            if (variable.name.lexeme == name) return true;
          }
        }
      }
    }
    final parameters = _parametersOf(current);
    if (parameters != null && _parameterBinds(parameters, name)) {
      return true;
    }
    if (current is ClassDeclaration || current is MixinDeclaration) {
      return false;
    }
  }
  return false;
}

FormalParameterList? _parametersOf(AstNode node) => switch (node) {
  MethodDeclaration(:final parameters) => parameters,
  ConstructorDeclaration(:final parameters) => parameters,
  FunctionDeclaration(:final functionExpression) =>
    functionExpression.parameters,
  FunctionExpression(:final parameters) => parameters,
  _ => null,
};

bool _parameterBinds(FormalParameterList parameters, String name) {
  for (final parameter in parameters.parameters) {
    final normal = parameter is DefaultFormalParameter
        ? parameter.parameter
        : parameter;
    if (normal is NormalFormalParameter && normal.name?.lexeme == name) {
      return true;
    }
  }
  return false;
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
