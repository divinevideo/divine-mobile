// ABOUTME: Finds files that publish a replaceable Nostr kind without reading
// ABOUTME: its current version through NostrClient.readCurrentVersion (#11317).

import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

/// Printed for a published kind the detector could not resolve. It fails like
/// any other kind until the site is classified.
const unresolvedKind = '?';

/// Whether NIP-01 replaces [kind] whole on every publish: kinds 0 and 3, the
/// replaceable range 10000-19999 and the addressable range 30000-39999.
bool isReplaceableKind(int kind) =>
    kind == 0 ||
    kind == 3 ||
    (kind >= 10000 && kind < 20000) ||
    (kind >= 30000 && kind < 40000);

/// Files the guard never reports, by path relative to `mobile/`, each with
/// the reason no base read can apply to it.
const exemptFiles = <String, String>{
  'packages/db_client/lib/src/database/daos/nostr_events_dao.dart':
      'Rebuilds cached events from their stored rows; it never signs or '
      'publishes one.',
  'packages/db_client/lib/src/database/daos/personal_events_dao.dart':
      "Rebuilds the account's cached events from their stored rows; it never "
      'signs or publishes one.',
  'packages/dm_repository/lib/src/nip17_message_service.dart':
      'Builds NIP-17 rumors, which reach a relay only sealed inside a kind '
      '1059 gift wrap, never as themselves.',
  'packages/nostr_app_bridge_repository/lib/src/nostr_app_bridge_service.dart':
      'The embedded-app bridge signs whatever kind the app allowlist permits, '
      'so the kind is runtime data: the app that asked owns the base read.',
  'packages/nostr_client/lib/src/nip89_client_tag.dart':
      'Adds the NIP-89 client tag to an event already on its way to a '
      'publish, keeping its kind; the code that built it is the publish site.',
  'packages/nostr_sdk/lib/nip59/gift_wrap_util.dart':
      'Rebuilds a received NIP-59 rumor from its JSON; it never publishes one.',
};

/// Calls whose result fixes a kind no constant names at the publish site.
///
/// A site resolves through an entry either by passing the call as the kind
/// itself or by reading `.kind` off a local the call initialized, the way the
/// people-list repositories read it off a codec payload.
const callKinds = <String, int>{
  // Both return NIP71VideoKinds.addressableShortVideo.
  'NIP71VideoKinds.getPreferredAddressableKind': 34236,
  'NIP71VideoKinds.getPreferredKind': 34236,
  // Every payload carries Nip51PeopleListCodec.kind.
  'Nip51PeopleListCodec.encode': 30000,
  'Nip51PeopleListCodec.encodeInfoEdit': 30000,
  'Nip51PeopleListCodec.encodeReserved': 30000,
};

/// `NostrClient` methods that sign and publish one fixed kind from content
/// their caller assembled. The caller owns the base read, so each call is a
/// publish site in the caller's file and the event built inside the method
/// is not.
const publishingMethods = <String, int>{
  'sendContactList': 3,
  'sendProfileAwaitOk': 0,
};

/// One file that publishes a replaceable [kind] and never reads that kind
/// through `readCurrentVersion`.
class ReplaceablePublishViolation {
  const ReplaceablePublishViolation({
    required this.path,
    required this.kind,
    required this.lines,
  });

  final String path;

  /// The kind as printed: digits, or [unresolvedKind].
  final String kind;

  /// The lines of the calls that publish it, ascending.
  final List<int> lines;
}

/// Reports violations across every source handed to [add].
///
/// Detection waits for [violations] because a constant or signer typedef
/// declared in one file resolves a publish site in another.
class ReplaceablePublishScanner {
  final _qualifiedConstants = <String, List<_Constant>>{};
  final _topLevelConstants = <String, List<_Constant>>{};
  final _signerTypedefs = <String>{};
  final _units = <_Unit>[];

  /// Parses [source] as the file at [path], relative to `mobile/`.
  void add(String path, String source) {
    final ParseStringResult parsed = parseString(
      content: source,
      featureSet: FeatureSet.latestLanguageVersion(),
      throwIfDiagnostics: false,
    );
    parsed.unit.accept(
      _DeclarationHarvester(
        path,
        _qualifiedConstants,
        _topLevelConstants,
        _signerTypedefs,
      ),
    );
    if (_isExempt(path) || !_mayPublishOrRead.hasMatch(source)) return;
    _units.add(_Unit(path, parsed.unit, parsed.lineInfo));
  }

