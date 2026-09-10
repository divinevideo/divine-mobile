// ABOUTME: Detector behind check_prefs_key_classification.sh — lists prefs keys
// ABOUTME: a service writes that no account-cleanup path clears (#8314).

import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

/// Members of `SharedPreferences` (and Hive `Box`) whose FIRST argument names
/// a storage key.
///
/// Reads count as well as writes. A key the app only ever reads is still a key
/// whose value belongs to whoever last signed in, and `getStringList` is how
/// the leak in #6985 surfaced — the write was in one method, the read that
/// applied the previous account's choices in another.
const Set<String> keyedAccessors = {
  'setString', 'setBool', 'setInt', 'setDouble', 'setStringList',
  'getString', 'getBool', 'getInt', 'getDouble', 'getStringList',
  'remove', 'containsKey',
  // Hive
  'put', 'get', 'delete',
};

/// Whether a keyed access on this receiver is a storage access.
///
/// Matching on the member name alone would sweep in every `Map.remove` and
/// `List.get` in the codebase. Requiring a receiver that names a preferences
/// object or a Hive box keeps the scan to real storage while staying
/// syntactic — at the cost of missing a receiver named neither, which is why
/// the guard is a ratchet on a reviewed baseline rather than a proof.
bool _looksLikePrefsReceiver(Expression? target) {
  if (target == null) return false;
  final text = target.toString().toLowerCase();
  return text.contains('pref') || text.contains('box');
}

/// A key the app stores under, with where it was declared.
class PrefsKey {
  PrefsKey(this.value, this.file, this.line);

  final String value;
  final String file;
  final int line;

  @override
  String toString() => '$value  ($file:$line)';
}

/// Collects `static const String X = 'literal'` and its top-level form.
///
/// The join this enables is the whole reason the detector can stay syntactic:
/// the cleanup list names constants, the services declare them, and resolving
/// one to the other needs no element model.
class ConstantCollector extends RecursiveAstVisitor<void> {
  final Map<String, String> values = {};
  String? _enclosing;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    _enclosing = node.namePart.typeName.lexeme;
    super.visitClassDeclaration(node);
    _enclosing = null;
  }

  @override
  void visitFieldDeclaration(FieldDeclaration node) {
    if (!node.isStatic || !node.fields.isConst) return;
    for (final variable in node.fields.variables) {
      final initializer = variable.initializer;
      if (initializer is SimpleStringLiteral && _enclosing != null) {
        values['$_enclosing.${variable.name.lexeme}'] = initializer.value;
      }
    }
  }

  @override
  void visitTopLevelVariableDeclaration(TopLevelVariableDeclaration node) {
    if (!node.variables.isConst) return;
    for (final variable in node.variables.variables) {
      final initializer = variable.initializer;
      if (initializer is SimpleStringLiteral) {
        values[variable.name.lexeme] = initializer.value;
      }
    }
  }
}

/// Resolves a key expression to its literal value, or null when it is not a
/// fixed string.
///
/// Returning null is a deliberate *pass*, not a failure: an interpolated key
/// (`'following_list_$pubkey'`) or one built by a helper
/// (`SavedSoundsService.accountStorageKey(pubkey)`) embeds the owner, so it
/// cannot carry one account's value into another's session. Only a fixed
/// string names a single device-wide slot, and only those are classifiable.
String? resolveKey(
  Expression expression,
  Map<String, String> constants, {
  String? enclosingClass,
}) {
  if (expression is SimpleStringLiteral) return expression.value;
  if (expression is SimpleIdentifier) {
    return constants[enclosingClass == null
            ? expression.name
            : '$enclosingClass.${expression.name}'] ??
        constants[expression.name];
  }
  if (expression is PrefixedIdentifier) {
    return constants['${expression.prefix.name}.${expression.identifier.name}'];
  }
  if (expression is PropertyAccess) {
    final target = expression.target;
    if (target is SimpleIdentifier) {
      return constants['${target.name}.${expression.propertyName.name}'];
    }
  }
  return null;
}

/// Collects every fixed-string key the file stores under.
class KeyUsageCollector extends RecursiveAstVisitor<void> {
  KeyUsageCollector(this.constants, this.file, this.lineFor);

