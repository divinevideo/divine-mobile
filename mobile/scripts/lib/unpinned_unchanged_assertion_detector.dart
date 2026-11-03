// ABOUTME: Detector behind check_unpinned_unchanged_assertions.sh — finds
// ABOUTME: "unchanged" assertions whose baseline read was never pinned (#8617).
//
// Usage (from mobile/):
//   dart run scripts/lib/unpinned_unchanged_assertion_detector.dart <scan-dir>... [options]
//     --path-prefix <dir>   strip this prefix from reported paths
//     --detail              one line per site instead of per-file counts
//     --all                 also report pairs sitting beside other assertions
//
// Output (default): `relpath<TAB>count`, one line per file with >0 sites,
// sorted by path — the shape scripts/lib/numeric_ratchet.sh consumes.
//
// What counts
// -----------
// An UNPINNED RE-READ: a test reads a value into a local, acts, then asserts
// the same read still equals the local, without ever asserting what the local
// held:
//
//   service.markReady();
//   final first = service.readyTime;
//   service.markReady();
//   expect(service.readyTime, equals(first));
//
// Both operands come from the state under test, so when the method is a total
// no-op the assertion compares null with null (or 0 with 0, or an empty list
// with itself) and passes. #8617 found one that survived exactly that mutant:
// the method never ran, the latch stayed null, and the test stayed green. The
// assertion claims the value did not change without proving the value existed.
//
// By default only a pair that is the test's ONLY assertion is reported — the
// test has nothing else that could fail, which is the shape #8617 hit and the
// one frozen at zero. `--all` also lists pairs sitting beside other
// assertions; those are worth a pin when touched, but the sibling may already
// prove the mechanism ran, so they are not frozen.
//
// What pins a baseline
// --------------------
// A site does NOT count when the same test body asserts something about the
// local, or about the expression it was read from, anywhere else:
// `expect(first, isNotNull)`, `expect(first, hasLength(2))`,
// `expect(cubit.state.status, ready)` before `final last = cubit.state`, or a
// `first!` that would throw on null. A read derived from a collection —
// `videos.length`, `rows.first` — is also pinned by an expect on the
// collection itself (`expect(videos, isNotEmpty)`). A pin that appears AFTER
// the re-read still counts — the test fails either way. Another
// unchanged-assertion on the same pair is not a pin; two of them are as
// vacuous as one.
//
// A read that cannot come back absent is its own pin. The single-result
// `tester.*` queries (`tester.state`, `tester.getSize`, ...) throw on an empty
// finder, and a Riverpod `container.read(fooProvider)`, `ref.watch(fooProvider)`
// or bloc `context.read<T>()` returns the provided value or throws. Two such
// reads compared with `same()` cannot pass on null == null, so the pair is not
// reported. A provider that is declared nullable is the known gap; that is the
// recoverable direction, since under-reporting leaves a test in place while a
// false positive invites a pin nobody needed. There is no inline escape hatch,
// for the same reason check_placeholder_tests.sh has none: an assertion the
// scan cannot see is one line away from being one it can.
//
// What does NOT count
// -------------------
// A local the test chose itself — a literal, a constructor call, a `copyWith`
// — is not a baseline read, so `expect(state, equals(expected))` against it is
// a real assertion. Without resolution a constructor call parses as a method
// invocation, so an invocation whose name or receiver is capitalised is taken
// to construct.
//
// A negative claim whose baseline is pinned — "polling has stopped" after
// `expect(cubit.state.status, readyToPublish)` — is the shape this guard
// pushes work toward and is not reported. An unpinned negative claim IS
// reported: `before = reads; reset(); expect(reads, before)` cannot tell "the
// sweep was cancelled" from "the sweep never ran", and the cure is the same
// one-line pin. Whether the claim is positive or negative is not a property a
// parser can read off a description, and the fix does not depend on it.
//
// Why an AST and not a regex
// --------------------------
// `dart format` wraps `expect(` argument lists, so the local, the re-read and
// the matcher regularly sit on different lines; the single-line regex that
// preceded this detector found 62 sites and the AST found more in the same
// tree. Whether the pair is pinned is a property of the whole test body, and a
// `toSource()` comparison sees through wrapping that a text match cannot.
//
// Exit codes: 0 clean run, 2 bad usage / unreadable scan dir.
import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

