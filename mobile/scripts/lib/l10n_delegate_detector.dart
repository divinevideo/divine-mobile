// ABOUTME: Detector behind check_l10n_delegates_ceiling.sh — finds MaterialApp
// ABOUTME: constructions in tests that register no AppLocalizations delegate.
//
// Usage (from mobile/):
//   dart run scripts/lib/l10n_delegate_detector.dart <scan-dir> [options]
//     --path-prefix <dir>   strip this prefix from reported paths
//     --detail              one line per site instead of per-file counts
//
// Output (default): `relpath<TAB>count`, one line per file with >0 sites,
// sorted by path — the shape scripts/lib/numeric_ratchet.sh consumes.
//
// Why an AST and not a regex
// --------------------------
// Issue #3613 was filed off `grep MaterialApp | grep -v localizationsDelegates`,
// which reported 39 offending screen tests. 31 of those 39 were false: the
// repo's own `testMaterialApp(...)` helper CONTAINS the substring `MaterialApp`,
// so the grep matched the helper's *name* rather than a construction — and that
// helper does register the delegates. A word-boundary regex fixes that half.
//
// The other half needs real parsing. File-level greps also cannot see a file
// that builds two MaterialApps, one with delegates and one without: the file
// mentions `localizationsDelegates`, so it looks clean while a site inside it
// is not. Comparing per-file match COUNTS is only a heuristic — it cannot tell
// which construction a mention belongs to, and it misfires on a mention inside
// a comment or a string.
//
// So a site counts when, and only when, it is an actual `MaterialApp(...)` or
// `MaterialApp.router(...)` construction whose argument list has no
// `localizationsDelegates:` value that references `AppLocalizations` — or
// `appLocalizationsDelegates`, the app's own aggregate, which spreads that
// generated list and adds material_ui's `Global*` delegates on top (#8916).
// Anything that merely *contains* the identifier — `testMaterialApp`,
// `MyMaterialAppWrapper`, a doc comment, a string literal — is not a
// construction and is never counted.
//
// Why this matters: `context.l10n` is `AppLocalizations.of(context)`, which is
// `Localizations.of<AppLocalizations>(context, AppLocalizations)!`. With no
// delegate registered that lookup is null and the `!` throws
// `Null check operator used on a null value`. MaterialApp always supplies the
// *framework* fallbacks (DefaultMaterialLocalizations etc.), so the failure is
// specific to the app's own AppLocalizations delegate and stays invisible until
// a widget under test actually reads `context.l10n`.

import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

const _delegatesArg = 'localizationsDelegates';

/// Identifiers that prove a delegates list registers `AppLocalizations`.
///
/// `appLocalizationsDelegates` (lib/l10n/l10n.dart) is the app's own list; it
/// spreads `AppLocalizations.localizationsDelegates` and appends material_ui's
/// `GlobalMaterialLocalizations.delegates`, so a site using it is registered
/// exactly like one naming the generated list directly.
const _delegateSources = {'AppLocalizations', 'appLocalizationsDelegates'};

/// Thrown when a scanned file cannot be parsed.
///
/// Deliberately fatal: a file reported with zero sites because it failed to
/// parse is indistinguishable from a genuinely clean one, which would let the
/// ratchet drift silently.
class DetectorParseException implements Exception {
  const DetectorParseException(this.message);

  final String message;

  @override
  String toString() => 'DetectorParseException: $message';
}

/// App-root widgets that own a `Localizations` scope. Each one registers its
/// own delegates, so a nested one without them re-breaks `context.l10n` for its
/// subtree even when an ancestor was configured correctly.
const appWidgets = {'MaterialApp', 'CupertinoApp', 'WidgetsApp'};

/// One app-root construction that registers no `AppLocalizations` delegate.
class DelegatelessSite {
  const DelegatelessSite({
    required this.path,
    required this.line,
    required this.widget,
  });

  /// Path as reported, with the `pathPrefix` stripped.
  final String path;

  /// 1-based line of the construction.
  final int line;

  /// Which app-root widget: `MaterialApp`, `CupertinoApp` or `WidgetsApp`.
  final String widget;
}

class _Visitor extends RecursiveAstVisitor<void> {
  _Visitor(this._lineInfo, this._path);

  final LineInfo _lineInfo;
  final String _path;
  final List<DelegatelessSite> sites = [];

