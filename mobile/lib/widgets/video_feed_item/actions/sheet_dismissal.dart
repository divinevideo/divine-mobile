// ABOUTME: Helpers for closing a bottom sheet and presenting a follow-up.
// ABOUTME: Survives sheets reached after their route is gone or outside GoRouter.

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Dismisses the sheet that owns [sheetContext].
///
/// Not `popModalIfMounted`: sheets are dismissed from bloc listeners rather
/// than from a button, so this has to survive being reached while GoRouter is
/// out of the tree. It shares that helper's mounted guard — `canPop` reads an
/// inherited widget and `Navigator.of` walks ancestors, and both throw on a
/// context whose route is already gone (#6512).
void dismissSheet(BuildContext sheetContext) {
  if (!sheetContext.mounted) {
    return;
  }
  try {
    if (sheetContext.canPop()) {
      sheetContext.pop();
      return;
    }
  } catch (_) {
    // GoRouter context extensions throw when the router is not in the
    // widget tree (e.g., inside modal bottom sheets). Fall through to
    // the standard Navigator as a safe fallback.
  }
  Navigator.of(sheetContext).maybePop();
}

/// Dismisses the sheet owning [sheetContext], then presents [presenter] from
/// the root navigator.
///
/// Callers may reach this after an `await`, when the sheet has already been
/// closed and disposed; reading the context then throws, so it does nothing.
Future<T?> presentAfterSheetDismiss<T>(
  BuildContext sheetContext,
  Future<T?> Function(BuildContext hostContext) presenter,
) async {
  if (!sheetContext.mounted) return null;
  final hostContext = Navigator.of(sheetContext, rootNavigator: true).context;
  dismissSheet(sheetContext);
  await WidgetsBinding.instance.endOfFrame;
  if (!sheetContext.mounted || !hostContext.mounted) return null;
  return presenter(hostContext);
}
