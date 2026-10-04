// ABOUTME: Finds widget-test interactions using layout after an unsettled scroll.
// ABOUTME: Tracks ordered calls, branches and same-file helpers for #7278.
//
// Syntax-only: follows direct top-level/local functions, with lexical lookup,
// tester parameter binding and a recursion guard. The shared scrollUntilTappable
// contract is recognized; other imported/dynamically invoked helpers are outside
// its scope. Function declarations and callback creation do
// not execute their bodies. Assertions and widget reads preserve pending scrolls.
// Branches merge by union: a pump clears a scroll only on paths that execute it.
// Output: path<TAB>count, or path:interaction-line<TAB>scroll-line<TAB>method
// with --detail. Scans Dart files in test/ and integration_test/, including
// helper files; excludes generated files and build/worktree directories.
import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

const _pumps = {'pump', 'pumpAndSettle', 'pumpWidget', 'pumpFrames'};
const _positions = {
  'tap',
  'tapAt',
  'tapOnText',
  'longPress',
  'longPressAt',
  'press',
  'drag',
  'dragFrom',
  'fling',
  'flingFrom',
  'timedDrag',
  'timedDragFrom',
  'startGesture',
  'getCenter',
  'getRect',
  'getTopLeft',
  'getTopRight',
  'getBottomLeft',
  'getBottomRight',
};

class BareScrollInteraction {
  const BareScrollInteraction(
    this.path,
    this.scrollLine,
    this.line,
    this.method,
  );

  final String path;
  final int scrollLine;
  final int line;
  final String method;
}

void main(List<String> args) {
  final dirs = <String>[];
  var prefix = '';
  var detail = false;
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--path-prefix':
        if (++i == args.length) _usage();
        prefix = args[i];
      case '--detail':
        detail = true;
      default:
        if (args[i].startsWith('-')) _usage();
        dirs.add(args[i]);
    }
  }
  if (dirs.isEmpty) _usage();
  final found = <BareScrollInteraction>[];
  for (final dir in dirs) {
    if (!Directory(dir).existsSync()) {
      stderr.writeln(
        'bare_scroll_interaction_detector: no such directory: $dir',
      );
      exit(2);
    }
    found.addAll(
      findBareScrollInteractions(Directory(dir), pathPrefix: prefix),
    );
  }
  if (detail) {
    for (final site in found) {
      stdout.writeln(
        '${site.path}:${site.line}\t${site.scrollLine}\t${site.method}',
      );
    }
  } else {
    final counts = <String, int>{};
    for (final site in found) {
      counts.update(site.path, (n) => n + 1, ifAbsent: () => 1);
    }
    for (final path in counts.keys.toList()..sort()) {
      stdout.writeln('$path\t${counts[path]}');
    }
  }
}

Never _usage() {
  stderr.writeln(
    'usage: bare_scroll_interaction_detector.dart <dir>... '
    '[--path-prefix <dir>] [--detail]',
  );
  exit(2);
}

List<BareScrollInteraction> findBareScrollInteractions(
  Directory dir, {
  String pathPrefix = '',
}) {
  final found = <BareScrollInteraction>[];
  for (final file in dir.listSync(recursive: true).whereType<File>()) {
    final parts = file.path.split('/');
    // Ignore nested artifacts, not ancestors of the supplied scan root: an
    // absolute scan path inside an isolated worktree must still be checked.
    final nestedParts = file.path.substring(dir.path.length).split('/');
    if (!file.path.endsWith('.dart') ||
        file.path.endsWith('.g.dart') ||
        file.path.endsWith('.mocks.dart') ||
        !parts.any({'test', 'integration_test'}.contains) ||
        nestedParts.any(
          {'.dart_tool', 'build', '.worktrees', 'generated'}.contains,
        )) {
      continue;
    }
    final parsed = parseString(
      content: file.readAsStringSync(),
      featureSet: FeatureSet.latestLanguageVersion(),
      throwIfDiagnostics: false,
    );
    var path = file.path;
    if (pathPrefix.isNotEmpty && path.startsWith('$pathPrefix/')) {
      path = path.substring(pathPrefix.length + 1);
    }
    final functions = _Functions();
    parsed.unit.accept(functions);
    final scanner = _Scanner(functions);
    for (final body in functions.bodies) {
      scanner.body(body, _State(), {});
    }
    for (final (scroll, interaction) in scanner.found) {
      found.add(
        BareScrollInteraction(
          path,
          parsed.lineInfo.getLocation(scroll.offset).lineNumber,
          parsed.lineInfo.getLocation(interaction.offset).lineNumber,
          interaction.methodName.name,
        ),
      );
    }
  }
  found.sort((a, b) {
    final path = a.path.compareTo(b.path);
    if (path != 0) return path;
    final line = a.line.compareTo(b.line);
    return line != 0 ? line : a.scrollLine.compareTo(b.scrollLine);
  });
  return found;
}

