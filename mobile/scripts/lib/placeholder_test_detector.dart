// ABOUTME: Detector behind check_placeholder_tests.sh — finds tests that pass
// ABOUTME: detects empty test files and groups too (#3340, #9146).
//
// Usage (from mobile/):
//   dart run scripts/lib/placeholder_test_detector.dart <scan-dir>... [options]
//     --path-prefix <dir>   strip this prefix from reported paths
//     --detail              one line per site instead of per-file counts
//
// Output (default): `relpath<TAB>count`, one line per file with >0 sites,
// sorted by path — the shape scripts/lib/numeric_ratchet.sh consumes.
//
// What counts
// -----------
// 1. TAUTOLOGY — a `test` / `testWidgets` / `patrolTest` whose every assertion
//    is trivially satisfied: `expect(true, isTrue)`, `expect(false, isFalse)`,
//    `expect(1, 1)`, `expect(x, equals(x))` for a literal x. The test cannot
//    fail, so a green run says nothing about the product.
// 2. NO DECLARATIONS — a `*_test.dart` file whose source declares no `test` /
//    `testWidgets` / `blocTest` / `patrolTest` / `group` at all. That is the
//    end state a gutted suite decays into, and the runner reports the file as
//    a passing suite.
// 3. EMPTY GROUP — a `group` whose callback tree declares no `test` /
//    `testWidgets` / `blocTest` / `patrolTest`. Lifecycle calls do not count,
//    and their callbacks are not searched: a `when(...)` inside `setUp` does
//    not turn an empty suite into a populated one. An unknown bare invocation
//    is conservatively treated as a possible test-declaring helper. Both
//    imported helpers such as `defineFutureDelayedCeilingTests` and local
//    wrappers such as `testWidgetsWithSurfaceSize` require that exemption.
//
// All three come from .claude/rules/testing.md: "A passing test should be
// evidence that the feature works. If the test would still pass with the
// feature broken, it tests nothing." A tautology is named there explicitly.
//
// What does NOT count
// -------------------
// A test with NO assertion at all. Assertions reach a test through too many
// routes to judge from one file: drift's `verifier.migrateAndValidate` throws
// on mismatch, `expectMeetsAccessibilityGuidelines` is imported from a helper
// library, and cross-file resolution is out of scope here for the same reason
// it is in ungrouped_test_detector.dart. Flagging those would put ~20 good
// tests on a debt list, and a guard that cries wolf gets switched off. The
// no-assertion population is real but needs helper-aware triage, not a gate.
//
// A `main()` that only forwards — `void main() => platform.main();` — is
// exempt from rule 2. That is the conditional-import dispatcher shape
// (`html_video_element_backend_web_test.dart`), where the declarations live in
// the platform library this file selects. The exemption is the SHAPE, not an
// allowlist: the body must be a single call to something named `main`.
//
// A tautology sitting beside a real assertion is not flagged, because the test
// as a whole can still fail. If an IMPORTED helper is the only real assertion,
// the tautology beside it is flagged — and deleting a line that asserts
// nothing is the right answer there too.
//
// Why an AST and not a regex
// --------------------------
// `dart format` wraps long argument lists, so `expect(true, isTrue)` is spelt
// on one line or four depending on what surrounds it. In
// `test/widget/tdd/accessibility_ui_test.dart` a line-oriented scan found 14
// of the file's 38 tautologies for exactly that reason. A regex also cannot
// tell an assertion in code from one quoted in a string or a comment, and
// cannot see whether the tautology is the test's ONLY assertion — which is the
// whole question, since `expect(true, isTrue)` next to real assertions is
// merely noise.
//
// Exit codes: 0 clean run, 2 bad usage / unreadable scan dir.
import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

/// Calls that declare a test case whose body can be judged.
const _testDeclarations = {'test', 'testWidgets', 'patrolTest'};

/// Everything that registers something with the runner, for rule 2.
const _anyDeclaration = {
  'test',
  'testWidgets',
  'blocTest',
  'patrolTest',
  'group',
};

/// Calls that configure a suite without declaring a test case.
///
/// Their callbacks are setup/cleanup code, so calls inside them cannot prove
/// that the surrounding group contains a test.
const _lifecycleDeclarations = {
  'setUp',
  'setUpAll',
  'tearDown',
  'tearDownAll',
  'addTearDown',
  'registerFallbackValue',
  'expect',
};