/// Calls that declare a test case whose body can be judged.
const _testDeclarations = {'test', 'testWidgets', 'patrolTest'};

/// Calls that compare an actual value with a matcher.
const _assertions = {'expect', 'expectLater', 'expectSync'};

/// Everything else that asserts. A pair sitting beside one of these is not a
/// lone assertion, so strict mode leaves it alone.
const _otherAssertions = {
  'verify',
  'verifyInOrder',
  'verifyNever',
  'verifyNoMoreInteractions',
  'verifyZeroInteractions',
  'fail',
  'matchesGoldenFile',
};

/// Matchers that assert identity or equality with their single argument.
const _identityMatchers = {
  'equals',
  'same',
  'orderedEquals',
  'unorderedEquals',
};

/// One assertion that a no-op under test would satisfy.
class UnpinnedUnchangedAssertion {
  UnpinnedUnchangedAssertion({
    required this.path,
    required this.line,
    required this.baseline,
    required this.read,
    required this.test,
    required this.sole,
  });

  final String path;
  final int line;

  /// The local holding the first read.
  final String baseline;

  /// The expression read again in the assertion.
  final String read;

  /// The enclosing test's description.
  final String test;

  /// True when every assertion in the test body is one of these pairs — the
  /// test has nothing else that could fail. Strict mode reports only these.
  final bool sole;
}

void main(List<String> args) {
  final positional = <String>[];
  var pathPrefix = '';
  var detail = false;
  var all = false;
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--path-prefix':
        pathPrefix = i + 1 < args.length ? args[++i] : '';
      case '--detail':
        detail = true;
      case '--all':
        all = true;
      default:
        positional.add(args[i]);
    }
  }
  if (positional.isEmpty) {
    stderr.writeln(
      'usage: unpinned_unchanged_assertion_detector.dart <scan-dir>... '
      '[--path-prefix <dir>] [--detail] [--all]',
    );
    exit(2);
  }
  final dirs = <Directory>[];
  for (final path in positional) {
    final dir = Directory(path);
    if (!dir.existsSync()) {
      stderr.writeln('not a directory: $path');
      exit(2);
    }
    dirs.add(dir);
  }
  if (pathPrefix.isEmpty) pathPrefix = dirs.first.path;

  final sites = findUnpinnedUnchangedAssertions(
    dirs,
    pathPrefix: pathPrefix,
  ).where((site) => all || site.sole).toList();
  if (detail) {
    for (final site in sites) {
      final shape = site.sole ? 'sole' : 'beside';
      stdout.writeln(
        '${site.path}:${site.line}\t$shape\t'
        '${site.baseline} <- ${site.read}\t${site.test}',
      );
    }
    return;
  }
  final counts = <String, int>{};
  for (final site in sites) {
    counts[site.path] = (counts[site.path] ?? 0) + 1;
  }
  final paths = counts.keys.toList()..sort();
  for (final path in paths) {
    stdout.writeln('$path\t${counts[path]}');
  }
}

/// Scans every `*_test.dart` file under [dirs] and returns the sites in
/// path-then-line order.
List<UnpinnedUnchangedAssertion> findUnpinnedUnchangedAssertions(
  List<Directory> dirs, {
  required String pathPrefix,
}) {
  final files = <File>[];
  for (final dir in dirs) {
    files.addAll(
      dir.listSync(recursive: true).whereType<File>().where(isTestFile),
    );
  }
  files.sort((a, b) => a.path.compareTo(b.path));

  final sites = <UnpinnedUnchangedAssertion>[];
  for (final file in files) {
    final String source;
    try {
      source = file.readAsStringSync();
    } on Object catch (error) {
      // Never swallow this: an unreadable file drops its sites, which reads to
      // the ratchet as a file somebody cleaned up.
      stderr.writeln(
        'unpinned_unchanged_assertion_detector: skipped ${file.path} ($error)',
      );
      continue;
    }
    final relative = file.path.startsWith('$pathPrefix/')
        ? file.path.substring(pathPrefix.length + 1)
        : file.path;
    sites.addAll(
      findUnpinnedUnchangedAssertionsInSource(source, path: relative),
    );
  }
  return sites;
}

