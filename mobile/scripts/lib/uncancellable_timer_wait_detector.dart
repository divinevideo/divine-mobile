// ABOUTME: Detector behind check_uncancellable_timer_wait.sh — finds discarded
// ABOUTME: Timers whose callback completes a Completer, i.e. uncancellable waits
//
// Usage (from mobile/):
//   dart run scripts/lib/uncancellable_timer_wait_detector.dart <scan-dir>... \
//     [--path-prefix <dir>] [--detail]
//
// Output (default): `relpath<TAB>count`, one line per file with >0 sites,
// sorted by path — the shape scripts/lib/numeric_ratchet.sh consumes.
//
// What counts
// -----------
// A `Timer(...)` / `Timer.periodic(...)` whose value is DISCARDED — the whole
// construction is an expression statement, so no variable, field, or
// collection ever holds it — AND whose callback completes a `Completer`:
//
//     final completer = Completer<void>();
//     Timer(delay, completer.complete);   // <- counted
//     await completer.future;
//
// That pair is a wall-clock wait with no owner. Nothing can call `.cancel()`
// on the timer, so `dispose()` cannot stop it: the awaiting code resumes into
// a torn-down owner after the delay elapses (#8457). It is exactly
// `await Future.delayed(delay)` with the ratchet-visible name filed off, which
// is why it needs its own guard — see check_future_delayed_production_ceiling.sh,
// whose detector matches `Future.delayed` call sites and cannot see this shape.
//
// The fix is AsyncScope in lib/utils/async_utils.dart, which owns every timer
// it creates and cancels them on cancelAll()/dispose().
//
// What does NOT count
// -------------------
// A timer whose value is kept — `_timer = Timer(...)`, `timers.add(Timer(...))`,
// `return Timer(...)` — is cancellable by whoever holds it, and ownership is
// then that holder's business rather than this detector's.
//
// A discarded timer that does NOT complete a Completer is ordinary
// fire-and-forget deferral (`Timer(d, () => _log('late'))`). It cannot strand
// an awaiting caller, so it is deliberately out of scope: widening to every
// discarded timer would flag dozens of benign sites and make the zero floor
// unreachable.
//
// Why an AST and not a regex
// --------------------------
// Three reasons, each of which the sibling detectors already hit:
//
//   • `dart format` wraps long argument lists, so the `Timer(` and the
//     `completer.complete` it hands off to routinely land on different lines.
//     A line-oriented scan sees neither half of the pair.
//   • Whether the timer's value is discarded is a question about the enclosing
//     node, not about the text. `_t = Timer(d, c.complete);` and
//     `Timer(d, c.complete);` differ by an assignment a grep cannot weigh.
//   • `Timer(` appears in comments, doc examples, and string literals — this
//     file's own header is one — and none of those schedule anything.
//
// Exit codes: 0 clean run, 2 bad usage / unreadable scan dir.
import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

/// Members of `Completer` that settle it, and therefore release an awaiter.
const _completerSettlers = {'complete', 'completeError'};