  List<ReplaceablePublishViolation> violations() {
    final violations = <ReplaceablePublishViolation>[];
    for (final unit in _units) {
      final scan = _UnitScan(this, unit)..run();
      final read = {for (final hit in scan.reads) hit.kind};
      final unreadLines = <String, Set<int>>{};
      for (final hit in scan.publishes) {
        if (!_isReplaceable(hit.kind) || read.contains(hit.kind)) continue;
        unreadLines.putIfAbsent(hit.kind, () => <int>{}).add(hit.line);
      }
      unreadLines.forEach((kind, lines) {
        violations.add(
          ReplaceablePublishViolation(
            path: unit.path,
            kind: kind,
            lines: lines.toList()..sort(),
          ),
        );
      });
    }
    return violations..sort(
      (a, b) => a.path != b.path
          ? a.path.compareTo(b.path)
          : a.kind.compareTo(b.kind),
    );
  }

  /// The value of `Owner.name`, preferring a declaration in [sitePath] when
  /// two files disagree, or null when nothing settles it.
  int? _qualifiedValue(
    String key,
    String sitePath, [
    Set<_Constant>? active,
  ]) => _settle(_qualifiedConstants[key], sitePath, active ?? {});

  int? _topLevelValue(
    String name,
    String sitePath, [
    Set<_Constant>? active,
  ]) => _settle(_topLevelConstants[name], sitePath, active ?? {});

  bool _isSignerTypedef(String name) => _signerTypedefs.contains(name);

  int? _settle(
    List<_Constant>? constants,
    String sitePath,
    Set<_Constant> active,
  ) {
    if (constants == null) return null;
    int? agreed(Iterable<_Constant> candidates) {
      final values = {
        for (final constant in candidates) _evaluate(constant, active),
      }..remove(null);
      return values.length == 1 ? values.single : null;
    }

    return agreed(constants) ??
        agreed(constants.where((constant) => constant.path == sitePath));
  }

  int? _evaluate(_Constant constant, Set<_Constant> active) {
    if (!active.add(constant)) return null;
    try {
      return switch (constant.value) {
        _IntValue(:final value) => value,
        _ReferenceValue(:final owner?, :final name) => _qualifiedValue(
          '$owner.$name',
          constant.path,
          active,
        ),
        _ReferenceValue(:final name) =>
          (constant.owner == null
                  ? null
                  : _qualifiedValue(
                      '${constant.owner}.$name',
                      constant.path,
                      active,
                    )) ??
              _topLevelValue(name, constant.path, active),
      };
    } finally {
      active.remove(constant);
    }
  }
}

/// Every source that can publish or read has one of these substrings: a named
/// `kind:` argument, an `Event(` construction, or a [publishingMethods] call.
final _mayPublishOrRead = RegExp(
  [
    r'\bkind\s*:',
    r'\bEvent\s*\(',
    ...publishingMethods.keys.map(RegExp.escape),
  ].join('|'),
);

bool _isExempt(String path) => exemptFiles.containsKey(path);

bool _isReplaceable(String kind) {
  if (kind == unresolvedKind) return true;
  final value = int.tryParse(kind);
  return value != null && isReplaceableKind(value);
}

/// Convenience for tests: scans [sourcesByPath], keyed by `mobile/`-relative
/// path, as one tree.
List<ReplaceablePublishViolation> findReplaceablePublishViolations(
  Map<String, String> sourcesByPath,
) {
  final scanner = ReplaceablePublishScanner();
  sourcesByPath.forEach(scanner.add);
  return scanner.violations();
}

class _Unit {
  const _Unit(this.path, this.unit, this.lineInfo);

  final String path;
  final CompilationUnit unit;
  final LineInfo lineInfo;
}

/// A `const` int declaration: a static member of [owner], or top-level when
/// [owner] is null.
class _Constant {
  const _Constant(this.path, this.owner, this.value);

  final String path;
  final String? owner;
  final _ConstantValue value;
}

sealed class _ConstantValue {
  const _ConstantValue();
}

final class _IntValue extends _ConstantValue {
  const _IntValue(this.value);

  final int value;
}

/// Another constant: `Owner.name`, or a bare `name` resolved from where the
/// declaration sits.
final class _ReferenceValue extends _ConstantValue {
  const _ReferenceValue(this.owner, this.name);

  final String? owner;
  final String name;
}