/// True for a file the Dart test runner would pick up as a suite.
///
/// Matching is per path SEGMENT, not `contains('/test/')` — a scan rooted at a
/// relative `test` yields `test/foo_test.dart`, which has no leading slash and
/// would silently match nothing.
bool isTestFile(File file) {
  final path = file.path;
  if (!path.endsWith('_test.dart')) return false;
  final segments = path.split('/');
  final directories = segments.sublist(0, segments.length - 1);
  if (directories.any(_excludedDirectories.contains)) return false;
  return directories.any(_testDirectories.contains);
}

const _testDirectories = {'test', 'integration_test'};
const _excludedDirectories = {'.dart_tool', 'build', '.worktrees'};

/// Parses [source] and returns every site in it.
List<UnpinnedUnchangedAssertion> findUnpinnedUnchangedAssertionsInSource(
  String source, {
  required String path,
}) {
  final parsed = parseString(
    content: source,
    path: path,
    featureSet: FeatureSet.latestLanguageVersion(),
    throwIfDiagnostics: false,
  );
  final visitor = _TestVisitor(path: path, lineInfo: parsed.lineInfo);
  parsed.unit.accept(visitor);
  return visitor.sites;
}

class _TestVisitor extends RecursiveAstVisitor<void> {
  _TestVisitor({required this.path, required this.lineInfo});

  final String path;
  final LineInfo lineInfo;
  final sites = <UnpinnedUnchangedAssertion>[];

  @override
  void visitMethodInvocation(MethodInvocation node) {
    // `harness.test(...)` is a method on another object, not a declaration.
    if (node.realTarget == null &&
        _testDeclarations.contains(node.methodName.name)) {
      final callback = _callbackOf(node);
      if (callback != null) {
        final scan = _BodyScan();
        callback.body.accept(scan);
        final args = node.argumentList.arguments;
        sites.addAll(
          scan.report(
            path: path,
            lineInfo: lineInfo,
            test: args.isEmpty ? '' : _describe(args.first),
          ),
        );
      }
    }
    super.visitMethodInvocation(node);
  }

  FunctionExpression? _callbackOf(MethodInvocation node) {
    for (final argument in node.argumentList.arguments) {
      if (argument is FunctionExpression) return argument;
    }
    return null;
  }

  String _describe(Argument first) {
    final text = first.toSource().replaceAll(RegExp(r'\s+'), ' ');
    return text.length <= 70 ? text : '${text.substring(0, 67)}...';
  }
}

/// Members whose value is derived from a collection, so a pin on the
/// collection itself (`expect(videos, isNotEmpty)`) pins the read too.
const _derivedMembers = {
  'length',
  'isEmpty',
  'isNotEmpty',
  'first',
  'last',
  'single',
  'keys',
  'values',
  'entries',
};

/// A local initialised from a read of state.
class _Baseline {
  _Baseline({
    required this.name,
    required this.offset,
    required this.read,
    required this.receiver,
    required this.cannotBeAbsent,
  });

  final String name;
  final int offset;
  final String read;

  /// True for a lookup that throws, or returns the provided value, when
  /// nothing is there — a pair built on it cannot pass on null == null.
  final bool cannotBeAbsent;

  /// The collection a derived member was read from (`videos` for
  /// `videos.length`), or null when the member is ordinary state.
  final String? receiver;
}

/// One `expect`-shaped call: the actual value and the unwrapped matcher.
class _Assertion {
  _Assertion({required this.node, required this.actual, required this.matcher});

  final MethodInvocation node;
  final Expression actual;
  final Expression matcher;
}