/// Whether [path] belongs to a production library scanned by this ratchet.
///
/// The command receives the broad `lib` and `packages` roots, so this predicate
/// is the boundary that keeps package tests and integration tests out of the
/// production-only zero floor.
bool shouldScanUncancellableTimerWaitFile(String path) {
  final normalized = path.replaceAll(r'\', '/');
  final segments = normalized
      .split('/')
      .where((segment) => segment.isNotEmpty)
      .toList();
  if (segments.contains('test') || segments.contains('integration_test')) {
    return false;
  }
  final packagesIndex = segments.indexOf('packages');
  if (packagesIndex >= 0 &&
      (segments.length <= packagesIndex + 2 ||
          segments[packagesIndex + 2] != 'lib')) {
    return false;
  }
  return normalized.endsWith('.dart') && !_isGenerated(normalized);
}

/// Generated files carry no hand-written waits and are never edited by hand.
bool _isGenerated(String path) =>
    path.endsWith('.g.dart') ||
    path.endsWith('.freezed.dart') ||
    path.endsWith('.gr.dart') ||
    path.endsWith('.config.dart') ||
    path.endsWith('.mocks.dart') ||
    path.contains('/l10n/generated/') ||
    path.contains('/.dart_tool/') ||
    path.contains('/build/');

/// One uncancellable timer-backed wait, as reported by
/// [findUncancellableTimerWaitsInSource].
class UncancellableTimerWait {
  const UncancellableTimerWait({required this.line, required this.snippet});

  /// 1-based line of the offending statement.
  final int line;

  /// The statement, whitespace-collapsed, for `--detail` output.
  final String snippet;

  @override
  String toString() => 'UncancellableTimerWait(line: $line)';
}

/// Finds discarded `Timer`s that settle a `Completer` in [source].
///
/// [path] is used only for diagnostics. Returns an empty list for source that
/// cannot be parsed, since the analyzer reports that separately.
List<UncancellableTimerWait> findUncancellableTimerWaitsInSource(
  String source, {
  required String path,
}) {
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
  final visitor = _Visitor(parsed.lineInfo, _SameFileFunctions(parsed.unit));
  parsed.unit.accept(visitor);
  return visitor.sites;
}

class _Visitor extends RecursiveAstVisitor<void> {
  _Visitor(this._lineInfo, this._functions);

  final LineInfo _lineInfo;
  final _SameFileFunctions _functions;
  final List<UncancellableTimerWait> sites = [];

  @override
  void visitExpressionStatement(ExpressionStatement node) {
    super.visitExpressionStatement(node);

    final expression = node.expression;
    final ArgumentList arguments;

    // `Timer(d, cb)` and `Timer.periodic(d, cb)` both parse as a
    // MethodInvocation in an unresolved AST; `new Timer(...)` keeps the
    // InstanceCreationExpression shape.
    if (expression is MethodInvocation) {
      if (!_isTimerConstruction(expression)) return;
      arguments = expression.argumentList;
    } else if (expression is InstanceCreationExpression) {
      if (expression.constructorName.type.name.lexeme != 'Timer') return;
      arguments = expression.argumentList;
    } else {
      return;
    }

    if (!_completesACompleter(arguments)) return;

    final location = _lineInfo.getLocation(node.offset);
    sites.add(
      UncancellableTimerWait(
        line: location.lineNumber,
        snippet: node.toString().replaceAll(RegExp(r'\s+'), ' '),
      ),
    );
  }

  bool _isTimerConstruction(MethodInvocation node) {
    final target = node.target;
    if (target == null) return node.methodName.name == 'Timer';
    return target is SimpleIdentifier &&
        target.name == 'Timer' &&
        node.methodName.name == 'periodic';
  }

  /// Whether any argument settles a `Completer`, as a tear-off or in a closure.
  bool _completesACompleter(ArgumentList arguments) {
    for (final argument in arguments.arguments) {
      final expression = argument is NamedArgument
          ? argument.argumentExpression
          : argument as Expression;

      // Tear-off: `completer.complete`
      if (expression is PrefixedIdentifier &&
          _completerSettlers.contains(expression.identifier.name)) {
        return true;
      }
      if (expression is PropertyAccess &&
          _completerSettlers.contains(expression.propertyName.name)) {
        return true;
      }

      // Closure: `() => completer.complete()` / `(_) { completer.complete(); }`
      if (expression is FunctionExpression) {
        final finder = _SettlerFinder(_functions);
        expression.body.accept(finder);
        if (finder.found) return true;
      }

      // Same-file callback: `Timer(delay, completeSearch)` or a class method
      // tear-off `Timer(delay, _fire)`. Following the declaration is essential
      // because named callbacks are the natural form when a timeout shares its
      // completion path with EOSE or another signal.
      if (expression is SimpleIdentifier) {
        final finder = _SettlerFinder(_functions);
        finder.follow(expression.name, expression);
        if (finder.found) return true;
      }
    }
    return false;
  }
}

/// Finds a `…complete(…)` / `…completeError(…)` call inside a callback body.
class _SettlerFinder extends RecursiveAstVisitor<void> {
  _SettlerFinder(this._functions, [Set<FunctionBody>? activeHelpers])
    : _activeHelpers = activeHelpers ?? <FunctionBody>{};

  final _SameFileFunctions _functions;
  final Set<FunctionBody> _activeHelpers;
  bool found = false;

  void follow(String name, AstNode callSite, {int? argumentCount}) {
    final helper = _functions.resolve(name, callSite);
    if (helper == null || !_activeHelpers.add(helper.body)) return;
    // An *async* method with arguments is ordinary work
    // (`subscribeToVideoFeed(...)`). Following it walks the class and
    // false-positives fire-and-forget timers whose callback happens to call a
    // method that contains an unrelated `x.complete()`. Sync methods, even
    // with arguments, are the completion-helper shape (`_finish(c)`,
    // `_settle(ok: true)`). Empty-arg methods and tear-offs stay in scope.
    if (helper.isMethod &&
        argumentCount != null &&
        argumentCount > 0 &&
        helper.body.isAsynchronous) {
      _activeHelpers.remove(helper.body);
      return;
    }
    helper.body.accept(this);
    _activeHelpers.remove(helper.body);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.target != null &&
        _completerSettlers.contains(node.methodName.name)) {
      found = true;
    }
    if (!found && node.target == null) {
      follow(
        node.methodName.name,
        node,
        argumentCount: node.argumentList.arguments.length,
      );
    }
    super.visitMethodInvocation(node);
  }
}

