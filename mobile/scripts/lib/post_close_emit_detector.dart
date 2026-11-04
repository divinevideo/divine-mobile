// ABOUTME: Detector behind check_post_close_emit_ceiling.sh — finds bloc/cubit
// ABOUTME: emit/add calls that can run after close() with no isClosed guard.
//
// Usage (from mobile/):
//   dart run scripts/lib/post_close_emit_detector.dart <scan-dir> [options]
//     --path-prefix <dir>   strip this prefix from reported paths
//     --detail              one line per site instead of per-file counts
//
// Output (default): `relpath<TAB>count`, one line per file with >0 sites,
// sorted by path — the shape scripts/lib/numeric_ratchet.sh consumes.
//
// Why an AST and not a regex
// --------------------------
// Only two of the four "emit/add after close" shapes actually throw, and
// telling them apart needs scope information (bloc 9.2.1):
//
//   BlocBase.emit  -> checks `_stateController.isClosed`, throws StateError
//                     `Cannot emit new states after calling close`. COUNTED.
//   Bloc.add       -> `_eventController` is closed by close() BEFORE the queue
//                     drains, so pending handlers throw StateError
//                     `Cannot add new events after calling close`. COUNTED.
//   Emitter.call   -> the `emit` parameter of an `on<Event>` handler. It is
//                     `if (!_isCanceled) _emit(state)`, and Bloc.close()
//                     cancels every live emitter before super.close(), so it
//                     degrades to a no-op. NOT counted — detected lexically as
//                     any scope binding a parameter named `emit`.
//   BlocBase.addError -> forwards to onError(), no controller. NOT counted.
//
// A site counts when it is reachable across a suspension point — an `await`,
// or a callback handed to a detached sink like `.listen` / `.then` / `Timer` —
// with no `isClosed` guard between that point and the call. `emitIfOpen` /
// `addIfOpen` from lib/blocs/close_guard.dart clear a site, as does an
// `if (isClosed) return;` after the await — including the `if (isClosed) {
// await cleanup(); return; }` form, since that await only runs on the path
// that never reaches the call. The guard has to be this instance's:
// `someController.isClosed` clears nothing. It also only covers the rest of
// the block/case it sits in — an await above an enclosing block still suspends
// the code after that block. A loop body counts as suspended throughout when it
// awaits anywhere, since its tail runs before its head runs again.
//
// This is intraprocedural, with one exception: a member handed to a detached
// sink as a tear-off (`listen(_onTick)`) is walked as detached, because it is
// the same code as the inline closure and must not get the opposite verdict.
// A helper reached by an ordinary call after the caller awaits is still only
// counted on its own body.
//
// Classes and `mixin ... on Bloc/Cubit/BlocBase` bodies are both walked, since
// a mixin reaches the same `emit`.
//
// Exit codes: 0 clean run, 2 bad usage / unreadable scan dir.
import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/line_info.dart';

/// Members whose closure arguments run detached from the calling frame, so a
/// call inside them can land after `close()` even with no `await` above it.
const _detachedSinks = {
  'then',
  'catchError',
  'whenComplete',
  'listen',
  'onError',
  'onData',
  'onDone',
  'forEach',
  'onEach',
  'periodic',
  'delayed',
  'scheduleMicrotask',
  'addPostFrameCallback',
  'unawaited',
  'Timer',
};

/// One `emit`/`add` call that can run after `close()`.
class PostCloseSite {
  PostCloseSite({
    required this.path,
    required this.line,
    required this.type,
    required this.member,
    required this.call,
  });

  final String path;
  final int line;
  final String type;
  final String member;

  /// Either `Cubit.emit` or `Bloc.add` — the API that throws after close.
  final String call;
}

void main(List<String> args) {
  final positional = <String>[];
  var pathPrefix = '';
  var detail = false;
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--path-prefix':
        pathPrefix = i + 1 < args.length ? args[++i] : '';
      case '--detail':
        detail = true;
      default:
        positional.add(args[i]);
    }
  }
  if (positional.length != 1) {
    stderr.writeln(
      'usage: post_close_emit_detector.dart <scan-dir> '
      '[--path-prefix <dir>] [--detail]',
    );
    exit(2);
  }
  final scanDir = Directory(positional.single);
  if (!scanDir.existsSync()) {
    stderr.writeln('not a directory: ${positional.single}');
    exit(2);
  }
  if (pathPrefix.isEmpty) pathPrefix = scanDir.path;

  final sites = findPostCloseSites(scanDir, pathPrefix: pathPrefix);
  if (detail) {
    for (final s in sites) {
      stdout.writeln(
        '${s.path}:${s.line}\t${s.type}.${s.member}\t${s.call}',
      );
    }
    return;
  }
  final counts = <String, int>{};
  for (final s in sites) {
    counts[s.path] = (counts[s.path] ?? 0) + 1;
  }
  final paths = counts.keys.toList()..sort();
  for (final path in paths) {
    stdout.writeln('$path\t${counts[path]}');
  }
}