class _DeclarationHarvester extends RecursiveAstVisitor<void> {
  _DeclarationHarvester(
    this._path,
    this._qualified,
    this._topLevel,
    this._signerTypedefs,
  );

  final String _path;
  final Map<String, List<_Constant>> _qualified;
  final Map<String, List<_Constant>> _topLevel;
  final Set<String> _signerTypedefs;

  @override
  void visitFieldDeclaration(FieldDeclaration node) {
    // A member's parent is the class body; the declaration is one level up.
    final owner = _classLikeName(node.parent?.parent);
    if (owner != null && node.isStatic) {
      _record(node.fields, owner, (name) => '$owner.$name', _qualified);
    }
    super.visitFieldDeclaration(node);
  }

  @override
  void visitTopLevelVariableDeclaration(TopLevelVariableDeclaration node) {
    _record(node.variables, null, (name) => name, _topLevel);
    super.visitTopLevelVariableDeclaration(node);
  }

  @override
  void visitGenericTypeAlias(GenericTypeAlias node) {
    final type = node.type;
    if (type is GenericFunctionType &&
        _isSignerShape(type.parameters, type.returnType)) {
      _signerTypedefs.add(node.name.lexeme);
    }
    super.visitGenericTypeAlias(node);
  }

  @override
  void visitFunctionTypeAlias(FunctionTypeAlias node) {
    if (_isSignerShape(node.parameters, node.returnType)) {
      _signerTypedefs.add(node.name.lexeme);
    }
    super.visitFunctionTypeAlias(node);
  }

  void _record(
    VariableDeclarationList list,
    String? owner,
    String Function(String name) keyOf,
    Map<String, List<_Constant>> into,
  ) {
    if (!list.isConst || !_isIntOrUntyped(list.type)) return;
    for (final variable in list.variables) {
      final value = _constantValue(variable.initializer);
      if (value == null) continue;
      into
          .putIfAbsent(keyOf(variable.name.lexeme), () => [])
          .add(_Constant(_path, owner, value));
    }
  }
}

bool _isIntOrUntyped(TypeAnnotation? type) =>
    type == null || (type is NamedType && type.name.lexeme == 'int');

_ConstantValue? _constantValue(Expression? initializer) {
  final expression = initializer is ParenthesizedExpression
      ? initializer.expression
      : initializer;
  return switch (expression) {
    IntegerLiteral(:final value?) => _IntValue(value),
    PrefixedIdentifier(:final prefix, :final identifier) => _ReferenceValue(
      prefix.name,
      identifier.name,
    ),
    // An import-prefixed `prefix.Owner.name`.
    PropertyAccess(
      target: PrefixedIdentifier(:final identifier),
      :final propertyName,
    ) =>
      _ReferenceValue(identifier.name, propertyName.name),
    SimpleIdentifier(:final name) => _ReferenceValue(null, name),
    _ => null,
  };
}

/// A function type shaped like `AuthService.createAndSignEvent`: a named
/// `kind` parameter and an `Event` result. Packages that cannot depend on the
/// app declare one as a typedef and call a field of that type instead.
bool _isSignerShape(FormalParameterList parameters, TypeAnnotation? result) =>
    parameters.parameters.any(
      (parameter) => parameter.isNamed && parameter.name?.lexeme == 'kind',
    ) &&
    result != null &&
    RegExp(r'\bEvent\b').hasMatch(result.toSource());

String? _classLikeName(AstNode? node) => switch (node) {
  ClassDeclaration(:final namePart) => namePart.typeName.lexeme,
  MixinDeclaration(:final name) => name.lexeme,
  EnumDeclaration(:final namePart) => namePart.typeName.lexeme,
  ExtensionDeclaration(:final name?) => name.lexeme,
  ExtensionTypeDeclaration(:final namePart) => namePart.typeName.lexeme,
  _ => null,
};

List<ClassMember> _classLikeMembers(AstNode node) => switch (node) {
  ClassDeclaration(:final body) => body.members,
  MixinDeclaration(:final body) => body.members,
  EnumDeclaration(:final body) => body.members,
  ExtensionDeclaration(:final body) => body.members,
  ExtensionTypeDeclaration(:final body) => body.members,
  _ => const [],
};

/// A kind one call publishes or reads, at the line of the call that fixed it.
class _Hit {
  const _Hit(this.kind, this.line);

  final String kind;
  final int line;
}

