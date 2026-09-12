// ABOUTME: Utility for clipboard operations with visual feedback
// ABOUTME: Provides consistent copy-to-clipboard experience across the app

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';

/// Utility class for clipboard operations with visual feedback.
///
/// Provides a consistent copy-to-clipboard experience across the app,
/// showing a styled snackbar on success.
class ClipboardUtils {
  /// Copies the given text to clipboard and shows a success snackbar.
  ///
  /// [context] is used to show the snackbar.
  /// [text] is the content to copy to clipboard.
  /// [message] is the snackbar message (defaults to 'Copied to clipboard').
  static Future<void> copy(
    BuildContext context,
    String text, {
    String message = 'Copied to clipboard',
  }) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(DivineSnackbarContainer.snackBar(message));
    }
  }

  /// Copies [text] and confirms it actually reached the clipboard.
  ///
  /// Neither platform reports whether the write took. Android's
  /// `setPrimaryClip` returns `void` and iOS assigns `pasteboard.string`, and
  /// the engine reports success after every non-throwing call. A silently
  /// blocked clipboard is therefore indistinguishable from a copy without
  /// reading the value back.
  ///
  /// Returns whether the clipboard accepted it. The success message is shown
  /// only when it did; a caller handing over something the user cannot
  /// re-derive should report the `false` case rather than stay silent.
  static Future<bool> copyVerified(
    BuildContext context,
    String text, {
    required String message,
  }) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      final echoed = await Clipboard.getData(Clipboard.kTextPlain);
      if (echoed?.text != text) return false;
    } on PlatformException {
      return false;
    }

    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(DivineSnackbarContainer.snackBar(message));
    }
    return true;
  }

  /// Copies a public key (npub) to clipboard with appropriate message.
  ///
  /// This is a convenience method specifically for copying Nostr public keys.
  static Future<void> copyPubkey(BuildContext context, String npub) async {
    await copy(context, npub, message: context.l10n.profilePublicKeyCopied);
  }
}
