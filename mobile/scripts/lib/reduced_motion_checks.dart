// ABOUTME: Shared recognition of this repo's reduced-motion preference reads.
// ABOUTME: Keeps every animation guard agreeing on what counts as a gate.

import 'package:analyzer/dart/ast/ast.dart';

/// Names that read the platform reduced-motion preference.
///
/// The app writes this three ways and all three are correct:
/// `MediaQuery.disableAnimationsOf(context)`, the older
/// `MediaQuery.of(context).disableAnimations`, and `context.reduceMotion`
/// from `lib/extensions/media_query_extensions.dart`. A guard that knows only
/// one of them reports correct call sites, which on a zero-tolerance check is
/// worse than silence.
const _readNames = {'disableAnimationsOf', 'disableAnimations', 'reduceMotion'};

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

/// Whether [condition] is true exactly when reduced motion is **on**.
///
/// Returns `true` for `reduceMotion` and `a || reduceMotion`, `false` for
/// `!reduceMotion` and `isPlaying && !reduceMotion`, and `null` when the
/// condition does not consult the preference at all. Callers use it to decide
/// which branch of an `if` is the motion-allowed one.
///
/// Disjunction and conjunction use Kleene three-valued logic so a mixed
/// `false`/`unknown` OR or `true`/`unknown` AND stays unknown. Those
/// conditions can still be true while reduced motion is on. Anything the
/// classifier cannot name returns `null` rather than guessing.
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
        // Kleene three-valued logic. A mixed false/unknown OR or true/unknown
        // AND is unknown: those conditions can still be true while reduced
        // motion is on, so they must not count as a gate.
        '||' =>
          left == true || right == true
              ? true
              : left == false && right == false
              ? false
              : null,
        '&&' =>
          left == false || right == false
              ? false
              : left == true && right == true
              ? true
              : null,
        _ => null,
      };
    default:
      return isReducedMotionRead(condition) ? true : null;
  }
}
