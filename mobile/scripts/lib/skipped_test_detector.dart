// ABOUTME: Detector behind check_skip_ceiling.sh — finds tests disabled by an
// ABOUTME: unconditional `skip:` or a file-level `@Skip(...)` (#3340, #4836).
//
// Usage (from mobile/):
//   dart run scripts/lib/skipped_test_detector.dart <scan-dir>... [options]
//     --path-prefix <dir>   strip this prefix from reported paths
//     --detail              one line per site instead of per-file counts
//
// Output (default): `relpath<TAB>count`, one line per file with >0 sites,
// sorted by path — the shape scripts/lib/numeric_ratchet.sh consumes.
//
// What counts
// -----------
// A `skip:` argument on an unqualified `test` / `testWidgets` / `group` /
// `patrolTest` call whose value is not a platform gate, plus a library-level
// `@Skip(...)` annotation (which disables the whole file — the most severe
// form, and one nothing guarded before).
//
// A non-literal value counts. `skip: _kBlockedOnCI` is an unconditional skip
// wearing a disguise, and leaving it uncounted would leave a one-line bypass.
// Only recognized platform-predicate expression shapes are exempt — see
// [_isPlatformGate] — because those gate a test to where it can run rather
// than switching it off.
//
// `skip: false` never counts: it disables nothing.
//
// blocTest is deliberately absent from [_testDeclarations]. `bloc_test`
// declares `int skip = 0` — the number of leading states to ignore before
// matching `expect` — so `blocTest(..., skip: 2)` is an assertion offset, not
// a disabled test. Excluding it by CALLEE rather than by value shape keeps
// that true even if a call passes a named int constant.
//
// Why an AST and not a regex
// --------------------------
// This replaces `[(, ]skip: (true|'|")`, which was wrong in both directions.
//
// It missed `skip:true`, `skip:  true` and `skip: r'…'`, and it could not see
// a `@Skip` annotation at all. It matched `// skip: true` in a comment and
// `'skip: true'` inside a string, since a line scan cannot tell code from
// prose. It needed `main_video_cache_startup_test.dart` excluded BY FILENAME,
// because that file passes `skip:` to the function under test — an argument
// the parser attributes to its own callee, so the exclusion disappears here.
//
// The count is per SITE, so a `skip:` on a group counts once however many
// tests the group holds — the fix is one edit either way.
//
// Exit codes: 0 clean run, 2 bad usage / unreadable scan dir.
import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

/// Calls whose `skip:` argument disables a test case or a whole group.
///
/// `blocTest` is excluded on purpose; see the header.
const _testDeclarations = {'test', 'testWidgets', 'group', 'patrolTest'};

const _platformGetters = {
  'isAndroid',
  'isIOS',
  'isLinux',
  'isMacOS',
  'isWindows',
  'isFuchsia',
};

const _targetPlatforms = {
  'android',
  'iOS',
  'linux',
  'macOS',
  'windows',
  'fuchsia',
};

/// One disabled test, group, or file.
class SkippedTest {
  SkippedTest({
    required this.path,
    required this.line,
    required this.declaration,
    required this.skipValue,
    required this.description,
  });

  final String path;
  final int line;

  /// `test`, `testWidgets`, `group`, `patrolTest`, or `@Skip` for a file-level
  /// annotation.
  final String declaration;

  /// The `skip:` value's source, so a reader can tell `true` from a reason.
  final String skipValue;

  /// The first argument's source, truncated — enough to find the test by eye.
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
      'usage: skipped_test_detector.dart <scan-dir>... '
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

