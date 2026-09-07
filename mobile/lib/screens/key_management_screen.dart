// ABOUTME: Key management screen for importing, exporting, and backing up Nostr keys
// ABOUTME: Simple, clear interface focused on user needs with helpful explanations

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/extensions/safe_pop_extension.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/authentication_source.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/protected_minor_providers.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/screens/key_management/keycast_key_export_card.dart';
import 'package:unified_logger/unified_logger.dart';

class KeyManagementScreen extends ConsumerStatefulWidget {
  /// Route name for this screen.
  static const routeName = 'key-management';

  /// Path for this route.
  static const String path = RoutePaths.keyManagement;

  const KeyManagementScreen({super.key});

  @override
  ConsumerState<KeyManagementScreen> createState() =>
      _KeyManagementScreenState();
}

class _KeyManagementScreenState extends ConsumerState<KeyManagementScreen> {
  bool _isProcessing = false;
  final _importController = TextEditingController();

  @override
  void dispose() {
    _importController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nostrService = ref.watch(nostrServiceProvider);
    final restricted = ref.watch(isKeyManagementRestrictedProvider);

    return Scaffold(
      appBar: DiVineAppBar(
        title: context.l10n.keyManagementTitle,
        showBackButton: true,
        onBackPressed: context.safePop,
      ),
      backgroundColor: context.vineColors.background,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: .fromLTRB(
              16,
              16,
              16,
              16 + MediaQuery.viewPaddingOf(context).bottom,
            ),
            children: [
              const _NpubDisplayBlock(),
              const SizedBox(height: 24),

              DivineInfoCard(
                title: context.l10n.keyManagementWhatAreKeys,
                message: context.l10n.keyManagementExplanation,
              ),
              const SizedBox(height: 24),

              // Protected minors (#182) cannot export their nsec or swap the
              // account to a self-held key; the affordances are replaced by an
              // explanatory locked card. Fails closed via
              // isKeyManagementRestrictedProvider.
              if (restricted)
                const _KeyManagementLockedCard()
              else ...[
                // Import existing key section
                _buildImportSection(context, nostrService),
                const SizedBox(height: 24),

                // Export/Backup section
                _buildExportSection(context),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImportSection(BuildContext context, nostrService) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.keyManagementImportTitle,
          style: VineTheme.titleMediumFont(
            color: context.vineColors.primaryText,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.keyManagementImportSubtitle,
          style: VineTheme.bodyMediumFont(
            color: context.vineColors.onSurfaceMuted,
          ),
        ),
        const SizedBox(height: 16),
        DivineTextField(
          controller: _importController,
          labelText: 'nsec1...',
          minLines: 1,
          maxLines: 3,
          enabled: !_isProcessing,
          autocorrect: false,
          textCapitalization: TextCapitalization.none,
          spellCheckConfiguration: const SpellCheckConfiguration.disabled(),
          filled: true,
          suffixIcon: DivineIconButton(
            icon: DivineIconName.clipboard,
            size: DivineIconButtonSize.small,
            backgroundColor: VineTheme.transparent,
            foregroundColor: context.vineColors.onSurfaceVariant,
            showShadow: false,
            tooltip: context.l10n.keyManagementPasteKey,
            onPressed: _isProcessing ? null : _pasteKeyFromClipboard,
          ),
        ),
        const SizedBox(height: 12),
        DivineInfoCard(
          icon: DivineIconName.warning,
          tone: DivineInfoCardTone.warning,
          compact: true,
          message: context.l10n.keyManagementImportWarning,
        ),
        const SizedBox(height: 16),
        DivineButton(
          label: context.l10n.keyManagementImportButton,
          expanded: true,
          isLoading: _isProcessing,
          onPressed: _isProcessing
              ? null
              : () => _importKey(context, nostrService),
        ),
      ],
    );
  }

  Widget _buildExportSection(BuildContext context) {
    final authService = ref.watch(authServiceProvider);
    final canExportLocalNsec = authService.canExportLocalNsec;
    final showKeycastRemoteSigningInfo =
        !canExportLocalNsec &&
        authService.authenticationSource == AuthenticationSource.divineOAuth;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.keyManagementBackupTitle,
          style: VineTheme.titleMediumFont(
            color: context.vineColors.primaryText,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.keyManagementBackupSubtitle,
          style: VineTheme.bodyMediumFont(
            color: context.vineColors.onSurfaceMuted,
          ),
        ),
        const SizedBox(height: 16),
        if (canExportLocalNsec) ...[
          DivineInfoCard(
            icon: DivineIconName.shieldCheck,
            tone: DivineInfoCardTone.error,
            compact: true,
            message: context.l10n.keyManagementNeverShare,
          ),
          const SizedBox(height: 16),
          DivineButton(
            label: context.l10n.keyManagementCopyNsec,
            leadingIcon: DivineIconName.copy,
            expanded: true,
            semanticIdentifier: SemanticIds.keyManagementCopyNsecButton,
            onPressed: _isProcessing ? null : () => _exportKey(context),
          ),
        ] else if (showKeycastRemoteSigningInfo)
          const KeycastKeyExportCard(),
      ],
    );
  }

  Future<void> _pasteKeyFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) return;
    _importController.text = text;
  }

  Future<void> _importKey(BuildContext context, nostrService) async {
    final nsec = _importController.text.trim();

    if (nsec.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        DivineSnackbarContainer.snackBar(
          context.l10n.keyManagementPasteKey,
          error: true,
        ),
      );
      return;
    }

    if (!nsec.startsWith('nsec1')) {
      ScaffoldMessenger.of(context).showSnackBar(
        DivineSnackbarContainer.snackBar(
          context.l10n.keyManagementInvalidFormat,
          error: true,
        ),
      );
      return;
    }

    // Show confirmation dialog
    final confirmed = await VineBottomSheet.show<bool>(
      context: context,
      scrollable: false,
      contentTitle: context.l10n.keyManagementConfirmImportTitle,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            context.l10n.keyManagementConfirmImportBody,
            style: VineTheme.bodyMediumFont(
              color: context.vineColors.onSurfaceVariant,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Row(
            spacing: 16,
            children: [
              Expanded(
                child: DivineButton(
                  label: context.l10n.reportCancel,
                  type: DivineButtonType.secondary,
                  expanded: true,
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ),
              Expanded(
                child: DivineButton(
                  label: context.l10n.keyManagementImportConfirm,
                  expanded: true,
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ),
            ],
          ),
        ),
      ],
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);

    try {
      // Use AuthService for proper session setup and relay discovery
      final authService = ref.read(authServiceProvider);
      // Re-check the protected-minor gate at the raw-key boundary: the
      // render-time gate in build() can flip to restricted while the
      // confirmation dialog above is open, and AuthService is policy-unaware.
      if (ref.read(isKeyManagementRestrictedProvider)) return;
      final result = await authService.importFromNsec(nsec);

      if (!result.success) {
        throw Exception(result.errorMessage ?? 'Failed to import key');
      }

      // Fetch profile after successful import (authService is source of truth)
      if (context.mounted && authService.currentPublicKeyHex != null) {
        try {
          await ref
              .read(profileRepositoryProvider)
              ?.fetchFreshProfile(pubkey: authService.currentPublicKeyHex!);
        } catch (e) {
          // Non-fatal - profile fetch failure shouldn't block import
        }
      }

      if (context.mounted) {
        _importController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          DivineSnackbarContainer.snackBar(
            context.l10n.keyManagementImportSuccess,
            duration: const Duration(seconds: 3),
          ),
        );

        context.safePop();
      }
    } catch (e) {
      Log.error(
        'Key import failed: $e',
        name: 'KeyManagementScreen',
        category: LogCategory.ui,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          DivineSnackbarContainer.snackBar(
            context.l10n.keyManagementImportFailed,
            error: true,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _exportKey(BuildContext context) async {
    try {
      // Consistency guard with _importKey's raw-key boundary check. No dialog
      // precedes this call, so there is no real flip window here; kept as
      // defense-in-depth so both key-handover call sites read the gate.
      if (ref.read(isKeyManagementRestrictedProvider)) return;
      final nsec = await ref.read(authServiceProvider).exportNsec();

      if (nsec == null) {
        throw Exception('No private key available to export.');
      }

      // Copy to clipboard
      await Clipboard.setData(ClipboardData(text: nsec));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          DivineSnackbarContainer.snackBar(
            context.l10n.keyManagementExportSuccess,
          ),
        );
      }
    } catch (e) {
      Log.error(
        'Key export failed: $e',
        name: 'KeyManagementScreen',
        category: LogCategory.ui,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          DivineSnackbarContainer.snackBar(
            context.l10n.keyManagementExportFailed,
            error: true,
          ),
        );
      }
    }
  }
}