/// Collects the baselines, assertions and null-assertions of one test body.
class _BodyScan extends RecursiveAstVisitor<void> {
  final _baselines = <_Baseline>[];
  final _found = <_Assertion>[];
  final _bangs = <String>{};
  var _otherAssertionCount = 0;

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    final initializer = node.initializer;
    if (initializer != null) {
      final read = _strip(initializer);
      if (_isStateRead(read)) {
        _baselines.add(
          _Baseline(
            name: node.name.lexeme,
            offset: node.offset,
            read: read.toSource(),
            receiver: _derivedReceiverOf(read),
            cannotBeAbsent: _cannotBeAbsent(read),
          ),
        );
      }
    }
    super.visitVariableDeclaration(node);
  }

  @override
  void visitPostfixExpression(PostfixExpression node) {
    if (node.operator.type == TokenType.BANG) {
      _bangs.add(node.operand.toSource());
    }
    super.visitPostfixExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.realTarget == null &&
        _otherAssertions.contains(node.methodName.name)) {
      _otherAssertionCount++;
    }
    if (node.realTarget == null && _assertions.contains(node.methodName.name)) {
      final positional = node.argumentList.arguments
          .whereType<Expression>()
          .toList();
      if (positional.length < 2) _otherAssertionCount++;
      if (positional.length >= 2) {
        _found.add(
          _Assertion(
            node: node,
            actual: _strip(positional[0]),
            matcher: _unwrapMatcher(positional[1]),
          ),
        );
      }
    }
    super.visitMethodInvocation(node);
  }

  List<UnpinnedUnchangedAssertion> report({
    required String path,
    required LineInfo lineInfo,
    required String test,
  }) {
    final flagged = <(_Assertion, _Baseline, String)>[];
    for (final assertion in _found) {
      final actual = assertion.actual.toSource();
      final matcher = assertion.matcher.toSource();

      _Baseline? baseline;
      String? read;
      if (assertion.matcher is SimpleIdentifier) {
        baseline = _baselineFor(
          matcher,
          before: assertion.node.offset,
          read: actual,
        );
        read = actual;
      }
      if (baseline == null && assertion.actual is SimpleIdentifier) {
        baseline = _baselineFor(
          actual,
          before: assertion.node.offset,
          read: matcher,
        );
        read = matcher;
      }
      if (baseline == null || read == null) continue;
      if (_isPinned(baseline, read)) continue;
      flagged.add((assertion, baseline, read));
    }
    final sole = _otherAssertionCount == 0 && flagged.length == _found.length;
    return [
      for (final (assertion, baseline, read) in flagged)
        UnpinnedUnchangedAssertion(
          path: path,
          line: lineInfo.getLocation(assertion.node.offset).lineNumber,
          baseline: baseline.name,
          read: read,
          test: test,
          sole: sole,
        ),
    ];
  }

  /// The nearest preceding local named [name] that was read from [read].
  _Baseline? _baselineFor(
    String name, {
    required int before,
    required String read,
  }) {
    _Baseline? found;
    for (final baseline in _baselines) {
      if (baseline.name == name &&
          baseline.offset < before &&
          baseline.read == read) {
        found = baseline;
      }
    }
    return found;
  }

  /// Whether anything in the body asserts on the local or on the expression
  /// it was read from, other than comparing the two with each other.
  bool _isPinned(_Baseline baseline, String read) {
    if (baseline.cannotBeAbsent) return true;
    if (_bangs.contains(baseline.name)) return true;
    final receiver = baseline.receiver;
    for (final other in _found) {
      final actual = other.actual.toSource();
      final matcher = other.matcher.toSource();
      final comparesThePair =
          (actual == read && matcher == baseline.name) ||
          (actual == baseline.name && matcher == read);
      if (comparesThePair) continue;
      if (_covers(actual, baseline.name) || _covers(actual, read)) return true;
      if (receiver != null && _covers(actual, receiver)) return true;
    }
    return false;
  }
}

/// Whether [source] is [target] itself or a member/index/null-check of it.
bool _covers(String source, String target) =>
    source == target ||
    source.startsWith('$target.') ||
    source.startsWith('$target!') ||
    source.startsWith('$target?.') ||
    source.startsWith('$target[');