class _Functions extends RecursiveAstVisitor<void> {
  final bodies = <FunctionBody>[];
  final declarations = <FunctionDeclaration>[];

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    declarations.add(node);
    super.visitFunctionDeclaration(node);
  }

  @override
  void visitBlockFunctionBody(BlockFunctionBody node) {
    bodies.add(node);
    super.visitBlockFunctionBody(node);
  }

  @override
  void visitExpressionFunctionBody(ExpressionFunctionBody node) {
    bodies.add(node);
    super.visitExpressionFunctionBody(node);
  }

  FunctionDeclaration? resolve(MethodInvocation call) {
    if (call.target != null) return null;
    FunctionDeclaration? best;
    var bestDepth = 1 << 30;
    for (final declaration in declarations) {
      if (declaration.name.lexeme != call.methodName.name) continue;
      final scope = declaration.parent is FunctionDeclarationStatement
          ? declaration.parent!.parent
          : declaration.parent;
      if (scope is! Block && scope is! CompilationUnit) continue;
      var depth = 0;
      for (AstNode? node = call; node != null; node = node.parent) {
        if (identical(node, scope) && depth < bestDepth) {
          // Smaller distance is the nearer lexical scope.
          best = declaration;
          bestDepth = depth;
        }
        depth++;
      }
    }
    return best;
  }
}

// Each tester retains every scroll that may still need a frame on a live path.
class _State {
  final pending = <String, Set<MethodInvocation>>{};

  _State copy() {
    final result = _State();
    for (final entry in pending.entries) {
      result.pending[entry.key] = {...entry.value};
    }
    return result;
  }

  bool sameAs(_State other) =>
      pending.length == other.pending.length &&
      pending.entries.every((entry) {
        final value = other.pending[entry.key];
        return value != null &&
            value.length == entry.value.length &&
            value.containsAll(entry.value);
      });
}

_State? _merge(_State? a, _State? b) {
  if (a == null) return b?.copy();
  final result = a.copy();
  if (b != null) {
    for (final entry in b.pending.entries) {
      result.pending.putIfAbsent(entry.key, () => {}).addAll(entry.value);
    }
  }
  return result;
}

class _Flow {
  _Flow(this.normal, {this.returned, this.broken, this.continued});

  _State? normal;
  _State? returned;
  _State? broken;
  _State? continued;

  void absorb(_Flow other) {
    returned = _merge(returned, other.returned);
    broken = _merge(broken, other.broken);
    continued = _merge(continued, other.continued);
  }
}

class _Scanner {
  _Scanner(this.functions);

  final _Functions functions;
  final active = <FunctionBody>{};
  final found = <(MethodInvocation, MethodInvocation)>{};
  final exceptionStates = <_State>[];

  _State body(FunctionBody body, _State state, Map<String, String> names) {
    if (!active.add(body)) return state;
    _State result;
    if (body is BlockFunctionBody) {
      final flow = statement(body.block, state, names);
      result = _merge(flow.normal, flow.returned) ?? state;
    } else if (body is ExpressionFunctionBody) {
      expression(body.expression, state, names, completed: true);
      result = state;
    } else {
      result = state;
    }
    active.remove(body);
    return result;
  }

  _Flow sequence(
    Iterable<Statement> statements,
    _State state,
    Map<String, String> names,
  ) {
    final flow = _Flow(state);
    for (final node in statements) {
      if (flow.normal == null) break;
      final next = statement(node, flow.normal!, names);
      flow.normal = next.normal;
      flow.absorb(next);
    }
    return flow;
  }