  final Map<String, String> constants;
  final String file;
  final int Function(int offset) lineFor;
  final List<PrefsKey> keys = [];
  String? _enclosing;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final previous = _enclosing;
    _enclosing = node.namePart.typeName.lexeme;
    super.visitClassDeclaration(node);
    _enclosing = previous;
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    super.visitMethodInvocation(node);
    if (!keyedAccessors.contains(node.methodName.name)) return;
    if (!_looksLikePrefsReceiver(node.target)) return;
    final arguments = node.argumentList.arguments;
    if (arguments.isEmpty) return;
    final value = resolveKey(
      arguments.first,
      constants,
      enclosingClass: _enclosing,
    );
    if (value == null || value.isEmpty) return;
    keys.add(PrefsKey(value, file, lineFor(node.offset)));
  }
}

/// Collects the entries of the named `List<String>` constants in a file.
class ListEntryCollector extends RecursiveAstVisitor<void> {
  ListEntryCollector(this.constants, this.listNames);

  final Map<String, String> constants;
  final Set<String> listNames;
  final Set<String> entries = {};
  String? _enclosing;

  void _collect(VariableDeclaration variable) {
    if (!listNames.contains(variable.name.lexeme)) return;
    final initializer = variable.initializer;
    if (initializer is! ListLiteral) return;
    for (final element in initializer.elements) {
      if (element is Expression) {
        final value = resolveKey(
          element,
          constants,
          enclosingClass: _enclosing,
        );
        if (value != null) entries.add(value);
      } else if (element is SpreadElement) {
        // `...TermsAcceptanceKeys.all` — a spread of a list constant. Resolve
        // the referenced list by name so the spread is not silently dropped.
        final expression = element.expression.toString();
        final scopedName = expression.contains('.')
            ? expression
            : _enclosing == null
            ? expression
            : '$_enclosing.$expression';
        entries.addAll(
          spreadPlaceholders[scopedName] ??
              spreadPlaceholders[expression] ??
              const {},
        );
      }
    }
  }

  /// Values contributed by list constants referenced through a spread.
  static final Map<String, Set<String>> spreadPlaceholders = {};

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final previous = _enclosing;
    _enclosing = node.namePart.typeName.lexeme;
    super.visitClassDeclaration(node);
    _enclosing = previous;
  }

  @override
  void visitFieldDeclaration(FieldDeclaration node) {
    if (!node.isStatic || !node.fields.isConst) return;
    node.fields.variables.forEach(_collect);
  }

  @override
  void visitTopLevelVariableDeclaration(TopLevelVariableDeclaration node) {
    if (!node.variables.isConst) return;
    node.variables.variables.forEach(_collect);
  }
}

/// Collects `static const List<String> ... = [...]` string lists, so a spread
/// of one can be expanded and a `deviceScopedPrefsKeys` declaration read.
class StringListCollector extends RecursiveAstVisitor<void> {
  StringListCollector(this.constants);

  final Map<String, String> constants;
  final Map<String, Set<String>> lists = {};
  String? _enclosing;

  void _collect(VariableDeclaration variable) {
    final initializer = variable.initializer;
    if (initializer is! ListLiteral) return;
    final values = <String>{};
    for (final element in initializer.elements) {
      if (element is Expression) {
        final value = resolveKey(
          element,
          constants,
          enclosingClass: _enclosing,
        );
        if (value != null) values.add(value);
      }
    }
    if (values.isEmpty) return;
    final name = variable.name.lexeme;
    lists[_enclosing == null ? name : '$_enclosing.$name'] = values;
  }

  Set<String> entriesNamed(String name) => {
    for (final entry in lists.entries)
      if (entry.key == name || entry.key.endsWith('.$name')) ...entry.value,
  };

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final previous = _enclosing;
    _enclosing = node.namePart.typeName.lexeme;
    super.visitClassDeclaration(node);
    _enclosing = previous;
  }

  @override
  void visitFieldDeclaration(FieldDeclaration node) {
    if (!node.isStatic || !node.fields.isConst) return;
    node.fields.variables.forEach(_collect);
  }

  @override
  void visitTopLevelVariableDeclaration(TopLevelVariableDeclaration node) {
    if (!node.variables.isConst) return;
    node.variables.variables.forEach(_collect);
  }
}

