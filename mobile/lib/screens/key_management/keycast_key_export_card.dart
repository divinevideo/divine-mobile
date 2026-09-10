// ABOUTME: Keycast-held private key export card for the Key Management screen
// ABOUTME: Password-confirmed fetch of the nsec Divine's login service holds

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/protected_minor_providers.dart';
import 'package:openvine/utils/clipboard_utils.dart';

/// Shown in place of the local "Copy My Private Key (nsec)" action for an
/// account whose key Keycast holds.
///
/// The key is not on this device and NIP-46 defines no method that returns key
/// material, so it comes from Keycast's own export endpoint, authorized by the
/// session's bearer token plus the account password. Keycast keeps both
/// preconditions server-side — a verified email, and the `verified_minor`
/// custody refusal — so nothing here is a way around them.
///
/// Nothing is stored and nothing is shown: the key goes from the response
/// straight to the clipboard the user asked for, and is never rendered,
/// written to disk, or logged. The clipboard is therefore the only route to
/// it — a deliberate trade for keeping key material out of every frame.
class KeycastKeyExportCard extends ConsumerWidget {
  const KeycastKeyExportCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DivineInfoCard(
      icon: DivineIconName.key,
      compact: true,
      message: context.l10n.keyManagementKeycastRemoteSigning,
      footer: DivineButton(
        label: context.l10n.keyManagementCopyNsec,
        leadingIcon: DivineIconName.copy,
        type: DivineButtonType.secondary,
        size: DivineButtonSize.small,
        onPressed: () => _copyKeycastKey(context, ref),
      ),
    );
  }

  Future<void> _copyKeycastKey(BuildContext context, WidgetRef ref) async {
    // Consistency guard with the other two key-boundary call sites. A flip to
    // restricted unmounts this card, so there is no real window here; kept so
    // every handover site reads the gate. Keycast refuses a minor's export
    // server-side too, so this is defense in depth rather than the gate itself.
    if (ref.read(isKeyManagementRestrictedProvider)) return;

    final result = await VineBottomSheet.show<ExportKeyResult>(
      context: context,
      scrollable: false,
      expanded: false,
      // Fixed mode otherwise derives isScrollControlled from `expanded`, which
      // caps the sheet's height and leaves it wholly behind the keyboard.
      isScrollControlled: true,
      // The title goes through the header rather than `contentTitle` because
      // the header also supplies the spacing below the divider.
      title: Text(context.l10n.keyManagementCopyNsec),
      body: const _KeycastKeyExportFlow(),
    );

    // The sheet returns a value only when it has a refusal to report: a wrong
    // password stays inline, and a success copies the key and confirms it from
    // inside the sheet. The key itself never crosses this boundary, so there is
    // nothing here to hold or render.
    if (result == null || !context.mounted) return;

    final l10n = context.l10n;
    ScaffoldMessenger.of(context).showSnackBar(
      DivineSnackbarContainer.snackBar(
        _failureMessage(l10n, result.failure),
        error: true,
      ),
    );
  }

  /// Map a refusal to copy the user can act on.
  ///
  /// Takes the enum rather than the whole result so the server's prose cannot
  /// reach the screen: [ExportKeyResult.error] is written for the web UI, is
  /// never translated, and for a transport failure it is the raw exception.
  /// Nothing reads it — `AuthService.exportKeycastNsec` logs the enum alone —
  /// so the prose is dropped here rather than shown or recorded.
  String _failureMessage(AppLocalizations l10n, ExportKeyFailure? failure) {
    return switch (failure) {
      ExportKeyFailure.needsSignIn => l10n.keyManagementKeycastSignInAgain,
      ExportKeyFailure.emailUnverified =>
        l10n.keyManagementKeycastEmailUnverified,
      ExportKeyFailure.denied => l10n.keyManagementKeycastDenied,
      ExportKeyFailure.rateLimited => l10n.keyManagementKeycastRateLimited,
      // A definitive "there is no key" is not a failure to reach the service,
      // and unlike the generic arm no retry will change it.
      ExportKeyFailure.noKey => l10n.keyManagementKeycastNoKey,
      _ => l10n.keyManagementKeycastGenericFailure,
    };
  }
}

/// The password confirmation behind the export.
///
/// The export runs here rather than in the caller so a wrong password can stay
/// inline — the field keeps its place and contents, and the retry costs one
/// keystroke instead of a reopen. Any refusal a retry cannot clear pops with the
/// result for the caller to report.
///
/// A success copies the key and closes: it is never rendered, never held in a
/// controller, and never handed back through the pop, so no frame of this flow
/// contains key material to screenshot or record. The password is the same — it
/// lives only in a controller disposed with the sheet.
class _KeycastKeyExportFlow extends ConsumerStatefulWidget {
  const _KeycastKeyExportFlow();

  @override
  ConsumerState<_KeycastKeyExportFlow> createState() =>
      _KeycastKeyExportFlowState();
}

class _KeycastKeyExportFlowState extends ConsumerState<_KeycastKeyExportFlow> {
  /// Gap kept between a raised keyboard and the sheet, mirroring the clearance
  /// `VineBottomSheet` applies to its own bottom input: reported keyboard height
  /// varies while typing, and a flush edge puts the actions under the keyboard.
  static const double _keyboardClearance = 12;

  /// Wrong passwords this sheet will take before it stops accepting them.
  ///
  /// An uncapped retry loop turns a borrowed unlocked phone into a password
  /// oracle that pays out the account's nsec. Reopening the sheet clears the
  /// count, so this is friction rather than a lockout — the durable control is
  /// the server-side lockout and `key_egress` audit trail that keycast#325
  /// adds.
  static const int _maxAttempts = 5;