  _Flow statement(Statement node, _State state, Map<String, String> names) {
    if (node is FunctionDeclarationStatement) return _Flow(state);
    if (node is Block) return sequence(node.statements, state, {...names});
    if (node is ReturnStatement) {
      if (node.expression != null) {
        expression(node.expression!, state, names, completed: true);
      }
      return _Flow(null, returned: state);
    }
    if (node is BreakStatement) return _Flow(null, broken: state);
    if (node is ContinueStatement) return _Flow(null, continued: state);
    if (node is SwitchStatement) {
      expression(node.expression, state, names);
      final combined = _Flow(null);
      var exhaustive = false;
      for (final member in node.members) {
        if (member is SwitchDefault ||
            (member is SwitchPatternCase &&
                member.guardedPattern.pattern is WildcardPattern &&
                member.guardedPattern.whenClause == null)) {
          exhaustive = true;
        }
        final branchState = state.copy();
        if (member is SwitchPatternCase &&
            member.guardedPattern.whenClause != null) {
          expression(member.guardedPattern.whenClause!, branchState, names);
        }
        final branch = sequence(member.statements, branchState, {...names});
        combined.normal = _merge(
          combined.normal,
          _merge(branch.normal, branch.broken),
        );
        combined.returned = _merge(combined.returned, branch.returned);
        combined.continued = _merge(combined.continued, branch.continued);
      }
      if (!exhaustive) combined.normal = _merge(combined.normal, state);
      return combined;
    }
    if (node is IfStatement) {
      expression(node.expression, state, names);
      final yes = statement(node.thenStatement, state.copy(), {...names});
      final no = node.elseStatement == null
          ? _Flow(state.copy())
          : statement(node.elseStatement!, state.copy(), {...names});
      return _Flow(_merge(yes.normal, no.normal))
        ..absorb(yes)
        ..absorb(no);
    }
    if (node is WhileStatement) {
      expression(node.condition, state, names);
      return loop(node.body, state, names, condition: node.condition);
    }
    if (node is DoStatement) {
      return loop(
        node.body,
        state,
        names,
        condition: node.condition,
        once: true,
      );
    }
    if (node is ForStatement) {
      final parts = node.forLoopParts;
      if (parts is ForParts) {
        for (final child in parts.childEntities.whereType<AstNode>()) {
          if (identical(child, parts.condition) ||
              parts.updaters.contains(child)) {
            continue;
          }
          expression(child, state, names);
        }
        if (parts.condition != null) expression(parts.condition!, state, names);
        return loop(
          node.body,
          state,
          names,
          condition: parts.condition,
          updaters: parts.updaters,
        );
      }
      expression(parts, state, names);
      return loop(node.body, state, names);
    }
    if (node is TryStatement) {
      final exceptional = state.copy();
      exceptionStates.add(exceptional);
      final tried = statement(node.body, state.copy(), {...names});
      exceptionStates.removeLast();
      final combined = _Flow(tried.normal)..absorb(tried);
      for (final clause in node.catchClauses) {
        // An exception can occur before any pump in the try body completes.
        final caught = statement(
          clause.body,
          exceptional.copy(),
          {...names},
        );
        combined.normal = _merge(combined.normal, caught.normal);
        combined.absorb(caught);
      }
      final finallyBlock = node.finallyBlock;
      if (finallyBlock != null) {
        for (final exit in ['normal', 'returned', 'broken', 'continued']) {
          final current = switch (exit) {
            'normal' => combined.normal,
            'returned' => combined.returned,
            'broken' => combined.broken,
            _ => combined.continued,
          };
          if (current == null) continue;
          final after = statement(finallyBlock, current, {...names});
          switch (exit) {
            case 'normal':
              combined.normal = after.normal;
            case 'returned':
              combined.returned = after.normal;
            case 'broken':
              combined.broken = after.normal;
            default:
              combined.continued = after.normal;
          }
          combined.absorb(after);
        }
      }
      return combined;
    }
    if (node is ExpressionStatement && node.expression is ThrowExpression) {
      expression(node.expression, state, names);
      return _Flow(null);
    }
    expression(node, state, names);
    return _Flow(state);
  }

  _Flow loop(
    Statement node,
    _State state,
    Map<String, String> names, {
    Expression? condition,
    Iterable<Expression> updaters = const [],
    bool once = false,
  }) {
    var incoming = state.copy();
    final exits = _Flow(once ? null : state.copy());
    while (true) {
      final iteration = statement(node, incoming.copy(), {...names});
      exits.returned = _merge(exits.returned, iteration.returned);
      exits.normal = _merge(exits.normal, iteration.broken);
      final next = _merge(iteration.normal, iteration.continued);
      if (next == null) break;
      for (final updater in updaters) {
        expression(updater, next, names);
      }
      if (condition != null) expression(condition, next, names);
      exits.normal = _merge(exits.normal, next);
      final merged = _merge(incoming, next)!;
      if (incoming.sameAs(merged)) break;
      incoming = merged;
    }
    return exits;
  }