/// Finds the publish sites and helper reads of one file.
class _UnitScan extends RecursiveAstVisitor<void> {
  _UnitScan(this._scanner, this._unit);

  final ReplaceablePublishScanner _scanner;
  final _Unit _unit;
  final publishes = <_Hit>[];
  final reads = <_Hit>[];

  /// Names this file declares with a signer type: fields, parameters,
  /// locals and record fields.
  final _signerNames = <String>{};

  /// Calls to this file's own functions and methods, by name, for following
  /// a forwarded kind back to the call that fixes it.
  final _ownCalls = <String, List<MethodInvocation>>{};

  void run() {
    _unit.unit.accept(_LocalIndexer(_scanner, _signerNames, _ownCalls));
    _unit.unit.accept(this);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final name = node.methodName.name;
    final kind = _namedArgument(node.argumentList, 'kind');
    if (name == 'readCurrentVersion') {
      if (kind != null) reads.addAll(_resolveAt(kind, node));
    } else if (_insidePublishingMethod(node)) {
      // The event a publishing method builds is its caller's publish.
    } else if (name == 'createAndSignEvent' || _signerNames.contains(name)) {
      if (kind != null) publishes.addAll(_resolveAt(kind, node));
    } else if (publishingMethods[name] case final fixed?) {
      publishes.add(_Hit('$fixed', _line(node)));
    } else if (name == 'Event' &&
        (node.target == null || node.target is SimpleIdentifier)) {
      _publishEventConstruction(node, node.argumentList);
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final constructor = node.constructorName;
    if (constructor.type.name.lexeme == 'Event' &&
        constructor.name == null &&
        !_insidePublishingMethod(node)) {
      _publishEventConstruction(node, node.argumentList);
    }
    super.visitInstanceCreationExpression(node);
  }

  /// `Event(pubkey, kind, tags, content)`: the kind is the second positional
  /// argument. A one-argument `Event(...)` is some other class.
  void _publishEventConstruction(AstNode node, ArgumentList arguments) {
    final positional = arguments.arguments.whereType<Expression>().toList();
    if (positional.length < 2) return;
    publishes.addAll(_resolveAt(positional[1], node));
  }

  List<_Hit> _resolveAt(Expression kind, AstNode call) =>
      _resolve(kind, _line(call), <Object>{});

  int _line(AstNode node) => _unit.lineInfo.getLocation(node.offset).lineNumber;

  List<_Hit> _resolve(Expression expression, int line, Set<Object> active) {
    final expr = _unwrap(expression);
    return switch (expr) {
      IntegerLiteral(:final value) => [_hit(value, line)],
      ConditionalExpression(:final thenExpression, :final elseExpression) => [
        ..._resolve(thenExpression, line, active),
        ..._resolve(elseExpression, line, active),
      ],
      PrefixedIdentifier() => [_hit(_prefixedValue(expr), line)],
      PropertyAccess(
        target: PrefixedIdentifier(:final identifier),
        :final propertyName,
      ) =>
        [_hit(_qualified('${identifier.name}.${propertyName.name}'), line)],
      MethodInvocation() => [_hit(_callKind(expr), line)],
      SimpleIdentifier() => _resolveName(expr, line, active),
      _ => [_Hit(unresolvedKind, line)],
    };
  }

  _Hit _hit(int? value, int line) =>
      _Hit(value == null ? unresolvedKind : '$value', line);

  int? _qualified(String key) => _scanner._qualifiedValue(key, _unit.path);

  /// `Owner.name`, or `payload.kind` off a local a [callKinds] call set.
  int? _prefixedValue(PrefixedIdentifier expr) {
    final constant = _qualified('${expr.prefix.name}.${expr.identifier.name}');
    if (constant != null || expr.identifier.name != 'kind') return constant;
    final local = _localDeclaration(expr.prefix.name, expr);
    final initializer = local?.initializer;
    return initializer == null ? null : _callKind(_unwrap(initializer));
  }

  int? _callKind(Expression expr) {
    if (expr is! MethodInvocation) return null;
    final target = expr.target;
    if (target is! SimpleIdentifier) return null;
    return callKinds['${target.name}.${expr.methodName.name}'];
  }

  /// Resolves a bare name from where it is used: a local, a parameter (a
  /// forwarded kind), a static member of the enclosing class, or a top-level
  /// constant.
  List<_Hit> _resolveName(SimpleIdentifier id, int line, Set<Object> active) {
    final name = id.name;
    for (AstNode? node = id.parent; node != null; node = node.parent) {
      final statements = _statementsOf(node);
      if (statements != null) {
        if (_patternDeclaresBefore(statements, name, id.offset)) {
          return [_Hit(unresolvedKind, line)];
        }
        final local = _declarationIn(statements, name, id.offset);
        if (local != null) {
          final initializer = local.initializer;
          if (initializer == null ||
              _isReassigned(local) ||
              !active.add(local)) {
            return [_Hit(unresolvedKind, line)];
          }
          try {
            return _resolve(initializer, line, active);
          } finally {
            active.remove(local);
          }
        }
      }
      if (_bindsLoopOrCatchVariable(node, name) ||
          _bindsPatternVariable(node, name)) {
        return [_Hit(unresolvedKind, line)];
      }
      final parameters = _parametersOf(node);
      final parameter = parameters?.parameters
          .where((parameter) => parameter.name?.lexeme == name)
          .firstOrNull;
      if (parameter != null) {
        return _followForwarded(node, parameters!, parameter, line, active);
      }
      final owner = _classLikeName(node);
      if (owner != null) {
        final constant = _qualified('$owner.$name');
        if (constant != null) return [_hit(constant, line)];
        if (_declaresMember(node, name)) return [_Hit(unresolvedKind, line)];
      }
      if (node is CompilationUnit) {
        return [_hit(_scanner._topLevelValue(name, _unit.path), line)];
      }
    }
    return [_Hit(unresolvedKind, line)];
  }

  /// A kind that is a parameter of the enclosing function is forwarded: its
  /// caller decides it. A signing entry point (`createAndSignEvent`, a
  /// [publishingMethods] method) is skipped, because a call to it is itself
  /// the publish site the detector sees. Calls in this file to a named
  /// function or method are followed to the argument they pass. Callers out
  /// of sight report `?`: a closure's, a constructor's, another file's for a
  /// public function, and a tear-off's for a private one this file never
  /// calls by name, plus the default kind such a caller may rely on.
  List<_Hit> _followForwarded(
    AstNode function,
    FormalParameterList parameters,
    FormalParameter parameter,
    int line,
    Set<Object> active,
  ) {
    final name = switch (function) {
      MethodDeclaration(:final name) => name.lexeme,
      FunctionExpression(parent: FunctionDeclaration(:final name)) =>
        name.lexeme,
      _ => null,
    };
    if (name == 'createAndSignEvent' || publishingMethods.containsKey(name)) {
      return const [];
    }
    if (name == null) return [_Hit(unresolvedKind, line)];
    if (!active.add(parameter)) return const [];
    try {
      final hits = <_Hit>[];
      final calls = _ownCalls[name] ?? const <MethodInvocation>[];
      for (final call in calls) {
        final argument =
            _argumentFor(call.argumentList, parameters, parameter) ??
            parameter.defaultClause?.value;
        if (argument != null) {
          hits.addAll(_resolve(argument, _line(call), active));
        }
      }
      if (!name.startsWith('_') || calls.isEmpty) {
        final fallback = parameter.defaultClause?.value;
        if (fallback != null) hits.addAll(_resolve(fallback, line, active));
        hits.add(_Hit(unresolvedKind, line));
      }
      return hits;
    } finally {
      active.remove(parameter);
    }
  }

  VariableDeclaration? _localDeclaration(String name, AstNode use) {
    for (AstNode? node = use.parent; node != null; node = node.parent) {
      final statements = _statementsOf(node);
      if (statements != null) {
        final local = _declarationIn(statements, name, use.offset);
        if (local != null) return local;
      }
      if (_parametersOf(node) != null || _classLikeName(node) != null) {
        return null;
      }
    }
    return null;
  }

  bool _insidePublishingMethod(AstNode node) {
    for (
      AstNode? current = node.parent;
      current != null;
      current = current.parent
    ) {
      if (current is MethodDeclaration &&
          publishingMethods.containsKey(current.name.lexeme)) {
        return true;
      }
    }
    return false;
  }
}

/// Indexes the signer-typed names and own-function calls of one file.
class _LocalIndexer extends RecursiveAstVisitor<void> {
  _LocalIndexer(this._scanner, this._signerNames, this._ownCalls);