  final _passwordController = TextEditingController();
  bool _submitting = false;
  String? _errorText;

  /// Wrong passwords submitted so far, against [_maxAttempts].
  int _wrongPasswords = 0;

  /// True once [_maxAttempts] is spent: the field and the submit action stay
  /// disabled until the sheet is dismissed.
  bool _lockedOut = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_lockedOut) return;

    final password = _passwordController.text;
    final l10n = context.l10n;

    if (password.isEmpty) {
      setState(() => _errorText = l10n.authPasswordRequired);
      return;
    }

    setState(() {
      _submitting = true;
      _errorText = null;
    });

    final result = await ref
        .read(authServiceProvider)
        .exportKeycastNsec(password);

    if (!mounted) return;

    if (result.success && result.key != null) {
      // Straight from the response to the clipboard: the key never reaches a
      // controller and never rebuilds into the tree, so no frame holds it. The
      // spinner stays up through the copy, which also blocks a second tap.
      // Copy before the pop — the confirmation goes through this context, and a
      // popped sheet's context is unmounted.
      try {
        final copied = await ClipboardUtils.copyVerified(
          context,
          result.key!,
          message: l10n.keyManagementExportSuccess,
        );
        // A clipboard the device refused is reported, not assumed: this is the
        // one hand-over the user cannot re-derive, and a silent "copied" would
        // leave them believing they have a backup they do not have.
        if (!copied && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            DivineSnackbarContainer.snackBar(
              l10n.keyManagementKeycastCopyBlocked,
              error: true,
            ),
          );
        }
      } finally {
        // Closed either way: both actions are disabled while submitting, so a
        // clipboard that throws would otherwise strand the sheet with nothing
        // left to tap. Nothing is handed back — the caller reports refusals,
        // and this success has already reported itself.
        if (mounted) Navigator.of(context).pop();
      }
      return;
    }

    // Wrong password is the one failure worth staying open for; anything else
    // needs a different action than "type it again". Retrying is capped so the
    // sheet is not an unlimited guessing loop against an endpoint that hands
    // back the nsec.
    if (result.failure == ExportKeyFailure.wrongPassword) {
      _wrongPasswords++;
      final lockedOut = _wrongPasswords >= _maxAttempts;
      setState(() {
        _submitting = false;
        _lockedOut = lockedOut;
        _errorText = lockedOut
            ? l10n.keyManagementKeycastTooManyAttempts
            : l10n.keyManagementKeycastWrongPassword;
      });
      return;
    }

    // The sheet is a Navigator route, so pop it through the Navigator that
    // owns it rather than GoRouter — the modal is not part of the route tree.
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(
        bottom: keyboardInset > 0 ? keyboardInset + _keyboardClearance : 0,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: _PasswordStep(
          controller: _passwordController,
          errorText: _errorText,
          submitting: _submitting,
          lockedOut: _lockedOut,
          onSubmit: _submit,
          onCancel: () => Navigator.of(context).pop(),
          // Clear a stale "wrong password" as soon as the user edits, so the
          // error refers to the attempt rather than the previous one. A spent
          // attempt budget is not stale, so it stays put.
          onEdited: () {
            if (_errorText != null && !_lockedOut) {
              setState(() => _errorText = null);
            }
          },
        ),
      ),
    );
  }
}

/// Confirm the account password, which copies the key it brings back.
class _PasswordStep extends StatelessWidget {
  const _PasswordStep({
    required this.controller,
    required this.errorText,
    required this.submitting,
    required this.lockedOut,
    required this.onSubmit,
    required this.onCancel,
    required this.onEdited,
  });

  final TextEditingController controller;
  final String? errorText;
  final bool submitting;
  final bool lockedOut;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;
  final VoidCallback onEdited;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final blocked = submitting || lockedOut;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 16,
      children: [
        Text(
          l10n.keyManagementKeycastPasswordPrompt,
          style: VineTheme.bodyMediumFont(
            color: context.vineColors.onSurfaceVariant,
          ),
        ),
        // The local-nsec path warns beside its copy button, before the key
        // moves. Confirming here is that same moment, so the warning belongs
        // ahead of the field rather than after the copy has already happened.
        DivineInfoCard(
          icon: DivineIconName.warning,
          tone: DivineInfoCardTone.error,
          compact: true,
          message: l10n.keyManagementNeverShare,
        ),
        DivineAuthTextField(
          label: l10n.authPasswordLabel,
          controller: controller,
          obscureText: true,
          autofillHints: const [AutofillHints.password],
          errorText: errorText,
          enabled: !blocked,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) {
            if (!blocked) onSubmit();
          },
          onChanged: (_) => onEdited(),
          showPasswordSemanticLabel: context.l10n.authShowPassword,
          hidePasswordSemanticLabel: context.l10n.authHidePassword,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          spacing: 8,
          children: [
            DivineButton(
              label: l10n.commonCancel,
              type: DivineButtonType.tertiary,
              size: DivineButtonSize.small,
              onPressed: submitting ? null : onCancel,
            ),
            // Confirming fetches the key and copies it in one step, so the
            // label and the icon both name the clipboard.
            DivineButton(
              label: l10n.keyManagementKeycastCopyKey,
              leadingIcon: DivineIconName.copy,
              size: DivineButtonSize.small,
              isLoading: submitting,
              onPressed: blocked ? null : onSubmit,
            ),
          ],
        ),
      ],
    );
  }
}