  String receiver(AstNode node, Map<String, String> names) {
    if (node is ParenthesizedExpression) {
      return receiver(node.expression, names);
    }
    return names[node.toSource()] ?? node.toSource();
  }

  void expression(
    AstNode node,
    _State state,
    Map<String, String> names, {
    bool completed = false,
  }) {
    if (node is FunctionExpression || node is FunctionDeclaration) return;
    if (node is AwaitExpression || node is ParenthesizedExpression) {
      final inner = node is AwaitExpression
          ? node.expression
          : (node as ParenthesizedExpression).expression;
      expression(
        inner,
        state,
        names,
        completed: completed || node is AwaitExpression,
      );
      return;
    }
    if (node is ConditionalExpression) {
      expression(node.condition, state, names);
      final yes = state.copy();
      final no = state.copy();
      expression(node.thenExpression, yes, {...names}, completed: completed);
      expression(node.elseExpression, no, {...names}, completed: completed);
      state.pending
        ..clear()
        ..addAll(_merge(yes, no)!.pending);
      return;
    }
    if (node is SwitchExpression) {
      expression(node.expression, state, names);
      _State? merged;
      for (final branch in node.cases) {
        final alternative = state.copy();
        if (branch.guardedPattern.whenClause != null) {
          expression(branch.guardedPattern.whenClause!, alternative, names);
        }
        expression(branch.expression, alternative, {
          ...names,
        }, completed: completed);
        merged = _merge(merged, alternative);
      }
      if (merged != null) {
        state.pending
          ..clear()
          ..addAll(merged.pending);
      }
      return;
    }
    if (node is BinaryExpression &&
        {'&&', '||', '??'}.contains(node.operator.lexeme)) {
      expression(node.leftOperand, state, names);
      final right = state.copy();
      expression(node.rightOperand, right, {...names});
      final merged = _merge(state, right)!;
      state.pending
        ..clear()
        ..addAll(merged.pending);
      return;
    }
    for (final child in node.childEntities.whereType<AstNode>()) {
      expression(child, state, names);
    }
    if (node is VariableDeclaration && node.initializer is SimpleIdentifier) {
      names[node.name.lexeme] = receiver(node.initializer!, names);
    }
    if (node is! MethodInvocation) return;
    final method = node.methodName.name;
    if (node.target != null) {
      final tester = receiver(node.target!, names);
      if (method == 'scrollUntilVisible') {
        state.pending.putIfAbsent(tester, () => {}).add(node);
        for (final exceptional in exceptionStates) {
          exceptional.pending.putIfAbsent(tester, () => {}).add(node);
        }
      } else if (_pumps.contains(method) && completed) {
        state.pending.remove(tester);
      } else if (_positions.contains(method)) {
        for (final scroll in state.pending[tester] ?? <MethodInvocation>{}) {
          found.add((scroll, node));
        }
      }
      return;
    }
    final helper = functions.resolve(node);
    if (helper == null) {
      // This existing shared helper guarantees an awaited pumpAndSettle.
      // Resolve same-file declarations first so a shadowed name cannot bypass
      // the guard merely by being named scrollUntilTappable.
      if (method == 'scrollUntilTappable' &&
          completed &&
          node.argumentList.arguments.isNotEmpty) {
        state.pending.remove(
          receiver(node.argumentList.arguments.first, names),
        );
      }
      return;
    }
    final bindings = {...names};
    final positional = node.argumentList.arguments
        .where((a) => a is! NamedExpression)
        .toList();
    var position = 0;
    for (final parameter
        in helper.functionExpression.parameters?.parameters ??
            <FormalParameter>[]) {
      final name = parameter.name?.lexeme;
      if (name == null) continue;
      AstNode? argument;
      if (parameter.isNamed) {
        for (final named
            in node.argumentList.arguments.whereType<NamedExpression>()) {
          if (named.name.label.name == name) argument = named.expression;
        }
      } else if (position < positional.length) {
        argument = positional[position++];
      }
      if (argument != null) bindings[name] = receiver(argument, names);
    }
    final after = body(helper.functionExpression.body, state.copy(), bindings);
    final result = completed ? after : _merge(state, after)!;
    state.pending
      ..clear()
      ..addAll(result.pending);
  }
}
