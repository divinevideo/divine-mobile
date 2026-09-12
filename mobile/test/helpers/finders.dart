// ABOUTME: Finders for widgets flutter_test resolves against the framework's
// ABOUTME: Material library rather than material_ui (#8916).

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// [CommonFinders.byTooltip] for a `material_ui` [Tooltip].
///
/// `flutter_test`'s own `byTooltip` resolves `Tooltip` from
/// `package:flutter/material.dart` (`finders.dart` imports it explicitly),
/// which since #8916 is not the class our widgets build. It still finds most
/// of them by accident, because its other branch matches the [RawTooltip] a
/// `Tooltip` mounts underneath — but a tooltip with `excludeFromSemantics:
/// true` publishes no semantics tooltip and therefore mounts none, so those
/// disappear from the finder entirely. That combination is common here: a
/// control usually carries its label on a `Semantics` wrapper and excludes the
/// tooltip to stop a screen reader announcing it twice.
///
/// The predicate is a faithful port of `flutter_test`'s, with `Tooltip`
/// resolved from `material_ui`, so what it returns for a non-excluded tooltip
/// is unchanged: the [RawTooltip], not the [Tooltip] above it.
Finder findByTooltip(Pattern message, {bool skipOffstage = true}) {
  bool matches(String candidate) =>
      message is RegExp ? message.hasMatch(candidate) : candidate == message;

  return find.byWidgetPredicate(
    (widget) {
      if (widget is Tooltip) {
        final tooltipMessage =
            widget.message ?? widget.richMessage?.toPlainText() ?? '';
        if ((widget.excludeFromSemantics ?? false) || tooltipMessage.isEmpty) {
          return matches(tooltipMessage);
        }
      }
      return widget is RawTooltip && matches(widget.semanticsTooltip ?? '');
    },
    description: 'tooltip "$message"',
    skipOffstage: skipOffstage,
  );
}