/// Scans every non-generated Dart file under [dir] and returns the sites in
/// path-then-line order.
List<PostCloseSite> findPostCloseSites(
  Directory dir, {
  required String pathPrefix,
}) {
  final files =
      dir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where((f) => !f.path.contains('/l10n/generated/'))
          .where((f) => !f.path.contains('/.dart_tool/'))
          .where((f) => !f.path.contains('/build/'))
          .where(
            (f) => !const [
              '.g.dart',
              '.freezed.dart',
              '.gr.dart',
              '.config.dart',
              '.mocks.dart',
            ].any(f.path.endsWith),
          )
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  final sites = <PostCloseSite>[];
  for (final file in files) {
    final ParseStringResult parsed;
    try {
      // A counted class extends something whose name ends in `Bloc` or
      // `Cubit`, so a file naming neither cannot hold one. Skipping those
      // before the parser sees them drops ~1000 of the ~1600 files under lib.
      final source = file.readAsStringSync();
      if (!source.contains('Bloc') && !source.contains('Cubit')) continue;
      parsed = parseString(
        content: source,
        path: file.path,
        featureSet: FeatureSet.latestLanguageVersion(),
        throwIfDiagnostics: false,
      );
    } on Object catch (error) {
      // Never swallow this silently: an unreadable file drops its sites, which
      // reads to the ratchet as a file that was cleaned up.
      stderr.writeln('post_close_emit_detector: skipped ${file.path} ($error)');
      continue;
    }
    final relative = file.path.startsWith('$pathPrefix/')
        ? file.path.substring(pathPrefix.length + 1)
        : file.path;
    for (final decl in parsed.unit.declarations) {
      final String typeName;
      final List<String> supertypes;
      if (decl is ClassDeclaration) {
        typeName = decl.namePart.typeName.lexeme;
        final superclass = decl.extendsClause?.superclass.name.lexeme;
        supertypes = superclass == null ? const [] : [superclass];
      } else if (decl is MixinDeclaration) {
        // A `mixin ... on Cubit<S>` reaches the same emit as the class does,
        // so scanning only classes would leave a one-line way past the guard.
        typeName = decl.name.lexeme;
        supertypes = [
          for (final constraint
              in decl.onClause?.superclassConstraints ?? const <NamedType>[])
            constraint.name.lexeme,
        ];
      } else {
        continue;
      }
      final isBloc = supertypes.any((name) => name.endsWith('Bloc'));
      // `BlocBase` is the mixin constraint that reaches `emit` without
      // reaching `add`, so it counts as a cubit rather than a bloc.
      final isCubit = supertypes.any(
        (name) => name.endsWith('Cubit') || name == 'BlocBase',
      );
      if (!isBloc && !isCubit) continue;
      _Scanner(
        sites,
        path: relative,
        lineInfo: parsed.lineInfo,
        type: typeName,
        isBloc: isBloc,
      ).scan(decl);
    }
  }
  sites.sort((a, b) {
    final byPath = a.path.compareTo(b.path);
    return byPath != 0 ? byPath : a.line.compareTo(b.line);
  });
  return sites;
}

/// Source-order walk over one class or mixin body, tracking per member whether
/// a suspension point has been crossed since the last `isClosed` guard.
class _Scanner {
  _Scanner(
    this.sites, {
    required this.path,
    required this.lineInfo,
    required this.type,
    required this.isBloc,
  });

  final List<PostCloseSite> sites;
  final String path;
  final LineInfo lineInfo;
  final String type;
  final bool isBloc;

  /// The member currently being walked, for `--detail` output only.
  String member = '';

  /// A suspension point has been crossed with no `isClosed` guard since.
  bool suspended = false;