/// Parses [path] once, keeping the line info with the unit.
///
/// Both are taken from a single parse deliberately: re-parsing a file just to
/// resolve an offset to a line doubled this detector's wall clock, which is
/// most of a CI job's timing budget across ~3,500 files.
ParseStringResult? _parse(String path) {
  try {
    return parseFile(
      path: path,
      featureSet: FeatureSet.latestLanguageVersion(),
    );
  } on Object {
    // A file the parser rejects is already failing `flutter analyze`; treating
    // it as empty keeps this guard from double-reporting that.
    return null;
  }
}

List<File> _dartFiles(List<String> roots) {
  final files = <File>[];
  for (final root in roots) {
    final directory = Directory(root);
    if (!directory.existsSync()) continue;
    for (final entity in directory.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path;
      final separator = Platform.pathSeparator;
      if (path.contains('.dart_tool') ||
          // A package's own tests seed throwaway keys; they are not app
          // storage and must not be reported as unclassified.
          path.contains('${separator}test$separator') ||
          path.contains(
            '${Platform.pathSeparator}build${Platform.pathSeparator}',
          ) ||
          path.endsWith('.g.dart') ||
          path.endsWith('.freezed.dart')) {
        continue;
      }
      files.add(entity);
    }
  }
  files.sort((a, b) => a.path.compareTo(b.path));
  return files;
}

void main(List<String> arguments) {
  final detail = arguments.contains('--detail');
  final roots = arguments.where((a) => !a.startsWith('--')).toList();
  if (roots.isEmpty) roots.addAll(['lib', 'packages']);

  final files = _dartFiles(roots);

  // Pass 1 — every fixed-string constant, so the cleanup list's references
  // and the services' declarations can be joined.
  final constants = ConstantCollector();
  final parsed = <String, ParseStringResult>{};
  for (final file in files) {
    final result = _parse(file.absolute.path);
    if (result == null) continue;
    parsed[file.path] = result;
    result.unit.accept(constants);
  }
  final units = {
    for (final entry in parsed.entries) entry.key: entry.value.unit,
  };

  // Pass 2 — expand list constants, so `...TermsAcceptanceKeys.all` and any
  // `deviceScopedPrefsKeys` declaration resolve.
  final stringLists = StringListCollector(constants.values);
  for (final unit in units.values) {
    unit.accept(stringLists);
  }
  ListEntryCollector.spreadPlaceholders.addAll(stringLists.lists);

  // Pass 3 — what the cleanup paths clear, and what is declared device-scoped.
  final swept = <String>{};
  final prefixes = <String>{};
  final deviceScoped = <String>{};
  for (final entry in units.entries) {
    if (entry.key.endsWith('user_data_cleanup_service.dart')) {
      final collector = ListEntryCollector(constants.values, {
        'userSpecificKeys',
        'ownerScopedLegacyKeys',
      });
      entry.value.accept(collector);
      swept.addAll(collector.entries);
      prefixes.addAll(stringLists.entriesNamed('identityChangePrefixes'));
      final legacy =
          constants.values['UserDataCleanupService.legacyDraftOwnerKey'];
      if (legacy != null) swept.add(legacy);
    }
    deviceScoped.addAll(stringLists.entriesNamed('deviceScopedPrefsKeys'));
  }

  // Pass 4 — every fixed-string key the app stores under.
  final used = <String, PrefsKey>{};
  for (final entry in units.entries) {
    if (entry.key.endsWith('user_data_cleanup_service.dart')) continue;
    final lineInfo = parsed[entry.key]!.lineInfo;
    final collector = KeyUsageCollector(
      constants.values,
      entry.key,
      (offset) => lineInfo.getLocation(offset).lineNumber,
    );
    entry.value.accept(collector);
    for (final key in collector.keys) {
      used.putIfAbsent(key.value, () => key);
    }
  }

  final unclassified = <PrefsKey>[];
  for (final entry in used.entries) {
    final value = entry.key;
    if (swept.contains(value)) continue;
    if (deviceScoped.contains(value)) continue;
    if (prefixes.any(value.startsWith)) continue;
    unclassified.add(entry.value);
  }
  unclassified.sort((a, b) => a.value.compareTo(b.value));

  if (detail) {
    stderr.writeln(
      '${unclassified.length} unclassified prefs key(s): stored by the app, '
      'cleared by no account-cleanup path, and not declared device-scoped.',
    );
    for (final key in unclassified) {
      stderr.writeln('  $key');
    }
  }
  for (final key in unclassified) {
    stdout.writeln(key.value);
  }
}