  final ReplaceablePublishScanner _scanner;
  final Set<String> _signerNames;
  final Map<String, List<MethodInvocation>> _ownCalls;

  bool _isSignerType(TypeAnnotation? type) => switch (type) {
    NamedType(:final name) => _scanner._isSignerTypedef(name.lexeme),
    GenericFunctionType(:final parameters, :final returnType) => _isSignerShape(
      parameters,
      returnType,
    ),
    _ => false,
  };

  @override
  void visitVariableDeclarationList(VariableDeclarationList node) {
    if (_isSignerType(node.type)) {
      _signerNames.addAll(node.variables.map((v) => v.name.lexeme));
    }
    super.visitVariableDeclarationList(node);
  }

  @override
  void visitFormalParameterList(FormalParameterList node) {
    for (final parameter in node.parameters) {
      final name = parameter.name?.lexeme;
      if (name != null && _isSignerType(parameter.type)) _signerNames.add(name);
    }
    super.visitFormalParameterList(node);
  }

  @override
  void visitRecordTypeAnnotationNamedField(
    RecordTypeAnnotationNamedField node,
  ) {
    if (_isSignerType(node.type)) _signerNames.add(node.name.lexeme);
    super.visitRecordTypeAnnotationNamedField(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final target = node.target;
    if (!node.isCascaded && (target == null || target is ThisExpression)) {
      _ownCalls.putIfAbsent(node.methodName.name, () => []).add(node);
    }
    super.visitMethodInvocation(node);
  }
}

Expression _unwrap(Expression expression) {
  var current = expression;
  while (true) {
    final Expression next;
    if (current is ParenthesizedExpression) {
      next = current.expression;
    } else if (current is AsExpression) {
      next = current.expression;
    } else if (current is PostfixExpression && current.operator.lexeme == '!') {
      next = current.operand;
    } else {
      return current;
    }
    current = next;
  }
}

Expression? _namedArgument(ArgumentList arguments, String name) {
  for (final argument in arguments.arguments) {
    if (argument is NamedArgument && argument.name.lexeme == name) {
      return argument.argumentExpression;
    }
  }
  return null;
}

Expression? _argumentFor(
  ArgumentList arguments,
  FormalParameterList parameters,
  FormalParameter parameter,
) {
  final name = parameter.name!.lexeme;
  if (parameter.isNamed) return _namedArgument(arguments, name);
  final index = parameters.parameters
      .where((candidate) => candidate.isPositional)
      .toList()
      .indexOf(parameter);
  final positional = arguments.arguments.whereType<Expression>().toList();
  return index >= 0 && index < positional.length ? positional[index] : null;
}

FormalParameterList? _parametersOf(AstNode node) => switch (node) {
  MethodDeclaration(:final parameters) => parameters,
  ConstructorDeclaration(:final parameters) => parameters,
  FunctionExpression(:final parameters) => parameters,
  _ => null,
};

/// Whether [node] binds [name] as a loop variable or a caught exception, which
/// no constant table can resolve.
bool _bindsLoopOrCatchVariable(AstNode node, String name) {
  final parts = switch (node) {
    ForStatement(:final forLoopParts) => forLoopParts,
    ForElement(:final forLoopParts) => forLoopParts,
    _ => null,
  };
  return switch (parts) {
    ForEachPartsWithDeclaration(:final loopVariable) =>
      loopVariable.name.lexeme == name,
    ForPartsWithDeclarations(:final variables) => variables.variables.any(
      (variable) => variable.name.lexeme == name,
    ),
    _ =>
      node is CatchClause &&
          (node.exceptionParameter?.name.lexeme == name ||
              node.stackTraceParameter?.name.lexeme == name),
  };
}

/// The statements a block or a switch case declares its locals among.
List<Statement>? _statementsOf(AstNode node) => switch (node) {
  Block(:final statements) => statements,
  SwitchMember(:final statements) => statements,
  _ => null,
};

/// The last declaration of [name] among [statements] before [offset].
VariableDeclaration? _declarationIn(
  List<Statement> statements,
  String name,
  int offset,
) {
  VariableDeclaration? found;
  for (final statement in statements) {
    if (statement.offset >= offset) break;
    if (statement is! VariableDeclarationStatement) continue;
    for (final variable in statement.variables.variables) {
      if (variable.name.lexeme == name) found = variable;
    }
  }
  return found;
}

/// Whether a pattern declaration among [statements] before [offset] binds
/// [name], as `final (kind, content) = picked;` does.
bool _patternDeclaresBefore(
  List<Statement> statements,
  String name,
  int offset,
) {
  for (final statement in statements) {
    if (statement.offset >= offset) break;
    if (statement is PatternVariableDeclarationStatement &&
        _patternBinds(statement.declaration.pattern, name)) {
      return true;
    }
  }
  return false;
}

/// Whether [node] binds [name] through a pattern its body sees: an if-case,
/// a switch case, or a for-in over a pattern.
bool _bindsPatternVariable(AstNode node, String name) => switch (node) {
  IfStatement(:final caseClause?) => _patternBinds(
    caseClause.guardedPattern.pattern,
    name,
  ),
  IfElement(:final caseClause?) => _patternBinds(
    caseClause.guardedPattern.pattern,
    name,
  ),
  SwitchPatternCase(:final guardedPattern) => _patternBinds(
    guardedPattern.pattern,
    name,
  ),
  SwitchExpressionCase(:final guardedPattern) => _patternBinds(
    guardedPattern.pattern,
    name,
  ),
  ForStatement(forLoopParts: ForEachPartsWithPattern(:final pattern)) ||
  ForElement(
    forLoopParts: ForEachPartsWithPattern(:final pattern),
  ) => _patternBinds(pattern, name),
  _ => false,
};

bool _patternBinds(DartPattern pattern, String name) {
  final finder = _BindingFinder(name);
  pattern.accept(finder);
  return finder.found;
}

/// Whether [local] may be assigned again after its declaration, so a later
/// use need not see its initializer.
bool _isReassigned(VariableDeclaration local) {
  if (local.isFinal || local.isConst) return false;
  final body = local.thisOrAncestorOfType<FunctionBody>();
  if (body == null) return true;
  final finder = _BindingFinder(local.name.lexeme, assignments: true);
  body.accept(finder);
  return finder.found;
}

/// Finds a pattern variable named [_name], or with [_assignments] an
/// assignment, increment or pattern assignment to it.
class _BindingFinder extends RecursiveAstVisitor<void> {
  _BindingFinder(this._name, {bool assignments = false})
    : _assignments = assignments;