  final sites = findSkippedTests(dirs, pathPrefix: pathPrefix);
  if (detail) {
    for (final site in sites) {
      stdout.writeln(
        '${site.path}:${site.line}\t${site.declaration}\t'
        '${site.skipValue}\t${site.description}',
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

/// Scans every `*_test.dart` file under [dirs] and returns the disabled tests
/// in path-then-line order.
List<SkippedTest> findSkippedTests(
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

  final sites = <SkippedTest>[];
  for (final file in files) {
    final String source;
    try {
      source = file.readAsStringSync();
    } on Object catch (error) {
      // Never swallow this: an unreadable file drops its sites, which reads to
      // the ratchet as a file somebody cleaned up.
      stderr.writeln('skipped_test_detector: skipped ${file.path} ($error)');
      continue;
    }
    final relative = file.path.startsWith('$pathPrefix/')
        ? file.path.substring(pathPrefix.length + 1)
        : file.path;
    sites.addAll(findSkippedTestsInSource(source, path: relative));
  }
  return sites;
}

/// True for a file the Dart test runner would pick up as a suite.
///
/// `*_test.dart` alone is not enough: a matching file under `lib/` is library
/// code, and `test_driver/integration_test.dart` is the driver entry point.
/// Both are invisible to the runner, so neither can disable a test.
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

/// Parses [source] and returns every disabled test, group, or file.
List<SkippedTest> findSkippedTestsInSource(
  String source, {
  required String path,
}) {
  final parsed = parseString(
    content: source,
    path: path,
    featureSet: FeatureSet.latestLanguageVersion(),
    throwIfDiagnostics: false,
  );
  final visitor = _SkippedTestVisitor(path: path, lineInfo: parsed.lineInfo);
  parsed.unit.accept(visitor);
  return visitor.sites;
}

class _SkippedTestVisitor extends RecursiveAstVisitor<void> {
  _SkippedTestVisitor({required this.path, required this.lineInfo});

  final String path;
  final LineInfo lineInfo;
  final sites = <SkippedTest>[];

  @override
  void visitAnnotation(Annotation node) {
    // `@Skip('reason')` above `library;` disables every test in the file.
    if (node.name.name == 'Skip' && node.parent is Directive) {
      final args = node.arguments?.arguments ?? const <Argument>[];
      sites.add(
        SkippedTest(
          path: path,
          line: lineInfo.getLocation(node.offset).lineNumber,
          declaration: '@Skip',
          skipValue: args.isEmpty ? '' : _oneLine(args.first.toSource()),
          description: '<whole file>',
        ),
      );
    }
    super.visitAnnotation(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    // `harness.test(...)` is a method on another object, and a `skip:` on any
    // other callee — including the function under test — belongs to that call.
    if (node.realTarget == null &&
        _testDeclarations.contains(node.methodName.name)) {
      final skip = _skipArgument(node);
      if (skip != null && disablesTest(skip)) {
        final args = node.argumentList.arguments;
        sites.add(
          SkippedTest(
            path: path,
            line: lineInfo.getLocation(node.offset).lineNumber,
            declaration: node.methodName.name,
            skipValue: _oneLine(skip.toSource()),
            description: args.isEmpty ? '' : _describe(args.first),
          ),
        );
      }
    }
    super.visitMethodInvocation(node);
  }

  Expression? _skipArgument(MethodInvocation node) {
    for (final argument in node.argumentList.arguments) {
      if (argument is NamedArgument && argument.name.lexeme == 'skip') {
        return argument.argumentExpression;
      }
    }
    return null;
  }

  String _describe(Argument first) => _oneLine(first.toSource(), max: 70);

  String _oneLine(String text, {int max = 60}) {
    final flat = text.replaceAll(RegExp(r'\s+'), ' ');
    return flat.length <= max ? flat : '${flat.substring(0, max - 3)}...';
  }
}

/// Whether a `skip:` [value] actually switches a test off.
///
/// `false` disables nothing. An expression built entirely from platform
/// predicates is a gate — it restricts a test to where it can run, which is
/// the sanctioned alternative to switching it off. Everything else counts,
/// including a bare identifier: a named constant that is always true is an
/// unconditional skip with a nicer name.
bool disablesTest(Expression value) {
  if (value is BooleanLiteral) return value.value;
  return !_isPlatformGate(value);
}

/// True for a boolean expression composed only of recognized platform checks.
///
/// Checking AST shapes, rather than identifier names, is load-bearing. A value
/// such as `!kIsWeb || true` mentions only a platform identifier but disables
/// the test everywhere, so it must count.
bool _isPlatformGate(Expression value) {
  if (value is ParenthesizedExpression) {
    return _isPlatformGate(value.expression);
  }
  if (value is SimpleIdentifier) return value.name == 'kIsWeb';
  if (value is PrefixExpression && value.operator.lexeme == '!') {
    return _isPlatformGate(value.operand);
  }
  if (value is ConditionalExpression && _isPlatformGate(value.condition)) {
    return _isPlatformSkipPair(
      value.thenExpression,
      value.elseExpression,
    );
  }
  if (_isProperty(value, 'Platform', _platformGetters)) return true;
  if (value is! BinaryExpression) return false;

  final operator = value.operator.lexeme;
  if (operator == '&&' || operator == '||') {
    return _isPlatformGate(value.leftOperand) &&
        _isPlatformGate(value.rightOperand);
  }
  if (operator == '==' || operator == '!=') {
    return (_isDefaultTargetPlatform(value.leftOperand) &&
            _isTargetPlatform(value.rightOperand)) ||
        (_isTargetPlatform(value.leftOperand) &&
            _isDefaultTargetPlatform(value.rightOperand));
  }
  return false;
}

bool _isPlatformSkipPair(Expression first, Expression second) {
  if ((first is StringLiteral && second is NullLiteral) ||
      (first is NullLiteral && second is StringLiteral)) {
    return true;
  }
  return first is BooleanLiteral &&
      second is BooleanLiteral &&
      first.value != second.value;
}

bool _isDefaultTargetPlatform(Expression value) {
  final unwrapped = value is ParenthesizedExpression ? value.expression : value;
  return unwrapped is SimpleIdentifier &&
      unwrapped.name == 'defaultTargetPlatform';
}

bool _isTargetPlatform(Expression value) =>
    _isProperty(value, 'TargetPlatform', _targetPlatforms);

bool _isProperty(Expression value, String receiver, Set<String> properties) {
  final unwrapped = value is ParenthesizedExpression ? value.expression : value;
  if (unwrapped is PrefixedIdentifier) {
    return unwrapped.prefix.name == receiver &&
        properties.contains(unwrapped.identifier.name);
  }
  if (unwrapped is PropertyAccess) {
    final target = unwrapped.target;
    return target is SimpleIdentifier &&
        target.name == receiver &&
        properties.contains(unwrapped.propertyName.name);
  }
  return false;
}
