// ABOUTME: Finds app call sites that rely on English semantic-label defaults
// ABOUTME: exposed by public divine_ui widgets (#7901).
//
// Usage (from mobile/):
//   dart run scripts/lib/divine_ui_semantic_label_detector.dart lib [options]
//     --path-prefix <dir>   strip this prefix from reported paths
//     --detail              print one line per omitted label
//
// Output (default): `relpath<TAB>count`, one line per file with omissions.
//
// divine_ui deliberately has no dependency on the app's generated
// localizations. Its public widgets therefore carry English fallbacks and let
// the app pass localized strings. That is a useful package boundary, but a
// caller can silently forget a label. This detector freezes that caller debt
// without making conditionally meaningful parameters required everywhere.
//
// A label counts only when its control can render. An omitted trigger uses the
// API's false/null default and does not count; an explicit `false` or `null`
// also does not count. Any other expression is conservatively treated as
// potentially rendering the control.

import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

/// Thrown when a scanned file cannot be parsed.
class DetectorParseException implements Exception {
  const DetectorParseException(this.message);

  final String message;

  @override
  String toString() => 'DetectorParseException: $message';
}

/// The semantic-label arguments one public divine_ui API must receive
/// whenever the control they describe can render.
class SemanticLabelRule {
  const SemanticLabelRule({
    required this.api,
    required this.triggerArgument,
    required this.labelArguments,
    this.visibilityArgument,
    this.hiddenWhenTrueArguments = const [],
    this.slotArguments = const {},
  });

  /// Constructor name, or `Class.helper` for a static helper.
  final String api;

  /// The argument that lets the control render. Omitted, `null` or `false`
  /// proves the control absent; anything else may render it.
  final String triggerArgument;

  /// Labels required once [triggerArgument] can render.
  final List<String> labelArguments;

  /// A `bool` argument that must also hold for the control to render.
  /// Defaults to `true` when omitted.
  final String? visibilityArgument;

  /// `bool` arguments that, when literally `true`, take precedence over the
  /// control and hide it.
  final List<String> hiddenWhenTrueArguments;

  /// Per label, the arguments whose inline widget takes over that control's
  /// slot, so the label can never be announced.
  final Map<String, List<String>> slotArguments;
}

const semanticLabelRules = <SemanticLabelRule>[
  SemanticLabelRule(
    api: 'DivineAuthTextField',
    triggerArgument: 'obscureText',
    labelArguments: ['showPasswordSemanticLabel', 'hidePasswordSemanticLabel'],
  ),
  // VineBottomSheetHeader resolves `leadingAction ?? leading` and
  // `trailingAction ?? trailing`, so a header action replaces the close or
  // completion button in its slot.
  SemanticLabelRule(
    api: 'VineBottomSheet',
    triggerArgument: 'onComplete',
    labelArguments: ['closeSemanticLabel', 'completeSemanticLabel'],
    visibilityArgument: 'showHeader',
    slotArguments: {
      'closeSemanticLabel': ['headerLeadingAction'],
      'completeSemanticLabel': ['headerTrailingAction'],
    },
  ),
  SemanticLabelRule(
    api: 'VineBottomSheet.show',
    triggerArgument: 'onComplete',
    labelArguments: ['closeSemanticLabel', 'completeSemanticLabel'],
    visibilityArgument: 'showHeader',
    slotArguments: {
      'closeSemanticLabel': ['headerLeadingAction'],
      'completeSemanticLabel': ['headerTrailingAction'],
    },
  ),
  SemanticLabelRule(
    api: 'DiVineAppBar',
    triggerArgument: 'leadingIcon',
    labelArguments: ['leadingActionSemanticLabel'],
  ),
  SemanticLabelRule(
    api: 'DiVineAppBarLeading',
    triggerArgument: 'leadingIcon',
    labelArguments: ['leadingActionSemanticLabel'],
    hiddenWhenTrueArguments: ['showBackButton', 'showMenuButton'],
  ),
  SemanticLabelRule(
    api: 'DivineSnackbarContainer',
    triggerArgument: 'onDismissPressed',
    labelArguments: ['dismissSemanticLabel'],
  ),
  SemanticLabelRule(
    api: 'DivineSnackbarContainer.snackBar',
    triggerArgument: 'onDismissPressed',
    labelArguments: ['dismissSemanticLabel'],
  ),
];

/// One omitted localized semantic label at an app call site.
class SemanticLabelOmission {
  const SemanticLabelOmission({
    required this.path,
    required this.line,
    required this.api,
    required this.argument,
  });

  final String path;
  final int line;
  final String api;
  final String argument;
}

class _Visitor extends RecursiveAstVisitor<void> {
  _Visitor(this._lineInfo, this._path);

  final LineInfo _lineInfo;
  final String _path;
  final List<SemanticLabelOmission> omissions = [];

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
    final methodName = node.methodName.name;
    final targetName = _lastIdentifierName(node.target);
    final api = targetName == null ? methodName : '$targetName.$methodName';