/// Calls that assert. A body whose assertions are all tautologies is rule 1.
const _assertions = {
  'expect',
  'expectLater',
  'expectSync',
  'verify',
  'verifyInOrder',
  'verifyNever',
  'verifyNoMoreInteractions',
  'verifyZeroInteractions',
  'fail',
  'matchesGoldenFile',
};

/// Why a site was reported.
enum PlaceholderKind {
  /// Every assertion in the body is trivially satisfied.
  tautology,

  /// The file declares no test at all.
  noDeclarations,

  /// A group's callback tree declares no test case.
  emptyGroup,
}

/// One test that cannot fail, or one file that declares none.
class PlaceholderTest {
  PlaceholderTest({
    required this.path,
    required this.line,
    required this.kind,
    required this.description,
  });

  final String path;
  final int line;
  final PlaceholderKind kind;

  /// The test's description, or `<no test declarations>` for a whole file.
  final String description;
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
  if (positional.isEmpty) {
    stderr.writeln(
      'usage: placeholder_test_detector.dart <scan-dir>... '
      '[--path-prefix <dir>] [--detail]',
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

  final sites = findPlaceholderTests(dirs, pathPrefix: pathPrefix);
  if (detail) {
    for (final site in sites) {
      stdout.writeln(
        '${site.path}:${site.line}\t${site.kind.name}\t${site.description}',
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
List<PlaceholderTest> findPlaceholderTests(
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

  final sites = <PlaceholderTest>[];
  for (final file in files) {
    final String source;
    try {
      source = file.readAsStringSync();
    } on Object catch (error) {
      // Never swallow this: an unreadable file drops its sites, which reads to
      // the ratchet as a file somebody cleaned up.
      stderr.writeln(
        'placeholder_test_detector: skipped ${file.path} ($error)',
      );
      continue;
    }
    final relative = file.path.startsWith('$pathPrefix/')
        ? file.path.substring(pathPrefix.length + 1)
        : file.path;
    sites.addAll(findPlaceholderTestsInSource(source, path: relative));
  }
  return sites;
}

/// True for a file the Dart test runner would pick up as a suite.
///
/// `*_test.dart` alone is not enough: a matching file under `lib/` is library
/// code, and `test_driver/integration_test.dart` is the driver entry point.
/// Neither is a suite, so neither is held to these rules.
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

/// Parses [source] and returns every placeholder site in it.
List<PlaceholderTest> findPlaceholderTestsInSource(
  String source, {
  required String path,
}) {
  final parsed = parseString(
    content: source,
    path: path,
    featureSet: FeatureSet.latestLanguageVersion(),
    throwIfDiagnostics: false,
  );
  final visitor = _PlaceholderVisitor(path: path, lineInfo: parsed.lineInfo);
  parsed.unit.accept(visitor);

  final sites = visitor.sites;
  if (!visitor.declaresAnyTest && !_isPureDelegation(parsed.unit)) {
    sites.insert(
      0,
      PlaceholderTest(
        path: path,
        line: 1,
        kind: PlaceholderKind.noDeclarations,
        description: '<no test declarations>',
      ),
    );
  }
  return sites;
}

/// True when `main()` does nothing but call another library's `main`.
///
/// That is the conditional-import dispatcher: the declarations live in whichever
/// platform library the import selects, so this file legitimately has none.
bool _isPureDelegation(CompilationUnit unit) {
  for (final declaration in unit.declarations) {
    if (declaration is! FunctionDeclaration) continue;
    if (declaration.name.lexeme != 'main') continue;
    final body = declaration.functionExpression.body;
    final Expression? expression;
    if (body is ExpressionFunctionBody) {
      expression = body.expression;
    } else if (body is BlockFunctionBody &&
        body.block.statements.length == 1 &&
        body.block.statements.single is ExpressionStatement) {
      expression =
          (body.block.statements.single as ExpressionStatement).expression;
    } else {
      expression = null;
    }
    final call = expression is AwaitExpression
        ? expression.expression
        : expression;
    return call is MethodInvocation && call.methodName.name == 'main';
  }
  return false;
}

class _PlaceholderVisitor extends RecursiveAstVisitor<void> {
  _PlaceholderVisitor({required this.path, required this.lineInfo});

  final String path;
  final LineInfo lineInfo;
  final sites = <PlaceholderTest>[];

  /// Whether the file registers anything at all with the runner.
  bool declaresAnyTest = false;

  /// Number of empty groups whose callbacks are currently being visited.
  int emptyGroupDepth = 0;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    // `harness.test(...)` is a method on another object, not a declaration.
    if (node.realTarget == null) {
      final name = node.methodName.name;
      if (_anyDeclaration.contains(name)) declaresAnyTest = true;
      if (name == 'group') {
        final body = _callbackOf(node);
        if (body != null) {
          final scan = _GroupScan();
          body.body.accept(scan);
          if (!scan.declaresTest) {
            if (emptyGroupDepth == 0) {
              final args = node.argumentList.arguments;
              sites.add(
                PlaceholderTest(
                  path: path,
                  line: lineInfo.getLocation(node.offset).lineNumber,
                  kind: PlaceholderKind.emptyGroup,
                  description: args.isEmpty ? '' : _describe(args.first),
                ),
              );
            }
            emptyGroupDepth++;
            super.visitMethodInvocation(node);
            emptyGroupDepth--;
            return;
          }
        }
      }
      if (_testDeclarations.contains(name)) {
        final body = _callbackOf(node);
        if (body != null) {
          final assertions = _AssertionScan();
          body.body.accept(assertions);
          if (assertions.total > 0 &&
              assertions.total == assertions.tautologies) {
            final args = node.argumentList.arguments;
            sites.add(
              PlaceholderTest(
                path: path,
                line: lineInfo.getLocation(node.offset).lineNumber,
                kind: PlaceholderKind.tautology,
                description: args.isEmpty ? '' : _describe(args.first),
              ),
            );
          }
        }
      }
    }
    super.visitMethodInvocation(node);
  }

  String _describe(Expression first) {
    final text = first.toSource().replaceAll(RegExp(r'\s+'), ' ');
    return text.length <= 70 ? text : '${text.substring(0, 67)}...';
  }
}

/// Conservatively decides whether a group callback declares any test case.
///
/// This deliberately does not resolve helpers. An unqualified unknown call may
/// be a local or imported wrapper around a test declaration, so it is evidence
/// that the group might be populated. A targeted product call is not.
class _GroupScan extends RecursiveAstVisitor<void> {
  bool declaresTest = false;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (declaresTest) return;

    if (node.realTarget != null) {
      super.visitMethodInvocation(node);
      return;
    }

    final name = node.methodName.name;
    if (_testDeclarations.contains(name) || name == 'blocTest') {
      declaresTest = true;
      return;
    }

    if (_lifecycleDeclarations.contains(name)) {
      return;
    }

    if (name == 'group') {
      final body = _callbackOf(node);
      if (body == null) {
        // `group('Feature', sharedSuite)` delegates its declarations.
        declaresTest = true;
        return;
      }
      body.body.accept(this);
      return;
    }

    // Unknown bare calls include local and imported test-declaring helpers.
    declaresTest = true;
  }
}

FunctionExpression? _callbackOf(MethodInvocation node) {
  for (final argument in node.argumentList.arguments) {
    if (argument is FunctionExpression) return argument;
  }
  return null;
}

/// Counts assertions in a test body and how many are trivially satisfied.
class _AssertionScan extends RecursiveAstVisitor<void> {
  int total = 0;
  int tautologies = 0;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (_assertions.contains(node.methodName.name)) {
      total++;
      if (isTautology(node)) tautologies++;
    }
    super.visitMethodInvocation(node);
  }
}

/// Whether an `expect(...)`-shaped call is satisfied by construction.
///
/// Deliberately literal-only. `expect(a, equals(a))` on a VARIABLE is also
/// tautological, but proving two expressions are the same value needs
/// resolution this parser does not do, and a wrong call here would delete a
/// real test. Under-reporting is recoverable; a false positive is not.
bool isTautology(MethodInvocation node) {
  final positional = node.argumentList.arguments
      .where((argument) => argument is! NamedExpression)
      .toList();
  if (positional.length < 2) return false;
  final actual = positional[0];
  var matcher = positional[1];

  // `equals(<literal>)` is the literal for this purpose.
  if (matcher is MethodInvocation &&
      matcher.methodName.name == 'equals' &&
      matcher.argumentList.arguments.length == 1) {
    matcher = matcher.argumentList.arguments.single;
  }

  if (actual is BooleanLiteral) {
    if (matcher is SimpleIdentifier) {
      return actual.value
          ? matcher.name == 'isTrue'
          : matcher.name == 'isFalse';
    }
    if (matcher is BooleanLiteral) return actual.value == matcher.value;
    return false;
  }
  if (!_isLiteral(actual) || !_isLiteral(matcher)) return false;
  return actual.toSource() == matcher.toSource();
}

bool _isLiteral(Expression expression) =>
    expression is IntegerLiteral ||
    expression is DoubleLiteral ||
    expression is SimpleStringLiteral;