  // `parseFile` is a SYNTACTIC parse with no type resolution, so an unprefixed
  // `MaterialApp(...)` is indistinguishable from a function call and lands as a
  // MethodInvocation. Only `const` / `new` forms become an
  // InstanceCreationExpression. Both shapes must be visited, or the detector
  // silently sees only the const ones.
  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    _check(
      node.constructorName.type.name.lexeme,
      node.argumentList,
      node.offset,
    );
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    // `X.router(...)` arrives as a MethodInvocation whose target is `X`;
    // prefixed `material.MaterialApp(...)` arrives with methodName MaterialApp.
    final methodName = node.methodName.name;
    final name = methodName == 'router'
        ? _lastIdentifierName(node.target) ?? methodName
        : methodName;
    _check(name, node.argumentList, node.offset);
    super.visitMethodInvocation(node);
  }

  void _check(String name, ArgumentList args, int offset) {
    // Exact identifier match only: `testMaterialApp` is a different name and is
    // never counted — that substring collision is what made #3613 report 39
    // offenders when 31 of them were already correct.
    if (!appWidgets.contains(name)) return;
    if (_hasAppLocalizationsDelegate(args)) return;
    sites.add(
      DelegatelessSite(
        path: _path,
        line: _lineInfo.getLocation(offset).lineNumber,
        widget: name,
      ),
    );
  }

  bool _hasAppLocalizationsDelegate(ArgumentList args) {
    for (final argument in args.arguments) {
      if (argument is! NamedExpression) continue;
      if (argument.name.label.name != _delegatesArg) continue;
      return _referencesAppLocalizations(argument.expression);
    }
    return false;
  }

  bool _referencesAppLocalizations(Expression expression) {
    final visitor = _AppLocalizationsReferenceVisitor();
    expression.accept(visitor);
    return visitor.found;
  }
}

String? _lastIdentifierName(Expression? expression) {
  return switch (expression) {
    SimpleIdentifier(:final name) => name,
    PrefixedIdentifier(:final identifier) => identifier.name,
    PropertyAccess(:final propertyName) => propertyName.name,
    _ => null,
  };
}

class _AppLocalizationsReferenceVisitor extends RecursiveAstVisitor<void> {
  bool found = false;

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (_delegateSources.contains(node.name)) found = true;
    super.visitSimpleIdentifier(node);
  }
}

/// Every app-root construction under [root] that registers no delegates,
/// sorted by path then line.
List<DelegatelessSite> findDelegatelessSites(
  Directory root, {
  String pathPrefix = '',
}) {
  final files =
      root
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where(
            (f) =>
                !f.path.contains('/.dart_tool/') && !f.path.contains('/build/'),
          )
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  final sites = <DelegatelessSite>[];
  for (final file in files) {
    final ParseStringResult parsed;
    try {
      parsed = parseFile(
        path: file.absolute.path,
        featureSet: FeatureSet.latestLanguageVersion(),
        throwIfDiagnostics: false,
      );
    } on Object catch (e) {
      // Never swallow this: a file that fails to parse would otherwise report
      // zero sites, which reads identically to "clean".
      throw DetectorParseException('could not parse ${file.path}: $e');
    }
    var rel = file.path;
    if (pathPrefix.isNotEmpty && rel.startsWith(pathPrefix)) {
      rel = rel.substring(pathPrefix.length);
    }
    rel = rel.replaceFirst(RegExp('^/'), '');
    final visitor = _Visitor(parsed.lineInfo, rel);
    parsed.unit.visitChildren(visitor);
    sites.addAll(visitor.sites);
  }
  return sites;
}

void main(List<String> argv) {
  if (argv.isEmpty) {
    stderr.writeln('usage: l10n_delegate_detector.dart <dir> [--detail]');
    exit(64);
  }
  final scanDir = argv.first;
  final detail = argv.contains('--detail');
  var prefix = '';
  final pIdx = argv.indexOf('--path-prefix');
  if (pIdx != -1 && pIdx + 1 < argv.length) prefix = argv[pIdx + 1];

  final root = Directory(scanDir);
  if (!root.existsSync()) {
    stderr.writeln('no such directory: $scanDir');
    exit(66);
  }

  final List<DelegatelessSite> sites;
  try {
    sites = findDelegatelessSites(root, pathPrefix: prefix);
  } on DetectorParseException catch (e) {
    stderr.writeln('FATAL: ${e.message}');
    exit(65);
  }

  if (detail) {
    for (final s in sites) {
      stdout.writeln('${s.path}:${s.line}\t${s.widget}');
    }
    return;
  }
  final counts = <String, int>{};
  for (final s in sites) {
    counts[s.path] = (counts[s.path] ?? 0) + 1;
  }
  final keys = counts.keys.toList()..sort();
  for (final k in keys) {
    stdout.writeln('$k\t${counts[k]}');
  }
}