    // An unresolved syntactic parse represents ordinary constructor calls as
    // MethodInvocation. Import-prefixed constructors look like
    // `ui.DivineAuthTextField`, but the API name remains the method name.
    final normalizedApi = semanticLabelRules.any((rule) => rule.api == api)
        ? api
        : methodName;
    _check(normalizedApi, node.argumentList, node.offset);
    super.visitMethodInvocation(node);
  }

  void _check(String api, ArgumentList arguments, int offset) {
    final matchingRules = semanticLabelRules.where((rule) => rule.api == api);
    if (matchingRules.isEmpty) return;

    final named = <String, Expression>{};
    for (final argument in arguments.arguments) {
      if (argument is NamedArgument) {
        named[argument.name.lexeme] = argument.argumentExpression;
      }
    }

    for (final rule in matchingRules) {
      final trigger = named[rule.triggerArgument];
      if (!_canRender(trigger, defaultValue: false)) continue;
      final visibilityArgument = rule.visibilityArgument;
      if (visibilityArgument != null &&
          !_canRender(named[visibilityArgument], defaultValue: true)) {
        continue;
      }
      if (rule.hiddenWhenTrueArguments.any(
        (argument) => _isDefinitelyTrue(named[argument]),
      )) {
        continue;
      }
      for (final label in rule.labelArguments) {
        if (named.containsKey(label)) continue;
        final slotArguments = rule.slotArguments[label] ?? const <String>[];
        if (slotArguments.any((argument) => _isInlineWidget(named[argument]))) {
          continue;
        }
        omissions.add(
          SemanticLabelOmission(
            path: _path,
            line: _lineInfo.getLocation(offset).lineNumber,
            api: api,
            argument: label,
          ),
        );
      }
    }
  }
}

bool _canRender(Expression? trigger, {required bool defaultValue}) {
  if (trigger == null) return defaultValue;
  if (trigger is NullLiteral) return false;
  return trigger is! BooleanLiteral || trigger.value;
}

bool _isDefinitelyTrue(Expression? expression) =>
    expression is BooleanLiteral && expression.value;

/// Whether [expression] constructs a widget inline, and so cannot be null.
///
/// An unresolved parse reads `DivineIconButton(...)` as a MethodInvocation on
/// a capitalised name, including when it has an import prefix. Its named
/// constructor is likewise a MethodInvocation targeted at `DivineIconButton`;
/// only `const`/`new` forms become an InstanceCreationExpression. A variable or
/// a conditional may still be null at runtime, so it does not count and the
/// label stays required; nor does a helper call such as `_buildAction()`,
/// whose name survives `toUpperCase` unchanged but is not a class name.
bool _isInlineWidget(Expression? expression) {
  if (expression is InstanceCreationExpression) return true;
  if (expression is! MethodInvocation) return false;
  final name = expression.methodName.name;
  return _capitalised.hasMatch(name) ||
      _lastIdentifierName(expression.target) == 'DivineIconButton';
}

final _capitalised = RegExp('^[A-Z]');

String? _lastIdentifierName(Expression? expression) {
  return switch (expression) {
    SimpleIdentifier(:final name) => name,
    PrefixedIdentifier(:final identifier) => identifier.name,
    PropertyAccess(:final propertyName) => propertyName.name,
    _ => null,
  };
}

/// Finds all relevant semantic-label omissions under [root].
List<SemanticLabelOmission> findSemanticLabelOmissions(
  Directory root, {
  String pathPrefix = '',
}) {
  final files =
      root
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .where(
            (file) =>
                !file.path.contains('/.dart_tool/') &&
                !file.path.contains('/build/') &&
                !file.path.endsWith('.g.dart') &&
                !file.path.endsWith('.freezed.dart') &&
                !file.path.endsWith('.gr.dart') &&
                !file.path.endsWith('.mocks.dart'),
          )
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  final omissions = <SemanticLabelOmission>[];
  for (final file in files) {
    final ParseStringResult parsed;
    try {
      parsed = parseFile(
        path: file.absolute.path,
        featureSet: FeatureSet.latestLanguageVersion(),
        throwIfDiagnostics: false,
      );
    } on Object catch (error) {
      throw DetectorParseException('could not parse ${file.path}: $error');
    }

    var relativePath = file.path;
    if (pathPrefix.isNotEmpty && relativePath.startsWith(pathPrefix)) {
      relativePath = relativePath.substring(pathPrefix.length);
    }
    relativePath = relativePath.replaceFirst(RegExp('^/'), '');

    final visitor = _Visitor(parsed.lineInfo, relativePath);
    parsed.unit.visitChildren(visitor);
    omissions.addAll(visitor.omissions);
  }

  omissions.sort((a, b) {
    final pathOrder = a.path.compareTo(b.path);
    if (pathOrder != 0) return pathOrder;
    final lineOrder = a.line.compareTo(b.line);
    if (lineOrder != 0) return lineOrder;
    return a.argument.compareTo(b.argument);
  });
  return omissions;
}

void main(List<String> arguments) {
  if (arguments.isEmpty) {
    stderr.writeln(
      'usage: divine_ui_semantic_label_detector.dart <dir> '
      '[--path-prefix <dir>] [--detail]',
    );
    exit(64);
  }

  final root = Directory(arguments.first);
  if (!root.existsSync()) {
    stderr.writeln('no such directory: ${arguments.first}');
    exit(66);
  }

  var pathPrefix = '';
  final prefixIndex = arguments.indexOf('--path-prefix');
  if (prefixIndex != -1 && prefixIndex + 1 < arguments.length) {
    pathPrefix = arguments[prefixIndex + 1];
  }

  final List<SemanticLabelOmission> omissions;
  try {
    omissions = findSemanticLabelOmissions(root, pathPrefix: pathPrefix);
  } on DetectorParseException catch (error) {
    stderr.writeln('FATAL: ${error.message}');
    exit(65);
  }

  if (arguments.contains('--detail')) {
    for (final omission in omissions) {
      stdout.writeln(
        '${omission.path}:${omission.line}\t${omission.api}'
        '\tmissing ${omission.argument}',
      );
    }
    return;
  }

  final counts = <String, int>{};
  for (final omission in omissions) {
    counts.update(omission.path, (count) => count + 1, ifAbsent: () => 1);
  }
  for (final entry in counts.entries) {
    stdout.writeln('${entry.key}\t${entry.value}');
  }
}