/// Directly callable top-level and lexically-visible local functions.
class _SameFileFunctions {
  _SameFileFunctions(CompilationUnit unit) {
    unit.accept(_FunctionDeclarationCollector(_byName));
  }

  final _byName = <String, List<_FunctionBody>>{};

  _FunctionBody? resolve(String name, AstNode callSite) {
    final candidates = _byName[name];
    if (candidates == null) return null;
    final visible = candidates.where((candidate) {
      final scope = candidate.scope;
      return scope == null || _isAncestorOf(scope, callSite);
    }).toList();
    if (visible.isEmpty) return null;
    visible.sort(
      (a, b) => _ancestorDepth(b.scope).compareTo(_ancestorDepth(a.scope)),
    );
    return visible.first;
  }

  static bool _isAncestorOf(AstNode ancestor, AstNode node) {
    for (AstNode? current = node; current != null; current = current.parent) {
      if (identical(current, ancestor)) return true;
    }
    return false;
  }

  static int _ancestorDepth(AstNode? node) {
    var depth = 0;
    for (var current = node; current != null; current = current.parent) {
      depth++;
    }
    return depth;
  }
}

class _FunctionBody {
  const _FunctionBody(this.body, this.scope, {this.isMethod = false});

  final FunctionBody body;
  final AstNode? scope;
  final bool isMethod;
}

class _FunctionDeclarationCollector extends RecursiveAstVisitor<void> {
  _FunctionDeclarationCollector(this.byName);

  final Map<String, List<_FunctionBody>> byName;

  void _add(
    String name,
    FunctionBody body,
    AstNode? scope, {
    bool isMethod = false,
  }) {
    byName
        .putIfAbsent(name, () => [])
        .add(_FunctionBody(body, scope, isMethod: isMethod));
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
    // Instance/static methods are the ordinary callback shape on the owners
    // this ratchet is for. A local function is already collected above;
    // without this visit, `Timer(d, _fire)` and `Timer(d, () => _fire())`
    // where `_fire` is a class method are invisible.
    _add(node.name.lexeme, node.body, node.parent, isMethod: true);
    super.visitMethodDeclaration(node);
  }
}

void main(List<String> args) {
  final scanDirs = <String>[];
  var pathPrefix = '';
  var detail = false;

  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--path-prefix':
        if (++i >= args.length) _usage();
        pathPrefix = args[i];
      case '--detail':
        detail = true;
      default:
        if (args[i].startsWith('--')) _usage();
        scanDirs.add(args[i]);
    }
  }
  if (scanDirs.isEmpty) _usage();

  final counts = <String, int>{};
  final details = <String>[];

  for (final scanDir in scanDirs) {
    final directory = Directory(scanDir);
    if (!directory.existsSync()) {
      stderr.writeln(
        'uncancellable_timer_wait_detector: no such dir: $scanDir',
      );
      exit(2);
    }

    final files =
        directory
            .listSync(recursive: true, followLinks: false)
            .whereType<File>()
            .where((f) => shouldScanUncancellableTimerWaitFile(f.path))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));

    for (final file in files) {
      final sites = findUncancellableTimerWaitsInSource(
        file.readAsStringSync(),
        path: file.path,
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
    return;
  }

  final paths = counts.keys.toList()..sort();
  for (final path in paths) {
    stdout.writeln('$path\t${counts[path]}');
  }
}

Never _usage() {
  stderr.writeln(
    'usage: uncancellable_timer_wait_detector.dart <scan-dir>... '
    '[--path-prefix <dir>] [--detail]',
  );
  exit(2);
}