/// Removes `await` and parentheses so `await x.y` and `(x.y)` compare as `x.y`.
Expression _strip(Expression expression) {
  var current = expression;
  while (true) {
    if (current is AwaitExpression) {
      current = current.expression;
    } else if (current is ParenthesizedExpression) {
      current = current.expression;
    } else {
      return current;
    }
  }
}

/// `equals(x)` / `same(x)` / `orderedEquals(x)` unwrap to `x`.
Expression _unwrapMatcher(Expression matcher) {
  final stripped = _strip(matcher);
  if (stripped is MethodInvocation &&
      stripped.realTarget == null &&
      _identityMatchers.contains(stripped.methodName.name)) {
    final positional = stripped.argumentList.arguments
        .whereType<Expression>()
        .toList();
    if (positional.length == 1) return _strip(positional.single);
  }
  return stripped;
}

/// The collection behind a derived read (`videos` for `videos.length`), or
/// null when the final member is ordinary state such as `service.readyTime`.
String? _derivedReceiverOf(Expression expression) {
  final (String? member, Expression? target) = switch (expression) {
    PropertyAccess(:final propertyName, :final realTarget) => (
      propertyName.name,
      realTarget,
    ),
    PrefixedIdentifier(:final identifier, :final prefix) => (
      identifier.name,
      prefix,
    ),
    _ => (null, null),
  };
  if (member == null || target == null) return null;
  return _derivedMembers.contains(member) ? target.toSource() : null;
}

/// Whether [expression] reads state rather than constructing a value.
///
/// A literal, a constructor call, a `copyWith` or a collection literal is a
/// value the test chose, so comparing state against it is a real assertion. A
/// property, index, call or identifier is a read whose result the test did
/// not choose. Without resolution a constructor call parses as a method
/// invocation, so an invocation whose name or receiver is capitalised is
/// taken to construct.
bool _isStateRead(Expression expression) {
  if (expression is MethodInvocation) return !_constructs(expression);
  return expression is PropertyAccess ||
      expression is PrefixedIdentifier ||
      expression is IndexExpression ||
      expression is SimpleIdentifier ||
      expression is FunctionExpressionInvocation ||
      (expression is PostfixExpression &&
          expression.operator.type == TokenType.BANG);
}

final _capitalised = RegExp('^[A-Z]');

/// `tester` queries that throw on an empty finder instead of returning null.
/// `widgetList` and friends are deliberately absent: they return an iterable
/// that can be empty.
const _throwingTesterQueries = {
  'state',
  'widget',
  'element',
  'renderObject',
  'getSemantics',
  'getSize',
  'getRect',
  'getCenter',
  'getTopLeft',
  'getTopRight',
  'getBottomLeft',
  'getBottomRight',
  'firstState',
  'firstWidget',
  'firstElement',
  'firstRenderObject',
};

/// Whether [read] is a lookup that throws, or returns the provided value, when
/// nothing is there: a single-result `tester` query, or a provider read such as
/// `container.read(fooProvider)`, `ref.watch(fooProvider)` or
/// `context.read<FooBloc>()`. `Type.of(...)` lookups never reach here because
/// [_constructs] already treats a capitalised receiver as a construction.
bool _cannotBeAbsent(Expression read) {
  if (read is! MethodInvocation) return false;
  final name = read.methodName.name;
  final target = read.realTarget;
  if (target is SimpleIdentifier && target.name == 'tester') {
    return _throwingTesterQueries.contains(name);
  }
  if (name != 'read' && name != 'watch') return false;
  final positional = read.argumentList.arguments
      .whereType<Expression>()
      .toList();
  if (positional.isEmpty) return read.typeArguments != null;
  return positional.length == 1 &&
      positional.single.toSource().contains('Provider');
}

bool _constructs(MethodInvocation invocation) {
  final name = invocation.methodName.name;
  if (name == 'copyWith') return true;
  final target = invocation.realTarget;
  if (target == null) return _capitalised.hasMatch(name);
  return target is SimpleIdentifier && _capitalised.hasMatch(target.name);
}