  /// An enclosing scope binds a parameter named `emit`, so bare `emit(...)` is
  /// the handler's `Emitter.call` rather than `BlocBase.emit`.
  bool emitterInScope = false;

  /// Members handed to a detached sink as a tear-off, as in `listen(_onTick)`.
  ///
  /// Their bodies run detached exactly like the equivalent inline closure, so
  /// they start suspended rather than clean. Without this, `listen(_onTick)`
  /// and `listen((v) => ...)` — identical semantics — get opposite verdicts.
  final Set<String> detachedTearOffs = {};

  void scan(CompilationUnitMember declaration) {
    _collectDetachedTearOffs(declaration);
    _children(declaration, guarded: false);
  }

  void _collectDetachedTearOffs(AstNode node) {
    final (ArgumentList? arguments, String name) = switch (node) {
      MethodInvocation(:final argumentList, :final methodName) => (
        argumentList,
        methodName.name,
      ),
      InstanceCreationExpression(:final argumentList, :final constructorName) =>
        (argumentList, constructorName.toSource()),
      _ => (null, ''),
    };
    if (arguments != null && _detachedSinks.any(name.contains)) {
      for (final argument in arguments.arguments) {
        final value = argument is NamedArgument
            ? argument.argumentExpression
            : argument as Expression;
        if (value is SimpleIdentifier) detachedTearOffs.add(value.name);
      }
    }
    node.childEntities.whereType<AstNode>().forEach(_collectDetachedTearOffs);
  }

  void _children(AstNode node, {required bool guarded}) {
    for (final child in node.childEntities.whereType<AstNode>()) {
      _node(child, guarded: guarded);
    }
  }

  void _statements(
    List<Statement> statements, {
    required bool guarded,
    required bool rejoinEntered,
  }) {
    final enteredSuspended = suspended;
    for (final statement in statements) {
      if (_isEarlyReturnGuard(statement)) {
        suspended = false;
        continue;
      }
      _node(statement, guarded: guarded);
    }
    if (rejoinEntered) {
      suspended |= enteredSuspended;
    }
  }

  /// Whether [node] tests *this* instance's `isClosed`.
  ///
  /// `someController.isClosed` says nothing about whether this bloc is still
  /// open, so only the receiverless and `this.` forms clear a site.
  bool _mentionsIsClosed(AstNode? node) {
    if (node == null) return false;
    if (node is SimpleIdentifier && node.name == 'isClosed') {
      final parent = node.parent;
      final qualified =
          (parent is PropertyAccess && parent.propertyName == node) ||
          (parent is PrefixedIdentifier && parent.identifier == node);
      if (!qualified) return true;
    }
    if (node is PropertyAccess &&
        node.target is ThisExpression &&
        node.propertyName.name == 'isClosed') {
      return true;
    }
    return node.childEntities.whereType<AstNode>().any(_mentionsIsClosed);
  }

  /// Whether [node] suspends the frame it sits in.
  ///
  /// A closure body is skipped: its `await` suspends the closure, not the loop
  /// or method asking the question.
  bool _containsAwait(AstNode node) {
    for (final child in node.childEntities.whereType<AstNode>()) {
      if (child is FunctionExpression) continue;
      if (child is AwaitExpression || _containsAwait(child)) return true;
    }
    return false;
  }

  /// `if (isClosed) return;` and friends — everything after it in this block is
  /// reachable only while open.
  ///
  /// Only the *exit* has to be unconditional, not the whole arm: the shape the
  /// close-guard rule recommends is often `if (isClosed) { await cleanup();
  /// return; }`, and an await that runs only on the closed path never suspends
  /// the path that falls through.
  bool _isEarlyReturnGuard(Statement statement) {
    if (statement is! IfStatement) return false;
    if (!_mentionsIsClosed(statement.expression)) return false;
    final then = statement.thenStatement;
    final body = then is Block ? then.statements : [then];
    if (body.isEmpty) return false;
    final exit = body.last;
    return exit is ReturnStatement ||
        exit is BreakStatement ||
        exit is ContinueStatement ||
        (exit is ExpressionStatement && exit.expression is ThrowExpression);
  }

