// ABOUTME: Shared recognition of this repo's reduced-motion preference reads.
// ABOUTME: Keeps every animation guard agreeing on what counts as a gate.

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

/// Names that read the platform reduced-motion preference.
///
/// The app writes this three ways and all three are correct:
/// `MediaQuery.disableAnimationsOf(context)`, the older
/// `MediaQuery.of(context).disableAnimations`, and `context.reduceMotion`
/// from `lib/extensions/media_query_extensions.dart`. A guard that knows only
/// one of them reports correct call sites, which on a zero-tolerance check is
/// worse than silence.
const _readNames = {
  'disableAnimationsOf',
  'disableAnimations',
  'reduceMotion',
};

/// Whether [expression] is itself a reduced-motion read.
///
/// Matches the whole identifier, so a merely similar name such as
/// `disableAnimationsLater` is not a read.
bool isReducedMotionRead(Expression? expression) {
  return switch (expression) {
    MethodInvocation(:final methodName) => _readNames.contains(methodName.name),
    PropertyAccess(:final propertyName) => _readNames.contains(
      propertyName.name,
    ),
    PrefixedIdentifier(:final identifier) => _readNames.contains(
      identifier.name,
    ),
    SimpleIdentifier(:final name) => _readNames.contains(name),
    _ => false,
  };
}

/// Whether [expression] mentions a reduced-motion read anywhere inside it.
bool mentionsReducedMotion(Expression? expression) {
  if (expression == null) return false;
  if (isReducedMotionRead(expression)) return true;
  final visitor = _MentionVisitor();
  expression.accept(visitor);
  return visitor.found;
}

/// Whether [condition] is true exactly when reduced motion is **on**.
///
/// Returns `true` for `reduceMotion` and `a || reduceMotion`, `false` for
/// `!reduceMotion` and `isPlaying && !reduceMotion`, and `null` when the
/// condition does not consult the preference at all. Callers use it to decide
/// which branch of an `if` is the motion-allowed one.
///
/// A disjunction is true when reduced motion is on if either side is; a
/// conjunction requires motion to be allowed if either side does. That is
/// enough for the shapes this codebase actually writes, and anything it cannot
/// classify returns `null` rather than guessing.
bool? reducedMotionPolarity(Expression? condition) {
  switch (condition) {
    case ParenthesizedExpression(:final expression):
      return reducedMotionPolarity(expression);
    case PrefixExpression(:final operator, :final operand)
        when operator.lexeme == '!':
      final inner = reducedMotionPolarity(operand);
      return inner == null ? null : !inner;
    case BinaryExpression(
      :final operator,
      :final leftOperand,
      :final rightOperand,
    ):
      final left = reducedMotionPolarity(leftOperand);
      final right = reducedMotionPolarity(rightOperand);
      if (left == null && right == null) return null;
      return switch (operator.lexeme) {
        '||' => (left ?? false) || (right ?? false),
        '&&' => !((left == false) || (right == false)),
        _ => null,
      };
    default:
      return isReducedMotionRead(condition) ? true : null;
  }
}

class _MentionVisitor extends RecursiveAstVisitor<void> {
  bool found = false;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (isReducedMotionRead(node)) found = true;
    super.visitMethodInvocation(node);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    if (isReducedMotionRead(node)) found = true;
    super.visitPropertyAccess(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    if (isReducedMotionRead(node)) found = true;
    super.visitPrefixedIdentifier(node);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (_readNames.contains(node.name)) found = true;
    super.visitSimpleIdentifier(node);
  }
}