  final String _name;
  final bool _assignments;
  bool found = false;

  bool _names(Expression expression) =>
      expression is SimpleIdentifier && expression.name == _name;

  @override
  void visitDeclaredVariablePattern(DeclaredVariablePattern node) {
    if (!_assignments && node.name.lexeme == _name) found = true;
    super.visitDeclaredVariablePattern(node);
  }

  @override
  void visitAssignedVariablePattern(AssignedVariablePattern node) {
    if (_assignments && node.name.lexeme == _name) found = true;
    super.visitAssignedVariablePattern(node);
  }

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    if (_assignments && _names(node.leftHandSide)) found = true;
    super.visitAssignmentExpression(node);
  }

  @override
  void visitPrefixExpression(PrefixExpression node) {
    if (_assignments && _isIncrement(node.operator.lexeme)) {
      if (_names(node.operand)) found = true;
    }
    super.visitPrefixExpression(node);
  }

  @override
  void visitPostfixExpression(PostfixExpression node) {
    if (_assignments && _isIncrement(node.operator.lexeme)) {
      if (_names(node.operand)) found = true;
    }
    super.visitPostfixExpression(node);
  }

  static bool _isIncrement(String operator) =>
      operator == '++' || operator == '--';
}

bool _declaresMember(AstNode classLike, String name) {
  for (final member in _classLikeMembers(classLike)) {
    if (member is FieldDeclaration &&
        member.fields.variables.any((v) => v.name.lexeme == name)) {
      return true;
    }
    if (member is MethodDeclaration && member.name.lexeme == name) return true;
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

  final scanner = ReplaceablePublishScanner();
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
      var relative = file.path;
      if (pathPrefix.isNotEmpty && relative.startsWith(pathPrefix)) {
        relative = relative.substring(pathPrefix.length);
      }
      relative = relative.replaceFirst(RegExp('^/'), '');
      scanner.add(relative, file.readAsStringSync());
    }
  }
  for (final violation in scanner.violations()) {
    final key = '${violation.path}\t${violation.kind}';
    stdout.writeln(
      detail ? '$key\tline ${violation.lines.join(', ')}' : key,
    );
  }
}

Never _usage([String? error]) {
  if (error != null) stderr.writeln(error);
  stderr.writeln(
    'usage: replaceable_publish_detector.dart <scan-dir>... '
    '[--path-prefix <dir>] [--detail]',
  );
  exit(2);
}