class _NpubDisplayBlock extends ConsumerWidget {
  const _NpubDisplayBlock();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final npub = ref.watch(authServiceProvider).currentNpub ?? '';

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.keyManagementYourPublicKeyLabel,
                  style: VineTheme.labelMediumFont(
                    color: context.vineColors.onSurfaceMuted,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  npub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: VineTheme.bodyMediumFont(
                    color: context.vineColors.primaryText,
                  ),
                ),
              ],
            ),
          ),
          DivineIconButton(
            icon: DivineIconName.copy,
            backgroundColor: VineTheme.transparent,
            foregroundColor: context.vineColors.onSurface,
            showShadow: false,
            tooltip: l10n.keyManagementCopyPublicKeyTooltip,
            onPressed: () => _copyNpub(context, npub),
          ),
        ],
      ),
    );
  }

  Future<void> _copyNpub(BuildContext context, String npub) async {
    final l10n = context.l10n;
    await Clipboard.setData(ClipboardData(text: npub));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      DivineSnackbarContainer.snackBar(l10n.keyManagementPublicKeyCopied),
    );
  }
}

/// Shown in place of the key backup/export and import sections for a protected
/// minor (#182): the account's keys are custodially managed, so those
/// affordances are removed. The npub display and the key explanation stay.
class _KeyManagementLockedCard extends StatelessWidget {
  const _KeyManagementLockedCard();

  @override
  Widget build(BuildContext context) {
    return DivineInfoCard(
      icon: DivineIconName.shieldCheck,
      title: context.l10n.keyManagementRestrictedTitle,
      message: context.l10n.keyManagementRestrictedBody,
    );
  }
}