  void _node(AstNode node, {required bool guarded}) {
    // Each class member starts a fresh frame: nothing has suspended yet, and
    // an `Emitter emit` parameter only shadows `BlocBase.emit` inside it.
    final (String? name, FormalParameterList? params) = switch (node) {
      MethodDeclaration(:final name, :final parameters) => (
        name.lexeme,
        parameters,
      ),
      ConstructorDeclaration(:final parameters) => ('<ctor>', parameters),
      FieldDeclaration(:final fields) => (
        fields.variables.first.name.lexeme,
        null,
      ),
      _ => (null, null),
    };
    if (name != null) {
      member = name;
      suspended = detachedTearOffs.contains(name);
      emitterInScope =
          params?.parameters.any((p) => p.name?.lexeme == 'emit') ?? false;
      _children(node, guarded: guarded);
      return;
    }

    if (node is Block) {
      // A block may not run at all (an `if` arm, a loop body), so what follows
      // it is suspended if *either* path suspended: the one through the block,
      // or the one around it. Without the join, a guard inside a conditional
      // arm would silently clear every call after the arm closes.
      _statements(node.statements, guarded: guarded, rejoinEntered: true);
      return;
    }

    if (node is IfStatement && _mentionsIsClosed(node.expression)) {
      _children(node, guarded: true);
      return;
    }

    if (node is SwitchStatement) {
      final enteredSuspended = suspended;
      var exitsSuspended = enteredSuspended;
      for (final member in node.members) {
        suspended = enteredSuspended;
        _statements(
          member.statements,
          guarded: guarded,
          rejoinEntered: false,
        );
        exitsSuspended |= suspended;
      }
      suspended = exitsSuspended;
      return;
    }

    if (node is TryStatement) {
      final enteredSuspended = suspended;
      final tryCanResume = enteredSuspended || _containsAwait(node.body);

      suspended = enteredSuspended;
      _node(node.body, guarded: guarded);
      var exitsSuspended = suspended;

      var catchCanResume = false;
      for (final catchClause in node.catchClauses) {
        suspended = tryCanResume;
        _node(catchClause.body, guarded: guarded);
        exitsSuspended |= suspended;
        catchCanResume |= _containsAwait(catchClause.body);
      }

      if (node.finallyBlock case final finallyBlock?) {
        suspended = tryCanResume || catchCanResume;
        _node(finallyBlock, guarded: guarded);
      } else {
        suspended = exitsSuspended;
      }
      return;
    }

    // A loop body's tail suspends before its head runs again, so a call above
    // the await is still reachable across one on the next iteration.
    if (node is ForStatement || node is WhileStatement || node is DoStatement) {
      suspended =
          suspended ||
          (node is ForStatement && node.awaitKeyword != null) ||
          _containsAwait(node);
      _children(node, guarded: guarded);
      return;
    }

    if (node is AwaitExpression) {
      _children(node, guarded: guarded);
      suspended = true;
      return;
    }

    if (node is FunctionExpression) {
      final savedSuspended = suspended;
      final savedEmitter = emitterInScope;
      suspended = suspended || _isDetached(node);
      emitterInScope =
          emitterInScope ||
          (node.parameters?.parameters.any((p) => p.name?.lexeme == 'emit') ??
              false);
      _children(node.body, guarded: guarded);
      suspended = savedSuspended;
      emitterInScope = savedEmitter;
      return;
    }

    if (node is MethodInvocation &&
        node.target == null &&
        !node.isCascaded &&
        suspended &&
        !guarded) {
      final name = node.methodName.name;
      if (name == 'emit' && !emitterInScope) {
        _report(node, 'Cubit.emit');
      } else if (name == 'add' && isBloc) {
        _report(node, 'Bloc.add');
      }
    }

    _children(node, guarded: guarded);
  }

  bool _isDetached(FunctionExpression node) {
    if (node.body.isAsynchronous) return true;
    final parent = node.parent;
    if (parent is! ArgumentList && parent is! NamedArgument) return false;
    final invocation = parent is NamedArgument
        ? parent.parent?.parent
        : parent?.parent;
    final name = switch (invocation) {
      MethodInvocation(:final methodName) => methodName.name,
      InstanceCreationExpression(:final constructorName) =>
        constructorName.toSource(),
      FunctionExpressionInvocation(:final function) => function.toSource(),
      _ => '',
    };
    return _detachedSinks.any(name.contains);
  }

  void _report(AstNode node, String call) {
    sites.add(
      PostCloseSite(
        path: path,
        line: lineInfo.getLocation(node.offset).lineNumber,
        type: type,
        member: member,
        call: call,
      ),
    );
  }
}
